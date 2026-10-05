import LevainCore
import SwiftUI
import UIKit

enum ConvMode: String, CaseIterable {
    case fixedMass
    case fixedPff

    var label: String {
        switch self {
        case .fixedMass: return L("르방 질량 고정")
        case .fixedPff: return L("PFF 고정")
        }
    }

    var desc: String {
        switch self {
        case .fixedMass:
            return L("르방 무게를 그대로 두고 첨가 밀가루·물을 조정합니다 — PFF(발효종 밀가루 비율)가 변합니다.")
        case .fixedPff:
            return L("발효종 밀가루 양(PFF)을 유지합니다 — 필요한 르방 무게가 달라지고, 첨가 물이 그만큼 조정됩니다.")
        }
    }
}

struct ConverterView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.windowIsRegular) private var windowIsRegular
    @Environment(\.dynamicTypeSize) private var typeSize

    /// nil = 손대지 않은 기본 이름 — 보일 때 현재 언어로 옮긴다 (한국어 원문을 저장해 두면 영어 화면에 그대로 샌다)
    @State private var name: String?
    @State private var input = CalcState.defaultDoughInput()
    /// 아직 기본 예시 배합인가 — 계산기·레시피에서 배합을 받으면 false
    @State private var showsExample = true
    @State private var targetHydrationPct: Double = 50
    /// 목표 프리셋 선택 — '직접'(2)도 실제 선택 가능
    @State private var targetPresetSel = 1
    @State private var convMode: ConvMode = .fixedMass
    @State private var distFlourId = ""
    @State private var editingSource = false
    @State private var showLoadSheet = false
    @State private var loadAsPopover = false
    @State private var showSave = false
    @State private var savedFeedback = false
    @State private var appliedFeedback = false
    @State private var toastMessage: String?
    @State private var keyboardVisible = false
    /// 예시 안내에서 계산기 배합을 가져오지 못한 이유 — 탭할 때만 따진다 (본문이 계산기 입력을 구독하지 않도록)
    @State private var calcPickError: String?

    /// 결과 바를 탭하면 성공 시 목표 수분율 행을 위로 올린다 — List의 scrollTo는 섹션 머리글을 건너뛰어,
    /// 결과 섹션을 기준점으로 삼으면 그 머리글이 내비게이션 바 밑에 숨는다
    private static let targetRowID = "converter.targetRow"
    /// 변환 불가 섹션의 스크롤 기준점
    private static let errorAnchorID = "converter.error"

    var body: some View {
        let sourceStats = computeStats(input)
        let newHydration = targetHydrationPct / 100
        let dist: DeltaDistribution =
            distFlourId.isEmpty ? .proRata : .single(flourID: distFlourId)
        let result: ConvertResult =
            convMode == .fixedMass
            ? convertFixedMass(input, newHydration: newHydration, dist: dist)
            : convertFixedPff(input, newHydration: newHydration)

        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    sourceSection(sourceStats: sourceStats)
                    settingsSection
                    resultSection(result: result, newHydration: newHydration)
                }
                .scrollDismissesKeyboard(.interactively)
                .readableFormWidth()
                .toast($toastMessage)
                .safeAreaInset(edge: .bottom) {
                    resultBar(result) {
                        withAnimation {
                            // 접근성 글자 크기에선 설정 행·꼬리말만으로 화면이 차 결과가 한 줄도 안 보인다 —
                            // 머리글을 포기하고 첫 결과 행을 위로
                            proxy.scrollTo(
                                !isSuccess(result)
                                    ? Self.errorAnchorID
                                    : typeSize.isAccessibilitySize ? BeforeAfterSections.anchorID : Self.targetRowID,
                                anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle(L("르방 변환"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // 계산기의 불러오기·레시피 탭과 같은 기호 — 책 = 저장된 레시피
                    Button {
                        // 모양은 여는 순간에 정한다 — 연 채로 창 크기 등급이 바뀌면 띄운 쪽이 닫히고 다른 쪽은 뜨지 않아
                        // showLoadSheet가 true로 남고 버튼이 먹통이 된다
                        loadAsPopover = windowIsRegular
                        showLoadSheet = true
                    } label: {
                        Label(L("불러오기"), systemImage: "book.closed")
                    }
                    // 넓은 창(iPad)에선 버튼에 붙은 팝오버로 — 행 두어 개에 시트는 거의 빈 화면이다
                    .popover(
                        isPresented: Binding(
                            get: { loadAsPopover && showLoadSheet },
                            set: { showLoadSheet = $0 })
                    ) {
                        loadSheet
                            .frame(idealWidth: 420, idealHeight: 420)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) { showSave = true }
                        // 르방 수분율 0 이하는 코덱 검증에서 탈락해 저장해도 다음 실행 때 사라진다
                        .disabled(!isSuccess(result) || newHydration <= 0)
                }
            }
            // ⌘S는 보이는 탭에서만 — 계산기 CalculatorView의 같은 단축키 참고
            .background {
                if model.selectedTab == .converter {
                    Button(L("저장")) {
                        guard !modalIsPresented() else { return }
                        showSave = true
                    }
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(!isSuccess(result) || newHydration <= 0)
                        .opacity(0)
                        .accessibilityHidden(true)
                }
            }
            // keyboardDoneButton()을 달지 않는다 — 편집 중엔 아래 결과 바가 완료를 보인다 (완료가 둘이 된다)
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in keyboardVisible = true }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in keyboardVisible = false }
            .sheet(
                isPresented: Binding(
                    get: { !loadAsPopover && showLoadSheet },
                    set: { showLoadSheet = $0 })
            ) {
                loadSheet
            }
            .sheet(isPresented: $showSave) {
                SaveRecipeSheet(
                    initialName: suggestedSaveName, initialTags: [], initialNote: "",
                    allowOverwrite: false
                ) { saveName, tags, note, _ in
                    if case .success(let r) = result {
                        let now = isoNow()
                        model.save(
                            Recipe(
                                name: saveName, note: note, tags: tags.isEmpty ? nil : tags,
                                createdAt: now, updatedAt: now, input: r.output))
                        savedFeedback.toggle()
                        toastMessage = L("변환 결과를 새 레시피로 저장했습니다")
                    }
                }
            }
            .sensoryFeedback(.success, trigger: savedFeedback)
            .sensoryFeedback(.impact(weight: .light), trigger: appliedFeedback)
            .onAppear {
                calcPickError = nil
                consumeSource()
            }
            .onChange(of: model.converterSource != nil) { consumeSource() }
            // 예시를 고쳐 쓰기 시작하면 더는 예시가 아니다
            .onChange(of: input) { showsExample = false }
        }
    }

    private var loadSheet: some View {
        ConverterLoadSheet(
            calcError: calcError,
            onPickCalc: pickCalcDough,
            onPickRecipe: { adopt(name: $0.name, input: $0.doughInput) })
    }

    private var displayName: String { name ?? L("캉파뉴") }

    private var suggestedSaveName: String {
        let type = levainShort(targetHydrationPct / 100)
        return "\(displayName) (\(type) \(fmtCount(targetHydrationPct))%)"
    }

    private func isSuccess(_ result: ConvertResult) -> Bool {
        if case .success = result { return true }
        return false
    }

    private func adopt(name newName: String, input newInput: DoughInput) {
        name = newName
        input = newInput
        // 반대 방향 프리셋: 현재 르방이 리퀴드 계열이면 뒤흐(50%)로, 아니면 리퀴드(100%)로
        targetHydrationPct =
            levainTypeFor(hydration: newInput.levain.hydration) == .liquide ? 50 : 100
        distFlourId = ""
        showsExample = false
    }

    private func consumeSource() {
        guard let source = model.converterSource else { return }
        adopt(name: source.name, input: source.input)
        model.converterSource = nil
    }

    /// 모드 B의 불가능한 목표 조합(음수 밀가루·물)은 변환기에 들이지 않는다
    private var calcError: String? {
        let dough = model.calc.currentDough
        let infeasible = dough.water < -1e-9 || dough.flours.contains { $0.grams < -1e-9 }
        return infeasible ? L("목표 조합이 불가능합니다 — 계산기에서 PFF를 낮추세요") : nil
    }

    private func pickCalcDough() {
        model.sendToConverter(name: model.calc.name, input: model.calc.currentDough)
    }

    private func pickCalcDoughFromFooter() {
        calcPickError = calcError
        if calcPickError == nil { pickCalcDough() }
    }

    // MARK: 원본

    @ViewBuilder
    private func sourceSection(sourceStats: DoughStats) -> some View {
        Section {
            TextField(
                L("레시피 이름"),
                text: Binding(get: { displayName }, set: { name = $0 })
            )
            .accessibilityLabel(L("레시피 이름"))
            StackingLabeledContent(L("현재 르방")) {
                Text(
                    "\(levainShort(input.levain.hydration)) \(clampedInt(input.levain.hydration * 100))% · \(fmtGrams(input.levain.grams, model.precision)) g"
                )
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            StackingLabeledContent(L("총 수분율")) {
                StatValue(value: fmtPct(sourceStats.hydrationPct))
            }
            sourceEditToggle
        } header: {
            Text(L("원본 배합"))
        } footer: {
            if showsExample {
                exampleFooter
            }
        }
        .textCase(nil)
        if editingSource {
            IngredientFormSections(
                input: $input, stats: sourceStats, precision: model.precision,
                basis: model.pctBasis)
        }
    }

    /// iOS 17의 DisclosureGroup 행은 VoiceOver에 버튼으로 드러나지 않고, 화살표만 이름 없는 작은 버튼으로 남는다
    /// (라벨에 접근성 특성을 달아도 그대로) — 17에선 같은 모양의 버튼으로 그린다
    @ViewBuilder
    private var sourceEditToggle: some View {
        if #available(iOS 18, *) {
            DisclosureGroup(L("원본 직접 편집"), isExpanded: $editingSource) {
                EmptyView()
            }
        } else {
            Button {
                withAnimation { editingSource.toggle() }
            } label: {
                HStack {
                    Text(L("원본 직접 편집"))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .rotationEffect(.degrees(editingSource ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .accessibilityValue(editingSource ? L("펼침") : L("접힘"))
        }
    }

    /// 고르기 행. 접근성 글자 크기에선 이름과 값을 한 메뉴 단추 안에 위아래로 그린다 (AXMenuPicker)
    @ViewBuilder
    private func pickerRow<P: View>(
        _ label: String, value: String, segmented: Bool = false, @ViewBuilder picker: () -> P
    ) -> some View {
        if typeSize.isAccessibilitySize {
            AXMenuPicker(label, value: value, picker: picker)
        } else if segmented {
            picker()
                .pickerStyle(.segmented)
        } else {
            picker()
        }
    }

    /// 기본 예시 배합임을 밝히고, 계산기 배합을 한 번에 가져오게 한다
    private var exampleFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 접근성 글자 크기에서 말줄임으로 잘리지 않게 세로로 늘린다
            Text(L("예시 배합입니다 — 내 배합을 변환하려면 불러오세요"))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: pickCalcDoughFromFooter) {
                Label(L("계산기 배합 가져오기"), systemImage: "arrow.down.doc")
                    .fontWeight(.semibold)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            if let calcPickError {
                Text(calcPickError)
                    .foregroundStyle(Color.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 변환 설정

    private func applyTargetPreset(_ sel: Int) {
        if sel == 0 { targetHydrationPct = 100 }
        if sel == 1 { targetHydrationPct = 50 }
    }

    private func syncTargetPreset(_ pct: Double) {
        let sel: Int
        if pct == 100 {
            sel = 0
        } else if pct == 50 {
            sel = 1
        } else {
            sel = 2
        }
        targetPresetSel = sel
    }

    /// 목표 프리셋 이름 (태그 = 위치) — 계산기 르방 프리셋과 같은 순서 (리퀴드 → 뒤흐)
    private var targetPresetNames: [String] { [L("리퀴드 100%"), L("뒤흐 50%"), L("직접")] }

    private var targetPresetPicker: some View {
        let names = targetPresetNames
        return pickerRow(L("목표"), value: names[targetPresetSel], segmented: true) {
            Picker(L("목표"), selection: $targetPresetSel) {
                ForEach(names.indices, id: \.self) { i in
                    Text(names[i]).tag(i)
                }
            }
        }
        .onChange(of: targetPresetSel) { _, sel in applyTargetPreset(sel) }
        .onChange(of: targetHydrationPct, initial: true) { _, pct in syncTargetPreset(pct) }
    }

    private var settingsSection: some View {
        Section {
            pickerRow(L("변환 모드"), value: convMode.label, segmented: true) {
                Picker(L("변환 모드"), selection: $convMode) {
                    ForEach(ConvMode.allCases, id: \.self) { m in
                        Text(m.label).tag(m)
                    }
                }
            }
            targetPresetPicker
            NumberField(
                label: L("목표 르방 수분율"), value: $targetHydrationPct, unit: "%",
                minValue: 1, maxValue: 1000
            )
            .id(Self.targetRowID)
            if convMode == .fixedMass && input.flours.count > 1 {
                pickerRow(
                    L("밀가루 증감 배분"),
                    value: input.flours.first { $0.id == distFlourId }.map(flourLabel) ?? L("비례 배분")
                ) {
                    Picker(L("밀가루 증감 배분"), selection: $distFlourId) {
                        Text(L("비례 배분")).tag("")
                        ForEach(input.flours) { f in
                            Text(flourLabel(f)).tag(f.id)
                        }
                    }
                }
            }
        } header: {
            Text(L("변환 설정"))
        } footer: {
            Text(convMode.desc)
        }
        .textCase(nil)
    }

    // MARK: 결과

    @ViewBuilder
    private func resultSection(result: ConvertResult, newHydration: Double) -> some View {
        switch result {
        case .success(let r):
            BeforeAfterSections(
                input: input, result: r, precision: model.precision)
        case .failure(let error):
            Section(L("변환 불가")) {
                errorView(error, newHydration: newHydration)
            }
            .textCase(nil)
            .id(Self.errorAnchorID)
        }
    }

    /// 아래 고정 결과 바 — 키보드 위에서도 변환 후 핵심 수치(또는 변환 불가)를 보인다
    @ViewBuilder
    private func resultBar(_ result: ConvertResult, onExpand: @escaping () -> Void) -> some View {
        switch result {
        case .success(let r):
            ResultBar(
                chips: [
                    StatChip(
                        title: L("르방"),
                        value: fmtGrams(r.output.levain.grams, model.precision) + " g"),
                    StatChip(
                        title: L("첨가 밀가루"),
                        value: fmtGrams(addedFlourTotal(r.output), model.precision) + " g"),
                    StatChip(
                        title: L("본반죽 물"),
                        value: fmtGrams(r.output.water, model.precision) + " g"),
                    StatChip(title: "PFF", value: fmtPct(r.after.pffPct)),
                ],
                isEditing: keyboardVisible, onExpand: onExpand,
                expandHint: L("변환 결과로 이동합니다"))
        case .failure:
            ResultBar(
                isEditing: keyboardVisible, onExpand: onExpand,
                expandHint: L("변환 결과로 이동합니다")
            ) {
                Label(L("변환 불가"), systemImage: "exclamationmark.triangle.fill")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func errorView(_ error: ConvertError, newHydration: Double) -> some View {
        switch error {
        case .fAddNegative(let maxGrams):
            errorCard(
                L("르방 속 밀가루가 총 밀가루를 초과합니다."),
                maxGrams: maxGrams)
        case .wAddNegative(let maxGrams):
            errorCard(
                L("본반죽 물이 부족해서 이 수분율로 변환할 수 없습니다."),
                maxGrams: maxGrams)
        case .singleFlourInsufficient(_, let needed, let available):
            Label(
                LF("지정한 밀가루가 부족합니다 (필요 %@ g, 보유 %@ g). 비례 배분을 선택하거나 다른 밀가루를 지정하세요.", fmtGrams(needed, model.precision), fmtGrams(available, model.precision)),
                systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.danger)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private func errorCard(_ message: String, maxGrams: Double) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(Color.danger)
            .font(.footnote)
        if maxGrams.isFinite {
            Button {
                input = withLevainMass(input, grams: maxGrams)
                appliedFeedback.toggle()
            } label: {
                Text(LF("최대 르방 질량 적용 — %@ g", fmtGrams(maxGrams, model.precision)))
            }
        }
    }
}

/// 변환기 소스 불러오기 시트 — 계산기 배합 또는 저장된 레시피
struct ConverterLoadSheet: View {
    /// 계산기 배합을 가져올 수 없는 이유 — 있으면 버튼을 막고 보여 준다
    var calcError: String? = nil
    let onPickCalc: () -> Void
    let onPickRecipe: (Recipe) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onPickCalc()
                        dismiss()
                    } label: {
                        Label(L("계산기 배합 가져오기"), systemImage: "arrow.down.doc")
                    }
                    .disabled(calcError != nil)
                } footer: {
                    if let calcError {
                        Text(calcError).foregroundStyle(Color.danger)
                    }
                }
                if !model.recipes.isEmpty {
                    Section(L("저장된 레시피")) {
                        ForEach(model.recipes) { recipe in
                            // 탭 영역은 라벨 안에서 넓힌다 — .plain 버튼 바깥의 contentShape는 글자 밖 탭을 받지 못한다
                            Button {
                                onPickRecipe(recipe)
                                dismiss()
                            } label: {
                                RecipeRow(recipe: recipe, precision: model.precision)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .textCase(nil)
                }
            }
            .navigationTitle(L("불러오기"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) { dismiss() }
                }
            }
        }
        .adaptiveDetents([.medium, .large])
    }
}
