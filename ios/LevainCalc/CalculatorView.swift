import LevainCore
import SwiftUI
import UIKit

struct CalculatorView: View {
    @Environment(AppModel.self) private var model
    @State private var showTable = false
    @State private var showSave = false
    @State private var savedFeedback = false
    @State private var showResetDialog = false
    @State private var keyboardVisible = false
    @State private var toastMessage: String?
    /// VoiceOver 결과 안내 — 입력이 멈춘 뒤 한 번만 읽도록 미룬다
    @State private var announceTask: Task<Void, Never>?
    @State private var wideEnoughForFiche = false
    @State private var showGlossary = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 넓은 가로 창(iPad 가로 — 13″ 1376pt, 11″ 1210pt)에선 배합표를 오른쪽 열에 늘 보인다.
    /// 결과 바·배합표 시트를 대신하고, 결과 바는 키보드를 내릴 '완료'가 필요한 편집 중에만 보인다
    private var showsSideFiche: Bool { sizeClass == .regular && wideEnoughForFiche }

    var body: some View {
        @Bindable var model = model
        let dough = model.calc.currentDough
        let stats = computeStats(dough)
        let pieces = model.calc.currentPieces
        let negativeWater = model.calc.mode == .b && dough.water < -1e-9
        let negativeFlour = model.calc.mode == .b && dough.flours.contains { $0.grams < -1e-9 }
        // 모드 B에서 목표 조합이 물리적으로 불가능한 경우 — 저장도 막는다
        let infeasible = negativeWater || negativeFlour
        let spokenResult = spokenSummary(dough: dough, stats: stats)

        NavigationStack {
            HStack(spacing: 0) {
                Form {
                    Section {
                        Picker(L("입력 모드"), selection: $model.calc.mode) {
                            Text(L("재료 입력")).tag(CalcMode.a)
                            Text(L("목표 역산")).tag(CalcMode.b)
                        }
                        .adaptiveSegmented(
                            L("입력 모드"), value: model.calc.mode == .a ? L("재료 입력") : L("목표 역산"))
                        TextField(L("레시피 이름"), text: $model.calc.name)
                            .accessibilityLabel(L("레시피 이름"))
                    }

                    if model.calc.mode == .a {
                        IngredientFormSections(
                            input: $model.calc.input, stats: stats, precision: model.precision,
                            basis: model.pctBasis)
                        Section {
                            NumberField(
                                label: L("분할 개수"), value: $model.calc.pieces,
                                unit: L("개"), maxValue: 1000, integer: true)
                            ScaleRecipeButton(doughWeight: stats.doughWeight)
                        } header: {
                            Text(L("분할"))
                        } footer: {
                            Text(L("0이면 분할하지 않습니다."))
                        }
                        .textCase(nil)
                    } else {
                        TargetFormSections(target: $model.calc.target)
                        targetErrors(dough: dough)
                        TargetResultSection(dough: dough, precision: model.precision)
                    }
                    Section {
                        Button {
                            model.sendToConverter(name: model.calc.name, input: dough)
                        } label: {
                            Label(L("이 배합으로 르방 변환"), systemImage: "arrow.left.arrow.right")
                        }
                        .disabled(infeasible || dough.levain.hydration <= 0)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .readableFormWidth()
                // 결과 바 안쪽에 단다 — 바깥(safeAreaInset 뒤)에 달면 토스트가 결과 바를 가린다
                .toast($toastMessage)
                // keyboardDoneButton()을 달지 않는다 — 편집 중엔 아래 결과 바가 완료를 보인다 (내비게이션 바에 완료가 둘이 된다)
                .safeAreaInset(edge: .bottom) {
                    if !showsSideFiche || keyboardVisible {
                        ResultBar(
                            chips: model.calc.mode == .a
                                ? summaryChips(stats: stats, pieces: pieces, precision: model.precision)
                                : solvedChips(
                                    dough: dough, negativeWater: negativeWater, negativeFlour: negativeFlour),
                            isEditing: keyboardVisible,
                            onExpand: { showTable = true },
                            expandHint: L("전체 배합표를 엽니다")
                        )
                        .accessibilityIdentifier("calc.resultBar")
                    }
                }
                if showsSideFiche {
                    FicheColumn(
                        name: model.calc.name, input: dough, stats: stats, pieces: pieces,
                        precision: model.precision, basis: model.pctBasis,
                        onGlossary: { showGlossary = true })
                    .frame(width: 460)
                    .accessibilityIdentifier("calc.sideFiche")
                }
            }
            .onGeometryChange(for: Bool.self) { $0.size.width >= 1100 } action: {
                wideEnoughForFiche = $0
            }
            .modifier(LegacyBarBackground(visible: showsSideFiche))
            // 배합표 열 안에 달지 않는다 — 세로로 돌려 열이 사라지면 열린 용어 설명도 함께 빠진다
            .navigationDestination(isPresented: $showGlossary) { GlossaryView() }
            // 두 손가락 두 번 탭 — 어디서든 지금 결과를 다시 읽는다
            .accessibilityAction(.magicTap) { announce(spokenResult, priority: .default) }
            .navigationTitle(L("계산기"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    RecipeLoadMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // iOS 26+는 확인창을 단 뷰에서 팝오버로 띄운다 — 화면 전체가 아니라 이 버튼에 단다
                    Button {
                        showResetDialog = true
                    } label: {
                        Label(L("새 배합"), systemImage: "square.and.pencil")
                    }
                    .confirmationDialog(
                        model.calcIsDirty
                            ? L("새 배합을 시작할까요? 저장하지 않은 입력은 지워집니다.") : L("새 배합 시작"),
                        isPresented: $showResetDialog, titleVisibility: .visible
                    ) {
                        Button(L("빈 배합으로 시작")) {
                            model.resetCalc(empty: true)
                        }
                        Button(L("예시 배합으로 시작 (캉파뉴)")) {
                            model.resetCalc(empty: false)
                        }
                        Button(L("취소"), role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("저장")) {
                        // 떠 있던 키보드를 먼저 내린다 — 포커스가 남은 채 시트를 띄우면 시트가 닫힐 때 UIKit이
                        // 그 칸(레시피 이름 등)에 포커스를 되돌려 키보드가 다시 뜬다
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        showSave = true
                    }
                    .accessibilityIdentifier("calc.save")
                    // 르방 수분율 0 이하는 코덱 검증에서 탈락해 저장해도 다음 실행 때 사라진다 (이전 draft 대비)
                    .disabled(infeasible || dough.levain.hydration <= 0)
                }
            }
            // ⌘N·⌘S는 보이는 탭에서만 — 툴바 버튼에 달면 한 번 들른 탭(TabView가 살려 둔다)의 단축키가
            // 다른 탭에서도 눌려 보이지 않는 확인창·저장 시트를 띄운다. 제목은 ⌘ 길게 누르기 목록에 나온다
            .background {
                if model.selectedTab == .calculator {
                    Group {
                        Button(L("새 배합")) {
                            guard !modalIsPresented() else { return }
                            showResetDialog = true
                        }
                        .keyboardShortcut("n", modifiers: .command)
                        Button(L("저장")) {
                            guard !modalIsPresented() else { return }
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            showSave = true
                        }
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(infeasible || dough.levain.hydration <= 0)
                    }
                    .opacity(0)
                    .accessibilityHidden(true)
                }
            }
            .onChange(of: spokenResult) { _, text in scheduleAnnouncement(text) }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in keyboardVisible = true }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in keyboardVisible = false }
            .sheet(isPresented: $showTable) {
                BakersTableSheet(
                    name: model.calc.name, input: dough, stats: stats, pieces: pieces,
                    precision: model.precision, basis: model.pctBasis)
            }
            .sheet(isPresented: $showSave) {
                let loaded = model.calc.recipeId.flatMap { id in
                    model.recipes.first { $0.id == id }
                }
                // 모드 B는 밀가루·물·소금·르방만 역산한다 — 불러온 레시피에 덮어쓰면 그 레시피의
                // 바시나주·액체·이스트·기타 재료가 사라진다. 모드 B 저장은 늘 새 레시피로
                let replaceable = model.calc.mode == .a ? loaded : nil
                SaveRecipeSheet(
                    initialName: model.calc.name,
                    initialTags: loaded?.tags ?? [],
                    initialNote: loaded?.note ?? "",
                    allowOverwrite: replaceable != nil,
                    loadedName: replaceable?.name
                ) { name, tags, note, overwrite in
                    let id = overwrite ? (replaceable?.id ?? newId()) : newId()
                    let now = isoNow()
                    let recipe = Recipe(
                        id: id, name: name, note: note, tags: tags.isEmpty ? nil : tags,
                        createdAt: now, updatedAt: now,
                        input: dough,
                        targetDoughWeight: model.calc.mode == .b
                            ? model.calc.target.spec.doughWeight : nil,
                        pieces: pieces)
                    model.save(recipe)
                    model.calc.name = name
                    model.calc.recipeId = id
                    model.markCalcSaved()
                    savedFeedback.toggle()
                    toastMessage = overwrite ? L("레시피를 덮어썼습니다") : LF("'%@' 레시피를 저장했습니다", name)
                }
            }
            .sensoryFeedback(.success, trigger: savedFeedback)
        }
    }

    /// 모드 B 결과 바 — 역산한 그램. 불가능한 조합이면 음수가 된 칩을 danger로
    private func solvedChips(dough: DoughInput, negativeWater: Bool, negativeFlour: Bool)
        -> [StatChip]
    {
        let p = model.precision
        return [
            StatChip(
                title: L("밀가루"), value: fmtGrams(addedFlourTotal(dough), p) + " g",
                tint: negativeFlour ? .danger : .brass),
            StatChip(
                title: L("물"), value: fmtGrams(dough.water, p) + " g",
                tint: negativeWater ? .danger : .brass),
            StatChip(title: L("소금"), value: fmtGrams(dough.salt, p) + " g"),
            StatChip(title: L("르방"), value: fmtGrams(dough.levain.grams, p) + " g"),
        ]
    }

    /// VoiceOver가 읽는 결과 — 모드 A는 총 수분율·총 반죽, 모드 B는 역산한 그램
    private func spokenSummary(dough: DoughInput, stats: DoughStats) -> String {
        let p = model.precision
        if model.calc.mode == .a {
            return LF(
                "총 수분율 %@, 총 반죽 %@그램", fmtPct(stats.hydrationPct), fmtGrams(stats.doughWeight, p))
        }
        return LF(
            "밀가루 %@그램, 물 %@그램, 소금 %@그램, 르방 %@그램",
            fmtGrams(addedFlourTotal(dough), p), fmtGrams(dough.water, p), fmtGrams(dough.salt, p),
            fmtGrams(dough.levain.grams, p))
    }

    private func scheduleAnnouncement(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        announceTask?.cancel()
        announceTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            // 낮은 우선순위 — 입력 반향을 끊지 않고 뒤에 줄을 선다
            announce(text, priority: .low)
        }
    }

