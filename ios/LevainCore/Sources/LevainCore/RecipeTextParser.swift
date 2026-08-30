import Foundation

/// 레시피 텍스트 → 배합 규칙 기반 파서.
/// Apple Intelligence를 쓸 수 없는 기기의 폴백이자, OCR 결과의 1차 해석기.
/// 키워드는 한국어·영어·프랑스어 제빵 용어를 커버한다.
///
/// 처리 순서: 머리 기호 제거 → SNS 토큰 제거 → 온도 표기 제거 → 구분자 분할
/// → 섹션 인식(르방 빌드/본반죽/공정) → 재료 분류.

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
    static let rx = String.CompareOptions.regularExpression

    // MARK: 토큰

    /// 줄 단위 숫자 토큰: (값, %) 여부.
    /// "T65"처럼 영문자에 붙은 숫자는 양이 아니므로 제외 — 경계 문자를 함께 매칭한다.
    /// 단위: % 는 수분율, kg/키로 는 g로 환산(×1000)
    static func numberTokens(in line: String) -> [(value: Double, isPercent: Bool)] {
        var tokens: [(Double, Bool)] = []
        let pattern = /(?:^|[^A-Za-z0-9])([0-9]+(?:,[0-9]{3})*(?:[.,][0-9]+)?)[ \t]*(%|[kK][gG]|㎏|키로|킬로)?/
        for match in line.matches(of: pattern) {
            var raw = String(match.1)
            // 천 단위 쉼표 제거 (쉼표 뒤 3자리), 남은 쉼표는 소수점으로
            while let r = raw.range(of: #",(?=[0-9]{3}(\D|$))"#, options: rx) {
                raw.removeSubrange(r)
            }
            raw = raw.replacingOccurrences(of: ",", with: ".")
            guard var v = Double(raw) else { continue }
            let unit = match.2.map(String.init)?.lowercased()
            if let unit, unit != "%" { v *= 1000 }  // kg 계열
            tokens.append((v, unit == "%"))
        }
        return tokens
    }

    static func contains(_ line: String, _ keywords: [String]) -> Bool {
        keywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    static func containsWord(_ line: String, _ word: String) -> Bool {
        line.range(of: "(?i)\\b\(word)\\b", options: rx) != nil
    }

    static func matchesFlour(_ line: String) -> Bool {
        if line.range(of: #"(?i)\bt[0-9]{2,3}\b"#, options: rx) != nil {
            return true  // T45/T65/T110 …
        }
        return contains(line, [
            "밀가루", "가루", "강력", "중력", "박력", "호밀", "통밀", "스펠트", "세몰리나", "듀럼",
            "트레디션", "flour", "farine", "rye", "wheat", "spelt", "semolina", "durum",
            "tradition", "grau", "메밀", "옥수수가루",
        ])
    }

    static let levainKeywords = [
        "르방", "levain", "스타터", "starter", "발효종", "사전반죽", "풀리시", "poolish", "biga",
    ]

    static func matchesLevain(_ line: String) -> Bool {
        contains(line, levainKeywords) || containsWord(line, "ferment")
    }

    // MARK: 전처리

    /// SNS 표기 제거 — @멘션은 재료 이름이 아니고, #해시태그는 잡음이다
    static func stripSocialTokens(_ line: String) -> String {
        var s = line
        s = s.replacingOccurrences(of: #"@[A-Za-z0-9_.]+"#, with: "", options: rx)
        s = s.replacingOccurrences(of: #"#\S+"#, with: "", options: rx)
        return s
    }

    /// 파싱 전 전체 텍스트 정리 — AI 경로도 같은 전처리를 쓰도록 공개
    public static func cleanForParsing(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { stripSocialTokens($0) }
            .joined(separator: "\n")
    }

    /// 온도 표기 제거 — "물 350g (30°C)"·"물 350g 30도" 같은 줄이 오염되지 않도록
    /// 괄호 안 온도와 "30°C"/"30℃"/"30도" 토큰을 걷어낸다
    /// ("도" 뒤에 글자가 이어지면(포도·도우 등) 매칭하지 않는다)
    static func stripTemperatures(_ line: String) -> String {
        var s = line
        s = s.replacingOccurrences(
            of: #"\([^)]*(?:°|℃|온도|[0-9][ \t]*도)[^)]*\)"#, with: "", options: rx)
        s = s.replacingOccurrences(
            of: #"[0-9]+(?:[.,][0-9]+)?[ \t]*(?:°[CcFf]?|℃|도씨?(?![가-힣A-Za-z]))"#,
            with: "", options: rx)
        return s
    }

    /// 한 줄에 여러 재료를 쓰는 표기("강력분 500 / 물 350 / 소금 10") 분할.
    /// 그램 수량을 가진 조각이 2개 이상일 때만 분할을 채택한다 —
    /// "밀가루(강력/T65) 500g" 같은 줄은 그대로 둔다. 분수(1/2)의 /는 구분자가 아니다.
    static func splitSegments(_ line: String) -> [String] {
        var work = line.replacingOccurrences(of: #",(?=\s)"#, with: "⎮", options: rx)
        work = work.replacingOccurrences(of: #"(?<![0-9])/|/(?![0-9])"#, with: "⎮", options: rx)
        for sep in ["|", "·", "•", ";"] {
            work = work.replacingOccurrences(of: sep, with: "⎮")
        }
        let parts = work.components(separatedBy: "⎮")
        guard parts.count > 1 else { return [line] }
        let numeric = parts.filter { p in numberTokens(in: p).contains { !$0.isPercent } }
        return numeric.count >= 2 ? parts : [line]
    }

    /// 재료가 아닌 줄 (헤더·합계 등).
    /// 수분율/hydration/온도는 그램 수량이 함께 있으면 재료 줄이므로 거르지 않는다.
    static func shouldSkip(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return true }
        if contains(t, ["합계", "총계", "총 ", "total", "재 료", "베이커", "baker"]) {
            return true
        }
        if contains(t, ["수분율", "hydration", "온도"]),
            !numberTokens(in: t).contains(where: { !$0.isPercent })
        {
            return true  // "수분율 75%" 같은 통계·표기 줄
        }
        // "물 340g에 르방을 풀어주세요" 같은 서술문
        if t.range(of: #"(하세요|해주세요|주세요|합니다|해 주세요)"#, options: rx) != nil {
            return true
        }
        // "양 (g)" / "g" 같은 표 헤더
        if t.range(of: #"^(재\s*료|양|무게|amount|quantity|ingr)[^0-9]*$"#, options: [rx, .caseInsensitive]) != nil {
            return true
        }
        return false
    }

    /// 숫자·단위를 걷어낸 재료 이름
    static func ingredientName(from line: String) -> String {
        var s = line
        s = s.replacingOccurrences(
            of: #"(?<![A-Za-z0-9])[0-9]+(?:[.,][0-9]+)?[ \t]*(?:%|g\b|그램|kg\b|㎏|키로|킬로)?"#,
            with: "", options: [rx, .caseInsensitive])
        s = s.replacingOccurrences(of: #"\([ \t]*\)"#, with: "", options: rx)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t:·.-—|"))
        return s
    }

    /// 제목 후보에서 "G." "1)" 같은 머리 기호 제거
    static func cleanTitle(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: #"^[A-Za-z0-9]{1,3}[.)][ \t]*"#, with: "", options: rx)
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: 섹션 헤더

    /// 르방 빌드 섹션 헤더 — "르방 만들기", "스타터 리프레시" 등 (숫자 없는 줄)
    static func isLevainBuildHeader(_ line: String) -> Bool {
        matchesLevain(line)
            && contains(line, ["만들기", "만드는", "빌드", "build", "리프레시", "refresh", "키우기", "밥주기", "먹이주기"])
    }

    /// 본반죽 섹션 헤더
    static func isMainDoughHeader(_ line: String) -> Bool {
        contains(line, ["본반죽", "본 반죽", "최종반죽", "최종 반죽", "main dough", "final dough"])
    }

    /// 공정(만드는 법) 섹션 헤더 — 이후 줄은 서술부로 보고 파싱을 멈춘다
    static func isMethodHeader(_ line: String) -> Bool {
        !matchesLevain(line)
            && contains(line, ["만드는 법", "만드는법", "만들기", "공정", "과정", "method", "instruction", "direction", "préparation"])
    }

    // MARK: 파싱

    public static func parse(_ text: String) -> ParsedRecipeText {
        var name: String?
        var flours: [Flour] = []
        var water = 0.0
        var bassinage = 0.0
        var salt = 0.0
        var levainGrams = 0.0
        var levainHydration = 1.0
        var levainHydrationExplicit = false
        var levainName: String?
        var liquids: [Liquid] = []
        var yeast = Yeast()
        var extras: [Extra] = []
        var matched = 0

        // 섹션 상태 — 르방 빌드 섹션 재료는 본반죽에 합산하지 않는다
        enum Section { case main, levainBuild, stopped }
        var section = Section.main
        var buildFlour = 0.0
        var buildWater = 0.0
        var buildTotal = 0.0

        // 전처리 + 구분자 분할
        var segments: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            // "G." "1)" 같은 머리 기호를 먼저 떼야 헤더("1. 재료")를 제대로 거른다
            let line = stripTemperatures(stripSocialTokens(cleanTitle(rawLine)))
            segments.append(contentsOf: splitSegments(line))
        }

        for segment in segments {
            let line = segment.trimmingCharacters(in: .whitespaces)
            if section == .stopped { continue }
            if shouldSkip(line) { continue }

            // 괄호 안 부연("500g (강력 400 + 통밀 100)")이 그램을 가리지 않도록,
            // 그램은 괄호를 뗀 텍스트에서 먼저 찾고 없으면 전체에서 찾는다.
            // %는 괄호 안("(수분율 100%)")에도 오므로 전체에서 찾는다.
            let parenStripped = line.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: rx)
            let fullTokens = numberTokens(in: line)
            let strippedTokens = numberTokens(in: parenStripped)
            let grams = (strippedTokens.last(where: { !$0.isPercent })
                ?? fullTokens.last(where: { !$0.isPercent }))?.value
            let percent = fullTokens.first(where: { $0.isPercent })?.value

            guard let grams, grams > 0 else {
                // 숫자 없는 줄: 섹션 헤더 또는 제목 후보
                if isLevainBuildHeader(line) {
                    section = .levainBuild
                } else if isMainDoughHeader(line) {
                    section = .main
                } else if matched >= 2, isMethodHeader(line) {
                    section = .stopped
                } else if name == nil, fullTokens.isEmpty, section == .main {
                    let t = cleanTitle(line)
                    if t.count >= 2 { name = t }
                }
                continue
            }

            matched += 1

            // 르방 빌드 섹션: 밀가루/물 비율로 수분율을 추정하고 총량만 기억한다
            if section == .levainBuild {
                buildTotal += grams
                if matchesLevain(line) {
                    // 종(chef) — 총량에만 반영
                } else if contains(line, ["물", "water", "eau"]) {
                    buildWater += grams
                } else if matchesFlour(line) {
                    buildFlour += grams
                }
                continue
            }

            if contains(line, ["바시나주", "바시나쥬", "bassinage", "조절수", "조정수"]) {
                bassinage += grams
            } else if matchesLevain(line) {
                levainGrams += grams
                levainName = ingredientName(from: line)
                if contains(line, ["리퀴드", "liquide", "liquid"]) {
                    levainHydration = 1.0
                    levainHydrationExplicit = true
                } else if contains(line, ["뒤흐", "dur", "스티프", "stiff"]) {
                    levainHydration = 0.5
                    levainHydrationExplicit = true
                } else if let percent, percent > 0 {
                    levainHydration = percent / 100
                    levainHydrationExplicit = true
                }
            } else if contains(line, ["소금", "salt", "sel", "천일염", "소곰"]) {
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
                || containsWord(line, "eau")
            {
                water += grams
            } else if matchesFlour(line) {
                flours.append(Flour(name: ingredientName(from: line), grams: grams))
            } else {
                extras.append(Extra(name: ingredientName(from: line), grams: grams))
            }
        }

        // 르방 빌드 섹션 정산:
        // 본반죽에 르방 g가 명시돼 있으면 빌드 재료는 그 내역이므로 버리고,
        // 없으면 빌드 총량이 곧 르방이다. 수분율은 빌드의 물/밀가루 비로 추정.
        if buildTotal > 0 {
            if levainGrams == 0 { levainGrams = buildTotal }
            if !levainHydrationExplicit, buildFlour > 0 {
                let h = buildWater / buildFlour
                if h >= 0.3, h <= 1.5 { levainHydration = h }
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
