import DoughmetryCore
import SwiftUI

/// 설정 — 도구 탭에서 다른 도구처럼 밀어 넣는 페이지 (언어 · % 표기 · 표시 자릿수 · iCloud · 정보)
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    /// BakersTableSheet가 읽는 키 — 없으면 켬
    @AppStorage("keepScreenAwake") private var keepAwake = true

    private var cloudStatusText: String {
        switch model.cloud.status {
        case .checking: return L("확인 중…")
        case .unavailable: return L("사용 불가 — iCloud 로그인 또는 앱 권한 필요")
        case .disabled: return L("꺼짐")
        case .syncing: return L("동기화 중…")
        case .error(let message): return message
        case .idle:
            if let at = model.cloud.lastSyncAt {
                return LF("마지막 동기화 %@", fmtTime(at))
            }
            return L("대기 중")
        }
    }

    var body: some View {
        @Bindable var model = model
        let cloud = model.cloud
        Form {
            if model.libraryWriteFailed {
                Section {
                    LibraryWriteErrorLabel()
                }
            }
            Section {
                // 사용할 수 없으면 꺼짐으로 보인다 — 저장된 선택은 그대로 두어 iCloud가 돌아오면 이어진다
                Toggle(
                    L("iCloud 동기화"),
                    isOn: Binding(
                        get: { cloud.enabled && cloud.isAvailable },
                        set: { cloud.enabled = $0 })
                )
                .disabled(!cloud.isAvailable)
                StackingLabeledContent(L("상태")) {
                    Text(cloudStatusText)
                        .foregroundStyle(.secondary)
                }
                if cloud.keptConflictCount > 0 {
                    Label(
                        LF("아직 합치지 못한 충돌 사본 %d개를 iCloud에 그대로 보관 중입니다 — 이번에 읽지 못했거나 일부 항목이 손상된 사본이라 지우지 않습니다.", count: cloud.keptConflictCount),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("iCloud")
            } footer: {
                Text(L("레시피·베이킹 로그를 iCloud로 기기 간 동기화합니다. 충돌 시 최신 수정본이 유지됩니다."))
            }
            .textCase(nil)
            Section {
                AXStackedPicker(
                    label: L("언어"), value: Lang.shared.current.label, selection: Bindable(Lang.shared).current
                ) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
            } footer: {
                Text(L("검색 같은 시스템 화면은 앱을 다시 열면 바뀝니다. 공유 시트의 일부 항목은 기기 언어를 따릅니다."))
            }
            Section {
                AXStackedPicker(
                    label: L("% 표기"),
                    value: model.pctBasis == .totalFlour ? L("총 밀가루 기준") : L("베이커스 퍼센트"),
                    selection: $model.pctBasis
                ) {
                    Text(L("총 밀가루 기준")).tag(PctBasis.totalFlour)
                    Text(L("베이커스 퍼센트")).tag(PctBasis.addedFlour)
                }
                NavigationLink(L("용어 설명")) { GlossaryView() }
            } footer: {
                Text(L("표시만 바뀝니다 — 계산과 총 수분율·PFF는 항상 총 밀가루 기준입니다."))
            }
            Section {
                AXStackedPicker(label: L("표시 자릿수"), value: model.precision.label, selection: $model.precision) {
                    ForEach(Precision.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                Toggle(L("배합표를 보는 동안 화면 켜두기"), isOn: $keepAwake)
            } footer: {
                Text(L("내부 계산은 항상 full precision — 반올림은 표시에만 적용됩니다."))
            }
            Section {
                StackingLabeledContent(L("버전")) {
                    Text(verbatim: "\(AppInfo.version) (\(AppInfo.build))")
                        .foregroundStyle(.secondary)
                }
                Link(L("개인정보 처리방침"), destination: AppLinks.privacy)
                Link(L("지원·문의"), destination: AppLinks.support)
                Link(L("웹 버전"), destination: AppLinks.web)
                if let review = AppLinks.writeReview {
                    Link(L("앱 평가하기"), destination: review)
                }
                if let store = AppLinks.appStore {
                    ShareLink(item: store) {
                        Text(L("앱 공유하기"))
                    }
                }
            } header: {
                Text(L("정보"))
            } footer: {
                Text(L("광고·계정·추적 없음"))
            }
            .textCase(nil)
        }
        .readableFormWidth()
        .navigationTitle(L("설정"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 메뉴 Picker 행. iOS 17·18의 메뉴 Picker는 접근성 글자 크기에서도 이름과 값을 한 줄에 나눠 둬 단어 중간에서 끊고,
/// 값이 두 줄로 접혀도 한 줄 높이만 잡아 이름과 겹친다 — 그때만 이름 아래에 값을 그린 메뉴로 (AXMenuPicker).
/// 26부터는 시스템이 스스로 위아래로 쌓는다
private struct AXStackedPicker<Selection: Hashable, Options: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let label: String
    let value: String
    @Binding var selection: Selection
    @ViewBuilder let options: Options

    private var stacks: Bool {
        if #available(iOS 26, *) { return false }
        return typeSize.isAccessibilitySize
    }

    var body: some View {
        if stacks {
            AXMenuPicker(label, value: value) {
                Picker(label, selection: $selection) { options }
            }
        } else {
            Picker(label, selection: $selection) { options }
        }
    }
}