    private func announce(_ text: String, priority: AnnouncementPriority.Value) {
        var announcement = AttributedString(text)
        // 키 타입 첨자로 단다 — 동적 멤버(키패스)로 달면 Swift 6에서 Sendable 경고가 난다
        announcement[AnnouncementPriority.self] = priority
        AccessibilityNotification.Announcement(announcement).post()
    }

    /// 모드 B에서 목표 조합이 물리적으로 불가능한 경우
    @ViewBuilder
    private func targetErrors(dough: DoughInput) -> some View {
        let negativeWater = dough.water < -1e-9
        let negativeFlour = dough.flours.contains { $0.grams < -1e-9 }
        if negativeWater || negativeFlour {
            Section {
                if negativeWater {
                    Label(
                        LF("이 조합에서는 첨가 물이 음수(%@ g)가 됩니다. PFF를 낮추거나 총 수분율을 높이세요.", fmtGrams(dough.water, model.precision)),
                        systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.danger)
                        .font(.footnote)
                }
                if negativeFlour {
                    Label(
                        L("르방 속 밀가루가 총 밀가루를 초과합니다. PFF를 낮추세요."),
                        systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.danger)
                        .font(.footnote)
                }
            }
        }
    }
}

/// 26 미만의 내비게이션·탭 막대는 화면의 스크롤 뷰 하나만 보고 배경을 켠다 — 폼과 배합표 열(List)이 나란히 있으면
/// 폼이 막대 밑으로 스크롤돼도 투명한 채라 글자가 겹친다. 그동안은 배경을 늘 켠다
private struct LegacyBarBackground: ViewModifier {
    let visible: Bool

