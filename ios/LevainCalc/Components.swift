import LevainCore
import SwiftUI
import UIKit

/// 그램·퍼센트 숫자 입력 — 데시멀 키패드, 편집 중 자유 입력, 포커스 해제 시 값 동기화.
struct NumberField: View {
    let label: String
    @Binding var value: Double
    var unit: String = "g"
    var fractionDigits: Int = 1
    /// 입력 하한 — 빈 칸도 이 값으로 저장한다 (웹 NumberField의 min과 동일)
    var minValue: Double = 0
    /// 입력 상한 — 넘으면 상한으로 저장한다. 개수·%·분처럼 표시에서 Int로 바꾸는 칸은 반드시 걸 것
    /// (Int(Double)은 Int.max를 넘으면 앱을 멈춘다)
    var maxValue: Double = .infinity
    /// 정수 칸(분할 개수·분) — 소수는 반올림해 저장한다. 보이는 "2"와 계산에 쓰는 2.5가 어긋나지 않도록
    var integer = false
    /// VoiceOver·음성 제어용 이름 — 화면 라벨이 비어 있는 행(밀가루·액체·기타 재료 이름 칸 아래)에서 넘긴다
    var accessibilityName: String? = nil

    @State private var text = ""
    /// 편집 중 자기 자신이 쓴 값 — 외부 변경(레시피 불러오기·이스트 환산 등)과 구분
    @State private var selfWritten: Double?
    @FocusState private var focused: Bool
    @ScaledMetric(relativeTo: .body) private var fieldMaxWidth: CGFloat = 110
    @Environment(\.dynamicTypeSize) private var typeSize

    private func format(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1e12 {
            return String(format: "%.0f", v)
        }
        // 정수 칸이라도 웹에서 가져온 2.5·2.25 같은 값은 반올림해 보이지 않는다 — 계산은 그 값으로 하므로
        // 배합표·상세와 같은 fmtCount로 끝자리까지 보인다
        if integer { return fmtCount(v) }
        return String(format: "%.\(max(fractionDigits, 1))f", v)
    }

    private func clamp(_ v: Double) -> Double {
        min(maxValue, max(minValue, integer ? v.rounded() : v))
    }

    private var accessibilityText: String {
        let name = accessibilityName ?? label
        return name.isEmpty ? unit : "\(name) (\(unit))"
    }

    var body: some View {
        // 접근성 글자 크기에선 라벨을 윗줄로 — 한 줄에 두면 긴 라벨이 글자 단위로 쪼개진다
        let layout =
            typeSize.isAccessibilitySize && !label.isEmpty
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
        layout {
            Text(label)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
            HStack {
                Spacer(minLength: 8)
                inputField
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 18, alignment: .leading)
                    .accessibilityHidden(true)
            }
        }
    }

    private var inputField: some View {
        // 최소 폭은 키우지 않는다 — 폭이 고정된 칸(타임라인 분)에서 넘쳐 옆 칸을 덮는다
        TextField("0", text: $text)
            .keyboardType(integer ? .numberPad : .decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .focused($focused)
            .frame(minWidth: 70, maxWidth: fieldMaxWidth)
            .accessibilityLabel(accessibilityText)
            .onChange(of: text) { _, newText in
                guard focused else { return }
                // 바인딩이 실제로 저장한 값을 다시 읽어 기록 — 하한·상한·환산 setter의 반향을
                // 외부 변경으로 오인해 입력 중인 텍스트를 덮어쓰지 않도록.
                // 붙여넣은 " 500 "도 받도록 앞뒤 공백을 걷는다 (웹 NumberField와 동일)
                let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    value = minValue
                    selfWritten = value
                } else if let v = parseDecimalInput(trimmed), v.isFinite, v >= 0 {
                    value = clamp(v)
                    selfWritten = value
                }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused {
                    text = format(value)
                    selfWritten = nil
                }
            }
            .onChange(of: value) { _, newValue in
                // 편집 중이라도 외부에서 값이 바뀌면(이스트 환산 등) 표시를 따라간다
                if !focused || newValue != selfWritten {
                    text = format(newValue)
                    selfWritten = focused ? newValue : nil
                }
            }
            .onAppear { text = format(value) }
    }
}

