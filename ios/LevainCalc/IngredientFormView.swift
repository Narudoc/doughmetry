import LevainCore
import SwiftUI

/// 모드 A 재료 입력 폼 — 계산기·변환기(원본 편집) 공용.
/// Form 안에서 여러 Section으로 렌더링된다.
struct IngredientFormSections: View {
    @Binding var input: DoughInput
    let stats: DoughStats
    let precision: Precision
    let basis: PctBasis

    /// footer의 % 기준 메뉴가 바꾸는 앱 설정 (설정 시트의 "% 표기"와 같은 값)
    @Environment(AppModel.self) private var model
    /// 입력 옆 % 열 — StatValue(14pt)와 같은 비율로 넓혀야 큰 글자에서 숫자가 끊기지 않는다
    @ScaledMetric(relativeTo: .subheadline) private var pctWidth: CGFloat = 60
    /// 이름 칸 옆 그램 + % 열 — 그램 칸이 소금 행 등 라벨 있는 행의 입력 칸과 같은 세로줄에 서도록
    @ScaledMetric(relativeTo: .body) private var gramsColumnWidth: CGFloat = 204
    /// 큰 글자에서 그램 열이 넓어져도 이름 칸이 이만큼은 남는다 (그램 열이 대신 줄어든다)
    @ScaledMetric(relativeTo: .subheadline) private var nameMinWidth: CGFloat = 72
    /// 액체 행의 "수분 x g" 열 — 값 폭(0.0 g ↔ 176.0 g)에 따라 수분 함량 칸이 옆으로 밀리지 않도록 폭을 고정한다.
    /// 더 넓은 값은 열을 넓히지 않고 StatValue가 글자를 줄인다
    @ScaledMetric(relativeTo: .footnote) private var waterColumnWidth: CGFloat = 84
    @Environment(\.dynamicTypeSize) private var typeSize

