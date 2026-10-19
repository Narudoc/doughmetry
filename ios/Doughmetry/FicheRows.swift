import DoughmetryCore
import SwiftUI

// 배합표(fiche technique)의 재료 행 — 배합표 시트·레시피 상세·공유 텍스트가 모두 여기서 만든다.

/// 르방 타입 이름 (르방 리퀴드 / 르방 뒤흐). 경계는 DoughmetryCore levainTypeFor와 같다
func levainName(_ hydration: Double) -> String {
    levainTypeFor(hydration: hydration) == .liquide ? L("르방 리퀴드") : L("르방 뒤흐")
}

/// 짧은 타입 이름 (리퀴드 / 뒤흐) — 목록 행·변환기 프리셋
func levainShort(_ hydration: Double) -> String {
    levainTypeFor(hydration: hydration) == .liquide ? L("리퀴드") : L("뒤흐")
}

/// 프랑스어 원어 — 언어와 무관하게 병기한다
func levainFr(_ hydration: Double) -> String {
    levainTypeFor(hydration: hydration) == .liquide ? "levain liquide" : "levain dur"
}

/// 배합표의 르방 행 이름 — "르방 리퀴드 100%"
func levainLabel(_ levain: Levain) -> String {
    "\(levainName(levain.hydration)) \(clampedInt(levain.hydration * 100))%"
}

struct FicheRow: Identifiable, Equatable {
    enum Kind: Equatable {
        case flour, water, bassinage, salt, levain
        /// 르방 속 밀가루 — 르방 행에 딸린 보조 행, %는 PFF
        case levainFlour
        case liquid, yeast, extra
    }

    let id: String
    let kind: Kind
    /// 화면 이름 ("↳ 속 밀가루 (PFF)"처럼 기호 포함)
    let name: String
    /// VoiceOver 이름 — 기호를 뺀 것
    let spokenName: String
    let grams: Double
    /// 표시 % (PctBasis 반영, 보조 행은 PFF). 물·바시나주는 없음
    let pct: Double?
    let precision: Precision

    var secondary: Bool { kind == .levainFlour }
    var gramsText: String { fmtGrams(grams, precision) }
    var pctText: String? { pct.map { fmtPct($0) } }
}

/// 재료 행 — 밀가루, 본반죽 물, 바시나주(> 0), 소금, 르방, ↳ 속 밀가루(PFF), 액체, 이스트(> 0), 기타 순.
/// 웹 BakersTable·PrintFiche와 같은 순서다
func ficheRows(
    input: DoughInput, stats: DoughStats? = nil, basis: PctBasis, precision: Precision
) -> [FicheRow] {
    let stats = stats ?? computeStats(input)
    func pct(_ grams: Double) -> Double { stats.uiPct(grams: grams, basis: basis) }
    func row(_ id: String, _ kind: FicheRow.Kind, _ name: String, _ grams: Double, _ pct: Double?)
        -> FicheRow
    {
        FicheRow(
            id: id, kind: kind, name: name, spokenName: name, grams: grams, pct: pct,
            precision: precision)
    }

    var rows = input.flours.map { row("flour-\($0.id)", .flour, flourLabel($0), $0.grams, pct($0.grams)) }
    rows.append(row("water", .water, L("본반죽 물"), input.water, nil))
    if input.bassinage > 0 {
        rows.append(row("bassinage", .bassinage, L("바시나주"), input.bassinage, nil))
    }
    rows.append(row("salt", .salt, L("소금"), input.salt, pct(input.salt)))
    rows.append(
        row("levain", .levain, levainLabel(input.levain), input.levain.grams, pct(input.levain.grams)))
    rows.append(
        FicheRow(
            id: "levainFlour", kind: .levainFlour, name: "↳ \(L("속 밀가루")) (PFF)",
            spokenName: "\(L("속 밀가루")) (PFF)", grams: stats.levainFlour, pct: stats.pffPct,
            precision: precision))
    rows += input.liquids.map {
        row("liquid-\($0.id)", .liquid, $0.name.isEmpty ? L("액체") : $0.name, $0.grams, pct($0.grams))
    }
    if input.yeast.grams > 0 {
        rows.append(
            row(
                "yeast", .yeast, input.yeast.type == .fresh ? L("생이스트") : L("인스턴트 이스트"),
                input.yeast.grams, pct(input.yeast.grams)))
    }
    rows += input.extras.map {
        row("extra-\($0.id)", .extra, $0.name.isEmpty ? L("기타") : $0.name, $0.grams, pct($0.grams))
    }
    return rows
}

