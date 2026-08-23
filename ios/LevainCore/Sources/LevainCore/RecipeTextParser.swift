import Foundation

/// 레시피 텍스트 → 배합 규칙 기반 파서.
/// Apple Intelligence를 쓸 수 없는 기기의 폴백이자, OCR 결과의 1차 해석기.
/// 키워드는 한국어·영어·프랑스어 제빵 용어를 커버한다.

public struct ParsedRecipeText: Equatable, Sendable {
    public var name: String?
    public var input: DoughInput
    /// 재료로 인식된 줄 수 — 0이면 인식 실패로 판단
    public var matchedLineCount: Int

    public init(name: String?, input: DoughInput, matchedLineCount: Int) {
        self.name = name
        self.input = input
        self.matchedLineCount = matchedLineCount
    }
}

public enum RecipeTextParser {
    /// 줄 단위 숫자 토큰: (값, %) 여부
    static func numberTokens(in line: String) -> [(value: Double, isPercent: Bool)] {
        // "T65"처럼 영문자에 붙은 숫자는 양이 아니므로 제외 — 경계 문자를 함께 매칭한다
        var tokens: [(Double, Bool)] = []
        let pattern = /(?:^|[^A-Za-z0-9])([0-9]+(?:,[0-9]{3})*(?:[.,][0-9]+)?)[ \t]*(%)?/
        for match in line.matches(of: pattern) {
            var raw = String(match.1)
            // 천 단위 쉼표 제거 (쉼표 뒤 3자리), 남은 쉼표는 소수점으로
            while let r = raw.range(of: #",(?=[0-9]{3}(\D|$))"#, options: String.CompareOptions.regularExpression) {
                raw.removeSubrange(r)
            }
            raw = raw.replacingOccurrences(of: ",", with: ".")
            guard let v = Double(raw) else { continue }
            tokens.append((v, match.2 != nil))
        }
        return tokens
    }

