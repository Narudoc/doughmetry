import LevainCore
import SwiftUI
import UIKit

/// 도구 탭 — 르방 빌드 계산기 · 물 온도(DDT) 계산기 · 타임라인 (+ 설정 바로가기)
struct ToolsView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        LevainBuildView()
                    } label: {
                        ToolRow(
                            title: L("르방 빌드 계산기"), subtitle: L("필요한 르방을 종 + 밀가루 + 물로 역산"),
                            systemImage: "leaf")
                    }
                    NavigationLink {
                        WaterTemperatureView()
                    } label: {
                        ToolRow(
                            title: L("물 온도 계산기"), subtitle: L("목표 반죽 온도(DDT)에 맞는 물 온도"),
                            systemImage: "thermometer.medium")
                    }
                    NavigationLink {
                        TimelineView()
                    } label: {
                        ToolRow(
                            title: L("타임라인"), subtitle: L("르방 빌드부터 굽기까지 단계별 시각 + 알림"),
                            systemImage: "clock.badge")
                    }
                }
                Section {
                    Button {
                        showSettings = true
                    } label: {
                        ToolRow(
                            title: L("설정"), subtitle: L("언어 · % 표기 · 표시 자릿수 · iCloud"),
                            systemImage: "gearshape"
                        )
                        // .primary(계층 스타일)는 버튼 안에서 틴트가 된다 — 위 도구 행과 같은 색으로
                        .foregroundStyle(Color.primary)
                    }
                }
            }
            .readableFormWidth()
            .navigationTitle(L("도구"))
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
        }
    }
}

/// 도구 목록 행. 접근성 글자 크기에선 아이콘을 윗줄로 올려 제목·설명이 행 폭을 다 쓰게 한다 —
/// 아이콘 옆 좁은 칸에선 긴 낱말(temperature)이 중간에서 끊기고 둘째 줄이 아이콘 밑으로 들어간다
private struct ToolRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.bottle)
                    .accessibilityHidden(true)
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage).foregroundStyle(Color.bottle)
            }
        }
    }
}

private extension View {
    /// 키보드가 떠 있는지 — 결과 바가 편집 중엔 완료 버튼을 보인다.
    /// keyboardDoneButton()과 같이 달지 않는다 (내비게이션 바와 결과 바에 완료가 둘이 된다)
    func trackingKeyboard(_ visible: Binding<Bool>) -> some View {
        self
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in visible.wrappedValue = true }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in visible.wrappedValue = false }
    }
}

// MARK: - 르방 빌드

struct LevainBuildView: View {
    @Environment(AppModel.self) private var model
    @State private var targetGrams: Double = 200
    @State private var targetHydrationPct: Double = 100
    @State private var chefByPercent = true
    @State private var chefPercent: Double = 10
    @State private var chefGrams: Double = 20
    @State private var chefHydrationPct: Double = 100
    @State private var chefSameHydration = true
    @State private var appliedFeedback = false
    @State private var keyboardVisible = false

    private var spec: LevainBuildSpec {
        LevainBuildSpec(
            targetGrams: targetGrams,
            targetHydration: max(0.01, targetHydrationPct / 100),
            chefGrams: chefByPercent ? targetGrams * chefPercent / 100 : chefGrams,
            chefHydration: max(0.01, (chefSameHydration ? targetHydrationPct : chefHydrationPct) / 100))
    }

