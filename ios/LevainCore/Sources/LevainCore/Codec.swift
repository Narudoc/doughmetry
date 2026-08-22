import Foundation

/// 레시피 JSON 검증·가져오기·내보내기 — 웹앱(src/lib/storage.ts)과 호환.
/// v1 레시피는 가져오기 시 v2로 자동 마이그레이션 (bassinage 0, liquids [], yeast 0).

public enum RecipeCodec {
    // MARK: 검증 (validateRecipe 이식)

    public enum ValidationResult {
        case ok(Recipe)
        case bad(CodecError)
    }

    static func nonNegNumber(_ x: Any?) -> Double? {
        let d: Double?
        switch x {
        case let n as Double: d = n
        case let n as Int: d = Double(n)
        case let n as NSNumber: d = n.doubleValue
        default: d = nil
        }
        guard let d, d.isFinite, d >= 0 else { return nil }
        return d
    }

    static func parseRows(_ x: Any?, field: String) -> Result<[Flour], CodecError> {
        guard let x else { return .success([]) }
        guard let arr = x as? [Any] else { return .failure(CodecError(.fieldNotArray(field: field))) }
        var rows: [Flour] = []
        for (i, item) in arr.enumerated() {
            guard let row = item as? [String: Any] else {
                return .failure(CodecError(.rowNotObject(field: field, index: i)))
            }
            guard let grams = nonNegNumber(row["grams"]) else {
                return .failure(CodecError(.rowGramsInvalid(field: field, index: i)))
            }
            let id = (row["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? newId()
            rows.append(Flour(id: id, name: row["name"] as? String ?? "", grams: grams))
        }
        return .success(rows)
    }

    static func parseLiquids(_ x: Any?) -> Result<[Liquid], CodecError> {
        guard let x else { return .success([]) }
        guard let arr = x as? [Any] else { return .failure(CodecError(.fieldNotArray(field: "liquids"))) }
        var rows: [Liquid] = []
        for (i, item) in arr.enumerated() {
            guard let row = item as? [String: Any] else {
                return .failure(CodecError(.rowNotObject(field: "liquids", index: i)))
            }
            guard let grams = nonNegNumber(row["grams"]) else {
                return .failure(CodecError(.rowGramsInvalid(field: "liquids", index: i)))
            }
            guard let ratio = nonNegNumber(row["waterRatio"]), ratio <= 1 else {
                return .failure(CodecError(.waterRatioInvalid(index: i)))
            }
            let id = (row["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? newId()
            rows.append(
                Liquid(id: id, name: row["name"] as? String ?? "", grams: grams, waterRatio: ratio))
        }
        return .success(rows)
    }

    static func parseYeast(_ x: Any?) -> Result<Yeast, CodecError> {
        guard let x else { return .success(Yeast()) }
        guard let y = x as? [String: Any] else { return .failure(CodecError(.yeastNotObject)) }
        guard let grams = nonNegNumber(y["grams"]) else {
            return .failure(CodecError(.yeastGramsInvalid))
        }
        return .success(Yeast(type: y["type"] as? String == "instant" ? .instant : .fresh, grams: grams))
    }

    public static func validate(_ x: Any) -> ValidationResult {
        guard let r = x as? [String: Any] else { return .bad(CodecError(.notAnObject)) }

        // v1 레시피는 v2로 마이그레이션
        let version = (r["schemaVersion"] as? NSNumber)?.intValue
        guard version == 1 || version == 2 else {
            return .bad(CodecError(.unsupportedSchemaVersion))
        }
        guard let name = r["name"] as? String,
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .bad(CodecError(.emptyName)) }

        let flours: [Flour]
        switch parseRows(r["flours"], field: "flours") {
        case .failure(let e): return .bad(e)
        case .success(let v): flours = v
        }
        let extras: [Flour]
        switch parseRows(r["extras"], field: "extras") {
        case .failure(let e): return .bad(e)
        case .success(let v): extras = v
        }
        let liquids: [Liquid]
        switch parseLiquids(r["liquids"]) {
        case .failure(let e): return .bad(e)
        case .success(let v): liquids = v
        }
        let yeast: Yeast
        switch parseYeast(r["yeast"]) {
        case .failure(let e): return .bad(e)
        case .success(let v): yeast = v
        }

        guard let water = nonNegNumber(r["water"]) else {
            return .bad(CodecError(.waterInvalid))
        }
        let bassinage: Double
        if r["bassinage"] == nil {
            bassinage = 0
        } else if let b = nonNegNumber(r["bassinage"]) {
            bassinage = b
        } else {
            return .bad(CodecError(.bassinageInvalid))
        }
        guard let salt = nonNegNumber(r["salt"]) else {
            return .bad(CodecError(.saltInvalid))
        }

        guard let lev = r["levain"] as? [String: Any] else { return .bad(CodecError(.levainMissing)) }
        guard let levGrams = nonNegNumber(lev["grams"]) else {
            return .bad(CodecError(.levainGramsInvalid))
        }
        guard let hydration = (lev["hydration"] as? NSNumber)?.doubleValue,
            hydration.isFinite, hydration > 0
        else { return .bad(CodecError(.levainHydrationInvalid)) }

        let tags = (r["tags"] as? [Any])?.compactMap { $0 as? String }
        let levType: LevainType =
            (lev["type"] as? String).flatMap { LevainType(rawValue: $0) }
            ?? levainTypeFor(hydration: hydration)

        let input = DoughInput(
            flours: flours,
            water: water,
            bassinage: bassinage,
            salt: salt,
            levain: Levain(
                type: levType, hydration: hydration, grams: levGrams,
                flourName: lev["flourName"] as? String),
            liquids: liquids,
            yeast: yeast,
            extras: extras.map { Extra(id: $0.id, name: $0.name, grams: $0.grams) }
        )
        let recipe = Recipe(
            id: (r["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? newId(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: r["note"] as? String,
            tags: (tags?.isEmpty ?? true) ? nil : tags,
            createdAt: r["createdAt"] as? String ?? isoNow(),
            updatedAt: r["updatedAt"] as? String ?? isoNow(),
            input: input,
            targetDoughWeight: nonNegNumber(r["targetDoughWeight"]),
            pieces: nonNegNumber(r["pieces"])
        )
        return .ok(recipe)
    }

    // MARK: 내보내기 / 가져오기 (웹 exportJson / importJson과 호환)

    public static func exportJSON(_ recipes: [Recipe]) throws -> String {
        struct Export: Codable {
            var app: String
            var schemaVersion: Int
            var exportedAt: String
            var recipes: [Recipe]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(
            Export(app: "levain-calc", schemaVersion: 2, exportedAt: isoNow(), recipes: recipes))
        return String(decoding: data, as: UTF8.self)
    }

    public static func importJSON(_ text: String) -> Result<[Recipe], CodecError> {
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: Data(text.utf8))
        } catch {
            return .failure(CodecError(.jsonParse(detail: error.localizedDescription)))
        }

        let items: [Any]
        if let arr = parsed as? [Any] {
            items = arr
        } else if let obj = parsed as? [String: Any], obj["recipes"] != nil {
            guard let rs = obj["recipes"] as? [Any] else {
                return .failure(CodecError(.recipesFieldNotArray))
            }
            items = rs
        } else if parsed is [String: Any] {
            items = [parsed] // 단일 레시피 객체
        } else {
            return .failure(CodecError(.noRecipeList))
        }

        if items.isEmpty { return .failure(CodecError(.emptyImport)) }

        var recipes: [Recipe] = []
        for (i, item) in items.enumerated() {
            switch validate(item) {
            case .bad(let reason): return .failure(CodecError(.recipeAt(index: i + 1, error: reason)))
            case .ok(let r): recipes.append(r)
            }
        }
        return .success(recipes)
    }
}
