import LevainCore
import SwiftUI

/// 모드 A 재료 입력 폼 — 계산기·변환기(원본 편집) 공용.
/// Form 안에서 여러 Section으로 렌더링된다.
struct IngredientFormSections: View {
    @Binding var input: DoughInput
    let stats: DoughStats
    let precision: Precision

    var body: some View {
        floursSection
        waterSection
        levainSection
        liquidsSection
        yeastSection
        extrasSection
    }

    // MARK: 밀가루

    private var floursSection: some View {
        Section {
            ForEach($input.flours) { $flour in
                VStack(alignment: .leading, spacing: 6) {
                    TextField(L("밀가루 이름 (T65, 호밀…)"), text: $flour.name)
                        .font(.subheadline)
                    HStack {
                        NumberField(label: "", value: $flour.grams)
                        StatValue(value: fmtPct(stats.pct(flour.id)), size: 14)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
            .onDelete { input.flours.remove(atOffsets: $0) }
            Button {
                input.flours.append(Flour(name: "", grams: 0))
            } label: {
                Label(L("밀가루 추가"), systemImage: "plus.circle")
            }
        } header: {
            Text(L("밀가루 (첨가)"))
        } footer: {
            Text(L("%는 총 밀가루(첨가 + 르방 속) 기준입니다."))
        }
    }

    // MARK: 물·바시나주·소금

    private var waterSection: some View {
        Section(L("물 · 소금")) {
            NumberField(label: L("본반죽 물"), value: $input.water)
            VStack(alignment: .leading, spacing: 2) {
                NumberField(label: L("바시나주"), value: $input.bassinage)
                Text(L("bassinage — 본반죽 후 추가하는 물"))
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            HStack {
                NumberField(label: L("소금"), value: $input.salt)
                StatValue(value: fmtPct(stats.saltPct), size: 14)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    // MARK: 르방

    private var levainPreset: Binding<Int> {
        Binding(
            get: {
                if input.levain.hydration == 1 { return 0 }
                if input.levain.hydration == 0.5 { return 1 }
                return 2
            },
            set: { newValue in
                if newValue == 0 { setLevainHydration(1) }
                if newValue == 1 { setLevainHydration(0.5) }
            })
    }

    private func setLevainHydration(_ h: Double) {
        input.levain.hydration = h
        input.levain.type = levainTypeFor(hydration: h)
    }

    private var levainSection: some View {
        Section {
            Picker(L("르방 종류"), selection: levainPreset) {
                Text(L("리퀴드 100%")).tag(0)
                Text(L("뒤흐 50%")).tag(1)
                Text(L("직접")).tag(2)
            }
            .pickerStyle(.segmented)
            HStack {
                NumberField(label: L("르방 무게"), value: $input.levain.grams)
                StatValue(value: fmtPct(stats.pffPct), size: 14)
                    .frame(width: 60, alignment: .trailing)
            }
            NumberField(
                label: L("수분율"),
                value: Binding(
                    get: { input.levain.hydration * 100 },
                    set: { setLevainHydration(max(0.01, $0 / 100)) }),
                unit: "%", fractionDigits: 0)
            TextField(
                L("르방 밀가루 (표시용)"),
                text: Binding(
                    get: { input.levain.flourName ?? "" },
                    set: { input.levain.flourName = $0.isEmpty ? nil : $0 }))
                .font(.subheadline)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text(L("속 밀가루")).font(.caption).foregroundStyle(.secondary)
                    StatValue(value: fmtGrams(stats.levainFlour, precision) + " g", size: 13)
                }
                HStack(spacing: 4) {
                    Text(L("속 물")).font(.caption).foregroundStyle(.secondary)
                    StatValue(value: fmtGrams(stats.levainWater, precision) + " g", size: 13)
                }
            }
        } header: {
            BilingualLabel(
                L("르방"),
                fr: input.levain.hydration >= 0.75 ? "levain liquide" : "levain dur")
        } footer: {
            Text(L("%는 PFF — 총 밀가루 중 르방 속 밀가루의 비율."))
        }
    }

    // MARK: 액체 재료

    private var liquidsSection: some View {
        Section {
            ForEach($input.liquids) { $liquid in
                VStack(alignment: .leading, spacing: 6) {
                    TextField(L("이름"), text: $liquid.name)
                        .font(.subheadline)
                    NumberField(label: "", value: $liquid.grams)
                    HStack {
                        NumberField(
                            label: L("수분율"),
                            value: Binding(
                                get: { liquid.waterRatio * 100 },
                                set: { liquid.waterRatio = min(1, max(0, $0 / 100)) }),
                            unit: "%", fractionDigits: 0)
                        HStack(spacing: 4) {
                            Text(L("수분")).font(.caption).foregroundStyle(.secondary)
                            StatValue(
                                value: fmtGrams(liquid.grams * liquid.waterRatio, precision) + " g",
                                size: 13)
                        }
                    }
                }
            }
            .onDelete { input.liquids.remove(atOffsets: $0) }
            Menu {
                ForEach(LiquidPreset.allCases, id: \.name) { preset in
                    Button("\(L(preset.name)) (\(L("수분")) \(Int(preset.waterRatio * 100))%)") {
                        input.liquids.append(
                            Liquid(name: L(preset.name), grams: 0, waterRatio: preset.waterRatio))
                    }
                }
                Button(L("직접 입력")) {
                    input.liquids.append(Liquid(name: "", grams: 0, waterRatio: 0.8))
                }
            } label: {
                Label(L("액체 재료 추가"), systemImage: "plus.circle")
            }
        } header: {
            Text(L("액체 재료"))
        } footer: {
            Text(L("우유·계란 등 — 수분율만큼 총 물에 반영됩니다 (USDA 기준: 우유 88%, 계란 76%)."))
        }
    }

    // MARK: 이스트

    private var yeastSection: some View {
        Section {
            Picker(L("이스트 종류"), selection: $input.yeast.type) {
                Text(L("생이스트")).tag(YeastType.fresh)
                Text(L("인스턴트")).tag(YeastType.instant)
            }
            .pickerStyle(.segmented)
            .onChange(of: input.yeast.type) { oldType, newType in
                input.yeast.grams = convertYeast(input.yeast.grams, from: oldType, to: newType)
            }
            HStack {
                NumberField(label: L("투입량"), value: $input.yeast.grams)
                StatValue(value: fmtPct(stats.yeastPct), size: 14)
                    .frame(width: 60, alignment: .trailing)
            }
            if input.yeast.grams > 0 {
                HStack(spacing: 4) {
                    Text(input.yeast.type == .fresh ? L("= 인스턴트") : L("= 생이스트"))
                        .font(.caption).foregroundStyle(.secondary)
                    StatValue(
                        value: fmtGrams(
                            convertYeast(
                                input.yeast.grams, from: input.yeast.type,
                                to: input.yeast.type == .fresh ? .instant : .fresh),
                            precision) + " g",
                        size: 13)
                }
            }
        } header: {
            Text(L("이스트 (선택)"))
        } footer: {
            Text(L("인스턴트 = 생이스트 × 0.4. 무게·%에만 반영, 수분율 미반영."))
        }
    }

    // MARK: 기타 재료

    private var extrasSection: some View {
        Section {
            ForEach($input.extras) { $extra in
                VStack(alignment: .leading, spacing: 6) {
                    TextField(L("이름 (호두, 건포도…)"), text: $extra.name)
                        .font(.subheadline)
                    HStack {
                        NumberField(label: "", value: $extra.grams)
                        StatValue(value: fmtPct(stats.pct(extra.id)), size: 14)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
            .onDelete { input.extras.remove(atOffsets: $0) }
            Button {
                input.extras.append(Extra(name: "", grams: 0))
            } label: {
                Label(L("기타 재료 추가"), systemImage: "plus.circle")
            }
        } header: {
            Text(L("기타 재료"))
        } footer: {
            Text(L("무게에만 합산되고 수분 계산에서 제외 — 수분이 있는 재료는 액체 재료로."))
        }
    }
}