    /// 접근성 글자 크기에선 입력 옆 보조 수치를 아랫줄로 — 한 줄에 두면 입력 칸이 화면 밖으로 밀린다
    private var rowLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 2)) : AnyLayout(HStackLayout())
    }

    /// 이름 | 그램 | % 한 줄 (접근성 글자 크기에선 이름을 윗줄로). ViewThatFits를 쓰지 않는다 —
    /// 이름을 칠 때마다 가지가 바뀌면 입력 중인 칸이 새로 만들어져 키보드·포커스를 잃는다
    private var nameRowLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))
    }

    private var gramsColumn: CGFloat? { typeSize.isAccessibilitySize ? nil : gramsColumnWidth }

    /// 행 구분선은 행 안 첫 Text(그램 칸의 단위 "g")에 맞춰지므로 행 앞에서 시작하도록 고정
    private func nameRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        nameRowLayout(content)
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }

    private func nameField(_ placeholder: String, text: Binding<String>, label: String) -> some View {
        TextField(placeholder, text: text)
            .accessibilityLabel(label)
            .font(.subheadline)
            .lineLimit(1)
            .frame(minWidth: nameMinWidth, maxWidth: .infinity, alignment: .leading)
    }

    private var basisName: String {
        basis == .totalFlour ? L("총 밀가루 기준") : L("베이커스 퍼센트")
    }

    /// % 기준 바꾸기 — 숫자를 보는 자리에서. 한 번 눌러 뒤집히는 토글이 아니라 메뉴 속 선택이라
    /// 지금 기준이 늘 보이고 실수로 바뀌지 않는다
    private var basisMenu: some View {
        Menu {
            Picker(L("% 표기"), selection: Binding(get: { basis }, set: { model.pctBasis = $0 })) {
                Text(L("총 밀가루 기준")).tag(PctBasis.totalFlour)
                Text(L("베이커스 퍼센트")).tag(PctBasis.addedFlour)
            }
        } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    // 한 줄 라벨은 접혀 가운데로 모이고 화살표가 글 가운데에 낀다 — 이름과 기준을 두 줄로
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("% 표기"))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(basisName)
                            Image(systemName: "chevron.up.chevron.down")
                                .imageScale(.small)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 4) {
                        Text(L("% 표기") + ": " + basisName)
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                    }
                }
            }
            .font(.footnote.weight(.medium))
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L("% 표기"))
        .accessibilityValue(basisName)
    }

    private func pctRow<Field: View>(
        _ pct: Double, levain: Bool = false, @ViewBuilder field: () -> Field
    ) -> some View {
        rowLayout {
            field()
            StatValue(value: fmtPct(pct), size: 14)
                .frame(width: typeSize.isAccessibilitySize ? nil : pctWidth, alignment: .trailing)
                .accessibilityLabel(spokenPct(pct, levain: levain))
        }
    }

    /// 화면의 "%"만으론 무엇의 몇 %인지 알 수 없다 — VoiceOver엔 기준을 붙여 읽는다
    private func spokenPct(_ pct: Double, levain: Bool) -> String {
        let p = fmtPct(pct)
        switch (levain, basis) {
        case (true, .totalFlour): return LF("PFF %@ — 총 밀가루 중 르방 속 밀가루", p)
        case (true, .addedFlour): return LF("르방, 첨가 밀가루의 %@", p)
        case (false, .totalFlour): return LF("총 밀가루의 %@", p)
        case (false, .addedFlour): return LF("첨가 밀가루의 %@", p)
        }
    }

    /// 목표 역산이 붙인 이름 "밀가루"는 flourLabel처럼 앱 언어로 보인다 — 저장값은 사용자가 고칠 때만 바뀐다
    private func flourNameBinding(_ name: Binding<String>) -> Binding<String> {
        Binding(
            get: { name.wrappedValue == "밀가루" ? L("밀가루") : name.wrappedValue },
            set: { name.wrappedValue = $0 })
    }

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
                nameRow {
                    nameField(
                        L("밀가루 (T65…)"), text: flourNameBinding($flour.name),
                        label: L("밀가루 이름 (T65, 호밀…)"))
                    pctRow(stats.uiPct(grams: flour.grams, basis: basis)) {
                        NumberField(
                            label: "", value: $flour.grams,
                            accessibilityName: flourLabel(flour))
                        .accessibilityIdentifier("ingredient.flourGrams")
                    }
                    .frame(maxWidth: gramsColumn)
                    .layoutPriority(1)
                }
                // onDelete의 시스템 "삭제"는 앱 언어가 아니라 번들 현지화를 따른다.
                // 앱 전체 tint(bottle)가 destructive의 빨강을 덮으므로 색을 직접 준다
                .swipeActions {
                    Button(L("삭제"), role: .destructive) { [id = flour.id] in
                        input.flours.removeAll { $0.id == id }
                    }
                    .tint(Color.danger)
                }
            }
            Button {
                input.flours.append(Flour(name: "", grams: 0))
            } label: {
                Label(L("밀가루 추가"), systemImage: "plus.circle")
            }
        } header: {
            Text(L("밀가루 (첨가)"))
        } footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    basis == .addedFlour
                        ? L("%는 첨가 밀가루 기준(베이커스 퍼센트)입니다.")
                        : L("%는 총 밀가루(첨가 + 르방 속) 기준입니다."))
                basisMenu
            }
        }
        // iOS 17/18은 섹션 머리말을 대문자로 바꾼다 ("FLOUR (ADDED)") — 섹션마다 직접 달아야 듣는다
        // (Form이나 머리말 Text 하나에 달면 17.5가 무시한다). 아래 섹션들도 같다
        .textCase(nil)
    }

    // MARK: 물·바시나주·소금

    private var waterSection: some View {
        Section(L("물 · 소금")) {
            NumberField(label: L("본반죽 물"), value: $input.water)
                .accessibilityIdentifier("ingredient.water")
            VStack(alignment: .leading, spacing: 2) {
                NumberField(label: L("바시나주"), value: $input.bassinage)
                Text(L("bassinage — 본반죽 후 추가하는 물"))
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            pctRow(stats.uiPct(grams: input.salt, basis: basis)) {
                NumberField(label: L("소금"), value: $input.salt)
            }
        }
        .textCase(nil)
    }

    // MARK: 르방

    /// 프리셋 선택 — '직접'(2)도 실제 선택 가능하도록 @State로 유지하고
    /// 수분율 변경(불러오기·직접 입력)과 동기화한다
    @State private var levainPresetSel = 0

    private func applyLevainPreset(_ sel: Int) {
        if sel == 0 { setLevainHydration(1) }
        if sel == 1 { setLevainHydration(0.5) }
    }

    private func syncLevainPreset(_ hydration: Double) {
        let sel: Int
        if hydration == 1 {
            sel = 0
        } else if hydration == 0.5 {
            sel = 1
        } else {
            sel = 2
        }
        levainPresetSel = sel
    }

    private var levainPresetPicker: some View {
        let names = [L("리퀴드 100%"), L("뒤흐 50%"), L("직접")]
        let picker = Picker(L("르방 종류"), selection: $levainPresetSel) {
            ForEach(names.indices, id: \.self) { i in
                Text(names[i]).tag(i)
            }
        }
        return picker
            .adaptiveSegmented(L("르방 종류"), value: names[levainPresetSel])
            .onChange(of: levainPresetSel) { _, sel in applyLevainPreset(sel) }
            .onChange(of: input.levain.hydration, initial: true) { _, h in syncLevainPreset(h) }
    }

    private func setLevainHydration(_ h: Double) {
        input.levain.hydration = h
        input.levain.type = levainTypeFor(hydration: h)
    }

    /// 비율 → % 입력값. ×100 부동소수 잡음(0.575 × 100 = 57.4999…)을 걷어내야
    /// 포커스 해제 후 57.5가 57로 보이지 않는다
    private func pctFromRatio(_ ratio: Double) -> Double {
        (ratio * 100 * 1e9).rounded() / 1e9
    }

    private var levainSection: some View {
        Section {
            levainPresetPicker
            pctRow(stats.uiLevainPct(levainGrams: input.levain.grams, basis: basis), levain: true) {
                NumberField(label: L("르방 무게"), value: $input.levain.grams)
            }
            NumberField(
                label: L("수분율"),
                value: Binding(
                    get: { pctFromRatio(input.levain.hydration) },
                    set: { setLevainHydration(max(0.01, $0 / 100)) }),
                unit: "%", maxValue: 1000, accessibilityName: L("르방 수분율"))
            TextField(
                L("르방 밀가루 (표시용)"),
                text: Binding(
                    get: { input.levain.flourName ?? "" },
                    set: { input.levain.flourName = $0.isEmpty ? nil : $0 }))
                .accessibilityLabel(L("르방 밀가루 (표시용)"))
                .font(.subheadline)
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 16))) {
                HStack(spacing: 4) {
                    Text(L("속 밀가루")).font(.caption).foregroundStyle(.secondary)
                    StatValue(value: fmtGrams(stats.levainFlour, precision) + " g", size: 13)
                }
                .accessibilityElement(children: .combine)
                HStack(spacing: 4) {
                    Text(L("속 물")).font(.caption).foregroundStyle(.secondary)
                    StatValue(value: fmtGrams(stats.levainWater, precision) + " g", size: 13)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            BilingualLabel(
                L("르방"),
                fr: levainFr(input.levain.hydration))
        } footer: {
            // PFF(10%)와 르방 무게 비율(22%)을 헷갈리는 자리라 여기서도 기준을 바꿀 수 있게
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    basis == .addedFlour
                        ? L("%는 첨가 밀가루 대비 르방 무게입니다.")
                        : L("%는 PFF — 총 밀가루 중 르방 속 밀가루의 비율."))
                basisMenu
            }
        }
        .textCase(nil)
    }

    // MARK: 액체 재료

    private var liquidsSection: some View {
        Section {
            ForEach($input.liquids) { $liquid in
                let liquidName = liquid.name.isEmpty ? L("액체") : liquid.name
                VStack(alignment: .leading, spacing: 6) {
                    nameRowLayout {
                        nameField(L("이름"), text: $liquid.name, label: L("액체 재료 이름"))
                        NumberField(label: "", value: $liquid.grams, accessibilityName: liquidName)
                            .frame(maxWidth: gramsColumn)
                            .layoutPriority(1)
                    }
                    rowLayout {
                        NumberField(
                            label: L("수분 함량"),
                            value: Binding(
                                get: { pctFromRatio(liquid.waterRatio) },
                                set: { liquid.waterRatio = min(1, max(0, $0 / 100)) }),
                            unit: "%", accessibilityName: LF("%@ 수분 함량", liquidName))
                        HStack(spacing: 4) {
                            Text(L("수분")).font(.caption).foregroundStyle(.secondary).fixedSize()
                            StatValue(
                                value: fmtGrams(liquid.grams * liquid.waterRatio, precision) + " g",
                                size: 13)
                        }
                        .frame(
                            width: typeSize.isAccessibilitySize ? nil : waterColumnWidth,
                            alignment: .trailing)
                        .accessibilityElement(children: .combine)
                    }
                }
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                .swipeActions {
                    Button(L("삭제"), role: .destructive) { [id = liquid.id] in
                        input.liquids.removeAll { $0.id == id }
                    }
                    .tint(Color.danger)
                }
            }
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
                AddMenuLabel(title: L("액체 재료 추가"))
            }
        } header: {
            Text(L("액체 재료"))
        } footer: {
            Text(L("우유·계란 등 — 수분율만큼 총 물에 반영됩니다 (USDA 기준: 우유 88%, 계란 76%)."))
        }
        .textCase(nil)
    }

    // MARK: 이스트

    private var yeastSection: some View {
        Section {
            // 환산은 사용자가 피커를 조작했을 때만 — 레시피 불러오기 등
            // 상태가 통째로 바뀔 때 이미 타입 기준인 무게를 재환산하면 안 된다
            Picker(
                L("이스트 종류"),
                selection: Binding(
                    get: { input.yeast.type },
                    set: { newType in
                        let oldType = input.yeast.type
                        guard newType != oldType else { return }
                        input.yeast.grams = convertYeast(
                            input.yeast.grams, from: oldType, to: newType)
                        input.yeast.type = newType
                    })
            ) {
                Text(L("생이스트")).tag(YeastType.fresh)
                Text(L("인스턴트")).tag(YeastType.instant)
            }
            .adaptiveSegmented(
                L("이스트 종류"), value: input.yeast.type == .fresh ? L("생이스트") : L("인스턴트"))
            pctRow(stats.uiPct(grams: input.yeast.grams, basis: basis)) {
                NumberField(label: L("투입량"), value: $input.yeast.grams)
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
        .textCase(nil)
    }

    // MARK: 기타 재료

    private var extrasSection: some View {
        Section {
            ForEach($input.extras) { $extra in
                nameRow {
                    nameField(L("재료 (호두…)"), text: $extra.name, label: L("이름 (호두, 건포도…)"))
                    pctRow(stats.uiPct(grams: extra.grams, basis: basis)) {
                        NumberField(
                            label: "", value: $extra.grams,
                            accessibilityName: extra.name.isEmpty ? L("기타 재료") : extra.name)
                    }
                    .frame(maxWidth: gramsColumn)
                    .layoutPriority(1)
                }
                .swipeActions {
                    Button(L("삭제"), role: .destructive) { [id = extra.id] in
                        input.extras.removeAll { $0.id == id }
                    }
                    .tint(Color.danger)
                }
            }
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
        .textCase(nil)
    }
}
