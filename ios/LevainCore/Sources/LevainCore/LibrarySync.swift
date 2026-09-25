import Foundation

/// 라이브러리 문서의 인코딩/관용 디코딩과 기기 간 병합.
///
/// 병합 규칙 (양쪽 문서 → 하나):
/// - 같은 id의 레시피/로그는 `updatedAt`이 최신인 쪽을 택한다 (동률이면 로컬)
/// - 묘비(tombstone)의 `deletedAt`이 항목의 `updatedAt`보다 최신이면 항목을 지운다
///   → 한 기기에서 지우고 다른 기기에서 그 뒤에 고친 항목은 되살아난다 (편집이 이긴다)
/// - 묘비는 id별로 최신 `deletedAt`만 남긴다
/// 결과는 입력 순서와 무관하게 결정적이다.
public enum LibrarySync {
    // MARK: ISO 시각 비교 (웹은 밀리초 포함, iOS는 미포함 — 둘 다 파싱)

    /// a가 b보다 최신이면 true (파싱 실패 시 문자열 비교).
    /// 병합·묘비 판정은 웹 문법(isNewerOnWeb)으로 좁히지 말 것 — 손으로 고친 백업의 느슨한 시각(한 자리 월·일 등)이
    /// 문자열 비교로 떨어지면 이 기기의 새 편집·삭제가 다른 기기의 옛 판에 밀린다.
    public static func isNewer(_ a: String, than b: String) -> Bool {
        if let da = parseISO(a), let db = parseISO(b) { return da > db }
        return a > b
    }

    /// 웹 storage.ts isNewer와 같은 판정 — JSON 가져오기(importable)가 웹 mergeImported와 같은 결과를 내도록.
    /// 둘 다 webEpochMillis로 읽히면 시각으로, 아니면 JS 문자열 비교(UTF-16 코드 단위 순)로.
    static func isNewerOnWeb(_ a: String, than b: String) -> Bool {
        if let ta = webEpochMillis(a), let tb = webEpochMillis(b) { return ta > tb }
        return b.utf16.lexicographicallyPrecedes(a.utf16)
    }

    /// 웹이 읽는 시각(epoch ms) — ISO_DATE_TIME 정규식을 통과한 문자열의 V8 Date.parse 값과 같다.
    /// YYYY-MM-DDTHH:MM:SS[.f…](Z|±HH[:]MM), ASCII 숫자. 월 1~12·일 1~31(그 달에 없는 날은 다음 달로 넘김),
    /// 분·초 ≤ 59, 24시는 24:00:00(.000…)만, 오프셋 ≤ 23:59, 소수 초는 밀리초까지 버림. 그 밖은 nil.
    /// parseISO(ICU)는 소문자 z·한 자리 월·10:60 같은 형식도 받아 주고 밀리초 아래까지 비교해 웹과 어긋난다.
    static func webEpochMillis(_ s: String) -> Int? {
        var s = s
        return s.withUTF8 { b -> Int? in
            func number(_ at: Int, _ count: Int) -> Int? {
                guard at + count <= b.count else { return nil }
                var v = 0
                for k in at..<(at + count) {
                    let d = b[k] &- 48
                    guard d < 10 else { return nil }
                    v = v * 10 + Int(d)
                }
                return v
            }
            guard b.count >= 20,
                let year = number(0, 4), b[4] == UInt8(ascii: "-"),
                let month = number(5, 2), (1...12).contains(month), b[7] == UInt8(ascii: "-"),
                let day = number(8, 2), (1...31).contains(day), b[10] == UInt8(ascii: "T"),
                let hour = number(11, 2), b[13] == UInt8(ascii: ":"),
                let minute = number(14, 2), minute <= 59, b[16] == UInt8(ascii: ":"),
                let second = number(17, 2), second <= 59
            else { return nil }
            var i = 19
            var millis = 0
            var fractionIsZero = true
            if b[i] == UInt8(ascii: ".") {
                i += 1
                let start = i
                while i < b.count, b[i] &- 48 < 10 {
                    let d = Int(b[i] - 48)
                    if i - start < 3 { millis = millis * 10 + d }
                    if d != 0 { fractionIsZero = false }
                    i += 1
                }
                guard i > start else { return nil }
                for _ in min(i - start, 3)..<3 { millis *= 10 }
            }
            guard hour <= 23 || (hour == 24 && minute == 0 && second == 0 && fractionIsZero),
                i < b.count
            else { return nil }
            var offsetMinutes = 0
            if b[i] == UInt8(ascii: "Z") {
                i += 1
            } else if b[i] == UInt8(ascii: "+") || b[i] == UInt8(ascii: "-") {
                let sign = b[i] == UInt8(ascii: "-") ? -1 : 1
                guard let oh = number(i + 1, 2), oh <= 23 else { return nil }
                i += 3
                if i < b.count, b[i] == UInt8(ascii: ":") { i += 1 }
                guard let om = number(i, 2), om <= 59 else { return nil }
                i += 2
                offsetMinutes = sign * (oh * 60 + om)
            } else {
                return nil
            }
            guard i == b.count else { return nil }
            // 1970-01-01부터의 일수 — JS Date처럼 역산 그레고리력 (ICU의 1582년 이전 율리우스력과 다르다)
            let y = month <= 2 ? year - 1 : year
            let era = (y >= 0 ? y : y - 399) / 400
            let yoe = y - era * 400
            let doy = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
            let days = era * 146_097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719_468
            return (((days * 24 + hour) * 60 + minute - offsetMinutes) * 60 + second) * 1000 + millis
        }
    }

