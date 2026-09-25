import Foundation
import Testing
@testable import LevainCore

/// 웹 recipeParser.test.ts와 케이스·기대값을 동일하게 유지할 것

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

/// 웹과 ICU 의미를 맞춘 회귀 케이스 — 적대적 검증 워크플로에서 발견된 차이들
@Suite("플랫폼 패리티 회귀")
struct RecipeTextParserParityTests {
    @Test("'lait fermenté'는 르방이 아니라 우유다 (유니코드 단어 경계)")
    func laitFermente() {
        let r = RecipeTextParser.parse("farine T80 450g\neau 340g\nsel 9g\nlait fermenté 250g")
        #expect(r.input.levain.grams == 0)
        #expect(r.input.liquids.count == 1)
        #expect(r.input.liquids.first?.grams == 250)
        #expect(r.input.liquids.first?.waterRatio == 0.88)
        #expect(r.input.flours.first?.grams == 450)
        #expect(r.input.water == 340)
    }

    @Test("'pâte fermentée'는 기타 재료로 분류된다 (iOS와 동일)")
    func pateFermentee() {
        let r = RecipeTextParser.parse("farine T80 450g\neau 340g\nsel 9g\npâte fermentée 150g")
        #expect(r.input.levain.grams == 0)
        #expect(r.input.extras.count == 1)
        #expect(r.input.extras.first?.grams == 150)
    }

    @Test("문자가 붙은 T번호('밀T65')는 밀가루 판정하지 않는다")
    func attachedT() {
        let r = RecipeTextParser.parse("밀T65 500g\n물 350")
        #expect(r.input.flours.isEmpty)
        #expect(r.input.extras.first?.grams == 500)
        #expect(r.input.water == 350)
    }

    @Test("U+2028·단독 \\r 개행도 줄로 분리된다")
    func newlines() {
        let a = RecipeTextParser.parse("강력분 500\u{2028}물 350g\u{2028}소금 10g")
        #expect(a.input.flours.first?.grams == 500)
        #expect(a.input.water == 350)
        #expect(a.input.salt == 10)
        #expect(a.matchedLineCount == 3)
        let b = RecipeTextParser.parse("강력분 500\r물 350g\r소금 10g")
        #expect(b.input.water == 350)
        #expect(b.input.salt == 10)
    }

    @Test("이모지 한 글자 줄은 제목이 되지 않는다 (자소 기준 길이)")
    func emojiTitle() {
        let r = RecipeTextParser.parse("🥖\n깜빠뉴\n강력분 500\n물 350")
        #expect(r.name == "깜빠뉴")
    }

    @Test("'르방 100g (20%)'의 베이커스 퍼센트는 수분율로 오독하지 않는다")
    func bakersPercent() {
        let r = RecipeTextParser.parse("강력분 500\n물 350\n르방 100g (20%)")
        #expect(r.input.levain.grams == 100)
        #expect(r.input.levain.hydration == 1.0)
        #expect(r.input.levain.type == .liquide)
    }

    @Test("르방 빌드 섹션의 물엿은 수분율 추정에 들어가지 않는다")
    func buildSyrup() {
        let r = RecipeTextParser.parse("르방 만들기\n밀가루 100\n물엿 100\n물 50")
        #expect(r.input.levain.grams == 250)  // 총량에는 포함
        #expect(r.input.levain.hydration == 0.5)  // 50/100 — 물엿 제외
    }

    @Test("'총량 950g' 합계 줄은 유령 재료가 되지 않는다")
    func totalAmountLine() {
        let r = RecipeTextParser.parse("강력분 500\n물 350\n총량 950g")
        #expect(r.input.extras.isEmpty)
        #expect(r.matchedLineCount == 2)
    }

