import Foundation
import Testing
@testable import LevainCore

/// src/lib/dough.test.ts의 스펙 케이스 1~5 이식 — 웹앱과 동일한 수치가 나와야 한다.

func makeInput(
    flours: [Flour] = [Flour(id: "f1", name: "T65", grams: 900)],
    water: Double = 620,
    bassinage: Double = 0,
    salt: Double = 20,
    levain: Levain = Levain(type: .liquide, hydration: 1, grams: 200),
    liquids: [Liquid] = [],
    yeast: Yeast = Yeast(type: .fresh, grams: 0),
    extras: [Extra] = []
) -> DoughInput {
    DoughInput(
        flours: flours, water: water, bassinage: bassinage, salt: salt,
        levain: levain, liquids: liquids, yeast: yeast, extras: extras)
}

/// 케이스 1·2의 기준 레시피: 밀가루 900 / 물 620 / 소금 20 / 르방 리퀴드 200 (h=1.0)
func baseRecipe() -> DoughInput { makeInput() }

func addedFlour(_ input: DoughInput) -> Double { input.flours.reduce(0) { $0 + $1.grams } }

func near(_ a: Double, _ b: Double, _ tol: Double = 1e-6) -> Bool { abs(a - b) < tol }

func expectInvariantsPreserved(
    _ a: DoughInput, _ b: DoughInput, tolerance: Double = 1e-6,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let sa = computeStats(a)
    let sb = computeStats(b)
    #expect(near(sb.totalFlour, sa.totalFlour), sourceLocation: sourceLocation)
    #expect(near(sb.totalWater, sa.totalWater), sourceLocation: sourceLocation)
    #expect(abs(sb.hydrationPct - sa.hydrationPct) < tolerance, sourceLocation: sourceLocation)
    #expect(near(sb.doughWeight, sa.doughWeight), sourceLocation: sourceLocation)
}

@Suite("케이스 1 — 기본 계산")
struct BasicCalc {
    @Test("총 수분율 72.0% / 소금 2.0% / PFF 10.0% / 총 반죽 1740g")
    func basics() {
        let s = computeStats(baseRecipe())
        #expect(near(s.levainFlour, 100))
        #expect(near(s.levainWater, 100))
        #expect(near(s.totalFlour, 1000))
        #expect(near(s.totalWater, 720))
        #expect(near(s.hydrationPct, 72.0))
        #expect(near(s.saltPct, 2.0))
        #expect(near(s.pffPct, 10.0))
        #expect(near(s.doughWeight, 1740))
    }

    @Test("모드 B 역산이 같은 배합을 복원한다")
    func solveTarget() {
        let solved = solveFromTarget(
            TargetSpec(
                doughWeight: 1740, hydration: 0.72, saltRatio: 0.02, pff: 0.1,
                levainHydration: 1))
        #expect(near(addedFlour(solved), 900))
        #expect(near(solved.water, 620))
        #expect(near(solved.salt, 20))
        #expect(near(solved.levain.grams, 200))
        #expect(near(computeStats(solved).hydrationPct, 72))
    }

    @Test("모드 B: 첨가 물이 0인 경계(H = PFF × h)에서 부동소수점 잔차가 음수 물로 남지 않는다")
    func solveTargetSnapsResidue() throws {
        // 보정 전 water: −2.27e-13 / −5.68e-14
        for (hydration, pff, levainHydration) in [(0.66, 0.55, 1.2), (0.42, 0.84, 0.5)] {
            let solved = solveFromTarget(
                TargetSpec(
                    doughWeight: 1740, hydration: hydration, saltRatio: 0.02, pff: pff,
                    levainHydration: levainHydration))
            #expect(solved.water == 0)
            // 저장 검증(water ≥ 0)을 통과해야 다음 로드에서 사라지지 않는다
            let recipe = Recipe(name: "경계", createdAt: isoNow(), updatedAt: isoNow(), input: solved)
            let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recipe))
            if case .bad(let e) = RecipeCodec.validate(json) {
                Issue.record("validate 실패: \(e)")
            }
        }
    }

    @Test("모드 B: 실제로 불가능한 배합은 음수 그대로 남는다 (UI가 저장을 막도록)")
    func solveTargetKeepsInfeasibleNegative() {
        let solved = solveFromTarget(
            TargetSpec(
                doughWeight: 1740, hydration: 0.3, saltRatio: 0.02, pff: 0.5, levainHydration: 1))
        #expect(solved.water < -1e-9)
    }
}