    /// 동률(updatedAt이 같고 내용이 다름)일 때 양쪽 기기가 같은 답을 내도록
    /// 인코딩 문자열이 큰 쪽을 택한다 — 어느 기기가 '로컬'이든 결과가 같아야 수렴한다
    static func deterministicTieBreak<T: Encodable>(_ a: T, _ b: T) -> T {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let da = try? enc.encode(a), let db = try? enc.encode(b) else { return a }
        let sa = String(decoding: da, as: UTF8.self)
        let sb = String(decoding: db, as: UTF8.self)
        return sb > sa ? b : a
    }

    /// 정규 순서 — 레시피는 생성 최신순(같으면 id), 로그는 구운 날짜 최신순(같으면 id), 묘비는 id.
    /// 병합 결과·저장 문서가 기기와 무관하게 같은 배열이 되어야 `==` 비교로 수렴을 판단할 수 있다.
    public static func canonical(_ doc: LibraryDocument) -> LibraryDocument {
        var d = doc
        d.recipes.sort { a, b in
            if a.createdAt != b.createdAt { return isNewer(a.createdAt, than: b.createdAt) }
            return a.id < b.id
        }
        d.logs.sort { a, b in
            if a.bakedAt != b.bakedAt { return isNewer(a.bakedAt, than: b.bakedAt) }
            return a.id < b.id
        }
        d.deleted.sort { $0.id < $1.id }
        return d
    }

    /// 코덱 왕복으로 정규화 (이름 trim, 빈 tags → nil 등 validate 규칙 적용) + 정규 순서.
    /// 로컬 상태를 이 형태로 유지해야 iCloud에서 읽은 문서와 `==`가 성립한다.
    public static func normalized(_ doc: LibraryDocument) -> LibraryDocument {
        guard let data = try? encode(doc) else { return canonical(doc) }
        return decode(data)
    }

    // MARK: 병합

