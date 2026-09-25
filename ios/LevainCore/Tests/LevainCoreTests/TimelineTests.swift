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

    @Test("계획 비교는 분·순서·삭제·기준 시각 변경을 모두 구분한다 (알림 재예약 트리거)")
    func equalityTracksEdits() {
        let plan = TimelinePlan.defaultPlan(startingAt: "2026-09-06T08:00:00Z")
        #expect(plan == plan)

        var minutes = plan
        minutes.stages[2].minutes = 300
        #expect(minutes != plan)

        var moved = plan
        moved.stages.swapAt(3, 4)
        #expect(moved != plan)

        var removed = plan
        removed.stages.removeLast()
        #expect(removed != plan)

        var restarted = plan
        restarted.anchor = .start("2026-09-07T08:00:00Z")
        #expect(restarted != plan)

        var flipped = plan
        flipped.anchor = .finish("2026-09-06T08:00:00Z")
        #expect(flipped != plan)
    }

    @Test("Codable 왕복 (앱 저장용)")
    func codable() throws {
        let plan = TimelinePlan.defaultPlan(startingAt: "2026-09-06T08:00:00Z")
        let data = try JSONEncoder().encode(plan)
        #expect(try JSONDecoder().decode(TimelinePlan.self, from: data) == plan)
    }

    @Test("이미 저장된 계획(UserDefaults)을 그대로 읽고, 사용자 단계 이름이 저장·비교된다")
    func savedPlanAndCustomName() throws {
        let saved = #"""
            {"stages":[{"kind":"mix","customName":"","minutes":15,"id":"a"},\#
            {"kind":"custom","customName":"폴딩","minutes":30,"id":"b"}],\#
            "anchor":{"start":{"_0":"2026-09-06T08:00:00Z"}}}
            """#
        let plan = try JSONDecoder().decode(TimelinePlan.self, from: Data(saved.utf8))
        #expect(plan.stages.map(\.id) == ["a", "b"])
        #expect(plan.stages.map(\.customName) == ["", "폴딩"])
        #expect(plan.anchor == .start("2026-09-06T08:00:00Z"))

        var renamed = plan
        renamed.stages[1].customName = "오븐 예열"
        #expect(renamed != plan)  // 이름만 바꿔도 알림 재예약 대상
        let data = try JSONEncoder().encode(renamed)
        #expect(try JSONDecoder().decode(TimelinePlan.self, from: data) == renamed)
    }

    @Test("서머타임이 끝나는 밤(뉴욕 2026-11-01)에도 알림 성분은 단계 종료 순간을 그대로 가리킨다")
    func dstFallBackNight() throws {
        // 14:30 EDT 시작, 냉장 발효 12시간 → 01:30 EST(06:30Z). 이 밤 01:30은 두 번 온다.
        let plan = TimelinePlan(
            stages: [TimelineStage(kind: .coldRetard, minutes: 720)],
            anchor: .start("2026-10-31T18:30:00Z"))
        let s = try #require(scheduleTimeline(plan).first)
        let end = try #require(parseISO("2026-11-01T06:30:00Z"))
        #expect(s.end == end)
        #expect(s.end.timeIntervalSince(s.start) == 12 * 3600)

        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let firstPass = end.addingTimeInterval(-3600)  // 01:30 EDT
        let wallClock: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        // 전제: 기기 벽시계 성분으로는 두 01:30을 구분하지 못한다 (알림이 한 시간 일찍 울리던 원인)
        #expect(ny.dateComponents(wallClock, from: end) == ny.dateComponents(wallClock, from: firstPass))

        let comps = absoluteDateComponents(for: s.end)
        #expect(comps.calendar?.identifier == .gregorian)
        #expect(comps.timeZone == .gmt)
        #expect(comps.date == end)
        #expect(absoluteDateComponents(for: firstPass).date == firstPass)
        #expect(comps != absoluteDateComponents(for: firstPass))
        // 어느 시간대에서 풀어도 같은 순간 (시간대를 옮겨도 목록 시각과 알림이 어긋나지 않음)
        for id in ["America/New_York", "Europe/Paris", "Asia/Seoul"] {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = try #require(TimeZone(identifier: id))
            #expect(cal.date(from: comps) == end, "\(id)")
        }
    }
}
