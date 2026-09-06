import LevainCore
import SwiftUI

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

    @State private var name = "캉파뉴"
    @State private var input = CalcState.defaultDoughInput()
    @State private var targetHydrationPct: Double = 50
    /// 목표 프리셋 선택 — '직접'(2)도 실제 선택 가능
    @State private var targetPresetSel = 0
    @State private var convMode: ConvMode = .fixedMass
    @State private var distFlourId = ""
    @State private var editingSource = false
    @State private var showLoadSheet = false
    @State private var showSave = false
    @State private var savedFeedback = false
    @State private var appliedFeedback = false

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
            Form {
                sourceSection(sourceStats: sourceStats)
                settingsSection
                resultSection(result: result, newHydration: newHydration)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L("르방 변환"))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showLoadSheet = true
                    } label: {
                        Label(L("불러오기"), systemImage: "square.and.arrow.down.on.square")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSave = true
                    } label: {
                        Label(L("저장"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(!isSuccess(result))
                }
            }
            .sheet(isPresented: $showLoadSheet) {
                ConverterLoadSheet(
                    onPickCalc: {
                        model.sendToConverter(
                            name: model.calc.name, input: model.calc.currentDough)
                    },
                    onPickRecipe: { adopt($0) })
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
                    }
                }
            }
            .sensoryFeedback(.success, trigger: savedFeedback)
            .sensoryFeedback(.impact(weight: .light), trigger: appliedFeedback)
            .onAppear(perform: consumeSource)
            .onChange(of: model.converterSource != nil) { consumeSource() }
        }
    }

    private var suggestedSaveName: String {
        let type = L(targetHydrationPct >= 75 ? "리퀴드" : "뒤흐")
        return "\(name) (\(type) \(Int(targetHydrationPct))%)"
    }

    private func isSuccess(_ result: ConvertResult) -> Bool {
        if case .success = result { return true }
        return false
    }

    private func adopt(_ recipe: Recipe) {
        name = recipe.name
        input = recipe.doughInput
        targetHydrationPct = recipe.levain.hydration >= 0.75 ? 50 : 100
        distFlourId = ""
    }

    private func consumeSource() {
        guard let source = model.converterSource else { return }
        name = source.name
        input = source.input
        // 반대 방향 프리셋: 현재 르방이 리퀴드 계열이면 뒤흐(50%)로, 아니면 리퀴드(100%)로
        targetHydrationPct = source.input.levain.hydration >= 0.75 ? 50 : 100
        distFlourId = ""
        model.converterSource = nil
    }

    // MARK: 원본

    @ViewBuilder
    private func sourceSection(sourceStats: DoughStats) -> some View {
        Section {
            TextField(L("레시피 이름"), text: $name)
            LabeledContent {
                Text(
                    "\(L(input.levain.hydration >= 0.75 ? "리퀴드" : "뒤흐")) \(Int((input.levain.hydration * 100).rounded()))% · \(fmtGrams(input.levain.grams, model.precision)) g"
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
        }
        if editingSource {
            IngredientFormSections(
                input: $input, stats: sourceStats, precision: model.precision,
                basis: model.pctBasis)
        }
    }

    // MARK: 변환 설정

    private func applyTargetPreset(_ sel: Int) {
        if sel == 0 { targetHydrationPct = 50 }
        if sel == 1 { targetHydrationPct = 100 }
    }

    private func syncTargetPreset(_ pct: Double) {
        let sel: Int
        if pct == 50 {
            sel = 0
        } else if pct == 100 {
            sel = 1
        } else {
            sel = 2
        }
        targetPresetSel = sel
    }

    private var targetPresetPicker: some View {
        let picker = Picker(L("목표"), selection: $targetPresetSel) {
            Text(L("뒤흐 50%")).tag(0)
            Text(L("리퀴드 100%")).tag(1)
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
                label: L("목표 르방 수분율"), value: $targetHydrationPct, unit: "%", fractionDigits: 0)
            if convMode == .fixedMass && input.flours.count > 1 {
                Picker(L("밀가루 증감 배분"), selection: $distFlourId) {
                    Text(L("비례 배분")).tag("")
                    ForEach(input.flours) { f in
                        Text(f.name.isEmpty ? L("이름 없음") : f.name).tag(f.id)
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