    public static func merge(local: LibraryDocument, remote: LibraryDocument) -> LibraryDocument {
        // 묘비: id별 최신
        var tombstones: [String: Tombstone] = [:]
        for t in local.deleted + remote.deleted {
            if let existing = tombstones[t.id], !isNewer(t.deletedAt, than: existing.deletedAt) {
                continue
            }
            tombstones[t.id] = t
        }

        func pickNewer<T: Encodable & Equatable>(_ a: T, _ b: T, updatedAt: (T) -> String) -> T {
            let ua = updatedAt(a), ub = updatedAt(b)
            if isNewer(ub, than: ua) { return b }
            if isNewer(ua, than: ub) { return a }
            return a == b ? a : deterministicTieBreak(a, b)
        }

        // 레시피: 로컬 순서를 기준으로, 원격에만 있는 항목은 뒤에 붙인다
        var recipeMap: [String: Recipe] = [:]
        var recipeOrder: [String] = []
        for r in local.recipes + remote.recipes {
            if let existing = recipeMap[r.id] {
                recipeMap[r.id] = pickNewer(existing, r, updatedAt: \.updatedAt)
            } else {
                recipeMap[r.id] = r
                recipeOrder.append(r.id)
            }
        }

        var logMap: [String: BakeLog] = [:]
        var logOrder: [String] = []
        for l in local.logs + remote.logs {
            if let existing = logMap[l.id] {
                logMap[l.id] = pickNewer(existing, l, updatedAt: \.updatedAt)
            } else {
                logMap[l.id] = l
                logOrder.append(l.id)
            }
        }

        // 묘비 적용 — 삭제 뒤에 편집된 항목은 살린다
        func isDeleted(id: String, updatedAt: String) -> Bool {
            guard let t = tombstones[id] else { return false }
            return !isNewer(updatedAt, than: t.deletedAt)
        }
        let recipes = recipeOrder.compactMap { recipeMap[$0] }
            .filter { !isDeleted(id: $0.id, updatedAt: $0.updatedAt) }
        let survivingRecipeIDs = Set(recipes.map(\.id))
        // 로그는 소속 레시피가 살아 있을 때만 의미가 있다
        let logs = logOrder.compactMap { logMap[$0] }
            .filter { !isDeleted(id: $0.id, updatedAt: $0.updatedAt) }
            .filter { survivingRecipeIDs.contains($0.recipeId) }

        // 살아남은 항목(편집이 이긴 경우)의 묘비는 더 이상 유효하지 않으므로 버린다
        let liveIDs = survivingRecipeIDs.union(logs.map(\.id))
        let deleted = tombstones.values
            .filter { !liveIDs.contains($0.id) }
            .sorted { $0.id < $1.id }

        // 원격의 더 큰 번호를 이어받지 않는다 — 이 버전이 읽지 못한 항목이 빠진 결과를
        // 새 형식의 온전한 문서로 표시하면 안 된다
        return canonical(
            LibraryDocument(
                schemaVersion: LibraryDocument.currentSchemaVersion,
                recipes: recipes, logs: logs, deleted: deleted))
    }

    /// 삭제 묘비 시각 — 지금 시각과 '항목 updatedAt + 1초' 중 늦은 쪽.
    /// 다른 기기 시계가 앞서 있어 항목이 미래 시각을 갖더라도 묘비가 반드시 이기게 한다.
    public static func tombstoneTime(for updatedAt: String, now: Date = Date()) -> String {
        let itemPlus = (parseISO(updatedAt) ?? .distantPast).addingTimeInterval(1)
        return isoString(from: max(now, itemPlus))
    }

    /// 편집 시각 — 지금 시각과 '바꾸는 판의 updatedAt + 1초' 중 늦은 쪽.
    /// 시계가 앞선 기기가 남긴 미래 시각의 판을 고쳐도 새 편집이 병합에서 이기게 한다 (tombstoneTime과 같은 방어).
    public static func editTime(replacing previous: String?, now: Date = Date()) -> String {
        guard let p = previous.flatMap(parseISO) else { return isoString(from: now) }
        return isoString(from: max(now, p.addingTimeInterval(1)))
    }

    /// 묘비가 있는 id를 다시 저장할 때(백업 복원, 삭제 직후 재저장)의 updatedAt.
    /// 묘비보다 최신이 아니면 다음 병합에서 다시 지워지므로 묘비 뒤로 민다.
    /// 지금 시각이 아니라 tombstoneTime을 쓴다 — 삭제와 같은 초이거나 묘비가 미래 시각이어도 이겨야 한다.
    public static func revivedUpdatedAt(
        _ updatedAt: String, over tombstone: Tombstone?, now: Date = Date()
    ) -> String {
        guard let tombstone, !isNewer(updatedAt, than: tombstone.deletedAt) else { return updatedAt }
        return tombstoneTime(for: tombstone.deletedAt, now: now)
    }

