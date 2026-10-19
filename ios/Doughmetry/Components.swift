import DoughmetryCore
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
    /// 이 값이 바뀔 때마다 칸에 포커스를 준다 — 다른 컨트롤에서 입력으로 넘길 때(물 온도 마찰계수 '직접')
    var focusRequest = 0

    @State private var text = ""
    /// 편집 중 자기 자신이 쓴 값 — 외부 변경(레시피 불러오기·이스트 환산 등)과 구분
    @State private var selfWritten: Double?
    @FocusState private var focused: Bool
    /// 라벨 오른쪽에 비워 둘 폭 — 입력 칸 최소 폭(70)과 간격. 긴 라벨은 숫자 밑으로 들어가지 않고 줄을 바꾼다
    @ScaledMetric(relativeTo: .body) private var labelTrailingRoom: CGFloat = 86
    @Environment(\.dynamicTypeSize) private var typeSize

    /// iOS 26 미만 iPad 하드웨어 키보드에선 첫 키에 FocusState가 false로 바뀌어도 UITextField는 계속 편집 중이다.
    /// 그 뒤의 키를 버리지 않도록 focused만 믿지 않는다 — 프로그램이 쓰는 텍스트는 늘 display(value)라
    /// 그와 다른 텍스트는 사용자 입력이고, selfWritten이 남아 있으면 아직 편집 중이다
    private var focusMayLag: Bool {
        if #available(iOS 26, *) { return false }
        return true
    }

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

    private var stacked: Bool { typeSize.isAccessibilitySize && !label.isEmpty }

    private var accessibilityText: String {
        let name = accessibilityName ?? label
        return name.isEmpty ? unit : "\(name) (\(unit))"
    }

    var body: some View {
        // 접근성 글자 크기에선 라벨을 윗줄로 — 한 줄에 두면 긴 라벨이 글자 단위로 쪼개진다
        // 입력 칸(UITextField)이 라벨 밑까지 행 전체에 깔리고 라벨은 그 위에 글자만 얹는다 — 라벨·빈 간격을 누르면
        // 입력 칸이 직접 탭을 받는다. 탭으로 FocusState를 쓰면 목록을 민 뒤나 결과 바 '완료' 뒤에
        // 탭이 죽거나 다른 재료 칸에 포커스가 간다 (iOS 17·27). 윗줄 라벨·행의 위아래 여백은 바탕(FieldTapArea)이 받는다
        VStack(alignment: .leading, spacing: 4) {
            if stacked { labelText }
            HStack {
                ZStack(alignment: .leading) {
                    inputField
                    if !stacked && !label.isEmpty {
                        labelText.padding(.trailing, labelTrailingRoom)
                    }
                }
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(minWidth: 18, alignment: .leading)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .background { FieldTapArea(focusRequest: focusRequest).padding(.vertical, -FieldTapArea.slop) }
    }

    private var labelText: some View {
        Text(label)
            .foregroundStyle(.primary)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    private var inputField: some View {
        // 최소 폭은 키우지 않는다 — 폭이 고정된 칸(타임라인 분)에서 넘쳐 옆 칸을 덮는다
        TextField("0", text: $text)
            .keyboardType(integer ? .numberPad : .decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .focused($focused)
            .frame(minWidth: 70, maxWidth: .infinity)
            .accessibilityLabel(accessibilityText)
            // 라벨을 윗줄에 둔 칸은 값 쪽을 누르게 — iOS 17은 칸의 틀을 행 전체로 알려 가운데가 라벨 줄에 떨어진다
            .accessibilityActivationPoint(stacked ? UnitPoint(x: 0.9, y: 0.8) : .center)
            .onChange(of: text) { _, newText in
                guard focused || (focusMayLag && newText != display(value)) else { return }
                // 데시멀 키패드와 달리 하드웨어 키보드는 글자·한글도 친다 — 칸에 "655뮻"이 남은 채 계산은 655로 하지 않도록
                // 걷어낸다. 프로그램이 쓴 표시값(정수 칸의 "1e+15" 같은 지수 표기)은 그대로 둔다
                let allowed = newText.filter { ("0"..."9").contains($0) || $0 == "." || $0 == "," || $0.isWhitespace }
                if allowed != newText, newText != display(value) {
                    text = allowed
                    return
                }
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
                    // 26 미만 하드웨어 키보드는 편집 중에도 FocusState가 false로 거듭 튄다 — 그때마다 "700."을 "700"으로
                    // 되돌리면 다음 키가 잘린 글자 뒤에 붙는다(700.5 → 7005). 칸이 아직 편집 중이면 끝날 때
                    // (textDidEndEditing) 맞춘다
                    if focusMayLag, let field = FirstResponder.current as? UITextField, field.text == text { return }
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
                let editing = focused || (focusMayLag && selfWritten != nil)
                if !editing || current != selfWritten {
                    text = display(current)
                    selfWritten = focused ? current : nil
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UITextField.textDidEndEditingNotification)
            ) { _ in
                // 포커스 해제(onChange(of: focused))를 못 받은 하드웨어 키보드 편집도 끝나면 표시 형식으로 맞춘다
                guard focusMayLag, !focused else { return }
                text = display(value)
                selfWritten = nil
            }
            .onAppear {
                SelectAllOnFocus.install()
                text = display(value)
            }
    }
}

/// NumberField 바탕 — 칸 둘레(라벨·단위, 행의 위아래 여백)를 눌러도 그 칸이 포커스를 얻는다.
/// 칸(UITextField)은 한 줄 높이(약 22pt)라 44pt 행의 위쪽과 윗줄 라벨이 눌리지 않았다.
/// FocusState가 아니라 칸을 직접 응답자로 — FocusState로 주면 목록을 민 뒤나 '완료' 뒤에
/// 탭이 죽거나 다른 칸에 포커스가 간다 (iOS 17·27)
private struct FieldTapArea: UIViewRepresentable {
    /// NumberField 위아래로 늘리는 폭 — 목록 행의 위아래 여백(iOS 17 11pt, 27 15pt)까지.
    /// 셀 밖은 UIKit이 셀 단위로 가려 옆 행을 덮지 않는다
    static let slop: CGFloat = 16
    /// 바뀔 때마다 이 칸을 응답자로 — 탭과 같은 길(FocusState가 아니라 칸을 직접)
    var focusRequest = 0

    func makeUIView(context: Context) -> UIView { TapView(focusRequest: focusRequest) }
    func updateUIView(_ view: UIView, context: Context) {
        guard let view = view as? TapView, view.focusRequest != focusRequest else { return }
        view.focusRequest = focusRequest
        // 이 갱신을 부른 탭(세그먼트 등)이 끝난 뒤에 — 그 컨트롤이 아직 터치를 쥐고 있다
        DispatchQueue.main.async { view.focusField() }
    }

    private final class TapView: UIView {
        var focusRequest: Int

        init(focusRequest: Int) {
            self.focusRequest = focusRequest
            super.init(frame: .zero)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        }

        required init?(coder: NSCoder) { nil }

        // 늘린 바탕이 같은 행의 다른 입력 칸(위아래로 쌓인 이름·그램 칸) 위에 걸친 자리는 그 칸에 넘긴다 —
        // 바탕이 받으면 포커스만 옮기고 커서 놓기·다시 눌러 전체 선택 풀기·길게 누르기가 죽는다.
        // nil을 돌려주면 iOS 17에서 터치가 그대로 삼켜진다
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let hit = super.hitTest(point, with: event), let window else { return nil }
            let location = convert(point, to: window)
            var root = superview
            while let container = root, !(container is UIScrollView) {
                let inputs = Self.textInputs(in: container)
                if !inputs.isEmpty {
                    guard let input = inputs.first(where: { $0.convert($0.bounds, to: window).contains(location) })
                    else { return hit }
                    return input.hitTest(convert(point, to: input), with: event) ?? input
                }
                root = container.superview
            }
            return hit
        }

        @objc private func tapped(_ tap: UITapGestureRecognizer) {
            focusField()
        }

        func focusField() {
            guard let window else { return }
            let own = convert(bounds.insetBy(dx: 0, dy: FieldTapArea.slop), to: window)
            // 행(셀) 안에서만 찾는다 — 시트 뒤에 깔린 화면의 칸이 같은 자리에 있을 수 있다
            var root = superview
            while let container = root, !(container is UIScrollView) {
                let inputs = Self.textInputs(in: container)
                let target = inputs.first {
                    let frame = $0.convert($0.bounds, to: window)
                    return own.contains(CGPoint(x: frame.midX, y: frame.midY))
                }
                if let target {
                    if !target.isFirstResponder { target.becomeFirstResponder() }
                    return
                }
                root = container.superview
            }
        }

        private static func textInputs(in view: UIView) -> [UIView] {
            guard !view.isHidden, view.alpha > 0, view.isUserInteractionEnabled else { return [] }
            if let field = view as? UITextField { return field.isEnabled ? [field] : [] }
            if view is UITextView { return [view] }
            return view.subviews.flatMap(textInputs(in:))
        }
    }
}

/// 지금 키 입력을 받는 응답자 — UIKit은 직접 묻는 API가 없어 대상 없는 액션을 보내 받는 쪽을 잡는다
@MainActor
private enum FirstResponder {
    private static weak var found: UIResponder?

    static var current: UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.levainCaptureFirstResponder(_:)), to: nil, from: nil, for: nil)
        defer { found = nil }
        return found
    }

    fileprivate static func capture(_ responder: UIResponder) { found = responder }
}

