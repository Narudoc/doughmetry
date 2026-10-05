import LevainCore
import SwiftUI

/// AI 인식 결과 확인 화면 — 저장 전 필수 단계.
/// 기존 재료 입력 폼을 그대로 재사용해서 바로 수정할 수 있다.
struct ImportReviewSheet: View {
    let imported: ImportedRecipe
    /// note는 비었으면 nil, pieces는 0이면 nil
    let onSave: (_ name: String, _ input: DoughInput, _ note: String?, _ pieces: Double?) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var name: String
    @State private var input: DoughInput
    @State private var note: String
    /// 분할 개수 (0 = 사용 안 함)
    @State private var pieces: Double
    @State private var showText = false
    @State private var showDiscard = false
    @State private var keyboardVisible = false

    init(
        imported: ImportedRecipe,
        onSave: @escaping (_ name: String, _ input: DoughInput, _ note: String?, _ pieces: Double?) -> Void
    ) {
        self.imported = imported
        self.onSave = onSave
        _name = State(initialValue: imported.name)
        _input = State(initialValue: imported.input)
        _note = State(initialValue: imported.note)
        _pieces = State(initialValue: imported.pieces ?? 0)
    }

    private var isEdited: Bool {
        name != imported.name || input != imported.input || note != imported.note
            || pieces != (imported.pieces ?? 0)
    }

    private var engineLabel: String {
        if imported.engine == .appleIntelligence { return L("Apple Intelligence로 분석했습니다.") }
        return imported.aiRejected
            ? L("AI 결과가 규칙 분석과 달라 규칙 기반 결과를 표시합니다 — 물·르방 값을 확인하세요")
            : L("규칙 기반으로 분석했습니다.")
    }

    /// 파서가 물을 바시나주로 잘못 나눴을 때의 신호 — 고치는 동안에도 다시 본다
    private var sanityHints: [String] {
        let hasDough = input.flours.contains { $0.grams > 0 } || input.levain.grams > 0
        if hasDough, input.water == 0, input.bassinage > 0 {
            return [L("본반죽 물이 0 g이고 바시나주만 있습니다 — 원본 텍스트와 대조하세요")]
        }
        if input.water > 0, input.bassinage > input.water {
            return [L("바시나주가 본반죽 물보다 많습니다")]
        }
        return []
    }

    var body: some View {
        let stats = computeStats(input)
        NavigationStack {
            Form {
                Section {
                    Label(
                        engineLabel,
                        systemImage: imported.aiRejected
                            ? "exclamationmark.triangle"
                            : imported.engine == .appleIntelligence ? "sparkles" : "text.viewfinder")
                        .font(.footnote)
                        .foregroundStyle(Color.bottle)
                    ForEach(sanityHints, id: \.self) { hint in
                        Label(hint, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.danger)
                    }
                } footer: {
                    Text(L("인식 결과를 확인·수정한 뒤 저장하세요."))
                }
                Section {
                    TextField(L("레시피 이름"), text: $name)
                        .accessibilityLabel(L("레시피 이름"))
                }
                IngredientFormSections(
                    input: $input, stats: stats, precision: model.precision,
                    basis: model.pctBasis)
                Section {
                    NumberField(
                        label: L("분할 개수"), value: $pieces,
                        unit: L("개"), maxValue: 1000, integer: true)
                } header: {
                    Text(L("분할"))
                } footer: {
                    Text(L("0이면 분할하지 않습니다."))
                }
                .textCase(nil)
                Section(L("지표")) {
                    statRow(L("총 수분율")) {
                        StatValue(value: fmtPct(stats.hydrationPct))
                    }
                    statRow(L("총 반죽 무게")) {
                        StatValue(value: fmtGrams(stats.doughWeight, model.precision) + " g")
                    }
                    statRow("PFF") { StatValue(value: fmtPct(stats.pffPct)) }
                }
                .textCase(nil)
                Section {
                    TextField(L("배합 메모, 발효 시간, 결과 등을 적어두세요"), text: $note, axis: .vertical)
                        .lineLimit(3...10)
                        .accessibilityLabel(L("노트"))
                } header: {
                    Text(L("노트"))
                } footer: {
                    Text(L("만드는 법은 노트로 저장됩니다"))
                }
                .textCase(nil)
                Section {
                    recognizedTextDisclosure
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .readableSheetWidth()
            .navigationTitle(L("가져오기 확인"))
            .navigationBarTitleDisplayMode(.inline)
            // keyboardDoneButton()을 달지 않는다 — 내비게이션 바의 완료가 저장 바로 옆에 붙어 두 번 누르면 저장된다.
            // 편집 중엔 아래 결과 바가 완료를 보인다 (계산기와 같은 방식)
            .safeAreaInset(edge: .bottom) {
                if keyboardVisible {
                    ResultBar(
                        chips: summaryChips(
                            stats: stats, pieces: pieces > 0 ? pieces : nil, precision: model.precision),
                        isEditing: true)
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in keyboardVisible = true }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in keyboardVisible = false }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) {
                        if isEdited { showDiscard = true } else { dismiss() }
                    }
                    .accessibilityIdentifier("importReview.cancel")
                    .discardConfirmation(isPresented: $showDiscard) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            trimmed.isEmpty ? L("가져온 레시피") : trimmed, input,
                            trimmedNote.isEmpty ? nil : trimmedNote, pieces > 0 ? pieces : nil)
                        dismiss()
                    }
                    .accessibilityIdentifier("importReview.save")
                }
            }
        }
        .pageSizedSheet()
        // 인식 결과는 사진 인식을 다시 돌려야 되살릴 수 있다 — 쓸어내리기로는 닫히지 않고 취소 버튼으로만 닫힌다
        .interactiveDismissDisabled()
    }

    /// iOS 17의 DisclosureGroup 행은 VoiceOver에 버튼으로 드러나지 않고, 화살표만 이름 없는 작은 버튼으로 남는다
    /// (라벨에 접근성 특성을 달아도 그대로) — 17에선 같은 모양의 버튼으로 그린다
    @ViewBuilder
    private var recognizedTextDisclosure: some View {
        if #available(iOS 18, *) {
            DisclosureGroup(L("인식된 원본 텍스트"), isExpanded: $showText) {
                recognizedTextContent
            }
        } else {
            Button {
                withAnimation { showText.toggle() }
            } label: {
                HStack {
                    Text(L("인식된 원본 텍스트"))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .rotationEffect(.degrees(showText ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .accessibilityValue(showText ? L("펼침") : L("접힘"))
            if showText {
                recognizedTextContent
            }
        }
    }

    @ViewBuilder
    private var recognizedTextContent: some View {
        Text(imported.recognizedText)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        // 만드는 법 머리글을 못 찾았을 때 — 원문을 통째로 노트로
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button(L("원본 텍스트를 노트에 넣기")) {
                note = imported.recognizedText
            }
        }
    }

    /// iOS 17·18의 LabeledContent는 접근성 글자 크기에서 이름과 값을 위아래로 쌓지 않아 이름이 단어 중간에서
    /// 끊긴다 — 26부터는 시스템이 쌓는다
    private var stacksLabeledRows: Bool {
        if #unavailable(iOS 26) { return typeSize.isAccessibilitySize }
        return false
    }

    @ViewBuilder
    private func statRow<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        if stacksLabeledRows {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                value()
            }
            .accessibilityElement(children: .combine)
        } else {
            LabeledContent {
                value()
            } label: {
                Text(label)
            }
        }
    }
}