    // MARK: 저장본 — 내용이 같은 저장은 변이가 아니다
    // 내용 그대로 updatedAt만 올리면, 아직 동기화되지 않은 이 기기의 낡은 사본이
    // 다른 기기의 더 새 편집을 병합에서 이긴다. 그래서 바뀐 게 없으면 nil을 돌려준다.

    /// 레시피 저장본. touch: false(백업 가져오기)면 가져온 updatedAt을 그대로 쓴다.
    /// 묘비가 있는 id는 묘비 뒤로 민다 (revivedUpdatedAt).
    public static func savedRecipe(
        _ recipe: Recipe, replacing existing: Recipe?, tombstone: Tombstone?,
        touch: Bool = true, now: Date = Date()
    ) -> Recipe? {
        if let existing, tombstone == nil, sameContent(existing, recipe) { return nil }
        var updated = recipe
        if let existing { updated.createdAt = existing.createdAt }
        if touch { updated.updatedAt = editTime(replacing: existing?.updatedAt, now: now) }
        updated.updatedAt = revivedUpdatedAt(updated.updatedAt, over: tombstone, now: now)
        return updated
    }

    /// 노트 편집본 — 빈 노트는 nil로 저장한다. 앞뒤 공백만 다르면 그대로 둔다
    /// (편집 시트는 잘라서 넘기지만 저장 시트·가져오기는 공백을 남긴 채 저장한다).
    public static func notedRecipe(_ recipe: Recipe, note: String?, now: Date = Date()) -> Recipe? {
        let normalized = (note?.isEmpty ?? true) ? nil : note
        func trimmed(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        guard trimmed(recipe.note) != trimmed(normalized) else { return nil }
        var updated = recipe
        updated.note = normalized
        updated.updatedAt = editTime(replacing: recipe.updatedAt, now: now)
        return updated
    }

    /// 베이킹 로그 저장본 — 비교 대상은 날짜·별점·메모·소속 레시피.
    public static func savedLog(
        _ log: BakeLog, replacing existing: BakeLog?, tombstone: Tombstone?, now: Date = Date()
    ) -> BakeLog? {
        if let existing, tombstone == nil,
            existing.bakedAt == log.bakedAt, existing.rating == log.rating,
            existing.note == log.note, existing.recipeId == log.recipeId
        {
            return nil
        }
        var updated = log
        if let existing { updated.createdAt = existing.createdAt }
        updated.updatedAt = revivedUpdatedAt(
            editTime(replacing: existing?.updatedAt, now: now), over: tombstone, now: now)
        return updated
    }

    /// 타임스탬프를 뺀 내용이 같은가
    static func sameContent(_ a: Recipe, _ b: Recipe) -> Bool {
        var b = b
        b.createdAt = a.createdAt
        b.updatedAt = a.updatedAt
        return a == b
    }

    /// JSON 가져오기에서 실제로 저장할 레시피 (파일 순서 유지) — 같은 id가 파일에 여럿이면 첫 항목만.
    /// 기기에 같은 id가 있으면 가져온 판이 더 최신이고 내용도 다를 때만 받는다 — iCloud 병합과 같은 규칙이라
    /// 동기화를 켜든 끄든 결과가 같다. 묘비만 남은 id는 복원으로 받는다 (저장 시 묘비 뒤로 밀린다).
    /// '더 최신'은 웹 mergeImported와 같은 문법으로 판정한다(isNewerOnWeb) — 병합과는 두 앱이 쓰지 않는
    /// 형식(밀리초 아래 자릿수, 소문자 z, 한 자리 월·일 등)에서만 갈린다.
    public static func importable(
        _ imported: [Recipe], local: [Recipe]
    ) -> (accepted: [Recipe], skipped: Int) {
        let localByID = Dictionary(local.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var seen = Set<String>()
        var accepted: [Recipe] = []
        for r in imported where seen.insert(r.id).inserted {
            if let l = localByID[r.id],
                !isNewerOnWeb(r.updatedAt, than: l.updatedAt) || sameContent(l, r)
            {
                continue
            }
            accepted.append(r)
        }
        return (accepted, imported.count - accepted.count)
    }

    // MARK: 인코딩 / 관용 디코딩

    public static func encode(_ doc: LibraryDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(doc)
    }

    /// 항목별 검증 — 불량 항목만 건너뛴다. 옛 형식(레시피 배열만)도 읽는다.
    public static func decode(_ data: Data) -> LibraryDocument {
        decodeReport(data).document
    }

    /// decode + 새 버전 앱이 쓴 형식이 섞였는지 (문서 또는 레시피의 schemaVersion이 이 버전보다 큼).
    /// isNewerFormat이면 이 버전은 그 항목·필드를 읽지 못해 버리므로, 호출 측은 그 문서를 로컬에 합쳐서도
    /// 덮어써서도 안 된다 — 필드가 빠진 사본이 원격과 같은 updatedAt으로 로컬에 남으면, 앱을 업데이트한 뒤
    /// 병합 동률에서 그 사본이 이겨 원격의 필드를 지운다.
    public static func decodeReport(_ data: Data) -> (document: LibraryDocument, isNewerFormat: Bool) {
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return (LibraryDocument(), false)
        }
        func hasNewerRecipe(_ items: [Any]) -> Bool {
            items.contains { item in
                let v = ((item as? [String: Any])?["schemaVersion"] as? NSNumber)?.intValue ?? 0
                return v > Recipe.currentSchemaVersion
            }
        }
        // 옛 recipes.json: 레시피 배열
        if let arr = parsed as? [Any] {
            return (canonical(LibraryDocument(recipes: salvage(arr))), hasNewerRecipe(arr))
        }
        guard let obj = parsed as? [String: Any] else { return (LibraryDocument(), false) }
        let recipeItems = obj["recipes"] as? [Any] ?? []
        let recipes = salvage(recipeItems)
        let decoder = JSONDecoder()
        let logs: [BakeLog] = (obj["logs"] as? [Any] ?? []).compactMap { item in
            guard let d = try? JSONSerialization.data(withJSONObject: item),
                let log = try? decoder.decode(BakeLog.self, from: d),
                log.rating.map({ (1...5).contains($0) }) ?? true
            else { return nil }
            return log
        }
        let deleted: [Tombstone] = (obj["deleted"] as? [Any] ?? []).compactMap { item in
            guard let d = try? JSONSerialization.data(withJSONObject: item) else { return nil }
            return try? decoder.decode(Tombstone.self, from: d)
        }
        let version = (obj["schemaVersion"] as? NSNumber)?.intValue
            ?? LibraryDocument.currentSchemaVersion
        let doc = canonical(
            LibraryDocument(schemaVersion: version, recipes: recipes, logs: logs, deleted: deleted))
        return (doc, version > LibraryDocument.currentSchemaVersion || hasNewerRecipe(recipeItems))
    }

    /// 원본 데이터의 레시피·로그 중 decode가 검증 실패로 버린 개수.
    /// 0보다 크면 다음 저장이 그 항목을 영구히 덮어쓰므로, 호출 측이 원본을 따로 보관해야 한다.
    public static func droppedItemCount(in data: Data, decoded: LibraryDocument) -> Int {
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else { return 0 }
        let raw: Int
        if let arr = parsed as? [Any] {
            raw = arr.count
        } else if let obj = parsed as? [String: Any] {
            // 키가 있는데 배열이 아니면 통째로 버려진 것으로 센다
            func count(_ key: String) -> Int {
                guard let v = obj[key] else { return 0 }
                return (v as? [Any])?.count ?? 1
            }
            raw = count("recipes") + count("logs")
        } else {
            return 0
        }
        return max(0, raw - decoded.recipes.count - decoded.logs.count)
    }

    private static func salvage(_ items: [Any]) -> [Recipe] {
        items.compactMap { item in
            if case .ok(let r) = RecipeCodec.validate(item) { return r }
            return nil
        }
    }
}
