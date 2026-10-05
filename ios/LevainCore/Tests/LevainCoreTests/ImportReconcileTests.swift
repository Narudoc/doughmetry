import Testing
@testable import LevainCore

/// AI 가져오기 초안 보정·교차 검증 — 규칙 결과는 고정 레시피의 RecipeTextParser.parse, 초안은 그것을 손본 것
@Suite("AI 초안 보정·교차 검증")
struct ImportReconcileTests {
    /// F_total 1000 · W_total 720 (72%) · PFF 10% · 총 1740 g
    static let base = "강력분 900g\n물 620g\n르방 200g\n소금 20g"

    func rules(_ text: String = base) -> ParsedRecipeText { RecipeTextParser.parse(text) }

    /// 르방을 2k 늘리고 밀가루·물을 k씩 줄인다 — 총 밀가루·총 물·총 무게는 그대로, PFF만 k/10 %p 오른다
    func shiftLevain(_ input: DoughInput, by k: Double) -> DoughInput {
        var d = input
        d.levain.grams += 2 * k
        d.flours[0].grams -= k
        d.water -= k
        return d
    }

    @Test("규칙 결과와 같은 초안은 그대로 통과한다")
    func faithfulDraft() {
        let r = rules()
        #expect(r.matchedLineCount == 4)
        #expect(reconcileAIDraft(r.input, rules: r) == .success(r.input))
    }

    @Test("밀가루·르방·물이 없는 초안은 버린다")
    func emptyDraft() {
        let empty = DoughInput(
            flours: [], water: 0, salt: 10, levain: Levain(type: .liquide, hydration: 1, grams: 0))
        #expect(reconcileAIDraft(empty, rules: rules()) == .failure(.empty))
    }

    @Test("르방이 밀가루·액체·기타로 분류된 초안은 버린다")
    func levainMisfiled() {
        let r = rules()
        var asFlour = r.input
        asFlour.levain.grams = 0
        asFlour.flours.append(Flour(name: "르방", grams: 200))
        #expect(reconcileAIDraft(asFlour, rules: r) == .failure(.levainMisfiled))
        var asLiquid = r.input
        asLiquid.liquids = [Liquid(name: "르방 리퀴드", grams: 10, waterRatio: 0.5)]
        #expect(reconcileAIDraft(asLiquid, rules: r) == .failure(.levainMisfiled))
        var asExtra = r.input
        asExtra.extras = [Extra(name: "starter", grams: 10)]
        #expect(reconcileAIDraft(asExtra, rules: r) == .failure(.levainMisfiled))
    }

    @Test("규칙 결과가 정한 르방 수분율이 모델 추정보다 우선한다")
    func levainHydrationFromRules() {
        let explicit = rules("강력분 900g\n물 620g\n르방 뒤흐 200g\n소금 20g")
        #expect(explicit.levainHydrationExplicit)
        var draft = explicit.input
        draft.levain.hydration = 1.0
        draft.levain.type = .liquide
        let fixed = try? reconcileAIDraft(draft, rules: explicit).get()
        #expect(fixed?.levain.hydration == 0.5)
        #expect(fixed?.levain.type == .dur)

        // 르방 빌드 섹션의 물/밀가루 비로 추정한 수분율(명시는 아님)도 규칙 쪽을 쓴다
        let build = rules("르방 만들기\n스타터 20g\n밀가루 100g\n물 50g\n본반죽\n강력분 900g\n물 620g\n소금 20g")
        #expect(!build.levainHydrationExplicit)
        #expect(build.input.levain.grams == 170)
        #expect(build.input.levain.hydration == 0.5)
        var buildDraft = build.input
        buildDraft.levain.hydration = 1.0
        buildDraft.levain.type = .liquide
        #expect((try? reconcileAIDraft(buildDraft, rules: build).get())?.levain.hydration == 0.5)

        // 규칙 결과가 기본값(100%, 명시 없음)이면 모델 값을 둔다
        let plain = rules()
        var guessed = plain.input
        guessed.levain.hydration = 0.9
        #expect((try? reconcileAIDraft(guessed, rules: plain).get())?.levain.hydration == 0.9)
    }

