import LevainCore
import StoreKit
import SwiftUI

/// 별점 입력/표시 — 같은 별을 다시 누르면 해제
struct StarRating: View {
    @Binding var rating: Int?
    let interactive: Bool
    /// 기본 글자 크기에서의 pt — Dynamic Type을 따라 커진다
    @ScaledMetric private var size: CGFloat

    init(rating: Binding<Int?>, interactive: Bool = true, size: CGFloat = 22) {
        _rating = rating
        self.interactive = interactive
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        let stars = HStack(spacing: interactive ? 0 : 4) {
            ForEach(1...5, id: \.self) { i in
                let star = Image(systemName: (rating ?? 0) >= i ? "star.fill" : "star")
                    // 입력용은 다섯 칸이 접근성 크기에서도 한 줄에 들어가도록 상한을 둔다
                    .font(.system(size: interactive ? min(size, 40) : size))
                    .foregroundStyle((rating ?? 0) >= i ? Color.bottle : Color.secondary)
                if interactive {
                    // 별마다 44pt 탭 영역 — 기본 스타일 Button 여러 개를 한 Form 행에 두면 행 전체가 한 버튼이 된다
                    star
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .onTapGesture { rating = rating == i ? nil : i }
                } else {
                    star
                }
            }
        }
        .allowsHitTesting(interactive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("별점"))
        .accessibilityValue(rating.map { LF("별 5개 중 %d개", $0) } ?? L("없음"))
        if interactive {
            stars.accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: rating = min(5, (rating ?? 0) + 1)
                case .decrement:
                    let next = (rating ?? 0) - 1
                    rating = next <= 0 ? nil : next
                @unknown default: break
                }
            }
        } else {
            stars
        }
    }
}

/// 베이킹 로그 추가/편집 시트
struct BakeLogSheet: View {
    let recipeId: String
    let existing: BakeLog?
    let onSave: (BakeLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var bakedAt: Date
    @State private var rating: Int?
    @State private var note: String
    @State private var showDiscard = false
    /// 연 시점의 날짜 — 새 기록은 Date()라 뷰가 다시 만들어질 때마다 달라지므로 상태로 한 번만 잡는다
    @State private var initialBakedAt: Date

    init(recipeId: String, existing: BakeLog?, onSave: @escaping (BakeLog) -> Void) {
        self.recipeId = recipeId
        self.existing = existing
        self.onSave = onSave
        let date = existing.flatMap { parseISO($0.bakedAt) } ?? Date()
        _bakedAt = State(initialValue: date)
        _initialBakedAt = State(initialValue: date)
        _rating = State(initialValue: existing?.rating)
        _note = State(initialValue: existing?.note ?? "")
    }

    private var isEdited: Bool {
        bakedAt != initialBakedAt || rating != existing?.rating || note != (existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(L("구운 날짜"), selection: $bakedAt, displayedComponents: [.date])
                    // 접근성 크기에선 별을 라벨 아래 줄로 — 커진 별 다섯 개가 라벨 옆에 들어가지 않는다
                    let ratingLayout =
                        typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
                    ratingLayout {
                        Text(L("별점"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        StarRating(rating: $rating)
                    }
                }
                Section(L("메모")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 140)
                        .font(.callout)
                        .accessibilityLabel(L("메모"))
                }
            }
            .navigationTitle(existing == nil ? L("기록 추가") : L("기록 편집"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) {
                        if isEdited { showDiscard = true } else { dismiss() }
                    }
                    .discardConfirmation(isPresented: $showDiscard) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) {
                        let now = isoNow()
                        onSave(
                            BakeLog(
                                id: existing?.id ?? newId(),
                                recipeId: recipeId,
                                bakedAt: isoString(from: bakedAt),
                                rating: rating,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                createdAt: existing?.createdAt ?? now,
                                updatedAt: now))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isEdited)
    }
}

/// 레시피 노트 편집 시트
struct NoteEditSheet: View {
    let initial: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var showDiscard = false

