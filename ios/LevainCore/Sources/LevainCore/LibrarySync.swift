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

    /// a가 b보다 최신이면 true (파싱 실패 시 문자열 비교)
    public static func isNewer(_ a: String, than b: String) -> Bool {
        if let da = parseISO(a), let db = parseISO(b) { return da > db }
        return a > b
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

        return canonical(
            LibraryDocument(
                schemaVersion: max(local.schemaVersion, remote.schemaVersion),
                recipes: recipes, logs: logs, deleted: deleted))
    }

    /// 삭제 묘비 시각 — 지금 시각과 '항목 updatedAt + 1초' 중 늦은 쪽.
    /// 다른 기기 시계가 앞서 있어 항목이 미래 시각을 갖더라도 묘비가 반드시 이기게 한다.
    public static func tombstoneTime(for updatedAt: String, now: Date = Date()) -> String {
        let itemPlus = (parseISO(updatedAt) ?? .distantPast).addingTimeInterval(1)
        return isoString(from: max(now, itemPlus))
    }

    // MARK: 인코딩 / 관용 디코딩

    public static func encode(_ doc: LibraryDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(doc)
    }

    /// 항목별 검증 — 불량 항목만 건너뛴다. 옛 형식(레시피 배열만)도 읽는다.
    public static func decode(_ data: Data) -> LibraryDocument {
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return LibraryDocument()
        }
        // 옛 recipes.json: 레시피 배열
        if let arr = parsed as? [Any] {
            return canonical(LibraryDocument(recipes: salvage(arr)))
        }
        guard let obj = parsed as? [String: Any] else { return LibraryDocument() }
        let recipes = salvage(obj["recipes"] as? [Any] ?? [])
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
        return canonical(
            LibraryDocument(schemaVersion: version, recipes: recipes, logs: logs, deleted: deleted))
    }

    private static func salvage(_ items: [Any]) -> [Recipe] {
        items.compactMap { item in
            if case .ok(let r) = RecipeCodec.validate(item) { return r }
            return nil
        }
    }
}
