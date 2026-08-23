import Testing
@testable import LevainCore

@Suite("레시피 텍스트 파서 (규칙 기반)")
struct RecipeTextParserTests {
    @Test("표 형식 OCR 텍스트 — 사워도우 바게트 샘플")
    func baguetteSample() {
        let text = """
            G. 사워도우 바게트 (Baguette au levain)
            1. 재료
            재 료 양 (g)
            T65 트레디션 1000
            물 680
            르방 리퀴드 350
            소금 21
            바시나쥬 물 30
            """
        let r = RecipeTextParser.parse(text)
        #expect(r.name == "사워도우 바게트 (Baguette au levain)")
        #expect(r.input.flours.count == 1)
        #expect(r.input.flours[0].grams == 1000)
        #expect(r.input.flours[0].name.contains("T65"))
        #expect(r.input.water == 680)
        #expect(r.input.levain.grams == 350)
        #expect(r.input.levain.hydration == 1.0)
        #expect(r.input.salt == 21)
        #expect(r.input.bassinage == 30)
        #expect(r.matchedLineCount == 5)
        #expect(r.input.extras.isEmpty)  // "1. 재료" 헤더가 재료로 오인되지 않는다
        // 합산 수분율 검증: (680+30+175)/(1000+175) ≈ 75.3%
        let s = computeStats(r.input)
        #expect(abs(s.hydrationPct - (680.0 + 30 + 175) / 1175 * 100) < 1e-9)
    }

    @Test("자유 서술형 + 다중 밀가루 + 이스트·우유")
    func freeForm() {
        let text = """
            캉파뉴
            강력분 700g
            호밀가루 300 g
            물 650
            우유 100
            르방 뒤흐 200
            소금 20
            인스턴트 이스트 4
            호두 80
            총 반죽 무게 2054
            """
        let r = RecipeTextParser.parse(text)
        #expect(r.name == "캉파뉴")
        #expect(r.input.flours.count == 2)
        #expect(r.input.flours[1].grams == 300)
        #expect(r.input.water == 650)
        #expect(r.input.levain.hydration == 0.5)
        #expect(r.input.levain.type == .dur)
        #expect(r.input.yeast == Yeast(type: .instant, grams: 4))
        #expect(r.input.liquids.count == 1)
        #expect(r.input.liquids[0].waterRatio == 0.88)
        #expect(r.input.extras.count == 1)
        #expect(r.input.extras[0].name.contains("호두"))
        // "총 반죽 무게" 줄은 무시된다
        #expect(computeStats(r.input).doughWeight == 700 + 300 + 650 + 100 + 200 + 20 + 4 + 80)
    }

    @Test("천 단위 쉼표와 르방 수분율 % 표기")
    func commaAndPercent() {
        let text = """
            T65 1,000
            물 700
            르방 80% 300
            소금 20
            """
        let r = RecipeTextParser.parse(text)
        #expect(r.input.flours[0].grams == 1000)
        #expect(r.input.levain.grams == 300)
        #expect(abs(r.input.levain.hydration - 0.8) < 1e-9)
    }

    @Test("온도 표기가 있어도 재료 줄이 살아남는다")
    func temperatureAnnotations() {
        let r = RecipeTextParser.parse(
            """
            T65 1000
            물 680 (30°C)
            소금 20 30℃
            르방 리퀴드 200
            """)
        #expect(r.input.water == 680)
        #expect(r.input.salt == 20)
        #expect(r.input.flours[0].grams == 1000)
        #expect(r.matchedLineCount == 4)
    }

    @Test("물엿·시럽은 물이 아니라 기타 재료로 분류된다")
    func syrupNotWater() {
        let r = RecipeTextParser.parse(
            """
            강력분 500
            물 350
            물엿 30
            """)
        #expect(r.input.water == 350)
        #expect(r.input.extras.count == 1)
        #expect(r.input.extras[0].grams == 30)
    }

    @Test("재료가 없으면 matchedLineCount 0")
    func nothingMatched() {
        let r = RecipeTextParser.parse("오늘의 일기\n빵을 굽고 싶다")
        #expect(r.matchedLineCount == 0)
    }
}
