import DoughmetryCore
import SwiftUI

/// 레시피 편집 시트에서 고친 칸 — nil인 칸은 손대지 않은 것. 빈 태그·빈 노트는 지운 것
struct RecipeEdit {
    var name: String?
    var tags: [String]?
    var note: String?

    /// 고친 칸만 옮긴다 — 시트를 연 사이 동기화로 바뀐 칸을 연 시점의 값으로 되돌리지 않고,
    /// 손대지 않은 칸의 저장 형태(태그 [] ↔ nil, 노트 끝 공백)도 그대로 두어 아무것도 안 고친 저장은 변이가 되지 않는다
    func applied(to recipe: Recipe) -> Recipe {
        var r = recipe
        if let name { r.name = name }
        if let tags { r.tags = tags.isEmpty ? nil : tags }
        if let note { r.note = note.isEmpty ? nil : note }
        return r
    }
}

/// 레시피 이름·태그·노트 편집 — 같은 레시피(같은 id)를 고친다. 배합은 계산기로 불러와 고친다
struct RecipeEditSheet: View {
    let recipe: Recipe
    let onSave: (RecipeEdit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var tagsText: String
    @State private var note: String
    @State private var showDiscard = false

    // 상태를 init에서 채운다 — onAppear에서 채우면 첫 프레임에 isEdited가 참이 된다
    init(recipe: Recipe, onSave: @escaping (RecipeEdit) -> Void) {
        self.recipe = recipe
        self.onSave = onSave
        _name = State(initialValue: recipe.name)
        _tagsText = State(initialValue: (recipe.tags ?? []).joined(separator: ", "))
        _note = State(initialValue: recipe.note ?? "")
    }

    private var initialTagsText: String { (recipe.tags ?? []).joined(separator: ", ") }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isEdited: Bool {
        name != recipe.name || tagsText != initialTagsText || note != (recipe.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("레시피 이름"), text: $name)
                        .accessibilityLabel(L("레시피 이름"))
                        .accessibilityIdentifier("recipeEdit.name")
                    TextField(L("태그 (쉼표로 구분)"), text: $tagsText)
                        .accessibilityLabel(L("태그 (쉼표로 구분)"))
                        .accessibilityIdentifier("recipeEdit.tags")
                }
                Section {
                    TextEditor(text: $note)
                        .frame(minHeight: 140)
                        .font(.callout)
                        .accessibilityLabel(L("노트"))
                        .accessibilityIdentifier("recipeEdit.note")
                } header: {
                    Text(L("노트"))
                }
                .textCase(nil)
            }
            .navigationTitle(L("레시피 편집"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) {
                        if isEdited { showDiscard = true } else { dismiss() }
                    }
                    .discardConfirmation(isPresented: $showDiscard) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) {
                        onSave(edit)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                    .accessibilityIdentifier("recipeEdit.save")
                }
            }
        }
        .adaptiveDetents([.medium, .large])
        .interactiveDismissDisabled(isEdited)
    }

    /// 태그는 저장 시트(SaveRecipeSheet)와 같이 쉼표로 나눈다
    private var edit: RecipeEdit {
        RecipeEdit(
            name: name == recipe.name ? nil : trimmedName,
            tags: tagsText == initialTagsText
                ? nil
                : tagsText.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty },
            note: note == (recipe.note ?? "") ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