    @Test("시간 표기(6시간·30분)는 그램으로 합산되지 않는다")
    func durations() {
        let build = RecipeTextParser.parse("르방 만들기\n스타터 20g\n밀가루 90g\n물 90g\n실온 6시간 발효")
        #expect(build.input.levain.grams == 200)  // 6이 더해지면 206
        #expect(build.input.levain.hydration == 1.0)
        let main = RecipeTextParser.parse("강력분 500\n물 350\n벌크 발효 4시간")
        #expect(main.matchedLineCount == 2)
        #expect(main.input.extras.isEmpty)
    }

    @Test("'물 100g + 50g' 합산 표기는 더해서 계산한다")
    func plusSum() {
        let r = RecipeTextParser.parse("강력분 500\n물 100g + 50g\n소금 10")
        #expect(r.input.water == 150)
        // 괄호 분해 표기는 여전히 바깥 값 하나만
        let b = RecipeTextParser.parse("밀가루 500g (강력 400 + 통밀 100)\n물 350g")
        #expect(b.input.flours.first?.grams == 500)
    }

    @Test("NFD로 분해된 텍스트도 NFC 정규화 후 파싱된다")
    func nfd() {
        let r = RecipeTextParser.parse("강력분 500\n물 350".decomposedStringWithCanonicalMapping)
        #expect(r.input.water == 350)
        #expect(r.input.flours.first?.grams == 500)
    }

    @Test("CRLF는 줄바꿈 하나로 정리된다")
    func crlf() {
        #expect(RecipeTextParser.cleanForParsing("강력분 500\r\n물 350") == "강력분 500\n물 350")
        let r = RecipeTextParser.parse("강력분 500\r\n물 350\r\n소금 10")
        #expect(r.matchedLineCount == 3)
    }

    @Test("르방 빌드 섹션의 'gâteau'는 물(eau)이 아니다")
    func buildGateau() {
        let r = RecipeTextParser.parse("르방 만들기\n밀가루 100\n물 100\ngâteau 50")
        #expect(r.input.levain.grams == 250)
        #expect(r.input.levain.hydration == 1.0)
    }
}

/// 가져오기 오인식 회귀 — 리뷰에서 재현된 실사용 입력들
@Suite("가져오기 오인식 회귀")
struct RecipeTextParserImportRegressionTests {
    @Test("베이커스 % 표의 르방 %는 수분율이 아니다")
    func bakersPercentTable() {
        let a = RecipeTextParser.parse(
            "Bread flour 450g (90%) / Whole wheat 50g (10%) / Water 375g (75%) / Starter 100g (20%) / Salt 10g (2%)")
        #expect(a.input.levain.grams == 100)
        #expect(a.input.levain.hydration == 1.0)
        #expect(a.input.levain.type == .liquide)
        #expect(a.levainHydrationExplicit == false)
        #expect(abs(computeStats(a.input).hydrationPct - 425.0 / 550 * 100) < 1e-9)
        let b = RecipeTextParser.parse("강력분 1000g 100% / 물 700g 70% / 르방 200g 20% / 소금 20g 2%")
        #expect(b.input.levain.hydration == 1.0)
        #expect(abs(computeStats(b.input).hydrationPct - 800.0 / 1100 * 100) < 1e-9)
        let c = RecipeTextParser.parse("강력분 500\n물 350\n르방 20% 100g")
        #expect(c.input.levain.grams == 100)
        #expect(c.input.levain.hydration == 1.0)
    }

    @Test("levainHydrationExplicit — 텍스트가 밝힌 르방 수분율만 true")
    func hydrationExplicitFlag() {
        #expect(RecipeTextParser.parse("강력분 500\n물 350\n르방 리퀴드 200").levainHydrationExplicit)
        #expect(RecipeTextParser.parse("강력분 500\n물 350\n르방 뒤흐 200").levainHydrationExplicit)
        #expect(RecipeTextParser.parse("강력분 500\n물 350\n르방 80% 300").levainHydrationExplicit)
        #expect(!RecipeTextParser.parse("강력분 500\n물 350\n르방 200").levainHydrationExplicit)
        let build = RecipeTextParser.parse("르방 만들기\n스타터 20g\n밀가루 100g\n물 50g")
        #expect(build.input.levain.hydration == 0.5)
        #expect(!build.levainHydrationExplicit)
    }

