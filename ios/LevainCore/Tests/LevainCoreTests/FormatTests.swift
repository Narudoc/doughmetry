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
