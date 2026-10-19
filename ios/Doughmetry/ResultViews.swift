import DoughmetryCore
import SwiftUI
import UIKit

/// 하단 고정 결과 바 — 계산기·변환기·도구 화면 공용 셸. `.safeAreaInset(edge: .bottom)`에 단다.
/// - isEditing: 키보드가 떠 있는 동안 참 — 펼침 화살표 대신 키보드를 내리는 완료 버튼을 보인다.
///   이 바를 다는 화면엔 keyboardDoneButton()을 달지 않는다 (완료가 둘이 된다)
/// - onExpand: 바를 탭했을 때(전체 결과 보기). nil이면 버튼 없이 내용만 — VoiceOver에 죽은 버튼이 생기지 않도록
/// - expandHint: onExpand 버튼의 VoiceOver 힌트
/// 칩만 보일 땐 `ResultBar(chips:isEditing:onExpand:expandHint:)` (큰 글자에선 2열로 접힌다),
/// 오류 문구 같은 다른 내용은 뷰 빌더로 넘긴다 — 여러 뷰를 넘기면 가로로 늘어놓는다
struct ResultBar<Content: View>: View {
    var isEditing: Bool
    var onExpand: (() -> Void)?
    var expandHint: String?
    let content: Content

    init(
        isEditing: Bool = false, onExpand: (() -> Void)? = nil, expandHint: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isEditing = isEditing
        self.onExpand = onExpand
        self.expandHint = expandHint
        self.content = content()
    }

