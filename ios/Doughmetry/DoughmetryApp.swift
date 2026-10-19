import SwiftUI

@main
struct DoughmetryApp: App {
    /// 앱 전체에 하나 — 선택 탭·검색 요청이 창마다 나뉘지 않으므로 iPad도 창 하나로 묶어 둔다
    /// (Doughmetry-Info.plist의 UIApplicationSupportsMultipleScenes false)
    @State private var model = AppModel()

    init() {
        #if DEBUG
        // Lang(앱 언어)이 저장값을 읽기 전에 — @State의 AppModel은 이 init보다 늦게 만들어진다
        AppModel.isolateDefaultsForUITest()
        #endif
        TimelineNotifier.presentInForeground()
        WaterTemperatureView.migrateFrictionPresets()
        if #unavailable(iOS 26) {
            // 26 미만의 confirmationDialog는 UIAlertController라 SwiftUI .tint를 따르지 않는다 (삭제 역할은 시스템 빨강 그대로).
            // UIColor(Color.bottle)은 다크 모드에서도 라이트 값으로 풀린다 — 화면 모드마다 SwiftUI로 직접 푼다
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor { traits in
                var environment = EnvironmentValues()
                environment.colorScheme = traits.userInterfaceStyle == .dark ? .dark : .light
                return UIColor(cgColor: Color.bottle.resolve(in: environment).cgColor)
            }
            KeyboardAvoidance.install()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(.bottle)
        }
        .commands {
            TabCommands(model: model)
        }
    }
}

/// 하드웨어 키보드 단축키 — ⌘1–4 탭 전환, ⌘F 레시피 검색.
/// ⌘N·⌘S는 보이는 탭에서만 듣도록 그 탭의 뷰에 단다.
/// UI 테스트에서 실행 뒤 첫 ⌘F가 앱에 오지 않는 것은 앱 문제가 아니다 — XCUITest의 가상 키보드는 키마다 붙었다 떨어지고,
/// 앱은 키보드가 붙을 때에야 단축키를 시스템에 등록하므로 첫 키는 ⌘F(찾기)를 등록해 둔 SpringBoard가 가져간다.
/// 실행 전부터 키보드가 붙어 있으면 첫 ⌘F도 앱이 받는다
private enum Shortcut: CaseIterable {
    case calculator, converter, recipes, tools, search

    var key: KeyEquivalent {
        switch self {
        case .calculator: "1"
        case .converter: "2"
        case .recipes: "3"
        case .tools: "4"
        case .search: "f"
        }
    }

    var title: String {
        switch self {
        case .calculator: L("계산기")
        case .converter: L("변환")
        case .recipes: L("레시피")
        case .tools: L("도구")
        case .search: L("레시피 검색")
        }
    }

    @MainActor func perform(_ model: AppModel) {
        guard !modalIsPresented() else { return }
        switch self {
        case .calculator: model.selectedTab = .calculator
        case .converter: model.selectedTab = .converter
        case .recipes: model.selectedTab = .recipes
        case .tools: model.selectedTab = .tools
        case .search:
            model.selectedTab = .recipes
            model.searchRequest += 1
        }
    }
}

/// 시트·팝오버·확인 대화상자가 떠 있으면 true — 단축키가 그 아래의 탭을 바꾸거나 떠 있는 시트를 저장 확인 없이 닫지 않게.
/// 레시피 검색(UISearchController)은 모달로 치지 않는다 — 검색 중에도 탭 전환·⌘F가 듣도록
@MainActor func modalIsPresented() -> Bool {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .contains { scene in
            guard let presented = scene.keyWindow?.rootViewController?.presentedViewController else { return false }
            return !(presented is UISearchController)
        }
}

private struct TabCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            ForEach(Shortcut.allCases, id: \.self) { shortcut in
                if shortcut == .search { Divider() }
                Button(shortcut.title) { shortcut.perform(model) }
                    .keyboardShortcut(shortcut.key)
            }
        }
    }
}

/// 26 미만에선 메뉴 명령(TabCommands)이 단축키를 받지 못한다 — iPhone엔 메뉴 명령이 오지 않고,
/// iPad의 ⌘F는 시스템 찾기 명령이 가로챈다. 뷰에 단 단축키는 메뉴 명령보다 먼저 받는다
private struct LegacyShortcuts: View {
    let model: AppModel

    var body: some View {
        ForEach(Shortcut.allCases, id: \.self) { shortcut in
            // 제목을 비워 iPad의 단축키 목록(⌘ 길게 누르기)에 메뉴 명령과 겹쳐 나오지 않게
            Button("") { shortcut.perform(model) }
                .keyboardShortcut(shortcut.key)
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            CalculatorView()
                .tabItem { Label(L("계산기"), systemImage: "scalemass") }
                .tag(AppModel.Tab.calculator)
            ConverterView()
                .tabItem { Label(L("변환"), systemImage: "arrow.left.arrow.right") }
                .tag(AppModel.Tab.converter)
            RecipesView()
                .tabItem { Label(L("레시피"), systemImage: "book.closed") }
                .tag(AppModel.Tab.recipes)
            ToolsView()
                .tabItem { Label(L("도구"), systemImage: "wrench.and.screwdriver") }
                .tag(AppModel.Tab.tools)
        }
        .background {
            if #unavailable(iOS 26) { LegacyShortcuts(model: model) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.requestSync() }
        }
        .environment(\.windowIsRegular, horizontalSizeClass == .regular)
        // L()은 문자열만 바꾼다 — DatePicker와 환경 로캘을 읽는 서식도 앱 언어를 따르게
        .environment(\.locale, Lang.shared.current.locale)
    }
}
