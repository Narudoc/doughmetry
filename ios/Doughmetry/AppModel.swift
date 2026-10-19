import Foundation
import DoughmetryCore
import Observation

/// 계산기 입력 모드
enum CalcMode: String, Codable {
    case a // 재료 입력
    case b // 목표 역산
}

/// 모드 B 입력 폼 — % 단위로 보관, 계산 시 소수로 변환 (src/state.ts 이식)
struct TargetForm: Codable, Equatable {
    var byPieces = false
    var doughWeight: Double = 1740
    var pieces: Double = 2
    var pieceWeight: Double = 870
    var hydrationPct: Double = 72
    var saltPct: Double = 2
    var pffPct: Double = 10
    var levainHydrationPct: Double = 100

    var spec: TargetSpec {
        TargetSpec(
            doughWeight: byPieces ? pieces * pieceWeight : doughWeight,
            hydration: hydrationPct / 100,
            saltRatio: saltPct / 100,
            pff: pffPct / 100,
            levainHydration: levainHydrationPct / 100)
    }
}

struct CalcState: Codable, Equatable {
    var mode: CalcMode = .a
    var name = L("캉파뉴")
    /// 저장된 레시피에서 불러온 경우 — 덮어쓰기 저장에 사용
    var recipeId: String?
    var input: DoughInput = defaultDoughInput()
    var target = TargetForm()
    /// 모드 A의 분할 개수 (0 = 사용 안 함)
    var pieces: Double = 0

    /// 새 배합용 빈 입력
    static func emptyDoughInput() -> DoughInput {
        DoughInput(
            flours: [Flour(name: "", grams: 0)],
            water: 0,
            salt: 0,
            levain: Levain(type: .liquide, hydration: 1, grams: 0))
    }

    static func defaultDoughInput() -> DoughInput {
        DoughInput(
            flours: [Flour(name: "T65", grams: 900)],
            water: 620,
            salt: 20,
            levain: Levain(type: .liquide, hydration: 1, grams: 200))
    }

    /// 현재 배합 — 모드 A는 그대로, 모드 B는 역산 결과
    var currentDough: DoughInput {
        mode == .a ? input : solveFromTarget(target.spec)
    }

    var currentPieces: Double? {
        if mode == .a { return pieces > 0 ? pieces : nil }
        return target.byPieces && target.pieces > 0 ? target.pieces : nil
    }
}

private func defaultDoughInput() -> DoughInput { CalcState.defaultDoughInput() }

@Observable @MainActor
final class AppModel {
    var calc = CalcState() {
        didSet { scheduleDraftSave() }
    }
    /// 마지막으로 불러오거나 새로 시작하거나 저장한 계산기 상태
    private var calcBaseline: CalcState?
    var recipes: [Recipe] = [] {
        didSet { if !isLoading { scheduleLibrarySave() } }
    }
    /// 베이킹 로그 — 레시피별 구운 기록
    var logs: [BakeLog] = [] {
        didSet {
            bakeSummaryCache = nil
            if !isLoading { scheduleLibrarySave() }
        }
    }
    /// 레시피별 굽기 요약 — 목록 행마다 전체 로그를 거르고 정렬하지 않도록 로그가 바뀔 때 한 번만 모은다
    @ObservationIgnored private var bakeSummaryCache: [String: BakeSummary]?
    /// 삭제 묘비 — iCloud 병합에서 삭제를 전파하기 위해 유지
    var tombstones: [Tombstone] = [] {
        didSet { if !isLoading { scheduleLibrarySave() } }
    }
    var precision: Precision = .tenth {
        didSet { UserDefaults.standard.set(precision.rawValue, forKey: "precision") }
    }
    var pctBasis: PctBasis = .totalFlour {
        didSet { UserDefaults.standard.set(pctBasis.rawValue, forKey: "pctBasis") }
    }
    /// 변환기로 보낸 배합 (탭 전환 시 적용)
    var converterSource: (name: String, input: DoughInput)?
    var selectedTab: Tab = .calculator
    /// 레시피 검색 요청 (하드웨어 키보드 ⌘F) — 올릴 때마다 레시피 탭이 검색 칸을 연다
    var searchRequest = 0

    let cloud = CloudSync()
    /// 마지막 library.json 쓰기가 실패했는가 — 다음 쓰기가 성공하면 false로 돌아간다
    /// (변이마다 문서 전체를 다시 쓰므로 재시도는 따로 없다)
    private(set) var libraryWriteFailed = false

