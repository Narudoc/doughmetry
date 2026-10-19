import Foundation
import Testing
@testable import DoughmetryCore

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
        // 첫 줄은 서술문이고, 재료 뒤의 맺음말은 이름이 아니다
        #expect(r.name == nil)
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

    @Test("괄호 속 '~니다' 메모는 재료 줄을 지우지 않는다")
    func politeNoteInParens() {
        let r = RecipeTextParser.parse(
            """
            강력분 500g
            물 350g (나눠 넣습니다)
            소금 10g (취향껏 줄여도 됩니다)
            르방 100g (전날 밤 리프레시합니다)
            물 340g에 르방을 풀어주세요
            (반죽이 매끈해질 때까지 치댑니다)
            """)
        #expect(r.input.water == 350)
        #expect(r.input.salt == 10)
        #expect(r.input.levain.grams == 100)
        // 괄호 밖 서술문과 괄호뿐인 서술문은 여전히 건너뛴다 (괄호뿐인 줄이 제목으로 잡히지도 않는다)
        #expect(r.matchedLineCount == 4)
        #expect(r.name == nil)
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

    @Test("아포스트로피 뒤 eau는 물이고, 문자에 붙은 dur·IDY는 낱말이 아니다 (iOS 17 단어 경계)")
    func apostropheAndAttachedWords() {
        for line in ["350 g d'eau", "350 g d’eau", "l'eau 350g"] {
            let r = RecipeTextParser.parse("farine T65 500g\n\(line)\nsel 10g")
            #expect(r.input.water == 350, "\(line)")
            #expect(r.input.extras.isEmpty, "\(line)")
            #expect(r.matchedLineCount == 3, "\(line)")
        }
        let dur = RecipeTextParser.parse("강력분 500g\n물 350g\n르방dur 200")
        #expect(dur.input.levain.grams == 200)
        #expect(dur.input.levain.hydration == 1.0)
        #expect(!dur.levainHydrationExplicit)
        let idy = RecipeTextParser.parse("강력분 500g\n물 350g\n이스트IDY 3g")
        #expect(idy.input.yeast == Yeast(type: .fresh, grams: 3))
    }

    @Test("대문자 I 키워드는 기기 지역과 무관하게 읽는다 (터키어 로캘의 I → ı)")
    func capitalIKeywords() {
        let r = RecipeTextParser.parse(
            "BREAD FLOUR 500G\nWATER 350G\nLIQUID LEVAIN 100G\nMILK 50G\nInstant yeast 2G\nSALT 10G")
        #expect(r.input.flours.map(\.grams) == [500])
        #expect(r.input.water == 350)
        #expect(r.input.levain.grams == 100)
        #expect(r.levainHydrationExplicit)
        #expect(r.input.liquids.map(\.waterRatio) == [0.88])
        #expect(r.input.yeast == Yeast(type: .instant, grams: 2))
        #expect(r.input.salt == 10)
        #expect(r.input.extras.isEmpty)
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

    @Test("글자에 붙은 VS16·키캡 테두리는 걷어낸다 (iOS는 앞 글자와 한 자소로 묶는다)")
    func strayVariationSelectors() {
        for salt in ["소금\u{FE0F} 10g", "소금\u{20E3} 10g", "소금\u{FE0F}\u{20E3} 10g"] {
            #expect(RecipeTextParser.cleanForParsing(salt) == "소금 10g", "\(salt)")
            for r in [
                RecipeTextParser.parse(RecipeTextParser.cleanForParsing("강력분 500g\n물 350g\n\(salt)")),
                RecipeTextParser.parse("강력분 500g\n물 350g\n\(salt)"),
            ] {
                #expect(r.input.salt == 10, "\(salt)")
                #expect(r.input.extras.isEmpty, "\(salt)")
            }
        }
        #expect(RecipeTextParser.cleanForParsing("Levain\u{FE0F} liquide 200g") == "Levain liquide 200g")
        // 이모지·키캡 바탕 뒤의 VS16은 그대로 — 키캡 번호는 여전히 걷힌다
        #expect(RecipeTextParser.cleanForParsing("❤️ 캄파뉴\n✔️ 재료") == "❤️ 캄파뉴\n✔️ 재료")
        #expect(
            RecipeTextParser.cleanForParsing("1️⃣ 르방 만들기\n#️⃣ 물 300g\n🔟️ 소금 10g")
                == "르방 만들기\n물 300g\n소금 10g")
        #expect(RecipeTextParser.cleanForParsing("강력분 500\u{FE0F}g") == "강력분 500g")
        #expect(RecipeTextParser.parse("비가 20\u{FE0F}g").input.levain.grams == 20)
        // CRLF 뒤에 VS16·키캡 테두리가 붙어도 한 줄바꿈이다
        #expect(RecipeTextParser.cleanForParsing("소금 10g\r\n\u{FE0F}물 350g") == "소금 10g\n물 350g")
        // 분해 한글 음절 속에 끼인 VS16을 걷어내면 다시 한 음절로 합친다
        #expect(RecipeTextParser.cleanForParsing("\u{1106}\u{116E}\u{FE0F}\u{11AF} 350") == "물 350")
        let w = RecipeTextParser.parse("강력분 500\n\u{1106}\u{116E}\u{FE0F}\u{11AF} 350")
        #expect(w.input.water == 350)
        #expect(w.input.extras.isEmpty)
        let f = RecipeTextParser.parse(
            "\u{1100}\u{1161}\u{FE0F}\u{11BC}\u{1105}\u{1167}\u{11A8}\u{1107}\u{116E}\u{11AB} 500\n물 350")
        #expect(f.input.flours.map(\.name) == ["강력분"])
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

    @Test("시간 약어('Bulk 4h', 'Pointage 3h30')는 그램이 아니다")
    func hourAbbreviations() {
        let fr = RecipeTextParser.parse(
            "farine T65 500g\neau 350g\nsel 10g\nlevain 100g\nMix and fold. Bulk 4h.\nPointage 3h30 à 24°C\nApprêt 1h\nPousse 2 H\nPointage 2 h 30 à 24 °C\nApprêt 1 h 15\nRepos 3 heures\nCuisson 45 mn")
        #expect(fr.input.extras.isEmpty)
        #expect(fr.input.levain.grams == 100)
        #expect(fr.matchedLineCount == 4)
        #expect(fr.name == nil)
        #expect(computeStats(fr.input).doughWeight == 960)
        // 숫자 뒤 h로 시작하는 낱말은 시간이 아니다
        let nuts = RecipeTextParser.parse("farine 500g\neau 350g\n50 hazelnuts\nnoisettes 2 hachées 30g")
        #expect(nuts.input.extras.map(\.name) == ["hazelnuts", "noisettes hachées"])
        #expect(nuts.input.extras.map(\.grams) == [50, 30])
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

/// 웹 recipeParser.test.ts의 'SNS 캡션·앱 배합표 가져오기'와 케이스·기대값을 동일하게 유지할 것
@Suite("SNS 캡션·앱 배합표 가져오기")
struct RecipeImportTextTests {
    static let caption = """
        🍞 무화과 호두 캄파뉴 (2개 분량)
        오늘은 르방 리퀴드로 구운 캄파뉴 레시피 공유해요 🙌

        ✔️ 재료
        강력분 400g
        통밀가루 100g
        물 340g (+ 바시나주 25g)
        르방 100g
        소금 10g
        건무화과 80g
        호두 60g

        ✔️ 과정
        1. 오토리즈 1시간
        2. 르방, 소금 넣고 믹싱 후 바시나주
        3. 1차 발효 4시간 (30분 간격 폴딩 3회)
        4. 성형 후 냉장 12시간
        5. 250도 예열, 230도 40분

        #사워도우 #캄파뉴 #천연발효빵 #홈베이킹 @bakery_kim
        """

    @Test("물 줄의 바시나주 부연은 물과 바시나주로 나눈다")
    func bassinageClause() {
        func parse(_ water: String) -> ParsedRecipeText {
            RecipeTextParser.parse("강력분 500g\n\(water)\n르방 100g\n소금 10g")
        }
        for line in [
            "물 340g (+ 바시나주 25g)", "물 340g + 바시나주 25g", "물 365g (바시나주 25g 포함)",
            "물 340g (바시나주 25g 별도)", "Water 340g + bassinage 25g",
        ] {
            let r = parse(line)
            #expect(r.input.water == 340, "\(line)")
            #expect(r.input.bassinage == 25, "\(line)")
            #expect(r.matchedLineCount == 4, "\(line)")
        }
        let own = RecipeTextParser.parse("강력분 500g\n물 320g\n바시나주 30g")
        #expect(own.input.water == 320)
        #expect(own.input.bassinage == 30)
        // 키워드 뒤에 양이 없으면 줄 전체가 바시나주다 (이전과 같음)
        let bare = parse("물 30g (바시나주)")
        #expect(bare.input.water == 0)
        #expect(bare.input.bassinage == 30)
    }

    @Test("인스타그램 캡션 — 분량 괄호·서술문·글머리 이모지·공정 노트")
    func instagramCaption() {
        let r = RecipeTextParser.parse(RecipeTextParser.cleanForParsing(Self.caption))
        #expect(r.name == "무화과 호두 캄파뉴")
        #expect(r.input.flours.map(\.name) == ["강력분", "통밀가루"])
        #expect(r.input.flours.map(\.grams) == [400, 100])
        #expect(r.input.water == 340)
        #expect(r.input.bassinage == 25)
        #expect(r.input.levain.grams == 100)
        #expect(r.input.salt == 10)
        #expect(r.input.extras.map(\.name) == ["건무화과", "호두"])
        #expect(r.input.extras.map(\.grams) == [80, 60])
        #expect(r.pieces == 2)
        #expect(
            r.methodNote == """
                ✔️ 과정
                1. 오토리즈 1시간
                2. 르방, 소금 넣고 믹싱 후 바시나주
                3. 1차 발효 4시간 (30분 간격 폴딩 3회)
                4. 성형 후 냉장 12시간
                5. 250도 예열, 230도 40분
                """)
        // 정리하지 않은 원문을 바로 넣어도 노트에 해시태그·멘션이 남지 않는다
        let raw = RecipeTextParser.parse(Self.caption)
        #expect(raw.methodNote?.contains("#") == false)
        #expect(raw.methodNote?.contains("@") == false)
        #expect(raw.methodNote?.hasSuffix("230도 40분") == true)
    }

    @Test("제목 — 분량 괄호는 걷어내고 서술문은 이름으로 고르지 않는다")
    func titleCandidates() {
        let servings = RecipeTextParser.parse("🍞 무화과 호두 캄파뉴 (2개 분량)\n강력분 400g\n물 300g")
        #expect(servings.name == "무화과 호두 캄파뉴")
        #expect(servings.pieces == 2)
        #expect(RecipeTextParser.parse("오늘은 캄파뉴 레시피 공유해요 🙌\n강력분 400g\n물 300g").name == nil)
        #expect(RecipeTextParser.parse("드디어 성공했어요!!\n강력분 400g\n물 300g").name == nil)
        #expect(RecipeTextParser.parse("이 빵 어때?\n강력분 400g\n물 300g").name == nil)
        #expect(RecipeTextParser.parse("Sourdough (2 loaves)\n500 g flour\n350 g water").name == "Sourdough")
        #expect(RecipeTextParser.parse("Sourdough (2 loaves)\n500 g flour\n350 g water").pieces == 2)
        // 괄호 속 개수는 분량 표기 — 섹션 머리글은 그대로 인식하고 분할 개수만 읽는다
        let header = RecipeTextParser.parse(
            "르방 만들기\n르방 20g\n밀가루 50g\n물 50g\n본반죽 (빵 2개 분량)\n강력분 500g\n물 350g\n소금 10g")
        #expect(header.name == nil)
        #expect(header.pieces == 2)
        #expect(header.input.water == 350)
        #expect(header.input.levain.grams == 120)
        // 분량 표기가 없으면 nil, 공정 머리글이 없으면 노트도 nil
        let plain = RecipeTextParser.parse("캄파뉴\n강력분 500g\n물 350g\n소금 10g")
        #expect(plain.pieces == nil)
        #expect(plain.methodNote == nil)
        // 세 자리 개수는 분량이 아니다 (1~99)
        #expect(RecipeTextParser.parse("모닝빵 (120개 분량)\n강력분 500g\n물 350g").pieces == nil)
        // 개수만 적은 괄호는 재료보다 앞선 줄에서만 분량 — 재료 사이의 "계란 (2개)"는 이름이 아니다
        #expect(RecipeTextParser.parse("강력분 500g\n계란 (2개)\n물 300g").name == nil)
        #expect(RecipeTextParser.parse("강력분 500g\n물 300g\n바나나 (1개)\n호두 50g").name == nil)
        #expect(RecipeTextParser.parse("캄파뉴 (2개)\n강력분 400g\n물 300g").name == "캄파뉴")
        // 덩이·덩어리·인분도 개수다 — 괄호 속 숫자를 그램으로 읽지 않는다
        let lump = RecipeTextParser.parse("캄파뉴 (2덩이 분량)\n강력분 500g\n물 300g")
        #expect(lump.name == "캄파뉴")
        #expect(lump.pieces == 2)
        #expect(lump.input.extras.isEmpty)
        let lumps = RecipeTextParser.parse("캄파뉴 (2덩어리 분량)\n강력분 400g\n물 300g")
        #expect(lumps.name == "캄파뉴")
        #expect(lumps.pieces == 2)
        #expect(lumps.input.extras.isEmpty)
        let three = RecipeTextParser.parse("🍞 무화과 호두 캄파뉴 (3덩이 분량)\n강력분 400g\n물 300g")
        #expect(three.name == "무화과 호두 캄파뉴")
        #expect(three.pieces == 3)
        #expect(three.input.extras.isEmpty)
        let serves = RecipeTextParser.parse("무화과 캄파뉴 (2인분)\n강력분 500g\n물 300g")
        #expect(serves.name == "무화과 캄파뉴")
        #expect(serves.input.extras.isEmpty)
        let lumpHeader = RecipeTextParser.parse("강력분 500g\n물 300g\n본반죽 (2덩이 분량)\n소금 10g")
        #expect(lumpHeader.input.extras.isEmpty)
        #expect(lumpHeader.matchedLineCount == 3)
        let lumpSection = RecipeTextParser.parse(
            "르방 만들기\n르방 20g\n밀가루 50g\n물 50g\n본반죽 (빵 2덩이 분량)\n강력분 500g\n물 350g\n소금 10g")
        #expect(lumpSection.pieces == 2)
        #expect(lumpSection.input.extras.isEmpty)
        #expect(lumpSection.input.levain.grams == 120)
        // 다·네로 끝나는 빵 이름은 서술문이 아니다
        for title in ["파네토네", "초코 파네토네", "할라피뇨 체다"] {
            #expect(RecipeTextParser.parse("\(title)\n강력분 500g\n물 300g").name == title, "\(title)")
        }
        #expect(RecipeTextParser.parse("오늘 파네토네 구웠다\n강력분 500g\n물 300g").name == nil)
        #expect(RecipeTextParser.parse("맛있네\n강력분 500g\n물 300g").name == nil)
        // 판·servings도 개수다 — 괄호 속 숫자를 그램으로 읽지 않는다
        let pizza = RecipeTextParser.parse("피자 도우 (3판 분량)\n강력분 400g\n물 300g")
        #expect(pizza.name == "피자 도우")
        #expect(pizza.input.extras.isEmpty)
        #expect(pizza.matchedLineCount == 2)
        #expect(RecipeTextParser.parse("포카치아 (1판)\n강력분 500g\n물 400g").name == "포카치아")
        let focaccia = RecipeTextParser.parse("Focaccia (2 servings)\n500 g flour\n350 g water")
        #expect(focaccia.name == "Focaccia")
        #expect(focaccia.input.extras.isEmpty)
        // 가운데의 분량 괄호를 걷어내도 공백이 겹치지 않는다
        #expect(RecipeTextParser.parse("치아바타 (2개 분량) 레시피\n강력분 400g\n물 300g").name == "치아바타 레시피")
        // 이름은 재료보다 앞선 줄에서만 — 첫 줄이 서술문이어도 재료 뒤의 맺음말을 이름으로 고르지 않는다
        #expect(RecipeTextParser.parse("Baked this today!\n500 g flour\n350 g water\nEnjoy").name == nil)
        #expect(RecipeTextParser.parse("오늘도 구웠어요!\n강력분 500g\n물 350g\n맛있는 캄파뉴").name == nil)
        #expect(RecipeTextParser.parse("🍞\n강력분 500g\n물 350g\n캄파뉴").name == nil)
        #expect(RecipeTextParser.parse("캄파뉴\n강력분 500g\n물 350g\nEnjoy").name == "캄파뉴")
    }

    @Test("글머리 이모지·기호는 재료 이름에 남지 않는다")
    func bulletNames() {
        let r = RecipeTextParser.parse("▪️강력분 400g\n• 물 300g\n- 르방 80g\n🔸호두 50g\n✔️ 건무화과 60g")
        #expect(r.input.flours.map(\.name) == ["강력분"])
        #expect(r.input.water == 300)
        #expect(r.input.levain.grams == 80)
        #expect(r.input.extras.map(\.name) == ["호두", "건무화과"])
        #expect(r.input.extras.map(\.grams) == [50, 60])
    }

    @Test("% 표기가 든 제목 줄도 이름이 된다 (재료보다 앞설 때)")
    func percentTitles() {
        for title in [
            "캉파뉴 75%", "통밀 30% 캉파뉴", "Pain de campagne au levain liquide 75% hydratation",
            "75% Hydration Sourdough", "캉파뉴 (수분율 75%)",
        ] {
            let r = RecipeTextParser.parse("\(title)\n강력분 500g\n물 350g")
            #expect(r.name == title, "\(title)")
            #expect(r.matchedLineCount == 2, "\(title)")
        }
        #expect(RecipeTextParser.parse("수분율 75%\n강력분 500g\n물 350g").name == nil)
        #expect(RecipeTextParser.parse("Hydration: 75%\n강력분 500g\n물 350g").name == nil)
        #expect(RecipeTextParser.parse("강력분 500g\n물 350g\nPFF 20%").name == nil)
        #expect(RecipeTextParser.parse("PFF 20%\n강력분 500g\n물 350g").name == nil)
        // 글자 없이 %만 있는 줄은 재료보다 앞서도 이름이 아니다
        #expect(RecipeTextParser.parse("75%\n강력분 500g\n물 350g").name == nil)
        #expect(RecipeTextParser.parse("수분율\n75%\n강력분 500g\n물 350g").name == nil)
        // 발효종·재료 머리글의 수분율 표기도 통계 줄이다
        for header in [
            "스타터 (수분율 100%)", "Starter (100% hydration)", "Poolish (100% hydration)", "재료 (수분율 75%)",
            "Ingredients (75% hydration)", "르방 리퀴드 (수분율 100%)", "르방 뒤흐 (수분율 50%)",
            "Levain liquide (100% hydration)", "Levain dur (50% hydration)",
        ] {
            #expect(RecipeTextParser.parse("\(header)\n강력분 500g\n물 350g").name == nil, "\(header)")
        }
        // 베이커스 % 표의 재료 한 줄은 이름이 아니다
        #expect(RecipeTextParser.parse("강력분 100%\n물 70%\n소금 2%\n르방 20%").name == nil)
        #expect(RecipeTextParser.parse("Levain liquide 100%\n강력분 500g\n물 350g").name == nil)
        #expect(RecipeTextParser.parse("르방 리퀴드 100%\n강력분 500g\n물 350g").name == nil)
        // 온도 줄은 글자가 남아도 통계 줄이다
        let temp = RecipeTextParser.parse("강력분 500g\n물 350g\n반죽 온도 24~25℃")
        #expect(temp.name == nil)
        #expect(temp.matchedLineCount == 2)
    }

    @Test("온도 범위('24-25도씨')는 물 양으로 읽지 않는다")
    func temperatureRanges() {
        for step in ["24-25도씨", "24~25℃", "24-25°C", "24도~25도"] {
            let r = RecipeTextParser.parse("강력분 500g\n물 180g\n1. \(step) 물과 밀가루를 섞는다")
            #expect(r.input.water == 180, "\(step)")
            #expect(r.input.extras.isEmpty, "\(step)")
            #expect(r.name == nil, "\(step)")
        }
        // 띄어 쓴 대시는 범위가 아니다 — 앞의 단위 없는 양을 지우지 않는다
        #expect(RecipeTextParser.parse("강력분 500\n물 350 - 30도 물").input.water == 350)
    }

    @Test("스레드 캡션 — '1배합, 1개 분량'은 재료가 아니다")
    func threadsCaption() {
        let text = """
            스친들이 궁금해하던 반죽기 없이 만드는 손반죽 사워도우 깜빠뉴 레시피
            🟡무반죽 사워도우 깜빠뉴 레시피
            1배합, 1개 분량
            강력분 150g
            T65 75g
            호밀가루 25g
            물 180g
            소금 5g
            르방 발효종 75g
            1. 24-25도씨 물과 밀가루 전량을 섞은 후 30분 휴지한다.
            2. 소금과 발효종을 넣어 소금 입자가 만져지지 않을 만큼 섞는다.
            """
        let r = RecipeTextParser.parse(RecipeTextParser.cleanForParsing(text))
        #expect(r.name == "스친들이 궁금해하던 반죽기 없이 만드는 손반죽 사워도우 깜빠뉴 레시피")
        #expect(r.input.flours.map(\.name) == ["강력분", "T65", "호밀가루"])
        #expect(r.input.flours.map(\.grams) == [150, 75, 25])
        #expect(r.input.water == 180)
        #expect(r.input.salt == 5)
        #expect(r.input.levain.grams == 75)
        #expect(r.input.extras.isEmpty)
        #expect(r.matchedLineCount == 6)
        #expect(r.pieces == 1)
    }

    @Test("풀리시·비가 — 발효종으로 읽고 수분율을 밝히지 않으면 관례값(100%·50%)")
    func preferments() {
        for line in ["비가 300g", "biga 300g", "Biga: 300g", "비가(수분율 50%) 300g"] {
            let r = RecipeTextParser.parse("강력분 500g\n물 300g\n\(line)\n소금 10g")
            #expect(r.input.levain.grams == 300, "\(line)")
            #expect(r.input.levain.hydration == 0.5, "\(line)")
            #expect(r.input.levain.type == .dur, "\(line)")
            #expect(r.levainHydrationExplicit, "\(line)")
            #expect(r.input.levain.flourName == nil, "\(line)")
            #expect(r.input.extras.isEmpty, "\(line)")
        }
        for line in ["폴리쉬 400g", "풀리시 400g", "풀리쉬 400g", "Poolish 400g"] {
            let r = RecipeTextParser.parse("강력분 500g\n물 300g\n\(line)\n소금 10g")
            #expect(r.input.levain.grams == 400, "\(line)")
            #expect(r.input.levain.hydration == 1.0, "\(line)")
            #expect(r.levainHydrationExplicit, "\(line)")
        }
        // 밝힌 수분율이 관례값보다 우선한다
        let stated = RecipeTextParser.parse("강력분 500g\n물 300g\n비가 (수분율 60%) 300g")
        #expect(abs(stated.input.levain.hydration - 0.6) < 1e-9)
        // '비가 와서 …'는 날씨 이야기다
        let rain = RecipeTextParser.parse("강력분 500g\n물 300g\n소금 10g\n비가 와서 2시간 더 발효")
        #expect(rain.input.levain.grams == 0)
        #expect(rain.input.extras.isEmpty)
        #expect(rain.matchedLineCount == 3)
        #expect(RecipeTextParser.parse("강력분 500g\n물 300g\n오늘은 비가 300mm").input.levain.grams == 0)
        #expect(!RecipeTextParser.matchesLevain("비가 와서 2시간 더 발효"))
        #expect(!RecipeTextParser.matchesLevain("오늘은 비가 300mm"))
        // 줄 머리의 '비가 3일째 …'도 날씨 이야기다 — 뒤의 르방 수분율을 바꾸지 않는다
        let weather = RecipeTextParser.parse("비가 3일째 오네요\n강력분 500g\n물 350g\n소금 10g\n르방 100g")
        #expect(weather.input.levain.grams == 100)
        #expect(weather.input.levain.hydration == 1.0)
        #expect(!weather.levainHydrationExplicit)
        #expect(!RecipeTextParser.matchesLevain("비가 3일째 오네요"))
        #expect(RecipeTextParser.matchesLevain("비가 300"))
        #expect(RecipeTextParser.matchesLevain("비가 1,2kg"))
        // 단위는 숫자 읽기와 같은 범위·대소문자 무시
        for (line, grams) in [("비가 300", 300.0), ("비가 1키로", 1000), ("비가 1KG", 1000), ("비가 300grams", 300)] {
            let r = RecipeTextParser.parse("강력분 500g\n물 300g\n\(line)\n소금 10g")
            #expect(r.input.levain.grams == grams, "\(line)")
            #expect(r.input.levain.hydration == 0.5, "\(line)")
            #expect(r.input.extras.isEmpty, "\(line)")
        }
        // 빌드 섹션의 물/밀가루 비가 관례값보다 먼저다
        let bigaBuild = RecipeTextParser.parse(
            "Biga build\nbread flour 300g\nwater 180g\nyeast 1g\nFinal dough\nbread flour 700g\nwater 450g\nsalt 20g\nbiga 481g")
        #expect(abs(bigaBuild.input.levain.hydration - 0.6) < 1e-9)
        let poolishBuild = RecipeTextParser.parse(
            "풀리시 만들기\n강력분 300g\n물 270g\n이스트 0.3g\n본반죽\n강력분 700g\n물 350g\n소금 20g\n풀리시 570g")
        #expect(abs(poolishBuild.input.levain.hydration - 0.9) < 1e-9)
    }
}

/// 앱이 공유한 배합표 텍스트를 앱이 다시 가져온다 — 픽스처는 FicheRows.swift ficheText·웹 fiche.ts가 내는 그대로.
/// 공유 형식이 바뀌면 이 픽스처와 웹 recipeParser.test.ts의 픽스처를 함께 고칠 것
@Suite("앱 배합표(fiche technique) 왕복")
struct FicheRoundTripTests {
    /// T65 900 · 통밀 100 · 물 620 · 바시나주 30 · 소금 20 · 르방 리퀴드 200 · 우유 50 · 인스턴트 이스트 2 · 분할 2,
    /// 0.1 g 자리, 총 밀가루 기준 %
    static let ko = """
        〔캉파뉴〕 fiche technique

        T65  900.0 g  (81.8%)
        통밀  100.0 g  (9.1%)
        본반죽 물  620.0 g
        바시나주  30.0 g
        소금  20.0 g  (1.8%)
        르방 리퀴드 100%  200.0 g  (18.2%)
          ↳ 속 밀가루  100.0 g  (PFF 9.1%)
        우유  50.0 g  (4.5%)
        인스턴트 이스트  2.0 g  (0.2%)

        총 밀가루  1100.0 g
        총 물  794.0 g
        총 수분율  72.2%
        총 반죽 무게  1922.0 g
        분할 2개 — 개당 961.0 g

        — Doughmetry · narudoc.github.io/doughmetry
        """

    static let en = """
        〔Country loaf〕 fiche technique

        T65  900.0 g  (81.8%)
        Whole wheat  100.0 g  (9.1%)
        Mixing water  620.0 g
        Bassinage  30.0 g
        Salt  20.0 g  (1.8%)
        Liquid levain 100%  200.0 g  (18.2%)
          ↳ Flour in levain  100.0 g  (PFF 9.1%)
        Milk  50.0 g  (4.5%)
        Instant yeast  2.0 g  (0.2%)

        Total flour  1100.0 g
        Total water  794.0 g
        Total hydration  72.2%
        Total dough weight  1922.0 g
        Divide by 2 — each 961.0 g

        — Doughmetry · narudoc.github.io/doughmetry
        """

    /// 웹 공유 텍스트(src/lib/fiche.ts)
    static let web = """
        〔캉파뉴〕 fiche technique

        T65  900.0 g  (81.8%)
        통밀  100.0 g  (9.1%)
        물 (본반죽)  620.0 g
        바시나주  30.0 g
        소금  20.0 g  (1.8%)
        르방 (리퀴드 liquide 100%)  200.0 g  (18.2%)
          ↳ 속 밀가루  100.0 g  (PFF 9.1%)
        우유  50.0 g  (4.5%)
        이스트 (인스턴트 드라이)  2.0 g  (0.2%)

        총 밀가루  1100.0 g
        총 물  794.0 g
        총 수분율  72.2%
        총 반죽 무게  1922.0 g
        분할 2개 — 개당 961.0 g

        %는 총 밀가루 대비
        """

    @Test("한국어·영어·웹 공유 텍스트가 같은 배합으로 돌아온다", arguments: [
        (ko, "캉파뉴", "통밀", "우유"), (en, "Country loaf", "Whole wheat", "Milk"),
        (web, "캉파뉴", "통밀", "우유"),
    ])
    func roundTrip(fixture: (text: String, name: String, wholeWheat: String, milk: String)) {
        let r = RecipeTextParser.parse(RecipeTextParser.cleanForParsing(fixture.text))
        #expect(r.name == fixture.name)
        #expect(r.input.flours.map(\.name) == ["T65", fixture.wholeWheat])
        #expect(r.input.flours.map(\.grams) == [900, 100])
        #expect(r.input.water == 620)
        #expect(r.input.bassinage == 30)
        #expect(r.input.salt == 20)
        #expect(r.input.levain.grams == 200)
        #expect(r.input.levain.hydration == 1.0)
        #expect(r.input.liquids.map(\.name) == [fixture.milk])
        #expect(r.input.liquids.map(\.grams) == [50])
        #expect(r.input.liquids.map(\.waterRatio) == [0.88])
        #expect(r.input.yeast == Yeast(type: .instant, grams: 2))
        #expect(r.input.extras.isEmpty)
        #expect(r.pieces == 2)
        let s = computeStats(r.input)
        #expect(abs(s.totalFlour - 1100) < 1e-9)
        #expect(abs(s.hydrationPct - 794.0 / 1100 * 100) < 1e-9)
        #expect(abs(s.doughWeight - 1922) < 1e-9)
    }

    /// Manitoba 500 · Tipo 00 400 · 물 500 · 소금 20 · 르방 리퀴드 80% 180 · 빈 이름 액체 100(수분 90%) · 꿀 30(수분 17%) · 호두 80
    static let customKo = """
        〔피자〕 fiche technique

        Manitoba  500.0 g  (50.0%)
        Tipo 00  400.0 g  (40.0%)
        본반죽 물  500.0 g
        소금  20.0 g  (2.0%)
        르방 리퀴드 80%  180.0 g  (18.0%)
          ↳ 속 밀가루  100.0 g  (PFF 10.0%)
        액체  100.0 g  (10.0%) · 수분 90.0%
        꿀  30.0 g  (3.0%) · 수분 17.0%
        호두  80.0 g  (8.0%)

        총 밀가루  1000.0 g
        총 물  675.1 g
        총 수분율  67.5%
        총 반죽 무게  1810.0 g

        — Doughmetry · narudoc.github.io/doughmetry
        """

    static let customEn = """
        〔Pizza〕 fiche technique

        Manitoba  500.0 g  (50.0%)
        Tipo 00  400.0 g  (40.0%)
        Mixing water  500.0 g
        Salt  20.0 g  (2.0%)
        Liquid levain 80%  180.0 g  (18.0%)
          ↳ Flour in levain  100.0 g  (PFF 10.0%)
        Liquid  100.0 g  (10.0%) · water 90.0%
        Honey  30.0 g  (3.0%) · water 17.0%
        Walnuts  80.0 g  (8.0%)

        Total flour  1000.0 g
        Total water  675.1 g
        Total hydration  67.5%
        Total dough weight  1810.0 g

        — Doughmetry · narudoc.github.io/doughmetry
        """

    static let customWeb = """
        〔피자〕 fiche technique

        Manitoba  500.0 g  (50.0%)
        Tipo 00  400.0 g  (40.0%)
        물 (본반죽)  500.0 g
        소금  20.0 g  (2.0%)
        르방 (리퀴드 liquide 80%)  180.0 g  (18.0%)
          ↳ 속 밀가루  100.0 g  (PFF 10.0%)
        액체 1  100.0 g  (10.0%) · 수분 90.0%
        꿀  30.0 g  (3.0%) · 수분 17.0%
        호두  80.0 g  (8.0%)

        총 밀가루  1000.0 g
        총 물  675.1 g
        총 수분율  67.5%
        총 반죽 무게  1810.0 g

        %는 총 밀가루 대비
        """

    @Test("이름이 키워드가 아닌 밀가루·액체도 종류와 수분 함량이 그대로 돌아온다", arguments: [
        (customKo, "피자", "액체", "꿀", "호두"), (customEn, "Pizza", "Liquid", "Honey", "Walnuts"),
        (customWeb, "피자", "액체 1", "꿀", "호두"),
    ])
    func customRowsRoundTrip(
        fixture: (text: String, name: String, blank: String, honey: String, walnuts: String)
    ) {
        let r = RecipeTextParser.parse(RecipeTextParser.cleanForParsing(fixture.text))
        #expect(r.name == fixture.name)
        #expect(r.input.flours.map(\.name) == ["Manitoba", "Tipo 00"])
        #expect(r.input.flours.map(\.grams) == [500, 400])
        #expect(r.input.water == 500)
        #expect(r.input.salt == 20)
        #expect(r.input.levain.grams == 180)
        #expect(abs(r.input.levain.hydration - 0.8) < 1e-9)
        #expect(r.input.levain.type == .liquide)
        #expect(r.input.liquids.map(\.name) == [fixture.blank, fixture.honey])
        #expect(r.input.liquids.map(\.grams) == [100, 30])
        #expect(r.input.liquids.map(\.waterRatio) == [0.9, 0.17])
        #expect(r.input.extras.map(\.name) == [fixture.walnuts])
        #expect(r.input.extras.map(\.grams) == [80])
        let s = computeStats(r.input)
        #expect(abs(s.totalFlour - 1000) < 1e-9)
        #expect(abs(s.totalWater - 675.1) < 1e-9)
        #expect(abs(s.pffPct - 10) < 1e-9)
        #expect(abs(s.doughWeight - 1810) < 1e-9)
    }

    @Test("르방 행의 수분율이 50·100%가 아니어도 그대로 돌아온다")
    func levainHydrationRows() {
        for (line, h) in [
            ("르방 (리퀴드 liquide 80%)  200.0 g  (20.0%)", 0.8),
            ("르방 (뒤흐 dur 60%)  200.0 g  (20.0%)", 0.6),
            ("르방 (리퀴드 liquide 125%)  200.0 g  (20.0%)", 1.25),
            ("르방 리퀴드 80%  200.0 g  (20.0%)", 0.8),
            ("르방 뒤흐 60%  200.0 g  (20.0%)", 0.6),
            ("Liquid levain 80%  200.0 g  (20.0%)", 0.8),
            ("Stiff levain 65%  200.0 g  (20.0%)", 0.65),
            ("levain liquide à 80% 150g", 0.8),
            ("르방 뒤흐 (수분율 60%) 200g", 0.6),
            // 0.745~0.75 미만은 뒤흐로 분류되지만 75%로 찍힌다
            ("르방 (뒤흐 dur 75%)  200.0 g  (20.0%)", 0.75),
            ("르방 뒤흐 75%  200.0 g  (20.0%)", 0.75),
            ("Stiff levain 75%  200.0 g  (20.0%)", 0.75),
            // 양 뒤의 %는 베이커스 퍼센트 — 타입 낱말을 따른다
            ("르방 리퀴드 200g (40%)", 1.0),
            ("르방 뒤흐 200g (20%)", 0.5),
            // 양 앞의 %라도 타입 낱말과 어긋나면 베이커스 퍼센트다
            ("Levain liquide 40% 400g", 1.0),
            ("르방 뒤흐 100% 200g", 0.5),
            ("르방 리퀴드 20% 200g", 1.0),
        ] {
            let r = RecipeTextParser.parse("T65 1000g\n물 650g\n\(line)\n소금 20g")
            #expect(abs(r.input.levain.hydration - h) < 1e-9, "\(line)")
            #expect(r.input.levain.type == (h >= 0.75 ? .liquide : .dur), "\(line)")
            #expect(r.levainHydrationExplicit, "\(line)")
            #expect(r.input.extras.isEmpty, "\(line)")
        }
    }

    @Test("배합표의 밀가루 구간은 제목 줄 뒤, 밀가루가 아닌 첫 재료 앞까지다")
    func ficheFlourRows() {
        // 본반죽 물이 0 g이어도 그 행에서 끝난다
        let zero = RecipeTextParser.parse(
            """
            〔X〕 fiche technique

            Manitoba  500.0 g  (100.0%)
            물 (본반죽)  0.0 g
            소금  0.0 g  (0.0%)
            르방 (리퀴드 liquide 100%)  0.0 g  (0.0%)
              ↳ 속 밀가루  0.0 g  (PFF 0.0%)
            호두  50.0 g  (10.0%)
            """)
        #expect(zero.input.flours.map(\.name) == ["Manitoba"])
        #expect(zero.input.extras.map(\.name) == ["호두"])
        // 손으로 쓴 배합표에서 밀가루보다 앞선 다른 재료 — 그 뒤의 재료는 밀가루가 아니다
        let typed = RecipeTextParser.parse("Pain aux noix fiche technique\nlevain 200g\nnoix 100g\nfarine 1000g\neau 700g")
        #expect(typed.input.flours.map(\.name) == ["farine"])
        #expect(typed.input.extras.map(\.name) == ["noix"])
        // 배합표 제목이 없으면 이름으로만 분류한다 (이전과 같음)
        let plain = RecipeTextParser.parse("Manitoba 500g\n물 350g")
        #expect(plain.input.flours.isEmpty)
        #expect(plain.input.extras.map(\.name) == ["Manitoba"])
        #expect(plain.input.extras.map(\.grams) == [500])
    }

    @Test("'· 수분 N%' 표기가 붙은 줄은 이름과 무관하게 그 수분 함량의 액체다")
    func waterRatioNotes() {
        // 공유 텍스트 일부만 붙여 넣어도(제목 줄 없이) 액체로 읽는다
        let r = RecipeTextParser.parse(
            """
            강력분 500g
            물 300g
            Yogurt  100.0 g  (10.0%) · water 90.0%
            Yeast water  50.0 g  (5.0%) · water 100.0%
            우유  50.0 g  (5.0%) · 수분 90.0%
            르방 100g · 수분 100%
            """)
        #expect(r.input.water == 300)
        #expect(r.input.yeast.grams == 0)
        #expect(r.input.liquids.map(\.name) == ["Yogurt", "Yeast water", "우유"])
        #expect(r.input.liquids.map(\.grams) == [100, 50, 50])
        #expect(r.input.liquids.map(\.waterRatio) == [0.9, 1, 0.9])
        // 르방 줄은 수분 표기가 붙어도 르방이다
        #expect(r.input.levain.grams == 100)
        #expect(r.input.levain.hydration == 1.0)
        #expect(r.input.extras.isEmpty)
        // 퍼센트 괄호 없이 붙은 수분 표기는 배합표 행이 아니다 — 밀가루 그대로
        let flour = RecipeTextParser.parse("강력분 500g · 수분 70%")
        #expect(flour.input.flours.map(\.grams) == [500])
        #expect(flour.input.liquids.isEmpty)
    }

    @Test("공유 텍스트 끝의 앱 표기 줄은 재료도 레시피 이름도 아니다")
    func shareFooterIgnored() {
        let r = RecipeTextParser.parse(
            RecipeTextParser.cleanForParsing("T65 900 g\n물 620 g\n\n— Doughmetry · narudoc.github.io/doughmetry"))
        #expect(r.name?.contains("Doughmetry") != true)
        #expect(r.input.flours.map(\.grams) == [900])
        #expect(r.input.water == 620)
        #expect(r.input.liquids.isEmpty)
        #expect(r.input.extras.isEmpty)
    }

    @Test("배합표·인쇄 표의 속 밀가루·속 물 행은 재료가 아니다 (화살표가 빠져도)")
    func levainBreakdownRows() {
        for rows in [
            "↳ 속 밀가루 100 g 9.1% 발효종 밀가루 (PFF)\n↳ 속 물 100 g",
            "속 밀가루 100 g 9.1% 발효종 밀가루 (PFF)\n속 물 100 g",
            "Flour in levain 100 g (PFF 9.1%)\nWater in levain 100 g",
            // 옛 영문 라벨
            "Flour inside 100 g (PFF 9.1%)\nWater inside 100 g",
        ] {
            let r = RecipeTextParser.parse("T65 900 g\n물 (본반죽) 620 g\n르방 (리퀴드 liquide 100%) 200 g\n\(rows)")
            #expect(r.input.flours.map(\.grams) == [900], "\(rows)")
            #expect(r.input.water == 620, "\(rows)")
            #expect(r.input.levain.grams == 200, "\(rows)")
            #expect(r.matchedLineCount == 3, "\(rows)")
        }
        // 사용자 레시피의 "(PFF 9%)" 부연은 르방 줄을 지우지 않는다
        #expect(RecipeTextParser.parse("강력분 500g\n물 350g\n르방 200g (PFF 9%)").input.levain.grams == 200)
    }
}