extension UIResponder {
    @objc fileprivate func levainCaptureFirstResponder(_ sender: Any?) {
        FirstResponder.capture(self)
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

/// iOS 26 미만: 키보드가 뜬 채 iPad를 돌리면(세로 → 가로) 포커스된 칸이 키보드·결과 바 뒤에 남는다.
/// 키보드가 뜨거나 틀이 바뀔 때마다 편집 중인 칸을 둘러싼 스크롤 뷰를 칸이 보이는 데까지 민다 (계산기·변환기·가져오기 확인·타임라인 공용).
/// 26+는 시스템이 스스로 다시 맞추므로 설치하지 않는다
enum KeyboardAvoidance {
    @MainActor static func install() {
        if #available(iOS 26, *) { return }
        KeyboardAvoidanceObserver.install()
    }
}

@MainActor
private final class KeyboardAvoidanceObserver: NSObject {
    private static var shared: KeyboardAvoidanceObserver?

    static func install() {
        if shared == nil { shared = KeyboardAvoidanceObserver() }
    }

    /// 숫자·이름 칸(UITextField)과 여러 줄 메모 칸(TextField(axis: .vertical) → UITextView)
    private weak var activeField: UIView?
    /// 화면 좌표의 키보드 틀 — 화면 아래에 붙은 키보드만 (떠 있는·분리된 키보드는 칸을 가리지 않는다)
    private var dockedKeyboard: CGRect?

    override private init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(didBeginEditing(_:)),
            name: UITextField.textDidBeginEditingNotification, object: nil)
        center.addObserver(
            self, selector: #selector(didBeginEditing(_:)),
            name: UITextView.textDidBeginEditingNotification, object: nil)
        center.addObserver(
            self, selector: #selector(keyboardDidChange(_:)),
            name: UIResponder.keyboardDidShowNotification, object: nil)
        center.addObserver(
            self, selector: #selector(keyboardDidChange(_:)),
            name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
    }

    @objc private func didBeginEditing(_ note: Notification) {
        activeField = note.object as? UIView
    }

    @objc private func keyboardDidChange(_ note: Notification) {
        let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        let screen = activeField?.window?.windowScene?.screen.bounds
        if let frame, let screen, !frame.isEmpty, frame.maxY >= screen.maxY - 1 {
            dockedKeyboard = frame
        } else {
            dockedKeyboard = nil
        }
        // 돌린 직후엔 SwiftUI가 키보드·결과 바만큼 줄인 안전 영역(adjustedContentInset)을 반 박자 늦게 반영한다 —
        // 첫 번은 알림의 키보드 틀로 키보드 위까지, 늦게 반영된 안전 영역을 보고 결과 바 위까지 몇 번 더 맞춘다
        for delay in [0, 0.3, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.revealActiveField() }
        }
    }