@Suite("v2 — 바시나주·액체 재료·이스트")
struct V2Features {
    @Test("바시나주는 총 물과 총 반죽 무게에 더해진다")
    func bassinage() {
        let s = computeStats(makeInput(bassinage: 50))
        #expect(near(s.totalWater, 770))
        #expect(near(s.hydrationPct, 77.0))
        #expect(near(s.doughWeight, 1790))
        #expect(near(s.totalFlour, 1000)) // 밀가루에는 영향 없음
    }

    @Test("우유 88% / 계란 76% 수분율이 총 물에 반영된다 (USDA 기준)")
    func liquids() {
        #expect(LiquidPreset.milk.waterRatio == 0.88)
        #expect(LiquidPreset.egg.waterRatio == 0.76)
        let s = computeStats(
            makeInput(liquids: [
                Liquid(id: "l1", name: "우유", grams: 100, waterRatio: 0.88),
                Liquid(id: "l2", name: "계란", grams: 50, waterRatio: 0.76),
            ]))
        #expect(near(s.liquidWater, 88 + 38))
        #expect(near(s.totalWater, 720 + 126))
        #expect(near(s.hydrationPct, 84.6))
        #expect(near(s.doughWeight, 1740 + 150)) // 액체는 전체 무게로 합산
        #expect(near(s.saltPct, 2.0)) // 소금·PFF는 여전히 총 밀가루 기준
    }

    @Test("생이스트 ↔ 인스턴트 드라이 변환 (IDY = 생이스트 × 0.4)")
    func yeastConversion() {
        #expect(idyFactor == 0.4)
        #expect(near(convertYeast(20, from: .fresh, to: .instant), 8, 1e-9))
        #expect(near(convertYeast(8, from: .instant, to: .fresh), 20, 1e-9))
        #expect(convertYeast(15, from: .fresh, to: .fresh) == 15)
        // 왕복 변환은 원래 값으로 돌아온다
        #expect(
            near(
                convertYeast(
                    convertYeast(13.7, from: .fresh, to: .instant), from: .instant, to: .fresh),
                13.7, 1e-9))
    }

    @Test("이스트는 반죽 무게와 %에만 반영되고 수분율에는 영향이 없다")
    func yeastStats() {
        let s = computeStats(makeInput(yeast: Yeast(type: .fresh, grams: 10)))
        #expect(near(s.doughWeight, 1750))
        #expect(near(s.yeastPct, 1.0))
        #expect(near(s.hydrationPct, 72.0))
    }
}

@Suite("케이스 2 — 리퀴드 → 뒤흐 변환 (르방 질량 고정)")
struct FixedMassConversion {
    @Test("첨가 밀가루 866.67g / 물 653.33g, 불변량 보존, PFF 10 → 13.33%")
    func liquideToDur() throws {
        let result = try convertFixedMass(baseRecipe(), newHydration: 0.5).get()

        #expect(abs(result.deltaFlour - 33.333333) < 1e-4)
        #expect(near(addedFlour(result.output), 866.67, 0.05))
        #expect(near(result.output.water, 653.33, 0.05))
        #expect(result.output.salt == 20)
        #expect(result.output.levain.grams == 200)
        #expect(near(result.after.levainFlour, 133.33, 0.05))
        #expect(near(result.after.levainWater, 66.67, 0.05))

        #expect(near(result.after.totalFlour, 1000))
        #expect(near(result.after.totalWater, 720))
        #expect(near(result.after.hydrationPct, 72.0))
        #expect(near(result.after.doughWeight, 1740))
        #expect(near(result.before.pffPct, 10.0))
        #expect(near(result.after.pffPct, 13.3333, 5e-4))
        #expect(result.output.levain.type == .dur)
    }

