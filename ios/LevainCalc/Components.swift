import LevainCore
import SwiftUI
import UIKit

/// 그램·퍼센트 숫자 입력 — 데시멀 키패드, 편집 중 자유 입력, 포커스 해제 시 값 동기화.
struct NumberField: View {
    let label: String
    @Binding var value: Double
    var unit: String = "g"
    var fractionDigits: Int = 1

    @State private var text = ""
    /// 편집 중 자기 자신이 쓴 값 — 외부 변경(레시피 불러오기·이스트 환산 등)과 구분
    @State private var selfWritten: Double?
    @FocusState private var focused: Bool

    private func format(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1e12 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.\(fractionDigits)f", v)
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($focused)
                .frame(minWidth: 70, maxWidth: 110)
                .onChange(of: text) { _, newText in
                    guard focused else { return }
                    let normalized = newText.replacingOccurrences(of: ",", with: ".")
                    if let v = Double(normalized), v.isFinite, v >= 0 {
                        selfWritten = v
                        value = v
                    } else if newText.isEmpty {
                        selfWritten = 0
                        value = 0
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
            Text(unit)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(minWidth: 18, alignment: .leading)
        }
    }
}

/// 계산 결과 수치 (brass 전용색)
struct StatValue: View {
    let value: String
    var size: CGFloat = 17

    var body: some View {
        Text(value)
            .font(.stat(size))
            .monospacedDigit()
            .foregroundStyle(Color.brass)
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
            Text(value)
                .font(.stat(emphasized ? 20 : 16))
                .monospacedDigit()
                .foregroundStyle(Color.brass)
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

    var body: some View {
        HStack {
            Text(name)
                .fontWeight(bold ? .semibold : .regular)
            Spacer()
            Text(grams)
                .monospacedDigit()
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(bold ? Color.brass : Color.primary)
            Text(pct ?? "")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }
}

extension View {
    /// 키보드 위 "완료" 버튼
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("완료")) {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
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

    /// 르방 행의 % — 총 밀가루 기준일 땐 PFF, 베이커스 퍼센트일 땐 르방 무게/첨가 밀가루
    func uiLevainPct(levainGrams: Double, basis: PctBasis) -> Double {
        basis == .addedFlour ? uiPct(grams: levainGrams, basis: basis) : pffPct
    }
}
