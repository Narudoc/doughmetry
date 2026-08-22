import Foundation
import Testing
@testable import LevainCore

/// storage.ts의 검증·마이그레이션·왕복 테스트 이식 (핵심 케이스)

@Suite("레시피 JSON 코덱")
struct CodecTests {
    @Test("v1 레시피는 v2로 마이그레이션된다 (bassinage 0, liquids [], yeast 0)")
    func v1Migration() throws {
        let json = """
            {"schemaVersion":1,"name":"옛 캉파뉴","flours":[{"id":"f1","name":"T65","grams":900}],
             "water":620,"salt":20,"levain":{"type":"liquide","hydration":1,"grams":200}}
            """
        let recipes = try RecipeCodec.importJSON(json).get()
        let r = try #require(recipes.first)
        #expect(r.schemaVersion == 2)
        #expect(r.bassinage == 0)
        #expect(r.liquids.isEmpty)
        #expect(r.yeast == Yeast(type: .fresh, grams: 0))
        #expect(r.name == "옛 캉파뉴")
    }

    @Test("내보내기 → 가져오기 왕복이 레시피를 보존한다")
    func roundTrip() throws {
        let input = DoughInput(
            flours: [Flour(id: "a", name: "T65", grams: 700), Flour(id: "b", name: "호밀", grams: 200)],
            water: 620, bassinage: 50, salt: 20,
            levain: Levain(type: .liquide, hydration: 1, grams: 200, flourName: "T80"),
            liquids: [Liquid(id: "l1", name: "우유", grams: 100, waterRatio: 0.88)],
            yeast: Yeast(type: .instant, grams: 4),
            extras: [Extra(id: "x1", name: "호두", grams: 80)])
        let recipe = Recipe(
            id: "r1", name: "테스트", note: "노트", tags: ["빵"],
            createdAt: "2026-08-21T00:00:00.000Z", updatedAt: "2026-08-21T00:00:00.000Z",
            input: input, pieces: 2)
        let json = try RecipeCodec.exportJSON([recipe])
        let back = try RecipeCodec.importJSON(json).get()
        #expect(back == [recipe])
        // 계산 결과도 동일해야 한다
        #expect(computeStats(back[0].doughInput) == computeStats(input))
    }

    @Test("잘못된 waterRatio는 거부된다 — 구조화된 오류 종류로")
    func badWaterRatio() {
        let json = """
            {"schemaVersion":2,"name":"x","flours":[],"water":0,"salt":0,
             "levain":{"hydration":1,"grams":0},"liquids":[{"grams":10,"waterRatio":1.5}]}
            """
        guard case .failure(let error) = RecipeCodec.importJSON(json) else {
            Issue.record("waterRatio 1.5는 거부되어야 한다")
            return
        }
        #expect(
            error.kind
                == .recipeAt(index: 1, error: CodecError(.waterRatioInvalid(index: 0))))
        #expect(error.message == "1번째 레시피: liquids[0].waterRatio가 0~1 사이의 소수가 아닙니다 (예: 0.88)")
    }

    @Test("웹 내보내기 형식({app, recipes:[…]})을 읽는다")
    func webEnvelope() throws {
        let json = """
            {"app":"levain-calc","schemaVersion":2,"exportedAt":"2026-08-21T00:00:00Z",
             "recipes":[{"schemaVersion":2,"name":"캉파뉴","flours":[{"grams":900}],
             "water":620,"salt":20,"levain":{"type":"liquide","hydration":1,"grams":200}}]}
            """
        let recipes = try RecipeCodec.importJSON(json).get()
        #expect(recipes.count == 1)
        #expect(near(computeStats(recipes[0].doughInput).hydrationPct, 72))
    }
}
