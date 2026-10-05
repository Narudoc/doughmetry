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

    /// 0은 빈 칸(회색 자리표시 "0")으로 — 글자 "0" 앞에 커서가 놓이면 400을 쳐도 4000이 된다.
    /// 빈 칸은 minValue로 저장되므로 하한이 0인 칸만
    private func display(_ v: Double) -> String {
        v == 0 && minValue == 0 ? "" : format(v)
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
            if !label.isEmpty {
                // 라벨이 먼저 제 폭을 받는다 — 입력 칸은 minWidth가 있어 좁아지지 않고, 그래도 넘치는 라벨만 줄을 바꾼다
                Text(label)
                    .foregroundStyle(.primary)
                    .layoutPriority(1)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            HStack {
                Spacer(minLength: 8)
                inputField
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(minWidth: 18, alignment: .leading)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        // 라벨·빈 간격·단위를 눌러도 이 칸에 포커스 — 입력 칸은 이 층 위에 있어 자기 탭(커서 위치)을 그대로 받는다
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { focused = true }
                .accessibilityHidden(true)
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
                    text = display(value)
                    selfWritten = nil
                }
            }
            .onChange(of: value) {
                // 편집 중이라도 외부에서 값이 바뀌면(이스트 환산 등) 표시를 따라간다.
                // newValue가 아니라 바인딩을 다시 읽어 비교한다 — 키 입력이 몰리면 이 onChange가 한 박자 늦게
                // 도착해(100 → 10 → 1에서 newValue 10, 바인딩은 이미 1) 낡은 값을 외부 변경으로 오인하고
                // 텍스트를 되돌린다. 그러면 text·value 핸들러가 10 ↔ 1을 끝없이 주고받아 메인 스레드가 멈춘다
                let current = value
                if !focused || current != selfWritten {
                    text = display(current)
                    selfWritten = focused ? current : nil
                }
            }
            .onAppear {
                SelectAllOnFocus.install()
                text = display(value)
            }
    }
}

/// 숫자 칸이 포커스를 얻으면 값 전체를 선택 — 첫 키 입력이 기존 값을 대체한다 (340에 350을 치면 350340이 되던 문제).
/// 이미 포커스된 칸을 다시 누르면 시스템대로 커서가 놓여 한 자리만 고칠 수 있다.
/// selectAll(_:)은 잘라내기·복사·붙여넣기 메뉴를 띄우므로 selectedTextRange를 직접 건다
@MainActor
private final class SelectAllOnFocus: NSObject {
    private static let shared = SelectAllOnFocus()

    static func install() { _ = shared }

    override private init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(didBeginEditing(_:)),
            name: UITextField.textDidBeginEditingNotification, object: nil)
    }

    @objc private func didBeginEditing(_ note: Notification) {
        // 숫자 키패드 칸(NumberField)만 — 이름·태그 칸은 손대지 않는다
        guard let field = note.object as? UITextField,
            field.keyboardType == .decimalPad || field.keyboardType == .numberPad
        else { return }
        // 다음 런루프에 — 탭한 자리에 커서를 놓는 UIKit 처리가 끝난 뒤라야 선택이 덮이지 않는다
        DispatchQueue.main.async {
            guard field.isFirstResponder else { return }
            field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument)
        }
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
    /// 값 색 — 계산 결과는 brass. 불가능한 역산 결과(음수)만 danger로
    var tint: Color = .brass

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
                .foregroundStyle(tint)
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
                Text(grams.isEmpty ? "" : grams + " g")
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
        // VoiceOver가 "강력분, 4000.0 g, 72.7%"를 한 항목으로 읽도록
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// 저장 같은 동작 뒤 잠깐 뜨는 상태 알림 (웹 Toast처럼 2.6초). message를 넣으면 아래쪽에 뜨고 VoiceOver가 읽으며, 시간이 지나면 nil로 돌린다.
    /// 아래 안전 영역 위에 놓이므로 요약 바를 단 safeAreaInset(edge: .bottom)보다 먼저(안쪽에) 붙여야 바를 가리지 않는다
    func toast(_ message: Binding<String?>) -> some View { modifier(ToastModifier(message: message)) }

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

private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                // 늘 있는 바깥 틀에 애니메이션을 걸어야 알림이 들고 나는 전환만 움직인다 (본문 변경까지 번지지 않게)
                ZStack {
                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(Color.paper)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.bottle, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .transition(
                                reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: message)
                .allowsHitTesting(false)
            }
            .task(id: message) {
                guard let shown = message else { return }
                // 탭을 떠나 취소돼도 지운다 — 남겨 두면 돌아올 때 지난 알림이 다시 뜬다
                try? await Task.sleep(for: .seconds(2.6))
                if message == shown { message = nil }
            }
            .onChange(of: message) { _, new in
                guard let new else { return }
                // 저장 시트가 닫히며 생기는 화면 전환 알림에 끊기지 않도록 높은 우선순위
                var announcement = AttributedString(new)
                announcement[AttributeScopes.AccessibilityAttributes.AnnouncementPriorityAttribute.self] = .high
                AccessibilityNotification.Announcement(announcement).post()
            }
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
