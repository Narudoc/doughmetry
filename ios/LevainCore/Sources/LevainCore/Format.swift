import Foundation

/// 표시 계층 — 내부는 full precision, 반올림은 여기서만. (src/lib/format.ts 이식)

public enum Precision: Double, Codable, Sendable, CaseIterable {
    case tenth = 0.1
    case whole = 1

    public var label: String {
        switch self {
        case .tenth: return "0.1 g"
        case .whole: return "1 g"
        }
    }
}

/// JS Number.prototype.toFixed 이식 — 웹과 글자까지 같아야 한다. printf(%.Nf)는 정확한 2진 동점(12.5, 72.25)을
/// 짝수 쪽으로 보내지만 toFixed는 0에서 먼 쪽으로 올리므로 동점만 따로 처리한다 (나머지는 둘 다 2진 값 그대로 반올림).
/// `(x * s).rounded(...) / s`로 단순화하지 말 것 — 1.8499999999999999 × 10이 18.5로 반올림돼 새 불일치가 생긴다.
/// |x| × 10^digits < 2^52 범위에서 정확 (반죽 값으로는 그 밖에 도달하지 않는다).
public func toFixed(_ x: Double, _ digits: Int) -> String {
    if x.isNaN { return "NaN" }
    if x.isInfinite { return x < 0 ? "-Infinity" : "Infinity" }
    let x = x == 0 ? 0 : x // −0은 toFixed에서 "0" (printf는 "-0")
    let s = pow(10.0, Double(digits))
    let scaled = x * s
    if fma(x, s, -scaled) == 0, // x × s가 오차 없이 계산됨
        abs(scaled - scaled.rounded(.towardZero)) == 0.5
    {
        return String(format: "%.\(digits)f", scaled.rounded(.toNearestOrAwayFromZero) / s)
    }
    return String(format: "%.\(digits)f", x)
}

/// 그램 표시 — 0.1g 또는 1g 반올림
public func fmtGrams(_ g: Double, _ precision: Precision = .tenth) -> String {
    toFixed(g, precision == .whole ? 0 : 1)
}

public func fmtPct(_ p: Double, digits: Int = 1) -> String {
    toFixed(p, digits) + "%"
}

/// 증감분 표시: +33.3 / −33.3 (U+2212)
public func fmtSigned(_ g: Double, _ precision: Precision = .tenth) -> String {
    let abs = fmtGrams(Swift.abs(g), precision)
    return g < 0 ? "\u{2212}\(abs)" : "+\(abs)"
}

/// 숫자 입력 해석 (웹 fields.tsx `parseDecimalInput`과 같은 규칙). 자릿수가 맞는 천 단위 구분("1,000",
/// "12,345,678", "1,000.5")만 쉼표를 지우고, 그 밖의 쉼표는 소수점으로 본다("72,5", "0,125" — 쉼표 소수점 키패드).
/// 해석할 수 없으면 nil. 숫자는 ASCII만 — Regex의 \d는 유니코드 숫자까지 받는다
public func parseDecimalInput(_ s: String) -> Double? {
    if s.wholeMatch(of: /[1-9][0-9]{0,2}(?:,[0-9]{3})+(?:\.[0-9]*)?/) != nil {
        return Double(s.replacingOccurrences(of: ",", with: ""))
    }
    guard let comma = s.firstIndex(of: ",") else { return Double(s) }
    return Double(s.replacingCharacters(in: comma...comma, with: "."))
}

// 포매터 생성은 비싸다(호출당 ~0.3ms) — 병합·정렬의 비교나 목록 행마다 만들지 않도록 재사용한다.
// ISO8601DateFormatter는 Sendable이 아니지만 생성 뒤 설정을 바꾸지 않으므로 여러 스레드에서 읽어도 안전하다.
private nonisolated(unsafe) let isoFormatter = ISO8601DateFormatter()

private let dotDateFormatter: DateFormatter = {
    let f = DateFormatter()
    // 고정 포맷은 사용자 달력(불교력·일본력 등)의 영향을 받지 않도록 반드시 고정할 것.
    // timeZone은 지정하지 않는다 — 지정하지 않아야 기기 시간대 변경을 따라간다.
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy.MM.dd"
    return f
}()

public func isoNow() -> String {
    isoString(from: Date())
}

/// 초 단위 ISO 8601 (예: 2026-09-03T10:00:00Z).
/// ISO8601FormatStyle로 바꾸지 말 것 — 초 경계 직전(.9995초 이상)을 올림하지 않고 버려 기존 저장값과 달라진다.
public func isoString(from date: Date) -> String {
    isoFormatter.string(from: date)
}

/// 웹(밀리초 포함)과 iOS(초 단위) ISO 8601을 모두 파싱
public func parseISO(_ s: String) -> Date? {
    (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(s))
        ?? (try? Date.ISO8601FormatStyle().parse(s))
}

public func fmtDate(iso: String) -> String {
    guard let d = parseISO(iso) else { return "" }
    return dotDateFormatter.string(from: d)
}
