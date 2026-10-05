import Foundation
import LevainCore
import os

/// 진단 기록 (통합 로그) — Mac의 Console.app에서 `subsystem:com.narudoc.doughmetry`로 거르거나 sysdiagnose로 받는다.
/// 기기 밖으로 나가지 않으므로 개인정보 라벨('수집하지 않음')은 그대로다.
/// - 요약은 .notice, 실패는 .error — .info·.debug는 기기에 남지 않아 나중에 볼 수 없다.
/// - 레시피 이름·메모·JSON은 남기지 않는다. 개수와 오류 도메인·코드만.
enum Log {
    static let sync = Logger(subsystem: "com.narudoc.doughmetry", category: "sync")
    static let storage = Logger(subsystem: "com.narudoc.doughmetry", category: "storage")
    /// AI 초안 시간 초과·기각 사유 (RecipeImporter)
    static let importer = Logger(subsystem: "com.narudoc.doughmetry", category: "import")
}

/// 오류의 도메인·코드 — 조정 접근·파일 오류는 진짜 원인을 NSUnderlyingErrorKey에 담아 오므로 그것도 붙인다.
/// localizedDescription은 쓰지 않는다 (기기 언어로 나오고 경로가 섞인다)
func errorCode(_ error: any Error) -> String {
    let ns = error as NSError
    var code = "\(ns.domain) \(ns.code)"
    if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
        code += " ← \(underlying.domain) \(underlying.code)"
    }
    return code
}

extension LibraryDocument {
    /// 개수 요약 — 내용은 남기지 않는다
    var logSummary: String { "\(recipes.count)r/\(logs.count)l/\(deleted.count)t" }
}