    private func revealActiveField() {
        guard let field = activeField, field.isFirstResponder, let window = field.window,
            let scrollView = enclosingScrollView(of: field)
        else { return }
        let inset = scrollView.adjustedContentInset
        let bounds = scrollView.bounds
        var visibleBottom = bounds.maxY - inset.bottom
        if let keyboard = dockedKeyboard {
            let local = scrollView.convert(keyboard, from: window.screen.coordinateSpace)
            visibleBottom = min(visibleBottom, local.minY)
        }
        let visibleTop = bounds.minY + inset.top
        var target = field.convert(field.bounds, to: scrollView).insetBy(dx: 0, dy: -12)
        // 보이는 높이보다 큰 여러 줄 칸은 칸 전체 대신 커서 줄을 — 칸 위쪽에 맞추면 치는 줄이 결과 바·키보드 뒤로 간다
        if target.height > visibleBottom - visibleTop, let textView = field as? UITextView,
            let caret = textView.selectedTextRange?.end
        {
            target = textView.convert(textView.caretRect(for: caret), to: scrollView).insetBy(dx: 0, dy: -12)
        }
        var offset = scrollView.contentOffset
        if target.maxY > visibleBottom {
            offset.y += min(target.maxY - visibleBottom, target.minY - visibleTop)
        } else if target.minY < visibleTop {
            offset.y -= visibleTop - target.minY
        } else {
            return
        }
        let maxOffset = max(-inset.top, scrollView.contentSize.height + inset.bottom - bounds.height)
        offset.y = min(max(offset.y, -inset.top), maxOffset)
        scrollView.setContentOffset(offset, animated: true)
    }