    enum Tab: Hashable {
        case calculator, converter, recipes, tools
    }

    // MARK: 저장 위치 — Application Support/levain-calc/
    //   library.json : 레시피 + 로그 + 묘비 (LibraryStore — LibraryDocument, iCloud 사본과 같은 형식)
    //   draft.json   : 계산기 작성 중 상태
    //   recipes.json : 옛 형식(레시피 배열) — 최초 실행 시 LibraryStore가 library.json으로 이전

    nonisolated private static var dir: URL {
        #if DEBUG
        if let dir = uiTestDataDir { return dir }
        #endif
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("levain-calc", isDirectory: true)
    }
    nonisolated private static var draftURL: URL { dir.appendingPathComponent("draft.json") }

    #if DEBUG
    /// UI 테스트 격리 — 실행 인자 `-uiTestDataDir <경로>`(인자 도메인)로 저장 위치를 바꾸고 iCloud를 켜지 않는다.
    /// 상대 경로는 앱 임시 폴더 아래로 (실기기 샌드박스에서도 쓸 수 있게)
    nonisolated private static var uiTestDataDir: URL? {
        guard let path = UserDefaults.standard.string(forKey: "uiTestDataDir"), !path.isEmpty else { return nil }
        return path.hasPrefix("/")
            ? URL(fileURLWithPath: path, isDirectory: true)
            : FileManager.default.temporaryDirectory.appendingPathComponent(path, isDirectory: true)
    }

