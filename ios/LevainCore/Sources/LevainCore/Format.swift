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

/// 그램 표시 — 0.1g 또는 1g 반올림
public func fmtGrams(_ g: Double, _ precision: Precision = .tenth) -> String {
    String(format: precision == .whole ? "%.0f" : "%.1f", g)
}

public func fmtPct(_ p: Double, digits: Int = 1) -> String {
    String(format: "%.\(digits)f%%", p)
}

/// 증감분 표시: +33.3 / −33.3 (U+2212)
public func fmtSigned(_ g: Double, _ precision: Precision = .tenth) -> String {
    let abs = fmtGrams(Swift.abs(g), precision)
    return g < 0 ? "\u{2212}\(abs)" : "+\(abs)"
}

public func isoNow() -> String {
    isoString(from: Date())
}

public func isoString(from date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

/// 웹(밀리초 포함)과 iOS(초 단위) ISO 8601을 모두 파싱
public func parseISO(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    return ISO8601DateFormatter().date(from: s)
}

public func fmtDate(iso: String) -> String {
    guard let d = parseISO(iso) else { return "" }
    let out = DateFormatter()
    // 고정 포맷은 사용자 달력(불교력·일본력 등)의 영향을 받지 않도록 반드시 고정할 것
    out.locale = Locale(identifier: "en_US_POSIX")
    out.calendar = Calendar(identifier: .gregorian)
    out.dateFormat = "yyyy.MM.dd"
    return out.string(from: d)
}
