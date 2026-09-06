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
