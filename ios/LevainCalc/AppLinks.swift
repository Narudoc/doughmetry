import Foundation

/// 앱 밖으로 나가는 주소 — 한곳에 모아 둔다 (출시 전 점검이 이 주소를 찾는다).
/// privacy·support 페이지는 웹(GitHub Pages)의 public/에서 배포된다
enum AppLinks {
    static let web = URL(string: "https://narudoc.github.io/doughmetry/")!
    static let privacy = URL(string: "https://narudoc.github.io/doughmetry/privacy.html")!
    static let support = URL(string: "https://narudoc.github.io/doughmetry/support.html")!

    /// App Store Connect의 Apple ID(숫자) — 앱 레코드를 만든 뒤에 채운다. nil이면 평가·공유 행을 숨긴다
    static let appStoreID: String? = nil

    static var appStore: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
    }

    static var writeReview: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }

    /// 공유 텍스트 끝줄 — 재료 줄로 읽히지 않도록 g 수량을 넣지 않는다
    static let shareFooter = "— Doughmetry · narudoc.github.io/doughmetry"
}

/// 번들 버전 — 설정의 정보 화면과 앱 평가 요청(버전마다 한 번)이 쓴다
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
}
