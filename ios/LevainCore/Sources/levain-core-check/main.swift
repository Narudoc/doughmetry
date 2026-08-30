import Foundation
import LevainCore

/// CLT 전용 스모크 체크 — Xcode 없이 `swift run levain-core-check`로 핵심 스펙을 검증한다.
/// 전체 스펙 테스트는 Tests/LevainCoreTests (Xcode 설치 후 `swift test`).

// `levain-core-check parse "<레시피 텍스트>"` — 파서 결과를 즉석 확인 (디버깅·검증용)
if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "parse" {
    let r = RecipeTextParser.parse(CommandLine.arguments[2])
    print("name: \(r.name ?? "(없음)")")
    for f in r.input.flours { print("flour: '\(f.name)' \(f.grams)g") }
    print("water: \(r.input.water)g  bassinage: \(r.input.bassinage)g  salt: \(r.input.salt)g")
    print("levain: \(r.input.levain.grams)g h=\(r.input.levain.hydration) (\(r.input.levain.type))")
    print("yeast: \(r.input.yeast.grams)g (\(r.input.yeast.type))")
    for l in r.input.liquids { print("liquid: '\(l.name)' \(l.grams)g ratio=\(l.waterRatio)") }
    for e in r.input.extras { print("extra: '\(e.name)' \(e.grams)g") }
    print("matchedLines: \(r.matchedLineCount)")
    let st = computeStats(r.input)
    print("stats: H=\(st.hydrationPct)% dough=\(st.doughWeight)g PFF=\(st.pffPct)%")
    exit(0)
}

var failures = 0

@MainActor func check(_ label: String, _ cond: Bool) {
    if cond { print("  ✓ \(label)") } else {
        failures += 1
        print("  ✗ \(label)")
    }
}

func near(_ a: Double, _ b: Double, _ tol: Double = 1e-6) -> Bool { abs(a - b) < tol }

let base = DoughInput(
    flours: [Flour(id: "f1", name: "T65", grams: 900)],
    water: 620, salt: 20,
    levain: Levain(type: .liquide, hydration: 1, grams: 200))

print("케이스 1 — 기본 계산")
let s = computeStats(base)
check("F_lev 100 / W_lev 100", near(s.levainFlour, 100) && near(s.levainWater, 100))
check("F_total 1000 / W_total 720", near(s.totalFlour, 1000) && near(s.totalWater, 720))
check("H 72.0% / 소금 2.0% / PFF 10.0%", near(s.hydrationPct, 72) && near(s.saltPct, 2) && near(s.pffPct, 10))
check("총 반죽 1740g", near(s.doughWeight, 1740))

print("모드 B 역산")
let solved = solveFromTarget(TargetSpec(doughWeight: 1740, hydration: 0.72, saltRatio: 0.02, pff: 0.1, levainHydration: 1))
check("F_add 900 / 물 620 / 소금 20 / 르방 200",
    near(addedFlourTotal(solved), 900) && near(solved.water, 620)
    && near(solved.salt, 20) && near(solved.levain.grams, 200))

print("v2 — 바시나주·액체·이스트")
var v2 = base
v2.bassinage = 50
check("바시나주 50 → H 77%", near(computeStats(v2).hydrationPct, 77))
var liq = base
liq.liquids = [
    Liquid(id: "l1", name: "우유", grams: 100, waterRatio: 0.88),
    Liquid(id: "l2", name: "계란", grams: 50, waterRatio: 0.76),
]
check("우유100+계란50 → H 84.6%", near(computeStats(liq).hydrationPct, 84.6))
check("IDY 변환 20생 → 8", near(convertYeast(20, from: .fresh, to: .instant), 8, 1e-9))

print("케이스 2 — 리퀴드→뒤흐 (질량 고정)")
switch convertFixedMass(base, newHydration: 0.5) {
case .failure: check("변환 성공", false)
case .success(let r):
    check("ΔF 33.33", abs(r.deltaFlour - 33.333333) < 1e-4)
    check("F_add 866.67 / 물 653.33",
        near(addedFlourTotal(r.output), 866.67, 0.05) && near(r.output.water, 653.33, 0.05))
    check("불변량 보존 (F_total/W_total/H/무게)",
        near(r.after.totalFlour, 1000) && near(r.after.totalWater, 720)
        && near(r.after.hydrationPct, 72) && near(r.after.doughWeight, 1740))
    check("PFF 10 → 13.33%", near(r.after.pffPct, 13.3333, 5e-4))
    check("타입 라벨 dur", r.output.levain.type == .dur)
}

print("케이스 3 — 왕복 변환")
if case .success(let toDur) = convertFixedMass(base, newHydration: 0.5),
   case .success(let back) = convertFixedMass(toDur.output, newHydration: 1) {
    check("원본 복원 ±0.01g",
        near(addedFlourTotal(back.output), 900, 0.01) && near(back.output.water, 620, 0.01)
        && near(back.output.levain.grams, 200, 0.01))
} else { check("왕복 성공", false) }