    @Test("'만드는 방법'·'순서'·'Steps' 헤더도 서술부 파싱을 멈춘다")
    func methodHeaderVariants() {
        let steps = [
            "1. 물 350g에 르방 100g을 넣고 섞어줍니다",
            "2. 강력분 500g을 넣고 섞어요",
            "3. 소금 10g을 넣고 30분 뒤 폴딩",
        ]
        for header in ["만드는 방법", "순서"] {
            let r = RecipeTextParser.parse(
                (["깜빠뉴", "강력분 500g", "물 350g", "르방 100g", "소금 10g", "", header] + steps)
                    .joined(separator: "\n"))
            #expect(r.input.flours.count == 1)
            #expect(r.input.salt == 10)
            #expect(r.input.levain.grams == 100)
            #expect(computeStats(r.input).doughWeight == 960)
        }
        let en = RecipeTextParser.parse(
            """
            Country loaf
            Bread flour 500g
            Water 350g
            Levain 100g
            Salt 10g

            Steps
            1. Mix water 350g with levain 100g
            2. Add bread flour 500g and mix
            """)
        #expect(computeStats(en.input).doughWeight == 960)
    }

    @Test("합계·분할 줄은 유령 재료가 되지 않는다")
    func totalLines() {
        for total in [
            "총반죽무게 960g",
            "반죽 무게 960g",
            "전체 반죽 960g",
            "계 960",
            "총량 960g",
            "분할 480g x 2",
            "반죽 4분할 240g",
            "- 총량 960g",
            "• 총반죽무게 960g",
            "반죽 총 무게 960g",
            "반죽 총량 960g",
            "반죽총중량 960g",
            "밀가루 총 500g",
            "(합계 960g)",
            "(Total 960g)",
            "(총 반죽 960g)",
            "재료 (총 960g)",
            "재료 (합계 960g)",
            "Ingredients (total 960g)",
            "반죽 (총 960g)",
        ] {
            let r = RecipeTextParser.parse("강력분 500g\n물 350g\n르방 100g\n소금 10g\n\(total)")
            #expect(r.input.extras.isEmpty)
            #expect(r.matchedLineCount == 4)
            #expect(computeStats(r.input).doughWeight == 960)
        }
    }

    @Test("괄호 안 '총' 부연은 재료 줄을 지우지 않는다")
    func totalInsideParens() {
        let a = RecipeTextParser.parse("강력분 1000g\n물 700g (총 수분율 75%)\n소금 20g")
        #expect(a.input.water == 700)
        #expect(a.matchedLineCount == 3)
        let b = RecipeTextParser.parse("강력분 1000g\n물 700g\n소금 20g (총 밀가루 대비 2%)")
        #expect(b.input.salt == 20)
        let c = RecipeTextParser.parse("강력분 500g\n물 350g\n르방 100g (총 수분율 75%)\n소금 10g")
        #expect(c.input.levain.grams == 100)
        #expect(c.input.levain.hydration == 1.0)  // 반죽 전체의 %는 르방 수분율이 아니다
        #expect(!c.levainHydrationExplicit)
        #expect(c.matchedLineCount == 4)
        for note in ["(total hydration 75%)", "(hydratation totale 75%)"] {
            let d = RecipeTextParser.parse("강력분 500g\n물 350g\n르방 100g \(note)\n소금 10g")
            #expect(d.input.levain.grams == 100)
            #expect(d.input.levain.hydration == 1.0)
            #expect(!d.levainHydrationExplicit)
        }
    }

    @Test("컵·스푼 표기는 괄호 안 그램을 쓴다")
    func cupsWithGrams() {
        let r = RecipeTextParser.parse(
            "3 3/4 cups (450g) bread flour / 1 1/2 cups (340g) water / 1/2 cup (113g) starter / 2 tsp (12g) salt")
        #expect(r.input.flours.count == 1)
        #expect(r.input.flours.first?.grams == 450)
        #expect(r.input.flours.first?.name == "bread flour")
        #expect(r.input.water == 340)
        #expect(r.input.levain.grams == 113)
        #expect(r.input.salt == 12)
        #expect(r.matchedLineCount == 4)
    }

