import Foundation

/// 레시피 텍스트 → 배합 규칙 기반 파서.
/// Apple Intelligence를 쓸 수 없는 기기의 폴백이자, OCR 결과의 1차 해석기.
/// 키워드는 한국어·영어·프랑스어 제빵 용어를 커버한다.
/// 웹(src/lib/recipeParser.ts)과 규칙·테스트를 동일하게 유지할 것.
///
/// 처리 순서: 머리 기호 제거 → SNS 토큰·키캡 번호 제거 → 온도·시간·차수 표기 제거 → 구분자 분할
/// → 섹션 인식(르방 빌드/본반죽/공정) → 재료 분류.

public struct ParsedRecipeText: Equatable, Sendable {
    public var name: String?
    public var input: DoughInput
    /// 재료로 인식된 줄 수 — 0이면 인식 실패로 판단
    public var matchedLineCount: Int
    /// 르방 수분율을 텍스트가 직접 밝혔는지(30~150% 또는 리퀴드/뒤흐 키워드) — 기본값·빌드 섹션 추정은 false
    public var levainHydrationExplicit: Bool

    public init(
        name: String?, input: DoughInput, matchedLineCount: Int, levainHydrationExplicit: Bool = false
    ) {
        self.name = name
        self.input = input
        self.matchedLineCount = matchedLineCount
        self.levainHydrationExplicit = levainHydrationExplicit
    }
}

public enum RecipeTextParser {
    static let rx = String.CompareOptions.regularExpression

    // MARK: 토큰

    /// percent: %, mass: 무게 단위(g로 환산), measure: 컵·스푼·개수(그램이 아님), bare: 단위 없음
    enum NumberKind: Sendable { case percent, mass, measure, bare }

    /// 단위별 분류·g 환산 계수 — 표에 없는 단위(컵·스푼·개수)는 measure
    static let units: [String: (kind: NumberKind, factor: Double)] = [
        "%": (.percent, 1),
        "kg": (.mass, 1000), "㎏": (.mass, 1000), "키로": (.mass, 1000), "킬로": (.mass, 1000),
        "g": (.mass, 1), "gr": (.mass, 1), "gram": (.mass, 1), "grams": (.mass, 1),
        "gramme": (.mass, 1), "grammes": (.mass, 1), "그램": (.mass, 1),
        "ml": (.mass, 1),
        "oz": (.mass, 28.349523125), "ounce": (.mass, 28.349523125), "ounces": (.mass, 28.349523125),
        "lb": (.mass, 453.59237), "lbs": (.mass, 453.59237),
        "pound": (.mass, 453.59237), "pounds": (.mass, 453.59237),
    ]

    static let kgUnits: Set<String> = ["kg", "㎏", "키로", "킬로"]
    static let lbUnits: Set<String> = ["lb", "lbs", "pound", "pounds"]
    static let ozUnits: Set<String> = ["oz", "ounce", "ounces"]