print("PFF 고정 모드")
if case .success(let pff) = convertFixedPff(base, newHydration: 0.5) {
    check("르방 150 / 물 670 / PFF·H 유지",
        near(pff.output.levain.grams, 150) && near(pff.output.water, 670)
        && near(pff.after.pffPct, 10) && near(pff.after.hydrationPct, 72))
} else { check("변환 성공", false) }

print("케이스 5 — 경계")
let stiff = DoughInput(
    flours: [Flour(id: "f1", name: "T65", grams: 1000)], water: 50, salt: 20,
    levain: Levain(type: .dur, hydration: 0.5, grams: 600))
if case .failure(.wAddNegative(let maxG)) = convertFixedMass(stiff, newHydration: 1) {
    check("W_ADD_NEGATIVE, 최대 500g", near(maxG, 500))
    let atMax = convertFixedMass(withLevainMass(stiff, grams: maxG), newHydration: 1)
    if case .success(let r) = atMax { check("최대값 적용 시 성공 (물 0)", near(r.output.water, 0)) }
    else { check("최대값 적용 시 성공", false) }
} else { check("W_ADD_NEGATIVE 발생", false) }

var bigLev = DoughInput(
    flours: [Flour(id: "f1", name: "T65", grams: 10)], water: 500, salt: 5,
    levain: Levain(type: .liquide, hydration: 1, grams: 600))
if case .failure(.fAddNegative) = convertFixedMass(bigLev, newHydration: 0.25) {
    check("F_ADD_NEGATIVE 발생", true)
} else { check("F_ADD_NEGATIVE 발생", false) }

print("케이스 4 — property (무작위 100건)")
struct Mulberry32 {
    var state: UInt32
    mutating func next() -> Double {
        state = state &+ 0x6D2B_79F5
        var t = (state ^ (state >> 15)) &* (state | 1)
        t = (t &+ ((t ^ (t >> 7)) &* (t | 61))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}
var rand = Mulberry32(state: 20_260_731)
@MainActor func between(_ lo: Double, _ hi: Double) -> Double { lo + rand.next() * (hi - lo) }
var successes = 0
var invariantFailures = 0
for _ in 0..<100 {
    let flourCount = 1 + Int(rand.next() * 3)
    let flours = (0..<flourCount).map { Flour(id: "f\($0)", name: "밀\($0)", grams: between(50, 800)) }
    let fsum = flours.reduce(0) { $0 + $1.grams }
    let input = DoughInput(
        flours: flours,
        water: fsum * between(0.45, 0.95),
        bassinage: rand.next() < 0.4 ? fsum * between(0.02, 0.1) : 0,
        salt: fsum * between(0.015, 0.025),
        levain: Levain(type: .liquide, hydration: between(0.4, 1.3), grams: fsum * between(0.1, 0.5)),
        liquids: rand.next() < 0.4
            ? [Liquid(id: "l", name: "우유", grams: between(30, 200), waterRatio: between(0.5, 1))] : [],
        yeast: rand.next() < 0.3 ? Yeast(type: .fresh, grams: between(2, 20)) : Yeast(),
        extras: rand.next() < 0.3 ? [Extra(id: "x", name: "씨앗", grams: between(10, 100))] : [])
    let h = between(0.4, 1.3)
    switch convertFixedMass(input, newHydration: h) {
    case .success(let r):
        successes += 1
        let sa = computeStats(input), sb = computeStats(r.output)
        if !(near(sa.totalFlour, sb.totalFlour) && near(sa.totalWater, sb.totalWater)
            && near(sa.hydrationPct, sb.hydrationPct) && near(sa.doughWeight, sb.doughWeight)) {
            invariantFailures += 1
        }
        if case .success(let p) = convertFixedPff(input, newHydration: h) {
            if !near(p.after.pffPct, p.before.pffPct) { invariantFailures += 1 }
        }
    case .failure(let e):
        if let maxG = e.maxLevainGrams {
            if case .failure = convertFixedMass(withLevainMass(input, grams: maxG), newHydration: h) {
                invariantFailures += 1
            }
        }
    }
}
check("성공 \(successes)건 > 50, 불변량 위반 0건", successes > 50 && invariantFailures == 0)

print("JSON 코덱")
let v1json = #"{"schemaVersion":1,"name":"옛것","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"hydration":1,"grams":200}}"#
switch RecipeCodec.importJSON(v1json) {
case .success(let rs):
    check("v1 → v2 마이그레이션", rs[0].schemaVersion == 2 && rs[0].bassinage == 0 && rs[0].yeast.grams == 0)
    if let json = try? RecipeCodec.exportJSON(rs), case .success(let back) = RecipeCodec.importJSON(json) {
        check("내보내기 왕복 보존", back == rs)
    } else { check("내보내기 왕복 보존", false) }
case .failure: check("v1 가져오기", false)
}

print(failures == 0 ? "\n전체 통과 ✓" : "\n실패 \(failures)건 ✗")
exit(failures == 0 ? 0 : 1)