/// 공유용 fiche technique 텍스트.
/// 형식을 바꾸면 가져오기 파서의 fiche 픽스처(RecipeTextParserTests.swift ↔ recipeParser.test.ts)도 함께 고칠 것 —
/// 앱이 공유한 텍스트를 앱이 다시 가져올 수 있어야 한다
func ficheText(
    name: String, input: DoughInput, stats: DoughStats? = nil, pieces: Double? = nil,
    basis: PctBasis, precision: Precision
) -> String {
    let stats = stats ?? computeStats(input)
    var lines = ["〔\(name.isEmpty ? L("배합표") : name)〕 fiche technique", ""]
    // 액체 행은 input.liquids 순서 그대로 — 수분 함량을 밝혀야 다시 가져올 때 이름과 무관하게 액체로 돌아온다
    var liquids = input.liquids.makeIterator()
    for r in ficheRows(input: input, stats: stats, basis: basis, precision: precision) {
        if r.kind == .levainFlour {
            lines.append("  ↳ \(L("속 밀가루"))  \(r.gramsText) g  (PFF \(r.pctText ?? ""))")
        } else if r.kind == .liquid, let liquid = liquids.next() {
            lines.append(
                "\(r.name)  \(r.gramsText) g  (\(r.pctText ?? "")) · \(L("수분")) \(fmtPct(liquid.waterRatio * 100))")
        } else if let pct = r.pctText {
            lines.append("\(r.name)  \(r.gramsText) g  (\(pct))")
        } else {
            lines.append("\(r.name)  \(r.gramsText) g")
        }
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
    lines.append("")
    lines.append(AppLinks.shareFooter)
    return lines.joined(separator: "\n")
}

/// 배합표 한 행 — 화면은 TableRow, VoiceOver는 한 요소("T65, 900.0 그램, 81.8%")
struct FicheRowView: View {
    let row: FicheRow

    var body: some View {
        TableRow(name: row.name, grams: row.gramsText, pct: row.pctText, secondary: row.secondary)
            .ficheRowAccessibility(name: row.spokenName, grams: row.gramsText, pct: row.pctText)
    }
}

extension View {
    /// 배합표 행을 VoiceOver 한 요소로 — 단위를 'g'(글자로 읽힘)가 아니라 '그램'으로 읽는다
    func ficheRowAccessibility(name: String, grams: String, pct: String?) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(name)
            .accessibilityValue(LF("%@그램", grams) + (pct.map { ", \($0)" } ?? ""))
    }
}

/// 배합표 본문 — 재료(% 기준 설명) + 합계(총 수분율 설명). List 안에 넣는다
struct FicheSections: View {
    let input: DoughInput
    let stats: DoughStats
    let pieces: Double?
    let precision: Precision
    let basis: PctBasis

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Section {
            ForEach(ficheRows(input: input, stats: stats, basis: basis, precision: precision)) {
                FicheRowView(row: $0)
            }
        } header: {
            Text(L("재료"))
        } footer: {
            Text(
                basis == .addedFlour
                    ? L("%는 첨가 밀가루 기준(베이커스 퍼센트)입니다.")
                    : L("%는 총 밀가루(첨가 + 르방 속) 기준입니다."))
        }
        .textCase(nil)
        Section {
            totalRow(L("총 밀가루"), stats.totalFlour, pct: "100%")
            totalRow(L("총 물"), stats.totalWater, pct: fmtPct(stats.hydrationPct))
            hydrationRow
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L("총 수분율"))
                .accessibilityValue(fmtPct(stats.hydrationPct))
            totalRow(L("총 반죽 무게"), stats.doughWeight, pct: nil)
            if let pieces, pieces > 0 {
                totalRow(LF("분할 %@개 — 개당", fmtCount(pieces)), stats.doughWeight / pieces, pct: nil)
            }
        } header: {
            Text(L("합계"))
        } footer: {
            Text(
                L("총 수분율 = 총 물 ÷ 총 밀가루. 총 물에는 본반죽 물·바시나주·르방 속 물·액체 재료의 수분이 모두 들어가서, 본반죽 물 ÷ 밀가루로 적은 레시피의 수분율보다 높게 나옵니다."))
        }
        .textCase(nil)
    }

    /// iOS 17·18의 LabeledContent는 접근성 글자 크기에서 이름과 값을 위아래로 쌓지 않아 값이 줄어든다 —
    /// 26부터는 시스템이 쌓는다
    private var stacksLabeledRows: Bool {
        if #unavailable(iOS 26) { return typeSize.isAccessibilitySize }
        return false
    }

    @ViewBuilder
    private var hydrationRow: some View {
        let label = BilingualLabel(L("총 수분율"), fr: "hydratation totale").fontWeight(.semibold)
        let value = StatValue(value: fmtPct(stats.hydrationPct), size: 17)
        if stacksLabeledRows {
            VStack(alignment: .leading, spacing: 4) {
                label
                value
            }
        } else {
            LabeledContent {
                value
            } label: {
                label
            }
        }
    }

    private func totalRow(_ name: String, _ grams: Double, pct: String?) -> some View {
        let g = fmtGrams(grams, precision)
        return TableRow(name: name, grams: g, pct: pct, bold: true)
            .ficheRowAccessibility(name: name, grams: g, pct: pct)
    }
}
