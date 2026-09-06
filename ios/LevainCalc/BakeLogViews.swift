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
        .accessibilityValue(rating.map { "\($0)/5" } ?? L("없음"))
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
    @State private var bakedAt = Date()
    @State private var rating: Int?
    @State private var note = ""

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
                    Button(L("취소")) { dismiss() }
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
            .onAppear {
                if let existing {
                    bakedAt = parseISO(existing.bakedAt) ?? Date()
                    rating = existing.rating
                    note = existing.note
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 레시피 노트 편집 시트
struct NoteEditSheet: View {
    let initial: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

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
                        Button(L("취소")) { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("저장")) {
                            onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                    }
                }
                .onAppear { text = initial }
        }
        .presentationDetents([.medium, .large])
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
