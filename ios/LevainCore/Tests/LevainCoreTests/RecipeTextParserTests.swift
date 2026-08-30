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

    @Test("인스타그램 스타일 — kg 단위·@멘션·stiff starter·숫자 선행")
    func instagramStyle() {
        let text = """
            Sun is shinning .... baguettes dough ... #dome action later !
            1kg flour ( @wessexmill )
            350 ferment ( starter stiff )
            730 water
            10 yeast fresh
            20 sea salt
            Large scoop of love or more...
            """
        let r = RecipeTextParser.parse(text)
        #expect(r.input.flours.count == 1)
        #expect(r.input.flours[0].grams == 1000)  // 1kg → 1000g
        #expect(!r.input.flours[0].name.contains("@"))
        #expect(!r.input.flours[0].name.contains("wessexmill"))
        #expect(r.input.levain.grams == 350)
        #expect(r.input.levain.hydration == 0.5)  // stiff starter → 뒤흐
        #expect(r.input.levain.type == .dur)
        #expect(r.input.water == 730)
        #expect(r.input.yeast == Yeast(type: .fresh, grams: 10))
        #expect(r.input.salt == 20)
        #expect(r.input.bassinage == 0)
        #expect(r.input.extras.isEmpty)
    }

    @Test("kg 표기 변형 — 1.5kg, 1키로, ㎏")
    func kgVariants() {
        let r = RecipeTextParser.parse(
            """
            강력분 1.5kg
            통밀 1키로
            물 1㎏
            소금 30
            """)
        #expect(r.input.flours[0].grams == 1500)
        #expect(r.input.flours[1].grams == 1000)
        #expect(r.input.water == 1000)
        #expect(r.input.salt == 30)
    }

    @Test("한국식 온도 표기 — '30도'가 물 양을 가리지 않는다")
    func koreanTemperature() {
        let a = RecipeTextParser.parse("강력분 500g\n물 350g (30도)\n소금 10g")
        #expect(a.input.water == 350)
        let b = RecipeTextParser.parse("강력분 500g\n물 350g 30도\n소금 10g")
        #expect(b.input.water == 350)
        // '도'로 끝나는 재료명은 건드리지 않는다
        let c = RecipeTextParser.parse("강력분 500\n물 350\n포도 100")
        #expect(c.input.extras.first?.grams == 100)
    }

    @Test("'수분율/hydration' 단어가 있어도 그램이 있는 재료 줄은 살아남는다")
    func hydrationWordOnIngredientLine() {
        let a = RecipeTextParser.parse("강력분 500g\n물 350g\n소금 10g\n르방 150g (수분율 100%)")
        #expect(a.input.levain.grams == 150)
        #expect(a.input.levain.hydration == 1.0)
        #expect(a.matchedLineCount == 4)

        let b = RecipeTextParser.parse("bread flour 500g\nwater 350g\nsalt 10g\n100% hydration starter 150g")
        #expect(b.input.levain.grams == 150)
        #expect(b.input.levain.hydration == 1.0)

        // 그램 없는 통계 줄은 여전히 걸러진다
        let c = RecipeTextParser.parse("강력분 500\n물 350\nHydration: 75%\n수분율 70%")
        #expect(c.matchedLineCount == 2)
    }

    @Test("괄호 안 분해 표기 — '500g (강력 400 + 통밀 100)'은 500g")
    func parenBreakdown() {
        let r = RecipeTextParser.parse("밀가루 500g (강력 400 + 통밀 100)\n물 350g\n소금 10g")
        #expect(r.input.flours.count == 1)
        #expect(r.input.flours[0].grams == 500)
        #expect(r.input.water == 350)
    }

    @Test("슬래시 한 줄 표기 분할 — '강력분 500 / 물 350 / 소금 10 / 르방 100'")
    func slashSeparated() {
        let r = RecipeTextParser.parse("강력분 500 / 물 350 / 소금 10 / 르방 100")
        #expect(r.input.flours.first?.grams == 500)
        #expect(r.input.water == 350)
        #expect(r.input.salt == 10)
        #expect(r.input.levain.grams == 100)
        #expect(r.matchedLineCount == 4)
        // 이름 속 슬래시는 분할하지 않는다
        let b = RecipeTextParser.parse("밀가루(강력/T65) 500g\n물 350")
        #expect(b.input.flours.count == 1)
        #expect(b.input.flours[0].grams == 500)
    }

    @Test("르방 빌드 섹션은 본반죽에 이중 합산되지 않는다")
    func levainBuildSection() {
        let r = RecipeTextParser.parse(
            """
            르방 만들기
            스타터 20g
            밀가루 60g
            물 60g

            본반죽
            밀가루 440g
            물 290g
            소금 9g
            르방 140g
            """)
        #expect(r.input.flours.count == 1)
        #expect(r.input.flours[0].grams == 440)
        #expect(r.input.water == 290)
        #expect(r.input.salt == 9)
        #expect(r.input.levain.grams == 140)
        #expect(r.input.levain.hydration == 1.0)  // 60/60에서 추정
        #expect(computeStats(r.input).doughWeight == 879)
    }

    @Test("빌드 섹션만 있으면 빌드 총량이 르방이 된다")
    func levainBuildOnly() {
        let r = RecipeTextParser.parse("르방 만들기\n스타터 20g\n밀가루 90g\n물 90g")
        #expect(r.input.levain.grams == 200)
        #expect(r.input.levain.hydration == 1.0)
        #expect(r.input.flours.isEmpty)
    }

    @Test("'만드는 법' 이후 서술부는 흡수하지 않는다")
    func methodSectionStops() {
        let r = RecipeTextParser.parse(
            """
            깜빠뉴
            강력분 500g
            물 350g
            소금 10g
            르방 100g

            만드는 법
            물 340g에 르방을 풀어주세요
            밀가루와 소금을 넣고 30분 휴지
            나머지 물 10g을 넣고 2분 믹싱
            """)
        #expect(r.name == "깜빠뉴")
        #expect(r.input.flours.first?.grams == 500)
        #expect(r.input.water == 350)
        #expect(r.input.salt == 10)
        #expect(r.input.levain.grams == 100)
        #expect(r.matchedLineCount == 4)
    }

    @Test("조절수·조정수는 바시나주로 분류된다")
    func adjustmentWater() {
        let r = RecipeTextParser.parse("강력분 500g\n물 320g\n조절수 30g\n소금 10g\n르방 100g")
        #expect(r.input.water == 320)
        #expect(r.input.bassinage == 30)
        let s = computeStats(r.input)
        #expect(abs(s.hydrationPct - (320.0 + 30 + 50) / 550 * 100) < 1e-9)
    }

    @Test("재료가 없으면 matchedLineCount 0")
    func nothingMatched() {
        let r = RecipeTextParser.parse("오늘의 일기\n빵을 굽고 싶다")
        #expect(r.matchedLineCount == 0)
    }
}
