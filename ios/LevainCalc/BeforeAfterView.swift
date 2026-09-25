import LevainCore
import SwiftUI

/// 변환 전후 비교 — 재료별 증감과 지표 보존 확인
struct BeforeAfterSections: View {
    let input: DoughInput
    let result: ConvertSuccess
    let precision: Precision

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
                    Text(fmtGrams(after, precision))
                        .monospacedDigit()
                        .foregroundStyle(Color.brass)
                        .fontWeight(.semibold)
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
    }

    private func deltaLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    var body: some View {
        Section(L("변환 결과 — 재료")) {
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
            compareRow(
                result.output.levain.hydration >= 0.75 ? L("르방 리퀴드") : L("르방 뒤흐"),
                input.levain.grams, result.output.levain.grams)
        }
        Section {
            metricRow(
                L("총 수분율"), fmtPct(result.before.hydrationPct), fmtPct(result.after.hydrationPct),
                preserved: abs(result.before.hydrationPct - result.after.hydrationPct) < 1e-6)
            metricRow(
                L("총 반죽 무게"),
                fmtGrams(result.before.doughWeight, precision) + " g",
                fmtGrams(result.after.doughWeight, precision) + " g",
                preserved: abs(result.before.doughWeight - result.after.doughWeight) < 1e-6)
            metricRow(
                "PFF", fmtPct(result.before.pffPct), fmtPct(result.after.pffPct),
                preserved: abs(result.before.pffPct - result.after.pffPct) < 1e-6)
            metricRow(
                L("총 밀가루"),
                fmtGrams(result.before.totalFlour, precision) + " g",
                fmtGrams(result.after.totalFlour, precision) + " g",
                preserved: abs(result.before.totalFlour - result.after.totalFlour) < 1e-6)
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

    private func metricRow(
        _ name: String, _ before: String, _ after: String, preserved: Bool
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
    }
}