    /// 가장 가까운 세로 스크롤 뷰 (Form·List의 컬렉션 뷰, ScrollView)
    private func enclosingScrollView(of view: UIView) -> UIScrollView? {
        var current = view.superview
        while let v = current {
            if let scroll = v as? UIScrollView, scroll.isScrollEnabled, !(scroll is UITextView) {
                return scroll
            }
            current = v.superview
        }
        return nil
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

/// 결과 칩 한 줄 — 칸이 넉넉하면 같은 폭 열로, 모자라면 긴 칩만 제 폭을 받고 나머지가 남은 칸을 나눈다.
/// 그래도 넘치면 모든 칩을 같은 비율로 줄인다. 같은 폭 HStack은 가장 긴 값(총 반죽) 하나만 70%로 줄였다
struct StatChipLine: Layout {
    var spacing: CGFloat = 12

    private func widths(_ subviews: Subviews, in width: CGFloat?) -> [CGFloat] {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        guard let width, width.isFinite, !ideals.isEmpty else { return ideals }
        let room = max(0, width - spacing * CGFloat(ideals.count - 1))
        let total = ideals.reduce(0, +)
        guard total <= room else {
            let scale = total > 0 ? room / total : 0
            return ideals.map { $0 * scale }
        }
        // 넓은 칩부터 제 폭으로 떼어 내고, 남은 칩은 남은 칸을 똑같이 나눈다
        var share = room / CGFloat(ideals.count)
        var rest = room
        var count = ideals.count
        for ideal in ideals.sorted(by: >) where ideal > share && count > 1 {
            rest -= ideal
            count -= 1
            share = rest / CGFloat(count)
        }
        return ideals.map { max($0, share) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ws = widths(subviews, in: proposal.width)
        let height =
            zip(subviews, ws)
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
            .max() ?? 0
        let natural = ws.reduce(0, +) + spacing * CGFloat(max(0, ws.count - 1))
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? natural
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, w) in zip(subviews, widths(subviews, in: bounds.width)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                proposal: ProposedViewSize(width: w, height: nil))
            x += w + spacing
        }
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
    /// 그램 색을 덮어쓴다 — 불가능한 역산 결과(음수)만 danger로
    var valueTint: Color? = nil

    @ScaledMetric(relativeTo: .footnote) private var pctWidth: CGFloat = 64
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // 접근성 글자 크기에선 이름을 위, 수치를 아래 줄로 — 한 줄에 두면 이름이 글자 단위로 쪼개진다.
                // 그램은 자르지 않는다("1120....") — 그램과 %가 한 줄에 안 들어가면 %를 그 아랫줄로
                VStack(alignment: .leading, spacing: 4) {
                    nameText
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Spacer(minLength: 8)
                            gramsText.layoutPriority(1)
                            if let pct {
                                pctText(pct).frame(width: pctWidth, alignment: .trailing)
                            }
                        }
                        VStack(alignment: .trailing, spacing: 2) {
                            gramsText
                            if let pct { pctText(pct) }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            } else {
                HStack {
                    nameText
                    HStack {
                        Spacer(minLength: 8)
                        gramsText
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        pctText(pct ?? "")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(width: pctWidth, alignment: .trailing)
                    }
                }
            }
        }
        // VoiceOver가 "강력분, 4000.0 g, 72.7%"를 한 항목으로 읽도록
        .accessibilityElement(children: .combine)
    }

