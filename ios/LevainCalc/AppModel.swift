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
    /// 마지막으로 불러오거나 새로 시작하거나 저장한 계산기 상태
    private var calcBaseline: CalcState?
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
    /// 마지막 library.json 쓰기가 실패했는가 — 다음 쓰기가 성공하면 false로 돌아간다
    /// (변이마다 문서 전체를 다시 쓰므로 재시도는 따로 없다)
    private(set) var libraryWriteFailed = false

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
                let doc = LibrarySync.decode(data)
                if LibrarySync.droppedItemCount(in: data, decoded: doc) > 0 {
                    Self.keepDroppedOriginal(data)
                }
                apply(doc)
            }
        } else if let data = try? Data(contentsOf: Self.legacyRecipesURL) {
            // 옛 형식 이전 — 항목별 검증으로 살릴 수 있는 것은 전부 살린다
            apply(LibrarySync.decode(data))
            libraryWriteFailed = !Self.writeLibrary(document)
        }
        if let data = try? Data(contentsOf: Self.draftURL),
            let draft = try? JSONDecoder().decode(CalcState.self, from: data)
        {
            // 복원한 draft는 기준으로 삼지 않는다 — 저장된 레시피와 같을 때만 calcIsDirty가 false
            calc = draft
        } else {
            calcBaseline = calc
        }
    }

    /// 검증에 실패해 버려진 항목이 든 원본을 옆에 복사해 둔다 (삭제 금지, 같은 내용은 한 번만) —
    /// 다음 저장이 library.json을 덮어쓰면 그 항목은 되찾을 길이 없다
    private static func keepDroppedOriginal(_ data: Data) {
        let fm = FileManager.default
        let existing = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let alreadyKept = existing.contains {
            $0.lastPathComponent.hasPrefix("library.dropped-") && (try? Data(contentsOf: $0)) == data
        }
        guard !alreadyKept else { return }
        let aside = dir.appendingPathComponent("library.dropped-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: aside, options: .atomic)
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
            libraryWriteFailed = !Self.writeLibrary(document)
            requestSync()
        }
    }

    /// 성공 여부를 돌려준다 — 실패해도 앱 동작은 계속하되 libraryWriteFailed로 사용자에게 알린다.
    /// 오류의 localizedDescription은 앱 언어가 아니라 실행 시점의 기기 언어로 나오므로 화면에 쓰지 않는다
    private static func writeLibrary(_ doc: LibraryDocument) -> Bool {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try LibrarySync.encode(doc).write(to: libraryURL, options: .atomic)
            return true
        } catch {
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
            // 새 버전 앱이 쓴 문서는 합치지도 쓰지도 않는다 — 모르는 필드를 뺀 사본이 원격과 같은 updatedAt으로
            // 로컬에 남으면, 업데이트 뒤 병합 동률에서 그 사본이 이겨 원격의 필드를 지운다
            if remote?.isNewerFormat == true {
                cloud.status = .error(L("새 버전 앱에서 저장한 데이터가 있습니다 — 이 기기의 앱을 업데이트하면 동기화됩니다"))
                return
            }
            // 여기서부터 apply까지는 await 없이 메인 액터에서 한 번에 — 그 사이 사용자 편집이 끼어들 수 없다.
            // 로컬은 정규화(코덱 왕복 + 정규 순서)해 원격과 같은 형태로 비교한다.
            let local = LibrarySync.normalized(document)
            let merged = LibrarySync.merge(local: local, remote: remote?.document ?? LibraryDocument())
            var localWriteFailed = false
            if merged != local {
                apply(merged)
                libraryWriteFailed = !Self.writeLibrary(merged)
                localWriteFailed = libraryWriteFailed
            }
            // 원격에 문서가 없고 로컬도 비었으면 아무것도 쓰지 않는다 (새 기기 보호)
            let shouldWrite = remote.map { merged != $0.document } ?? !merged.isEmpty
            if shouldWrite {
                try await cloud.writeRemote(merged)
            }
            if localWriteFailed {
                cloud.status = .error(L("기기에 저장하지 못했습니다 — 저장 공간을 확인하세요"))
            } else {
                cloud.markSynced()
            }
        } catch {
            // localizedDescription은 앱 언어가 아니라 기기 언어로 나온다
            cloud.status = .error(L("동기화하지 못했습니다 — 다음에 다시 시도합니다"))
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

    func logs(for recipeId: String) -> [BakeLog] {
        logs.filter { $0.recipeId == recipeId }
            .map { ($0, parseISO($0.bakedAt) ?? .distantPast) }
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

    /// 계산기 내용을 레시피로 저장한 직후 호출 — 이후 바뀐 것만 '저장하지 않은 입력'이 된다
    func markCalcSaved() {
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
