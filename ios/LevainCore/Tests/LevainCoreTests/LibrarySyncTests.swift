import Foundation
import Testing
@testable import LevainCore

/// 기기 간 병합 규칙 — updatedAt 최신 우선, 묘비, 편집-vs-삭제, 결정성

private func recipe(_ id: String, name: String, updatedAt: String) -> Recipe {
    Recipe(
        id: id, name: name, createdAt: "2026-09-01T00:00:00Z", updatedAt: updatedAt,
        input: DoughInput(
            flours: [Flour(id: "\(id)-f", name: "T65", grams: 900)], water: 620, salt: 20,
            levain: Levain(type: .liquide, hydration: 1, grams: 200)))
}

private func log(_ id: String, recipeId: String, note: String, updatedAt: String) -> BakeLog {
    BakeLog(
        id: id, recipeId: recipeId, bakedAt: "2026-09-02T08:00:00Z", rating: 4, note: note,
        createdAt: "2026-09-02T08:00:00Z", updatedAt: updatedAt)
}

@Suite("라이브러리 병합 (iCloud 동기화)")
struct LibrarySyncTests {
    @Test("양쪽에만 있는 항목은 합쳐지고, 같은 id는 updatedAt 최신이 이긴다")
    func unionAndNewerWins() {
        let local = LibraryDocument(recipes: [
            recipe("a", name: "로컬 A", updatedAt: "2026-09-03T10:00:00Z"),
            recipe("b", name: "B", updatedAt: "2026-09-01T00:00:00Z"),
        ])
        let remote = LibraryDocument(recipes: [
            recipe("a", name: "원격 A (더 새것)", updatedAt: "2026-09-03T12:00:00.500Z"),
            recipe("c", name: "C", updatedAt: "2026-09-01T00:00:00Z"),
        ])
        let m = LibrarySync.merge(local: local, remote: remote)
        #expect(m.recipes.map(\.id) == ["a", "b", "c"])
        #expect(m.recipes[0].name == "원격 A (더 새것)")
        // 결정성: 순서를 바꿔도 같은 집합·같은 승자
        let m2 = LibrarySync.merge(local: remote, remote: local)
        #expect(Set(m2.recipes.map(\.id)) == Set(m.recipes.map(\.id)))
        #expect(m2.recipes.first { $0.id == "a" }?.name == "원격 A (더 새것)")
    }

    @Test("동률이면 양쪽 기기가 같은 답을 낸다 (결정적 tie-break)")
    func tieIsDeterministic() {
        let t = "2026-09-03T10:00:00Z"
        let a = LibraryDocument(recipes: [recipe("a", name: "판 A", updatedAt: t)])
        let b = LibraryDocument(recipes: [recipe("a", name: "판 B", updatedAt: t)])
        let ab = LibrarySync.merge(local: a, remote: b)
        let ba = LibrarySync.merge(local: b, remote: a)
        #expect(ab == ba)
        // 같은 내용이면 그대로
        let same = LibrarySync.merge(local: a, remote: a)
        #expect(same.recipes[0].name == "판 A")
    }

    @Test("병합 결과는 순서까지 결정적 — 두 기기가 같은 문서로 수렴한다 (무한 동기화 루프 방지)")
    func orderIndependentConvergence() {
        let r1 = recipe("r1", name: "A", updatedAt: "2026-09-01T00:00:00Z")
        var r2 = recipe("r2", name: "B", updatedAt: "2026-09-02T00:00:00Z")
        r2.createdAt = "2026-09-02T00:00:00Z"
        var r3 = recipe("r3", name: "C", updatedAt: "2026-09-03T00:00:00Z")
        r3.createdAt = "2026-09-03T00:00:00Z"
        let deviceA = LibraryDocument(recipes: [r2, r1])  // A: 최신 생성이 앞
        let deviceB = LibraryDocument(recipes: [r3, r2, r1])
        let fromA = LibrarySync.merge(local: deviceA, remote: deviceB)
        let fromB = LibrarySync.merge(local: deviceB, remote: deviceA)
        #expect(fromA == fromB)  // 배열 순서까지 동일
        #expect(fromA.recipes.map(\.id) == ["r3", "r2", "r1"])  // 생성 최신순
        // 재병합은 멱등 — 같은 문서를 다시 합쳐도 변하지 않는다 (쓰기 조건 `merged != remote`가 거짓이 됨)
        #expect(LibrarySync.merge(local: fromA, remote: fromB) == fromA)
    }

    @Test("정규화는 멱등이고, 이름 trim 같은 코덱 규칙을 로컬에도 적용한다")
    func normalizationIdempotent() throws {
        var r = recipe("a", name: "캉파뉴 ", updatedAt: "2026-09-01T00:00:00Z")
        r.tags = []
        let doc = LibraryDocument(recipes: [r])
        let n1 = LibrarySync.normalized(doc)
        #expect(n1.recipes[0].name == "캉파뉴")
        #expect(n1.recipes[0].tags == nil)
        #expect(LibrarySync.normalized(n1) == n1)
        // 정규화된 문서는 인코딩→디코딩 왕복에서 그대로다 (원격 비교의 전제)
        #expect(LibrarySync.decode(try LibrarySync.encode(n1)) == n1)
    }