    private var nameText: some View {
        Text(name)
            .font(secondary ? .footnote : nil)
            .fontWeight(bold ? .semibold : .regular)
            .foregroundStyle(secondary ? Color.secondary : Color.primary)
    }

    private var gramsText: some View {
        Text(grams.isEmpty ? "" : grams + " g")
            .font(secondary ? .footnote : nil)
            .monospacedDigit()
            .fontWeight(bold ? .semibold : .regular)
            .foregroundStyle(valueTint ?? (bold ? Color.brass : secondary ? Color.secondary : Color.primary))
    }

    private func pctText(_ pct: String) -> some View {
        Text(pct)
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

/// 날짜·시각 선택 행. iOS 26 미만의 compact DatePicker는 가장 큰 표준 글자 크기(XXXL)부터 라벨을 낱말 중간에서,
/// 접근성 글자 크기에선 한 글자씩 세로로 쪼갠다 —
/// 라벨을 윗줄에 따로 두고 피커는 라벨 없이 아랫줄에. 26+는 시스템이 스스로 라벨을 위로 쌓는다
struct AXDatePicker: View {
    let label: String
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents

    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        _ label: String, selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date, .hourAndMinute]
    ) {
        self.label = label
        _selection = selection
        self.displayedComponents = displayedComponents
    }

    private var stacksLabel: Bool {
        guard typeSize >= .xxxLarge else { return false }
        if #available(iOS 26, *) { return false }
        return true
    }

    var body: some View {
        if stacksLabel {
            VStack(alignment: .leading, spacing: 4) {
                // 피커가 라벨을 숨겨도 VoiceOver엔 그 이름을 읽힌다 — 여기선 화면용으로만
                Text(label)
                    .accessibilityHidden(true)
                DatePicker(label, selection: $selection, displayedComponents: displayedComponents)
                    .labelsHidden()
            }
        } else {
            DatePicker(label, selection: $selection, displayedComponents: displayedComponents)
        }
    }
}

extension View {
    /// 저장 같은 동작 뒤 잠깐 뜨는 상태 알림 (웹 Toast처럼 2.6초). message를 넣으면 아래쪽에 뜨고 VoiceOver가 읽으며, 받는 즉시 nil로 돌린다.
    /// 아래 안전 영역 위에 놓이므로 요약 바를 단 safeAreaInset(edge: .bottom)보다 먼저(안쪽에) 붙여야 바를 가리지 않는다
    func toast(_ message: Binding<String?>) -> some View { modifier(ToastModifier(message: message)) }

    /// 키보드가 떠 있는 동안 내비게이션 바 오른쪽에 "완료" — iOS 26+의 떠 있는 키보드 액세서리(.keyboard 툴바)는
    /// 포커스된 행의 오른쪽 정렬 값을 덮는다
    func keyboardDoneButton() -> some View { modifier(KeyboardDoneToolbar()) }