    var body: some View {
        let result = solveLevainBuild(spec)
        Form {
            Section {
                NumberField(label: L("필요한 르방"), value: $targetGrams)
                NumberField(
                    label: L("르방 수분율"), value: $targetHydrationPct, unit: "%", maxValue: 1000)
                Button {
                    let lev = model.calc.currentDough.levain
                    targetGrams = lev.grams
                    targetHydrationPct = lev.hydration * 100
                } label: {
                    Label(L("계산기 배합에서 가져오기"), systemImage: "arrow.down.doc")
                }
            } header: {
                Text(L("목표"))
            }
            Section {
                Picker(L("종 입력"), selection: $chefByPercent) {
                    Text(L("르방 대비 %")).tag(true)
                    Text(L("그램")).tag(false)
                }
                .pickerStyle(.segmented)
                if chefByPercent {
                    NumberField(label: L("종 비율"), value: $chefPercent, unit: "%", maxValue: 1000)
                } else {
                    NumberField(label: L("종 무게"), value: $chefGrams)
                }
                Toggle(L("종 수분율 = 르방과 같음"), isOn: $chefSameHydration)
                if !chefSameHydration {
                    NumberField(
                        label: L("종 수분율"), value: $chefHydrationPct, unit: "%", maxValue: 1000)
                }
            } header: {
                BilingualLabel(L("종"), fr: "chef")
            } footer: {
                Text(L("종은 이전 르방(스타터)에서 남긴 씨앗입니다. 보통 르방 무게의 10~20%."))
            }
            switch result {
            case .success(let b):
                Section {
                    row(L("종"), b.chef)
                    row(L("밀가루"), b.flour)
                    row(L("물"), b.water)
                    HStack {
                        Text(L("합계")).fontWeight(.semibold)
                        Spacer()
                        StatValue(value: fmtGrams(b.total, model.precision) + " g")
                    }
                    if let r = b.ratio {
                        LabeledContent(L("비율 (종 : 밀가루 : 물)")) {
                            StatValue(value: "1 : \(trim(r.flour)) : \(trim(r.water))", size: 15)
                        }
                    }
                } header: {
                    Text(L("리프레시 배합"))
                } footer: {
                    Text(L("종을 밀가루·물과 섞어 발효시키면 목표 무게·수분율의 르방이 됩니다."))
                }
            case .failure(.chefTooLarge(let maxChef)):
                Section(L("계산 불가")) {
                    Label(L("종이 너무 많습니다 — 밀가루나 물이 음수가 됩니다."), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.danger).font(.footnote)
                    if maxChef.isFinite {
                        Button {
                            chefByPercent = false
                            chefGrams = maxChef
                            appliedFeedback.toggle()
                        } label: {
                            Text(LF("최대 종 적용 — %@ g", fmtGrams(maxChef, model.precision)))
                        }
                    }
                }
            }
            Section {
                NavigationLink {
                    TimelineView(prependLevainBuild: true)
                } label: {
                    Label(L("타임라인에 르방 빌드 넣기 — 피크 알림"), systemImage: "bell.badge")
                }
            } footer: {
                Text(L("완성 시각 기준이면 르방 빌드만큼 시작이 앞당겨져 르방을 먹일 시각이 나옵니다. 시작 시각 기준이면 이후 단계가 그만큼 뒤로 밀립니다."))
            }
        }
        .readableFormWidth()
        .navigationTitle(L("르방 빌드 계산기"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            ResultBar(isEditing: keyboardVisible) {
                switch result {
                case .success(let b):
                    StatChipRow(chips: [
                        StatChip(title: L("종"), value: fmtGrams(b.chef, model.precision) + " g"),
                        StatChip(title: L("밀가루"), value: fmtGrams(b.flour, model.precision) + " g"),
                        StatChip(title: L("물"), value: fmtGrams(b.water, model.precision) + " g"),
                    ])
                case .failure:
                    Label(L("종이 너무 많습니다 — 밀가루나 물이 음수가 됩니다."), systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .trackingKeyboard($keyboardVisible)
        .sensoryFeedback(.impact(weight: .light), trigger: appliedFeedback)
    }

    private func row(_ name: String, _ grams: Double) -> some View {
        HStack {
            Text(name)
            Spacer()
            StatValue(value: fmtGrams(grams, model.precision) + " g")
        }
    }

    private func trim(_ x: Double) -> String {
        x == x.rounded() ? String(format: "%.0f", x) : String(format: "%.1f", x)
    }
}

// MARK: - 물 온도 (DDT)

struct WaterTemperatureView: View {
    @Environment(AppModel.self) private var model
    // 저장값과 계산은 늘 °C — °F는 보이고 받는 쪽에서만 바꾼다 (단위를 오가도 값이 흐르지 않게)
    @AppStorage("ddt.desired") private var desired: Double = 25
    @AppStorage("ddt.flour") private var flourTemp: Double = 22
    @AppStorage("ddt.room") private var roomTemp: Double = 24
    @AppStorage("ddt.useLevain") private var useLevain = true
    @AppStorage("ddt.levain") private var levainTemp: Double = 24
    @AppStorage("ddt.friction") private var friction: Double = 2
    /// "c" / "f"
    @AppStorage("ddt.unit") private var unit: String = WaterTemperatureView.defaultUnit

    /// 처음엔 기기 지역·온도 단위 설정을 따른다. 환경의 \.locale은 인앱 언어 선택으로 다시 만든 것이라
    /// 사용자의 온도 단위 설정이 빠져 있어 쓰지 않는다
    static let defaultUnit = UnitTemperature(forLocale: .autoupdatingCurrent) == .fahrenheit ? "f" : "c"

    /// 마찰계수 프리셋 — '직접'(2)도 실제 선택 가능하도록 @State로 유지하고 값 변경과 동기화한다
    @State private var frictionSel = 0
    @State private var keyboardVisible = false

    private var isFahrenheit: Bool { unit == "f" }
    private var unitSymbol: String { isFahrenheit ? "°F" : "°C" }

    private func applyFrictionPreset(_ sel: Int) {
        if sel == 0 { friction = 2 }
        if sel == 1 { friction = 8 }
    }

    private func syncFrictionPreset(_ f: Double) {
        // °F로 입력한 값은 °C로 돌아오며 끝자리가 어긋난다(3.6 °F → 1.9999…) — 같음 비교 대신 오차 허용
        let sel: Int
        if abs(f - 2) < 1e-6 {
            sel = 0
        } else if abs(f - 8) < 1e-6 {
            sel = 1
        } else {
            sel = 2
        }
        frictionSel = sel
    }

    /// 절대 온도 칸 (°C 저장값 ↔ 표시 단위)
    private func temperature(_ celsiusValue: Binding<Double>) -> Binding<Double> {
        Binding(
            get: {
                isFahrenheit ? tidy(fahrenheit(fromCelsius: celsiusValue.wrappedValue)) : celsiusValue.wrappedValue
            },
            set: { celsiusValue.wrappedValue = isFahrenheit ? celsius(fromFahrenheit: $0) : $0 })
    }

    /// 마찰계수 칸 — 온도 차라 ×1.8만 하고 32를 더하지 않는다
    private func temperatureDelta(_ celsiusValue: Binding<Double>) -> Binding<Double> {
        Binding(
            get: {
                isFahrenheit
                    ? tidy(fahrenheitDelta(fromCelsius: celsiusValue.wrappedValue)) : celsiusValue.wrappedValue
            },
            set: { celsiusValue.wrappedValue = isFahrenheit ? celsiusDelta(fromFahrenheit: $0) : $0 })
    }

    /// 환산 끝자리 오차를 걷는다 — 25 °C가 "77.0"이 아니라 "77"로 보이고, 입력 칸이 쓴 값을 그대로 다시 읽는다
    private func tidy(_ x: Double) -> Double {
        abs(x) < 1e6 ? (x * 1e9).rounded() / 1e9 : x
    }

    /// 안내 문구의 °C 기준 수치를 표시 단위의 정수로 (24 °C → 75 °F, 마찰 2 °C → 4 °F)
    private func hint(_ c: Double, delta: Bool = false) -> Int {
        guard isFahrenheit else { return Int(c) }
        return Int((delta ? fahrenheitDelta(fromCelsius: c) : fahrenheit(fromCelsius: c)).rounded())
    }

    private func fmtTemp(_ c: Double) -> String {
        String(format: "%.1f %@", isFahrenheit ? fahrenheit(fromCelsius: c) : c, unitSymbol)
    }

    var body: some View {
        let water = solveWaterTemperature(
            WaterTemperatureSpec(
                desiredDoughTemp: desired, flourTemp: flourTemp, roomTemp: roomTemp,
                levainTemp: useLevain ? levainTemp : nil, frictionFactor: friction))
        Form {
            Section {
                // 입력 중인 칸을 먼저 닫는다 — 열린 칸은 바뀐 단위로 다시 쓴 글자(소수 한 자리)를 저장값으로 되읽는다
                Picker(
                    L("온도 단위"),
                    selection: Binding(
                        get: { unit },
                        set: { newUnit in
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            unit = newUnit
                        })
                ) {
                    Text("°C").tag("c")
                    Text("°F").tag("f")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(L("온도 단위"))
                NumberField(
                    label: L("목표 반죽 온도 (DDT)"), value: temperature($desired), unit: unitSymbol,
                    fractionDigits: 1)
            } footer: {
                Text(LF("사워도우는 보통 %d~%d%@. 벌크 발효 속도를 좌우하는 가장 중요한 변수입니다.", hint(24), hint(26), unitSymbol))
            }
            Section(L("현재 온도")) {
                NumberField(label: L("밀가루"), value: temperature($flourTemp), unit: unitSymbol, fractionDigits: 1)
                NumberField(label: L("실온"), value: temperature($roomTemp), unit: unitSymbol, fractionDigits: 1)
                Toggle(L("르방 사용"), isOn: $useLevain)
                if useLevain {
                    NumberField(
                        label: L("르방"), value: temperature($levainTemp), unit: unitSymbol, fractionDigits: 1)
                }
            }
            Section {
                Picker(L("마찰계수"), selection: $frictionSel) {
                    Text(L("손반죽")).tag(0)
                    Text(L("스탠드 믹서")).tag(1)
                    Text(L("직접")).tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: frictionSel) { _, sel in applyFrictionPreset(sel) }
                .onChange(of: friction, initial: true) { _, f in syncFrictionPreset(f) }
                NumberField(
                    label: L("마찰계수"), value: temperatureDelta($friction), unit: unitSymbol, fractionDigits: 1)
            } footer: {
                Text(
                    LF(
                        "믹싱 마찰로 오르는 온도. 손반죽 %d~%d%@, 스탠드 믹서 %d~%d%@ — 본인 환경에 맞게 조정하세요.",
                        hint(1, delta: true), hint(2, delta: true), unitSymbol,
                        hint(6, delta: true), hint(10, delta: true), unitSymbol))
            }
            Section {
                LabeledContent {
                    StatValue(value: fmtTemp(water), size: 22)
                } label: {
                    BilingualLabel(L("사용할 물 온도"), fr: "température de l'eau")
                        .fontWeight(.semibold)
                }
                // 경고 기준은 °C로 비교한다 — 단위를 바꿔도 같은 물 온도에서 뜬다
                if water < 4 {
                    Label(L("얼음물이 필요합니다 — 얼음을 넣어 물 온도를 맞추세요."), systemImage: "snowflake")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if water > 40 {
                    Label(tooHotMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Color.danger)
                }
            } header: {
                Text(L("결과"))
            } footer: {
                Text(useLevain
                    ? L("물 온도 = DDT × 4 − (밀가루 + 실온 + 르방 + 마찰계수)")
                    : L("물 온도 = DDT × 3 − (밀가루 + 실온 + 마찰계수)"))
            }
        }
        .readableFormWidth()
        .navigationTitle(L("물 온도 계산기"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            ResultBar(isEditing: keyboardVisible) {
                HStack(spacing: 12) {
                    StatChip(title: L("사용할 물 온도"), value: fmtTemp(water), emphasized: true)
                    if water < 4 {
                        Image(systemName: "snowflake")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(L("얼음물이 필요합니다 — 얼음을 넣어 물 온도를 맞추세요."))
                    } else if water > 40 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.danger)
                            .accessibilityLabel(tooHotMessage)
                    }
                }
            }
        }
        .trackingKeyboard($keyboardVisible)
    }

    private var tooHotMessage: String {
        LF("너무 뜨겁습니다 — %d%@ 이상은 르방 활성을 해칠 수 있습니다.", hint(40), unitSymbol)
    }
}
