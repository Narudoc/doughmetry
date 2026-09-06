import LevainCore
import SwiftUI
import UserNotifications

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
    case .custom: return s.customName.isEmpty ? L("사용자 단계") : s.customName
    }
}

/// 타임라인 알림 — 각 단계가 끝나는 시각에 "다음 단계" 알림
@MainActor
enum TimelineNotifier {
    static let prefix = "timeline."

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
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
    }

    /// 예약된 건수를 돌려준다 (이미 지난 시각은 건너뜀)
    static func schedule(_ scheduled: [ScheduledStage]) async -> Int {
        await cancelAll()
        let center = UNUserNotificationCenter.current()
        var count = 0
        for (i, s) in scheduled.enumerated() where s.end > Date() {
            let content = UNMutableNotificationContent()
            let next = i + 1 < scheduled.count ? scheduled[i + 1] : nil
            content.title = next.map { LF("다음 단계: %@", stageName($0.stage)) } ?? L("완성! 빵을 꺼낼 시간")
            content.body = LF("%@ 끝", stageName(s.stage))
            content.sound = .default
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: s.end)
            let req = UNNotificationRequest(
                identifier: prefix + s.stage.id, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            if (try? await center.add(req)) != nil { count += 1 }
        }
        return count
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
        }
    }
    var scheduledCount: Int = UserDefaults.standard.integer(forKey: "timeline.scheduledCount") {
        didSet { UserDefaults.standard.set(scheduledCount, forKey: "timeline.scheduledCount") }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "timeline.plan"),
            let p = try? JSONDecoder().decode(TimelinePlan.self, from: data)
        {
            plan = p
        } else {
            plan = TimelinePlan.defaultPlan(startingAt: isoString(from: Date()))
        }
    }
}

struct TimelineView: View {
    @State private var store = TimelineStore()
    @State private var permissionDenied = false
    @State private var scheduledFeedback = false
    @State private var showAddStage = false

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
                ForEach(Array(scheduled.enumerated()), id: \.element.stage.id) { i, s in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stageName(s.stage))
                            Text("\(fmtClock(s.start)) → \(fmtClock(s.end))")
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        Spacer()
                        NumberField(
                            label: "",
                            value: Binding(
                                get: { store.plan.stages[i].minutes },
                                set: { store.plan.stages[i].minutes = $0 }),
                            unit: L("분"), fractionDigits: 0)
                            .frame(width: 120)
                    }
                }
                .onDelete { store.plan.stages.remove(atOffsets: $0) }
                .onMove { store.plan.stages.move(fromOffsets: $0, toOffset: $1) }
                Menu {
                    ForEach(StageKind.allCases, id: \.self) { kind in
                        Button(stageName(TimelineStage(kind: kind, minutes: 0))) {
                            store.plan.stages.append(TimelineStage(kind: kind, minutes: kind == .coldRetard ? 720 : 30))
                        }
                    }
                } label: {
                    Label(L("단계 추가"), systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text(L("단계"))
                    Spacer()
                    EditButton().font(.caption)
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
                        store.scheduledCount = await TimelineNotifier.schedule(scheduled)
                        scheduledFeedback.toggle()
                    }
                } label: {
                    Label(L("단계 알림 예약"), systemImage: "bell.badge")
                }
                if store.scheduledCount > 0 {
                    LabeledContent(L("예약된 알림")) {
                        Text(LF("%d개", store.scheduledCount)).foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        Task {
                            await TimelineNotifier.cancelAll()
                            store.scheduledCount = 0
                        }
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
        .alert(L("알림 권한이 꺼져 있습니다"), isPresented: $permissionDenied) {
            Button(L("확인"), role: .cancel) {}
        } message: {
            Text(L("설정 앱 → 알림에서 이 앱의 알림을 허용해 주세요."))
        }
    }

    private func fmtClock(_ d: Date) -> String {
        let cal = Calendar.current
        let time = d.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(d) { return time }
        if cal.isDateInTomorrow(d) { return L("내일") + " " + time }
        return d.formatted(.dateTime.month(.defaultDigits).day()) + " " + time
    }

    private func fmtDuration(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return m >= 60 ? LF("%d시간 %d분", m / 60, m % 60) : LF("%d분", m)
    }
}