    static func contains(_ line: String, _ keywords: [String]) -> Bool {
        keywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    static func matchesFlour(_ line: String) -> Bool {
        if line.range(of: #"(?i)\bt[0-9]{2,3}\b"#, options: String.CompareOptions.regularExpression) != nil {
            return true  // T45/T65/T110 …
        }
        return contains(line, [
            "밀가루", "가루", "강력", "중력", "박력", "호밀", "통밀", "스펠트", "세몰리나", "듀럼",
            "트레디션", "flour", "farine", "rye", "wheat", "spelt", "semolina", "durum",
            "tradition", "grau", "메밀", "옥수수가루",
        ])
    }

    /// 재료가 아닌 줄 (헤더·합계·비율 표기 등)
    static func shouldSkip(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return true }
        if contains(t, ["합계", "총계", "총 ", "total", "재 료", "베이커", "baker", "수분율", "hydration", "온도"]) {
            return true
        }
        // "양 (g)" / "g" 같은 표 헤더
        if t.range(of: #"^(재\s*료|양|무게|amount|quantity|ingr)[^0-9]*$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return false
    }

    /// 온도 표기 제거 — "물 350g (30°C)" 같은 줄이 통째로 버려지지 않도록
    /// 괄호 안 온도와 "30°C"/"30℃" 토큰만 걷어낸다
    static func stripTemperatures(_ line: String) -> String {
        var s = line
        s = s.replacingOccurrences(
            of: #"\([^)]*(?:°|℃|온도)[^)]*\)"#,
            with: "", options: String.CompareOptions.regularExpression)
        s = s.replacingOccurrences(
            of: #"[0-9]+(?:[.,][0-9]+)?[ \t]*(?:°[CcFf]?|℃)"#,
            with: "", options: String.CompareOptions.regularExpression)
        return s
    }

    /// 숫자·단위를 걷어낸 재료 이름
    static func ingredientName(from line: String) -> String {
        var s = line
        s = s.replacingOccurrences(
            of: #"(?<![A-Za-z0-9])[0-9]+(?:[.,][0-9]+)?[ \t]*(?:%|g\b|그램|kg\b)?"#,
            with: "", options: [.regularExpression, .caseInsensitive])
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t:·.-—|"))
        return s
    }

    /// 제목 후보에서 "G." "1)" 같은 머리 기호 제거
    static func cleanTitle(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(
            of: #"^[A-Za-z0-9]{1,3}[.)][ \t]*"#, with: "", options: String.CompareOptions.regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    public static func parse(_ text: String) -> ParsedRecipeText {
        var name: String?
        var flours: [Flour] = []
        var water = 0.0
        var bassinage = 0.0
        var salt = 0.0
        var levainGrams = 0.0
        var levainHydration = 1.0
        var levainName: String?
        var liquids: [Liquid] = []
        var yeast = Yeast()
        var extras: [Extra] = []
        var matched = 0

        for rawLine in text.components(separatedBy: .newlines) {
            // "G." "1)" 같은 머리 기호를 먼저 떼야 헤더("1. 재료")를 제대로 거른다
            let line = stripTemperatures(cleanTitle(rawLine))
            if shouldSkip(line) { continue }

            let tokens = numberTokens(in: line)
            let grams = tokens.last(where: { !$0.isPercent })?.value
            let percent = tokens.first(where: { $0.isPercent })?.value

            guard let grams, grams > 0 else {
                // 숫자 없는 줄: 첫 줄만 제목 후보로
                if name == nil, tokens.isEmpty {
                    let t = cleanTitle(line)
                    if t.count >= 2 { name = t }
                }
                continue
            }

            matched += 1
            if contains(line, ["바시나주", "바시나쥬", "bassinage"]) {
                bassinage += grams
            } else if contains(line, ["르방", "levain", "스타터", "starter", "발효종", "사전반죽", "풀리시", "poolish", "biga"]) {
                levainGrams += grams
                levainName = ingredientName(from: line)
                if contains(line, ["리퀴드", "liquide", "liquid"]) {
                    levainHydration = 1.0
                } else if contains(line, ["뒤흐", "dur", "스티프", "stiff"]) {
                    levainHydration = 0.5
                } else if let percent, percent > 0 {
                    levainHydration = percent / 100
                }
            } else if contains(line, ["소금", "salt", "sel", "천일염"]) {
                salt += grams
            } else if contains(line, ["이스트", "yeast", "levure", "효모"]) {
                yeast.grams += grams
                if contains(line, ["인스턴트", "드라이", "instant", "dry", "sèche"]) {
                    yeast.type = .instant
                }
            } else if contains(line, ["우유", "milk", "lait"]) {
                liquids.append(
                    Liquid(name: ingredientName(from: line), grams: grams,
                           waterRatio: LiquidPreset.milk.waterRatio))
            } else if contains(line, ["계란", "달걀", "전란", "egg", "oeuf", "œuf"]) {
                liquids.append(
                    Liquid(name: ingredientName(from: line), grams: grams,
                           waterRatio: LiquidPreset.egg.waterRatio))
            } else if contains(line, ["물", "water"]) && !contains(line, ["물엿", "시럽", "syrup"])
                || line.range(of: #"(?i)\beau\b"#, options: String.CompareOptions.regularExpression) != nil
            {
                water += grams
            } else if matchesFlour(line) {
                flours.append(Flour(name: ingredientName(from: line), grams: grams))
            } else {
                extras.append(Extra(name: ingredientName(from: line), grams: grams))
            }
        }

        let input = DoughInput(
            flours: flours,
            water: water,
            bassinage: bassinage,
            salt: salt,
            levain: Levain(
                type: levainTypeFor(hydration: levainHydration),
                hydration: levainHydration,
                grams: levainGrams,
                flourName: levainName?.isEmpty == true ? nil : levainName.flatMap {
                    // "르방 리퀴드" 자체는 표시용 이름으로 의미 없음
                    contains($0, ["르방", "levain", "스타터", "starter"]) ? nil : $0
                }),
            liquids: liquids,
            yeast: yeast,
            extras: extras)
        return ParsedRecipeText(name: name, input: input, matchedLineCount: matched)
    }
}
