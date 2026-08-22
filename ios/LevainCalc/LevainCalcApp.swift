import SwiftUI

@main
struct LevainCalcApp: App {
    @State private var model = AppModel()

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
        }
    }
}
