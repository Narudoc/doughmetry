import CoreGraphics
import Foundation
import Testing
@testable import LevainCore

/// OCR 조각 → 줄 재조립. 좌표는 Vision이 실제 카드·표 사진에서 돌려준 값에 맞춘 근사치
/// (정규화 좌표, 좌하단 원점, 글자 높이 ≈ 0.037)
@Suite("OCR 행 재조립")
struct OCRLayoutTests {
    /// row 0이 맨 위 — Vision y는 아래에서 위로 커진다
    func piece(_ text: String, x: CGFloat, row: Int, width: CGFloat) -> OCRLayout.Piece {
        (text, CGRect(x: x, y: 0.9 - CGFloat(row) * 0.06, width: width, height: 0.037))
    }

    @Test("재료 | 만드는 법 두 단 카드 — 오른쪽 단은 왼쪽 단 뒤에 따로 붙는다")
    func twoColumnCard() {
        let pieces = [
            piece("재료", x: 0.05, row: 0, width: 0.08),
            piece("만드는 법", x: 0.40, row: 0, width: 0.16),
            piece("강력분 500g", x: 0.05, row: 1, width: 0.20),
            piece("1. 볼에 물과 르방을 넣고 섞어주세요", x: 0.40, row: 1, width: 0.52),
            piece("물 350g", x: 0.05, row: 2, width: 0.13),
            piece("2. 밀가루를 넣고 30분 오토리즈합니다", x: 0.40, row: 2, width: 0.52),
            piece("르방 100g", x: 0.05, row: 3, width: 0.15),
            piece("3. 소금을 넣고 치대세요", x: 0.40, row: 3, width: 0.40),
            piece("소금 10g", x: 0.05, row: 4, width: 0.14),
            piece("4. 실온에서 4시간 발효합니다", x: 0.40, row: 4, width: 0.45),
        ]
        let text = OCRLayout.assembleRows(pieces.reversed())
        #expect(
            text == """
                재료
                강력분 500g
                물 350g
                르방 100g
                소금 10g
                만드는 법
                1. 볼에 물과 르방을 넣고 섞어주세요
                2. 밀가루를 넣고 30분 오토리즈합니다
                3. 소금을 넣고 치대세요
                4. 실온에서 4시간 발효합니다
                """)
        let r = RecipeTextParser.parse(RecipeTextParser.cleanForParsing(text))
        #expect(r.input.flours.map(\.grams) == [500])
        #expect(r.input.water == 350)
        #expect(r.input.salt == 10)
        #expect(r.input.levain.grams == 100)
        #expect(r.matchedLineCount == 4)
    }

    @Test("수량 칸이 따로 있는 두 단 카드 — 줄바꿈된 짧은 공정 줄 때문에 단 분리를 포기하지 않는다")
    func twoColumnCardWithAmountColumnAndWrappedSteps() {
        let pieces = [
            piece("재료", x: 0.05, row: 0, width: 0.08),
            piece("만드는 법", x: 0.43, row: 0, width: 0.16),
            piece("강력분", x: 0.05, row: 1, width: 0.12),
            piece("500g", x: 0.21, row: 1, width: 0.09),
            piece("1. 물에 르방을 풀고", x: 0.43, row: 1, width: 0.30),
            piece("물", x: 0.05, row: 2, width: 0.04),
            piece("350g", x: 0.21, row: 2, width: 0.09),
            piece("밀가루를 섞는다", x: 0.43, row: 2, width: 0.26),
            piece("르방", x: 0.05, row: 3, width: 0.08),
            piece("100g", x: 0.21, row: 3, width: 0.09),
            piece("2. 소금을 넣고", x: 0.43, row: 3, width: 0.24),
            piece("소금", x: 0.05, row: 4, width: 0.08),
            piece("10g", x: 0.21, row: 4, width: 0.07),
            piece("치댄다", x: 0.43, row: 4, width: 0.12),
        ]
        let r = RecipeTextParser.parse(OCRLayout.assembleRows(pieces.reversed()))
        #expect(r.input.flours.map(\.grams) == [500])
        #expect(r.input.water == 350)
        #expect(r.input.levain.grams == 100)
        #expect(r.input.salt == 10)
    }

    @Test("이름 | 양 표 — 멀리 떨어진 수량 칸은 같은 줄에 붙는다")
    func nameAmountTable() {
        let pieces = [
            piece("재료", x: 0.05, row: 0, width: 0.08),
            piece("양 (g)", x: 0.58, row: 0, width: 0.10),
            piece("강력분", x: 0.05, row: 1, width: 0.10),
            piece("500", x: 0.58, row: 1, width: 0.06),
            piece("물", x: 0.05, row: 2, width: 0.03),
            piece("350", x: 0.58, row: 2, width: 0.06),
            piece("르방 리퀴드", x: 0.05, row: 3, width: 0.15),
            piece("100", x: 0.58, row: 3, width: 0.06),
            piece("소금", x: 0.05, row: 4, width: 0.06),
            piece("10", x: 0.58, row: 4, width: 0.04),
        ]
        #expect(OCRLayout.assembleRows(pieces) == "재료 양 (g)\n강력분 500\n물 350\n르방 리퀴드 100\n소금 10")

        let withPct = [
            piece("강력분", x: 0.05, row: 0, width: 0.10),
            piece("500", x: 0.45, row: 0, width: 0.06),
            piece("100%", x: 0.70, row: 0, width: 0.08),
            piece("물", x: 0.05, row: 1, width: 0.03),
            piece("350 g", x: 0.45, row: 1, width: 0.08),
            piece("(70%)", x: 0.70, row: 1, width: 0.09),
        ]
        #expect(OCRLayout.assembleRows(withPct) == "강력분 500 100%\n물 350 g (70%)")
    }

    @Test("이름 | 양 | 비고 표 — 비고 칸은 문장 메모가 섞여도 그 행에 남는다")
    func notesTable() {
        let en = [
            piece("Ingredient", x: 0.05, row: 0, width: 0.20),
            piece("Grams", x: 0.375, row: 0, width: 0.12),
            piece("Notes", x: 0.666, row: 0, width: 0.12),
            piece("Bread flour", x: 0.05, row: 1, width: 0.22),
            piece("500", x: 0.375, row: 1, width: 0.07),
            piece("T65", x: 0.666, row: 1, width: 0.07),
            piece("Water", x: 0.05, row: 2, width: 0.12),
            piece("350", x: 0.375, row: 2, width: 0.07),
            piece("Keep it cool.", x: 0.666, row: 2, width: 0.20),
            piece("Levain", x: 0.05, row: 3, width: 0.13),
            piece("150", x: 0.375, row: 3, width: 0.07),
            piece("Stiff (50%)", x: 0.666, row: 3, width: 0.20),
            piece("Salt", x: 0.05, row: 4, width: 0.08),
            piece("10", x: 0.375, row: 4, width: 0.05),
            piece("Yeast", x: 0.05, row: 5, width: 0.10),
            piece("3", x: 0.375, row: 5, width: 0.03),
            piece("instant", x: 0.666, row: 5, width: 0.14),
        ]
        let text = OCRLayout.assembleRows(en)
        #expect(
            text == """
                Ingredient Grams Notes
                Bread flour 500 T65
                Water 350 Keep it cool.
                Levain 150 Stiff (50%)
                Salt 10
                Yeast 3 instant
                """)
        let r = RecipeTextParser.parse(text)
        #expect(r.name == nil)
        #expect(r.input.flours.map(\.name) == ["Bread flour T65"])
        #expect(r.input.water == 350)
        #expect(r.input.levain.grams == 150)
        #expect(r.input.levain.hydration == 0.5)
        #expect(r.input.yeast == Yeast(type: .instant, grams: 3))

        let ko = [
            piece("재료", x: 0.05, row: 0, width: 0.08),
            piece("양 (g)", x: 0.375, row: 0, width: 0.10),
            piece("비고", x: 0.666, row: 0, width: 0.08),
            piece("강력분", x: 0.05, row: 1, width: 0.10),
            piece("500", x: 0.375, row: 1, width: 0.07),
            piece("T65", x: 0.666, row: 1, width: 0.07),
            piece("물", x: 0.05, row: 2, width: 0.03),
            piece("350", x: 0.375, row: 2, width: 0.07),
            piece("르방", x: 0.05, row: 3, width: 0.06),
            piece("150", x: 0.375, row: 3, width: 0.07),
            piece("뒤흐", x: 0.666, row: 3, width: 0.06),
            piece("소금", x: 0.05, row: 4, width: 0.06),
            piece("10", x: 0.375, row: 4, width: 0.05),
        ]
        let k = RecipeTextParser.parse(OCRLayout.assembleRows(ko))
        #expect(k.name == nil)
        #expect(k.input.levain.grams == 150)
        #expect(k.input.levain.hydration == 0.5)

        let fr = [
            piece("Ingrédient", x: 0.05, row: 0, width: 0.20),
            piece("Poids (g)", x: 0.375, row: 0, width: 0.16),
            piece("Remarques", x: 0.666, row: 0, width: 0.18),
            piece("Farine T65", x: 0.05, row: 1, width: 0.20),
            piece("1000", x: 0.375, row: 1, width: 0.09),
            piece("Eau", x: 0.05, row: 2, width: 0.07),
            piece("700", x: 0.375, row: 2, width: 0.07),
            piece("eau froide du robinet", x: 0.666, row: 2, width: 0.30),
            piece("Levain", x: 0.05, row: 3, width: 0.13),
            piece("200", x: 0.375, row: 3, width: 0.07),
            piece("dur", x: 0.666, row: 3, width: 0.06),
            piece("Sel", x: 0.05, row: 4, width: 0.06),
            piece("20", x: 0.375, row: 4, width: 0.05),
        ]
        let f = RecipeTextParser.parse(OCRLayout.assembleRows(fr))
        #expect(f.name == nil)
        #expect(f.input.water == 700)
        #expect(f.input.levain.grams == 200)
        #expect(f.input.levain.hydration == 0.5)
    }

    @Test("단 판정 보조 — 수량·표 칸·옆 단 첫 조각")
    func columnPredicates() {
        #expect(OCRLayout.hasGramAmount("강력분 500g"))
        #expect(!OCRLayout.hasGramAmount("T65"))
        #expect(!OCRLayout.hasGramAmount("1. 볼에 물과 르방을 넣고 섞어주세요"))
        #expect(!OCRLayout.hasGramAmount("수분율 75%"))
        #expect(OCRLayout.isBareAmount("350 g"))
        #expect(OCRLayout.isBareAmount("(100%)"))
        #expect(!OCRLayout.isBareAmount("T65"))
        #expect(OCRLayout.startsColumn("1. 볼에 물과 르방을 넣고 섞어주세요"))
        #expect(OCRLayout.startsColumn("소금 10g"))
        #expect(OCRLayout.startsColumn("Mix the levain with the water"))
        #expect(!OCRLayout.startsColumn("Stiff (50%)"))
        #expect(!OCRLayout.startsColumn("instant"))
        #expect(!OCRLayout.startsColumn("T65"))
    }
}
