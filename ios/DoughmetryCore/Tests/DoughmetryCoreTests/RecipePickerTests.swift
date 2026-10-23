import Foundation
import Testing
@testable import DoughmetryCore

/// 레시피 불러오기 목록 — 웹 recipePicker.test.ts와 같은 벡터 (한쪽을 바꾸면 함께)

private func recipe(
    _ id: String, _ name: String, tags: [String] = [], createdAt: String, updatedAt: String
) -> Recipe {
    Recipe(
        id: id, name: name, tags: tags.isEmpty ? nil : tags, createdAt: createdAt, updatedAt: updatedAt,
        input: DoughInput(
            flours: [Flour(id: "\(id)-f", name: "T65", grams: 900)], water: 620, salt: 20,
            levain: Levain(type: .liquide, hydration: 1, grams: 200)))
}

private let r1 = recipe(
    "r1", "캉파뉴", tags: ["T65"], createdAt: "2026-09-01T00:00:00.000Z", updatedAt: "2026-10-01T00:00:00.000Z")
private let r2 = recipe(
    "r2", "바게트", createdAt: "2026-09-02T00:00:00.000Z", updatedAt: "2026-10-05T00:00:00.000Z")
private let r3 = recipe(
    "r3", "Pain de campagne", tags: ["french"], createdAt: "2026-09-03T00:00:00.000Z",
    updatedAt: "2026-09-20T00:00:00.000Z")
private let r4 = recipe(
    "r4", "캉파뉴 10", createdAt: "2026-09-04T00:00:00.000Z", updatedAt: "2026-10-03T00:00:00.000Z")
private let r5 = recipe(
    "r5", "캉파뉴 2", tags: ["호밀"], createdAt: "2026-09-05T00:00:00.000Z", updatedAt: "2026-10-03T00:00:00.000Z")
// 밀리초 없는 시각 (iOS가 예전에 쓰던 형식)
private let r6 = recipe(
    "r6", "brioche", createdAt: "2026-09-06T00:00:00.000Z", updatedAt: "2026-09-10T00:00:00Z")
private let r7 = recipe(
    "r7", "Écrasé", createdAt: "2026-09-07T00:00:00.000Z", updatedAt: "2026-09-15T00:00:00.000Z")
private let all = [r1, r2, r3, r4, r5, r6, r7]

private func ids(_ s: RecipePicker.Section) -> [String] { s.recipes.map(\.id) }

@Suite("레시피 불러오기 목록 (웹 recipePicker.ts와 같은 벡터)")
struct RecipePickerTests {
    @Test("5개보다 많으면 최근 5개 + 전체 이름순 — 한글 다음 로마자, 숫자는 값으로, 대소문자·악센트 무시")
    func recentAndAll() {
        let s = RecipePicker.sections(all, query: "")
        #expect(s.map(\.kind) == [.recent, .all])
        // r4·r5는 updatedAt이 같다 → createdAt이 늦은 r5가 먼저
        #expect(ids(s[0]) == ["r2", "r5", "r4", "r1", "r3"])
        #expect(ids(s[1]) == ["r2", "r1", "r5", "r4", "r6", "r7", "r3"])
    }

    @Test("5개 이하면 저장된 레시피 하나 — 최근 수정순")
    func savedWhenFew() {
        let s = RecipePicker.sections([r1, r2, r3], query: "")
        #expect(s.map(\.kind) == [.saved])
        #expect(ids(s[0]) == ["r2", "r1", "r3"])
        #expect(RecipePicker.sections(Array(all.prefix(RecipePicker.recentCount)), query: "").map(\.kind) == [.saved])
        #expect(RecipePicker.sections([], query: "") == [RecipePicker.Section(kind: .saved, recipes: [])])
    }

    @Test(
        "검색은 이름·태그에서 — 대소문자·악센트 무시, 결과는 이름순",
        arguments: [
            ("캉파", ["r1", "r5", "r4"]),
            ("ecrase", ["r7"]),
            ("PAIN", ["r3"]),
            ("호밀", ["r5"]),
            ("t65", ["r1"]),
            ("없는이름", []),
        ])
    func search(query: String, expected: [String]) {
        let s = RecipePicker.sections(all, query: query)
        #expect(s.map(\.kind) == [.results])
        #expect(ids(s[0]) == expected)
    }

    @Test("공백뿐인 검색어는 빈 검색어와 같다")
    func blankQuery() {
        #expect(RecipePicker.sections(all, query: "  ") == RecipePicker.sections(all, query: ""))
        #expect(RecipePicker.sections(all, query: " 캉파 ") == RecipePicker.sections(all, query: "캉파"))
    }

    @Test("읽지 못하는 updatedAt은 최근 수정순 맨 뒤")
    func unparseableLast() {
        let bad = recipe(
            "r0", "Zzz", createdAt: "2026-10-30T00:00:00.000Z", updatedAt: "garbage")
        let order = RecipePicker.byRecency(all + [bad]).map(\.id)
        #expect(order.last == "r0")
        #expect(RecipePicker.sections([bad, r6, r3], query: "").first.map(ids) == ["r3", "r6", "r0"])
        #expect(RecipePicker.sections(all + [bad], query: "").first.map(ids) == ["r2", "r5", "r4", "r1", "r3"])
    }

    @Test("시각이 모두 같으면 id 오름차순, 같은 이름은 최근 수정순")
    func tieBreaks() {
        let t = "2026-10-01T00:00:00.000Z"
        let a = recipe("b", "같은 이름", createdAt: t, updatedAt: t)
        let b = recipe("a", "같은 이름", createdAt: t, updatedAt: t)
        let c = recipe("c", "같은 이름", createdAt: t, updatedAt: "2026-10-02T00:00:00.000Z")
        #expect(RecipePicker.byRecency([a, b, c]).map(\.id) == ["c", "a", "b"])
        #expect(RecipePicker.byName([a, b, c]).map(\.id) == ["c", "a", "b"])
        #expect(RecipePicker.sections([a, b, c], query: "같은").first.map(ids) == ["c", "a", "b"])
        // updatedAt이 같으면 나중에 만든 쪽이 앞 (r4·r5)
        #expect(RecipePicker.sections([r4, r5], query: "").first.map(ids) == ["r5", "r4"])
    }
}