extension View {
    /// iPad에선 긴 편집 폼이 작은 폼 시트에 갇히지 않게 페이지 크기 시트로 (iOS 18+). iPhone 시트는 그대로
    @ViewBuilder
    fileprivate func pageSizedSheet() -> some View {
        if #available(iOS 18, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }

    /// 페이지 크기 시트(넓은 창)에서 폼을 결과 바와 같은 폭(700pt)으로 가운데에 모은다. 시트 안의 크기 클래스로는
    /// 알 수 없어(폼 시트는 iPad에서도 compact) readableFormWidth() 대신 띄운 창의 폭(windowIsRegular)을 본다 —
    /// iPhone·좁은 창은 그대로
    fileprivate func readableSheetWidth() -> some View { modifier(ReadableSheetWidth()) }
}

private struct ReadableSheetWidth: ViewModifier {
    @Environment(\.windowIsRegular) private var windowIsRegular

    func body(content: Content) -> some View {
        if windowIsRegular {
            GeometryReader { proxy in
                content.contentMargins(
                    .horizontal, max(20, (proxy.size.width - 700) / 2), for: .scrollContent)
            }
        } else {
            content
        }
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
                .accessibilityLabel(L("레시피 텍스트를 붙여넣으세요"))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L("레시피 텍스트를 붙여넣으세요"))
                                .foregroundStyle(.tertiary)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                            // 붙여넣기 권한 묻기 없이 바로 분석으로 — 저장은 여전히 확인 시트를 거친다.
                            // PasteButton의 글자는 시스템 언어로 그려져 앱 안 언어 선택을 따르지 않는다 — 아이콘만 쓰고 설명을 옆에
                            HStack(spacing: 12) {
                                PasteButton(payloadType: String.self) { strings in
                                    let pasted = strings.joined(separator: "\n")
                                    guard !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                        return
                                    }
                                    Task { @MainActor in
                                        dismiss()
                                        onSubmit(pasted)
                                    }
                                }
                                .labelStyle(.iconOnly)
                                .buttonBorderShape(.capsule)
                                .tint(Color.bottle)
                                // 시스템 붙여넣기 버튼은 controlSize·frame을 따르지 않고 글자 크기로만 커진다 —
                                // 기본 크기(41×34pt)로는 터치 영역 44pt에 못 미쳐 AX1 이상으로 그린다
                                .dynamicTypeSize(.accessibility1...)
                                .accessibilityIdentifier("textImport.paste")
                                Text(L("붙여넣고 분석"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(16)
                    }
                }
                .navigationTitle(L("텍스트에서 가져오기"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L("취소")) {
                            if hasText && text != initialText { showDiscard = true } else { dismiss() }
                        }
                        .discardConfirmation(isPresented: $showDiscard) { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("분석")) {
                            dismiss()
                            onSubmit(text)
                        }
                        .disabled(!hasText)
                        .accessibilityIdentifier("textImport.analyze")
                    }
                }
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
