import Foundation
import LevainCore
import Observation

/// % 표기 기준 — 계산은 항상 총 밀가루 기준이고, 재료 옆 % 표시만 전환한다
enum PctBasis: String, CaseIterable {
    case totalFlour  // 총 밀가루 (프랑스식, 기본)
    case addedFlour  // 첨가 밀가루 = 100% (베이커스 퍼센트)
}

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
    var recipes: [Recipe] = [] {
        didSet { if !isLoading { scheduleLibrarySave() } }
    }
    /// 베이킹 로그 — 레시피별 구운 기록
    var logs: [BakeLog] = [] {
        didSet { if !isLoading { scheduleLibrarySave() } }
    }
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

    let cloud = CloudSync()

    enum Tab: Hashable {
        case calculator, converter, recipes, tools
    }

    // MARK: 저장 위치 — Application Support/levain-calc/
    //   library.json : 레시피 + 로그 + 묘비 (LibraryDocument, iCloud 사본과 같은 형식)
    //   draft.json   : 계산기 작성 중 상태
    //   recipes.json : 옛 형식(레시피 배열) — 최초 실행 시 library.json으로 이전

    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("levain-calc", isDirectory: true)
    }
    private static var libraryURL: URL { dir.appendingPathComponent("library.json") }
    private static var legacyRecipesURL: URL { dir.appendingPathComponent("recipes.json") }
    private static var draftURL: URL { dir.appendingPathComponent("draft.json") }

    private var draftSaveTask: Task<Void, Never>?
    private var librarySaveTask: Task<Void, Never>?
    private var isLoading = false

    init() {
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
        if let data = try? Data(contentsOf: Self.libraryURL) {
            if (try? JSONSerialization.jsonObject(with: data)) == nil {
                // 손상된 파일은 옆으로 치워 두고(삭제 금지) 빈 라이브러리로 시작한다 —
                // 그대로 두면 다음 저장이 사용자 데이터를 영구히 덮어쓴다
                let aside = Self.dir.appendingPathComponent("library.corrupt-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: Self.libraryURL, to: aside)
            } else {
                apply(LibrarySync.decode(data))
            }
        } else if let data = try? Data(contentsOf: Self.legacyRecipesURL) {
            // 옛 형식 이전 — 항목별 검증으로 살릴 수 있는 것은 전부 살린다
            apply(LibrarySync.decode(data))
            Self.writeLibrary(document)
        }
        if let data = try? Data(contentsOf: Self.draftURL),
            let draft = try? JSONDecoder().decode(CalcState.self, from: data)
        {
            calc = draft
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
            Self.writeLibrary(document)
            requestSync()
        }
    }

    private static func writeLibrary(_ doc: LibraryDocument) {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try LibrarySync.encode(doc).write(to: libraryURL, options: .atomic)
        } catch {
            // 저장 실패 시에도 앱 동작은 계속
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
        }
    }

    // MARK: iCloud 동기화

    private var syncInFlight = false
    private var syncRequested = false

    private func startCloud() async {
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
            // 여기서부터 apply까지는 await 없이 메인 액터에서 한 번에 — 그 사이 사용자 편집이 끼어들 수 없다.
            // 로컬은 정규화(코덱 왕복 + 정규 순서)해 원격과 같은 형태로 비교한다.
            let local = LibrarySync.normalized(document)
            let merged = LibrarySync.merge(local: local, remote: remote ?? LibraryDocument())
            if merged != local {
                apply(merged)
                Self.writeLibrary(merged)
            }
            // 원격에 문서가 없고 로컬도 비었으면 아무것도 쓰지 않는다 (새 기기 보호)
            let shouldWrite = remote.map { merged != $0 } ?? !merged.isEmpty
            if shouldWrite {
                try await cloud.writeRemote(merged)
            }
            cloud.markSynced()
        } catch {
            cloud.status = .error(error.localizedDescription)
        }
    }

    // MARK: 레시피 CRUD

    /// touch: false면 updatedAt을 그대로 둔다 (백업 가져오기 — 다른 기기의 더 새 편집을 덮지 않도록)
    func save(_ recipe: Recipe, touch: Bool = true) {
        var updated = recipe
        if touch { updated.updatedAt = isoNow() }
        tombstones.removeAll { $0.id == recipe.id }
        if let idx = recipes.firstIndex(where: { $0.id == recipe.id }) {
            updated.createdAt = recipes[idx].createdAt
            recipes[idx] = updated
        } else {
            recipes.insert(updated, at: 0)
        }
    }

    func updateNote(recipeId: String, note: String?) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipeId }) else { return }
        recipes[idx].note = (note?.isEmpty ?? true) ? nil : note
        recipes[idx].updatedAt = isoNow()
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

    func logs(for recipeId: String) -> [BakeLog] {
        logs.filter { $0.recipeId == recipeId }
            .map { ($0, parseISO($0.bakedAt) ?? .distantPast) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    func saveLog(_ log: BakeLog) {
        var updated = log
        updated.updatedAt = isoNow()
        tombstones.removeAll { $0.id == log.id }
        if let idx = logs.firstIndex(where: { $0.id == log.id }) {
            updated.createdAt = logs[idx].createdAt
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

    func loadIntoCalculator(_ recipe: Recipe) {
        calc = CalcState(
            mode: .a,
            name: recipe.name,
            recipeId: recipe.id,
            input: recipe.doughInput,
            pieces: recipe.pieces ?? 0)
        selectedTab = .calculator
    }

    /// 계산기 초기화 — 새 배합 시작 (recipeId 연결도 해제)
    func resetCalc(empty: Bool) {
        calc = CalcState(
            mode: .a,
            name: empty ? "" : L("캉파뉴"),
            input: empty ? CalcState.emptyDoughInput() : CalcState.defaultDoughInput())
    }

    func sendToConverter(name: String, input: DoughInput) {
        converterSource = (name, input)
        selectedTab = .converter
    }
}
