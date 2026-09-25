import LevainCore
import SwiftUI
import UIKit

/// 하단 고정 결과 요약 바 — 탭하면 전체 배합표 시트
struct SummaryBar: View {
    let stats: DoughStats
    let pieces: Double?
    let precision: Precision
    /// 키보드가 떠 있는 동안 — 펼침 화살표 대신 키보드를 내리는 완료 버튼을 보인다
    var isEditing = false
    let onExpand: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var chips: [StatChip] {
        var chips = [
            StatChip(title: L("총 수분율"), value: fmtPct(stats.hydrationPct), emphasized: true),
            StatChip(title: L("총 반죽"), value: fmtGrams(stats.doughWeight, precision) + " g"),
            StatChip(title: "PFF", value: fmtPct(stats.pffPct)),
        ]
        if let pieces, pieces > 0 {
            chips.append(
                StatChip(
                    title: L("개당"),
                    value: fmtGrams(stats.doughWeight / pieces, precision) + " g"))
        }
        return chips
    }

    var body: some View {
        // 여백은 버튼 라벨 안에 둔다 — 카드 전체가 탭 영역이 되도록
        HStack(spacing: 0) {
            Button(action: onExpand) {
                HStack(spacing: 12) {
                    chipLayout
                    if !isEditing {
                        Image(systemName: "chevron.up.circle.fill")
                            .foregroundStyle(Color.bottle)
                            .font(.title3)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, isEditing ? 6 : 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isEditing {
                Button {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Text(L("완료"))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.bottle)
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.leading, 6)
                        .padding(.trailing, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        // 늘 떠 있는 바라 키보드와 함께 폼을 덮지 않도록 AX1에서 멈춘다 — 전체 수치는 배합표 시트에서 끝까지 커진다
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// 큰 글자(칩 4개면 xLarge부터, 접근성 크기는 늘)에선 한 줄에 칩이 다 들어가지 않는다 — 2열로 접는다
    @ViewBuilder
    private var chipLayout: some View {
        let items = chips
        if typeSize.isAccessibilitySize || (items.count > 3 && typeSize >= .xLarge) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { i in
                    GridRow {
                        items[i]
                        if i + 1 < items.count { items[i + 1] }
                    }
                }
            }
        } else {
            HStack(spacing: items.count > 3 ? 8 : 12) {
                ForEach(items.indices, id: \.self) { items[$0] }
            }
        }
    }
}

/// 전체 배합표 (fiche technique) — 시트로 표시, 텍스트 공유 지원
struct BakersTableSheet: View {
    let name: String
    let input: DoughInput
    let stats: DoughStats
    let pieces: Double?
    let precision: Precision
    let basis: PctBasis

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(input.flours) { f in
                        TableRow(
                            name: flourLabel(f),
                            grams: fmtGrams(f.grams, precision),
                            pct: fmtPct(stats.uiPct(grams: f.grams, basis: basis)))
                    }
                    TableRow(name: L("본반죽 물"), grams: fmtGrams(input.water, precision), pct: nil)
                    if input.bassinage > 0 {
                        TableRow(
                            name: L("바시나주"), grams: fmtGrams(input.bassinage, precision), pct: nil)
                    }
                    TableRow(
                        name: L("소금"), grams: fmtGrams(input.salt, precision),
                        pct: fmtPct(stats.uiPct(grams: input.salt, basis: basis)))
                    TableRow(
                        name: levainLabel,
                        grams: fmtGrams(input.levain.grams, precision),
                        pct: fmtPct(stats.uiPct(grams: input.levain.grams, basis: basis)))
                    TableRow(
                        name: "↳ \(L("속 밀가루")) (PFF)",
                        grams: fmtGrams(stats.levainFlour, precision),
                        pct: fmtPct(stats.pffPct), secondary: true)
                    ForEach(input.liquids) { l in
                        TableRow(
                            name: l.name.isEmpty ? L("액체") : l.name,
                            grams: fmtGrams(l.grams, precision),
                            pct: fmtPct(stats.uiPct(grams: l.grams, basis: basis)))
                    }
                    if input.yeast.grams > 0 {
                        TableRow(
                            name: input.yeast.type == .fresh ? L("생이스트") : L("인스턴트 이스트"),
                            grams: fmtGrams(input.yeast.grams, precision),
                            pct: fmtPct(stats.uiPct(grams: input.yeast.grams, basis: basis)))
                    }
                    ForEach(input.extras) { e in
                        TableRow(
                            name: e.name.isEmpty ? L("기타") : e.name,
                            grams: fmtGrams(e.grams, precision),
                            pct: fmtPct(stats.uiPct(grams: e.grams, basis: basis)))
                    }
                } header: {
                    Text(L("재료"))
                } footer: {
                    Text(
                        basis == .addedFlour
                            ? L("%는 첨가 밀가루 기준(베이커스 퍼센트)입니다.")
                            : L("%는 총 밀가루(첨가 + 르방 속) 기준입니다."))
                }
                Section(L("합계")) {
                    TableRow(
                        name: L("총 밀가루"), grams: fmtGrams(stats.totalFlour, precision),
                        pct: "100%", bold: true)
                    TableRow(
                        name: L("총 물"), grams: fmtGrams(stats.totalWater, precision),
                        pct: fmtPct(stats.hydrationPct), bold: true)
                    LabeledContent {
                        StatValue(value: fmtPct(stats.hydrationPct), size: 17)
                    } label: {
                        BilingualLabel(L("총 수분율"), fr: "hydratation totale")
                            .fontWeight(.semibold)
                    }
                    TableRow(
                        name: L("총 반죽 무게"), grams: fmtGrams(stats.doughWeight, precision),
                        pct: nil, bold: true)
                    if let pieces, pieces > 0 {
                        TableRow(
                            name: LF("분할 %@개 — 개당", fmtCount(pieces)),
                            grams: fmtGrams(stats.doughWeight / pieces, precision),
                            pct: nil, bold: true)
                    }
                }
            }
            .navigationTitle(name.isEmpty ? L("배합표") : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("닫기")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: ficheText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(L("공유"))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var levainLabel: String {
        let type = input.levain.hydration >= 0.75 ? L("르방 리퀴드") : L("르방 뒤흐")
        let h = clampedInt(input.levain.hydration * 100)
        return "\(type) \(h)%"
    }

    /// 공유용 fiche technique 텍스트
    private var ficheText: String {
        var lines: [String] = []
        lines.append("〔\(name.isEmpty ? L("배합표") : name)〕 fiche technique")
        lines.append("")
        for f in input.flours {
            lines.append(
                "\(flourLabel(f))  \(fmtGrams(f.grams, precision)) g  (\(fmtPct(stats.uiPct(grams: f.grams, basis: basis))))")
        }
        lines.append("\(L("본반죽 물"))  \(fmtGrams(input.water, precision)) g")
        if input.bassinage > 0 {
            lines.append("\(L("바시나주"))  \(fmtGrams(input.bassinage, precision)) g")
        }
        lines.append("\(L("소금"))  \(fmtGrams(input.salt, precision)) g  (\(fmtPct(stats.uiPct(grams: input.salt, basis: basis))))")
        lines.append(
            "\(levainLabel)  \(fmtGrams(input.levain.grams, precision)) g  (\(fmtPct(stats.uiPct(grams: input.levain.grams, basis: basis))))")
        lines.append(
            "  ↳ \(L("속 밀가루"))  \(fmtGrams(stats.levainFlour, precision)) g  (PFF \(fmtPct(stats.pffPct)))")
        for l in input.liquids {
            lines.append("\(l.name.isEmpty ? L("액체") : l.name)  \(fmtGrams(l.grams, precision)) g")
        }
        if input.yeast.grams > 0 {
            lines.append(
                "\(L(input.yeast.type == .fresh ? "생이스트" : "인스턴트 이스트"))  \(fmtGrams(input.yeast.grams, precision)) g")
        }
        for e in input.extras {
            lines.append("\(e.name.isEmpty ? L("기타") : e.name)  \(fmtGrams(e.grams, precision)) g")
        }
        lines.append("")
        lines.append("\(L("총 밀가루"))  \(fmtGrams(stats.totalFlour, precision)) g")
        lines.append("\(L("총 물"))  \(fmtGrams(stats.totalWater, precision)) g")
        lines.append("\(L("총 수분율"))  \(fmtPct(stats.hydrationPct))")
        lines.append("\(L("총 반죽 무게"))  \(fmtGrams(stats.doughWeight, precision)) g")
        if let pieces, pieces > 0 {
            lines.append(
                "\(LF("분할 %@개 — 개당", fmtCount(pieces))) \(fmtGrams(stats.doughWeight / pieces, precision)) g")
        }
        return lines.joined(separator: "\n")
    }
}

/// 레시피 저장 시트
struct SaveRecipeSheet: View {
    let initialName: String
    let initialTags: [String]
    let initialNote: String
    let allowOverwrite: Bool
    /// 불러온 레시피의 저장된 이름 — 이름이 이와 다르면 덮어쓰기를 끈 채로 시작한다
    var loadedName: String? = nil
    let onSave: (_ name: String, _ tags: [String], _ note: String?, _ overwrite: Bool) -> Void

    @State private var name: String
    @State private var tagsText: String
    @State private var note: String
    @State private var overwrite: Bool
    @State private var showDiscard = false
    @Environment(\.dismiss) private var dismiss

    // 상태를 init에서 채운다 — onAppear에서 채우면 첫 프레임에 isEdited가 참이 된다
    init(
        initialName: String, initialTags: [String], initialNote: String, allowOverwrite: Bool,
        loadedName: String? = nil,
        onSave: @escaping (_ name: String, _ tags: [String], _ note: String?, _ overwrite: Bool) -> Void
    ) {
        self.initialName = initialName
        self.initialTags = initialTags
        self.initialNote = initialNote
        self.allowOverwrite = allowOverwrite
        self.loadedName = loadedName
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _tagsText = State(initialValue: initialTags.joined(separator: ", "))
        _note = State(initialValue: initialNote)
        let base = (loadedName ?? initialName).trimmingCharacters(in: .whitespacesAndNewlines)
        _overwrite = State(
            initialValue: allowOverwrite
                && initialName.trimmingCharacters(in: .whitespacesAndNewlines) == base)
    }

    /// 계산기 이름 칸에서 이미 바꾼 이름도 걸러내도록 화면 이름이 아니라 저장된 이름과 비교한다
    private var baseName: String {
        (loadedName ?? initialName).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEdited: Bool {
        name != initialName || tagsText != initialTags.joined(separator: ", ") || note != initialNote
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(L("레시피 이름"), text: $name)
                TextField(L("태그 (쉼표로 구분)"), text: $tagsText)
                TextField(L("노트"), text: $note, axis: .vertical)
                    .lineLimit(2...5)
                if allowOverwrite {
                    Toggle(L("불러온 레시피에 덮어쓰기"), isOn: $overwrite)
                }
            }
            .navigationTitle(L("레시피 저장"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) {
                        if isEdited { showDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) {
                        let tags = tagsText.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        onSave(
                            name.trimmingCharacters(in: .whitespacesAndNewlines), tags,
                            note.isEmpty ? nil : note,
                            allowOverwrite && overwrite)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .discardConfirmation(isPresented: $showDiscard) { dismiss() }
            // 이름을 바꾸면 새 레시피로 저장하려는 것으로 보고 덮어쓰기를 해제한다 (다시 켤 수는 있음)
            .onChange(of: name) { _, newName in
                if allowOverwrite,
                    newName.trimmingCharacters(in: .whitespacesAndNewlines) != baseName
                {
                    overwrite = false
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isEdited)
    }
}
