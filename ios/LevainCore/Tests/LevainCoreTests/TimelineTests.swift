import Foundation
import Testing
@testable import LevainCore

@Suite("타임라인 스케줄러")
struct TimelineTests {
    @Test("기본 일정은 시작 시각부터 순차 배치되고 총 460분")
    func forward() throws {
        let plan = TimelinePlan.defaultPlan(startingAt: "2026-09-06T08:00:00Z")
        #expect(plan.totalMinutes == 460)
        let s = scheduleTimeline(plan)
        #expect(s.count == 8)
        #expect(s.first?.start == parseISO("2026-09-06T08:00:00Z"))
        #expect(s.last?.end == parseISO("2026-09-06T15:40:00Z"))
        // 연속성: 각 단계의 시작 = 이전 단계의 종료
        for i in 1..<s.count { #expect(s[i].start == s[i - 1].end) }
    }

    @Test("완성 시각 기준이면 역산해 시작 시각이 정해진다")
    func backward() throws {
        var plan = TimelinePlan.defaultPlan(startingAt: "x")
        plan.anchor = .finish("2026-09-06T18:00:00Z")
        let s = scheduleTimeline(plan)
        #expect(s.last?.end == parseISO("2026-09-06T18:00:00Z"))
        #expect(s.first?.start == parseISO("2026-09-06T10:20:00Z"))  // 18:00 − 7h40m
    }

    @Test("0분·음수 단계는 길이 0으로 취급되고 순서는 유지된다")
    func zeroStage() {
        let plan = TimelinePlan(
            stages: [
                TimelineStage(kind: .mix, minutes: 10),
                TimelineStage(kind: .custom, customName: "메모", minutes: -5),
                TimelineStage(kind: .bake, minutes: 40),
            ], anchor: .start("2026-09-06T08:00:00Z"))
        let s = scheduleTimeline(plan)
        #expect(s[1].start == s[1].end)
        #expect(s[2].end == parseISO("2026-09-06T08:50:00Z"))
    }

    @Test("Codable 왕복 (앱 저장용)")
    func codable() throws {
        let plan = TimelinePlan.defaultPlan(startingAt: "2026-09-06T08:00:00Z")
        let data = try JSONEncoder().encode(plan)
        #expect(try JSONDecoder().decode(TimelinePlan.self, from: data) == plan)
    }
}
