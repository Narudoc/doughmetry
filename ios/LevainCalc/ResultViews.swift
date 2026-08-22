import LevainCore
import SwiftUI

/// 하단 고정 결과 요약 바 — 탭하면 전체 배합표 시트
struct SummaryBar: View {
    let stats: DoughStats
    let pieces: Double?
    let precision: Precision
    let onExpand: () -> Void

    var body: some View {
        Button(action: onExpand) {
            HStack(spacing: 12) {
                StatChip(title: L("총 수분율"), value: fmtPct(stats.hydrationPct), emphasized: true)
                StatChip(title: L("총 반죽"), value: fmtGrams(stats.doughWeight, precision) + " g")
                StatChip(title: "PFF", value: fmtPct(stats.pffPct))
                if let pieces, pieces > 0 {
                    StatChip(
                        title: L("개당"),
                        value: fmtGrams(stats.doughWeight / pieces, precision) + " g")
                }
                Image(systemName: "chevron.up.circle.fill")
                    .foregroundStyle(Color.bottle)
                    .font(.title3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14).strokeBorder(Color.line, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
    }
}

/// 전체 배합표 (fiche technique) — 시트로 표시, 텍스트 공유 지원
struct BakersTableSheet: View {
    let name: String
    let input: DoughInput
    let stats: DoughStats
    let pieces: Double?
    let precision: Precision

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(L("재료")) {
                    ForEach(input.flours) { f in
                        TableRow(
                            name: f.name.isEmpty ? L("밀가루") : f.name,
                            grams: fmtGrams(f.grams, precision),
                            pct: fmtPct(stats.pct(f.id)))
                    }
                    TableRow(name: L("본반죽 물"), grams: fmtGrams(input.water, precision), pct: nil)
                    if input.bassinage > 0 {
                        TableRow(
                            name: L("바시나주"), grams: fmtGrams(input.bassinage, precision), pct: nil)
                    }
                    TableRow(
                        name: L("소금"), grams: fmtGrams(input.salt, precision),
                        pct: fmtPct(stats.saltPct))
                    TableRow(
                        name: levainLabel,
                        grams: fmtGrams(input.levain.grams, precision),
                        pct: fmtPct(stats.pffPct))
                    ForEach(input.liquids) { l in
                        TableRow(
                            name: l.name.isEmpty ? L("액체") : l.name,
                            grams: fmtGrams(l.grams, precision),
                            pct: fmtPct(stats.pct(l.id)))
                    }
                    if input.yeast.grams > 0 {
                        TableRow(
                            name: input.yeast.type == .fresh ? L("생이스트") : L("인스턴트 이스트"),
                            grams: fmtGrams(input.yeast.grams, precision),
                            pct: fmtPct(stats.yeastPct))
                    }
                    ForEach(input.extras) { e in
                        TableRow(
                            name: e.name.isEmpty ? L("기타") : e.name,
                            grams: fmtGrams(e.grams, precision),
                            pct: fmtPct(stats.pct(e.id)))
                    }
                }
                Section(L("합계")) {
                    TableRow(
                        name: L("총 밀가루"), grams: fmtGrams(stats.totalFlour, precision),
                        pct: "100%", bold: true)
                    TableRow(
                        name: L("총 물"), grams: fmtGrams(stats.totalWater, precision),
                        pct: fmtPct(stats.hydrationPct), bold: true)
                    HStack {
                        BilingualLabel(L("총 수분율"), fr: "hydratation totale")
                            .fontWeight(.semibold)
                        Spacer()
                        StatValue(value: fmtPct(stats.hydrationPct), size: 17)
                    }
                    TableRow(
                        name: L("총 반죽 무게"), grams: fmtGrams(stats.doughWeight, precision),
                        pct: nil, bold: true)
                    if let pieces, pieces > 0 {
                        TableRow(
                            name: LF("분할 %d개 — 개당", Int(pieces)),
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
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var levainLabel: String {
        let type = input.levain.hydration >= 0.75 ? L("르방 리퀴드") : L("르방 뒤흐")
        let h = Int((input.levain.hydration * 100).rounded())
        return "\(type) \(h)%"
    }

    /// 공유용 fiche technique 텍스트
    private var ficheText: String {
        var lines: [String] = []
        lines.append("〔\(name.isEmpty ? L("배합표") : name)〕 fiche technique")
        lines.append("")
        for f in input.flours {
            lines.append(
                "\(f.name.isEmpty ? L("밀가루") : f.name)  \(fmtGrams(f.grams, precision)) g  (\(fmtPct(stats.pct(f.id))))")
        }
        lines.append("\(L("본반죽 물"))  \(fmtGrams(input.water, precision)) g")
        if input.bassinage > 0 {
            lines.append("\(L("바시나주"))  \(fmtGrams(input.bassinage, precision)) g")
        }
        lines.append("\(L("소금"))  \(fmtGrams(input.salt, precision)) g  (\(fmtPct(stats.saltPct)))")
        lines.append(
            "\(levainLabel)  \(fmtGrams(input.levain.grams, precision)) g  (PFF \(fmtPct(stats.pffPct)))")
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
                "\(LF("분할 %d개 — 개당", Int(pieces))) \(fmtGrams(stats.doughWeight / pieces, precision)) g")
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
    let onSave: (_ name: String, _ tags: [String], _ note: String?, _ overwrite: Bool) -> Void

    @State private var name = ""
    @State private var tagsText = ""
    @State private var note = ""
    @State private var overwrite = true
    @Environment(\.dismiss) private var dismiss

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
                    Button(L("취소")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) {
                        let tags = tagsText.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        onSave(
                            name, tags, note.isEmpty ? nil : note,
                            allowOverwrite && overwrite)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = initialName
                tagsText = initialTags.joined(separator: ", ")
                note = initialNote
            }
        }
        .presentationDetents([.medium])
    }
}
