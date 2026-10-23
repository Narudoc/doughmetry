import Foundation

// MARK: - 타임라인 스케줄러

public enum StageKind: String, Codable, CaseIterable, Sendable {
    case levainBuild  // 르방 빌드(리프레시)
    case autolyse
    case mix
    case bulk
    case divide
    case bench
    case shape
    case proof
    case coldRetard
    case bake
    case custom

    /// 보통 하는 순서 — 새 단계를 넣을 자리를 정할 때만 쓴다 (사용자 단계는 순서를 알 수 없어 nil)
    var naturalRank: Int? {
        switch self {
        case .levainBuild: return 0
        case .autolyse: return 1
        case .mix: return 2
        case .bulk: return 3
        case .divide: return 4
        case .bench: return 5
        case .shape: return 6
        case .coldRetard: return 7
        case .proof: return 8
        case .bake: return 9
        case .custom: return nil
        }
    }
}

public struct TimelineStage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: StageKind
    /// custom일 때 표시 이름 (그 외는 UI가 kind로 번역)
    public var customName: String
    public var minutes: Double

    public init(id: String = newId(), kind: StageKind, customName: String = "", minutes: Double) {
        self.id = id
        self.kind = kind
        self.customName = customName
        self.minutes = minutes
    }

    /// 단계를 새로 넣을 때의 기본 길이(분) — 르방 빌드는 피크까지 6시간, 냉장 발효는 하룻밤 12시간
    public static func defaultMinutes(for kind: StageKind) -> Double {
        switch kind {
        case .levainBuild: return 360
        case .coldRetard: return 720
        default: return 30
        }
    }
}

public struct TimelinePlan: Codable, Equatable, Sendable {
    public enum Anchor: Codable, Equatable, Sendable {
        case start(String) // ISO — 이 시각에 첫 단계 시작
        case finish(String) // ISO — 이 시각에 마지막 단계 종료 (역산)
    }

    public var stages: [TimelineStage]
    public var anchor: Anchor

    public init(stages: [TimelineStage], anchor: Anchor) {
        self.stages = stages
        self.anchor = anchor
    }

    public var totalMinutes: Double { stages.reduce(0) { $0 + max(0, $1.minutes) } }

    /// 기준만 시작 ↔ 완성으로 바꾼다. 일정(각 단계 시각)은 그대로 — 같은 첫 단계 시작을 새 기준의 시각으로 옮겨 적는다.
    /// 이미 그 기준이거나 시각을 읽을 수 없으면 그대로 둔다
    public mutating func setAnchorKind(finish: Bool) {
        switch anchor {
        case .start(let iso):
            guard finish, let start = parseISO(iso) else { return }
            anchor = .finish(isoString(from: start.addingTimeInterval(totalMinutes * 60)))
        case .finish(let iso):
            guard !finish, let end = parseISO(iso) else { return }
            anchor = .start(isoString(from: end.addingTimeInterval(-totalMinutes * 60)))
        }
    }

    /// 맨 앞에 르방 빌드 단계를 넣는다 (이미 있으면 그대로 두고 false).
    /// 완성 시각 기준이면 시작이 그만큼 앞당겨져 르방을 먹일 시각이 되고, 시작 시각 기준이면 뒤 단계가 그만큼 밀린다
    @discardableResult
    public mutating func prependLevainBuild() -> Bool {
        guard !stages.contains(where: { $0.kind == .levainBuild }) else { return false }
        stages.insert(
            TimelineStage(kind: .levainBuild, minutes: TimelineStage.defaultMinutes(for: .levainBuild)), at: 0)
        return true
    }

    /// 새 단계를 넣을 자리 — 보통 하는 순서의 제자리(냉장 발효는 성형 뒤, 굽기 앞).
    /// 사용자가 바꿔 둔 순서는 다시 정렬하지 않는다: 순위가 같거나 앞선 마지막 단계 바로 뒤, 없으면 순위가 뒤인 첫 단계 앞.
    /// 굽기 뒤로는 넣지 않는다 — 사용자 단계는 첫 굽기 바로 앞(굽기가 없으면 맨 끝), 굽기를 하나 더 넣으면 맨 끝
    public static func insertionIndex(for kind: StageKind, in stages: [TimelineStage]) -> Int {
        if kind == .bake { return stages.count }
        let firstBake = stages.firstIndex { $0.kind == .bake } ?? stages.count
        guard let rank = kind.naturalRank else { return firstBake }
        if let last = stages.lastIndex(where: { ($0.kind.naturalRank ?? .max) <= rank }) {
            return min(last + 1, firstBake)
        }
        return stages.firstIndex { ($0.kind.naturalRank ?? -1) > rank } ?? 0
    }

