import LevainCore
import SwiftUI

/// AI 인식 결과 확인 화면 — 저장 전 필수 단계.
/// 기존 재료 입력 폼을 그대로 재사용해서 바로 수정할 수 있다.
struct ImportReviewSheet: View {
    let imported: ImportedRecipe
    let onSave: (_ name: String, _ input: DoughInput) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var input = CalcState.defaultDoughInput()
    @State private var showText = false

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
                    input: $input, stats: stats, precision: model.precision)
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
                    Button(L("취소")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) {
                        onSave(
                            name.trimmingCharacters(in: .whitespaces).isEmpty
                                ? L("가져온 레시피") : name,
                            input)
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = imported.name
                input = imported.input
            }
        }
    }
}

/// 텍스트 붙여넣기 입력 시트
struct TextImportSheet: View {
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

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
                        Button(L("취소")) { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("분석")) {
                            dismiss()
                            onSubmit(text)
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}