    /// 피커 모양 — 기본은 세그먼트, 접근성 글자 크기에선 이름과 고른 값(value)을 위아래로 그린 메뉴(AXMenuPicker).
    /// 세그먼트 글자는 Dynamic Type을 따라 커지지 않아 아주 큰 본문 옆에서 13pt 남짓으로 남는다
    func adaptiveSegmented(_ label: String, value: String) -> some View {
        modifier(AdaptiveSegmented(label: label, value: value))
    }
}

private struct AdaptiveSegmented: ViewModifier {
    let label: String
    let value: String
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        if typeSize.isAccessibilitySize {
            AXMenuPicker(label, value: value) { content }
        } else {
            content.pickerStyle(.segmented)
        }
    }
}

/// 접근성 글자 크기의 고르기 행 — 이름과 고른 값을 한 메뉴 단추 안에 위아래로 그린다.
/// 시스템 메뉴 Picker는 값이 두 줄로 접혀도 행 높이를 한 줄로 잡아 이름에 붙고 둘째 줄이 구분선에 잘린다 (iOS 17·18·27).
/// iOS 26 전의 메뉴 Picker는 이름과 값을 한 줄에 두어 낱말이 중간에서 끊기기도 한다
struct AXMenuPicker<P: View>: View {
    private let label: String
    private let value: String
    private let picker: P

    init(_ label: String, value: String, @ViewBuilder picker: () -> P) {
        self.label = label
        self.value = value
        self.picker = picker()
    }

    var body: some View {
        Menu {
            picker
                .pickerStyle(.inline)
                .labelsHidden()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .foregroundStyle(Color.primary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                }
            }
            // 메뉴 라벨은 여러 줄 글자를 가운데로 맞춘다
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

/// '추가' 메뉴의 라벨 — 행 폭 전체가 메뉴를 연다 (Menu 행은 라벨 글자·아이콘만 눌린다).
/// Menu 안의 Label은 접근성 글자 크기에서 낱말 중간에서 끊긴다 ("Ad | d liquid", iOS 17·18) — 아이콘과 글자를 직접 늘어놓는다
struct AddMenuLabel: View {
    let title: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                HStack {
                    Image(systemName: "plus.circle")
                        .accessibilityHidden(true)
                    Text(title)
                }
            } else {
                Label(title, systemImage: "plus.circle")
            }
        }
        // 메뉴 라벨은 여러 줄 글자를 가운데로 맞춘다
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
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

/// 띄운 알림 한 번 — 같은 문구를 다시 띄워도 id가 달라 타이머·VoiceOver 안내가 처음부터 다시 돈다
private struct Toast: Equatable {
    let id = UUID()
    let text: String
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    @State private var toast: Toast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                // 늘 있는 바깥 틀에 애니메이션을 걸어야 알림이 들고 나는 전환만 움직인다 (본문 변경까지 번지지 않게)
                ZStack {
                    if let toast {
                        Text(toast.text)
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
                .animation(.easeInOut(duration: 0.25), value: toast)
                .allowsHitTesting(false)
            }
            // 받은 문구는 바로 비운다 — 같은 문구를 다시 넣어도 값이 바뀌어(nil → 문구) 새 알림으로 잡힌다
            .onChange(of: message) { _, new in
                guard let new else { return }
                toast = Toast(text: new)
                message = nil
            }
            .task(id: toast?.id) {
                guard let shown = toast else { return }
                // 탭을 떠나 취소돼도 지운다 — 남겨 두면 돌아올 때 지난 알림이 다시 뜬다
                try? await Task.sleep(for: .seconds(2.6))
                if toast?.id == shown.id { toast = nil }
            }
            .onChange(of: toast?.id) {
                guard let toast else { return }
                // 저장 시트가 닫히며 생기는 화면 전환 알림에 끊기지 않도록 높은 우선순위
                var announcement = AttributedString(toast.text)
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
