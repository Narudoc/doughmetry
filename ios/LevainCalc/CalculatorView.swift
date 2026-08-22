import LevainCore
import SwiftUI

struct CalculatorView: View {
    @Environment(AppModel.self) private var model
    @State private var showTable = false
    @State private var showSave = false
    @State private var savedFeedback = false

    var body: some View {
        @Bindable var model = model
        let dough = model.calc.currentDough
        let stats = computeStats(dough)
        let pieces = model.calc.currentPieces

        NavigationStack {
            Form {
                Section {
                    Picker(L("입력 모드"), selection: $model.calc.mode) {
                        Text(L("재료 입력")).tag(CalcMode.a)
                        Text(L("목표 역산")).tag(CalcMode.b)
                    }
                    .pickerStyle(.segmented)
                    TextField(L("레시피 이름"), text: $model.calc.name)
                }

                if model.calc.mode == .a {
                    IngredientFormSections(
                        input: $model.calc.input, stats: stats, precision: model.precision)
                    Section(L("분할")) {
                        NumberField(
                            label: L("분할 개수 (0 = 사용 안 함)"), value: $model.calc.pieces,
                            unit: L("개"), fractionDigits: 0)
                    }
                } else {
                    TargetFormSections(target: $model.calc.target)
                    targetErrors(dough: dough)
                    TargetResultSection(
                        dough: dough, stats: stats, precision: model.precision)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L("계산기"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.sendToConverter(name: model.calc.name, input: dough)
                    } label: {
                        Label(L("변환기로"), systemImage: "arrow.left.arrow.right")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSave = true
                    } label: {
                        Label(L("저장"), systemImage: "square.and.arrow.down")
                    }
                }
            }
            .keyboardDoneButton()
            .safeAreaInset(edge: .bottom) {
                SummaryBar(stats: stats, pieces: pieces, precision: model.precision) {
                    showTable = true
                }
            }
            .sheet(isPresented: $showTable) {
                BakersTableSheet(
                    name: model.calc.name, input: dough, stats: stats, pieces: pieces,
                    precision: model.precision)
            }
            .sheet(isPresented: $showSave) {
                let loaded = model.calc.recipeId.flatMap { id in
                    model.recipes.first { $0.id == id }
                }
                SaveRecipeSheet(
                    initialName: model.calc.name,
                    initialTags: loaded?.tags ?? [],
                    initialNote: loaded?.note ?? "",
                    allowOverwrite: loaded != nil
                ) { name, tags, note, overwrite in
                    let id = overwrite ? (loaded?.id ?? newId()) : newId()
                    let now = isoNow()
                    let recipe = Recipe(
                        id: id, name: name, note: note, tags: tags.isEmpty ? nil : tags,
                        createdAt: now, updatedAt: now,
                        input: dough,
                        targetDoughWeight: model.calc.mode == .b
                            ? model.calc.target.spec.doughWeight : nil,
                        pieces: pieces)
                    model.save(recipe)
                    model.calc.name = name
                    model.calc.recipeId = id
                    savedFeedback.toggle()
                }
            }
            .sensoryFeedback(.success, trigger: savedFeedback)
        }
    }

    /// 모드 B에서 목표 조합이 물리적으로 불가능한 경우
    @ViewBuilder
    private func targetErrors(dough: DoughInput) -> some View {
        let negativeWater = dough.water < -1e-9
        let negativeFlour = dough.flours.contains { $0.grams < -1e-9 }
        if negativeWater || negativeFlour {
            Section {
                if negativeWater {
                    Label(
                        LF("이 조합에서는 첨가 물이 음수(%@ g)가 됩니다. PFF를 낮추거나 총 수분율을 높이세요.", fmtGrams(dough.water, model.precision)),
                        systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.danger)
                        .font(.footnote)
                }
                if negativeFlour {
                    Label(
                        L("르방 속 밀가루가 총 밀가루를 초과합니다. PFF를 낮추세요."),
                        systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.danger)
                        .font(.footnote)
                }
            }
        }
    }
}

/// 모드 B 목표 입력 폼
struct TargetFormSections: View {
    @Binding var target: TargetForm

    var body: some View {
        Section(L("목표")) {
            Picker(L("무게 입력"), selection: $target.byPieces) {
                Text(L("총 반죽 무게")).tag(false)
                Text(L("개수 × 개당")).tag(true)
            }
            .pickerStyle(.segmented)
            if target.byPieces {
                NumberField(label: L("분할 개수"), value: $target.pieces, unit: L("개"), fractionDigits: 0)
                NumberField(label: L("개당 무게"), value: $target.pieceWeight)
                HStack {
                    Text(L("총 반죽 무게")).foregroundStyle(.secondary)
                    Spacer()
                    StatValue(value: fmtGrams(target.pieces * target.pieceWeight, .tenth) + " g")
                }
            } else {
                NumberField(label: L("총 반죽 무게"), value: $target.doughWeight)
            }
        }
        Section {
            NumberField(label: L("총 수분율"), value: $target.hydrationPct, unit: "%")
            NumberField(label: L("소금"), value: $target.saltPct, unit: "%")
            NumberField(label: "PFF", value: $target.pffPct, unit: "%")
            NumberField(label: L("르방 수분율"), value: $target.levainHydrationPct, unit: "%", fractionDigits: 0)
        } header: {
            Text(L("비율 (총 밀가루 기준)"))
        } footer: {
            Text(L("밀가루·물·소금·르방만 역산합니다. 바시나주·액체·이스트는 재료 입력 모드에서."))
        }
    }
}

/// 모드 B 역산 결과
struct TargetResultSection: View {
    let dough: DoughInput
    let stats: DoughStats
    let precision: Precision

    var body: some View {
        Section(L("역산 결과")) {
            TableRow(
                name: L("첨가 밀가루"),
                grams: fmtGrams(addedFlourTotal(dough), precision), pct: nil, bold: true)
            TableRow(name: L("본반죽 물"), grams: fmtGrams(dough.water, precision), pct: nil, bold: true)
            TableRow(name: L("소금"), grams: fmtGrams(dough.salt, precision), pct: nil, bold: true)
            TableRow(
                name: dough.levain.hydration >= 0.75 ? L("르방 리퀴드") : L("르방 뒤흐"),
                grams: fmtGrams(dough.levain.grams, precision), pct: nil, bold: true)
        }
    }
}
