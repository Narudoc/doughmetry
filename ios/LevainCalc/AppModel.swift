import Foundation
import LevainCore
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
    var name = "캉파뉴"
    /// 저장된 레시피에서 불러온 경우 — 덮어쓰기 저장에 사용
    var recipeId: String?
    var input: DoughInput = defaultDoughInput()
    var target = TargetForm()
    /// 모드 A의 분할 개수 (0 = 사용 안 함)
    var pieces: Double = 0

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
        didSet { scheduleRecipesSave() }
    }
    var precision: Precision = .tenth {
        didSet { UserDefaults.standard.set(precision.rawValue, forKey: "precision") }
    }
    /// 변환기로 보낸 배합 (탭 전환 시 적용)
    var converterSource: (name: String, input: DoughInput)?
    var selectedTab: Tab = .calculator

    enum Tab: Hashable {
        case calculator, converter, recipes
    }

    // MARK: 저장 위치 — Application Support/levain-calc/*.json (웹 스키마와 동일한 항목 형식)

    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("levain-calc", isDirectory: true)
    }
    private static var recipesURL: URL { dir.appendingPathComponent("recipes.json") }
    private static var draftURL: URL { dir.appendingPathComponent("draft.json") }

    private var draftSaveTask: Task<Void, Never>?
    private var recipesSaveTask: Task<Void, Never>?

    init() {
        if let raw = UserDefaults.standard.object(forKey: "precision") as? Double,
            let p = Precision(rawValue: raw)
        {
            precision = p
        }
        load()
    }

    private func load() {
        // 레시피: 웹 localStorage 형식과 같은 배열 JSON — 항목별 검증·마이그레이션
        if let data = try? Data(contentsOf: Self.recipesURL),
            let text = String(data: data, encoding: .utf8),
            case .success(let loaded) = RecipeCodec.importJSON(text)
        {
            recipes = loaded
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

    private func scheduleRecipesSave() {
        recipesSaveTask?.cancel()
        recipesSaveTask = Task { [recipes] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            Self.write(recipes, to: Self.recipesURL)
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

    // MARK: 레시피 CRUD

    func save(_ recipe: Recipe) {
        if let idx = recipes.firstIndex(where: { $0.id == recipe.id }) {
            var updated = recipe
            updated.createdAt = recipes[idx].createdAt
            recipes[idx] = updated
        } else {
            recipes.insert(recipe, at: 0)
        }
    }

    func delete(_ id: String) {
        recipes.removeAll { $0.id == id }
    }

    func loadIntoCalculator(_ recipe: Recipe) {
        calc = CalcState(
            mode: .a,
            name: recipe.name,
            recipeId: recipe.id,
            input: recipe.doughInput,
            pieces: recipe.pieces ?? 0)
        selectedTab = .calculator
    }

    func sendToConverter(name: String, input: DoughInput) {
        converterSource = (name, input)
        selectedTab = .converter
    }
}
