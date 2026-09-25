import Foundation

/// 사워도우 반죽 계산 — 순수 함수 모듈. (src/lib/dough.ts 이식)
///
/// 규칙: 수분율·소금·PFF는 모두 총 밀가루(F_total = 첨가 밀가루 + 르방 속 밀가루) 기준.
/// 총 물 = 본반죽 물 + 바시나주 + 르방 속 물 + 액체 재료의 수분 (grams × waterRatio).
/// 내부 계산은 full precision으로 하고, 반올림은 표시 계층(Format.swift)에서만 한다.

public let defaultLevainHydration: [LevainType: Double] = [
    .liquide: 1,
    .dur: 0.5,
]

/// 액체 재료 수분율 프리셋 (소수). 출처: USDA FoodData Central per 100g
public enum LiquidPreset: CaseIterable, Sendable {
    case milk
    case egg

    public var name: String {
        switch self {
        case .milk: return "우유"
        case .egg: return "계란"
        }
    }

    public var waterRatio: Double {
        switch self {
        case .milk: return 0.88 // 전유 3.25% milkfat: 물 88.1g/100g
        case .egg: return 0.76 // 전란 생: 물 76.15g/100g
        }
    }
}

/// 인스턴트 드라이 이스트 = 생이스트 × 0.4
public let idyFactor = 0.4

public func convertYeast(_ grams: Double, from: YeastType, to: YeastType) -> Double {
    if from == to { return grams }
    return from == .fresh ? grams * idyFactor : grams / idyFactor
}

/// 수분율로 르방 타입 라벨을 정한다 (경계 0.75).
public func levainTypeFor(hydration: Double) -> LevainType {
    hydration >= 0.75 ? .liquide : .dur
}

let eps = 1e-9

/// 부동소수점 잔차(−eps < x < 0)만 0으로. 그보다 큰 음수는 불가능한 배합이므로 그대로 둔다 —
/// UI의 −1e-9 가드가 저장을 막고 부족한 그램을 보여 줘야 한다. (dough.ts snapTinyNegative와 동일)
func snapTinyNegative(_ x: Double) -> Double {
    x < 0 && x > -eps ? 0 : x
}

public func addedFlourTotal(_ input: DoughInput) -> Double {
    input.flours.reduce(0) { $0 + $1.grams }
}

/// F_lev = L / (1 + h), W_lev = L − F_lev
public func levainBreakdown(grams: Double, hydration: Double) -> (flour: Double, water: Double) {
    let flour = grams / (1 + hydration)
    return (flour, grams - flour)
}

public struct DoughStats: Equatable, Sendable {
    public var levainFlour: Double // F_lev
    public var levainWater: Double // W_lev
    public var liquidWater: Double // Σ liquid.grams × waterRatio
    public var totalFlour: Double // F_total
    public var totalWater: Double // W_total = 본반죽 물 + 바시나주 + W_lev + 액체 수분
    public var hydrationPct: Double // H = W_total / F_total × 100
    public var saltPct: Double
    public var pffPct: Double
    public var yeastPct: Double
    public var doughWeight: Double // 모든 재료 무게 합
    /// id → 총 밀가루 대비 % (밀가루·액체·기타 공용)
    public var pcts: [String: Double]

    public func pct(_ id: String) -> Double { pcts[id] ?? 0 }
}

public func computeStats(_ input: DoughInput) -> DoughStats {
    let (levainFlour, levainWater) = levainBreakdown(
        grams: input.levain.grams, hydration: input.levain.hydration)
    let addedFlour = addedFlourTotal(input)
    let liquidWater = input.liquids.reduce(0) { $0 + $1.grams * $1.waterRatio }
    let liquidsTotal = input.liquids.reduce(0) { $0 + $1.grams }
    let extrasTotal = input.extras.reduce(0) { $0 + $1.grams }
    let totalFlour = addedFlour + levainFlour
    let totalWater = input.water + input.bassinage + levainWater + liquidWater
    let doughWeight =
        addedFlour + input.water + input.bassinage + input.levain.grams + input.salt
        + liquidsTotal + input.yeast.grams + extrasTotal
    func pctOfFlour(_ g: Double) -> Double { totalFlour > eps ? g / totalFlour * 100 : 0 }

    var pcts: [String: Double] = [:]
    for f in input.flours { pcts[f.id] = pctOfFlour(f.grams) }
    for l in input.liquids { pcts[l.id] = pctOfFlour(l.grams) }
    for e in input.extras { pcts[e.id] = pctOfFlour(e.grams) }

    return DoughStats(
        levainFlour: levainFlour,
        levainWater: levainWater,
        liquidWater: liquidWater,
        totalFlour: totalFlour,
        totalWater: totalWater,
        hydrationPct: pctOfFlour(totalWater),
        saltPct: pctOfFlour(input.salt),
        pffPct: pctOfFlour(levainFlour),
        yeastPct: pctOfFlour(input.yeast.grams),
        doughWeight: doughWeight,
        pcts: pcts
    )
}

