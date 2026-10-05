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

    @Test("기준을 시작 ↔ 완성으로 바꿔도 일정은 그대로다 (같은 시각을 새 기준으로 옮겨 적음)")
    func anchorKindKeepsSchedule() {
        let plan = TimelinePlan.defaultPlan(startingAt: "2026-09-06T08:00:00Z")
        var finish = plan
        finish.setAnchorKind(finish: true)
        #expect(finish.anchor == .finish("2026-09-06T15:40:00Z"))
        #expect(scheduleTimeline(finish) == scheduleTimeline(plan))

        var back = finish
        back.setAnchorKind(finish: false)
        #expect(back.anchor == .start("2026-09-06T08:00:00Z"))
        #expect(back == plan)

        // 이미 그 기준이면 그대로
        var same = plan
        same.setAnchorKind(finish: false)
        #expect(same == plan)
        var sameFinish = finish
        sameFinish.setAnchorKind(finish: true)
        #expect(sameFinish == finish)

        // 읽을 수 없는 시각은 건드리지 않는다
        var broken = TimelinePlan.defaultPlan(startingAt: "x")
        broken.setAnchorKind(finish: true)
        #expect(broken.anchor == .start("x"))

        // 단계가 없으면 시작 = 완성
        var empty = TimelinePlan(stages: [], anchor: .start("2026-09-06T08:00:00Z"))
        empty.setAnchorKind(finish: true)
        #expect(empty.anchor == .finish("2026-09-06T08:00:00Z"))
    }

    @Test("새 단계 기본 길이 — 르방 빌드 6시간, 냉장 발효 12시간, 나머지 30분")
    func defaultMinutes() {
        #expect(TimelineStage.defaultMinutes(for: .levainBuild) == 360)
        #expect(TimelineStage.defaultMinutes(for: .coldRetard) == 720)
        for kind in StageKind.allCases where kind != .levainBuild && kind != .coldRetard {
            #expect(TimelineStage.defaultMinutes(for: kind) == 30, "\(kind)")
        }
    }

    @Test("르방 빌드는 맨 앞에 한 번만 — 완성 기준이면 시작(르방 먹일 시각)이 앞당겨지고, 시작 기준이면 뒤 단계가 밀린다")
    func prependLevainBuild() {
        var finish = TimelinePlan.defaultPlan(startingAt: "x")
        finish.anchor = .finish("2026-09-06T18:00:00Z")
        let added = finish.prependLevainBuild()
        #expect(added)
        #expect(finish.stages.count == 9)
        #expect(finish.stages.first?.kind == .levainBuild)
        #expect(finish.stages.first?.minutes == 360)
        let f = scheduleTimeline(finish)
        #expect(f.first?.start == parseISO("2026-09-06T04:20:00Z"))  // 10:20 − 6h
        #expect(f[1].start == parseISO("2026-09-06T10:20:00Z"))  // 오토리즈는 그대로
        #expect(f.last?.end == parseISO("2026-09-06T18:00:00Z"))
        let addedAgain = finish.prependLevainBuild()
        #expect(!addedAgain)
        #expect(finish.stages.count == 9)

        var start = TimelinePlan.defaultPlan(startingAt: "2026-09-06T08:00:00Z")
        start.prependLevainBuild()
        let s = scheduleTimeline(start)
        #expect(s.first?.start == parseISO("2026-09-06T08:00:00Z"))
        #expect(s[1].start == parseISO("2026-09-06T14:00:00Z"))
        #expect(s.last?.end == parseISO("2026-09-06T21:40:00Z"))

        // 사용자가 이미 넣어 둔 르방 빌드가 있으면(맨 앞이 아니어도) 하나 더 넣지 않는다
        var existing = TimelinePlan.defaultPlan(startingAt: "2026-09-06T08:00:00Z")
        existing.stages.insert(TimelineStage(kind: .levainBuild, minutes: 240), at: 2)
        let before = existing
        let addedToExisting = existing.prependLevainBuild()
        #expect(!addedToExisting)
        #expect(existing == before)
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