    func body(content: Content) -> some View {
        if #unavailable(iOS 26) {
            content.toolbarBackground(visible ? .visible : .automatic, for: .navigationBar, .tabBar)
        } else {
            content
        }
    }
}

private typealias AnnouncementPriority = AttributeScopes.AccessibilityAttributes
    .AnnouncementPriorityAttribute

/// 저장된 레시피 불러오기 메뉴 — 계산기 본문과 따로 그린다. 본문에 두면 키 입력마다 레시피 수만큼의
/// 메뉴 항목을 다시 만든다 (이 뷰는 model.recipes가 바뀔 때만 다시 그려진다)
private struct RecipeLoadMenu: View {
    @Environment(AppModel.self) private var model
    /// 저장하지 않은 입력이 있을 때 고른 레시피 — 확인 뒤에만 불러온다
    @State private var pendingLoad: Recipe?

    /// 메뉴에 보이는 최근 레시피 수 — 나머지는 레시피 탭(검색)에서
    private let limit = 10

    var body: some View {
        if !model.recipes.isEmpty {
            Menu {
                ForEach(model.recipes.prefix(limit)) { recipe in
                    Button(recipe.name) {
                        if model.calcIsDirty {
                            pendingLoad = recipe
                        } else {
                            model.loadIntoCalculator(recipe)
                        }
                    }
                }
                if model.recipes.count > limit {
                    Divider()
                    Button(L("모두 보기…")) { model.selectedTab = .recipes }
                }
            } label: {
                Label(L("저장된 레시피 불러오기"), systemImage: "book.closed")
            }
            // 메뉴 항목이 아니라 메뉴에 단다 — 항목은 메뉴가 닫히며 사라져 확인창을 띄우지 못한다
            .confirmationDialog(
                L("레시피를 불러올까요? 저장하지 않은 입력은 지워집니다."),
                isPresented: Binding(
                    get: { pendingLoad != nil }, set: { if !$0 { pendingLoad = nil } }),
                titleVisibility: .visible,
                presenting: pendingLoad
            ) { recipe in
                Button(L("불러오기"), role: .destructive) { model.loadIntoCalculator(recipe) }
                Button(L("취소"), role: .cancel) {}
            }
        }
    }
}

