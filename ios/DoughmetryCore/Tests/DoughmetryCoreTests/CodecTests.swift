import Foundation
import Testing
@testable import DoughmetryCore

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

    @Test("salvageRecipes — 불량 항목이 있어도 유효한 레시피는 살린다 (저장소 로드용)")
    func salvage() {
        let json = """
            [{"schemaVersion":2,"name":"좋은것","flours":[{"grams":900}],"water":620,"salt":20,
              "levain":{"type":"liquide","hydration":1,"grams":200}},
             {"schemaVersion":2,"name":"불량","flours":[],"water":-5,"salt":0,
              "levain":{"hydration":1,"grams":0}}]
            """
        // 엄격한 importJSON은 전체 실패
        #expect((try? RecipeCodec.importJSON(json).get()) == nil)
        // salvage는 유효한 1건을 살린다
        let salvaged = RecipeCodec.salvageRecipes(json)
        #expect(salvaged.count == 1)
        #expect(salvaged[0].name == "좋은것")
    }

    @Test("fmtDate는 사용자 달력과 무관하게 그레고리력으로 표시된다")
    func dateFormatting() {
        #expect(fmtDate(iso: "2026-08-22T10:30:00.000Z").hasPrefix("2026."))
        #expect(fmtDate(iso: "2026-08-22T00:00:00Z").hasPrefix("2026."))
    }

    @Test("fmtDate는 그 달에 없는 날·분 없는 오프셋도 정렬과 같은 시각으로 표시한다 (iOS 17·18.2에서 비지 않게)")
    func dateFormattingLenientForms() {
        #expect(fmtDate(iso: "2026-02-30T10:00:00Z") == fmtDate(iso: "2026-03-02T10:00:00Z"))
        #expect(fmtDate(iso: "2026-09-03T10:00:00+09") == fmtDate(iso: "2026-09-03T01:00:00Z"))
        #expect(!fmtDate(iso: "2026-09-03T10:00:00+9").isEmpty)
    }

    @Test("이 버전보다 새 레시피 schemaVersion은 거부한다 (새 버전 앱의 형식)")
    func rejectsNewerSchemaVersion() {
        let json = """
            {"schemaVersion":\(Recipe.currentSchemaVersion + 1),"name":"새 형식","flours":[{"grams":900}],
             "water":620,"salt":20,"levain":{"type":"liquide","hydration":1,"grams":200}}
            """
        #expect((try? RecipeCodec.importJSON(json).get()) == nil)
        #expect(RecipeCodec.salvageRecipes(json).isEmpty)
    }

    /// storage.test.ts의 같은 벡터 — 웹 validateRecipe와 같은 판정이어야 한다 (한쪽을 바꾸면 함께)
    @Test("JSON true/false는 숫자로 받지 않고 schemaVersion은 정수만 받는다 (웹과 같은 판정)")
    func booleansAndFractionalVersionLikeWeb() throws {
        func validate(_ json: String) throws -> RecipeCodec.ValidationResult {
            RecipeCodec.validate(try JSONSerialization.jsonObject(with: Data(json.utf8)))
        }
        let rejected: [(json: String, kind: CodecError.Kind)] = [
            (
                #"{"schemaVersion":2.5,"name":"x","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"type":"liquide","hydration":1,"grams":200}}"#,
                .unsupportedSchemaVersion
            ),
            (
                #"{"schemaVersion":true,"name":"x","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"type":"liquide","hydration":1,"grams":200}}"#,
                .unsupportedSchemaVersion
            ),
            (
                #"{"schemaVersion":2,"name":"x","flours":[{"grams":900}],"water":620,"salt":true,"levain":{"type":"liquide","hydration":1,"grams":200}}"#,
                .saltInvalid
            ),
            (
                #"{"schemaVersion":2,"name":"x","flours":[{"grams":900}],"extras":[{"grams":true}],"water":620,"salt":20,"levain":{"type":"liquide","hydration":1,"grams":200}}"#,
                .rowGramsInvalid(field: "extras", index: 0)
            ),
            (
                #"{"schemaVersion":2,"name":"x","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"type":"liquide","hydration":true,"grams":200}}"#,
                .levainHydrationInvalid
            ),
        ]
        for (json, kind) in rejected {
            guard case .bad(let error) = try validate(json) else {
                Issue.record("거부되어야 한다: \(json)")
                continue
            }
            #expect(error.kind == kind, "\(json)")
        }

        // 1.0은 정수 1이다 (웹 JSON.parse도 1로 읽는다)
        let v1 = try validate(
            #"{"schemaVersion":1.0,"name":"x","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"type":"liquide","hydration":1,"grams":200}}"#
        )
        guard case .ok(let migrated) = v1 else {
            Issue.record("schemaVersion 1.0은 통과해야 한다")
            return
        }
        #expect(migrated.schemaVersion == 2)
        // 선택 숫자 필드의 true는 거부하지 않고 없는 값으로 둔다
        let withPieces = try validate(
            #"{"schemaVersion":2,"name":"x","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"type":"liquide","hydration":1,"grams":200},"pieces":true}"#
        )
        guard case .ok(let r) = withPieces else {
            Issue.record("pieces: true는 통과해야 한다")
            return
        }
        #expect(r.pieces == nil)
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
