import SwiftUI
import UIKit

/// 웹앱 색 토큰의 iOS 이식 — 라이트/다크 자동 대응.
/// paper 배경 / ink 본문 / bottle 구조색 / brass 계산 결과값 전용 / line 괘선 / danger 오류.
extension Color {
    static let paper = Color(light: 0xF5F2EA, dark: 0x1C1B16)
    static let ink = Color(light: 0x22271F, dark: 0xE9E5D9)
    static let bottle = Color(light: 0x1E4034, dark: 0x8FB8A5)
    static let brass = Color(light: 0x9A6B32, dark: 0xD3A662)
    static let line = Color(light: 0xD9D3C4, dark: 0x3B382E)
    static let danger = Color(light: 0x9E3B2F, dark: 0xD97A6C)
    /// 카드(입력 섹션) 배경 — 웹의 흰 카드에 해당
    static let card = Color(light: 0xFFFFFF, dark: 0x26241D)

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
        })
    }
}

extension Font {
    /// 결과 수치용 — tabular figures
    static func stat(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
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

    var body: some View {
        if let fr {
            Text("\(ko) ").foregroundStyle(.primary)
                + Text(fr).italic().font(.caption).foregroundStyle(.secondary)
        } else {
            Text(ko)
        }
    }
}