    @Test("개수·oz·분수·ml 단위를 그램으로 오독하지 않는다")
    func unitKinds() {
        let eggs = RecipeTextParser.parse("강력분 500g\n물 350g\n2 large eggs (100g)")
        #expect(eggs.input.liquids.count == 1)
        #expect(eggs.input.liquids.first?.grams == 100)
        #expect(eggs.input.liquids.first?.name == "eggs")
        let oz = RecipeTextParser.parse("Bread flour 17.6 oz\nWater 350g")
        #expect(abs((oz.input.flours.first?.grams ?? 0) - 17.6 * 28.349523125) < 1e-9)
        #expect(oz.input.flours.first?.name == "Bread flour")
        let half = RecipeTextParser.parse("강력분 500g\n물 350g\n이스트 1/2")
        #expect(half.input.yeast.grams == 0.5)
        let milk = RecipeTextParser.parse("강력분 500g\n물 350g\n우유 200ml")
        #expect(milk.input.liquids.first?.name == "우유")
        #expect(milk.input.liquids.first?.grams == 200)
        let times = RecipeTextParser.parse("강력분 500g x 2\n물 350g")
        #expect(times.input.flours.first?.grams == 500)
        // 개수만 있는 줄은 그램이 아니다
        let count = RecipeTextParser.parse("강력분 500g\n물 350g\n계란 2개")
        #expect(count.input.liquids.isEmpty)
        #expect(count.matchedLineCount == 2)
    }

    @Test("범위·두 배합 표기('350/370g')는 분수가 아니다")
    func slashRanges() {
        #expect(RecipeTextParser.parse("강력분 500g\n물 350/370g").input.water == 370)
        let fr = RecipeTextParser.parse("Eau 350/370 g\nFarine T65 500 g")
        #expect(fr.input.water == 370)
        #expect(fr.input.flours.first?.grams == 500)
        #expect(RecipeTextParser.parse("강력분 250/500g\n물 350g").input.flours.first?.grams == 500)
        #expect(RecipeTextParser.parse("강력분 500g\n물 350g\n이스트 1/2").input.yeast.grams == 0.5)
    }

    @Test("파운드·온스 복합 표기('1 lb 2 oz')는 한 수량")
    func poundsAndOunces() {
        let expected = 453.59237 + 2 * 28.349523125
        let a = RecipeTextParser.parse("Bread flour 1 lb 2 oz (510g)\nWater 350g")
        #expect(abs((a.input.flours.first?.grams ?? 0) - expected) < 1e-9)
        #expect(a.input.flours.first?.name == "Bread flour")
        let b = RecipeTextParser.parse("Bread flour 1 pound 2 ounces\nWater 350g")
        #expect(abs((b.input.flours.first?.grams ?? 0) - expected) < 1e-9)
    }

    @Test("프랑스식 kg 소수 쉼표 — '0,700 kg'은 700g")
    func frenchKgDecimalComma() {
        let r = RecipeTextParser.parse(
            "Farine T65 1,000 kg\nEau 0,700 kg\nLevain liquide 0,200 kg\nSel 0,020 kg")
        #expect(r.input.flours.first?.grams == 1000)
        #expect(r.input.water == 700)
        #expect(r.input.levain.grams == 200)
        #expect(r.input.salt == 20)
    }

