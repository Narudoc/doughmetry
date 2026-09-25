import SwiftUI

@main
struct LevainCalcApp: App {
    @State private var model = AppModel()

    init() {
        TimelineNotifier.presentInForeground()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(.bottle)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.requestSync() }
        }
        // L()은 문자열만 바꾼다 — DatePicker와 환경 로캘을 읽는 서식도 앱 언어를 따르게
        .environment(\.locale, Lang.shared.current.locale)
    }
}