/// 배율 조정 — 모든 재료의 그램을 같은 배율로 곱한다 (scaleDough). 수분율·소금·PFF·이스트 %는 그대로
private struct ScaleRecipeButton: View {
    @Environment(AppModel.self) private var model
    let doughWeight: Double

    @State private var showSheet = false
    @State private var scaledCount = 0

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Label(L("배율 조정"), systemImage: "arrow.up.left.and.arrow.down.right")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .disabled(!(doughWeight > 0))
        .sheet(isPresented: $showSheet) {
            ScaleRecipeSheet(
                doughWeight: doughWeight, pieces: model.calc.pieces, precision: model.precision
            ) { factor, pieces in
                model.calc.input = scaleDough(model.calc.input, by: factor)
                if let pieces { model.calc.pieces = pieces }
                scaledCount += 1
            }
        }
        .sensoryFeedback(.success, trigger: scaledCount)
    }
}

/// 배율 · 총 반죽 무게 · 개수 × 개당 — 웹 ScaleDialog와 같은 선택지와 범위
private struct ScaleRecipeSheet: View {
    enum Mode: Hashable { case factor, weight, pieces }

    let doughWeight: Double
    let precision: Precision
    /// factor는 유한한 양수. 개수 × 개당이면 분할 개수도 함께
    let onApply: (_ factor: Double, _ pieces: Double?) -> Void