    @Test("공백 천 단위 구분 — '1 000 g'")
    func spaceThousands() {
        for sep in [" ", "\u{00A0}", "\u{202F}"] {
            let r = RecipeTextParser.parse("Farine T65 1\(sep)000 g\nEau 700 g")
            #expect(r.input.flours.first?.grams == 1000)
            #expect(r.input.flours.first?.name == "Farine T65")
            #expect(r.input.water == 700)
        }
        let gr = RecipeTextParser.parse("Farine T65 1 000 gr\nEau 700 gr\nSel 20 gr")
        #expect(gr.input.flours.first?.grams == 1000)
        #expect(gr.input.salt == 20)
        #expect(gr.matchedLineCount == 3)
        #expect(RecipeTextParser.parse("Farine 1 000 grammes\nEau 700 grammes").input.flours.first?.grams == 1000)
        #expect(RecipeTextParser.parse("Eau 1 000 ml\nFarine 1 500 g").input.water == 1000)
    }

    @Test("공백 천 단위는 앞의 형번·% 열 수를 붙이지 않는다")
    func spaceThousandsNeighbors() {
        let type = RecipeTextParser.parse("Farine type 65 500 g\nEau 350 g")
        #expect(type.input.flours.first?.grams == 500)
        let table = RecipeTextParser.parse("Farine 100 500 g\nEau 70 350 g\nLevain 20 100 g\nSel 2 10 g")
        #expect(table.input.flours.first?.grams == 500)
        #expect(table.input.water == 350)
        #expect(table.input.levain.grams == 100)
        #expect(table.input.salt == 10)
    }

    @Test("kg 열 표의 단위 없는 소수 쉼표 — '0,700'은 '1,000'과 같은 배율")
    func kgColumnTable() {
        let r = RecipeTextParser.parse(
            "Ingrédients Quantité (kg)\nFarine T65 1,000\nEau 0,700\nLevain liquide 0,200\nSel 0,020")
        #expect(r.input.flours.first?.grams == 1000)
        #expect(r.input.water == 700)
        #expect(r.input.levain.grams == 200)
        #expect(r.input.salt == 20)
    }

    @Test("컵·스푼·개수만 있는 줄은 섹션 헤더가 되지 않는다")
    func measureOnlyLines() {
        let starter = RecipeTextParser.parse("스타터 2큰술 (리프레시 후 사용)\n강력분 500g\n물 350g\n소금 10g")
        #expect(starter.input.flours.first?.grams == 500)
        #expect(starter.input.water == 350)
        #expect(starter.input.salt == 10)
        #expect(starter.input.levain.grams == 0)
        let order = RecipeTextParser.parse("강력분 500\n물 350\n소금 1작은술 (넣는 순서 주의)\n르방 100")
        #expect(order.input.levain.grams == 100)
        // 괄호 속 개수는 분량 표기 — 섹션 머리글은 그대로 인식한다
        let servings = RecipeTextParser.parse(
            "르방 만들기\n르방 20g\n밀가루 50g\n물 50g\n본반죽 (빵 2개 분량)\n강력분 500g\n물 350g\n소금 10g")
        #expect(servings.input.flours.first?.grams == 500)
        #expect(servings.input.water == 350)
        #expect(servings.input.salt == 10)
        #expect(servings.input.levain.grams == 120)
    }

    @Test("르방 표기 변형 — 르뱅·Leaven·뒤르")
    func levainSpellings() {
        let a = RecipeTextParser.parse("강력분 500g\n물 350g\n르뱅 100g\n소금 10g")
        #expect(a.input.levain.grams == 100)
        #expect(a.input.extras.isEmpty)
        let tartine = RecipeTextParser.parse(
            "Leaven 200g\nBread flour 900g\nWhole wheat flour 100g\nWater 750g\nSalt 20g")
        #expect(tartine.input.levain.grams == 200)
        #expect(tartine.input.levain.flourName == nil)
        #expect(tartine.input.extras.isEmpty)
        #expect(abs(computeStats(tartine.input).hydrationPct - 850.0 / 1100 * 100) < 1e-9)
        let dur = RecipeTextParser.parse("강력분 500g\n물 350g\n르방 뒤르 150g")
        #expect(dur.input.levain.hydration == 0.5)
    }

