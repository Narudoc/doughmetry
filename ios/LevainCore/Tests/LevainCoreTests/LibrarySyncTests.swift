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

    @Test("parseISO — 초 단위·밀리초·시간대 오프셋을 읽고, 형식이 다르면 nil")
    func parseISOForms() throws {
        let base = 1_788_429_600.0 // 2026-09-03T10:00:00Z
        #expect(parseISO("2026-09-03T10:00:00Z")?.timeIntervalSince1970 == base)
        let ms = try #require(parseISO("2026-09-03T10:00:00.123Z")).timeIntervalSince1970
        #expect(abs(ms - (base + 0.123)) < 1e-6)
        #expect(parseISO("2026-09-03T19:00:00+09:00")?.timeIntervalSince1970 == base)
        #expect(parseISO("2026-09-03T19:00:00.250+09:00")?.timeIntervalSince1970 == base + 0.25)
        #expect(parseISO("2026-09-03") == nil)
        #expect(parseISO("x") == nil)
        #expect(parseISO("") == nil)
    }

    @Test("isoString은 초 단위 UTC 형식 그대로다 (저장값 형식 호환)")
    func isoStringFormat() {
        #expect(isoString(from: Date(timeIntervalSince1970: 1_788_429_600.25)) == "2026-09-03T10:00:00Z")
        let now = isoNow()
        #expect(now.count == 20 && now.hasSuffix("Z"))
        #expect(isoString(from: parseISO(now)!) == now)
    }

    @Test("큰 라이브러리(레시피 200 · 로그 1000)의 정규화+병합이 프레임 몇 개 안에 끝난다")
    func mergePerformance() {
        let base = Date(timeIntervalSince1970: 1_788_429_600)
        func stamp(_ i: Int) -> String { isoString(from: base.addingTimeInterval(Double(i) * 37)) }
        var recipes: [Recipe] = []
        for i in 0..<200 {
            var r = recipe("r\(i)", name: "R\(i)", updatedAt: stamp(i))
            r.createdAt = stamp(i * 7 % 200)
            recipes.append(r)
        }
        let logs = (0..<1000).map { i in
            BakeLog(
                id: "l\(i)", recipeId: "r\(i % 200)", bakedAt: stamp(i * 13 % 1000), rating: 3,
                note: "", createdAt: stamp(i), updatedAt: stamp(i))
        }
        let doc = LibraryDocument(recipes: recipes, logs: logs)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            let local = LibrarySync.normalized(doc)
            _ = LibrarySync.merge(local: local, remote: local)
        }
        // 호출마다 ISO8601DateFormatter를 만들던 때는 수 초 — 메인 스레드에서 돌므로 넉넉히 잡아도 1초 미만이어야 한다
        #expect(elapsed < .seconds(1))
    }

    @Test("지운 레시피를 백업에서 복원하면 다음 병합 뒤에도 살아남는다 (같은 초 · 미래 묘비 포함)")
    func restoreAfterDeleteSurvivesMerge() {
        let deletedAt = Date(timeIntervalSince1970: 1_788_429_600)
        let backup = recipe("R", name: "복원", updatedAt: "2026-09-01T00:00:00Z")
        for tomb in [
            Tombstone(id: "R", deletedAt: LibrarySync.tombstoneTime(for: backup.updatedAt, now: deletedAt)),
            Tombstone(id: "R", deletedAt: "2099-01-01T00:00:00Z"), // 시계가 앞선 기기가 지운 경우
        ] {
            // 삭제가 동기화된 원격 사본
            let remote = LibrarySync.merge(
                local: LibraryDocument(deleted: [tomb]),
                remote: LibraryDocument(recipes: [backup]))
            #expect(remote.recipes.isEmpty)

            // 백업의 옛 updatedAt 그대로면 다시 지워진다
            let stale = LibrarySync.merge(
                local: LibrarySync.normalized(LibraryDocument(recipes: [backup])), remote: remote)
            #expect(stale.recipes.isEmpty)

            // 삭제와 같은 초에 복원해도 묘비 뒤로 밀려 살아남는다
            var restored = backup
            restored.updatedAt = LibrarySync.revivedUpdatedAt(
                backup.updatedAt, over: tomb, now: deletedAt)
            #expect(LibrarySync.isNewer(restored.updatedAt, than: tomb.deletedAt))
            let merged = LibrarySync.merge(
                local: LibrarySync.normalized(LibraryDocument(recipes: [restored])), remote: remote)
            #expect(merged.recipes.map(\.id) == ["R"])
            #expect(merged.deleted.isEmpty)
        }
    }

    @Test("묘비가 없거나 이미 묘비보다 최신이면 updatedAt을 건드리지 않는다")
    func reviveKeepsNewerStamp() {
        let t = "2026-09-03T10:00:00Z"
        #expect(LibrarySync.revivedUpdatedAt(t, over: nil) == t)
        let older = Tombstone(id: "R", deletedAt: "2026-09-02T00:00:00Z")
        #expect(LibrarySync.revivedUpdatedAt(t, over: older) == t)
    }

    @Test(
        "UI 최소 르방 수분율(1%)로 만든 레시피는 정규화(로드·동기화)에서 살아남는다",
        arguments: ["target", "fixedMass", "fixedPff"])
    func minHydrationRecipeSurvives(source: String) throws {
        let h = 0.01
        let base = DoughInput(
            flours: [Flour(id: "f", name: "T65", grams: 900)], water: 620, salt: 20,
            levain: Levain(type: .liquide, hydration: 1, grams: 200))
        let input: DoughInput
        switch source {
        case "target":
            input = solveFromTarget(
                TargetSpec(
                    doughWeight: 1740, hydration: 0.72, saltRatio: 0.02, pff: 0.1,
                    levainHydration: h))
        case "fixedMass":
            input = try convertFixedMass(base, newHydration: h).get().output
        default:
            input = try convertFixedPff(base, newHydration: h).get().output
        }
        let r = Recipe(
            id: "min", name: "최소 수분율", createdAt: "2026-09-01T00:00:00Z",
            updatedAt: "2026-09-01T00:00:00Z", input: input)
        let n = LibrarySync.normalized(LibraryDocument(recipes: [r]))
        #expect(n.recipes.map(\.id) == ["min"])
        #expect(n.recipes.first?.levain.hydration == h)
    }

    @Test("decode가 검증 실패로 버린 레시피·로그 개수를 센다 (원본 보관 판단용)")
    func droppedItemCount() {
        let ok = #"{"schemaVersion":2,"name":"좋은것","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"hydration":1,"grams":200}}"#
        let badHydration = #"{"schemaVersion":2,"name":"수분율0","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"hydration":0,"grams":200}}"#
        let badLog = #"{"id":"l","recipeId":"a","bakedAt":"x","rating":9,"note":"","createdAt":"x","updatedAt":"x"}"#
        let doc = Data(#"{"recipes":[\#(ok),\#(badHydration)],"logs":[\#(badLog)],"deleted":[]}"#.utf8)
        #expect(LibrarySync.droppedItemCount(in: doc, decoded: LibrarySync.decode(doc)) == 2)
        let legacy = Data("[\(ok),\(badHydration)]".utf8)
        #expect(LibrarySync.droppedItemCount(in: legacy, decoded: LibrarySync.decode(legacy)) == 1)
        let clean = Data(#"{"recipes":[\#(ok)],"logs":[]}"#.utf8)
        #expect(LibrarySync.droppedItemCount(in: clean, decoded: LibrarySync.decode(clean)) == 0)
        let notArray = Data(#"{"recipes":{"oops":1}}"#.utf8)
        #expect(LibrarySync.droppedItemCount(in: notArray, decoded: LibrarySync.decode(notArray)) == 1)
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

    // MARK: 편집 시각 · 내용이 같은 저장 · 가져오기 · 새 버전 형식

    @Test("편집 시각은 바꾸는 판의 updatedAt보다 항상 뒤다 (시계가 앞선 기기의 판을 고쳐도 편집이 이긴다)")
    func editTimeIsMonotonic() throws {
        let now = Date(timeIntervalSince1970: 1_788_429_600)  // 2026-09-03T10:00:00Z
        #expect(LibrarySync.editTime(replacing: nil, now: now) == "2026-09-03T10:00:00Z")
        #expect(LibrarySync.editTime(replacing: "2026-09-01T00:00:00Z", now: now) == "2026-09-03T10:00:00Z")
        // 같은 초·밀리초 판도 앞선다
        #expect(LibrarySync.editTime(replacing: "2026-09-03T10:00:00Z", now: now) == "2026-09-03T10:00:01Z")
        #expect(LibrarySync.isNewer(
            LibrarySync.editTime(replacing: "2026-09-03T10:00:00.900Z", now: now), than: "2026-09-03T10:00:00.900Z"))

        // 3분 빠른 기기 B가 남긴 판 위에 A(정확한 시계)가 편집 → A의 편집이 병합에서 이긴다
        let fromB = recipe("R", name: "B 편집", updatedAt: "2026-09-03T10:03:00Z")
        var edit = fromB
        edit.name = "A 편집"
        let saved = try #require(
            LibrarySync.savedRecipe(edit, replacing: fromB, tombstone: nil, now: now))
        #expect(LibrarySync.isNewer(saved.updatedAt, than: fromB.updatedAt))
        let remote = LibraryDocument(recipes: [fromB])
        let local = LibrarySync.normalized(LibraryDocument(recipes: [saved]))
        #expect(LibrarySync.merge(local: local, remote: remote).recipes.map(\.name) == ["A 편집"])
        #expect(LibrarySync.merge(local: remote, remote: local).recipes.map(\.name) == ["A 편집"])
    }

    @Test("내용이 같은 저장은 updatedAt을 올리지 않는다 — 낡은 사본이 다른 기기의 새 편집을 이기지 못하게")
    func noOpSavesDoNotBump() throws {
        let now = Date(timeIntervalSince1970: 1_788_429_600)
        var stale = recipe("R", name: "R", updatedAt: "2026-09-01T00:00:00Z")
        stale.note = "메모"
        // 다른 기기(A)에서 물을 바꾼 새 판
        var newer = stale
        newer.water = 750
        newer.updatedAt = "2026-09-02T00:00:00Z"

        // 노트: 그대로 저장하면 nil, 빈 노트와 nil은 같은 것
        #expect(LibrarySync.notedRecipe(stale, note: "메모", now: now) == nil)
        var noNote = stale
        noNote.note = nil
        #expect(LibrarySync.notedRecipe(noNote, note: "", now: now) == nil)
        #expect(LibrarySync.notedRecipe(noNote, note: nil, now: now) == nil)
        // 앞뒤 공백만 다른 노트 (편집 시트는 잘라서 넘긴다)
        var spaced = stale
        spaced.note = "메모 \n"
        #expect(LibrarySync.notedRecipe(spaced, note: "메모", now: now) == nil)
        let edited = try #require(LibrarySync.notedRecipe(stale, note: "새 메모", now: now))
        #expect(edited.note == "새 메모")
        #expect(LibrarySync.isNewer(edited.updatedAt, than: stale.updatedAt))
        #expect(try #require(LibrarySync.notedRecipe(stale, note: "", now: now)).note == nil)

        // 기기 B는 아직 낡은 사본 — 노트를 그대로 저장해도 바뀌지 않으므로 A의 편집이 살아남는다
        let afterNoOp = LibrarySync.notedRecipe(stale, note: "메모", now: now) ?? stale
        let m = LibrarySync.merge(
            local: LibraryDocument(recipes: [afterNoOp]), remote: LibraryDocument(recipes: [newer]))
        #expect(m.recipes.first?.water == 750)

        // 레시피: 타임스탬프만 다른 같은 내용은 nil, 내용이 다르면 편집 시각
        var resave = stale
        resave.createdAt = "2026-09-03T10:00:00Z"
        resave.updatedAt = "2026-09-03T10:00:00Z"
        #expect(LibrarySync.savedRecipe(resave, replacing: stale, tombstone: nil, now: now) == nil)
        resave.water = 700
        let savedRecipe = try #require(
            LibrarySync.savedRecipe(resave, replacing: stale, tombstone: nil, now: now))
        #expect(savedRecipe.createdAt == stale.createdAt)
        #expect(savedRecipe.updatedAt == "2026-09-03T10:00:00Z")
        // 묘비가 있으면(삭제 직후 재저장) 같은 내용이어도 저장하고 묘비 뒤로 민다
        let tomb = Tombstone(id: "R", deletedAt: "2099-01-01T00:00:00Z")
        let revived = try #require(
            LibrarySync.savedRecipe(stale, replacing: nil, tombstone: tomb, touch: false, now: now))
        #expect(LibrarySync.isNewer(revived.updatedAt, than: tomb.deletedAt))

        // 로그: 날짜·별점·메모·소속이 같으면 nil
        let existing = log("l1", recipeId: "R", note: "좋음", updatedAt: "2026-09-02T00:00:00Z")
        var same = existing
        same.updatedAt = "2026-09-03T10:00:00Z"
        same.createdAt = "2026-09-03T10:00:00Z"
        #expect(LibrarySync.savedLog(same, replacing: existing, tombstone: nil, now: now) == nil)
        same.rating = 5
        let savedLog = try #require(
            LibrarySync.savedLog(same, replacing: existing, tombstone: nil, now: now))
        #expect(savedLog.createdAt == existing.createdAt)
        #expect(LibrarySync.isNewer(savedLog.updatedAt, than: existing.updatedAt))
        // 새 로그는 그대로 저장
        #expect(LibrarySync.savedLog(existing, replacing: nil, tombstone: nil, now: now) != nil)
    }

    @Test("JSON 가져오기 — 기기의 같거나 더 새 판은 건너뛰고, 파일 안 중복 id는 첫 항목만")
    func importKeepsNewerLocal() {
        let local = [
            recipe("a", name: "기기 A (화요일)", updatedAt: "2026-09-02T00:00:00Z"),
            recipe("b", name: "B", updatedAt: "2026-09-01T00:00:00Z"),
            recipe("c", name: "C", updatedAt: "2026-09-01T00:00:00Z"),
        ]
        let imported = [
            recipe("new", name: "새 레시피", updatedAt: "2026-08-01T00:00:00Z"),
            recipe("a", name: "백업 A (월요일)", updatedAt: "2026-09-01T00:00:00Z"),  // 더 옛것
            recipe("b", name: "B", updatedAt: "2026-09-05T00:00:00Z"),  // 더 새것이지만 내용이 같다
            recipe("c", name: "C 수정", updatedAt: "2026-09-05T00:00:00Z"),  // 더 새것
            recipe("dup", name: "첫 항목", updatedAt: "2026-08-01T00:00:00Z"),
            recipe("dup", name: "둘째 항목", updatedAt: "2026-09-09T00:00:00Z"),
        ]
        let plan = LibrarySync.importable(imported, local: local)
        #expect(plan.accepted.map(\.id) == ["new", "c", "dup"])
        #expect(plan.accepted.first { $0.id == "dup" }?.name == "첫 항목")
        #expect(plan.skipped == 3)
        // 묘비만 남은 id(지운 레시피)는 복원으로 받는다
        #expect(LibrarySync.importable([recipe("gone", name: "복원", updatedAt: "2026-08-01T00:00:00Z")], local: local).accepted.count == 1)
    }

    // src/lib/storage.test.ts mergeImported와 같은 경우 — 두 플랫폼이 한 규칙을 쓴다
    @Test("JSON 가져오기 — 같은 시각은 내용이 달라도 건너뛰고, 시각은 문자열이 아니라 실제 시각으로 비교")
    func importComparesParsedTimes() {
        let local = [recipe("a", name: "기기 A", updatedAt: "2026-08-01T00:00:00Z")]
        // 같은 시각 + 다른 내용 → 건너뜀 (iCloud 병합의 동률 처리에 맡기지 않는다)
        #expect(LibrarySync.importable(
            [recipe("a", name: "백업 A", updatedAt: "2026-08-01T00:00:00.000Z")], local: local).skipped == 1)
        // 문자열로는 더 크지만 실제로는 더 이른 시각(2026-07-31T23:00Z) → 건너뜀
        #expect(LibrarySync.importable(
            [recipe("a", name: "백업 A", updatedAt: "2026-08-01T08:00:00+09:00")], local: local).skipped == 1)
        // 같은 내보내기를 다시 가져오면 아무것도 받지 않는다
        #expect(LibrarySync.importable(local, local: local).accepted.isEmpty)
        // 한쪽이라도 해석되지 않으면 문자열로 비교한다 (웹 mergeImported와 같은 결과)
        #expect(LibrarySync.importable(
            [recipe("a", name: "백업 A", updatedAt: "zzz")], local: local).accepted.count == 1)
        #expect(LibrarySync.importable(
            [recipe("a", name: "백업 A", updatedAt: "2026-09-01T00:00:00Z")],
            local: [recipe("a", name: "기기 A", updatedAt: "garbage")]).skipped == 1)
        // 날짜만 있는 문자열은 해석하지 않는다 → 문자열로는 더 작다
        #expect(LibrarySync.importable(
            [recipe("a", name: "백업 A", updatedAt: "2026-08-02")],
            local: [recipe("a", name: "기기 A", updatedAt: "2026-08-02T01:00:00+09:00")]).skipped == 1)
    }

    // 기댓값은 웹 storage.ts isNewer(ISO_DATE_TIME + V8 Date.parse)로 같은 쌍을 돌린 결과
    @Test(
        "JSON 가져오기 — 시각 문법이 웹과 같다 (밀리초 아래 버림, 소문자 z·한 자리 월·10:60은 문자열 비교)",
        arguments: [
            // (기기 updatedAt, 가져온 updatedAt, 받는가)
            ("2026-09-03T10:00:00.1234Z", "2026-09-03T10:00:00.1235Z", false),
            ("2026-09-03T10:00:00.123Z", "2026-09-03T10:00:00.123400Z", false),
            ("2026-09-03T10:00:00Z", "2026-09-03T10:00:00z", true),
            ("2026-09-03T10:00:00Z", "2026-9-3T10:00:00Z", true),
            ("2026-09-03T19:00:00+09:00", "2026-09-03T10:60:00Z", false),
            ("2026-09-03T10:00:00Z", "2026-09-03T19:00:00+09", true),
            ("2026-09-03T10:00:00Z", "2026-09-03T10:00:00Z ", true),
            ("2026-09-03T10:00:00Z", "2026-09-03T19:00:01+0900", true),
            ("2026-09-04T00:00:00Z", "2026-09-03T24:00:00.000Z", false),
            ("2026-09-03T23:59:59Z", "2026-09-03T24:00:00Z", true),
            ("2026-03-03T00:00:00Z", "2026-02-31T00:00:00Z", false),
        ])
    func importMatchesWebTimeGrammar(local: String, imported: String, accepted: Bool) {
        let plan = LibrarySync.importable(
            [recipe("a", name: "백업 A", updatedAt: imported)],
            local: [recipe("a", name: "기기 A", updatedAt: local)])
        #expect(plan.accepted.count == (accepted ? 1 : 0))
    }

    @Test("webEpochMillis — V8 Date.parse와 같은 값, 웹 정규식·Date.parse가 거절하는 형식은 nil")
    func webEpochMillisMatchesV8() {
        let parsed: [(String, Int)] = [
            ("2026-09-03T10:00:00Z", 1_788_429_600_000),
            ("2026-09-03T10:00:00.5Z", 1_788_429_600_500),
            ("2026-09-03T10:00:00.1234567Z", 1_788_429_600_123),
            ("2026-09-03T19:00:00+0900", 1_788_429_600_000),
            ("2026-09-03T00:30:00-09:30", 1_788_429_600_000),
            ("2026-09-03T24:00:00.000Z", 1_788_480_000_000),
            ("2026-02-31T00:00:00Z", 1_772_496_000_000),  // 3월 3일로 넘어간다
            ("2024-02-30T00:00:00Z", 1_709_251_200_000),
            ("0000-01-01T00:00:00Z", -62_167_219_200_000),
            ("1969-12-31T23:59:59.999Z", -1),
            ("9999-12-31T23:59:59.999Z", 253_402_300_799_999),
        ]
        for (s, ms) in parsed {
            #expect(LibrarySync.webEpochMillis(s) == ms, "\(s)")
        }
        let rejected = [
            "", "x", "2026-09-03", "2026-09-03T10:00Z", "2026-09-03 10:00:00Z", "2026-09-03t10:00:00Z",
            "2026-09-03T10:00:00z", "2026-9-3T10:00:00Z", "2026-09-03T10:00:00+09", "2026-09-03T10:00:00Z ",
            "2026-09-03T10:00:00.Z", "2026-09-03T10:60:00Z", "2026-09-03T10:00:60Z", "2026-09-03T25:00:00Z",
            "2026-09-03T24:00:01Z", "2026-09-03T24:00:00.0000000001Z", "2026-13-01T00:00:00Z",
            "2026-00-01T00:00:00Z", "2026-09-00T00:00:00Z", "2026-09-32T00:00:00Z",
            "2026-09-03T10:00:00+24:00", "2026-09-03T10:00:00+0960", "２０２６-09-03T10:00:00Z",
        ]
        for s in rejected {
            #expect(LibrarySync.webEpochMillis(s) == nil, "\(s)")
        }
    }

    @Test("새 버전 앱이 쓴 문서(문서·레시피 schemaVersion이 더 큼)를 알아본다")
    func detectsNewerFormat() throws {
        let ok = #"{"schemaVersion":2,"id":"r1","name":"R1","createdAt":"2026-09-01T00:00:00Z","updatedAt":"2026-09-01T00:00:00Z","flours":[{"id":"f1","grams":900}],"water":620,"salt":20,"levain":{"hydration":1,"grams":200}}"#
        let v3 = #"{"schemaVersion":3,"id":"r2","name":"R2","flours":[{"grams":900}],"water":620,"salt":20,"levain":{"hydration":1,"grams":200},"photos":["p"]}"#

        let current = try LibrarySync.encode(
            LibraryDocument(recipes: [recipe("a", name: "A", updatedAt: "2026-09-01T00:00:00Z")]))
        #expect(LibrarySync.decodeReport(current).isNewerFormat == false)
        #expect(LibrarySync.decodeReport(Data("not json".utf8)).isNewerFormat == false)

        let newerDoc = Data(#"{"schemaVersion":\#(LibraryDocument.currentSchemaVersion + 1),"recipes":[\#(ok)],"logs":[],"deleted":[]}"#.utf8)
        let report = LibrarySync.decodeReport(newerDoc)
        #expect(report.isNewerFormat)
        #expect(report.document.recipes.map(\.id) == ["r1"])  // 읽을 수 있는 항목은 읽는다

        let newerRecipe = Data(#"{"schemaVersion":1,"recipes":[\#(ok),\#(v3)],"logs":[],"deleted":[]}"#.utf8)
        let r2 = LibrarySync.decodeReport(newerRecipe)
        #expect(r2.isNewerFormat)
        #expect(r2.document.recipes.map(\.id) == ["r1"])
        #expect(LibrarySync.decode(newerRecipe) == r2.document)

        // 병합 결과는 원격의 더 큰 번호를 이어받지 않는다 — 옛 버전이 걸러 낸 문서에 새 번호가 붙지 않게
        let merged = LibrarySync.merge(local: LibraryDocument(), remote: report.document)
        #expect(report.document.schemaVersion == LibraryDocument.currentSchemaVersion + 1)
        #expect(merged.schemaVersion == LibraryDocument.currentSchemaVersion)
    }

    @Test("불량 로그(별점 범위 밖)·깨진 JSON은 건너뛰거나 빈 문서로")
    func lenientDecode() {
        let bad = Data(#"{"recipes":[],"logs":[{"id":"l","recipeId":"a","bakedAt":"x","rating":9,"note":"","createdAt":"x","updatedAt":"x"},{"id":"ok","recipeId":"a","bakedAt":"x","rating":5,"note":"","createdAt":"x","updatedAt":"x"}]}"#.utf8)
        #expect(LibrarySync.decode(bad).logs.map(\.id) == ["ok"])
        #expect(LibrarySync.decode(Data("not json".utf8)).isEmpty)
    }
}
