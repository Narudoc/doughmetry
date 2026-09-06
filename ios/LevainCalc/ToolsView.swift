import LevainCore
import SwiftUI

/// 도구 탭 — 르방 빌드 계산기 · 물 온도(DDT) 계산기
struct ToolsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    LevainBuildView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("르방 빌드 계산기"))
                            Text(L("필요한 르방을 종 + 밀가루 + 물로 역산"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "leaf").foregroundStyle(Color.bottle)
                    }
                }
                NavigationLink {
                    WaterTemperatureView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("물 온도 계산기"))
                            Text(L("목표 반죽 온도(DDT)에 맞는 물 온도"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "thermometer.medium").foregroundStyle(Color.bottle)
                    }
                }
                NavigationLink {
                    TimelineView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("타임라인"))
                            Text(L("오토리즈부터 굽기까지 단계별 시각 + 알림"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "clock.badge").foregroundStyle(Color.bottle)
                    }
                }
            }
            .navigationTitle(L("도구"))
        }
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
                NumberField(label: L("르방 수분율"), value: $targetHydrationPct, unit: "%", fractionDigits: 0)
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
                    NumberField(label: L("종 비율"), value: $chefPercent, unit: "%", fractionDigits: 0)
                } else {
                    NumberField(label: L("종 무게"), value: $chefGrams)
                }
                Toggle(L("종 수분율 = 르방과 같음"), isOn: $chefSameHydration)
                if !chefSameHydration {
                    NumberField(label: L("종 수분율"), value: $chefHydrationPct, unit: "%", fractionDigits: 0)
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
        }
        .navigationTitle(L("르방 빌드 계산기"))
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .scrollDismissesKeyboard(.interactively)
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
    @AppStorage("ddt.desired") private var desired: Double = 25
    @AppStorage("ddt.flour") private var flourTemp: Double = 22
    @AppStorage("ddt.room") private var roomTemp: Double = 24
    @AppStorage("ddt.useLevain") private var useLevain = true
    @AppStorage("ddt.levain") private var levainTemp: Double = 24
    @AppStorage("ddt.friction") private var friction: Double = 2

    private var frictionPreset: Int {
        friction == 2 ? 0 : friction == 8 ? 1 : 2
    }

    var body: some View {
        let water = solveWaterTemperature(
            WaterTemperatureSpec(
                desiredDoughTemp: desired, flourTemp: flourTemp, roomTemp: roomTemp,
                levainTemp: useLevain ? levainTemp : nil, frictionFactor: friction))
        Form {
            Section {
                NumberField(label: L("목표 반죽 온도 (DDT)"), value: $desired, unit: "°C", fractionDigits: 1)
            } footer: {
                Text(L("사워도우는 보통 24~26°C. 벌크 발효 속도를 좌우하는 가장 중요한 변수입니다."))
            }
            Section(L("현재 온도")) {
                NumberField(label: L("밀가루"), value: $flourTemp, unit: "°C", fractionDigits: 1)
                NumberField(label: L("실온"), value: $roomTemp, unit: "°C", fractionDigits: 1)
                Toggle(L("르방 사용"), isOn: $useLevain)
                if useLevain {
                    NumberField(label: L("르방"), value: $levainTemp, unit: "°C", fractionDigits: 1)
                }
            }
            Section {
                Picker(
                    L("마찰계수"),
                    selection: Binding(
                        get: { frictionPreset },
                        set: { v in
                            if v == 0 { friction = 2 }
                            if v == 1 { friction = 8 }
                        })
                ) {
                    Text(L("손반죽")).tag(0)
                    Text(L("스탠드 믹서")).tag(1)
                    Text(L("직접")).tag(2)
                }
                .pickerStyle(.segmented)
                NumberField(label: L("마찰계수"), value: $friction, unit: "°C", fractionDigits: 1)
            } footer: {
                Text(L("믹싱 마찰로 오르는 온도. 손반죽 1~2°C, 스탠드 믹서 6~10°C — 본인 환경에 맞게 조정하세요."))
            }
            Section {
                HStack {
                    BilingualLabel(L("사용할 물 온도"), fr: "température de l'eau")
                        .fontWeight(.semibold)
                    Spacer()
                    StatValue(value: String(format: "%.1f °C", water), size: 22)
                }
                if water < 4 {
                    Label(L("얼음물이 필요합니다 — 얼음을 넣어 물 온도를 맞추세요."), systemImage: "snowflake")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if water > 40 {
                    Label(L("너무 뜨겁습니다 — 40°C 이상은 르방 활성을 해칠 수 있습니다."), systemImage: "exclamationmark.triangle")
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
        .navigationTitle(L("물 온도 계산기"))
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .scrollDismissesKeyboard(.interactively)
    }
}