    /// 줄 단위 숫자 토큰.
    /// "T65"처럼 영문자에 붙은 숫자는 양이 아니므로 제외 — 경계 문자를 함께 매칭한다.
    /// 단위: % 는 수분율, kg류·oz·lb 는 g로 환산, 컵·스푼·개수는 그램이 아니다.
    /// 캡처 1: 분수("1/2", "3 3/4") — 두 자리까지만, "350/370g" 같은 범위·두 배합 표기는 분수가 아니다
    /// 캡처 2: 수 — 천 단위 구분은 쉼표·NBSP류 공백, 일반 공백은 무게 단위가 뒤따르고 앞자리가 한 자리일 때만
    ///   ("1 000 g" — "type 65 500 g"·"Farine 100 500 g"의 앞 수는 별개)
    /// 캡처 3: 단위 — 단어 중간("500g을", "gâteau")은 단위가 아니다
    static func numberTokens(in line: String) -> [(value: Double, kind: NumberKind)] {
        var tokens: [(Double, NumberKind)] = []
        let pattern = #/(?:^|[^A-Za-z0-9])(?:((?:[0-9]+[ \t]+)?[0-9]{1,2}/[0-9]{1,2}(?![0-9]))|([1-9](?:[ \u{A0}\u{202F}\u{2009}][0-9]{3})+(?=[ \t\u{A0}\u{202F}\u{2009}]*(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml)(?![\p{L}\p{M}\p{N}_]))|[0-9]{1,3}(?:[\u{A0}\u{202F}\u{2009}][0-9]{3})+|[0-9]+(?:,[0-9]{3})*(?:[.,][0-9]+)?))(?:[ \t\u{A0}\u{202F}\u{2009}]*(%|(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml|oz|ounces?|lbs?|pounds?|cups?|컵|tsp|tbsp|teaspoons?|tablespoons?|큰술|작은술|티스푼|개|large|medium|small)(?![\p{L}\p{M}\p{N}_])))?/#
            .ignoresCase()
            // 웹(/u 정규식)과 같은 코드포인트 단위 — 자소 단위면 "500️g"(숫자+VS16)의 마지막 0을 숫자로 못 읽는다
            .matchingSemantics(.unicodeScalar)
        // "1 lb 2 oz"는 한 수량 — lb 바로 뒤(공백 하나)의 oz는 앞 토큰에 더한다
        var lbEnd: String.Index?
        for match in line.matches(of: pattern) {
            let unit = match.3.map { String($0).lowercased() }
            var v: Double
            if let frac = match.1 {
                let parts = frac.split(whereSeparator: { $0 == " " || $0 == "\t" })
                let ratio = parts[parts.count - 1].split(separator: "/")
                guard ratio.count == 2, let n = Double(ratio[0]), let d = Double(ratio[1]), d != 0
                else { continue }
                v = (parts.count == 2 ? Double(parts[0]) ?? 0 : 0) + n / d
            } else if let number = match.2 {
                var raw = String(number).filter { !" \u{00A0}\u{202F}\u{2009}".contains($0) }
                if unit.map({ kgUnits.contains($0) }) == true,
                    raw.wholeMatch(of: /[0-9]{1,3},[0-9]{3}/) != nil
                {
                    // 프랑스식 소수 쉼표 — "0,700 kg"·"1,000 kg"은 1000배가 아니다.
                    // 단위 없는 "0,700"은 kg 열 표("1,000 / 0,700")와 같은 배율이 되도록 천 단위로 둔다
                    raw = raw.replacingOccurrences(of: ",", with: ".")
                } else {
                    // 천 단위 쉼표 제거 (쉼표 뒤 3자리), 남은 쉼표는 소수점으로
                    while let r = raw.range(of: #",(?=[0-9]{3}(\D|$))"#, options: rx) {
                        raw.removeSubrange(r)
                    }
                    raw = raw.replacingOccurrences(of: ",", with: ".")
                }
                guard let parsed = Double(raw) else { continue }
                v = parsed
            } else {
                continue
            }
            let (kind, factor) = unit.map { units[$0] ?? (.measure, 1) } ?? (.bare, 1)
            v *= factor
            guard v.isFinite else { continue }
            if let unit, ozUnits.contains(unit), match.range.lowerBound == lbEnd,
                match.output.0.first?.isWhitespace == true
            {
                tokens[tokens.count - 1].0 += v
                lbEnd = nil
                continue
            }
            tokens.append((v, kind))
            lbEnd = unit.map { lbUnits.contains($0) } == true ? match.range.upperBound : nil
        }
        return tokens
    }