    @Test("'leavening'·'르뱅쿠키'는 르방이 아니다")
    func notLevain() {
        let a = RecipeTextParser.parse("강력분 500g\n물 350g\nleavening 5g")
        #expect(a.input.levain.grams == 0)
        #expect(a.input.extras.count == 1)
        let cookie = RecipeTextParser.parse("르뱅쿠키 만들기\n박력분 200g\n버터 100g\n초코칩 80g")
        #expect(cookie.name == "르뱅쿠키 만들기")
        #expect(cookie.input.levain.grams == 0)
        #expect(cookie.input.flours.count == 1)
        #expect(cookie.input.flours.first?.grams == 200)
        #expect(cookie.input.extras.count == 2)
    }

    @Test("부분 문자열 오분류 — unsalted·곡물·식물성·durum·IDY·코코아가루")
    func substringMisclassification() {
        let butter = RecipeTextParser.parse("Bread flour 500g\nWater 350g\nUnsalted butter 60g\nSalt 9g")
        #expect(butter.input.salt == 9)
        #expect(butter.input.extras.map(\.name) == ["Unsalted butter"])
        #expect(butter.input.extras.map(\.grams) == [60])
        let grain = RecipeTextParser.parse("강력분 500\n물 380\n곡물 믹스 80\n식물성 오일 20\n소금 10")
        #expect(grain.input.water == 380)
        #expect(grain.input.extras.count == 2)
        let durum = RecipeTextParser.parse("T65 500g\nwater 350g\nDurum levain 100g")
        #expect(durum.input.levain.grams == 100)
        #expect(durum.input.levain.hydration == 1.0)
        let idy = RecipeTextParser.parse("T65 500g\nwater 350g\nIDY 3g")
        #expect(idy.input.yeast == Yeast(type: .instant, grams: 3))
        let cocoa = RecipeTextParser.parse("강력분 500g\n물 350g\n코코아가루 30g")
        #expect(cocoa.input.flours.count == 1)
        #expect(cocoa.input.extras.first?.grams == 30)
    }

    @Test("'@75%'는 멘션이 아니라 르방 수분율이다")
    func atPercent() {
        let r = RecipeTextParser.parse("T65 500g\nwater 350g\nLevain 150g @75%")
        #expect(r.input.levain.hydration == 0.75)
        #expect(RecipeTextParser.cleanForParsing("Levain 150g @75%") == "Levain 150g @75%")
        #expect(RecipeTextParser.cleanForParsing("flour @7thbakery 500g") == "flour  500g")
    }

    @Test("숫자가 앞서는 초코칩·분유는 시간 표기로 지우지 않는다")
    func numberFirstIngredients() {
        let chips = RecipeTextParser.parse("강력분 500\n물 350\n르방 100\n50 초코칩")
        #expect(chips.input.extras.map(\.name) == ["초코칩"])
        #expect(chips.input.extras.map(\.grams) == [50])
        #expect(chips.name == nil)
        #expect(chips.matchedLineCount == 4)
        let milk = RecipeTextParser.parse("강력분 500\n물 350\n20 분유")
        #expect(milk.input.extras.map(\.name) == ["분유"])
        #expect(milk.input.extras.map(\.grams) == [20])
        let more = RecipeTextParser.parse("강력분 500\n물 350\n100 초코칩")
        #expect(more.input.extras.map(\.name) == ["초코칩"])
        #expect(more.input.extras.map(\.grams) == [100])
        #expect(more.matchedLineCount == 3)
    }

    @Test("시간 표기만 남은 공정 줄은 재료도 제목도 아니다")
    func durationOnlyLines() {
        let rest = RecipeTextParser.parse("강력분 500\n물 350\n30분간 휴지")
        #expect(rest.input.extras.isEmpty)
        #expect(rest.matchedLineCount == 2)
        #expect(rest.name == nil)
        #expect(RecipeTextParser.parse("강력분 500\n물 350\n오토리즈 30분").name == nil)
        #expect(RecipeTextParser.parse("강력분 500\n물 350\n벌크 발효 4시간").name == nil)
        let build = RecipeTextParser.parse("르방 만들기\n스타터 20g\n밀가루 90g\n물 90g\n30분마다 저어주기")
        #expect(build.input.levain.grams == 200)
        let levain = RecipeTextParser.parse("강력분 500g\n물 350g\n르방 100g 12시간\n소금 10g")
        #expect(levain.input.levain.grams == 100)
    }