    @State private var mode = Mode.factor
    @State private var factor: Double = 1
    @State private var weight: Double = 0
    @State private var count: Double
    @State private var each: Double = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        doughWeight: Double, pieces: Double, precision: Precision,
        onApply: @escaping (_ factor: Double, _ pieces: Double?) -> Void
    ) {
        self.doughWeight = doughWeight
        self.precision = precision
        self.onApply = onApply
        _count = State(initialValue: pieces > 0 ? pieces : 0)
    }

    /// 쓸 수 없는 입력이면 nil — 배율은 0.01~100, 분할 개수는 분할 개수 칸과 같은 1~1000개
    private var k: Double? {
        guard doughWeight > 0 else { return nil }
        let k: Double
        switch mode {
        case .factor:
            guard factor >= 0.01, factor <= 100 else { return nil }
            k = factor
        case .weight:
            k = weight / doughWeight
        case .pieces:
            guard count >= 1, count <= 1000 else { return nil }
            k = count * each / doughWeight
        }
        return k.isFinite && k > 0 ? k : nil
    }

    private var modeName: String {
        switch mode {
        case .factor: L("배율")
        case .weight: L("총 반죽")
        case .pieces: L("개수 × 개당")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("배율 조정"), selection: $mode) {
                        Text(L("배율")).tag(Mode.factor)
                        // 칸 이름(총 반죽 무게)보다 짧게 — 영어 "Total dough weight"는 375pt 폭에서 잘린다
                        Text(L("총 반죽")).tag(Mode.weight)
                        Text(L("개수 × 개당")).tag(Mode.pieces)
                    }
                    .adaptiveSegmented(L("배율 조정"), value: modeName)
                    switch mode {
                    case .factor:
                        // 접근성 글자 크기에선 위아래로 — 나란히 두면 버튼 이름이 단어 중간에서 끊긴다
                        let ax = typeSize.isAccessibilitySize
                        let buttons =
                            ax
                            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                        buttons {
                            Button {
                                apply(0.5, pieces: nil)
                            } label: {
                                Text(L("절반으로 (×½)")).frame(maxWidth: ax ? .infinity : nil)
                            }
                            Button {
                                apply(2, pieces: nil)
                            } label: {
                                Text(L("두 배로 (×2)")).frame(maxWidth: ax ? .infinity : nil)
                            }
                        }
                        // 한 행의 기본 버튼은 행 전체가 눌려 둘 다 실행된다 — 테두리 버튼으로 따로 누르게
                        .buttonStyle(.bordered)
                        NumberField(
                            label: L("배율"), value: $factor, unit: "×", fractionDigits: 2,
                            minValue: 0.01, maxValue: 100)
                    case .weight:
                        NumberField(label: L("총 반죽 무게"), value: $weight)
                    case .pieces:
                        NumberField(
                            label: L("분할 개수"), value: $count, unit: L("개"), maxValue: 1000,
                            integer: true)
                        NumberField(label: L("개당 무게"), value: $each)
                    }
                } footer: {
                    Text(
                        LF(
                            "지금 총 반죽은 %@ g입니다. 모든 재료를 같은 배율로 늘리거나 줄여 수분율·소금·PFF는 그대로입니다.",
                            fmtGrams(doughWeight, precision)))
                }
                Section {
                    preview
                        .accessibilityElement(children: .combine)
                }
            }
            .navigationTitle(L("배율 조정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("적용")) {
                        if let k { apply(k, pieces: mode == .pieces ? count : nil) }
                    }
                    .disabled(k == nil)
                    .accessibilityIdentifier("scale.apply")
                }
            }
        }
    }

    /// 지금 무게 → 바뀔 무게 (배율). 접근성 글자 크기에선 한 줄에 두면 지금 무게가 조각나고 결과가 줄어든다 —
    /// 결과를 아랫줄에 두고, 배율 표시도 결과 옆에 안 들어가면 그 아래로
    @ViewBuilder
    private var preview: some View {
        let from = Text("\(fmtGrams(doughWeight, precision)) g →").monospacedDigit()
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                from
                if let k {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { scaled(k) }
                        VStack(alignment: .leading, spacing: 4) { scaled(k) }
                    }
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(spacing: 6) {
                from
                Spacer(minLength: 0)
                if let k {
                    scaled(k)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func scaled(_ k: Double) -> some View {
        StatValue(value: "\(fmtGrams(doughWeight * k, precision)) g")
        Text("(×\(fmtCount((k * 1000).rounded() / 1000)))")
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private func apply(_ factor: Double, pieces: Double?) {
        onApply(factor, pieces)
        dismiss()
    }
}

/// 모드 B 목표 입력 폼
struct TargetFormSections: View {
    @Binding var target: TargetForm

    var body: some View {
        Section(L("목표")) {
            Picker(L("무게 입력"), selection: $target.byPieces) {
                Text(L("총 반죽 무게")).tag(false)
                Text(L("개수 × 개당")).tag(true)
            }
            .adaptiveSegmented(L("무게 입력"), value: target.byPieces ? L("개수 × 개당") : L("총 반죽 무게"))
            if target.byPieces {
                NumberField(
                    label: L("분할 개수"), value: $target.pieces, unit: L("개"),
                    maxValue: 1000, integer: true)
                NumberField(label: L("개당 무게"), value: $target.pieceWeight)
                HStack {
                    Text(L("총 반죽 무게")).foregroundStyle(.secondary)
                    Spacer()
                    StatValue(value: fmtGrams(target.pieces * target.pieceWeight, .tenth) + " g")
                }
            } else {
                NumberField(label: L("총 반죽 무게"), value: $target.doughWeight)
            }
        }
        .textCase(nil)
        Section {
            NumberField(label: L("총 수분율"), value: $target.hydrationPct, unit: "%")
            NumberField(label: L("소금"), value: $target.saltPct, unit: "%")
            NumberField(label: "PFF", value: $target.pffPct, unit: "%")
            NumberField(
                label: L("르방 수분율"), value: $target.levainHydrationPct, unit: "%",
                minValue: 1, maxValue: 1000)
        } header: {
            Text(L("비율 (총 밀가루 기준)"))
        } footer: {
            Text(L("밀가루·물·소금·르방만 역산합니다. 바시나주·액체·이스트는 재료 입력 모드에서."))
        }
        .textCase(nil)
    }
}

/// 모드 B 역산 결과
struct TargetResultSection: View {
    let dough: DoughInput
    let precision: Precision

    var body: some View {
        Section(L("역산 결과")) {
            row(L("첨가 밀가루"), addedFlourTotal(dough))
            row(L("본반죽 물"), dough.water)
            row(L("소금"), dough.salt)
            row(levainName(dough.levain.hydration), dough.levain.grams)
        }
        .textCase(nil)
    }

    private func row(_ name: String, _ grams: Double) -> some View {
        let g = fmtGrams(grams, precision)
        // 불가능한 조합의 음수는 결과값(brass)이 아니다 — 결과 바 칩과 같은 danger로
        return TableRow(
            name: name, grams: g, pct: nil, bold: true, valueTint: grams < -1e-9 ? .danger : nil)
            .ficheRowAccessibility(name: name, grams: g, pct: nil)
    }
}