// MARK: - 모드 B (목표 역산)

/// 모드 B — 목표 반죽 무게에서 역산. 비율 값은 전부 소수(0.72 = 72%).
/// v2에서도 밀가루·물·소금·르방만 역산한다 (바시나주·액체·이스트는 모드 A에서).
public struct TargetSpec: Sendable {
    public var doughWeight: Double
    public var hydration: Double
    public var saltRatio: Double
    public var pff: Double
    public var levainHydration: Double
    public var othersRatio: Double

    public init(
        doughWeight: Double, hydration: Double, saltRatio: Double, pff: Double,
        levainHydration: Double, othersRatio: Double = 0
    ) {
        self.doughWeight = doughWeight
        self.hydration = hydration
        self.saltRatio = saltRatio
        self.pff = pff
        self.levainHydration = levainHydration
        self.othersRatio = othersRatio
    }
}

public func solveFromTarget(_ spec: TargetSpec) -> DoughInput {
    let totalFlour = spec.doughWeight / (1 + spec.hydration + spec.saltRatio + spec.othersRatio)
    let levainFlour = spec.pff * totalFlour
    let levainGrams = levainFlour * (1 + spec.levainHydration)
    let levainWater = levainGrams - levainFlour
    return DoughInput(
        flours: [Flour(name: "밀가루", grams: snapTinyNegative(totalFlour - levainFlour))],
        water: snapTinyNegative(spec.hydration * totalFlour - levainWater),
        salt: spec.saltRatio * totalFlour,
        levain: Levain(
            type: levainTypeFor(hydration: spec.levainHydration),
            hydration: spec.levainHydration,
            grams: levainGrams
        )
    )
}

// MARK: - 르방 변환

/// 르방 변환 시 ΔF를 첨가 밀가루 여러 행에 배분하는 방식
public enum DeltaDistribution: Equatable, Sendable {
    case proRata // 기본: 현재 비율대로 비례 배분
    case single(flourID: String) // 특정 밀가루에서만 증감
}

public enum ConvertError: Error, Equatable, Sendable {
    case fAddNegative(maxLevainGrams: Double) // 르방 속 밀가루가 총 밀가루를 초과
    case wAddNegative(maxLevainGrams: Double) // 본반죽 물이 부족한 경우
    case singleFlourInsufficient(flourID: String, needed: Double, available: Double)

    public var maxLevainGrams: Double? {
        switch self {
        case .fAddNegative(let m), .wAddNegative(let m): return m
        case .singleFlourInsufficient: return nil
        }
    }
}

public struct ConvertSuccess: Sendable {
    public var output: DoughInput
    public var before: DoughStats
    public var after: DoughStats
    /// ΔF = F_lev_new − F_lev_old (르방 속 밀가루 증가량, g)
    public var deltaFlour: Double
}

public typealias ConvertResult = Result<ConvertSuccess, ConvertError>

/// 르방 질량 고정 모드에서, 원본의 총 밀가루·총 물을 유지하면서
/// 목표 수분율 h_new로 변환 가능한 최대 르방 질량.
/// 물 쪽 상한은 조정 가능 풀(본반죽 물 + 르방 속 물) 기준 (바시나주·액체 수분은 고정).
public func maxConvertibleLevain(_ input: DoughInput, newHydration: Double) -> Double {
    let s = computeStats(input)
    let adjustableWater = input.water + s.levainWater
    let byFlour = s.totalFlour * (1 + newHydration)
    let byWater =
        newHydration > eps ? adjustableWater * (1 + newHydration) / newHydration : .infinity
    return min(byFlour, byWater)
}

func distributeFlourDelta(
    _ flours: [Flour], delta: Double, dist: DeltaDistribution
) -> Result<[Flour], ConvertError> {
    if abs(delta) < eps { return .success(flours) }

    if case .single(let flourID) = dist {
        if let idx = flours.firstIndex(where: { $0.id == flourID }) {
            let target = flours[idx]
            let next = target.grams + delta
            if next < -eps {
                return .failure(
                    .singleFlourInsufficient(
                        flourID: target.id, needed: -delta, available: target.grams))
            }
            var out = flours
            out[idx].grams = max(0, next)
            return .success(out)
        }
        // 지정한 밀가루 행이 없으면 비례 배분으로 진행
    }

    if flours.isEmpty {
        return .success(delta > 0 ? [Flour(name: "밀가루", grams: delta)] : [])
    }
    let total = flours.reduce(0) { $0 + $1.grams }
    if total < eps {
        let each = delta / Double(flours.count)
        return .success(flours.map { f in
            var f = f
            f.grams = max(0, f.grams + each)
            return f
        })
    }
    let ratio = 1 + delta / total
    return .success(flours.map { f in
        var f = f
        f.grams = max(0, f.grams * ratio)
        return f
    })
}