    /// 줄의 그램 수량 — 괄호 밖 무게 단위 → 전체 무게 단위 → 괄호 밖 단위 없는 수 → 전체 단위 없는 수 순.
    /// 괄호 안 부연("500g (강력 400 + 통밀 100)")이 그램을 가리지 않고,
    /// "1 1/2 cups (340g)"에서는 컵 수가 아니라 괄호 안 340g을 쓴다.
    /// 같은 그룹에 수가 2개 이상이고 '+'가 있으면 합산("물 100g + 50g"), 아니면 마지막 값.
    static func pickGrams(_ line: String) -> Double? {
        let outer = line.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: rx)
        let outerTokens = numberTokens(in: outer)
        let allTokens = numberTokens(in: line)
        let groups: [(values: [Double], source: String)] = [
            (outerTokens.filter { $0.kind == .mass }.map(\.value), outer),
            (allTokens.filter { $0.kind == .mass }.map(\.value), line),
            (outerTokens.filter { $0.kind == .bare }.map(\.value), outer),
            (allTokens.filter { $0.kind == .bare }.map(\.value), line),
        ]
        for (values, source) in groups where !values.isEmpty {
            return values.count >= 2 && source.contains("+") ? values.reduce(0, +) : values.last
        }
        return nil
    }

    static func hasAmount(_ tokens: [(value: Double, kind: NumberKind)]) -> Bool {
        tokens.contains { $0.kind == .mass || $0.kind == .bare }
    }

    static func contains(_ line: String, _ keywords: [String]) -> Bool {
        keywords.contains { line.localizedCaseInsensitiveContains($0) }
    }

    static func containsWord(_ line: String, _ word: String) -> Bool {
        line.range(of: "(?i)\\b\(word)\\b", options: rx) != nil
    }

    static func matchesFlour(_ line: String) -> Bool {
        // "코코아가루"·"시나몬가루"는 가루지만 밀가루가 아니다
        if contains(line, ["코코아", "카카오", "시나몬", "계피", "말차", "녹차", "커피"]) {
            return false
        }
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

    /// 르방(사전발효종) 줄·이름 — '르뱅쿠키'는 과자 이름, 'leavening'은 팽창제라 제외
    public static func matchesLevain(_ line: String) -> Bool {
        contains(line, levainKeywords) || containsWord(line, "ferment") || containsWord(line, "leaven")
            || line.range(of: #"르뱅(?!\s*쿠키)"#, options: rx) != nil
    }

    /// 물 — 물엿·시럽과 '물'이 들어간 다른 단어(곡물·식물성 …)는 제외, eau는 단어 단위(gâteau 방지)
    static func matchesWater(_ line: String) -> Bool {
        contains(line, ["물", "water"])
            && !contains(line, ["물엿", "시럽", "syrup", "곡물", "식물성", "동물성", "해산물"])
            || containsWord(line, "eau")
    }

    // MARK: 전처리

    /// SNS 표기 제거 — @멘션은 재료 이름이 아니고, #해시태그는 잡음이다 ("@75%"처럼 숫자뿐이면 멘션이 아니다).
    /// 키캡 번호("1️⃣ 르방 만들기", 🔟)는 섹션·단계 번호라 수량이 아니다
    static func stripSocialTokens(_ line: String) -> String {
        var s = line
        s = s.replacingOccurrences(
            of: #"(?:[0-9#*]\x{FE0F}?\x{20E3}|\x{1F51F}\x{FE0F}?)[.)]?[ \t]*"#, with: "", options: rx)
        s = s.replacingOccurrences(of: #"@(?=[A-Za-z0-9_.]*[A-Za-z_])[A-Za-z0-9_.]+"#, with: "", options: rx)
        s = s.replacingOccurrences(of: #"#\S+"#, with: "", options: rx)
        return s
    }

    /// 줄 분리 — NFC로 정규화하고 CRLF를 한 줄바꿈으로 본다
    /// (components(separatedBy: .newlines)는 \r\n 사이에 빈 줄을 만든다)
    static func lines(of text: String) -> [String] {
        text.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
    }

    /// 파싱 전 전체 텍스트 정리 — AI 경로도 같은 전처리를 쓰도록 공개
    public static func cleanForParsing(_ text: String) -> String {
        lines(of: text)
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

    /// 시간·차수 표기 제거 — "실온 6시간 발효", "30분 휴지", "1차 발효 3~4시간", "3회 폴딩" 같은 줄의 숫자가
    /// 그램으로 합산되지 않도록 한다 (르방 빌드 섹션에서 특히 치명적). 범위("3~4시간", "3-4 hours" — 대시는 붙여 쓴 것만)는 앞 수까지 지운다.
    /// 숫자가 앞서는 재료("50 초코칩", "20 분유", "4분할")는 시간이 아니고,
    /// 차·회·번 뒤에 다른 글자가 붙으면("1회분", "번데기") 차수가 아니다.
    static func stripDurations(_ line: String) -> String {
        var s = line
        s = s.replacingOccurrences(
            of: #"(?:[0-9]+(?:[.,][0-9]+)?(?:[ \t]*[~〜～][ \t]*|[–-]))?[0-9]+(?:[.,][0-9]+)?[ \t]*(?:시간|분(?!유|당|말|할)|초(?!코|콜)|hours?|hrs?|minutes?|mins?|seconds?|secs?)(?![A-Za-z])"#,
            with: "", options: [rx, .caseInsensitive])
        s = s.replacingOccurrences(
            of: #"(?<![0-9.,])(?:[0-9]{1,2}(?:[ \t]*[~〜～][ \t]*|[–-]))?[0-9]{1,2}[ \t]*(?:차|회차?|번째?)(?=[^가-힣A-Za-z0-9]|$|발효|반죽|폴딩|접기|펀칭|성형|휴지|믹싱|오토리즈)"#,
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
        let numeric = parts.filter { hasAmount(numberTokens(in: $0)) }
        return numeric.count >= 2 ? parts : [line]
    }

    /// 재료가 아닌 줄 (헤더·합계 등).
    /// 수분율/hydration/온도는 그램 수량이 함께 있으면 재료 줄이므로 거르지 않는다.
    static func shouldSkip(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return true }
        // 합계 표기는 괄호 밖·머리 기호("- ", "• ") 뒤에서 본다 — "물 700g (총 수분율 75%)"는 재료 줄.
        // 괄호 밖에 양이 없으면("재료 (총 960g)"·"(합계 960g)") 괄호 안까지 본다
        var outer = t.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: rx)
        if outer.range(of: #"\p{L}"#, options: rx) == nil || !hasAmount(numberTokens(in: outer)) {
            outer = t.replacingOccurrences(of: #"[()]"#, with: " ", options: rx)
        }
        outer = outer.replacingOccurrences(of: #"^[^\p{L}\p{N}]+"#, with: "", options: rx)
        if outer.range(
            of: #"(?<![가-힣A-Za-z0-9])총|총\s*(?:계|량|중량|무게)|합\s*계|^계(?![가-힣A-Za-z0-9])"#,
            options: rx) != nil
        {
            return true
        }
        if !matchesLevain(outer),
            outer.range(of: #"전체\s*반죽|반죽\s*(?:무게|중량)|분할"#, options: rx) != nil
        {
            return true
        }
        if contains(outer, ["total", "재 료", "베이커", "baker"]) {
            return true
        }
        if contains(t, ["수분율", "hydration", "온도"]), !hasAmount(numberTokens(in: t)) {
            return true  // "수분율 75%" 같은 통계·표기 줄
        }
        // "물 340g에 르방을 풀어주세요" 같은 서술문
        if t.range(of: #"(하세요|해주세요|주세요|해 주세요|니다)"#, options: rx) != nil {
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
            of: #"(?<![A-Za-z0-9])(?:[0-9]+[ \t]+)?[0-9]+(?:/[0-9]+|(?:[ \u00A0\u202F\u2009][0-9]{3})*(?:[.,][0-9]+)?)[ \t\u00A0\u202F\u2009]*(?:%|(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml|oz|ounces?|lbs?|pounds?|cups?|컵|tsp|tbsp|teaspoons?|tablespoons?|큰술|작은술|티스푼|개|large|medium|small)(?![\p{L}\p{M}\p{N}_]))?"#,
            with: "", options: [rx, .caseInsensitive])
        s = s.replacingOccurrences(of: #"\([ \t]*\)"#, with: "", options: rx)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t\u{00A0}\u{202F}\u{2009}:·.-—|"))
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
            && (contains(line, [
                "만드는 법", "만드는법", "방법", "만들기", "순서", "공정", "과정",
                "method", "instruction", "direction", "préparation", "étapes",
            ])
                || containsWord(line, "steps")
                || containsWord(line, "how to")
                || containsWord(line, "procedures?"))
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
        var segments: [(text: String, hadDuration: Bool)] = []
        for rawLine in lines(of: text) {
            // "G." "1)" 같은 머리 기호를 먼저 떼야 헤더("1. 재료")를 제대로 거른다
            let pre = stripTemperatures(stripSocialTokens(cleanTitle(rawLine)))
            let line = stripDurations(pre)
            // 시간·차수만 남았던 공정 줄("벌크 발효 4시간", "1차 발효")은 제목 후보가 아니다
            let hadDuration = line != pre
            segments.append(contentsOf: splitSegments(line).map { ($0, hadDuration) })
        }

        for segment in segments {
            let line = segment.text.trimmingCharacters(in: .whitespaces)
            if section == .stopped { continue }
            if shouldSkip(line) { continue }

            let grams = pickGrams(line)
            // %는 괄호 안("(수분율 100%)")에도 오므로 전체에서 찾되,
            // "(총 수분율 75%)"처럼 반죽 전체를 가리키는 괄호는 이 재료의 %가 아니다
            let percent = numberTokens(
                in: line.replacingOccurrences(
                    of: #"\([^)]*(?:총|반죽|total)[^)]*\)"#, with: " ", options: [rx, .caseInsensitive])
            ).first(where: { $0.kind == .percent })?.value

            guard let grams, grams > 0 else {
                // 괄호 밖에 컵·스푼·개수만 있는 줄은 그램을 모르는 재료 줄 — 섹션 헤더·제목 후보가 아니다
                // ("본반죽 (빵 2개 분량)"은 머리글)
                let outer = line.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: rx)
                if numberTokens(in: outer).contains(where: { $0.kind == .measure }) { continue }
                // 숫자 없는 줄: 섹션 헤더 또는 제목 후보
                if isLevainBuildHeader(line) {
                    section = .levainBuild
                } else if isMainDoughHeader(line) {
                    section = .main
                } else if matched >= 2, isMethodHeader(line) {
                    section = .stopped
                } else if name == nil, numberTokens(in: line).isEmpty, section == .main,
                    !segment.hadDuration
                {
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
                } else if matchesWater(line) {
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
                } else if contains(line, ["뒤흐", "뒤르", "듀르", "스티프", "stiff"])
                    || containsWord(line, "dur")
                {
                    levainHydration = 0.5
                    levainHydrationExplicit = true
                } else if let percent, percent >= 30, percent <= 150 {
                    // 30~150% 밖의 %는 수분율이 아니라 베이커스 퍼센트 표기일 가능성이 높다
                    // (예: "르방 100g (20%)") — 무시하고 기본 수분율을 유지한다
                    levainHydration = percent / 100
                    levainHydrationExplicit = true
                }
            } else if contains(line, ["소금", "천일염", "소곰"])
                || containsWord(line, "salt") || containsWord(line, "sel")
            {
                salt += grams
            } else if contains(line, ["이스트", "yeast", "levure", "효모"]) || containsWord(line, "IDY") {
                yeast.grams += grams
                if contains(line, ["인스턴트", "드라이", "instant", "dry", "sèche"]) || containsWord(line, "IDY") {
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
            } else if matchesWater(line) {
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
                    matchesLevain($0) ? nil : $0
                }),
            liquids: liquids,
            yeast: yeast,
            extras: extras)
        return ParsedRecipeText(
            name: name, input: input, matchedLineCount: matched,
            levainHydrationExplicit: levainHydrationExplicit)
    }
}
