import DoughmetryCore
import SwiftUI

/// 계산기·변환기의 레시피 불러오기 — 검색, 최근·전체(가나다순) 묶음은 RecipePicker (웹 RecipePicker와 같은 규칙).
/// top은 목록 맨 위의 행 (변환기의 '계산기 배합 가져오기'). 좁은 창은 시트, 넓은 창은 버튼에 붙은 팝오버로 띄운다
struct RecipePickerSheet<Top: View>: View {
    /// 고른 순간에 묻는다 — 참이면 확인한 뒤에만 onPick (계산기에 저장하지 않은 입력이 있을 때)
    var needsConfirmation: () -> Bool = { false }
    let onPick: (Recipe) -> Void
    @ViewBuilder var top: () -> Top

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    /// 확인을 기다리는 레시피
    @State private var pendingLoad: Recipe?

    var body: some View {
        let sections = RecipePicker.sections(model.recipes, query: search)
        NavigationStack {
            List {
                top()
                ForEach(sections, id: \.kind) { section in
                    if section.kind == .results && section.recipes.isEmpty {
                        noResults
                    } else if !section.recipes.isEmpty {
                        Section {
                            ForEach(section.recipes) { recipe in
                                row(recipe)
                            }
                        } header: {
                            Text(title(section.kind))
                        }
                        .textCase(nil)
                    }
                }
            }
            .accessibilityIdentifier("recipePicker.list")
            .searchable(
                text: $search, placement: .navigationBarDrawer(displayMode: .always),
                prompt: L("이름·태그 검색"))
            // 행이 아니라 목록에 단다 — 행은 검색어가 바뀌면 사라져 확인창을 잃는다
            .confirmationDialog(
                L("레시피를 불러올까요? 저장하지 않은 입력은 지워집니다."),
                isPresented: Binding(
                    get: { pendingLoad != nil }, set: { if !$0 { pendingLoad = nil } }),
                titleVisibility: .visible,
                presenting: pendingLoad
            ) { recipe in
                Button(L("불러오기"), role: .destructive) { load(recipe) }
                    .accessibilityIdentifier("recipePicker.confirmLoad")
                Button(L("취소"), role: .cancel) {}
            }
            .navigationTitle(L("레시피 불러오기"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) { dismiss() }
                        .accessibilityIdentifier("recipePicker.cancel")
                }
            }
        }
        .adaptiveDetents([.large])
    }

    private func row(_ recipe: Recipe) -> some View {
        // 탭 영역은 라벨 안에서 넓힌다 — .plain 버튼 바깥의 contentShape는 글자 밖 탭을 받지 못한다
        Button {
            if needsConfirmation() {
                pendingLoad = recipe
            } else {
                load(recipe)
            }
        } label: {
            RecipeRow(recipe: recipe, precision: model.precision)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recipePicker.row")
    }

    private func load(_ recipe: Recipe) {
        onPick(recipe)
        dismiss()
    }

    private func title(_ kind: RecipePicker.Kind) -> String {
        switch kind {
        case .recent: L("최근")
        case .all: L("전체 (가나다순)")
        case .saved: L("저장된 레시피")
        case .results: L("검색 결과")
        }
    }

    /// 시스템 .search는 앱 언어가 아니라 번들 현지화를 따른다 — 레시피 탭의 빈 검색 결과와 같은 문구로
    private var noResults: some View {
        ContentUnavailableView(
            LF("'%@'에 대한 결과 없음", search.trimmingCharacters(in: .whitespacesAndNewlines)),
            systemImage: "magnifyingglass",
            description: Text(L("철자를 확인하거나 다른 검색어로 찾아보세요.")))
            .listRowBackground(Color.clear)
    }
}

extension RecipePickerSheet where Top == EmptyView {
    init(needsConfirmation: @escaping () -> Bool = { false }, onPick: @escaping (Recipe) -> Void) {
        self.init(needsConfirmation: needsConfirmation, onPick: onPick, top: { EmptyView() })
    }
}
