import LevainCore
import SwiftUI
import UserNotifications
import os

/// 단계 이름 (kind → 현재 언어)
func stageName(_ s: TimelineStage) -> String {
    switch s.kind {
    case .levainBuild: return L("르방 빌드")
    case .autolyse: return L("오토리즈")
    case .mix: return L("믹싱")
    case .bulk: return L("벌크 발효")
    case .divide: return L("분할")
    case .bench: return L("벤치 타임")
    case .shape: return L("성형")
    case .proof: return L("최종 발효")
    case .coldRetard: return L("냉장 발효")
    case .bake: return L("굽기")
    case .custom:
        let name = s.customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? L("사용자 단계") : name
    }
}

/// 타임라인 알림 — 각 단계가 끝나는 시각에 "다음 단계" 알림
@MainActor
enum TimelineNotifier {
    nonisolated static let prefix = "timeline."
    /// center.delegate는 weak라 여기서 붙잡아 둔다
    private static let presenter = ForegroundPresenter()
    private static var followingLanguage = false
    /// 예약·취소마다 올린다 — 문구를 바꾸는 사이 재예약·취소가 끼면 옛 요청을 되살리지 않도록.
    /// 언어가 바뀐 그 순간(격리 밖 onChange)의 값을 떠야 해서 MainActor 변수가 아니라 잠금으로 둔다.
    nonisolated private static let generation = OSAllocatedUnfairLock(initialState: 0)

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default: return false
        }
    }

    static func cancelAll() async {
        generation.withLock { $0 += 1 }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
    }

    static func pendingCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(prefix) }.count
    }

    /// 앱이 앞에 떠 있을 때도 단계 알림 배너를 띄운다. 앱 시작 때 불리므로 언어 관찰도 여기서 건다.
    static func presentInForeground() {
        let center = UNUserNotificationCenter.current()
        if center.delegate == nil { center.delegate = presenter }
        if !followingLanguage {
            followingLanguage = true
            followLanguage()
            // iOS 설정 → 앱 → 언어로 바꾸면 Lang.init에서 바뀌어 관찰에 안 걸린다 — 시작 때 한 번 맞춘다
            let gen = generation.withLock { $0 }
            Task { await relocalizePending(ifStill: gen) }
        }
    }

    /// 언어 선택은 설정 시트(레시피 탭)에 있어 타임라인 화면이 떠 있지 않아도 따라가야 한다
    private static func followLanguage() {
        withObservationTracking {
            _ = Lang.shared.current
        } onChange: {
            // 값이 바뀌기 직전(willSet)에 불린다 — 새 언어는 다음 차례에 읽힌다
            let gen = generation.withLock { $0 }
            Task { @MainActor in
                followLanguage()
                await relocalizePending(ifStill: gen)
            }
        }
    }

    /// 알림 문구는 예약 시점 언어로 굳는다 — 다시 만들 수 있게 단계 종류·이름을 userInfo에 싣는다
    private static func makeContent(stage: TimelineStage, next: TimelineStage?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = next.map { LF("다음 단계: %@", stageName($0)) } ?? L("완성! 빵을 꺼낼 시간")
        content.body = LF("%@ 끝", stageName(stage))
        content.sound = .default
        content.userInfo = [
            "kind": stage.kind.rawValue, "custom": stage.customName,
            "nextKind": next?.kind.rawValue ?? "", "nextCustom": next?.customName ?? "",
        ]
        return content
    }

    private static func stage(from info: [AnyHashable: Any], kind: String, custom: String) -> TimelineStage? {
        guard let raw = info[kind] as? String, let k = StageKind(rawValue: raw) else { return nil }
        return TimelineStage(kind: k, customName: info[custom] as? String ?? "", minutes: 0)
    }

    /// 대기 중인 알림 문구를 현재 언어로 바꾼다. 같은 식별자·트리거로 다시 넣으므로 울릴 시각은 그대로다.
    /// 대기 중인 알림이 없으면(알림을 켜 두지 않았으면) 아무것도 하지 않는다.
    private static func relocalizePending(ifStill gen: Int) async {
        let center = UNUserNotificationCenter.current()
        for req in await center.pendingNotificationRequests() where req.identifier.hasPrefix(prefix) {
            let info = req.content.userInfo
            guard let s = stage(from: info, kind: "kind", custom: "custom") else { continue }
            let content = makeContent(stage: s, next: stage(from: info, kind: "nextKind", custom: "nextCustom"))
            guard content.title != req.content.title || content.body != req.content.body,
                (req.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() != nil
            else { continue }
            guard gen == generation.withLock({ $0 }) else { return }
            try? await center.add(
                UNNotificationRequest(identifier: req.identifier, content: content, trigger: req.trigger))
        }
    }

    struct ScheduleResult {
        var added = 0
        var future = 0
        var error: Error?
    }

    /// 예약 결과: 성공 건수, 아직 끝나지 않은 단계 수(이미 지난 시각은 건너뜀), 첫 실패.
    /// 성공 0건이 "모두 지남"인지 예약 실패인지 가려야 안내가 틀리지 않는다
    static func schedule(_ scheduled: [ScheduledStage]) async -> ScheduleResult {
        await cancelAll()
        let center = UNUserNotificationCenter.current()
        var r = ScheduleResult()
        for (i, s) in scheduled.enumerated() where s.end > Date() {
            if Task.isCancelled { break }
            r.future += 1
            let next = i + 1 < scheduled.count ? scheduled[i + 1].stage : nil
            let req = UNNotificationRequest(
                identifier: prefix + s.stage.id, content: makeContent(stage: s.stage, next: next),
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: absoluteDateComponents(for: s.end), repeats: false))
            do {
                try await center.add(req)
                r.added += 1
            } catch {
                if r.error == nil { r.error = error }
            }
        }
        return r
    }
}