    var body: some View {
        // 여백은 버튼 라벨 안에 둔다 — 카드 전체가 탭 영역이 되도록
        HStack(spacing: 0) {
            if let onExpand {
                Button(action: onExpand) {
                    HStack(spacing: 12) {
                        row
                        if !isEditing {
                            Image(systemName: "chevron.up.circle.fill")
                                .foregroundStyle(Color.bottle)
                                .font(.title3)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, isEditing ? 6 : 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // iPad 트랙패드 포인터 강조 — 모서리는 카드(14)와 같게
                .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 14))
                .hoverEffect(.highlight)
                .accessibilityHint(expandHint ?? "")
            } else {
                row
                    .padding(.leading, 16)
                    .padding(.trailing, isEditing ? 6 : 16)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
            }
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
        // iPad(넓은 창)에서 화면 끝까지 늘어나지 않게 — readableFormWidth()의 폭과 맞춘다
        .frame(maxWidth: 700)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        // iOS 17·18의 불투명 탭 바와 카드 사이 틈·양옆 여백으로 밑에 깔린 목록 글자가 비친다 (26+는 유리 탭 바라 그대로)
        .background {
            if #unavailable(iOS 26) {
                Rectangle().fill(.bar)
            }
        }
        // 늘 떠 있는 바라 키보드와 함께 폼을 덮지 않도록 AX1에서 멈춘다 — 전체 수치는 배합표 시트에서 끝까지 커진다
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var row: some View {
        HStack(spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ResultBar where Content == StatChipRow {
    init(
        chips: [StatChip], isEditing: Bool = false, onExpand: (() -> Void)? = nil,
        expandHint: String? = nil
    ) {
        self.init(isEditing: isEditing, onExpand: onExpand, expandHint: expandHint) {
            StatChipRow(chips: chips)
        }
    }
}

/// 결과 칩 한 줄 — VoiceOver는 칩 전체를 한 요소로 읽는다
struct StatChipRow: View {
    let chips: [StatChip]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        layout.accessibilityElement(children: .combine)
    }

    /// 큰 글자(칩 4개면 xLarge부터, 접근성 크기는 늘)에선 한 줄에 칩이 다 들어가지 않는다 — 2열로 접는다
    @ViewBuilder
    private var layout: some View {
        if typeSize.isAccessibilitySize || (chips.count > 3 && typeSize >= .xLarge) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(Array(stride(from: 0, to: chips.count, by: 2)), id: \.self) { i in
                    GridRow {
                        chips[i]
                        if i + 1 < chips.count { chips[i + 1] }
                    }
                }
            }
        } else {
            StatChipLine(spacing: chips.count > 3 ? 8 : 12) {
                ForEach(chips.indices, id: \.self) { chips[$0] }
            }
        }
    }
}

/// 배합 요약 칩 — 총 수분율 / 총 반죽 / PFF / (개당)
func summaryChips(stats: DoughStats, pieces: Double?, precision: Precision) -> [StatChip] {
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

/// 전체 배합표 (fiche technique) — 시트로 표시, 텍스트 공유 지원
struct BakersTableSheet: View {
    let name: String
    let input: DoughInput
    let stats: DoughStats
    let pieces: Double?
    let precision: Precision
    let basis: PctBasis

    @Environment(\.dismiss) private var dismiss
    /// 처음부터 크게 — 중간 높이에선 합계가 접힌 아래에 있다
    @State private var detent: PresentationDetent = .large
    /// 배합표를 보며 계량하는 동안 화면이 꺼지지 않게 (설정 키 "keepScreenAwake", 기본 켬)
    @AppStorage("keepScreenAwake") private var keepAwake = true

    var body: some View {
        NavigationStack {
            List {
                FicheSections(
                    input: input, stats: stats, pieces: pieces, precision: precision, basis: basis)
            }
            .readableSheetWidth()
            .navigationTitle(name.isEmpty ? L("배합표") : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("닫기")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GlossaryView()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel(L("용어 설명"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: ficheText(
                            name: name, input: input, stats: stats, pieces: pieces, basis: basis,
                            precision: precision)
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(L("공유"))
                }
            }
        }
        .adaptiveDetents([.medium, .large], selection: $detent)
        // iPad: 한 장짜리 배합표답게 재료와 합계(총 수분율·총 반죽 무게)가 한 화면에 — 작은 폼 시트에선 합계가 잘린다
        .pageSizedSheet()
        .modifier(KeepScreenAwake(enabled: keepAwake))
    }
}

/// 넓은 가로 창(iPad 가로)의 계산기 오른쪽 열 — 배합표 시트와 같은 내용을 늘 보인다.
/// 결과 바(시트로 가는 길)를 감추므로 시트의 용어 설명·공유도 여기 둔다. 화면 꺼짐 방지는 걸지 않는다 —
/// 시트와 달리 닫히는 때가 없어 계산기를 보는 내내 자동 잠금이 꺼진다
struct FicheColumn: View {
    let name: String
    let input: DoughInput
    let stats: DoughStats
    let pieces: Double?
    let precision: Precision
    let basis: PctBasis
    /// 용어 설명 열기 — 이 열은 화면을 돌리면 사라지므로 내비게이션 대상은 계산기 화면이 단다
    let onGlossary: () -> Void

    var body: some View {
        List {
            HStack(spacing: 16) {
                Text(L("배합표"))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button(action: onGlossary) {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel(L("용어 설명"))
                ShareLink(
                    item: ficheText(
                        name: name, input: input, stats: stats, pieces: pieces, basis: basis,
                        precision: precision)
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L("공유"))
            }
            // 행 안의 버튼 둘을 따로 누르게 — 기본 스타일은 행 전체가 한 버튼이 된다
            .buttonStyle(.borderless)
            .listRowBackground(Color.clear)
            FicheSections(
                input: input, stats: stats, pieces: pieces, precision: precision, basis: basis)
        }
    }
}

/// 켜 있는 동안 자동 잠금을 막는다 — 닫히거나 앱이 뒤로 가면 풀린다 (isIdleTimerDisabled는 앱 전체 설정)
private struct KeepScreenAwake: ViewModifier {
    let enabled: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { apply(enabled) }
            .onDisappear { apply(false) }
            .onChange(of: scenePhase) { _, phase in apply(enabled && phase == .active) }
            .onChange(of: enabled) { _, on in apply(on && scenePhase == .active) }
    }

    private func apply(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on
    }
}

/// 용어 설명 — 배합표의 지표가 무엇을 뜻하는지. 결과값이 아니므로 brass를 쓰지 않는다
struct GlossaryView: View {
    var body: some View {
        List {
            entry(
                L("총 수분율"), fr: "hydratation totale",
                L("총 물 ÷ 총 밀가루. 총 물 = 본반죽 물 + 바시나주 + 르방 속 물 + 액체 재료의 수분."))
            entry(
                "PFF", fr: "prefermented flour",
                L("르방 속 밀가루 ÷ 총 밀가루 — 미리 발효된 밀가루의 비율."))
            entry(
                L("르방 리퀴드"), fr: "levain liquide",
                L("수분율 100% 안팎의 르방 (밀가루 1 : 물 1). 75% 이상이면 리퀴드로 봅니다."))
            entry(
                L("르방 뒤흐"), fr: "levain dur",
                L("수분율 50% 안팎의 단단한 르방 (밀가루 1 : 물 0.5). 75% 미만이면 뒤흐로 봅니다."))
            entry(
                L("바시나주"), fr: "bassinage",
                L("본반죽을 섞은 뒤 나눠 넣는 물. 총 물과 총 수분율에 들어갑니다."))
        }
        .navigationTitle(L("용어 설명"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entry(_ title: String, fr: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BilingualLabel(title, fr: fr)
                .fontWeight(.semibold)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
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
                    .accessibilityLabel(L("레시피 이름"))
                TextField(L("태그 (쉼표로 구분)"), text: $tagsText)
                    .accessibilityLabel(L("태그 (쉼표로 구분)"))
                TextField(L("노트"), text: $note, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityLabel(L("노트"))
                if allowOverwrite {
                    Toggle(
                        loadedName.map { LF("'%@'에 덮어쓰기", $0) } ?? L("불러온 레시피에 덮어쓰기"),
                        isOn: $overwrite)
                }
            }
            .navigationTitle(L("레시피 저장"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("취소")) {
                        if isEdited { showDiscard = true } else { dismiss() }
                    }
                    .discardConfirmation(isPresented: $showDiscard) { dismiss() }
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
                    .accessibilityIdentifier("saveRecipe.confirm")
                }
            }
            // 이름을 바꾸면 새 레시피로 저장하려는 것으로 보고 덮어쓰기를 해제한다 (다시 켤 수는 있음)
            .onChange(of: name) { _, newName in
                if allowOverwrite,
                    newName.trimmingCharacters(in: .whitespacesAndNewlines) != baseName
                {
                    overwrite = false
                }
            }
        }
        .adaptiveDetents([.medium, .large])
        .interactiveDismissDisabled(isEdited)
    }
}
