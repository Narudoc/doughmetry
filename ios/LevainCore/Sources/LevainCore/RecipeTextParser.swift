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
    /// 르방 수분율을 텍스트가 직접 밝혔는지(30~150%, 리퀴드/뒤흐 키워드, 풀리시·비가) — 기본값·빌드 섹션 추정은 false
    public var levainHydrationExplicit: Bool
    /// 공정(만드는 법) 머리글부터 끝까지의 원문 — 레시피 노트로 저장한다. 없으면 nil
    public var methodNote: String?
    /// 분량 표기("2개 분량", "2 loaves", 배합표의 "분할 2개 — 개당")에서 읽은 분할 개수. 없으면 nil
    public var pieces: Double?

    public init(
        name: String?, input: DoughInput, matchedLineCount: Int, levainHydrationExplicit: Bool = false,
        methodNote: String? = nil, pieces: Double? = nil
    ) {
        self.name = name
        self.input = input
        self.matchedLineCount = matchedLineCount
        self.levainHydrationExplicit = levainHydrationExplicit
        self.methodNote = methodNote
        self.pieces = pieces
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
    /// 단위: % 는 수분율, kg류·oz·lb 는 g로 환산, 컵·스푼·개수·배합("1배합")은 그램이 아니다.
    /// 캡처 1: 분수("1/2", "3 3/4") — 두 자리까지만, "350/370g" 같은 범위·두 배합 표기는 분수가 아니다
    /// 캡처 2: 수 — 천 단위 구분은 쉼표·NBSP류 공백, 일반 공백은 무게 단위가 뒤따르고 앞자리가 한 자리일 때만
    ///   ("1 000 g" — "type 65 500 g"·"Farine 100 500 g"의 앞 수는 별개)
    /// 캡처 3: 단위 — 단어 중간("500g을", "gâteau")은 단위가 아니다
    static func numberTokens(in line: String) -> [(value: Double, kind: NumberKind)] {
        var tokens: [(Double, NumberKind)] = []
        let pattern = #/(?:^|[^A-Za-z0-9])(?:((?:[0-9]+[ \t]+)?[0-9]{1,2}/[0-9]{1,2}(?![0-9]))|([1-9](?:[ \u{A0}\u{202F}\u{2009}][0-9]{3})+(?=[ \t\u{A0}\u{202F}\u{2009}]*(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml)(?![\p{L}\p{M}\p{N}_]))|[0-9]{1,3}(?:[\u{A0}\u{202F}\u{2009}][0-9]{3})+|[0-9]+(?:,[0-9]{3})*(?:[.,][0-9]+)?))(?:[ \t\u{A0}\u{202F}\u{2009}]*(%|(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml|oz|ounces?|lbs?|pounds?|cups?|컵|tsp|tbsp|teaspoons?|tablespoons?|큰술|작은술|티스푼|개|덩어리|덩이|인분|판|배합|loaf|loaves|servings?|large|medium|small)(?![\p{L}\p{M}\p{N}_])))?/#
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

    /// 로캘과 무관한 대소문자 무시 (웹 toLowerCase와 같음) — localized 비교는 기기 지역이 터키어면 'I'를 'ı'로 접어
    /// "Instant"·"MILK"를 놓친다
    static func contains(_ line: String, _ keywords: [String]) -> Bool {
        keywords.contains { line.range(of: $0, options: .caseInsensitive) != nil }
    }

    /// 단어 경계는 \b 대신 웹과 같은 lookaround로 — iOS 17의 String.range는 \b를 NSRegularExpression과 다르게 읽어
    /// "d'eau"의 eau는 낱말로 못 보고 "르방dur"의 dur은 낱말로 본다 (18부터는 같다)
    static func containsWord(_ line: String, _ word: String) -> Bool {
        line.range(of: "(?i)(?<![\\p{L}\\p{M}\\p{N}_])\(word)(?![\\p{L}\\p{M}\\p{N}_])", options: rx) != nil
    }

    static func matchesFlour(_ line: String) -> Bool {
        // "코코아가루"·"시나몬가루"는 가루지만 밀가루가 아니다
        if contains(line, ["코코아", "카카오", "시나몬", "계피", "말차", "녹차", "커피"]) {
            return false
        }
        if line.range(of: #"(?i)(?<![\p{L}\p{M}\p{N}_])t[0-9]{2,3}(?![\p{L}\p{M}\p{N}_])"#, options: rx) != nil {
            return true  // T45/T65/T110 … — "밀T65"처럼 문자가 붙으면 아니다
        }
        return contains(line, [
            "밀가루", "가루", "강력", "중력", "박력", "호밀", "통밀", "스펠트", "세몰리나", "듀럼",
            "트레디션", "flour", "farine", "rye", "wheat", "spelt", "semolina", "durum",
            "tradition", "grau", "메밀", "옥수수가루",
        ])
    }

    static let poolishKeywords = ["풀리시", "풀리쉬", "폴리쉬", "폴리시", "poolish"]

    static let levainKeywords = [
        "르방", "levain", "스타터", "starter", "발효종", "사전반죽", "biga",
    ] + poolishKeywords

    /// 비가(biga) — '비가'는 흔한 낱말("비가 와서 …", "비가 3일째 …")이라 줄 머리에서 양(숫자 + 단위 또는
    /// 숫자만)·괄호·쌍점·'만들기'가 뒤따르거나 그 낱말만 있을 때만 발효종으로 본다
    static func matchesBiga(_ line: String) -> Bool {
        contains(line, ["biga"])
            || line.range(
                of: #"(?i)^[^\p{L}\p{N}]*비가(?=[ \t]*(?:[(:]|만들기|$|[0-9][0-9.,]*[ \t]*(?:%|kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml|oz|ounces?|lbs?|pounds?)?(?![\p{L}\p{N}])))"#,
                options: rx) != nil
    }

    /// 르방(사전발효종) 줄·이름 — '르뱅쿠키'는 과자 이름, 'leavening'은 팽창제라 제외
    public static func matchesLevain(_ line: String) -> Bool {
        contains(line, levainKeywords) || matchesBiga(line)
            || containsWord(line, "ferment") || containsWord(line, "leaven")
            || line.range(of: #"르뱅(?!\s*쿠키)"#, options: rx) != nil
    }

    /// 수분율을 밝히지 않은 풀리시·비가의 관례 수분율 — 풀리시 100%, 비가 50%
    static func prefermentHydration(_ line: String) -> Double? {
        if contains(line, poolishKeywords) { return 1.0 }
        if matchesBiga(line) { return 0.5 }
        return nil
    }

    /// 물 — 물엿·시럽과 '물'이 들어간 다른 단어(곡물·식물성 …)는 제외, eau는 단어 단위(gâteau 방지)
    static func matchesWater(_ line: String) -> Bool {
        contains(line, ["물", "water"])
            && !contains(line, ["물엿", "시럽", "syrup", "곡물", "식물성", "동물성", "해산물"])
            || containsWord(line, "eau")
    }

    static func matchesSalt(_ line: String) -> Bool {
        contains(line, ["소금", "천일염", "소곰"]) || containsWord(line, "salt") || containsWord(line, "sel")
    }

    static let bassinageKeywords = ["바시나주", "바시나쥬", "bassinage", "조절수", "조정수"]

    /// 액체 재료 키워드 — 파서의 액체 분기와 AI 초안 보정(reconcileAIDraft)이 같은 표를 쓴다
    static let milkKeywords = ["우유", "milk", "lait"]
    static let eggKeywords = ["계란", "달걀", "전란", "egg", "oeuf", "œuf"]

    /// 이름으로 고른 액체 프리셋(우유·계란) — 해당 없으면 nil
    public static func liquidPreset(forName name: String) -> LiquidPreset? {
        if contains(name, milkKeywords) { return .milk }
        if contains(name, eggKeywords) { return .egg }
        return nil
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
    /// ("도" 뒤에 글자가 이어지면(포도·도우 등) 매칭하지 않는다).
    /// 범위("24-25도씨", "24~25℃")는 앞 수까지 지운다 — 대시는 붙여 쓴 것만 (시간 범위와 같은 규칙)
    static func stripTemperatures(_ line: String) -> String {
        var s = line
        s = s.replacingOccurrences(
            of: #"\([^)]*(?:°|℃|온도|[0-9][ \t]*도)[^)]*\)"#, with: "", options: rx)
        s = s.replacingOccurrences(
            of: #"(?:[0-9]+(?:[.,][0-9]+)?(?:[ \t]*(?:°[CcFf]?|℃|도))?(?:[ \t]*[~〜～][ \t]*|[–-]))?[0-9]+(?:[.,][0-9]+)?[ \t]*(?:°[CcFf]?|℃|도씨?(?![가-힣A-Za-z]))"#,
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
        // 앱 배합표의 르방 속 밀가루·물 행("  ↳ 속 밀가루  100.0 g  (PFF 9.1%)", "↳ Flour in levain …") —
        // 르방 무게에 이미 들어 있다. OCR이 화살표를 놓쳐도 앱 라벨(Localization의 속 밀가루·속 물, 옛 영문
        // "Flour inside" 포함)로 거른다
        if t.hasPrefix("↳") { return true }
        if t.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: rx).range(
            of: #"(?i)(?<!\p{L})속\s*(?:밀가루|물)(?!\p{L})|(?<!\p{L})(?:flour|water)\s+in(?:side|\s+levain)(?!\p{L})"#,
            options: rx) != nil
        {
            return true
        }
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
            outer.range(
                of: #"(?i)전체\s*반죽|반죽\s*(?:무게|중량)|분할|(?<!\p{L})divide(?!\p{L})"#, options: rx) != nil
        {
            return true
        }
        if contains(outer, ["total", "재 료", "베이커", "baker"]) {
            return true
        }
        // "수분율 75%" 같은 통계·표기 줄 — 통계 낱말 말고 다른 글자가 남으면("75% Hydration Sourdough") 제목일 수 있다.
        // 온도 줄("반죽 온도 24℃")은 글자가 남아도 통계 줄이다
        if !hasAmount(numberTokens(in: t)),
            contains(t, ["온도"])
                || contains(t, ["수분율", "hydration", "hydratation", "PFF"])
                    && t.replacingOccurrences(
                        of: #"(?i)수분율|hydration|hydratation|levain|르방|르뱅|리퀴드|liquide|뒤흐|dur|스타터|starter|발효종|사전반죽|풀리시|풀리쉬|폴리쉬|폴리시|poolish|biga|비가|pff|반죽|dough|재료|ingredients?|[^\p{L}]"#,
                        with: "",
                        options: rx
                    ).isEmpty
        {
            return true
        }
        // "물 340g에 르방을 풀어주세요" 같은 서술문 — 합계 판정처럼 괄호 밖에서 본다.
        // "물 350g (나눠 넣습니다)"의 괄호 속 메모는 재료 줄을 지우지 않는다
        if outer.range(of: #"(하세요|해주세요|주세요|해 주세요|니다)"#, options: rx) != nil {
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
            of: #"(?<![A-Za-z0-9])(?:[0-9]+[ \t]+)?[0-9]+(?:/[0-9]+|(?:[ \u00A0\u202F\u2009][0-9]{3})*(?:[.,][0-9]+)?)[ \t\u00A0\u202F\u2009]*(?:%|(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml|oz|ounces?|lbs?|pounds?|cups?|컵|tsp|tbsp|teaspoons?|tablespoons?|큰술|작은술|티스푼|개|덩어리|덩이|인분|판|배합|loaf|loaves|servings?|large|medium|small)(?![\p{L}\p{M}\p{N}_]))?"#,
            with: "", options: [rx, .caseInsensitive])
        s = s.replacingOccurrences(of: #"\([ \t]*\)"#, with: "", options: rx)
        s = stripLeadingSymbols(s)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t\u{00A0}\u{202F}\u{2009}:·.-—|"))
        return s
    }

    /// 제목 후보에서 "G." "1)" 같은 머리 기호와 앱 배합표 제목 줄의 꾸밈("〔캉파뉴〕 fiche technique") 제거
    static func cleanTitle(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespaces)
        s = s.replacingOccurrences(of: #"^[A-Za-z0-9]{1,3}[.)][ \t]*"#, with: "", options: rx)
        s = s.replacingOccurrences(of: #"[〔〕【】「」]"#, with: "", options: rx)
        s = s.replacingOccurrences(of: #"(?i)[ \t]*fiche[ \t]+technique[ \t]*$"#, with: "", options: rx)
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// 줄 머리의 이모지·글머리표("🍞 ", "▪️", "• ", "✔️ ") — 여는 괄호는 남긴다
    static func stripLeadingSymbols(_ s: String) -> String {
        s.replacingOccurrences(of: #"^[^\p{L}\p{N}(]+"#, with: "", options: rx)
    }

    /// 제목 후보에서 걷어낼 분량 괄호 하나 — "무화과 호두 캄파뉴 (2개 분량)"
    static let servingsParenthetical = #"(?i)\([^)]*(?:분량|인분|loaf|loaves|servings?)[^)]*\)"#
    /// 개수만 적은 괄호("캄파뉴 (2개)")는 재료보다 앞선 줄에서만 분량으로 본다 — 재료 사이의 "계란 (2개)"는 재료 줄
    static let countParenthetical =
        #"(?i)\([^)]*(?:분량|인분|개|판|덩어리|덩이|loaf|loaves|servings?)[^)]*\)"#

    /// 그램 없는 줄이 레시피 이름이면 그 이름, 아니면 nil.
    /// % 표기만 있는 줄("캉파뉴 75%")은 재료보다 앞설 때만 이름이 된다 — 재료 사이의 "PFF 20%"는 이름이 아니다
    static func titleCandidate(_ line: String, matched: Int) -> String? {
        var s = line
        if let r = s.range(of: matched == 0 ? countParenthetical : servingsParenthetical, options: rx) {
            s.replaceSubrange(r, with: " ")
            s = s.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: rx)
        }
        let tokens = numberTokens(in: s)
        guard tokens.isEmpty || (matched == 0 && tokens.allSatisfy { $0.kind == .percent }) else {
            return nil
        }
        let t = stripLeadingSymbols(cleanTitle(s))
        guard t.count >= 2 else { return nil }
        // 베이커스 % 표의 재료 한 줄("강력분 100%", "르방 20%")은 이름이 아니다
        if !tokens.isEmpty {
            let rest = ingredientName(from: t)
                .replacingOccurrences(of: #"(?i)(?<!\p{L})(?:liquide|dur|리퀴드|뒤흐)(?!\p{L})"#, with: "", options: rx)
                .trimmingCharacters(in: .whitespaces)
            // 글자 없이 %만 남은 줄("75%", "(75%)")은 이름이 아니다
            if rest.range(of: #"\p{L}"#, options: rx) == nil { return nil }
            if !rest.contains(where: \.isWhitespace),
                matchesFlour(rest) || matchesLevain(rest) || matchesWater(rest) || matchesSalt(rest)
            {
                return nil
            }
        }
        // "…레시피 공유해요 🙌" 같은 서술문은 이름이 아니다 — 끝의 이모지·문장부호를 걷어내고 본다
        let end = t.replacingOccurrences(of: #"[^\p{L}\p{N}!?]+$"#, with: "", options: rx)
        if isChatty(end) { return nil }
        // 주소가 든 줄(앱 공유 텍스트의 끝줄 "— Doughmetry · narudoc.github.io/…", 블로그 링크)은 이름이 아니다
        if t.range(of: webAddress, options: rx) != nil { return nil }
        return t
    }

    /// 서술문 끝 — 요·죠·!·?는 늘, 다·네는 앞 글자가 '니'이거나 받침이 ㄴ·ㅄ·ㅆ일 때만
    /// (한다·섞는다·없다·구웠다·맛있네·입니다). '파네토네'·'할라피뇨 체다' 같은 빵 이름은 남긴다
    static func isChatty(_ end: String) -> Bool {
        let scalars = Array(end.unicodeScalars)
        guard let last = scalars.last else { return false }
        if "요죠!?".unicodeScalars.contains(last) { return true }
        guard last == "다" || last == "네", scalars.count >= 2 else { return false }
        let prev = scalars[scalars.count - 2]
        if prev == "니" { return true }
        let c = Int(prev.value) - 0xAC00
        return c >= 0 && c < 11172 && [4, 18, 20].contains(c % 28)
    }

    static let webAddress =
        #"(?i)https?://|www\.|(?<![\p{L}\p{N}])[a-z0-9-]+\.(?:com|net|org|io|kr|co|me|app|ly)(?![\p{L}\p{N}])"#

    /// 물 줄에 붙은 바시나주 부연 — "물 340g (+ 바시나주 25g)", "물 340g + 바시나주 25g",
    /// "물 365g (바시나주 25g 포함)". 키워드 앞이 물 줄이고 앞뒤에 각자 양이 있을 때만 나눈다
    /// ('포함'이면 앞의 양에서 뺀다). 아니면 nil — 줄 전체가 바시나주다
    static func bassinageClause(_ line: String) -> (water: Double, bassinage: Double)? {
        guard let kw = bassinageKeywords
            .compactMap({ line.range(of: $0, options: .caseInsensitive) })
            .min(by: { $0.lowerBound < $1.lowerBound })
        else { return nil }
        let head = String(line[..<kw.lowerBound])
        let tail = String(line[kw.upperBound...])
        guard matchesWater(head), let water = pickGrams(head), water > 0,
            let extra = pickGrams(tail), extra > 0
        else { return nil }
        if tail.contains("포함") {
            return water > extra ? (water - extra, extra) : nil
        }
        return (water, extra)
    }

    /// 분량 표기 — "빵 2개 분량", "2 loaves", 앱 배합표의 "분할 2개 — 개당"·"Divide by 2 — each"
    static func servings(in line: String) -> Double? {
        let pattern =
            #"(?:빵\s*)?(?<![0-9])([0-9]{1,2})\s*(?:개|덩이|덩어리)\s*분량|(?<![\p{L}\p{N}])([0-9]{1,2})\s+loaves?(?!\p{L})|(?:분할\s*([0-9]{1,2})\s*개|(?<!\p{L})divide\s+by\s+([0-9]{1,2}))\s*[—–-]\s*(?:개당|each)"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
        else { return nil }
        for i in 1..<m.numberOfRanges {
            if let r = Range(m.range(at: i), in: line), let n = Double(line[r]), n >= 1, n <= 99 {
                return n
            }
        }
        return nil
    }

    /// 공정 서술부를 노트로 — SNS 토큰만 걷어내고 시간·온도("1시간", "230도")는 남긴다.
    /// 앞뒤 빈 줄은 버리고 이어진 빈 줄은 하나로
    static func methodText(_ lines: ArraySlice<String>) -> String? {
        var out: [String] = []
        for raw in lines {
            let l = stripSocialTokens(raw).trimmingCharacters(in: .whitespaces)
            if l.isEmpty, out.last?.isEmpty ?? true { continue }
            out.append(l)
        }
        while out.last?.isEmpty == true { out.removeLast() }
        return out.isEmpty ? nil : out.joined(separator: "\n")
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
        var pieces: Double?
        var methodStart: Int?

        // 섹션 상태 — 르방 빌드 섹션 재료는 본반죽에 합산하지 않는다
        enum Section { case main, levainBuild, stopped }
        var section = Section.main
        var buildFlour = 0.0
        var buildWater = 0.0
        var buildTotal = 0.0
        // 풀리시·비가의 관례 수분율 — 빌드 섹션의 물/밀가루 비가 있으면 그쪽이 먼저다
        var prefermentDefault: Double?

        // 전처리 + 구분자 분할
        let rawLines = lines(of: text)
        var segments: [(text: String, hadDuration: Bool, lineIndex: Int)] = []
        for (index, rawLine) in rawLines.enumerated() {
            // "G." "1)" 같은 머리 기호를 먼저 떼야 헤더("1. 재료")를 제대로 거른다
            let pre = stripTemperatures(stripSocialTokens(cleanTitle(rawLine)))
            if pieces == nil { pieces = servings(in: pre) }
            let line = stripDurations(pre)
            // 시간·차수만 남았던 공정 줄("벌크 발효 4시간", "1차 발효")은 제목 후보가 아니다
            let hadDuration = line != pre
            segments.append(contentsOf: splitSegments(line).map { ($0, hadDuration, index) })
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
                    methodStart = segment.lineIndex
                } else if name == nil, section == .main, !segment.hadDuration {
                    name = titleCandidate(line, matched: matched)
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

            if contains(line, bassinageKeywords) {
                if let clause = bassinageClause(line) {
                    water += clause.water
                    bassinage += clause.bassinage
                } else {
                    bassinage += grams
                }
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
                } else if let h = prefermentHydration(line) {
                    prefermentDefault = h
                }
            } else if matchesSalt(line) {
                salt += grams
            } else if contains(line, ["이스트", "yeast", "levure", "효모"]) || containsWord(line, "IDY") {
                yeast.grams += grams
                if contains(line, ["인스턴트", "드라이", "instant", "dry", "sèche"]) || containsWord(line, "IDY") {
                    yeast.type = .instant
                }
            } else if contains(line, milkKeywords) {
                liquids.append(
                    Liquid(name: ingredientName(from: line), grams: grams,
                           waterRatio: LiquidPreset.milk.waterRatio))
            } else if contains(line, eggKeywords) {
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
        var usedBuildRatio = false
        if buildTotal > 0 {
            if levainGrams == 0 { levainGrams = buildTotal }
            if !levainHydrationExplicit, buildFlour > 0 {
                let h = buildWater / buildFlour
                if h >= 0.3, h <= 1.5 {
                    levainHydration = h
                    usedBuildRatio = true
                }
            }
        }
        if !levainHydrationExplicit, !usedBuildRatio, let d = prefermentDefault {
            levainHydration = d
            levainHydrationExplicit = true
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
            levainHydrationExplicit: levainHydrationExplicit,
            methodNote: methodStart.flatMap { methodText(rawLines[$0...]) },
            pieces: pieces)
    }
}
