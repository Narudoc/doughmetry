import Foundation
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

    @Test("updatedAt은 createdAt과 같다 — epoch로 만들면 epoch보다 새 시각이 없다")
    func updatedAtIsCreatedAt() throws {
        #expect(samples.allSatisfy { $0.updatedAt == $0.createdAt })
        let fresh = SampleRecipes.make(now: SampleRecipes.epoch, localize: { $0 })
        #expect(fresh.allSatisfy { $0.updatedAt == $0.createdAt })
        #expect(!fresh.contains { LibrarySync.isNewer($0.updatedAt, than: SampleRecipes.epoch) })
        // 1초씩 앞당긴 createdAt — 정의한 순서가 유지된다
        let doc = LibrarySync.decode(try LibrarySync.encode(LibraryDocument(recipes: fresh)))
        #expect(doc.recipes.map(\.id) == fresh.map(\.id))
    }

    /// 앱의 "예시 레시피 추가" — RecipesView.addSamples와 같은 저장 (epoch, touch: false, 이미 있는 id는 건너뜀)
    private func addSamples(to doc: LibraryDocument, now: Date) -> LibraryDocument {
        var doc = doc
        for sample in SampleRecipes.make(now: SampleRecipes.epoch, localize: { $0 }).reversed()
        where !doc.recipes.contains(where: { $0.id == sample.id }) {
            guard
                let saved = LibrarySync.savedRecipe(
                    sample, replacing: nil, tombstone: doc.deleted.first { $0.id == sample.id },
                    touch: false, now: now)
            else { continue }
            doc.deleted.removeAll { $0.id == sample.id }
            doc.recipes.insert(saved, at: 0)
        }
        return doc
    }

    @Test("다른 기기에서 나중에 넣은 예시가 이 기기의 예시 편집·삭제를 되돌리지 않는다 (병합 순서 무관)")
    func laterAddDoesNotRevertEdits() throws {
        let t0 = try #require(parseISO("2026-10-01T10:00:00Z"))
        // 기기 A: 예시를 넣고 캉파뉴를 고치고 바게트를 지웠다
        var a = addSamples(to: LibraryDocument(), now: t0)
        let idx = try #require(a.recipes.firstIndex(where: { $0.id == "sample-campagne" }))
        var edited = a.recipes[idx]
        edited.name = "내 캉파뉴"
        edited.water = 700
        a.recipes[idx] = try #require(
            LibrarySync.savedRecipe(
                edited, replacing: a.recipes[idx], tombstone: nil, now: t0.addingTimeInterval(60)))
        let baguette = try #require(a.recipes.first(where: { $0.id == "sample-baguette" }))
        a.recipes.removeAll { $0.id == "sample-baguette" }
        a.deleted.append(
            Tombstone(
                id: "sample-baguette",
                deletedAt: LibrarySync.tombstoneTime(for: baguette.updatedAt, now: t0.addingTimeInterval(120))))

        // 기기 B: 빈 라이브러리(새로 설치해 아직 내려받기 전)에서 한 시간 뒤 예시를 넣었다
        let b = addSamples(to: LibraryDocument(), now: t0.addingTimeInterval(3600))

        for m in [LibrarySync.merge(local: a, remote: b), LibrarySync.merge(local: b, remote: a)] {
            let campagne = try #require(m.recipes.first(where: { $0.id == "sample-campagne" }))
            #expect(campagne.water == 700)
            #expect(campagne.name == "내 캉파뉴")
            #expect(!m.recipes.contains { $0.id == "sample-baguette" })
            #expect(m.deleted.map(\.id) == ["sample-baguette"])
            #expect(m.recipes.map(\.id).sorted() == ["sample-brioche", "sample-campagne", "sample-complet"])
        }
    }

    @Test("이 기기에서 지운 예시를 다시 넣으면 묘비 뒤로 밀려 되살아난다")
    func reAddAfterLocalDeleteRevives() throws {
        let t0 = try #require(parseISO("2026-10-01T10:00:00Z"))
        var a = addSamples(to: LibraryDocument(), now: t0)
        let baguette = try #require(a.recipes.first(where: { $0.id == "sample-baguette" }))
        a.recipes.removeAll { $0.id == "sample-baguette" }
        let tombstone = Tombstone(
            id: "sample-baguette",
            deletedAt: LibrarySync.tombstoneTime(for: baguette.updatedAt, now: t0.addingTimeInterval(60)))
        a.deleted.append(tombstone)
        // iCloud에는 삭제 직후의 문서가 남아 있다 — 같은 묘비
        let remote = a

        let readded = addSamples(to: a, now: t0.addingTimeInterval(120))
        let revived = try #require(readded.recipes.first(where: { $0.id == "sample-baguette" }))
        #expect(LibrarySync.isNewer(revived.updatedAt, than: tombstone.deletedAt))
        #expect(readded.deleted.isEmpty)
        for m in [
            LibrarySync.merge(local: readded, remote: remote), LibrarySync.merge(local: remote, remote: readded),
        ] {
            #expect(m.recipes.contains { $0.id == "sample-baguette" })
            #expect(m.deleted.isEmpty)
            #expect(m.recipes.count == 4)
        }
    }
}
