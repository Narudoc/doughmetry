import Testing
@testable import LevainCore

// src/lib/format.test.ts와 같은 벡터 — 두 플랫폼이 같은 레시피를 같은 숫자로 보여야 한다.

@Suite("반올림 — 정확한 2진 동점은 0에서 먼 쪽으로 (toFixed)")
struct FormatRounding {
    @Test("1g 단위")
    func wholeGrams() {
        #expect(fmtGrams(12.5, .whole) == "13")
        #expect(fmtGrams(2.5, .whole) == "3")
        #expect(fmtGrams(500.5, .whole) == "501")
    }

    @Test("0.1 단위 %·그램")
    func tenths() {
        #expect(fmtPct(5.0 / 400 * 100) == "1.3%")
        #expect(fmtPct(289.0 / 400 * 100) == "72.3%")
        #expect(fmtPct(9.0 / 400 * 100) == "2.3%")
        #expect(fmtGrams(0.25) == "0.3")
    }

    @Test("동점이 아닌 값은 2진 값 그대로 반올림한다")
    func nonTies() {
        // 18.5/1000×100 = 1.8499999999999999 — ×10을 먼저 하면 18.5가 되어 1.9로 틀린다
        #expect(fmtPct(18.5 / 1000 * 100) == "1.8%")
        #expect(fmtGrams(1.45) == "1.4") // 1.4499999999999999556
        #expect(fmtGrams(0.05) == "0.1") // 0.0500000000000000028
    }

    @Test("음수·−0·증감분")
    func negatives() {
        #expect(fmtGrams(-2.5, .whole) == "-3")
        #expect(fmtGrams(-0.25) == "-0.3")
        #expect(fmtGrams(-0.01) == "-0.0")
        #expect(fmtGrams(-0.0) == "0.0")
        #expect(fmtSigned(-12.5, .whole) == "\u{2212}13")
        #expect(fmtSigned(12.5, .whole) == "+13")
        #expect(fmtSigned(-0.0) == "+0.0")
    }

    @Test("유한하지 않은 값")
    func nonFinite() {
        #expect(fmtPct(.nan) == "NaN%")
        #expect(fmtGrams(.infinity) == "Infinity")
        #expect(fmtGrams(-.infinity, .whole) == "-Infinity")
    }
}

// src/components/ui/fields.test.ts와 같은 벡터
@Suite("숫자 입력 해석 — 천 단위 쉼표와 소수점 쉼표")
struct DecimalInputParsing {
    @Test("자릿수가 맞는 천 단위 쉼표는 구분 기호로 읽는다")
    func grouping() {
        #expect(parseDecimalInput("1,000") == 1000)
        #expect(parseDecimalInput("12,345,678") == 12_345_678)
        #expect(parseDecimalInput("1,000.5") == 1000.5)
    }

    @Test("그 밖의 쉼표는 소수점으로 읽는다")
    func decimalComma() {
        #expect(parseDecimalInput("72,5") == 72.5)
        #expect(parseDecimalInput("0,125") == 0.125)
        #expect(parseDecimalInput("1.5") == 1.5)
    }

    @Test("입력 도중의 값은 그 시점까지로 해석한다")
    func partial() {
        #expect(parseDecimalInput("1,") == 1)
        #expect(parseDecimalInput("1,00") == 1)
    }

    @Test("해석할 수 없으면 nil (이전 값 유지)")
    func rejected() {
        #expect(parseDecimalInput("1,000,5") == nil)
        #expect(parseDecimalInput("1.000.5") == nil)
    }
}

// src/lib/format.test.ts의 uiPct·rebasePct·uiLevainPct와 같은 벡터
@Suite("% 표기 기준 — 분모만 바뀌고 계산 지표는 그대로")
struct PctBasisDisplay {
    private let stats = computeStats(
        DoughInput(
            flours: [Flour(id: "f1", name: "T65", grams: 900)], water: 620, salt: 20,
            levain: Levain(type: .liquide, hydration: 1, grams: 200)))

    private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    @Test("총 밀가루 기준은 첨가 + 르방 속 밀가루(1000g), 베이커스 퍼센트는 첨가 밀가루(900g)로 나눈다")
    func denominators() {
        #expect(near(stats.uiPct(grams: 620, basis: .totalFlour), 62))
        #expect(near(stats.uiPct(grams: 620, basis: .addedFlour), 620.0 / 900 * 100))
        #expect(fmtPct(stats.uiPct(grams: 620, basis: .addedFlour)) == "68.9%")
        #expect(near(stats.uiPct(grams: 900, basis: .addedFlour), 100))
        // 표시 기준과 무관하게 계산 지표는 총 밀가루 기준
        #expect(near(stats.hydrationPct, 72))
    }

    @Test("총 밀가루 기준 % 환산 — 베이커스 퍼센트면 × 총 밀가루 / 첨가 밀가루")
    func rebase() {
        #expect(near(stats.saltPct, 2))
        #expect(near(stats.rebasePct(stats.saltPct, basis: .totalFlour), 2))
        #expect(near(stats.rebasePct(stats.saltPct, basis: .addedFlour), 20.0 / 900 * 100))
        #expect(near(stats.rebasePct(stats.saltPct, basis: .addedFlour), stats.uiPct(grams: 20, basis: .addedFlour)))
    }

    @Test("르방 칩 — 총 밀가루 기준은 PFF, 베이커스 퍼센트는 르방 무게 / 첨가 밀가루")
    func levainChip() {
        #expect(near(stats.uiLevainPct(levainGrams: 200, basis: .totalFlour), 10))
        #expect(near(stats.uiLevainPct(levainGrams: 200, basis: .addedFlour), 200.0 / 900 * 100))
    }

    @Test("밀가루가 없으면 0 (NaN이 아니다)")
    func noFlour() {
        let empty = computeStats(
            DoughInput(
                flours: [], water: 100, salt: 0,
                levain: Levain(type: .liquide, hydration: 1, grams: 0)))
        for basis in PctBasis.allCases {
            #expect(empty.uiPct(grams: 100, basis: basis) == 0)
            #expect(empty.rebasePct(0, basis: basis) == 0)
            #expect(empty.uiLevainPct(levainGrams: 0, basis: basis) == 0)
        }
    }

    @Test("저장값(UserDefaults \"pctBasis\")은 그대로 읽힌다")
    func storedRawValues() {
        #expect(PctBasis(rawValue: "totalFlour") == .totalFlour)
        #expect(PctBasis(rawValue: "addedFlour") == .addedFlour)
    }
}