/// 기본 모드 — 르방 질량 L 고정, 총 수분율 보존.
/// ΔF = L/(1+h_new) − L/(1+h_old)를 첨가 밀가루에서 빼고 본반죽 물에 더한다.
/// 총 밀가루·총 물·총 수분율·총 반죽 무게가 모두 보존된다 (PFF는 변함).
public func convertFixedMass(
    _ input: DoughInput, newHydration: Double, dist: DeltaDistribution = .proRata
) -> ConvertResult {
    let before = computeStats(input)
    let levainFlourNew = input.levain.grams / (1 + newHydration)
    let deltaFlour = levainFlourNew - before.levainFlour
    let addedFlourNew = before.totalFlour - levainFlourNew
    let addedWaterNew = input.water + deltaFlour

    if addedFlourNew < -eps {
        return .failure(
            .fAddNegative(maxLevainGrams: maxConvertibleLevain(input, newHydration: newHydration)))
    }
    if addedWaterNew < -eps {
        return .failure(
            .wAddNegative(maxLevainGrams: maxConvertibleLevain(input, newHydration: newHydration)))
    }

    let flours: [Flour]
    switch distributeFlourDelta(input.flours, delta: -deltaFlour, dist: dist) {
    case .failure(let e): return .failure(e)
    case .success(let v): flours = v
    }

    var output = input
    output.flours = flours
    output.water = max(0, addedWaterNew)
    output.levain.type = levainTypeFor(hydration: newHydration)
    output.levain.hydration = newHydration
    return .success(
        ConvertSuccess(
            output: output, before: before, after: computeStats(output), deltaFlour: deltaFlour))
}

/// 보조 모드 — PFF(F_lev) 고정. 르방 질량 L과 본반죽 물이 변하고,
/// 총 밀가루·총 물·총 수분율·PFF는 유지된다.
public func convertFixedPff(_ input: DoughInput, newHydration: Double) -> ConvertResult {
    let before = computeStats(input)
    let levainFlour = before.levainFlour // 고정
    let levainGramsNew = levainFlour * (1 + newHydration)
    let levainWaterNew = levainGramsNew - levainFlour
    let addedWaterNew = input.water + before.levainWater - levainWaterNew

    // 첨가 밀가루는 그대로 복사되므로, 모드 B의 불가능한 조합(PFF > 100%)이 음수 밀가루로 넘어오면 여기서 막는다
    if addedFlourTotal(input) < -eps {
        return .failure(
            .fAddNegative(maxLevainGrams: before.totalFlour * (1 + input.levain.hydration)))
    }
    if addedWaterNew < -eps {
        // F_lev ≤ (본반죽 물 + W_lev) / h_new → 원본 수분율 기준 최대 르방 질량으로 환산
        let maxLevainGrams =
            newHydration > eps
            ? (input.water + before.levainWater) / newHydration * (1 + input.levain.hydration)
            : .infinity
        return .failure(.wAddNegative(maxLevainGrams: maxLevainGrams))
    }

    var output = input
    output.water = max(0, addedWaterNew)
    output.levain.type = levainTypeFor(hydration: newHydration)
    output.levain.hydration = newHydration
    output.levain.grams = levainGramsNew
    return .success(
        ConvertSuccess(
            output: output, before: before, after: computeStats(output), deltaFlour: 0))
}

/// 총 밀가루·총 물을 유지한 채 르방 질량만 바꾼 배합을 만든다.
/// 첨가 밀가루의 증감분은 비례 배분, 물 보정은 본반죽 물에서.
/// (오류 시 "최대 르방 질량 적용"에 사용)
public func withLevainMass(_ input: DoughInput, grams: Double) -> DoughInput {
    let before = computeStats(input)
    let levainFlour = grams / (1 + input.levain.hydration)
    let levainWater = grams - levainFlour
    let targetAddedFlour = before.totalFlour - levainFlour
    let dist = distributeFlourDelta(
        input.flours, delta: targetAddedFlour - addedFlourTotal(input), dist: .proRata)

    var output = input
    if case .success(let v) = dist { output.flours = v }
    output.water = max(0, input.water + before.levainWater - levainWater)
    output.levain.grams = grams
    return output
}
