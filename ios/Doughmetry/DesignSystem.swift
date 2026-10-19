import SwiftUI
import UIKit

/// 웹앱 색 토큰의 iOS 이식 — 라이트/다크 자동 대응.
/// paper 배경 / ink 본문 / bottle 구조색 / brass 계산 결과값 전용 / line 괘선 / danger 오류.
extension Color {
    static let paper = Color(light: 0xF5F2EA, dark: 0x1C1B16)
    static let ink = Color(light: 0x22271F, dark: 0xE9E5D9)
    static let bottle = Color(light: 0x1E4034, dark: 0x8FB8A5)
    /// 대비 증가(설정 → 손쉬운 사용)에선 한 단계 더 진하게/밝게 — 요약 바 재질 위에서도 4.5:1을 넉넉히 넘도록
    static let brass = Color(
        light: 0x8A5C26, dark: 0xD3A662, highContrastLight: 0x7A5222, highContrastDark: 0xE0B676)
    static let line = Color(light: 0xD9D3C4, dark: 0x3B382E)
    static let danger = Color(light: 0x9E3B2F, dark: 0xD97A6C)
    /// 카드(입력 섹션) 배경 — 웹의 흰 카드에 해당
    static let card = Color(light: 0xFFFFFF, dark: 0x26241D)

    init(light: UInt32, dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) {
        self.init(uiColor: UIColor { trait in
            let isDark = trait.userInterfaceStyle == .dark
            let hex =
                trait.accessibilityContrast == .high
                ? (isDark ? (highContrastDark ?? dark) : (highContrastLight ?? light))
                : (isDark ? dark : light)
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
        })
    }
}

extension View {
    /// 결과 수치용 글꼴 — size는 기본 글자 크기에서의 pt이고 가장 가까운 텍스트 스타일 비율로 Dynamic Type을 따라간다.
    /// 고정 크기로 두면 옆 라벨만 커져 숫자가 상대적으로 작아지고 줄바꿈이 어긋난다
    func statFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        modifier(StatFont(size: size, weight: weight))
    }
}

private struct StatFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        let style: Font.TextStyle =
            switch size {
            case ..<14: .footnote
            case ..<16: .subheadline
            case ..<17: .callout
            case ..<19: .body
            case ..<21: .title3
            default: .title2
            }
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

/// 한국어 라벨 + 프랑스어 원어 병기 (이탤릭)
struct BilingualLabel: View {
    let ko: String
    let fr: String?

    init(_ ko: String, fr: String? = nil) {
        self.ko = ko
        self.fr = fr
    }

    /// 라벨을 되풀이하는 원어는 줄이거나 뺀다 — 영어 "Bassinage" + "bassinage", "Levain" + "levain liquide"
    private var gloss: String? {
        guard let fr else { return nil }
        if fr.caseInsensitiveCompare(ko) == .orderedSame { return nil }
        let prefix = ko + " "
        if fr.count > prefix.count,
            fr.prefix(prefix.count).caseInsensitiveCompare(prefix) == .orderedSame
        {
            return String(fr.dropFirst(prefix.count))
        }
        return fr
    }

    var body: some View {
        // 섹션 머리말에 놓이면 iOS 17/18이 대문자로 바꾼다 ("LEVAIN LIQUIDE") — 원어 표기는 그대로 보인다
        Group {
            if let gloss {
                (Text("\(ko) ").foregroundStyle(.primary)
                    + Text(gloss).italic().font(.caption).foregroundStyle(.secondary))
                    .accessibilityLabel("\(ko), \(gloss)")
            } else {
                Text(ko)
            }
        }
        .textCase(nil)
    }
}

extension View {
    /// 넓은 창(regular 폭)에서 폼·목록을 읽기 좋은 폭(700pt)으로 가운데에 모은다 — compact(iPhone)는 그대로.
    /// 결과 바(ResultBar)의 maxWidth와 같은 값이어야 한다
    func readableFormWidth() -> some View { modifier(ReadableFormWidth()) }
}

