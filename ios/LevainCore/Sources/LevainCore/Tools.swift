import Foundation

// MARK: - 르방 빌드 계산기

/// 필요한 르방 L(수분율 h)을 종(chef) C(수분율 hc)로부터 만들 때 넣을 밀가루·물.
///
/// F = L/(1+h), W = L − F ; 종의 밀가루 Fc = C/(1+hc), 물 Wc = C − Fc
/// 첨가 밀가루 = F − Fc, 첨가 물 = W − Wc — 둘 다 0 이상이어야 한다.
public struct LevainBuildSpec: Equatable, Sendable {
    public var targetGrams: Double // L
    public var targetHydration: Double // h (소수)
    public var chefGrams: Double // C
    public var chefHydration: Double // hc (소수)

    public init(targetGrams: Double, targetHydration: Double, chefGrams: Double, chefHydration: Double) {
        self.targetGrams = targetGrams
        self.targetHydration = targetHydration
        self.chefGrams = chefGrams
        self.chefHydration = chefHydration
    }
}

public struct LevainBuild: Equatable, Sendable {
    public var chef: Double
    public var flour: Double
    public var water: Double
    /// 종 대비 비율 1 : flour/chef : water/chef (종이 0이면 nil)
    public var ratio: (flour: Double, water: Double)? {
        chef > 1e-9 ? (flour / chef, water / chef) : nil
    }
    public var total: Double { chef + flour + water }

    public static func == (a: LevainBuild, b: LevainBuild) -> Bool {
        a.chef == b.chef && a.flour == b.flour && a.water == b.water
    }
}

public enum LevainBuildError: Error, Equatable, Sendable {
    /// 종이 너무 많아 밀가루/물이 음수 — 종의 최대 허용량을 함께 알려준다
    case chefTooLarge(maxChefGrams: Double)
}

public func solveLevainBuild(_ s: LevainBuildSpec) -> Result<LevainBuild, LevainBuildError> {
    let flourTotal = s.targetGrams / (1 + s.targetHydration)
    let waterTotal = s.targetGrams - flourTotal
    let chefFlour = s.chefGrams / (1 + s.chefHydration)
    let chefWater = s.chefGrams - chefFlour
    let flour = flourTotal - chefFlour
    let water = waterTotal - chefWater
    if flour < -1e-9 || water < -1e-9 {
        // 밀가루 한도: C ≤ F·(1+hc) ; 물 한도: C·hc/(1+hc) ≤ W → C ≤ W·(1+hc)/hc
        let byFlour = flourTotal * (1 + s.chefHydration)
        let byWater = s.chefHydration > 1e-9
            ? waterTotal * (1 + s.chefHydration) / s.chefHydration : Double.infinity
        return .failure(.chefTooLarge(maxChefGrams: min(byFlour, byWater)))
    }
    return .success(LevainBuild(chef: s.chefGrams, flour: max(0, flour), water: max(0, water)))
}

// MARK: - 물 온도 (DDT) 계산기

/// 목표 반죽 온도(DDT)에서 사용할 물 온도를 역산.
/// 물 온도 = DDT × N − (밀가루 온도 + 실온 + [르방 온도] + 마찰계수), N = 반영한 온도 항 수(3 또는 4).
public struct WaterTemperatureSpec: Equatable, Sendable {
    public var desiredDoughTemp: Double
    public var flourTemp: Double
    public var roomTemp: Double
    /// 르방(사전반죽)을 쓰면 온도, 아니면 nil
    public var levainTemp: Double?
    /// 믹싱 중 마찰로 오르는 온도 — 손반죽 ≈ 1~2°C, 스탠드 믹서 ≈ 6~10°C
    public var frictionFactor: Double

    public init(
        desiredDoughTemp: Double, flourTemp: Double, roomTemp: Double,
        levainTemp: Double? = nil, frictionFactor: Double
    ) {
        self.desiredDoughTemp = desiredDoughTemp
        self.flourTemp = flourTemp
        self.roomTemp = roomTemp
        self.levainTemp = levainTemp
        self.frictionFactor = frictionFactor
    }
}

public func solveWaterTemperature(_ s: WaterTemperatureSpec) -> Double {
    let factors = s.levainTemp == nil ? 3.0 : 4.0
    let known = s.flourTemp + s.roomTemp + (s.levainTemp ?? 0) + s.frictionFactor
    return s.desiredDoughTemp * factors - known
}
