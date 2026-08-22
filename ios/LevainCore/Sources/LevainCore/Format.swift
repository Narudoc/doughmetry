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
    ISO8601DateFormatter().string(from: Date())
}

public func fmtDate(iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    guard let d else { return "" }
    let out = DateFormatter()
    out.dateFormat = "yyyy.MM.dd"
    return out.string(from: d)
}