private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix(TimelineNotifier.prefix) ? [.banner, .list, .sound] : []
    }
}

/// 타임라인 계획 저장 (로컬, UserDefaults)
@Observable @MainActor
final class TimelineStore {
    var plan: TimelinePlan {
        didSet {
            if let data = try? JSONEncoder().encode(plan) {
                UserDefaults.standard.set(data, forKey: "timeline.plan")
            }
            if alertsArmed, plan != oldValue { rescheduleSoon() }
        }
    }
    var scheduledCount: Int = UserDefaults.standard.integer(forKey: "timeline.scheduledCount") {
        didSet { UserDefaults.standard.set(scheduledCount, forKey: "timeline.scheduledCount") }
    }
    /// 사용자가 알림을 켜 둔 상태. scheduledCount와 따로 두는 이유: 편집 도중(날짜만 먼저 바꾸는 등)
    /// 모든 단계가 잠깐 과거가 되어 0개로 떨어져도 이어지는 편집을 계속 따라가 다시 예약해야 한다.
    private(set) var alertsArmed = false
    /// 뷰의 .task가 아니라 스토어가 쥔다 — 편집 직후 뒤로 가도 재예약이 취소되지 않게
    @ObservationIgnored private var rescheduling: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: "timeline.plan"),
            var p = try? JSONDecoder().decode(TimelinePlan.self, from: data)
        {
            // 분 칸에 상한이 없던 판이 저장한 값(1e19 등)은 표시의 Int 변환에서 앱을 멈춘다
            p.stages = p.stages.map {
                var s = $0
                s.minutes = s.minutes.isFinite ? min(max(s.minutes, 0), 10080).rounded() : 0
                return s
            }
            plan = p
        } else {
            plan = TimelinePlan.defaultPlan(startingAt: isoString(from: Date()))
        }
    }

    /// 입력 한 글자마다 지우고 다시 넣지 않도록 잠시 모았다가 재예약
    private func rescheduleSoon() {
        rescheduling?.cancel()
        rescheduling = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, alertsArmed else { return }
            let r = await TimelineNotifier.schedule(scheduleTimeline(plan))
            if !Task.isCancelled { scheduledCount = r.added }
        }
    }

    func scheduleAlerts() async -> TimelineNotifier.ScheduleResult {
        rescheduling?.cancel()
        let r = await TimelineNotifier.schedule(scheduleTimeline(plan))
        scheduledCount = r.added
        alertsArmed = r.added > 0
        return r
    }

    func cancelAlerts() async {
        rescheduling?.cancel()
        alertsArmed = false
        await TimelineNotifier.cancelAll()
        scheduledCount = 0
    }

    /// 울린 알림은 대기 목록에서 빠지므로 저장해 둔 건수 대신 실제 대기 건수를 따른다
    func refreshPending() async {
        let n = await TimelineNotifier.pendingCount()
        scheduledCount = n
        alertsArmed = n > 0
    }
}