    @Test("르방이 없는 초안은 수분율을 100%·리퀴드로 되돌린다")
    func noLevainResetsHydration() {
        let r = rules("강력분 500g\n물 350g\n소금 10g\n이스트 5g")
        var draft = r.input
        draft.levain = Levain(type: .dur, hydration: 0.5, grams: 0)
        let fixed = try? reconcileAIDraft(draft, rules: r).get()
        #expect(fixed?.levain.hydration == 1.0)
        #expect(fixed?.levain.type == .liquide)
    }

    @Test("우유·계란은 모델 수분율 대신 프리셋")
    func liquidPresets() {
        let r = rules("강력분 500g\n물 250g\n우유 100g\n계란 50g\n소금 10g")
        #expect(r.input.liquids.map(\.waterRatio) == [0.88, 0.76])
        var draft = r.input
        draft.liquids[0].waterRatio = 0.5
        draft.liquids[1].waterRatio = 0.5
        let fixed = try? reconcileAIDraft(draft, rules: r).get()
        #expect(fixed?.liquids.map(\.waterRatio) == [0.88, 0.76])
        #expect(RecipeTextParser.liquidPreset(forName: "Whole Milk") == .milk)
        #expect(RecipeTextParser.liquidPreset(forName: "달걀") == .egg)
        #expect(RecipeTextParser.liquidPreset(forName: "맥주") == nil)
    }

    @Test("규칙 결과의 인스턴트 이스트가 이긴다")
    func instantYeastFromRules() {
        let r = rules("강력분 500g\n물 350g\n소금 10g\n인스턴트 이스트 5g")
        #expect(r.input.yeast.type == .instant)
        var draft = r.input
        draft.yeast.type = .fresh
        #expect((try? reconcileAIDraft(draft, rules: r).get())?.yeast.type == .instant)
    }

    @Test("총 무게 허용치 — max(5 g, 1%)")
    func weightThreshold() {
        let r = rules()  // 1740 g → 17.4 g
        var within = r.input
        within.extras = [Extra(name: "호두", grams: 17)]
        #expect((try? reconcileAIDraft(within, rules: r).get()) == within)
        var beyond = r.input
        beyond.extras = [Extra(name: "호두", grams: 18)]
        #expect(reconcileAIDraft(beyond, rules: r) == .failure(.weight))

        let small = rules("강력분 200g\n물 140g\n르방 40g\n소금 4g")  // 384 g → 1%는 3.84 g, 5 g
        var smallWithin = small.input
        smallWithin.extras = [Extra(name: "호두", grams: 5)]
        #expect((try? reconcileAIDraft(smallWithin, rules: small).get()) == smallWithin)
        var smallBeyond = small.input
        smallBeyond.extras = [Extra(name: "호두", grams: 6)]
        #expect(reconcileAIDraft(smallBeyond, rules: small) == .failure(.weight))
    }

    @Test("총 수분율 허용치 — 2%p")
    func hydrationThreshold() {
        let r = rules()
        // 밀가루 → 물로 옮긴다 — 총 무게는 그대로
        var within = r.input
        within.flours[0].grams -= 10
        within.water += 10  // 730 / 990 = 73.74%
        #expect((try? reconcileAIDraft(within, rules: r).get()) == within)
        var beyond = r.input
        beyond.flours[0].grams -= 12
        beyond.water += 12  // 732 / 988 = 74.09%
        #expect(reconcileAIDraft(beyond, rules: r) == .failure(.hydration))
    }

    @Test("PFF 허용치 — 2%p")
    func pffThreshold() {
        let r = rules()
        // PFF 11.9% — PFF는 통과하고 르방 무게(+38 g)에서 걸린다
        #expect(reconcileAIDraft(shiftLevain(r.input, by: 19), rules: r) == .failure(.levainMass))
        // PFF 12.1%
        #expect(reconcileAIDraft(shiftLevain(r.input, by: 21), rules: r) == .failure(.pff))
    }

