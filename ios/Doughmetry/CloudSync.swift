import Foundation
import DoughmetryCore
import Observation

/// iCloud Documents 컨테이너에 라이브러리 문서(library.json)를 두고 기기 간 동기화한다.
///
/// - entitlement가 없거나(개발자 프로그램 승인 전 빌드) iCloud 미로그인이면
///   컨테이너 URL이 nil → `isAvailable == false` → 앱은 로컬 저장으로만 동작한다.
/// - 읽기/쓰기는 NSFileCoordinator로 조정, 원격 변경은 NSMetadataQuery로 감지.
/// - 병합 규칙은 DoughmetryCore.LibrarySync (테스트 완료), 여기는 파일 계층만 담당.
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
    /// 합치거나 정리하지 못하고 iCloud에 그대로 둔 충돌 판 수 — 설정 화면에 알린다 (데이터를 지우지 않으므로 남는다)
    var keptConflictCount = 0

    private(set) var containerURL: URL?
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    /// 원격 변경 콜백 (AppModel이 설정) — 메인 액터에서 호출된다
    private var onRemoteChange: (@MainActor () -> Void)?
    /// 마지막으로 동기화를 일으킨 원격 문서 상태 (remoteState) — nil이면 다음 갱신에서 거르지 않는다
    private var lastRemoteState: LibrarySync.RemoteFileState?
    /// 마지막으로 기록한 업로드 오류 — 같은 오류를 갱신마다 다시 남기지 않는다
    private var lastUploadError: String?

    var isAvailable: Bool { containerURL != nil }

    /// 쿼리 결과의 library.json 항목을 읽는다 — 읽는 동안 갱신을 멈춘다. 쿼리가 없으면 nil
    private func withLibraryItem<T>(_ body: (NSMetadataItem?) -> T) -> T? {
        guard let query else { return nil }
        query.disableUpdates()
        defer { query.enableUpdates() }
        let item = query.results.lazy.compactMap({ $0 as? NSMetadataItem }).first(where: {
            $0.value(forAttribute: NSMetadataItemFSNameKey) as? String == Self.fileName
        })
        return body(item)
    }

    /// iCloud 메타데이터에 library.json이 존재하는가 (아직 내려받지 않았어도 true)
    private var remoteFileKnown: Bool {
        withLibraryItem { $0 != nil } ?? false
    }

    /// 원격 문서의 내용 변경 시각·내려받기 상태·충돌 여부 — 그대로면 다시 읽어도 결과가 같다
    private var remoteState: LibrarySync.RemoteFileState {
        withLibraryItem { item -> LibrarySync.RemoteFileState in
            guard let item else { return .absent }
            let changed = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
            let download = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            guard changed != nil || download != nil else { return .unknown }
            return .present(
                changed: changed, download: download,
                failed: item.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) != nil,
                conflicts: item.value(forAttribute: NSMetadataUbiquitousItemHasUnresolvedConflictsKey) as? Bool
                    ?? false)
        } ?? .unknown
    }

    /// iCloud가 library.json 내려받기에 실패했다고 알린 상태 (NSMetadataUbiquitousItemDownloadingErrorKey)
    private var remoteDownloadFailed: Bool {
        withLibraryItem { $0?.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) != nil } ?? false
    }

    /// 업로드 실패 기록 — 기기에 쓴 뒤 업로드가 막히면(저장 공간 부족 NSUbiquitousFileNotUploadedDueToQuotaError 등)
    /// 화면은 '동기화됨'으로 남으므로 적어도 진단 기록에는 남긴다. 같은 오류는 한 번만
    private func logUploadState() {
        let upload = withLibraryItem { item -> (error: String?, uploaded: Bool?) in
            let error = item?.value(forAttribute: NSMetadataUbiquitousItemUploadingErrorKey) as? NSError
            return (error.map(errorCode), item?.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool)
        }
        guard let upload, upload.error != lastUploadError else { return }
        lastUploadError = upload.error
        if let error = upload.error {
            Log.sync.error(
                "upload failed: \(error, privacy: .public) uploaded=\(upload.uploaded.map { "\($0)" } ?? "?", privacy: .public)")
        } else {
            Log.sync.notice("upload error cleared")
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
        onRemoteChange = onChange
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
                Task { @MainActor in self?.queryDidChange() }
            }
            observers.append(token)
        }
        q.start()
        query = q
    }

    /// 첫 수집 완료·원격 메타데이터 갱신. 갱신은 이 앱이 쓴 파일의 업로드 진행률이 바뀔 때마다도 오므로,
    /// 원격 문서 상태가 그대로면 전체 동기화(조정 읽기·병합)를 다시 돌리지 않는다 (LibrarySync.shouldSync)
    private func queryDidChange() {
        logUploadState()
        let state = remoteState
        guard LibrarySync.shouldSync(state: state, last: lastRemoteState, hasGathered: hasGathered) else { return }
        Log.sync.notice("remote changed: \(state.logSummary, privacy: .public) gathered=\(self.hasGathered)")
        hasGathered = true
        lastRemoteState = state
        onRemoteChange?()
    }

    /// 동기화가 실패했을 때 — 원격 상태가 그대로여도 다음 메타데이터 갱신에서 다시 시도하도록 기억을 지운다
    func forgetRemoteState() {
        lastRemoteState = nil
    }

    // MARK: 파일 I/O (NSFileCoordinator)

    enum SyncError: Error {
        /// iCloud 메타데이터에는 문서가 있는데 이 기기에 내려오지 않았다 — "원격 없음"으로 보면
        /// 로컬 문서로 iCloud의 유일한 사본을 덮어쓰므로 동기화를 미룬다 (내려받기가 끝나면 메타데이터 갱신으로 다시 돈다)
        case notDownloaded
        /// iCloud가 내려받기 실패를 알렸다 (NSMetadataUbiquitousItemDownloadingErrorKey) — 다음 시도에서 다시 내려받는다
        case downloadFailed
        /// 조정 읽기·쓰기가 제한 시간 안에 끝나지 않았다 — 오프라인에서 내려받기를 끝없이 기다리지 않도록 취소했다
        case timedOut
    }

    /// 정리할 충돌 판 — NSFileVersion 객체를 그대로 들고 있다가 정리한다.
    /// URL은 식별자로 쓰지 않는다: 판이 지워지면 nil이 되는데 Swift에는 non-optional로 들어와 접근하면 앱이 멈춘다.
    /// NSFileVersion은 Sendable이 아니지만 읽기 작업이 만든 뒤 정리 작업이 넘겨받을 뿐, 동시에 만지지 않는다.
    struct ConflictVersions: @unchecked Sendable {
        let versions: [NSFileVersion]
        var isEmpty: Bool { versions.isEmpty }
    }

    /// 원격 문서 스냅샷 — 내용과 판정은 LibrarySync.snapshot, 여기는 정리할 판 객체만 더 든다
    struct RemoteSnapshot: Sendable {
        var snapshot: LibrarySync.Snapshot
        /// snapshot.resolvable에 해당하는 충돌 판 — 병합 결과를 원격에 쓴 뒤에만 정리한다
        var resolvable: ConflictVersions
    }

    /// 조정 접근 콜백을 받는 큐 — 메인 스레드를 막지 않는다
    nonisolated private static let ioQueue = OperationQueue()

    /// 조정 읽기 제한 시간 — 내려받기를 기다리는 시간을 포함한다
    nonisolated private static let readTimeout: Duration = .seconds(60)
    /// 조정 쓰기 제한 시간 — 쓰기는 기기 안에서 끝나고 업로드는 나중에 되므로 짧게
    nonisolated private static let writeTimeout: Duration = .seconds(30)

    /// NSFileCoordinator.cancel()은 다른 스레드에서 부를 수 있다 (제한 시간 타이머가 부른다)
    private struct CoordinatorBox: @unchecked Sendable {
        let coordinator = NSFileCoordinator(filePresenter: nil)
    }

    /// 비동기 조정 접근 + 제한 시간. 시간이 지나면 조정자를 취소하고 timedOut을 던진다 —
    /// 오프라인에서 조정 읽기가 내려받기를 끝없이 기다리면 동기화가 '동기화 중'에 멈추고 다음 동기화도 돌지 못한다.
    /// 조정자는 접근 블록을 정확히 한 번 부르므로(취소되면 NSUserCancelledError로) continuation도 한 번만 재개된다.
    /// body는 ioQueue에서 한 번 실행된다 — 호출 측이 그 뒤로 만지지 않는 값만 잡을 것.
    nonisolated private static func coordinate<T: Sendable>(
        _ intents: [NSFileAccessIntent], timeout: Duration, _ body: @escaping @Sendable () throws -> T
    ) async throws -> T {
        let box = CoordinatorBox()
        let timer = Task {
            try? await Task.sleep(for: timeout)
            if !Task.isCancelled { box.coordinator.cancel() }
        }
        defer { timer.cancel() }
        return try await withCheckedThrowingContinuation { continuation in
            box.coordinator.coordinate(with: intents, queue: ioQueue) { error in
                if let error = error as NSError? {
                    let cancelled = error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
                    continuation.resume(throwing: cancelled ? SyncError.timedOut : error)
                    return
                }
                continuation.resume(with: Result { try body() })
            }
        }
    }

    /// 원격 문서 읽기 — 문서가 없으면 nil. 아직 내려받지 않은 파일은 조정 읽기가 다운로드를 기다리고,
    /// 그래도 파일이 없으면 nil이 아니라 notDownloaded를(iCloud가 실패를 알렸으면 downloadFailed를) 던진다.
    /// 충돌 판도 함께 읽는다 — 현재 판만 읽으면 다른 판에만 있는 레시피는 그 기기가 다시 동기화하기 전에
    /// 초기화·분실되면 영영 사라진다.
    func readRemote() async throws -> RemoteSnapshot? {
        guard let url = documentURL else { return nil }
        // 로컬에 아직 내려오지 않았어도 iCloud 메타데이터에 있으면 "없음"이 아니다 (새 기기에서 로컬 문서로 덮어쓰는 사고 방지)
        let known = remoteFileKnown
        do {
            return try await Self.readSnapshot(at: url, known: known)
        } catch SyncError.notDownloaded where remoteDownloadFailed {
            throw SyncError.downloadFailed
        } catch SyncError.timedOut where remoteDownloadFailed {
            throw SyncError.downloadFailed
        }
    }

    nonisolated private static func readSnapshot(at url: URL, known: Bool) async throws -> RemoteSnapshot? {
        if !FileManager.default.fileExists(atPath: url.path) && !known { return nil }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        let versions = ConflictVersions(versions: NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? [])
        do {
            return try await coordinatedSnapshot(url: url, known: known, versions: versions)
        } catch {
            // 충돌 판 하나를 읽지 못하면(내려받기 실패·그새 지워짐) 한꺼번에 건 조정 읽기 전체가 실패한다 —
            // 그 판 하나 때문에 동기화가 영영 멈추지 않도록 문서만 다시 읽는다. 그 판은 병합하지도 정리하지도 않는다
            if versions.isEmpty || error is SyncError { throw error }
            Log.sync.notice(
                "reading \(versions.versions.count) conflict versions failed (\(errorCode(error), privacy: .public)) — reading current only")
            var snapshot = try await coordinatedSnapshot(url: url, known: known, versions: ConflictVersions(versions: []))
            snapshot?.snapshot.keptConflictCount = versions.versions.count
            return snapshot
        }
    }

    /// 문서와 충돌 판을 한 번의 조정 읽기로 함께 읽는다 — 조정자를 겹쳐 쓰지 않고,
    /// 아직 내려오지 않은 판도 그 URL의 조정 읽기가 내려받는다 (NSFileVersion.h)
    nonisolated private static func coordinatedSnapshot(
        url: URL, known: Bool, versions: ConflictVersions
    ) async throws -> RemoteSnapshot? {
        let item = NSFileAccessIntent.readingIntent(with: url, options: [])
        let versionIntents = versions.versions.map { NSFileAccessIntent.readingIntent(with: $0.url, options: []) }
        let snapshot = try await coordinate([item] + versionIntents, timeout: readTimeout) {
            () throws -> LibrarySync.Snapshot? in
            // 문서가 없으면 충돌 판도 읽지 않는다 (원격 없음 또는 notDownloaded)
            var currentData: Data?
            var versionData: [Data?] = []
            if FileManager.default.fileExists(atPath: item.url.path) {
                currentData = try Data(contentsOf: item.url)
                versionData = versionIntents.map { try? Data(contentsOf: $0.url) }
            }
            do {
                return try LibrarySync.snapshot(currentData: currentData, known: known, versionData: versionData)
            } catch LibrarySync.SnapshotError.notDownloaded {
                throw SyncError.notDownloaded
            }
        }
        guard let snapshot else { return nil }
        if snapshot.currentIsCorrupt {
            // 빈 문서로 읽었으므로 이번 동기화가 병합 결과로 그 파일을 덮어쓴다
            Log.sync.error("remote library.json is not JSON — treated as empty")
        }
        return RemoteSnapshot(
            snapshot: snapshot,
            resolvable: ConflictVersions(versions: snapshot.resolvable.map { versions.versions[$0] }))
    }

    /// 병합해 원격에 반영한 충돌 판을 정리한다 — 읽을 때 들고 온 판만 지우므로 그 뒤 새로 생긴 판은 남는다.
    /// 실패해도(제한 시간 포함) 괜찮다: 남은 판은 다음 동기화에서 다시 합쳐진다 (병합은 반복해도 결과가 같다).
    func resolveConflicts(_ conflicts: ConflictVersions) async {
        guard let url = documentURL, !conflicts.isEmpty else { return }
        await Self.resolve(conflicts, at: url)
    }

    nonisolated private static func resolve(_ conflicts: ConflictVersions, at url: URL) async {
        let intent = NSFileAccessIntent.writingIntent(with: url, options: [])
        do {
            try await coordinate([intent], timeout: writeTimeout) {
                // 그새 다른 기기가 정리한 판은 건드리지 않는다 — 지금도 미해결인 판 중 들고 온 것과 같은 판만
                // (NSFileVersion의 ==는 같은 판인지를 비교한다, NSFileVersion.h)
                for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: intent.url) ?? []
                where conflicts.versions.contains(version) {
                    version.isResolved = true
                    do {
                        try version.remove()
                    } catch {
                        Log.sync.error("removing a conflict version failed: \(errorCode(error), privacy: .public)")
                    }
                }
            }
        } catch {
            Log.sync.error("resolving conflict versions failed: \(errorCode(error), privacy: .public)")
        }
    }

    func writeRemote(_ doc: LibraryDocument) async throws {
        guard let url = documentURL else { return }
        try await Self.write(doc, to: url)
    }

    /// 인코딩도 여기서 — 라이브러리 전체 인코딩을 메인 액터에서 하지 않는다
    nonisolated private static func write(_ doc: LibraryDocument, to url: URL) async throws {
        let data = try LibrarySync.encode(doc)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let intent = NSFileAccessIntent.writingIntent(with: url, options: .forReplacing)
        try await coordinate([intent], timeout: writeTimeout) {
            try data.write(to: intent.url, options: .atomic)
        }
    }

    /// 동기화 실패 알림 — 그사이 동기화를 껐으면 '꺼짐'으로 둔다 (꺼진 동안은 다시 시도하지 않으므로 "다시 시도합니다"는 거짓이 된다)
    func fail(_ message: String) {
        status = enabled ? .error(message) : .disabled
    }

    func markSynced() {
        lastSyncAt = Date()
        status = .idle
        refreshStatus()  // 동기화 중 토글을 껐으면 .disabled로
    }
}

extension LibrarySync.RemoteFileState {
    /// 진단 기록용 요약
    var logSummary: String {
        switch self {
        case .absent: return "absent"
        case .unknown: return "unknown"
        case let .present(changed, download, failed, conflicts):
            let status = download.map { $0.replacingOccurrences(of: "NSMetadataUbiquitousItemDownloadingStatus", with: "") }
            return "changed=\(changed.map { "\(Int($0.timeIntervalSince1970))" } ?? "?") download=\(status ?? "?")"
                + " failed=\(failed) conflicts=\(conflicts)"
        }
    }
}