    @Test("차수·범위 표기가 남은 공정 줄은 재료가 아니다")
    func ordinalProcessLines() {
        let r = RecipeTextParser.parse(
            "캄파뉴\n강력분 500g\n물 350g\n소금 10g\n르방 100g\n1차 발효 3~4시간\n3회 폴딩")
        #expect(r.name == "캄파뉴")
        #expect(r.input.extras.isEmpty)
        #expect(r.matchedLineCount == 4)
        let en = RecipeTextParser.parse(
            "Sourdough\n500 g flour\n350 g water\n10 g salt\n100 g starter (100% hydration)\n1차 발효 4시간")
        #expect(en.input.extras.isEmpty)
        #expect(en.matchedLineCount == 4)
        let more = RecipeTextParser.parse(
            "강력분 500g\n물 350g\n르방 100g\n2차발효 1～2시간\n30분 간격으로 폴딩 3~4회\n2번째 접기\nBulk ferment 3-4 hours")
        #expect(more.input.extras.isEmpty)
        #expect(more.input.levain.grams == 100)
        #expect(more.matchedLineCount == 3)
        // 띄어 쓴 대시는 범위가 아니다 — 앞의 단위 없는 재료 양을 지우지 않는다
        #expect(RecipeTextParser.parse("강력분 500\n물 350 - 30분 후 투입").input.water == 350)
        let only = RecipeTextParser.parse("1차 발효")
        #expect(only.name == nil)
        #expect(only.matchedLineCount == 0)
        let tea = RecipeTextParser.parse("강력분 500g\n물 350g\n녹차 가루 10g\n말차 5g")
        #expect(tea.input.extras.map(\.name) == ["녹차 가루", "말차"])
        #expect(tea.input.extras.map(\.grams) == [10, 5])
    }

    @Test("키캡 번호(1️⃣ …)는 수량이 아니라 섹션·단계 번호다")
    func keycapNumbers() {
        let r = RecipeTextParser.parse(
            RecipeTextParser.cleanForParsing(
                "🥖 캄파뉴\n1️⃣ 르방 만들기\n스타터 20g\n밀가루 100g\n물 100g\n2️⃣ 본반죽\n강력분 450g\n물 300g\n소금 10g\n"
                    + "3️⃣ 만드는 방법\n물 300g에 르방을 풀고 섞어요\n강력분 450g을 넣고 섞어요"))
        #expect(r.input.flours.map(\.name) == ["강력분"])
        #expect(r.input.flours.map(\.grams) == [450])
        #expect(r.input.water == 300)
        #expect(r.input.salt == 10)
        #expect(r.input.levain.grams == 220)
        #expect(r.input.levain.hydration == 1.0)
        #expect(r.input.extras.isEmpty)
        #expect(r.matchedLineCount == 6)
        let short = RecipeTextParser.parse("캄파뉴\n1️⃣ 강력분 450\n2️⃣ 물 300\n3️⃣ 르방\n4️⃣ 소금 10")
        #expect(short.input.flours.map(\.name) == ["강력분"])
        #expect(short.input.levain.grams == 0)
        #expect(
            RecipeTextParser.cleanForParsing("1️⃣ 르방 만들기\n2️⃣. 본반죽\n🔟 소금 10g\n#️⃣ 물 300g")
                == "르방 만들기\n본반죽\n소금 10g\n물 300g")
        // 숫자 뒤 VS16이 숫자를 끊지 않는다 — 양쪽 모두 코드포인트 단위로 토큰화
        #expect(RecipeTextParser.parse("강력분 500\u{FE0F}g\n물 350g").input.flours.first?.grams == 500)
    }
}