/// 계산 결과 수치 (brass 전용색). size는 기본 글자 크기에서의 pt — Dynamic Type을 따라 커진다
struct StatValue: View {
    let value: String
    var size: CGFloat = 17

    var body: some View {
        Text(value)
            .statFont(size)
            .monospacedDigit()
            .foregroundStyle(Color.brass)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

/// 요약 통계 칩 (하단 바·결과 카드 공용)
struct StatChip: View {
    let title: String
    let value: String
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .statFont(emphasized ? 20 : 16)
                .monospacedDigit()
                .foregroundStyle(Color.brass)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 배합표 행: 이름 / 그램 / %
struct TableRow: View {
    let name: String
    let grams: String
    let pct: String?
    var bold = false
    /// 윗 행에 딸린 보조 행(르방 속 밀가루 등) — 작고 흐리게
    var secondary = false

    @ScaledMetric(relativeTo: .footnote) private var pctWidth: CGFloat = 64
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // 접근성 글자 크기에선 이름을 위, 수치를 아래 줄로 — 한 줄에 두면 이름이 글자 단위로 쪼개진다
        let layout =
            typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
        layout {
            Text(name)
                .font(secondary ? .footnote : nil)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(secondary ? Color.secondary : Color.primary)
            HStack {
                Spacer(minLength: 8)
                Text(grams)
                    .font(secondary ? .footnote : nil)
                    .monospacedDigit()
                    .fontWeight(bold ? .semibold : .regular)
                    .foregroundStyle(bold ? Color.brass : secondary ? Color.secondary : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(pct ?? "")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: pctWidth, alignment: .trailing)
            }
        }
    }
}

extension View {
    /// 키보드가 떠 있는 동안 내비게이션 바 오른쪽에 "완료" — iOS 26+의 떠 있는 키보드 액세서리(.keyboard 툴바)는
    /// 포커스된 행의 오른쪽 정렬 값을 덮는다
    func keyboardDoneButton() -> some View { modifier(KeyboardDoneToolbar()) }
}

private struct KeyboardDoneToolbar: ViewModifier {
    @State private var keyboardVisible = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                if keyboardVisible {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("완료")) {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in keyboardVisible = true }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in keyboardVisible = false }
    }
}

/// 표시 계층의 % 계산 — 설정(PctBasis)에 따라 분모만 달라진다.
/// 계산 코어의 지표(총 수분율·PFF)는 항상 총 밀가루 기준으로 유지된다.
extension DoughStats {
    var addedFlourTotalForDisplay: Double { totalFlour - levainFlour }

    func uiPct(grams: Double, basis: PctBasis) -> Double {
        let denom = basis == .addedFlour ? addedFlourTotalForDisplay : totalFlour
        return denom > 1e-9 ? grams / denom * 100 : 0
    }

    /// 계산기 입력 폼의 르방 % 칩 전용 — 총 밀가루 기준일 땐 PFF, 베이커스 퍼센트일 땐 르방 무게/첨가 밀가루
    /// (폼 하단 설명이 이 뜻을 밝힌다). 배합표·레시피 상세의 르방 행은 웹 BakersTable처럼
    /// uiPct(르방 무게) + "↳ 속 밀가루 (PFF)" 보조 행으로 나눠 보인다.
    func uiLevainPct(levainGrams: Double, basis: PctBasis) -> Double {
        basis == .addedFlour ? uiPct(grams: levainGrams, basis: basis) : pffPct
    }
}

/// 표시용 Int 변환 — 음수·NaN·무한대·거대값에도 멈추지 않는다 (Int(Double)은 범위를 벗어나면 트랩)
func clampedInt(_ x: Double, max hi: Double = 1e9) -> Int {
    guard x.isFinite else { return 0 }
    return Int(min(Swift.max(x, 0), hi).rounded())
}

/// 개수 표시 — 정수면 "2", 아니면 "2.5"(웹처럼 값 그대로). 개당 무게는 실제 값으로 나누므로 잘라 보이면 안 된다
func fmtCount(_ x: Double) -> String {
    x == x.rounded() && abs(x) < 1e15 ? String(format: "%.0f", x) : "\(x)"
}