    @Test("바시나주·액체·이스트는 변환에서 그대로 보존되고 본반죽 물만 조정된다")
    func fixedPartsPreserved() throws {
        let input = makeInput(
            bassinage: 60,
            liquids: [Liquid(id: "l1", name: "우유", grams: 100, waterRatio: 0.88)],
            yeast: Yeast(type: .fresh, grams: 10))
        let result = try convertFixedMass(input, newHydration: 0.5).get()
        #expect(result.output.bassinage == 60)
        #expect(result.output.liquids == input.liquids)
        #expect(result.output.yeast == input.yeast)
        #expect(near(result.output.water, 620 + result.deltaFlour))
        expectInvariantsPreserved(input, result.output)
    }

    @Test("다중 밀가루 비례 배분: 비율이 유지된다")
    func proRata() throws {
        let input = makeInput(flours: [
            Flour(id: "a", name: "T65", grams: 700),
            Flour(id: "b", name: "T110", grams: 150),
            Flour(id: "c", name: "호밀", grams: 50),
        ])
        let result = try convertFixedMass(input, newHydration: 0.5).get()
        let f = result.output.flours
        // 700:150:50 비율 유지
        #expect(near(f[0].grams / f[1].grams, 700.0 / 150.0))
        #expect(near(f[1].grams / f[2].grams, 150.0 / 50.0))
        #expect(near(addedFlour(result.output), 900 - result.deltaFlour))
        expectInvariantsPreserved(input, result.output)
    }

    @Test("단일 밀가루 지정 배분: 지정한 행에서만 증감")
    func singleFlour() throws {
        let input = makeInput(flours: [
            Flour(id: "a", name: "T65", grams: 700),
            Flour(id: "b", name: "T110", grams: 200),
        ])
        let result = try convertFixedMass(input, newHydration: 0.5, dist: .single(flourID: "b"))
            .get()
        #expect(result.output.flours[0].grams == 700)
        #expect(near(result.output.flours[1].grams, 200 - result.deltaFlour))
        expectInvariantsPreserved(input, result.output)
    }

    @Test("단일 밀가루가 부족하면 SINGLE_FLOUR_INSUFFICIENT")
    func singleFlourInsufficient() {
        let input = makeInput(flours: [
            Flour(id: "a", name: "T65", grams: 880),
            Flour(id: "b", name: "호밀", grams: 20),
        ])
        let result = convertFixedMass(input, newHydration: 0.5, dist: .single(flourID: "b"))
        guard case .failure(.singleFlourInsufficient) = result else {
            Issue.record("SINGLE_FLOUR_INSUFFICIENT 오류가 발생해야 한다")
            return
        }
    }
}

@Suite("케이스 3 — 왕복 변환")
struct RoundTrip {
    @Test("리퀴드 → 뒤흐 → 리퀴드가 원본을 복원한다 (±0.01g)")
    func roundTrip() throws {
        let original = makeInput(
            bassinage: 40,
            liquids: [Liquid(id: "l1", name: "계란", grams: 50, waterRatio: 0.76)],
            yeast: Yeast(type: .instant, grams: 4))
        let toDur = try convertFixedMass(original, newHydration: 0.5).get()
        let back = try convertFixedMass(toDur.output, newHydration: 1).get()
        #expect(near(addedFlour(back.output), 900, 0.01))
        #expect(near(back.output.water, 620, 0.01))
        #expect(near(back.output.salt, 20, 0.01))
        #expect(near(back.output.levain.grams, 200, 0.01))
        #expect(back.output.levain.hydration == 1)
        #expect(back.output.bassinage == 40)
        #expect(back.output.liquids == original.liquids)
        #expect(back.output.yeast == original.yeast)
    }
}

@Suite("케이스 4 — 불변식 property test (무작위 100건)")
struct PropertyTests {
    /// 시드 고정 PRNG — 웹 테스트의 mulberry32와 동일 시퀀스
    struct Mulberry32 {
        var state: UInt32
        init(seed: UInt32) { state = seed }
        mutating func next() -> Double {
            state = state &+ 0x6D2B_79F5
            var t = (state ^ (state >> 15)) &* (state | 1)
            t = (t &+ ((t ^ (t >> 7)) &* (t | 61))) ^ t
            return Double(t ^ (t >> 14)) / 4_294_967_296
        }
    }

