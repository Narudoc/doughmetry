import LevainCore
import SwiftUI

/// 별점 입력/표시 — 같은 별을 다시 누르면 해제
struct StarRating: View {
    @Binding var rating: Int?
    var interactive = true
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: (rating ?? 0) >= i ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle((rating ?? 0) >= i ? Color.brass : Color.secondary.opacity(0.5))
                    .onTapGesture { rating = rating == i ? nil : i }
            }
        }
        .allowsHitTesting(interactive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("별점"))
        .accessibilityValue(rating.map { LF("별 5개 중 %d개", $0) } ?? L("없음"))
        .accessibilityAdjustableAction { direction in
            guard interactive else { return }
            switch direction {
            case .increment: rating = min(5, (rating ?? 0) + 1)
            case .decrement:
                let next = (rating ?? 0) - 1
                rating = next <= 0 ? nil : next
            @unknown default: break
            }
        }
    }
}

/// 베이킹 로그 추가/편집 시트
struct BakeLogSheet: View {
    let recipeId: String
    let existing: BakeLog?
    let onSave: (BakeLog) -> Void

    @Environment(\.dismiss) private var dismiss
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
                    HStack {
                        Text(L("별점"))
                        Spacer()
                        StarRating(rating: $rating)
                    }
                }
                Section(L("메모")) {
                    TextEditor(text: $note)
                        .frame(minHeight: 140)
                        .font(.callout)
                } 
            }
            .navigationTitle(existing == nil ? L("기록 추가") : L("기록 편집"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) {
                        if isEdited { showDiscard = true } else { dismiss() }
                    }
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
            .discardConfirmation(isPresented: $showDiscard) { dismiss() }
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
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(L("배합 메모, 발효 시간, 결과 등을 적어두세요"))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
                .navigationTitle(L("노트 편집"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L("취소")) {
                            if text != initial { showDiscard = true } else { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("저장")) {
                            if text != initial { onSave(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                            dismiss()
                        }
                    }
                }
                .discardConfirmation(isPresented: $showDiscard) { dismiss() }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(text != initial)
    }
}

/// 베이킹 로그 한 줄
struct BakeLogRow: View {
    let log: BakeLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(fmtDate(iso: log.bakedAt))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                Spacer()
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