    /// UI 테스트 실행은 설정(% 기준·앱 언어·타임라인 계획·@AppStorage)도 빈 상태로 시작한다.
    /// UserDefaults.standard의 쓰기는 늘 앱 영속 도메인으로 가므로 도메인을 통째로 바꿔 끼운다 — 실제 설정은
    /// 첫 UI 테스트 실행 때 따로 보관했다가 훅 없이 실행할 때 되돌린다 (테스트가 쓴 설정은 버린다).
    /// 실행 인자(-uiTestDataDir·-appLanguage)는 인자 도메인이라 지워지지 않는다.
    /// 설정을 읽는 무엇보다 먼저 불러야 한다 — 앱 언어(Lang)는 AppModel보다 먼저 DoughmetryApp.init에서 만들어진다.
    /// 여러 번 불러도 결과가 같다.
    nonisolated static func isolateDefaultsForUITest() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        let defaults = UserDefaults.standard
        let savedName = id + ".uitest-saved"
        // 지운 도메인도 iOS 버전에 따라 nil이 아니라 빈 사전으로 읽힌다 — 보관 여부는 "domain" 키로 본다
        let saved = defaults.persistentDomain(forName: savedName)?["domain"] as? [String: Any]
        if uiTestDataDir != nil {
            // 보관본이 있으면 지금 도메인은 앞 테스트 실행의 것이다 — 보관본을 덮어쓰지 않는다
            if saved == nil {
                defaults.setPersistentDomain(
                    ["domain": defaults.persistentDomain(forName: id) ?? [:]], forName: savedName)
                guard defaults.persistentDomain(forName: savedName)?["domain"] != nil else { return }
            }
            defaults.removePersistentDomain(forName: id)
        } else if let saved {
            defaults.setPersistentDomain(saved, forName: id)
            defaults.removePersistentDomain(forName: savedName)
        }
    }
    #endif

    private var store: LibraryStore
    /// 라이브러리 쓰기(인코딩 포함)는 메인 액터 밖 이 직렬 큐에서 한다. 큐에 넣는 것은 메인 액터에서 await 전에
    /// 동기적으로 하므로 변이 순서대로 쓰인다 — 낡은 스냅샷이 새것 뒤에 쓰이지 않는다 (apply()의 취소가 기대는 보장)
    nonisolated private static let libraryWriteQueue = DispatchQueue(label: "library-write", qos: .utility)

    private var draftSaveTask: Task<Void, Never>?
    private var librarySaveTask: Task<Void, Never>?
    private var isLoading = false

    init() {
        #if DEBUG
        Self.isolateDefaultsForUITest()
        #endif
        store = LibraryStore(directory: Self.dir)
        if let raw = UserDefaults.standard.object(forKey: "precision") as? Double,
            let p = Precision(rawValue: raw)
        {
            precision = p
        }
        if let raw = UserDefaults.standard.string(forKey: "pctBasis"),
            let b = PctBasis(rawValue: raw)
        {
            pctBasis = b
        }
        load()
        Task { await startCloud() }
    }

    var document: LibraryDocument {
        LibraryDocument(recipes: recipes, logs: logs, deleted: tombstones)
    }

    private func apply(_ doc: LibraryDocument) {
        // 대기 중인 디바운스 저장이 옛 스냅샷으로 이 결과를 덮어쓰지 않도록 취소
        librarySaveTask?.cancel()
        isLoading = true
        recipes = doc.recipes
        logs = doc.logs
        tombstones = doc.deleted
        isLoading = false
    }

    private func load() {
        // 손상 파일·버려진 항목의 원본 보관과 옛 형식 이전은 LibraryStore가 한다 (삭제 금지)
        let result = store.load()
        Self.logLoad(result)
        apply(result.document)
        // 치우지 못한 손상 파일이 있으면 저장소가 쓰기를 거절한다 — 첫 편집 전부터 저장 실패를 알린다
        libraryWriteFailed = store.isWriteBlocked || result.migrationWriteError != nil
        if let data = try? Data(contentsOf: Self.draftURL),
            let draft = try? JSONDecoder().decode(CalcState.self, from: data)
        {
            // 복원한 draft는 기준으로 삼지 않는다 — 저장된 레시피와 같을 때만 calcIsDirty가 false.
            // 손대지 않은 예시·빈 배합은 예외 (새 배합 확인창이 지워질 입력이 없는데 경고하지 않게)
            calc = draft
            if Self.isUntouchedStart(draft) { calcBaseline = draft }
        } else {
            calcBaseline = calc
        }
    }

    private static func logLoad(_ r: LibraryStore.LoadResult) {
        if let aside = r.corruptSetAside {
            Log.storage.error("library.json was not JSON — set aside as \(aside.lastPathComponent, privacy: .public)")
        }
        if let error = r.corruptSetAsideError {
            Log.storage.error(
                "could not set aside the corrupt library.json (\(errorCode(error), privacy: .public)) — local writes blocked")
        }
        if r.droppedItemCount > 0 {
            let kept = r.droppedOriginalKept?.lastPathComponent ?? (r.droppedOriginalError == nil ? "an earlier copy" : "none")
            Log.storage.error("\(r.droppedItemCount) invalid items dropped on load — original kept as \(kept, privacy: .public)")
        }
        if let error = r.droppedOriginalError {
            Log.storage.error("keeping the original with dropped items failed: \(errorCode(error), privacy: .public)")
        }
        if r.migratedLegacy {
            Log.storage.notice("migrated legacy recipes.json: \(r.document.recipes.count) recipes")
        }
        if let error = r.migrationWriteError {
            Log.storage.error("writing migrated library.json failed: \(errorCode(error), privacy: .public)")
        }
    }

    private func scheduleDraftSave() {
        draftSaveTask?.cancel()
        draftSaveTask = Task { [calc] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            Self.write(calc, to: Self.draftURL)
        }
    }

    private func scheduleLibrarySave() {
        librarySaveTask?.cancel()
        librarySaveTask = Task { [document] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            libraryWriteFailed = !(await persistLibrary(document))
            requestSync()
        }
    }

    /// 성공 여부를 돌려준다 — 실패해도 앱 동작은 계속하되 libraryWriteFailed로 사용자에게 알린다.
    /// 오류의 localizedDescription은 앱 언어가 아니라 실행 시점의 기기 언어로 나오므로 화면에 쓰지 않는다
    private func persistLibrary(_ doc: LibraryDocument) async -> Bool {
        let store = store
        return await withCheckedContinuation { continuation in
            Self.libraryWriteQueue.async {
                continuation.resume(returning: Self.writeLibrary(doc, with: store))
            }
        }
    }

    nonisolated private static func writeLibrary(_ doc: LibraryDocument, with store: LibraryStore) -> Bool {
        do {
            try store.write(doc)
            return true
        } catch {
            Log.storage.error("writing library.json failed: \(errorCode(error), privacy: .public)")
            return false
        }
    }

    private static func write(_ value: some Encodable, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            // 저장 실패 시에도 앱 동작은 계속 (웹의 saveJson과 동일한 태도)
            Log.storage.error("writing \(url.lastPathComponent, privacy: .public) failed: \(errorCode(error), privacy: .public)")
        }
    }

    // MARK: iCloud 동기화

    private var syncInFlight = false
    private var syncRequested = false

    private func startCloud() async {
        #if DEBUG
        // UI 테스트 실행은 iCloud(개발 컨테이너)와 절대 합치지 않는다 — 시뮬레이터가 iCloud에 로그인돼 있어도
        if Self.uiTestDataDir != nil {
            cloud.status = .unavailable
            return
        }
        #endif
        await cloud.prepare()
        guard cloud.isAvailable else { return }
        cloud.onEnabled = { [weak self] in self?.requestSync() }
        // 첫 동기화는 메타데이터 수집(DidFinishGathering)이 끝난 뒤 콜백으로 시작한다 —
        // 그 전엔 iCloud에 문서가 있는지 알 수 없어 빈 로컬로 덮어쓸 위험이 있다
        cloud.startObserving { [weak self] in self?.requestSync() }
    }

    /// 동기화 요청 — 진행 중이면 끝난 뒤 한 번 더 돈다 (병합은 결정적이라 반복해도 안전)
    func requestSync() {
        guard cloud.enabled, cloud.isAvailable, cloud.hasGathered else { return }
        if syncInFlight {
            syncRequested = true
            return
        }
        Task { await runSync() }
    }

    private func runSync() async {
        syncInFlight = true
        defer {
            syncInFlight = false
            if syncRequested {
                syncRequested = false
                requestSync()
            }
        }
        cloud.status = .syncing
        do {
            let remote = try await cloud.readRemote()
            cloud.keptConflictCount = remote?.snapshot.keptConflictCount ?? 0
            // 여기서부터 apply까지는 await 없이 메인 액터에서 한 번에 — 그 사이 사용자 편집이 끼어들 수 없다.
            // 무엇을 할지는 LibrarySync.plan이 정한다 (정규화한 로컬 + 현재 판 + 충돌 판을 한 번에 병합)
            let local = document
            let plan = LibrarySync.plan(local: local, remote: remote?.snapshot)
            // 새 버전 앱이 쓴 문서는 합치지도 쓰지도 않는다
            if plan.abortNewerFormat {
                Log.sync.notice("sync stopped: a newer app wrote the iCloud library")
                cloud.fail(L("새 버전 앱에서 저장한 데이터가 있습니다 — 이 기기의 앱을 업데이트하면 동기화됩니다"))
                return
            }
            var localWriteFailed = false
            if plan.applyLocally {
                apply(plan.merged)
                let written = await persistLibrary(plan.merged)
                libraryWriteFailed = !written
                localWriteFailed = !written
            }
            // 원격 쓰기 전에 남긴다 — 쓰기가 실패하면 catch에는 오류 코드만 남는다
            Log.sync.notice(
                """
                sync plan: local \(local.logSummary, privacy: .public) remote \(remote?.snapshot.current.logSummary ?? "none", privacy: .public) \
                conflicts \(remote?.snapshot.conflicts.count ?? 0) merged \(plan.merged.logSummary, privacy: .public) \
                apply=\(plan.applyLocally) write=\(plan.writeRemote) resolve=\(plan.resolveConflictsAfterWrite) \
                kept=\(remote?.snapshot.keptConflictCount ?? 0) localWriteFailed=\(localWriteFailed)
                """)
            // 원격에 문서가 없고 로컬도 비었으면 아무것도 쓰지 않는다 (새 기기 보호).
            // 비교는 iCloud 현재 판과 한다 — 충돌 판에서 합친 내용도 현재 판에 써야 반영된다
            if plan.writeRemote {
                try await cloud.writeRemote(plan.merged)
            }
            // 충돌 판은 그 내용이 현재 판에 들어간 뒤에만 정리한다 (쓰기가 실패하면 위에서 catch로 빠진다)
            if plan.resolveConflictsAfterWrite, let remote {
                await cloud.resolveConflicts(remote.resolvable)
            }
            if localWriteFailed {
                cloud.fail(L("기기에 저장하지 못했습니다 — 저장 공간을 확인하세요"))
            } else {
                Log.sync.notice("synced")
                cloud.markSynced()
            }
        } catch CloudSync.SyncError.notDownloaded {
            Log.sync.notice("sync deferred: library.json not downloaded yet")
            cloud.forgetRemoteState()
            cloud.fail(L("iCloud에서 라이브러리를 내려받는 중입니다 — 끝나면 동기화합니다"))
        } catch CloudSync.SyncError.downloadFailed {
            Log.sync.notice("sync deferred: iCloud reported a download error")
            cloud.forgetRemoteState()
            cloud.fail(L("iCloud에서 라이브러리를 내려받지 못했습니다 — 네트워크와 iCloud 저장 공간을 확인하세요. 다시 시도합니다"))
        } catch CloudSync.SyncError.timedOut {
            Log.sync.notice("sync deferred: coordinated access timed out")
            cloud.forgetRemoteState()
            cloud.fail(L("iCloud에 연결하지 못해 동기화를 미뤘습니다 — 연결되면 다시 시도합니다"))
        } catch {
            let code = errorCode(error)
            Log.sync.error("sync failed: \(code, privacy: .public)")
            cloud.forgetRemoteState()
            // localizedDescription은 앱 언어가 아니라 기기 언어로 나온다 — 도메인·코드는 문의할 때 원인을 알려 준다
            cloud.fail(LF("동기화하지 못했습니다 (%@) — 다음에 다시 시도합니다", code))
        }
    }

    // MARK: 레시피 CRUD

    /// touch: false면 updatedAt을 그대로 둔다 (백업 가져오기 — 받을지는 LibrarySync.importable이 정한다).
    /// 단 묘비가 있는 id는 묘비 뒤로 민다 — 지운 레시피의 복원은 편집이고, 그러지 않으면
    /// iCloud에 남은 같은 묘비에 다음 병합에서 다시 지워진다. 내용이 그대로면 아무것도 하지 않는다.
    func save(_ recipe: Recipe, touch: Bool = true) {
        let idx = recipes.firstIndex { $0.id == recipe.id }
        guard
            let updated = LibrarySync.savedRecipe(
                recipe, replacing: idx.map { recipes[$0] },
                tombstone: tombstones.first { $0.id == recipe.id }, touch: touch)
        else { return }
        tombstones.removeAll { $0.id == recipe.id }
        if let idx {
            recipes[idx] = updated
        } else {
            recipes.insert(updated, at: 0)
        }
    }

    func updateNote(recipeId: String, note: String?) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipeId }),
            let updated = LibrarySync.notedRecipe(recipes[idx], note: note)
        else { return }
        recipes[idx] = updated
    }

    func delete(_ id: String) {
        delete(ids: [id])
    }

    /// 여러 건 삭제 — 한 번의 변이로 처리 (필터된 목록 인덱스가 밀리는 것을 방지)
    func delete(ids: Set<String>) {
        // 묘비는 항목 updatedAt보다 늦은 시각으로 (기기 시계 차이 방어).
        // 소속 로그는 묘비 없이 지운다 — 레시피가 '삭제 뒤 편집'으로 되살아나면 로그도 돌아오고,
        // 아니면 병합의 고아 로그 필터가 걸러 준다.
        let now = Date()
        let victims = recipes.filter { ids.contains($0.id) }
        recipes.removeAll { ids.contains($0.id) }
        logs.removeAll { ids.contains($0.recipeId) }
        tombstones.append(contentsOf: victims.map {
            Tombstone(id: $0.id, deletedAt: LibrarySync.tombstoneTime(for: $0.updatedAt, now: now))
        })
    }

    // MARK: 베이킹 로그

    struct BakeSummary {
        let count: Int
        let latestBakedAt: String
    }

    /// 목록 행용 굽기 요약 (횟수·최근 날짜)
    func bakeSummary(for recipeId: String) -> BakeSummary? {
        let logs = self.logs  // 관찰 등록 — 로그가 바뀌면 행이 다시 그려진다
        if bakeSummaryCache == nil {
            var acc: [String: (count: Int, latest: BakeLog, date: Date)] = [:]
            for log in logs {
                let date = LibrarySync.syncInstant(log.bakedAt) ?? .distantPast
                if let cur = acc[log.recipeId] {
                    acc[log.recipeId] = (cur.count + 1, date > cur.date ? log : cur.latest, max(date, cur.date))
                } else {
                    acc[log.recipeId] = (1, log, date)
                }
            }
            bakeSummaryCache = acc.mapValues { BakeSummary(count: $0.count, latestBakedAt: $0.latest.bakedAt) }
        }
        return bakeSummaryCache?[recipeId]
    }

    func logs(for recipeId: String) -> [BakeLog] {
        logs.filter { $0.recipeId == recipeId }
            .map { ($0, LibrarySync.syncInstant($0.bakedAt) ?? .distantPast) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    func saveLog(_ log: BakeLog) {
        let idx = logs.firstIndex { $0.id == log.id }
        guard
            let updated = LibrarySync.savedLog(
                log, replacing: idx.map { logs[$0] }, tombstone: tombstones.first { $0.id == log.id })
        else { return }
        tombstones.removeAll { $0.id == log.id }
        if let idx {
            logs[idx] = updated
        } else {
            logs.append(updated)
        }
    }

    func deleteLog(_ id: String) {
        guard let log = logs.first(where: { $0.id == id }) else { return }
        logs.removeAll { $0.id == id }
        tombstones.append(
            Tombstone(id: id, deletedAt: LibrarySync.tombstoneTime(for: log.updatedAt)))
    }

    // MARK: 계산기 연동

    /// 계산기에 저장하지 않은 입력이 있는가 — 불러오기가 덮어쓰기 전에 확인한다
    var calcIsDirty: Bool {
        guard calc != calcBaseline else { return false }
        // 연결된 레시피와 내용이 같으면 저장된 것 (앱 재실행으로 복원한 draft, 동기화 뒤 포함).
        // 레시피엔 목표 역산 입력이 없다 — 불러오기는 target을 기본값으로 두므로 다르면 불러온 뒤 고친 것
        guard calc.mode == .a, calc.target == (calcBaseline?.target ?? TargetForm()),
            let id = calc.recipeId,
            let r = recipes.first(where: { $0.id == id })
        else { return true }
        return !(r.name == calc.name && r.doughInput == calc.input && (r.pieces ?? 0) == calc.pieces)
    }

    /// 새로 시작한 그대로인가 — 레시피 연결 없이 이름·목표 역산 입력·배합이 예시 또는 빈 배합과 같다 (생성 id는 무시).
    /// 앱 언어가 바뀌어 예시 이름이 달라졌으면 고친 것으로 본다 (경고가 나는 쪽이 안전)
    private static func isUntouchedStart(_ state: CalcState) -> Bool {
        guard state.recipeId == nil, state.mode == .a, state.pieces == 0, state.target == TargetForm()
        else { return false }
        let input = withoutIds(state.input)
        return (state.name == L("캉파뉴") && input == withoutIds(CalcState.defaultDoughInput()))
            || (state.name.isEmpty && input == withoutIds(CalcState.emptyDoughInput()))
    }

    private static func withoutIds(_ input: DoughInput) -> DoughInput {
        var copy = input
        for i in copy.flours.indices { copy.flours[i].id = "" }
        for i in copy.liquids.indices { copy.liquids[i].id = "" }
        for i in copy.extras.indices { copy.extras[i].id = "" }
        return copy
    }

    /// 계산기 내용을 레시피로 저장한 직후 호출 — 이후 바뀐 것만 '저장하지 않은 입력'이 된다.
    /// 모드 B 저장은 역산 결과만 남긴다 — 숨은 모드 A 입력이 마지막 기준과 다르면 그 입력은 여전히 저장되지 않은 것
    func markCalcSaved() {
        if calc.mode == .b {
            // 다시 띄워 복원한 draft엔 기준이 없다 — calcIsDirty처럼 연결된 레시피를 기준으로 본다.
            // 분할 개수도 모드 B에선 숨은 모드 A 입력이다
            let linked = calc.recipeId.flatMap { id in recipes.first { $0.id == id } }
            let savedInput = calcBaseline?.input ?? linked?.doughInput
            let savedPieces = calcBaseline?.pieces ?? linked.map { $0.pieces ?? 0 }
            if calc.input != savedInput || calc.pieces != savedPieces { return }
        }
        calcBaseline = calc
    }

    func loadIntoCalculator(_ recipe: Recipe) {
        calc = CalcState(
            mode: .a,
            name: recipe.name,
            recipeId: recipe.id,
            input: recipe.doughInput,
            pieces: recipe.pieces ?? 0)
        calcBaseline = calc
        selectedTab = .calculator
    }

    /// 계산기 초기화 — 새 배합 시작 (recipeId 연결도 해제)
    func resetCalc(empty: Bool) {
        calc = CalcState(
            mode: .a,
            name: empty ? "" : L("캉파뉴"),
            input: empty ? CalcState.emptyDoughInput() : CalcState.defaultDoughInput())
        calcBaseline = calc
    }

    func sendToConverter(name: String, input: DoughInput) {
        converterSource = (name, input)
        selectedTab = .converter
    }
}
