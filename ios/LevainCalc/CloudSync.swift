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
    /// 합치거나 정리하지 못하고 iCloud에 그대로 둔 충돌 판 수 — 설정 화면에 알린다 (데이터를 지우지 않으므로 남는다)
    var keptConflictCount = 0

    private(set) var containerURL: URL?
    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    /// 원격 변경 콜백 (AppModel이 설정) — 메인 액터에서 호출된다
    private var onRemoteChange: (@MainActor () -> Void)?
    /// 마지막으로 동기화를 일으킨 원격 문서 상태 (remoteState)
    private var lastRemoteState: String?

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

    /// 원격 문서의 내용 변경 시각·내려받기 상태·충돌 여부 요약 — 셋이 그대로면 다시 읽어도 결과가 같다.
    /// 속성을 알 수 없으면 nil (그때는 거르지 않고 동기화한다)
    private var remoteState: String? {
        guard let query else { return nil }
        query.disableUpdates()
        defer { query.enableUpdates() }
        guard
            let item = query.results.lazy.compactMap({ $0 as? NSMetadataItem }).first(where: {
                $0.value(forAttribute: NSMetadataItemFSNameKey) as? String == Self.fileName
            })
        else { return "absent" }
        let changed = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
        let download = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
        guard changed != nil || download != nil else { return nil }
        let failed = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) != nil
        let conflicts =
            item.value(forAttribute: NSMetadataUbiquitousItemHasUnresolvedConflictsKey) as? Bool ?? false
        return "\(changed?.timeIntervalSinceReferenceDate ?? 0)|\(download ?? "")|\(failed)|\(conflicts)"
    }

    /// iCloud가 library.json 내려받기에 실패했다고 알린 상태 (NSMetadataUbiquitousItemDownloadingErrorKey)
    private var remoteDownloadFailed: Bool {
        guard let query else { return false }
        query.disableUpdates()
        defer { query.enableUpdates() }
        return query.results.lazy.compactMap({ $0 as? NSMetadataItem }).contains {
            $0.value(forAttribute: NSMetadataItemFSNameKey) as? String == Self.fileName
                && $0.value(forAttribute: NSMetadataUbiquitousItemDownloadingErrorKey) != nil
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
    /// 원격 문서 상태가 그대로면 전체 동기화(조정 읽기·병합)를 다시 돌리지 않는다
    private func queryDidChange() {
        let state = remoteState
        // 충돌 판이 남아 있는 동안은 거르지 않는다 — 정리하지 않고 둔 판 때문에 표시가 계속 켜져 있으면
        // 새 충돌 판이 와도 상태 요약이 그대로라 놓친다
        let hasConflicts = state?.hasSuffix("|true") ?? false
        if hasGathered, let state, !hasConflicts, state == lastRemoteState { return }
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

    /// 원격 문서 스냅샷
    struct RemoteSnapshot: Sendable {
        /// iCloud 현재 판 — 병합 대상이자, 병합 결과를 다시 써야 하는지 비교하는 대상
        var current: LibraryDocument
        /// 두 기기가 따로 쓴 판(미해결 충돌 판) — 로컬·현재 판과 함께 LibrarySync.merge(_:) 한 번으로 합친다
        var conflicts: [LibraryDocument]
        /// 새 버전 앱이 쓴 판이 섞였다 — 이 기기는 합치지도 덮어쓰지도 않는다 (LibrarySync.decodeReport)
        var isNewerFormat: Bool
        /// conflicts 중 정리해도 되는 판 — 병합 결과를 원격에 쓴 뒤에만 정리한다
        var resolvable: ConflictVersions
        /// 정리하지 않고 그대로 두는 충돌 판 수 — 이번에 읽지 못했거나 일부 항목이 손상된 판.
        /// 새 버전 앱이 쓴 판은 빼고 센다 (isNewerFormat이 따로 알린다 — 앱을 업데이트하면 합쳐진다)
        var keptConflictCount: Int
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
    nonisolated private static func coordinate<T>(
        _ intents: [NSFileAccessIntent], timeout: Duration, _ body: @escaping () throws -> T
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
            var snapshot = try await coordinatedSnapshot(url: url, known: known, versions: ConflictVersions(versions: []))
            snapshot?.keptConflictCount = versions.versions.count
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
        return try await coordinate([item] + versionIntents, timeout: readTimeout) { () throws -> RemoteSnapshot? in
            guard FileManager.default.fileExists(atPath: item.url.path) else {
                if known { throw SyncError.notDownloaded }
                return nil
            }
            let report = LibrarySync.decodeReport(try Data(contentsOf: item.url))
            // 읽지 못한 판은 병합에도 정리에도 넣지 않는다
            var versionData: [Data] = []
            var readVersions: [NSFileVersion] = []
            for (version, intent) in zip(versions.versions, versionIntents) {
                guard let data = try? Data(contentsOf: intent.url) else { continue }
                versionData.append(data)
                readVersions.append(version)
            }
            let conflicts = LibrarySync.conflictDocuments(versionData)
            return RemoteSnapshot(
                current: report.document,
                conflicts: conflicts.documents,
                isNewerFormat: report.isNewerFormat || conflicts.isNewerFormat,
                resolvable: ConflictVersions(versions: conflicts.resolvable.map { readVersions[$0] }),
                keptConflictCount: versions.versions.count - conflicts.resolvable.count
                    - conflicts.newerFormatCount)
        }
    }

    /// 병합해 원격에 반영한 충돌 판을 정리한다 — 읽을 때 들고 온 판만 지우므로 그 뒤 새로 생긴 판은 남는다.
    /// 실패해도(제한 시간 포함) 괜찮다: 남은 판은 다음 동기화에서 다시 합쳐진다 (병합은 반복해도 결과가 같다).
    func resolveConflicts(_ conflicts: ConflictVersions) async {
        guard let url = documentURL, !conflicts.isEmpty else { return }
        await Self.resolve(conflicts, at: url)
    }

    nonisolated private static func resolve(_ conflicts: ConflictVersions, at url: URL) async {
        let intent = NSFileAccessIntent.writingIntent(with: url, options: [])
        try? await coordinate([intent], timeout: writeTimeout) {
            // 그새 다른 기기가 정리한 판은 건드리지 않는다 — 지금도 미해결인 판 중 들고 온 것과 같은 판만
            // (NSFileVersion의 ==는 같은 판인지를 비교한다, NSFileVersion.h)
            for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: intent.url) ?? []
            where conflicts.versions.contains(version) {
                version.isResolved = true
                try? version.remove()
            }
        }
    }

    func writeRemote(_ doc: LibraryDocument) async throws {
        guard let url = documentURL else { return }
        try await Self.write(try LibrarySync.encode(doc), to: url)
    }

    nonisolated private static func write(_ data: Data, to url: URL) async throws {
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