    /// 단계를 제자리(`insertionIndex`)에 넣는다. 다른 단계는 움직이지 않는다 —
    /// 완성 시각 기준이면 완성 시각은 그대로고 앞 단계들의 시작이 그만큼 당겨진다
    public mutating func addStage(_ stage: TimelineStage) {
        stages.insert(stage, at: Self.insertionIndex(for: stage.kind, in: stages))
    }

    /// 기본 사워도우 일정 — 오토리즈 → 믹싱 → 벌크 → 분할 → 벤치 → 성형 → 최종발효 → 굽기
    public static func defaultPlan(startingAt iso: String) -> TimelinePlan {
        TimelinePlan(
            stages: [
                TimelineStage(kind: .autolyse, minutes: 30),
                TimelineStage(kind: .mix, minutes: 15),
                TimelineStage(kind: .bulk, minutes: 240),
                TimelineStage(kind: .divide, minutes: 10),
                TimelineStage(kind: .bench, minutes: 20),
                TimelineStage(kind: .shape, minutes: 10),
                TimelineStage(kind: .proof, minutes: 90),
                TimelineStage(kind: .bake, minutes: 45),
            ],
            anchor: .start(iso))
    }
}

public struct ScheduledStage: Equatable, Sendable {
    public var stage: TimelineStage
    public var start: Date
    public var end: Date
}

/// 단계별 시작·종료 시각. 완성 시각 기준이면 총 소요를 빼서 시작 시각을 구한다.
public func scheduleTimeline(_ plan: TimelinePlan) -> [ScheduledStage] {
    let startDate: Date
    switch plan.anchor {
    case .start(let iso):
        guard let d = parseISO(iso) else { return [] }
        startDate = d
    case .finish(let iso):
        guard let d = parseISO(iso) else { return [] }
        startDate = d.addingTimeInterval(-plan.totalMinutes * 60)
    }
    var cursor = startDate
    return plan.stages.map { stage in
        let end = cursor.addingTimeInterval(max(0, stage.minutes) * 60)
        defer { cursor = end }
        return ScheduledStage(stage: stage, start: cursor, end: end)
    }
}

// MARK: - 타임라인 알림

/// 예약할 알림 하나 — 문구는 앱이 현재 언어로 만든다
public struct TimelineAlert: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case start  // 첫 단계 시작 — 완성 시각으로 역산하면 앱이 정해 준 시각이라 가장 놓치기 쉽다
        case end  // 단계 끝 → 다음 단계
        case preheat  // 첫 굽기 시작 몇 분 전 오븐 예열
    }

    /// 한 번의 예약 안에서 겹치지 않는 꼬리 (단계 id 기반) — 앱이 접두어·예약 토큰을 앞에 붙인다
    public var id: String
    public var date: Date
    public var kind: Kind
    /// 알림이 가리키는 단계(`scheduleTimeline` 결과의 인덱스) — 시작은 첫 단계, 끝은 끝나는 단계, 예열은 첫 굽기
    public var stageIndex: Int
}

/// iOS는 앱마다 대기 알림을 울릴 시각이 가까운 64개만 남긴다
public let timelineAlertLimit = 64

/// 예약할 알림 — 첫 단계 시작, 각 단계 끝, `preheatMinutes`가 있으면 첫 굽기 시작 그만큼 전의 예열.
/// `now`보다 늦은 것만 시각 순으로(같은 시각이면 시작 → 끝 → 예열), 가까운 `timelineAlertLimit`개까지
public func timelineAlerts(_ scheduled: [ScheduledStage], preheatMinutes: Int? = nil, now: Date) -> [TimelineAlert] {
    var alerts: [TimelineAlert] = []
    if let first = scheduled.first {
        alerts.append(TimelineAlert(id: first.stage.id + ".start", date: first.start, kind: .start, stageIndex: 0))
    }
    for (i, s) in scheduled.enumerated() {
        alerts.append(TimelineAlert(id: s.stage.id, date: s.end, kind: .end, stageIndex: i))
    }
    if let minutes = preheatMinutes, let i = scheduled.firstIndex(where: { $0.stage.kind == .bake }) {
        let bake = scheduled[i]
        alerts.append(
            TimelineAlert(
                id: bake.stage.id + ".preheat", date: bake.start.addingTimeInterval(-Double(max(0, minutes)) * 60),
                kind: .preheat, stageIndex: i))
    }
    return alerts.enumerated()
        .filter { $0.element.date > now }
        .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
        .prefix(timelineAlertLimit)
        .map(\.element)
}

/// 알림 트리거(UNCalendarNotificationTrigger)용 날짜 성분 — UTC 그레고리력과 시간대를 성분에 함께 싣는다.
/// 기기 시간대의 벽시계 성분은 서머타임이 끝나는 밤 반복되는 한 시간에서 앞쪽 시각으로 풀리고,
/// 시간대를 옮기면 그곳 벽시계 기준으로 밀린다.
public func absoluteDateComponents(for date: Date) -> DateComponents {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = .gmt
    return utc.dateComponents(
        [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: date)
}