    init(initial: String, onSave: @escaping (String) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _text = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.callout)
                .padding(8)
                .accessibilityLabel(L("노트"))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L("배합 메모, 발효 시간, 결과 등을 적어두세요"))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .navigationTitle(L("노트 편집"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L("취소")) {
                            if text != initial { showDiscard = true } else { dismiss() }
                        }
                        .discardConfirmation(isPresented: $showDiscard) { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("저장")) {
                            if text != initial { onSave(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(text != initial)
    }
}

/// 베이킹 로그 한 줄
struct BakeLogRow: View {
    let log: BakeLog
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
        VStack(alignment: .leading, spacing: 4) {
            layout {
                Text(fmtDay(iso: log.bakedAt))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .accessibilityLabel(fmtSpokenDate(log.bakedAt))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if log.rating != nil {
                    StarRating(rating: .constant(log.rating), interactive: false, size: 13)
                }
            }
            if !log.note.isEmpty {
                Text(log.note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 탭하면 편집, 밀어서 삭제하는 로그 행 — 레시피 상세와 전체 기록 화면이 같이 쓴다
struct EditableBakeLogRow: View {
    @Environment(AppModel.self) private var model
    let log: BakeLog
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            BakeLogRow(log: log)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        // onDelete의 시스템 "삭제"는 앱 언어가 아니라 번들 현지화를 따른다
        .swipeActions {
            // 앱 전체 .tint(.bottle)이 destructive 역할의 빨강을 덮는다
            Button(L("삭제"), role: .destructive) { model.deleteLog(log.id) }
                .tint(Color.danger)
        }
    }
}

/// 레시피의 전체 베이킹 로그 — 상세 화면은 최근 몇 개만 보인다
struct BakeLogListView: View {
    @Environment(AppModel.self) private var model
    let recipeId: String

    @State private var showNewLog = false
    @State private var editingLog: BakeLog?

    var body: some View {
        List {
            Button {
                showNewLog = true
            } label: {
                Label(L("기록 추가"), systemImage: "plus.circle")
            }
            ForEach(model.logs(for: recipeId)) { log in
                EditableBakeLogRow(log: log) { editingLog = log }
            }
        }
        .readableFormWidth()
        .navigationTitle(L("베이킹 로그"))
        .navigationBarTitleDisplayMode(.inline)
        .newBakeLogSheet(isPresented: $showNewLog, recipeId: recipeId)
        .sheet(item: $editingLog) { log in
            BakeLogSheet(recipeId: recipeId, existing: log) { model.saveLog($0) }
        }
    }
}

extension View {
    /// 새 베이킹 로그 시트 — 별점 4개 이상으로 저장하면 시트가 닫힌 뒤 앱 평가를 청한다 (앱 버전마다 한 번).
    /// 편집 저장·계산기·변환기·앱 실행 중에는 청하지 않는다
    func newBakeLogSheet(isPresented: Binding<Bool>, recipeId: String) -> some View {
        modifier(NewBakeLogSheet(isPresented: isPresented, recipeId: recipeId))
    }
}

private struct NewBakeLogSheet: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.requestReview) private var requestReview
    @AppStorage("reviewPromptedVersion") private var promptedVersion = ""
    @Binding var isPresented: Bool
    let recipeId: String
    @State private var wantsReview = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: askForReview) {
            BakeLogSheet(recipeId: recipeId, existing: nil) { log in
                model.saveLog(log)
                if (log.rating ?? 0) >= 4 { wantsReview = true }
            }
        }
    }

    private func askForReview() {
        guard wantsReview else { return }
        wantsReview = false
        let version = AppInfo.version
        guard promptedVersion != version else { return }
        promptedVersion = version
        Task { @MainActor in
            // 시트가 다 내려간 뒤에 띄운다 — 닫히는 중에 요청하면 시스템이 무시할 수 있다
            try? await Task.sleep(for: .milliseconds(600))
            requestReview()
        }
    }
}
