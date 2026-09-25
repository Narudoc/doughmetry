import LevainCore
import SwiftUI

/// AI 인식 결과 확인 화면 — 저장 전 필수 단계.
/// 기존 재료 입력 폼을 그대로 재사용해서 바로 수정할 수 있다.
struct ImportReviewSheet: View {
    let imported: ImportedRecipe
    let onSave: (_ name: String, _ input: DoughInput) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var input: DoughInput
    @State private var showText = false
    @State private var showDiscard = false

    init(imported: ImportedRecipe, onSave: @escaping (_ name: String, _ input: DoughInput) -> Void) {
        self.imported = imported
        self.onSave = onSave
        _name = State(initialValue: imported.name)
        _input = State(initialValue: imported.input)
    }

    private var isEdited: Bool { name != imported.name || input != imported.input }

    var body: some View {
        let stats = computeStats(input)
        NavigationStack {
            Form {
                Section {
                    Label(
                        imported.engine == .appleIntelligence
                            ? L("Apple Intelligence로 분석했습니다.")
                            : L("규칙 기반으로 분석했습니다."),
                        systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(Color.bottle)
                } footer: {
                    Text(L("인식 결과를 확인·수정한 뒤 저장하세요."))
                }
                Section {
                    TextField(L("레시피 이름"), text: $name)
                }
                IngredientFormSections(
                    input: $input, stats: stats, precision: model.precision,
                    basis: model.pctBasis)
                Section(L("지표")) {
                    LabeledContent(L("총 수분율")) {
                        StatValue(value: fmtPct(stats.hydrationPct))
                    }
                    LabeledContent(L("총 반죽 무게")) {
                        StatValue(value: fmtGrams(stats.doughWeight, model.precision) + " g")
                    }
                    LabeledContent("PFF") { StatValue(value: fmtPct(stats.pffPct)) }
                }
                Section {
                    DisclosureGroup(L("인식된 원본 텍스트"), isExpanded: $showText) {
                        Text(imported.recognizedText)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L("가져오기 확인"))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) {
                        if isEdited { showDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed.isEmpty ? L("가져온 레시피") : trimmed, input)
                        dismiss()
                    }
                }
            }
            .discardConfirmation(isPresented: $showDiscard) { dismiss() }
        }
        // 인식 결과는 사진 인식을 다시 돌려야 되살릴 수 있다 — 쓸어내리기로는 닫히지 않고 취소 버튼으로만 닫힌다
        .interactiveDismissDisabled()
    }
}

/// 텍스트 붙여넣기 입력 시트
struct TextImportSheet: View {
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var showDiscard = false
    private let initialText: String

    /// initialText — 인식에 실패한 텍스트를 고쳐 다시 분석할 때 채워 둔다
    init(initialText: String = "", onSubmit: @escaping (String) -> Void) {
        self.onSubmit = onSubmit
        self.initialText = initialText
        _text = State(initialValue: initialText)
    }

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.callout)
                .padding(8)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L("레시피 텍스트를 붙여넣으세요"))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
                .navigationTitle(L("텍스트에서 가져오기"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L("취소")) {
                            if hasText && text != initialText { showDiscard = true } else { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("분석")) {
                            dismiss()
                            onSubmit(text)
                        }
                        .disabled(!hasText)
                    }
                }
                .discardConfirmation(isPresented: $showDiscard) { dismiss() }
        }
        .interactiveDismissDisabled(hasText)
    }
}

extension View {
    /// 편집 내용이 있는 시트의 취소 확인 — 시트의 취소 버튼이 편집 여부를 보고 isPresented를 켠다
    func discardConfirmation(isPresented: Binding<Bool>, onDiscard: @escaping () -> Void) -> some View {
        confirmationDialog(L("변경 사항을 버릴까요?"), isPresented: isPresented, titleVisibility: .visible) {
            Button(L("버리기"), role: .destructive, action: onDiscard)
            Button(L("계속 편집"), role: .cancel) {}
        }
    }
}
