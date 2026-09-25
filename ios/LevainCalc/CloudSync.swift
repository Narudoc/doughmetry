import Foundation
import LevainCore
import Observation

/// iCloud Documents 컨테이너에 라이브러리 문서(library.json)를 두고 기기 간 동기화한다.
///
/// - entitlement가 없거나(개발자 프로그램 승인 전 빌드) iCloud 미로그인이면
///   컨테이너 URL이 nil → `isAvailable == false` → 앱은 로컬 저장으로만 동작한다.
/// - 읽기/쓰기는 NSFileCoordinator로 조정, 원격 변경은 NSMetadataQuery로 감지.
/// - 병합 규칙은 LevainCore.LibrarySync (테스트 완료), 여기는 파일 계층만 담당.
@Observable @MainActor
final class CloudSync {
    enum Status: Equatable {
        case checking
        case unavailable
        case disabled
        case idle
        case syncing
        case error(String)
    }

    static let fileName = "library.json"

    var status: Status = .checking
    var lastSyncAt: Date?
    var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "iCloudSyncEnabled")
            refreshStatus()
            if enabled, !oldValue { onEnabled?() }
        }
    }
    /// 토글을 다시 켰을 때 동기화를 재개하기 위한 콜백 (AppModel이 설정)
    var onEnabled: (() -> Void)?
    /// NSMetadataQuery가 첫 수집을 마쳤는지 — 그 전엔 원격 문서 유무를 알 수 없으므로 동기화하지 않는다
    private(set) var hasGathered = false

    private(set) var containerURL: URL?
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []

    var isAvailable: Bool { containerURL != nil }

    /// iCloud 메타데이터에 library.json이 존재하는가 (아직 내려받지 않았어도 true)
    private var remoteFileKnown: Bool {
        guard let query else { return false }
        query.disableUpdates()
        defer { query.enableUpdates() }
        return query.results.contains { item in
            (item as? NSMetadataItem)?.value(forAttribute: NSMetadataItemFSNameKey) as? String
                == Self.fileName
        }
    }

    private var documentURL: URL? {
        containerURL?.appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(Self.fileName)
    }

    init() {
        enabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
    }

    /// 컨테이너 URL 확인 — 메인 스레드를 막을 수 있어 백그라운드에서 조회한다
    func prepare() async {
        let url = await Task.detached(priority: .utility) { () -> URL? in
            FileManager.default.url(forUbiquityContainerIdentifier: nil)
        }.value
        containerURL = url
        refreshStatus()
    }

    private func refreshStatus() {
        if !isAvailable {
            status = .unavailable
        } else if !enabled {
            status = .disabled
        } else if status != .syncing {
            status = .idle
        }
    }

    /// 원격 변경 감지 시작 — 콜백은 메인 액터에서 호출된다
    func startObserving(onChange: @escaping @MainActor () -> Void) {
        guard isAvailable, query == nil else { return }
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, Self.fileName)
        for name in [
            NSNotification.Name.NSMetadataQueryDidFinishGathering,
            NSNotification.Name.NSMetadataQueryDidUpdate,
        ] {
            let token = NotificationCenter.default.addObserver(
                forName: name, object: q, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.hasGathered = true
                    onChange()
                }
            }
            observers.append(token)
        }
        q.start()
        query = q
    }

    // MARK: 파일 I/O (NSFileCoordinator)

    /// 원격 문서 읽기 — 없으면 nil. 아직 내려받지 않은 파일은 조정 읽기가 다운로드를 기다린다.
    /// isNewerFormat이면 새 버전 앱이 쓴 문서라 이 기기는 덮어쓰면 안 된다 (LibrarySync.decodeReport).
    func readRemote() async throws -> (document: LibraryDocument, isNewerFormat: Bool)? {
        guard let url = documentURL else { return nil }
        // 로컬에 아직 내려오지 않았어도 iCloud 메타데이터에 있으면 "없음"이 아니다 —
        // 조정 읽기가 다운로드를 기다린다. (새 기기에서 빈 문서로 덮어쓰는 사고 방지)
        let known = remoteFileKnown
        return try await Task.detached(priority: .userInitiated) {
            () -> (document: LibraryDocument, isNewerFormat: Bool)? in
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) && !known { return nil }
            try? fm.startDownloadingUbiquitousItem(at: url)

            var coordError: NSError?
            var result: (document: LibraryDocument, isNewerFormat: Bool)?
            var readError: Error?
            NSFileCoordinator(filePresenter: nil).coordinate(
                readingItemAt: url, options: [], error: &coordError
            ) { readURL in
                guard fm.fileExists(atPath: readURL.path) else { return }
                do {
                    let data = try Data(contentsOf: readURL)
                    result = LibrarySync.decodeReport(data)
                } catch {
                    readError = error
                }
            }
            if let coordError { throw coordError }
            if let readError { throw readError }
            return result
        }.value
    }

    func writeRemote(_ doc: LibraryDocument) async throws {
        guard let url = documentURL else { return }
        let data = try LibrarySync.encode(doc)
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            try fm.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            var coordError: NSError?
            var writeError: Error?
            NSFileCoordinator(filePresenter: nil).coordinate(
                writingItemAt: url, options: .forReplacing, error: &coordError
            ) { writeURL in
                do {
                    try data.write(to: writeURL, options: .atomic)
                } catch {
                    writeError = error
                }
            }
            if let coordError { throw coordError }
            if let writeError { throw writeError }
        }.value
    }

    func markSynced() {
        lastSyncAt = Date()
        status = .idle
        refreshStatus()  // 동기화 중 토글을 껐으면 .disabled로
    }
}
