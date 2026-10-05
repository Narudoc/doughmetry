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
    @State private var showSave = false
    @State private var savedFeedback = false
    @State private var appliedFeedback = false
    @State private var toastMessage: String?
    @State private var keyboardVisible = false
    /// 예시 안내에서 계산기 배합을 가져오지 못한 이유 — 탭할 때만 따진다 (본문이 계산기 입력을 구독하지 않도록)
    @State private var calcPickError: String?

    /// 변환 불가 섹션의 스크롤 기준점 — 성공 시엔 BeforeAfterSections.anchorID
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
                            proxy.scrollTo(
                                isSuccess(result) ? BeforeAfterSections.anchorID : Self.errorAnchorID,
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
                        showLoadSheet = true
                    } label: {
                        Label(L("불러오기"), systemImage: "book.closed")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) { showSave = true }
                        // 르방 수분율 0 이하는 코덱 검증에서 탈락해 저장해도 다음 실행 때 사라진다
                        .disabled(!isSuccess(result) || newHydration <= 0)
                }
            }
            // keyboardDoneButton()을 달지 않는다 — 편집 중엔 아래 결과 바가 완료를 보인다 (완료가 둘이 된다)
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in keyboardVisible = true }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in keyboardVisible = false }
            .sheet(isPresented: $showLoadSheet) {
                ConverterLoadSheet(
                    calcError: calcError,
                    onPickCalc: pickCalcDough,
                    onPickRecipe: { adopt(name: $0.name, input: $0.doughInput) })
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
            LabeledContent {
                Text(
                    "\(levainShort(input.levain.hydration)) \(clampedInt(input.levain.hydration * 100))% · \(fmtGrams(input.levain.grams, model.precision)) g"
                )
                .monospacedDigit()
                .foregroundStyle(.secondary)
            } label: {
                Text(L("현재 르방"))
            }
            LabeledContent {
                StatValue(value: fmtPct(sourceStats.hydrationPct))
            } label: {
                Text(L("총 수분율"))
            }
            DisclosureGroup(L("원본 직접 편집"), isExpanded: $editingSource) {
                EmptyView()
            }
        } header: {
            Text(L("원본 배합"))
        } footer: {
            if showsExample {
                exampleFooter
            }
        }
        if editingSource {
            IngredientFormSections(
                input: $input, stats: sourceStats, precision: model.precision,
                basis: model.pctBasis)
        }
    }

    /// 기본 예시 배합임을 밝히고, 계산기 배합을 한 번에 가져오게 한다
    private var exampleFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("예시 배합입니다 — 내 배합을 변환하려면 불러오세요"))
            Button(action: pickCalcDoughFromFooter) {
                Label(L("계산기 배합 가져오기"), systemImage: "arrow.down.doc")
                    .fontWeight(.semibold)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            if let calcPickError {
                Text(calcPickError).foregroundStyle(Color.danger)
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

    private var targetPresetPicker: some View {
        let picker = Picker(L("목표"), selection: $targetPresetSel) {
            // 계산기 르방 프리셋과 같은 순서 (리퀴드 → 뒤흐)
            Text(L("리퀴드 100%")).tag(0)
            Text(L("뒤흐 50%")).tag(1)
            Text(L("직접")).tag(2)
        }
        return picker
            .pickerStyle(.segmented)
            .onChange(of: targetPresetSel) { _, sel in applyTargetPreset(sel) }
            .onChange(of: targetHydrationPct, initial: true) { _, pct in syncTargetPreset(pct) }
    }

    private var settingsSection: some View {
        Section {
            Picker(L("변환 모드"), selection: $convMode) {
                ForEach(ConvMode.allCases, id: \.self) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            targetPresetPicker
            NumberField(
                label: L("목표 르방 수분율"), value: $targetHydrationPct, unit: "%",
                minValue: 1, maxValue: 1000)
            if convMode == .fixedMass && input.flours.count > 1 {
                Picker(L("밀가루 증감 배분"), selection: $distFlourId) {
                    Text(L("비례 배분")).tag("")
                    ForEach(input.flours) { f in
                        Text(flourLabel(f)).tag(f.id)
                    }
                }
            }
        } header: {
            Text(L("변환 설정"))
        } footer: {
            Text(convMode.desc)
        }
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
                            Button {
                                onPickRecipe(recipe)
                                dismiss()
                            } label: {
                                RecipeRow(recipe: recipe, precision: model.precision)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                        }
                    }
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
        .presentationDetents([.medium, .large])
    }
}
