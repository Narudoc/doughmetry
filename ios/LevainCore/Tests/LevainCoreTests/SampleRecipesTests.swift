import Testing
@testable import LevainCore

@Suite("예시 레시피")
struct SampleRecipesTests {
    private let samples = SampleRecipes.make(now: "2026-01-01T00:00:00.000Z", localize: { $0 })

    @Test("id는 고정이다 — 두 기기에서 따로 넣어도 병합 뒤 한 벌")
    func fixedIds() {
        #expect(samples.map(\.id) == ["sample-campagne", "sample-complet", "sample-baguette", "sample-brioche"])
        let later = SampleRecipes.make(now: "2026-06-01T12:00:00.000Z", localize: { $0 })
        #expect(later.map(\.id) == samples.map(\.id))
        #expect(Set(samples.map(\.id)).count == samples.count)
    }

    @Test("JSON 내보내기 → 가져오기 왕복이 그대로다")
    func codecRoundTrip() throws {
        let json = try RecipeCodec.exportJSON(samples)
        let back = try RecipeCodec.importJSON(json).get()
        #expect(back == samples)
    }

    @Test("수분율·소금·PFF가 그럴듯한 범위")
    func plausibleStats() {
        for r in samples {
            let s = computeStats(r.doughInput)
            #expect((50...85).contains(s.hydrationPct), "\(r.id) 수분율 \(s.hydrationPct)")
            #expect((1.5...2.5).contains(s.saltPct), "\(r.id) 소금 \(s.saltPct)")
            #expect((5...25).contains(s.pffPct), "\(r.id) PFF \(s.pffPct)")
        }
    }

    @Test("캉파뉴 예시는 계산기 기본 배합과 같다 (T65 900 · 물 620 · 소금 20 · 리퀴드 200)")
    func campagneMatchesDefault() throws {
        let input = try #require(samples.first).doughInput
        #expect(input.flours.map(\.name) == ["T65"])
        #expect(input.flours.map(\.grams) == [900])
        #expect(input.water == 620)
        #expect(input.salt == 20)
        #expect(input.levain.type == .liquide)
        #expect(input.levain.hydration == 1)
        #expect(input.levain.grams == 200)
        #expect(input.bassinage == 0 && input.liquids.isEmpty && input.yeast.grams == 0 && input.extras.isEmpty)
    }

    @Test("다시 읽어도(정규 순서) 정의한 순서 그대로다")
    func orderSurvivesReload() throws {
        let doc = LibrarySync.decode(try LibrarySync.encode(LibraryDocument(recipes: samples)))
        #expect(doc.recipes.map(\.id) == samples.map(\.id))
    }
}