private struct ReadableFormWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            GeometryReader { proxy in
                // 여백은 스크롤 뷰 가장자리부터 잰다 — iPadOS 26+ 떠 있는 사이드바 아래로 깔린 만큼(safe area)을 더한다
                let side = max(20, (proxy.size.width - 700) / 2)
                content
                    .contentMargins(.leading, proxy.safeAreaInsets.leading + side, for: .scrollContent)
                    .contentMargins(.trailing, proxy.safeAreaInsets.trailing + side, for: .scrollContent)
            }
        } else {
            content
        }
    }
}

extension EnvironmentValues {
    /// 앱 창이 regular 폭인지 — RootView가 정한다. 시트 안의 크기 클래스는 iPad에서도 compact라
    /// 시트 높이처럼 띄운 창에 따라 달라지는 판단은 이 값을 쓴다
    @Entry var windowIsRegular: Bool = false
}

extension View {
    /// 시트 높이 — 넓은 창(iPad)에선 늘 큰 시트(가운데 폼 시트), 좁은 창은 주어진 높이들.
    /// 넓은 창의 중간 높이는 iOS 17/18에선 내용이 잘린 짧은 카드, 26+에선 아래에 붙은 반 높이 시트가 된다
    func adaptiveDetents(_ detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        modifier(AdaptiveDetents(detents: detents))
    }

    func adaptiveDetents(
        _ detents: Set<PresentationDetent>, selection: Binding<PresentationDetent>
    ) -> some View {
        modifier(AdaptiveDetentsSelection(detents: detents, selection: selection))
    }
}

// 창 폭이 바뀌어도(iPad 분할 화면) 같은 호출 하나로 — 가지를 나누면 시트 내용이 새로 만들어져 입력 상태를 잃는다
private struct AdaptiveDetents: ViewModifier {
    let detents: Set<PresentationDetent>
    @Environment(\.windowIsRegular) private var windowIsRegular

    func body(content: Content) -> some View {
        content.presentationDetents(windowIsRegular ? [.large] : detents)
    }
}

private struct AdaptiveDetentsSelection: ViewModifier {
    let detents: Set<PresentationDetent>
    @Binding var selection: PresentationDetent
    @Environment(\.windowIsRegular) private var windowIsRegular

    func body(content: Content) -> some View {
        // 넓은 창에선 선택값이 고를 수 없는 높이(.medium)로 남지 않게 .large로 읽힌다
        let regular = windowIsRegular
        let selection = $selection
        return content.presentationDetents(
            regular ? [.large] : detents,
            selection: Binding(
                get: { regular ? .large : selection.wrappedValue },
                set: { if !regular { selection.wrappedValue = $0 } }))
    }
}

extension View {
    /// iPad에선 긴 내용이 작은 폼 시트에 갇히지 않게 페이지 크기 시트로 (iOS 18+ — 17은 adaptiveDetents의 .large 폼 시트).
    /// iPhone·좁은 창의 시트는 그대로 — 크기 지정은 폼/페이지 시트로 뜰 때(넓은 창)만 쓰인다
    @ViewBuilder
    func pageSizedSheet() -> some View {
        if #available(iOS 18, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }

    /// 페이지 크기 시트(넓은 창)에서 폼을 결과 바와 같은 폭(700pt)으로 가운데에 모은다. 시트 안의 크기 클래스로는
    /// 알 수 없어(폼 시트는 iPad에서도 compact) readableFormWidth() 대신 띄운 창의 폭(windowIsRegular)을 본다 —
    /// iPhone·좁은 창은 그대로
    func readableSheetWidth() -> some View { modifier(ReadableSheetWidth()) }
}

private struct ReadableSheetWidth: ViewModifier {
    @Environment(\.windowIsRegular) private var windowIsRegular

    func body(content: Content) -> some View {
        if windowIsRegular {
            GeometryReader { proxy in
                content.contentMargins(
                    .horizontal, max(20, (proxy.size.width - 700) / 2), for: .scrollContent)
            }
        } else {
            content
        }
    }
}
