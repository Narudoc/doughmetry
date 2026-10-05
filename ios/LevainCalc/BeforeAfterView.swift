import LevainCore
import SwiftUI

/// 변환 전후 비교 — 재료별 증감과 지표 보존 확인
struct BeforeAfterSections: View {
    let input: DoughInput
    let result: ConvertSuccess
    let precision: Precision

    /// 재료 섹션의 스크롤 기준점 — 변환기 아래 결과 바를 탭하면 여기로 간다
    static let anchorID = "beforeAfter.ingredients"

    @ScaledMetric(relativeTo: .caption) private var deltaWidth: CGFloat = 56
    @Environment(\.dynamicTypeSize) private var typeSize

    /// 접근성 글자 크기에선 이름을 위, 전후 수치를 아랫줄로 — 한 줄에 두면 이름과 수치가 쪼개진다
    private var rowLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
    }

    private func deltaText(_ before: Double, _ after: Double) -> String? {
        let d = after - before
        guard abs(d) >= (precision == .whole ? 0.5 : 0.05) else { return nil }
        return fmtSigned(d, precision)
    }

    private func compareRow(_ name: String, _ before: Double, _ after: Double) -> some View {
        let delta = deltaText(before, after)
        return rowLayout {
            Text(name)
            VStack(alignment: .trailing, spacing: 2) {
                HStack {
                    Spacer(minLength: 8)
                    Text(fmtGrams(before, precision))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    // brass는 변환이 바꾼 값에만 — 그대로인 재료까지 칠하면 실제로 바뀐 행이 묻힌다
                    Text(fmtGrams(after, precision))
                        .monospacedDigit()
                        .foregroundStyle(delta != nil ? Color.brass : Color.primary)
                        .fontWeight(delta != nil ? .semibold : .regular)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if !typeSize.isAccessibilitySize {
                        deltaLabel(delta ?? "")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(width: deltaWidth, alignment: .trailing)
                    }
                }
                // 접근성 크기에선 증감을 아랫줄로 — 전후 수치와 한 줄에 두면 넷 다 잘린다
                if typeSize.isAccessibilitySize, let delta {
                    deltaLabel(delta)
                }
            }
        }
        // 'g'만 두면 VoiceOver가 글자로 읽는다 — 단위를 말로 풀어 한 행을 한 번에 읽힌다
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(
            LF("%@그램에서 %@그램으로", fmtGrams(before, precision), fmtGrams(after, precision))
                + ", " + (delta ?? L("변화 없음")))
    }

    private func deltaLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    var body: some View {
        Section(L("변환 결과 — 재료 (g)")) {
            ForEach(Array(result.output.flours.enumerated()), id: \.element.id) { idx, f in
                let before = input.flours.first { $0.id == f.id }?.grams
                    ?? (idx < input.flours.count ? input.flours[idx].grams : 0)
                compareRow(flourLabel(f), before, f.grams)
            }
            compareRow(L("본반죽 물"), input.water, result.output.water)
            if input.bassinage > 0 {
                compareRow(L("바시나주"), input.bassinage, result.output.bassinage)
            }
            compareRow(L("소금"), input.salt, result.output.salt)
            // 변환이 건드리지 않는 재료도 보여야 행을 더한 값이 총 반죽 무게와 맞는다 (순서는 웹 BeforeAfter와 같게)
            ForEach(input.liquids) { l in
                compareRow(
                    l.name.isEmpty ? L("액체") : l.name, l.grams,
                    result.output.liquids.first { $0.id == l.id }?.grams ?? l.grams)
            }
            if input.yeast.grams > 0 {
                compareRow(
                    input.yeast.type == .fresh ? L("생이스트") : L("인스턴트 이스트"),
                    input.yeast.grams, result.output.yeast.grams)
            }
            compareRow(
                levainName(result.output.levain.hydration),
                input.levain.grams, result.output.levain.grams)
            ForEach(input.extras) { e in
                compareRow(
                    e.name.isEmpty ? L("기타") : e.name, e.grams,
                    result.output.extras.first { $0.id == e.id }?.grams ?? e.grams)
            }
        }
        .id(Self.anchorID)
        Section {
            pctMetricRow(L("총 수분율"), result.before.hydrationPct, result.after.hydrationPct)
            gramsMetricRow(L("총 반죽 무게"), result.before.doughWeight, result.after.doughWeight)
            pctMetricRow("PFF", result.before.pffPct, result.after.pffPct)
            gramsMetricRow(L("총 밀가루"), result.before.totalFlour, result.after.totalFlour)
        } header: {
            Text(L("지표"))
        } footer: {
            if abs(result.deltaFlour) > 1e-9 {
                Text(
                    LF("ΔF = %@ g — 르방 속 밀가루 증감분을 첨가 밀가루에서 빼고 본반죽 물에 더했습니다.", fmtSigned(result.deltaFlour, precision))
                )
            }
        }
    }

    private func gramsMetricRow(_ name: String, _ before: Double, _ after: Double) -> some View {
        metricRow(
            name, fmtGrams(before, precision) + " g", fmtGrams(after, precision) + " g",
            spoken: LF("%@그램에서 %@그램으로", fmtGrams(before, precision), fmtGrams(after, precision)),
            preserved: abs(before - after) < 1e-6)
    }

    private func pctMetricRow(_ name: String, _ before: Double, _ after: Double) -> some View {
        metricRow(
            name, fmtPct(before), fmtPct(after),
            spoken: LF("%@에서 %@로", fmtPct(before), fmtPct(after)),
            preserved: abs(before - after) < 1e-6)
    }

    private func metricRow(
        _ name: String, _ before: String, _ after: String, spoken: String, preserved: Bool
    ) -> some View {
        rowLayout {
            HStack {
                Text(name)
                if preserved {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(Color.bottle)
                }
            }
            HStack {
                Spacer(minLength: 8)
                Text(before)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(after)
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(preserved ? Color.primary : Color.brass)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(preserved ? spoken + ", " + L("보존됨") : spoken)
    }
}