    @Test("르방 무게 허용치 — max(10 g, 10%)")
    func levainMassThreshold() {
        let r = rules()  // 200 g → 20 g
        let within = shiftLevain(r.input, by: 10)
        #expect((try? reconcileAIDraft(within, rules: r).get()) == within)
        #expect(reconcileAIDraft(shiftLevain(r.input, by: 11), rules: r) == .failure(.levainMass))

        let small = rules("강력분 900g\n물 620g\n르방 50g\n소금 20g")  // 50 g → 10%는 5 g, 10 g
        let smallWithin = shiftLevain(small.input, by: 5)
        #expect((try? reconcileAIDraft(smallWithin, rules: small).get()) == smallWithin)
        #expect(reconcileAIDraft(shiftLevain(small.input, by: 6), rules: small) == .failure(.levainMass))
    }

    @Test("기타 재료 가짓수가 규칙 결과보다 적으면 버린다")
    func extrasMissing() {
        let r = rules(Self.base + "\n호두 50g\n건포도 50g")
        #expect(r.input.extras.count == 2)
        var merged = r.input
        merged.extras = [Extra(name: "견과·건과일", grams: 100)]
        #expect(reconcileAIDraft(merged, rules: r) == .failure(.extrasMissing))
    }

    @Test("규칙 결과에 있는 이스트를 빠뜨리면 버린다 — 무게 허용치에 묻히는 소량")
    func yeastMissing() {
        let r = rules(Self.base + "\n이스트 2g")
        var draft = r.input
        draft.yeast.grams = 0
        #expect(reconcileAIDraft(draft, rules: r) == .failure(.yeastMissing))
    }

    /// 옛 스키마(르방 무게만 묻는 levainGrams)에서 온디바이스 모델이 내던 초안 — '르방 리퀴드'·'starter' 줄을
    /// 통째로 빠뜨리고 나머지는 맞게 읽는다. 빠진 르방은 무게 검증에서 걸려야 한다
    @Test("르방 줄을 빠뜨린 초안은 무게에서 버리고, 르방을 읽은 초안은 통과한다")
    func droppedLevainLine() {
        let r = rules("통밀 캉파뉴\nT65 밀가루 400g\n통밀가루 100g\n물 350g\n르방 리퀴드 100g\n소금 10g")
        #expect(r.matchedLineCount == 5)
        #expect(r.input.levain.grams == 100)
        var dropped = r.input
        dropped.levain.grams = 0
        #expect(reconcileAIDraft(dropped, rules: r) == .failure(.weight))
        // 모델이 밀가루 이름을 줄여 적어도("T65 밀가루" → "밀가루") 수치가 같으면 받고, 이름은 규칙 파서의 긴 이름으로 되돌린다
        var read = r.input
        read.flours[0].name = "밀가루"
        #expect((try? reconcileAIDraft(read, rules: r).get())?.flours.map(\.name) == ["T65 밀가루", "통밀가루"])

        let stiff = rules("800g bread flour\n150 starter (stiff)\n600 water\n5 instant yeast\n18 salt")
        #expect(stiff.input.levain.grams == 150)
        var stiffDropped = stiff.input
        stiffDropped.levain.grams = 0
        #expect(reconcileAIDraft(stiffDropped, rules: stiff) == .failure(.weight))
    }

    @Test("규칙 결과의 재료 줄이 3개 미만이면 교차 검증하지 않는다")
    func fewRuleLinesSkipCrossCheck() {
        let r = rules("강력분 500g\n물 350g")
        #expect(r.matchedLineCount == 2)
        var draft = r.input
        draft.water = 100
        draft.extras = []
        #expect((try? reconcileAIDraft(draft, rules: r).get())?.water == 100)
    }
}