    @Test("묘비 시각은 항목의 updatedAt보다 항상 뒤다 (기기 시계 차이 방어)")
    func tombstoneBeatsFutureItem() {
        let future = "2099-01-01T00:00:00Z"
        let t = LibrarySync.tombstoneTime(for: future, now: Date())
        #expect(LibrarySync.isNewer(t, than: future))
        let m = LibrarySync.merge(
            local: LibraryDocument(deleted: [Tombstone(id: "a", deletedAt: t)]),
            remote: LibraryDocument(recipes: [recipe("a", name: "미래", updatedAt: future)]))
        #expect(m.recipes.isEmpty)
    }

    @Test("한 기기에서 지운 항목은 다른 기기 사본에서도 사라진다 (묘비)")
    func tombstoneDeletes() {
        let local = LibraryDocument(
            recipes: [],
            deleted: [Tombstone(id: "a", deletedAt: "2026-09-04T00:00:00Z")])
        let remote = LibraryDocument(recipes: [
            recipe("a", name: "A", updatedAt: "2026-09-03T00:00:00Z"),
            recipe("b", name: "B", updatedAt: "2026-09-03T00:00:00Z"),
        ])
        let m = LibrarySync.merge(local: local, remote: remote)
        #expect(m.recipes.map(\.id) == ["b"])
        #expect(m.deleted.map(\.id) == ["a"])  // 묘비는 유지되어 세 번째 기기에도 전파
    }

    @Test("삭제 뒤에 다른 기기에서 편집한 항목은 살아난다 (편집이 이김)")
    func editAfterDeleteRevives() {
        let local = LibraryDocument(
            deleted: [Tombstone(id: "a", deletedAt: "2026-09-04T00:00:00Z")])
        let remote = LibraryDocument(recipes: [
            recipe("a", name: "수정본", updatedAt: "2026-09-05T00:00:00Z")
        ])
        let m = LibrarySync.merge(local: local, remote: remote)
        #expect(m.recipes.map(\.id) == ["a"])
        #expect(m.deleted.isEmpty)  // 무효화된 묘비는 버린다
    }

    @Test("로그는 소속 레시피가 살아 있을 때만 남고, 로그 자체도 최신·묘비 규칙을 따른다")
    func logsFollowRecipes() {
        let local = LibraryDocument(
            recipes: [recipe("a", name: "A", updatedAt: "2026-09-01T00:00:00Z")],
            logs: [
                log("l1", recipeId: "a", note: "로컬 메모", updatedAt: "2026-09-02T00:00:00Z"),
                log("l2", recipeId: "gone", note: "고아", updatedAt: "2026-09-02T00:00:00Z"),
            ])
        let remote = LibraryDocument(
            recipes: [recipe("a", name: "A", updatedAt: "2026-09-01T00:00:00Z")],
            logs: [
                log("l1", recipeId: "a", note: "원격 메모(최신)", updatedAt: "2026-09-03T00:00:00Z"),
                log("l3", recipeId: "a", note: "삭제됨", updatedAt: "2026-09-02T00:00:00Z"),
            ],
            deleted: [Tombstone(id: "l3", deletedAt: "2026-09-04T00:00:00Z")])
        let m = LibrarySync.merge(local: local, remote: remote)
        #expect(m.logs.map(\.id) == ["l1"])
        #expect(m.logs[0].note == "원격 메모(최신)")
    }

    @Test("웹 밀리초 ISO와 iOS 초 단위 ISO를 올바르게 비교한다")
    func isoComparison() {
        #expect(LibrarySync.isNewer("2026-09-03T10:00:00.500Z", than: "2026-09-03T10:00:00Z"))
        #expect(!LibrarySync.isNewer("2026-09-03T10:00:00Z", than: "2026-09-03T10:00:00.500Z"))
        #expect(LibrarySync.isNewer("2026-09-03T10:00:01Z", than: "2026-09-03T10:00:00.999Z"))
    }

    @Test("인코딩 왕복 + 옛 recipes.json(배열) 형식도 읽는다")
    func codecRoundTrip() throws {
        let doc = LibraryDocument(
            recipes: [recipe("a", name: "A", updatedAt: "2026-09-01T00:00:00Z")],
            logs: [log("l1", recipeId: "a", note: "메모", updatedAt: "2026-09-02T00:00:00Z")],
            deleted: [Tombstone(id: "x", deletedAt: "2026-09-03T00:00:00Z")])
        let data = try LibrarySync.encode(doc)
        #expect(LibrarySync.decode(data) == doc)
        // 웹 가져오기와 호환: recipes 키가 있는 봉투
        let text = String(decoding: data, as: UTF8.self)
        #expect((try? RecipeCodec.importJSON(text).get())?.count == 1)
        // 옛 형식
        let legacy = Data(#"[{"schemaVersion":2,"name":"옛것","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"hydration":1,"grams":200}}]"#.utf8)
        let migrated = LibrarySync.decode(legacy)
        #expect(migrated.recipes.count == 1)
        #expect(migrated.logs.isEmpty)
    }

    @Test("불량 로그(별점 범위 밖)·깨진 JSON은 건너뛰거나 빈 문서로")
    func lenientDecode() {
        let bad = Data(#"{"recipes":[],"logs":[{"id":"l","recipeId":"a","bakedAt":"x","rating":9,"note":"","createdAt":"x","updatedAt":"x"},{"id":"ok","recipeId":"a","bakedAt":"x","rating":5,"note":"","createdAt":"x","updatedAt":"x"}]}"#.utf8)
        #expect(LibrarySync.decode(bad).logs.map(\.id) == ["ok"])
        #expect(LibrarySync.decode(Data("not json".utf8)).isEmpty)
    }
}