    @Test("변환 전후 총 밀가루·총 물·총 수분율·총 반죽 무게가 보존된다")
    func invariants() throws {
        var rand = Mulberry32(seed: 20_260_731)
        func between(_ lo: Double, _ hi: Double) -> Double { lo + rand.next() * (hi - lo) }
        var successes = 0

        for _ in 0..<100 {
            let flourCount = 1 + Int(rand.next() * 3)
            let flours = (0..<flourCount).map { k in
                Flour(id: "f\(k)", name: "밀가루\(k)", grams: between(50, 800))
            }
            let flourSum = flours.reduce(0) { $0 + $1.grams }
            let input = makeInput(
                flours: flours,
                water: flourSum * between(0.45, 0.95),
                bassinage: rand.next() < 0.4 ? flourSum * between(0.02, 0.1) : 0,
                salt: flourSum * between(0.015, 0.025),
                levain: Levain(
                    type: .liquide, hydration: between(0.4, 1.3),
                    grams: flourSum * between(0.1, 0.5)),
                liquids: rand.next() < 0.4
                    ? [Liquid(id: "l", name: "우유", grams: between(30, 200), waterRatio: between(0.5, 1))]
                    : [],
                yeast: rand.next() < 0.3
                    ? Yeast(type: .fresh, grams: between(2, 20)) : Yeast(type: .fresh, grams: 0),
                extras: rand.next() < 0.3 ? [Extra(id: "x", name: "씨앗", grams: between(10, 100))] : []
            )
            let newHydration = between(0.4, 1.3)
            let result = convertFixedMass(input, newHydration: newHydration)

            switch result {
            case .success(let r):
                successes += 1
                expectInvariantsPreserved(input, r.output)
                for f in r.output.flours { #expect(f.grams >= 0) }
                #expect(r.output.water >= 0)
                // PFF 고정 모드도 같은 불변량을 보존해야 한다
                if case .success(let pff) = convertFixedPff(input, newHydration: newHydration) {
                    expectInvariantsPreserved(input, pff.output)
                    #expect(near(pff.after.pffPct, pff.before.pffPct))
                }
            case .failure(let error):
                // 실패 시 제시된 최대 르방 질량으로 줄이면 변환이 성공해야 한다
                if let maxGrams = error.maxLevainGrams {
                    #expect(maxGrams.isFinite)
                    let reduced = withLevainMass(input, grams: maxGrams)
                    let retry = convertFixedMass(reduced, newHydration: newHydration)
                    #expect((try? retry.get()) != nil)
                }
            }
        }
        #expect(successes > 50)
    }
}

@Suite("케이스 5 — 경계 조건 (W_add_new < 0)")
struct Boundaries {
    /// 저수분 + 대량 뒤흐 르방: 뒤흐 → 리퀴드 변환이 불가능한 배합
    func stiffInput() -> DoughInput {
        makeInput(
            flours: [Flour(id: "f1", name: "T65", grams: 1000)],
            water: 50,
            salt: 20,
            levain: Levain(type: .dur, hydration: 0.5, grams: 600))
    }

    @Test("W_ADD_NEGATIVE 오류가 발생하고 최대 르방 질량이 제시된다")
    func wAddNegative() {
        let result = convertFixedMass(stiffInput(), newHydration: 1)
        guard case .failure(.wAddNegative(let maxGrams)) = result else {
            Issue.record("W_ADD_NEGATIVE 오류가 발생해야 한다")
            return
        }
        // F_total=1400, 조정 가능 물 = 50 + 200 = 250 → max = min(1400×2, 250×2/1) = 500
        #expect(near(maxGrams, 500))
        #expect(near(maxConvertibleLevain(stiffInput(), newHydration: 1), 500))
    }

    @Test("제시된 최대 르방 질량은 실제로 유효하다 (그 이하 성공, 초과 실패)")
    func maxIsValid() throws {
        let max = maxConvertibleLevain(stiffInput(), newHydration: 1)

        let reduced = withLevainMass(stiffInput(), grams: max)
        let atMax = try convertFixedMass(reduced, newHydration: 1).get()
        #expect(near(atMax.output.water, 0))
        expectInvariantsPreserved(reduced, atMax.output)

        let overMax = convertFixedMass(withLevainMass(stiffInput(), grams: max + 1), newHydration: 1)
        #expect((try? overMax.get()) == nil)
    }