struct TimelineView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var store = TimelineStore()
    @State private var permissionDenied = false
    @State private var allStagesPast = false
    /// 예약 실패 사유 — 빈 문자열이면 사유 없이 안내만
    @State private var scheduleError: String?
    @State private var scheduledFeedback = false
    @State private var showAddStage = false
    @FocusState private var focusedName: String?

    private var anchorIsFinish: Bool {
        if case .finish = store.plan.anchor { return true }
        return false
    }

    private var anchorDate: Binding<Date> {
        Binding(
            get: {
                switch store.plan.anchor {
                case .start(let iso), .finish(let iso): return parseISO(iso) ?? Date()
                }
            },
            set: { d in
                store.plan.anchor = anchorIsFinish ? .finish(isoString(from: d)) : .start(isoString(from: d))
            })
    }

    /// 사용자 단계 이름 — 분 입력과 같은 이유로 인덱스가 아니라 id로 찾는다
    private func customName(_ id: String) -> Binding<String> {
        Binding(
            get: { store.plan.stages.first { $0.id == id }?.customName ?? "" },
            set: { v in
                if let j = store.plan.stages.firstIndex(where: { $0.id == id }) {
                    store.plan.stages[j].customName = v
                }
            })
    }

    var body: some View {
        let scheduled = scheduleTimeline(store.plan)
        Form {
            Section {
                Picker(L("기준"), selection: Binding(
                    get: { anchorIsFinish ? 1 : 0 },
                    set: { v in
                        let d = anchorDate.wrappedValue
                        store.plan.anchor = v == 1 ? .finish(isoString(from: d)) : .start(isoString(from: d))
                    })
                ) {
                    Text(L("시작 시각")).tag(0)
                    Text(L("완성 시각")).tag(1)
                }
                .pickerStyle(.segmented)
                DatePicker(
                    anchorIsFinish ? L("빵이 완성될 시각") : L("첫 단계 시작"),
                    selection: anchorDate, displayedComponents: [.date, .hourAndMinute])
                Button {
                    store.plan.anchor = .start(isoString(from: Date()))
                } label: {
                    Label(L("지금 시작"), systemImage: "play.circle")
                }
                LabeledContent(L("총 소요")) {
                    StatValue(value: fmtDuration(store.plan.totalMinutes))
                }
            } header: {
                Text(L("일정"))
            }

            Section {
                ForEach(scheduled, id: \.stage.id) { s in
                    let id = s.stage.id
                    // 접근성 글자 크기에선 분 칸을 아랫줄로 — 폭 120 고정 칸에선 세 자리 분이 "2…"로 잘린다
                    let layout =
                        typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
                    layout {
                        VStack(alignment: .leading, spacing: 2) {
                            if s.stage.kind == .custom {
                                TextField(L("사용자 단계"), text: customName(id))
                                    .focused($focusedName, equals: id)
                                    .submitLabel(.done)
                            } else {
                                Text(stageName(s.stage))
                            }
                            Text("\(fmtClock(s.start)) → \(fmtClock(s.end))")
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 인덱스를 잡아 두면 삭제된 마지막 행의 바인딩이 한 번 더 읽혀 범위를 벗어난다 — id로 찾는다
                        NumberField(
                            label: "",
                            value: Binding(
                                get: { store.plan.stages.first { $0.id == id }?.minutes ?? s.stage.minutes },
                                set: { v in
                                    if let j = store.plan.stages.firstIndex(where: { $0.id == id }) {
                                        store.plan.stages[j].minutes = v
                                    }
                                }),
                            unit: L("분"), maxValue: 10080, integer: true,
                            accessibilityName: stageName(s.stage))
                            .frame(width: typeSize.isAccessibilitySize ? nil : 120)
                    }
                    // onDelete의 시스템 "삭제"는 앱 언어가 아니라 번들 현지화를 따른다 — 밀기 버튼은 직접 달고
                    // onDelete는 편집 모드의 삭제 표시(−)용으로만 둔다. 앱 tint(bottle)가 destructive의 빨강을 덮는다
                    .swipeActions {
                        Button(L("삭제"), role: .destructive) {
                            store.plan.stages.removeAll { $0.id == id }
                        }
                        .tint(Color.danger)
                    }
                }
                .onDelete { store.plan.stages.remove(atOffsets: $0) }
                .onMove { store.plan.stages.move(fromOffsets: $0, toOffset: $1) }
                Menu {
                    ForEach(StageKind.allCases, id: \.self) { kind in
                        Button(stageName(TimelineStage(kind: kind, minutes: 0))) {
                            let stage = TimelineStage(kind: kind, minutes: kind == .coldRetard ? 720 : 30)
                            store.plan.stages.append(stage)
                            if kind == .custom { focusedName = stage.id }
                        }
                    }
                } label: {
                    Label(L("단계 추가"), systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text(L("단계"))
                    Spacer()
                    LocalizedEditButton().font(.caption)
                }
            } footer: {
                Text(L("길게 눌러 순서를 바꾸고, 밀어서 삭제합니다. 냉장 발효는 12시간(720분)이 기본입니다."))
            }

            Section {
                Button {
                    Task {
                        guard await TimelineNotifier.requestPermission() else {
                            permissionDenied = true
                            return
                        }
                        let r = await store.scheduleAlerts()
                        if r.added > 0 {
                            scheduledFeedback.toggle()
                        } else if r.future == 0 {
                            allStagesPast = true
                        } else {
                            scheduleError = r.error?.localizedDescription ?? ""
                        }
                    }
                } label: {
                    Label(L("단계 알림 예약"), systemImage: "bell.badge")
                }
                // 단계가 없으면 "모든 단계가 이미 지났습니다"로 잘못 안내된다
                .disabled(store.plan.stages.isEmpty)
                if store.scheduledCount > 0 {
                    LabeledContent(L("예약된 알림")) {
                        Text(LF("%d개", store.scheduledCount)).foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        Task { await store.cancelAlerts() }
                    } label: {
                        Label(L("알림 취소"), systemImage: "bell.slash")
                    }
                }
            } footer: {
                Text(L("각 단계가 끝나는 시각에 다음 단계 알림이 옵니다. 앱을 닫아도 울립니다."))
            }
        }
        .navigationTitle(L("타임라인"))
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.success, trigger: scheduledFeedback)
        .task {
            TimelineNotifier.presentInForeground()
            await store.refreshPending()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refreshPending() } }
        }
        .alert(L("알림 권한이 꺼져 있습니다"), isPresented: $permissionDenied) {
            Button(L("확인"), role: .cancel) {}
        } message: {
            Text(L("설정 앱 → 알림에서 이 앱의 알림을 허용해 주세요."))
        }
        .alert(L("모든 단계가 이미 지났습니다"), isPresented: $allStagesPast) {
            Button(L("확인"), role: .cancel) {}
        } message: {
            Text(L("시작 시각을 바꾸거나 '지금 시작'을 누른 뒤 다시 예약하세요."))
        }
        .alert(
            L("알림을 예약하지 못했습니다"),
            isPresented: Binding(get: { scheduleError != nil }, set: { if !$0 { scheduleError = nil } })
        ) {
            Button(L("확인"), role: .cancel) {}
        } message: {
            Text(L("잠시 후 다시 시도하세요.") + (scheduleError.map { $0.isEmpty ? "" : "\n\n" + $0 } ?? ""))
        }
    }

    private func fmtClock(_ d: Date) -> String {
        let cal = Calendar.current
        let time = fmtTime(d)
        if cal.isDateInToday(d) { return time }
        if cal.isDateInTomorrow(d) { return L("내일") + " " + time }
        return fmtMonthDay(d) + " " + time
    }

    private func fmtDuration(_ minutes: Double) -> String {
        let m = clampedInt(minutes)
        return m >= 60 ? LF("%d시간 %d분", m / 60, m % 60) : LF("%d분", m)
    }
}