    @Test("바시나주는 조정 가능한 물이 아니다 — 물 상한은 본반죽 물 기준")
    func bassinageNotAdjustable() throws {
        // 바시나주가 커도 본반죽 물이 적으면 변환 한도는 그만큼 낮아야 한다
        let input = makeInput(
            flours: [Flour(id: "f1", name: "T65", grams: 1000)],
            water: 10,
            bassinage: 300,
            salt: 20,
            levain: Levain(type: .dur, hydration: 0.5, grams: 600))
        // 조정 가능 물 = 10 + 200 = 210 → max = min(1400×2, 210×2/1) = 420
        let max = maxConvertibleLevain(input, newHydration: 1)
        #expect(near(max, 420))

        #expect((try? convertFixedMass(input, newHydration: 1).get()) == nil)
        let atMax = try convertFixedMass(withLevainMass(input, grams: max), newHydration: 1).get()
        #expect(near(atMax.output.water, 0))
        #expect(atMax.output.bassinage == 300) // 바시나주는 손대지 않는다
    }

    @Test("르방 속 밀가루가 총 밀가루를 초과하면 F_ADD_NEGATIVE")
    func fAddNegative() {
        let input = makeInput(
            flours: [Flour(id: "f1", name: "T65", grams: 10)],
            water: 500,
            salt: 5,
            levain: Levain(type: .liquide, hydration: 1, grams: 600))
        // h 1.0 → 0.25: F_lev 300 → 480 > F_total 310
        let result = convertFixedMass(input, newHydration: 0.25)
        guard case .failure(.fAddNegative) = result else {
            Issue.record("F_ADD_NEGATIVE 오류가 발생해야 한다")
            return
        }
    }
}

@Suite("보조 모드 — PFF 고정")
struct FixedPff {
    @Test("르방 질량과 본반죽 물이 바뀌고 F_add·PFF·수분율은 유지된다")
    func basics() throws {
        let result = try convertFixedPff(baseRecipe(), newHydration: 0.5).get()
        #expect(near(result.after.levainFlour, 100)) // F_lev 고정
        #expect(near(result.output.levain.grams, 150)) // 100 × 1.5
        #expect(near(result.output.water, 670)) // 620 + (100 − 50)
        #expect(near(addedFlour(result.output), 900)) // F_add 불변
        #expect(near(result.after.pffPct, 10))
        #expect(near(result.after.hydrationPct, 72))
    }

    @Test("바시나주·액체가 있어도 불변량이 유지된다")
    func invariantsWithExtras() throws {
        let input = makeInput(
            bassinage: 60,
            liquids: [Liquid(id: "l1", name: "우유", grams: 100, waterRatio: 0.88)])
        let result = try convertFixedPff(input, newHydration: 0.5).get()
        #expect(result.output.bassinage == 60)
        #expect(result.output.liquids == input.liquids)
        expectInvariantsPreserved(input, result.output)
    }

    @Test("모드 B의 PFF > 100% 배합(음수 첨가 밀가루)은 F_ADD_NEGATIVE — 최대 르방 적용 후엔 저장 가능한 결과")
    func infeasibleTargetRejected() throws {
        // 총 밀가루 1000 / F_lev 1200 → 첨가 밀가루 −200, 본반죽 물 −480
        let input = solveFromTarget(
            TargetSpec(
                doughWeight: 1740, hydration: 0.72, saltRatio: 0.02, pff: 1.2, levainHydration: 1))
        guard case .failure(.fAddNegative(let maxGrams)) = convertFixedPff(input, newHydration: 0.5)
        else {
            Issue.record("F_ADD_NEGATIVE 오류가 발생해야 한다")
            return
        }
        #expect(near(maxGrams, 2000)) // F_total × (1 + h)

        let applied = try convertFixedPff(withLevainMass(input, grams: maxGrams), newHydration: 0.5)
            .get()
        let recipe = Recipe(
            name: "적용", createdAt: isoNow(), updatedAt: isoNow(), input: applied.output)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(recipe))
        if case .bad(let e) = RecipeCodec.validate(json) {
            Issue.record("validate 실패: \(e)")
        }
    }
}
