import CoreTransferable
import DoughmetryCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 레시피 목록의 화면 정렬 — 저장 순서(model.recipes)는 iCloud 수렴용 정규 순서라 바꾸지 않는다
enum RecipeSort: String, CaseIterable {
    case updated
    case lastBaked
    case name
}

struct RecipesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.windowIsRegular) private var windowIsRegular
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var search = ""
    @State private var searchPresented = false
    /// ⌘F의 검색 칸 포커스 (iOS 18+ searchFocused) — 17은 isPresented를 닫았다 다시 연다
    @FocusState private var searchFocused: Bool
    /// 화면에 있는 목록 수 — 다른 탭이나 열어 둔 상세에서 온 ⌘F는 목록이 뜬 뒤에 포커스를 준다.
    /// 창 폭 등급이 바뀔 때 새 목록이 뜨는 것과 옛 목록이 지는 것의 순서가 정해져 있지 않아 참/거짓 대신 센다
    @State private var listsOnScreen = 0
    @State private var searchFocusPending = false
    /// 마지막으로 받은 ⌘F 요청 — 탭을 처음 그릴 때 이미 올라간 요청은 받고, 목록을 다시 그릴 때는 되풀이하지 않는다
    @State private var handledSearchRequest = 0
    /// 두 열(regular 폭)에서 상세에 보이는 레시피
    @State private var selectedID: String?
    @State private var splitVisibility: NavigationSplitViewVisibility = .all
    /// 상세 열에서 민 화면(전체 기록) — 다른 레시피를 고르면 비운다. 안 비우면 앞 레시피의 기록 화면이 남아
    /// 기록 추가가 그 레시피로 간다
    @State private var detailPath = NavigationPath()
    /// 한 열(compact 폭)의 내비게이션 경로 — 창 폭 등급이 바뀌어도 열어 둔 레시피를 잇는다
    @State private var compactPath = NavigationPath()
    /// 레시피 상세·전체 기록의 시트 — 상세는 창 폭 등급이 바뀔 때 다시 만들어지므로 여기서 띄운다 (적던 내용이 남게)
    @State private var detailSheet: RecipeDetailSheet?
    @AppStorage("recipeSort") private var sort: RecipeSort = .updated
    @State private var showImporter = false
    @State private var importError: String?
    @State private var importResult: (added: Int, skipped: Int)?
    @State private var showImportDialog = false
    /// 빈 화면의 가져오기 버튼에서 연 선택지 — 툴바 버튼과 따로 두어 팝오버가 누른 버튼에서 나오게 한다
    @State private var showEmptyImportDialog = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showTextSheet = false
    /// 텍스트 시트를 열 때 미리 채울 내용 (인식 실패 후 "텍스트 편집")
    @State private var textSeed = ""
    /// 인식에 실패한 원본 텍스트 — 실패 알림에서 고쳐 다시 분석할 수 있게 보관
    @State private var failedText: String?
    @State private var importingAI = false
    /// 진행 중인 단계 — 기다리는 동안 무엇을 하는지 보인다 (규칙 분석만 하는 텍스트는 단계 없이 끝난다)
    @State private var importStage: ImportStage?
    @State private var importTask: Task<Void, Never>?
    /// 이번 가져오기의 모델 세션 — 사진·텍스트를 고르는 순간 미리 데우고, 끝나면 버린다
    @State private var importSession: ImportSession?
    @State private var review: ImportedRecipe?
    /// 텍스트 시트가 내려가는 동안 나온 결과 — 내려가는 중에 띄운 확인 시트는 iPadOS 18에서 페이지 크기를 무시한다
    @State private var pendingReview: ImportedRecipe?
    @State private var textSheetOnScreen = false
    @State private var importSaved = false
    /// 밀어서 삭제를 누른 레시피 id — 확인 뒤에만 지운다
    @State private var pendingDelete: String?

    private var filtered: [Recipe] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let matched =
            q.isEmpty
            ? model.recipes
            : model.recipes.filter { r in
                r.name.localizedCaseInsensitiveContains(q)
                    || (r.note ?? "").localizedCaseInsensitiveContains(q)
                    || (r.tags ?? []).contains { $0.localizedCaseInsensitiveContains(q) }
            }
        return sorted(matched)
    }

    /// 같은 값끼리는 저장 순서를 유지한다. 시각은 ISO 문자열 그대로 비교한다(웹 RecipesPage와 같은 규칙) —
    /// 초 단위(iOS)와 밀리초(웹) 표기가 섞여도 같은 초 안에서만 순서가 어긋난다
    private func sorted(_ recipes: [Recipe]) -> [Recipe] {
        recipes.enumerated().sorted { x, y in
            let a = x.element
            let b = y.element
            switch sort {
            case .updated:
                if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
            case .lastBaked:
                let ba = model.bakeSummary(for: a.id)?.latestBakedAt
                let bb = model.bakeSummary(for: b.id)?.latestBakedAt
                if ba != bb {
                    // 구운 적 없는 레시피는 뒤로
                    guard let ba else { return false }
                    guard let bb else { return true }
                    return ba > bb
                }
                if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
            case .name:
                let order = a.name.localizedStandardCompare(b.name)
                if order != .orderedSame { return order == .orderedAscending }
            }
            return x.offset < y.offset
        }
        .map(\.element)
    }

    var body: some View {
        presentations(columns)
            .onChange(of: selectedID) { detailPath = NavigationPath() }
            // 넓은 창에서 열어 둔 레시피를 좁은 창에서도 연 채로 둔다
            .onChange(of: windowIsRegular) { _, regular in
                // 창을 줄이는 동안 두 열이 목록을 접어(.detailOnly) 둔다 — 다시 넓어지면 편다
                guard !regular else { splitVisibility = .all; return }
                if let id = selectedID, model.recipes.contains(where: { $0.id == id }) {
                    compactPath = NavigationPath([id])
                } else {
                    compactPath = NavigationPath()
                }
            }
            .recipeDetailSheets($detailSheet)
    }

    /// 창 폭 등급이 바뀌면(iPad 창 크기 조절·Split View) 두 갈래가 통째로 바뀐다 — 시트·알림·선택처럼 입력을 담은 것은
    /// 갈래 밖(body)에 단다. Group은 수식어를 갈래마다 따로 달아 갈래와 함께 사라지므로 ZStack으로 감싼다
    private var columns: some View {
        ZStack {
            if windowIsRegular {
                // 넓은 창: 목록 | 상세 두 열. 세로 화면에서도 목록을 상세 위에 덮지 않고 옆에 둔다
                NavigationSplitView(columnVisibility: $splitVisibility) {
                    decorated(splitContent)
                } detail: {
                    NavigationStack(path: $detailPath) {
                        splitDetail
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .modifier(SplitFillsTop())
                .overlay {
                    if importingAI {
                        importProgress
                    }
                }
            } else {
                NavigationStack(path: $compactPath) {
                    decorated(content)
                    .overlay {
                        if importingAI {
                            importProgress
                        }
                    }
                    .navigationDestination(for: String.self) { id in
                        Group {
                            if let recipe = model.recipes.first(where: { $0.id == id }) {
                                RecipeDetailView(recipe: recipe, sheet: $detailSheet)
                            } else {
                                deletedRecipe
                            }
                        }
                        .onAppear { selectedID = id }
                    }
                }
                .onChange(of: compactPath) { _, path in
                    if path.isEmpty { selectedID = nil }
                }
            }
        }
    }

    /// 목록 열에 붙는 제목·툴바 — 내비게이션 열 안에 있어야 하므로 갈래마다 단다
    private func decorated<Content: View>(_ base: Content) -> some View {
        base
            .safeAreaInset(edge: .bottom) {
                if model.libraryWriteFailed {
                    LibraryWriteErrorLabel()
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle(L("레시피"))
            .toolbar { toolbarContent }
    }

    /// 가져오기 흐름·설정의 시트와 알림 — 창 폭 등급이 바뀌어도 닫히지 않게 두 갈래 밖에 단다
    private func presentations<Content: View>(_ base: Content) -> some View {
        base
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .plainText]
            ) { result in
                handleImport(result)
            }
            .alert(
                L("가져오기 실패"), isPresented: .init(
                    get: { importError != nil },
                    set: {
                        if !$0 {
                            importError = nil
                            failedText = nil
                        }
                    })
            ) {
                if let text = failedText, !text.isEmpty {
                    Button(L("텍스트 편집")) {
                        textSeed = text
                        importSession = .prewarmed()
                        showTextSheet = true
                    }
                }
                Button(L("확인"), role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .alert(
                L("가져오기 완료"), isPresented: .init(
                    get: { importResult != nil }, set: { if !$0 { importResult = nil } })
            ) {
                Button(L("확인"), role: .cancel) {}
            } message: {
                let added = importResult?.added ?? 0
                let skipped = importResult?.skipped ?? 0
                Text(
                    skipped > 0
                        ? LF("%d개를 가져왔고, %d개는 이미 있는 버전이라 건너뛰었습니다.", added, skipped)
                        : LF("%d개의 레시피를 가져왔습니다.", count: added))
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            // 고르지 않고 닫으면 미리 데운 모델 세션을 버린다
            .onChange(of: showPhotoPicker) { _, shown in
                if !shown, photoItem == nil, !importingAI { importSession = nil }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                runImport { session, onStage in
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw ImportError.unreadableImage
                    }
                    return try await RecipeImporter.importRecipe(from: data, session: session, onStage: onStage)
                }
            }
            .onChange(of: showTextSheet) { _, shown in
                if shown { textSheetOnScreen = true }
            }
            .sheet(
                isPresented: $showTextSheet,
                onDismiss: {
                    textSheetOnScreen = false
                    if let pending = pendingReview {
                        pendingReview = nil
                        review = pending
                    }
                    if !importingAI { importSession = nil }
                }
            ) {
                TextImportSheet(initialText: textSeed) { text in
                    runImport { session, onStage in
                        try await RecipeImporter.importRecipe(from: text, session: session, onStage: onStage)
                    }
                }
            }
            .sheet(item: $review) { imported in
                ImportReviewSheet(imported: imported) { name, input, note, pieces in
                    let now = isoNow()
                    let recipe = Recipe(
                        name: name, note: note, createdAt: now, updatedAt: now, input: input, pieces: pieces)
                    model.save(recipe)
                    if windowIsRegular { selectedID = recipe.id }
                    importSaved.toggle()
                }
            }
            .sensoryFeedback(.success, trigger: importSaved)
            .onChange(of: model.searchRequest, initial: true) { _, request in
                guard request != handledSearchRequest else { return }
                handledSearchRequest = request
                // 빈 라이브러리엔 검색 칸이 없다 — 켜 두면 첫 레시피가 생길 때 검색이 저절로 열린다
                guard !model.recipes.isEmpty else { return }
                splitVisibility = .all
                // 한 열에서 상세를 열어 둔 채면 목록으로 돌아간다 — 가려진 목록에서 검색만 켜 두면 뒤로 갈 때 키보드가 올라온다
                if !windowIsRegular, !compactPath.isEmpty { compactPath = NavigationPath() }
                if #available(iOS 18, *) {
                    // 검색을 닫았다 다시 여는 길은 탭 전환과 엇갈려 포커스를 놓친다 — 포커스만 준다
                    if listsOnScreen > 0 { searchFocused = true } else { searchFocusPending = true }
                    return
                }
                guard searchPresented else {
                    searchPresented = true
                    return
                }
                // 이미 열린 검색(키보드만 내려간 상태)은 true를 다시 넣어도 포커스가 돌아오지 않는다. 닫은 것이 검색 칸에
                // 반영되기 전에 다시 열면 둘이 합쳐져 아무 일도 없으므로 한 박자 쉬고 연다 — 닫으면 지워지는 검색어도 되살린다
                // 검색어는 먼저 비워 둔다 — 닫힐 때 칸만 비고 search는 남아, 빈 칸 아래 옛 검색어로 거른 목록이 보인다
                let query = search
                search = ""
                searchPresented = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    searchPresented = true
                    try? await Task.sleep(for: .milliseconds(100))
                    if search.isEmpty { search = query }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if model.recipes.isEmpty {
            emptyState
        } else {
            let rows = filtered
            searchFocusTracking(
                List {
                    ForEach(rows) { recipe in
                        row(recipe)
                    }
                }
                .overlay { noResults(rows) }
                .readableFormWidth()
                .searchable(
                    text: $search, isPresented: $searchPresented,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: L("이름·메모·태그 검색"))
            )
        }
    }

    /// 검색 칸 포커스를 잇고, 목록이 화면에 들어온 뒤에 기다리던 ⌘F 포커스를 준다. 화면을 떠날 때 포커스를 내려 두어야
    /// 다음 ⌘F의 true가 바뀐 값으로 들어간다
    private func searchFocusTracking<Content: View>(_ list: Content) -> some View {
        list
            .modifier(SearchFocusBinding(focused: $searchFocused))
            .onAppear {
                listsOnScreen += 1
                guard searchFocusPending else { return }
                searchFocusPending = false
                searchFocused = true
            }
            .onDisappear {
                listsOnScreen = max(0, listsOnScreen - 1)
                searchFocused = false
            }
    }

    /// 두 열의 목록 — 검색은 목록 열 안에 둔다. 화면 전체 폭 검색(.toolbar 배치 포함)은 검색 중에 탭 막대를 가린다.
    /// List(selection:)은 고른 행 글자를 흰색으로 뒤집어 brass 수분율·bottle 르방 종류를 가리므로 직접 고른다
    @ViewBuilder
    private var splitContent: some View {
        if model.recipes.isEmpty {
            // 들여오는 길(emptyState)은 넓은 상세 열에 — 좁은 목록 열에선 설명이 여러 줄로 접힌다
            ContentUnavailableView(L("저장된 레시피가 없습니다"), systemImage: "book.closed")
        } else {
            let rows = filtered
            searchFocusTracking(
                List {
                    ForEach(rows) { recipe in
                        sidebarRow(recipe)
                    }
                }
                .overlay { noResults(rows) }
                .searchable(
                    text: $search, isPresented: $searchPresented, placement: sidebarSearchPlacement,
                    prompt: L("이름·메모·태그 검색"))
            )
            .modifier(SearchKeepsTitleBar())
        }
    }

    /// iOS 17·18의 자동 배치는 목록이 스크롤되지 않으면 검색 칸을 숨겨 둔다 (끌어내려야 보인다)
    private var sidebarSearchPlacement: SearchFieldPlacement {
        if #available(iOS 26, *) { return .automatic }
        return .navigationBarDrawer(displayMode: .always)
    }

    @ViewBuilder
    private var splitDetail: some View {
        if let id = selectedID {
            if let recipe = model.recipes.first(where: { $0.id == id }) {
                RecipeDetailView(recipe: recipe, sheet: $detailSheet)
                    .id(id)
            } else {
                deletedRecipe
            }
        } else if !model.recipes.isEmpty {
            ContentUnavailableView(
                L("레시피를 고르세요"), systemImage: "book.closed",
                description: Text(L("왼쪽 목록에서 레시피를 고르면 배합표와 베이킹 로그가 여기에 보입니다.")))
        } else {
            emptyState
        }
    }

    /// 다른 기기에서 삭제된 레시피가 동기화로 사라진 경우
    private var deletedRecipe: some View {
        ContentUnavailableView(
            L("삭제된 레시피"), systemImage: "trash",
            description: Text(L("이 레시피는 다른 기기에서 삭제되었습니다.")))
    }

    /// 검색어에 맞는 레시피가 없을 때 — 빈 목록만 남기지 않는다. 시스템 .search는 앱 언어가 아니라 번들 현지화를 따른다
    @ViewBuilder
    private func noResults(_ rows: [Recipe]) -> some View {
        let q = search.trimmingCharacters(in: .whitespaces)
        if rows.isEmpty, !q.isEmpty {
            ContentUnavailableView(
                LF("'%@'에 대한 결과 없음", q), systemImage: "magnifyingglass",
                description: Text(L("철자를 확인하거나 다른 검색어로 찾아보세요.")))
        }
    }

    private func row(_ recipe: Recipe) -> some View {
        deletable(
            NavigationLink(value: recipe.id) {
                RecipeRow(recipe: recipe, precision: model.precision)
            }
            .accessibilityIdentifier("recipes.row"),
            recipe)
    }

    private func sidebarRow(_ recipe: Recipe) -> some View {
        let selected = selectedID == recipe.id
        return deletable(
            Button {
                selectedID = recipe.id
            } label: {
                RecipeRow(recipe: recipe, precision: model.precision)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(
                selected ? RoundedRectangle(cornerRadius: 12).fill(Color.bottle.opacity(0.12)) : nil)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("recipes.row"),
            recipe)
    }

    /// 밀어서 삭제 + 확인 — 한 열과 두 열의 목록 행이 같이 쓴다
    private func deletable<Row: View>(_ base: Row, _ recipe: Recipe) -> some View {
        base
        // 끝까지 밀어도 바로 지우지 않는다 — 소속 베이킹 로그까지 모든 기기에서 사라진다.
        // role: .destructive는 확인 전에 행을 치우므로 쓰지 않는다
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                pendingDelete = recipe.id
            } label: {
                Label(L("삭제"), systemImage: "trash")
            }
            .tint(Color.danger)
        }
        // 확인은 그 행에 붙인다 — 목록에 붙이면 iPad·iOS 26 팝오버가 다른 행을 가리킨다
        .confirmationDialog(
            LF("'%@' 레시피를 삭제할까요?", recipe.name),
            isPresented: .init(
                get: { pendingDelete == recipe.id },
                set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L("삭제"), role: .destructive) {
                pendingDelete = nil
                if selectedID == recipe.id { selectedID = nil }
                model.delete(recipe.id)
            }
            Button(L("취소"), role: .cancel) {}
        } message: {
            // 대화상자 내용은 행마다 그릴 때 만들어진다 — 로그 전체를 훑지 않고 캐시된 요약을 쓴다
            let logCount = model.bakeSummary(for: recipe.id)?.count ?? 0
            Text(
                logCount > 0
                    ? LF("베이킹 기록 %d개도 함께 삭제되며 되돌릴 수 없습니다.", logCount)
                    : L("되돌릴 수 없습니다."))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: actionPlacement) {
            Button {
                showImportDialog = true
            } label: {
                if importIconOnly {
                    Image(systemName: "sparkles")
                } else {
                    // iOS 26+ 툴바는 Label의 labelStyle(.titleAndIcon)을 무시하고 아이콘만 그린다
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text(L("가져오기"))
                    }
                }
            }
            .accessibilityLabel(L("사진·텍스트에서 가져오기"))
            .disabled(importingAI)
            .accessibilityIdentifier("recipes.import")
            .confirmationDialog(
                L("사진·텍스트에서 가져오기"), isPresented: $showImportDialog, titleVisibility: .visible
            ) {
                importChoices
            }
        }
        ToolbarItem(placement: actionPlacement) {
            Menu {
                // 정렬은 막대에 따로 두지 않는다 — iPad 세로·영어나 접근성 크기에서 가져오기 버튼까지 시스템 '더 보기'로 밀어낸다.
                // 하위 메뉴로 둔다: 메뉴 안 Section 제목은 Picker와 함께면 보이지 않아 '이름' 같은 항목만 덩그러니 남는다
                if model.recipes.count > 1 {
                    Picker(selection: $sort) {
                        Text(L("최근 수정")).tag(RecipeSort.updated)
                        Text(L("최근 구움")).tag(RecipeSort.lastBaked)
                        Text(L("이름")).tag(RecipeSort.name)
                    } label: {
                        Label(L("정렬"), systemImage: "arrow.up.arrow.down")
                    }
                    .pickerStyle(.menu)
                }
                Section {
                    if !model.recipes.isEmpty {
                        ShareLink(
                            item: RecipesExport(recipes: model.recipes),
                            preview: SharePreview(RecipesExport.libraryFileName)
                        ) {
                            Label(L("JSON 내보내기"), systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label(L("JSON 가져오기"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(importingAI)
                }
            } label: {
                Label(L("더 보기"), systemImage: "ellipsis.circle")
            }
        }
    }

    /// iPadOS 18의 떠 있는 탭 막대는 세로 화면에서 목록 열 막대를 덮는다 — 그 밑의 버튼을 누르면 탭이 바뀐다.
    /// 탭 막대는 글자 크기·창 폭에 따라 넓어져 위 막대의 어느 자리든 덮일 수 있으니 목록 열 아래 막대로 내린다.
    /// 17은 탭 막대가 아래에 있고, 26부터는 탭 막대가 목록 열 막대를 비켜 간다
    private var actionPlacement: ToolbarItemPlacement {
        if #available(iOS 26, *) { return .topBarTrailing }
        if #available(iOS 18, *), windowIsRegular { return .bottomBar }
        return .topBarTrailing
    }

    /// 가져오기 버튼에 글자를 빼는 곳 — 두 열의 좁은 목록 열, 그리고 막대 글자가 글자 크기를 따라 커지는 iOS 17·18의
    /// 접근성 크기. 글자까지 넣으면 막대가 넘쳐 시스템 '더 보기'로 숨는다
    private var importIconOnly: Bool {
        if windowIsRegular { return true }
        if #available(iOS 26, *) { return false }
        return typeSize.isAccessibilitySize
    }

    /// 레시피가 하나도 없을 때 — 레시피를 들여오는 길을 바로 보인다
    private var emptyState: some View {
        // 접근성 글자 크기에선 버튼까지 화면을 넘는다 — 스크롤되게 두고, 들어가면 가운데에 둔다
        GeometryReader { proxy in
            ScrollView {
                ContentUnavailableView {
                    Label(L("저장된 레시피가 없습니다"), systemImage: "book.closed")
                } description: {
                    Text(L("사진·텍스트에서 레시피를 가져오거나 계산기에서 만든 배합을 저장하세요. 저장한 레시피에는 굽기마다 날짜·별점·메모를 남길 수 있습니다."))
                } actions: {
                    Button {
                        showEmptyImportDialog = true
                    } label: {
                        Label(L("사진·텍스트에서 가져오기"), systemImage: "sparkles")
                            .foregroundStyle(Color.paper)
                            .multilineTextAlignment(.center)
                            .frame(width: emptyActionWidth(proxy))
                    }
                    .buttonStyle(.borderedProminent)
                    // 빈 화면의 actions는 바깥 controlSize를 따르지 않는다 — 버튼마다 준다 (44pt 탭 영역)
                    .controlSize(.large)
                    .disabled(importingAI)
                    .confirmationDialog(
                        L("사진·텍스트에서 가져오기"), isPresented: $showEmptyImportDialog,
                        titleVisibility: .visible
                    ) {
                        importChoices
                    }
                    Button {
                        addSamples()
                    } label: {
                        Label(L("예시 레시피 추가"), systemImage: "text.badge.plus")
                            .multilineTextAlignment(.center)
                            .frame(width: emptyActionWidth(proxy))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    Button {
                        model.selectedTab = .calculator
                    } label: {
                        // 테두리 없는 버튼은 글자 높이만 눌린다 — 44pt 탭 영역
                        Text(L("계산기로 가기"))
                            .multilineTextAlignment(.center)
                            .frame(width: emptyActionWidth(proxy))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// iOS 17의 빈 화면은 접근성 글자 크기에서 버튼 글자를 줄바꿈하지 않고 한 줄로 늘여 제목·설명까지 화면 밖으로 민다 —
    /// 버튼 폭을 정해 준다. 18부터는 스스로 줄바꿈한다 (폭 그대로 두면 가운데만 옮겨질 뿐 넘친다)
    private func emptyActionWidth(_ proxy: GeometryProxy) -> CGFloat? {
        if #available(iOS 18, *) { return nil }
        return typeSize.isAccessibilitySize ? max(0, proxy.size.width - 120) : nil
    }

    /// 사진·텍스트 가져오기 선택지 — 어느 쪽이든 결과는 확인 시트를 거쳐 저장된다.
    /// 고르는 순간 모델을 데운다 — 사진을 고르거나 붙여넣는 동안 모델 로드가 끝난다
    @ViewBuilder
    private var importChoices: some View {
        Button(L("사진에서 가져오기")) {
            importSession = .prewarmed()
            showPhotoPicker = true
        }
        Button(L("텍스트 붙여넣기")) {
            importSession = .prewarmed()
            textSeed = ""
            showTextSheet = true
        }
        Button(L("취소"), role: .cancel) {}
    }

    /// 예시 배합을 라이브러리에 넣는다 — 고정 시각(epoch)으로 touch 없이. 지금 시각이면 같은 id의 예시를 다른 기기에서
    /// 고치거나 지운 것을 iCloud 병합이 되돌린다. 지웠던 예시는 save가 묘비 뒤로 밀어 되살린다
    private func addSamples() {
        let samples = SampleRecipes.make(now: SampleRecipes.epoch, localize: L)
        // save는 맨 앞에 넣으므로 역순으로 — 정의한 순서대로 보인다
        for recipe in samples.reversed() where !model.recipes.contains(where: { $0.id == recipe.id }) {
            model.save(recipe, touch: false)
        }
        if windowIsRegular, let first = samples.first { selectedID = first.id }
        importSaved.toggle()
    }

    /// 인식 중 표시 — 단계 문구와 취소. 모델 분석 중엔 이미 끝난 규칙 분석 결과로 바로 넘어갈 수 있다
    private var importProgress: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(
                    importStage == .analyzing
                        ? L("Apple Intelligence로 분석 중…")
                        : importStage == .reading ? L("텍스트 인식 중…") : L("인식 중…"))
                if importStage == .analyzing {
                    Button {
                        importSession?.skipAnalysis()
                    } label: {
                        Text(L("규칙 결과로 보기"))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    importTask?.cancel()
                } label: {
                    Text(L("취소"))
                        .frame(minWidth: 88, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// AI 인식 파이프라인 실행 — 결과는 확인 시트로, 실패는 알림으로. 취소하면 아무것도 보이지 않는다
    private func runImport(
        _ work: @escaping (ImportSession?, @escaping @MainActor @Sendable (ImportStage) -> Void) async throws
            -> ImportedRecipe
    ) {
        // 인식 중이거나 확인 시트가 열려 있으면 새 결과가 그것을 덮어쓴다
        guard !importingAI, review == nil, pendingReview == nil else { return }
        importingAI = true
        let session = importSession
        importTask = Task { @MainActor in
            defer {
                importingAI = false
                importStage = nil
                importTask = nil
                importSession = nil
            }
            do {
                let result = try await work(session) { importStage = $0 }
                guard !Task.isCancelled else { return }
                if textSheetOnScreen { pendingReview = result } else { review = result }
            } catch let error as ImportError {
                guard !Task.isCancelled else { return }
                switch error {
                case .unreadableImage:
                    importError = L("이미지를 읽을 수 없습니다")
                case .noText:
                    importError = L("이미지에서 텍스트를 찾지 못했습니다")
                case .noIngredients(let text):
                    failedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    importError = L("재료를 인식하지 못했습니다. 재료와 g 수량이 줄 단위로 적힌 텍스트가 필요합니다.")
                }
            } catch {
                guard !Task.isCancelled else { return }
                importError = L("가져오는 중 오류가 발생했습니다. 다시 시도해 주세요.")
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            importError = L("파일을 읽을 수 없습니다")
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                importError = L("파일을 읽을 수 없습니다")
                return
            }
            switch RecipeCodec.importJSON(text) {
            case .failure(let reason):
                importError = reason.localizedMessage
            case .success(let imported):
                let plan = LibrarySync.importable(imported, local: model.recipes)
                // 새 레시피는 앞에 추가 — 역순으로 넣어 파일 순서를 유지한다
                for recipe in plan.accepted.reversed() {
                    model.save(recipe, touch: false)  // 백업의 updatedAt 보존
                }
                importResult = (plan.accepted.count, plan.skipped)
            }
        }
    }
}

/// 검색 칸 포커스 바인딩 — searchFocused는 iOS 18+
private struct SearchFocusBinding: ViewModifier {
    let focused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.searchFocused(focused)
        } else {
            content
        }
    }
}

/// iPadOS 18의 목록 열에서 검색을 시작하면 검색 칸이 막대 자리로 올라가 취소 버튼이 떠 있는 탭 막대 밑에 깔린다 —
/// 막대를 그대로 두고 그 아래에서 검색한다. 17(아래 탭 막대)·26+(막대를 비켜 감)은 그대로
private struct SearchKeepsTitleBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else if #available(iOS 18, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
    }
}

/// iOS 27에서 두 열은 처음 그릴 때만 위 탭 막대 아래에서 시작하고(그 위는 흰 띠), 회전·탭 왕복 뒤엔 화면 위까지 올라간다 —
/// 늘 위까지 둔다. 탭 막대는 열마다 내비게이션 막대가 안전 영역을 따라 비킨다. 26의 떠 있는 목록 열은 처음부터 같은 자리다
private struct SplitFillsTop: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.ignoresSafeArea(.container, edges: .top)
        } else {
            content
        }
    }
}

struct RecipeRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let recipe: Recipe
    let precision: Precision

    /// 손대지 않은 예시 레시피는 updatedAt이 옛 기준 시각(SampleRecipes.epoch)이라 수정 날짜를 보이지 않는다
    private var edited: Bool { LibrarySync.isNewer(recipe.updatedAt, than: SampleRecipes.epoch) }

    var body: some View {
        let stats = computeStats(recipe.doughInput)
        let bake = model.bakeSummary(for: recipe.id)
        // 접근성 크기에선 한 줄에 하나씩 — 한 줄에 두면 폭을 나눠 가져 숫자·단어 중간에서 끊긴다
        let ax = typeSize.isAccessibilitySize
        let statsLayout = ax
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 8))
        let metaLayout = ax
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 6))
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.name)
                .font(.headline)
            statsLayout {
                StatValue(value: fmtPct(stats.hydrationPct), size: 13)
                if !ax { Text("·").foregroundStyle(.tertiary) }
                Text("\(fmtGrams(stats.doughWeight, precision)) g")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)  // 한 줄 배치에서 모자라면 태그부터 줄인다
                if !ax { Text("·").foregroundStyle(.tertiary) }
                Text(levainShort(recipe.levain.hydration))
                    .font(.footnote)
                    .foregroundStyle(Color.bottle)
                    .lineLimit(1)
                    .layoutPriority(1)
                if let tags = recipe.tags, !tags.isEmpty {
                    Text(tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(ax ? 2 : 1)
                }
            }
            metaLayout {
                if edited {
                    Text(fmtDay(iso: recipe.updatedAt))
                        .lineLimit(1)
                }
                if let bake {
                    if !ax, edited { Text("·") }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "flame")
                        Text(LF("%d회 구움 · 최근 %@", bake.count, fmtDay(iso: bake.latestBakedAt)))
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        // 목록 행은 높이를 모자라게 제안할 때가 있다 — 그러면 수분율이 절반 크기로 줄고 굽기 요약이 한 줄에서 잘린다
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        // VoiceOver는 한 문장으로 — 구분점(·)과 단위 없는 숫자를 조각조각 읽지 않게
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary(stats: stats, bake: bake))
    }

    private func spokenSummary(stats: DoughStats, bake: AppModel.BakeSummary?) -> String {
        var parts = [
            recipe.name,
            LF("총 수분율 %@", fmtPct(stats.hydrationPct)),
            LF("총 반죽 %@", LF("%@그램", fmtGrams(stats.doughWeight, precision))),
            LF("르방 %@", levainShort(recipe.levain.hydration)),
        ]
        if let tags = recipe.tags, !tags.isEmpty {
            parts.append(LF("태그 %@", tags.joined(separator: ", ")))
        }
        if edited { parts.append(LF("수정 %@", fmtSpokenDate(recipe.updatedAt))) }
        if let bake {
            parts.append(LF("구운 횟수 %d, 최근 %@", bake.count, fmtSpokenDate(bake.latestBakedAt)))
        }
        return parts.joined(separator: ", ")
    }
}

/// 화면용 날짜 — 한국어는 웹과 같은 2026.10.01, 영어는 Oct 1, 2026
func fmtDay(iso: String) -> String {
    guard Lang.shared.current != .ko else { return fmtDate(iso: iso) }
    guard let date = LibrarySync.syncInstant(iso) else { return "" }
    var style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Lang.shared.current.locale)
    // 사용자 달력(불교력·일본력 등)과 무관하게 — fmtDate와 같은 그레고리력 보장
    style.calendar = Calendar(identifier: .gregorian)
    return date.formatted(style)
}

/// VoiceOver용 날짜 (2025년 10월 20일 / October 20, 2025) — 점 표기는 숫자 나열로 읽힌다
func fmtSpokenDate(_ iso: String) -> String {
    guard let date = LibrarySync.syncInstant(iso) else { return "" }
    var style = Date.FormatStyle.dateTime.year().month(.wide).day().locale(Lang.shared.current.locale)
    style.calendar = Calendar(identifier: .gregorian)
    return date.formatted(style)
}

/// 전체 기록 화면 — 값으로 밀어야 두 열 상세의 경로(detailPath)를 비울 때 함께 빠진다
struct BakeLogListRoute: Hashable {
    let recipeId: String
}

struct RecipeDetailView: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe
    @Binding var sheet: RecipeDetailSheet?

    @State private var confirmLoad = false

    /// 상세에 바로 보이는 최근 기록 수 — 기록이 쌓여도 '기록 추가'가 밀려나지 않게 나머지는 전체 목록으로
    private let recentLogCount = 3

    /// 목록에서 넘어온 값이 아니라 모델의 최신 사본 (노트·로그 편집 즉시 반영)
    private var current: Recipe {
        model.recipes.first { $0.id == recipe.id } ?? recipe
    }

    var body: some View {
        let recipe = current
        let input = recipe.doughInput
        let stats = computeStats(input)
        let logs = model.logs(for: recipe.id)
        List {
            header(recipe)
            FicheSections(
                input: input, stats: stats, pieces: recipe.pieces, precision: model.precision,
                basis: model.pctBasis)
            Section {
                Button {
                    sheet = .note(recipeId: recipe.id)
                } label: {
                    if let note = recipe.note, !note.isEmpty {
                        // 가져온 만드는 법은 길다 — 전체는 누르면 열리는 편집 시트에서
                        Text(note)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Label(L("노트 추가"), systemImage: "square.and.pencil")
                    }
                }
            } header: {
                Text(L("노트"))
            }
            .textCase(nil)
            Section {
                Button {
                    sheet = .newLog(recipeId: recipe.id)
                } label: {
                    Label(L("기록 추가"), systemImage: "plus.circle")
                }
                ForEach(logs.prefix(recentLogCount)) { log in
                    EditableBakeLogRow(log: log) { sheet = .editLog(log) }
                }
                if logs.count > recentLogCount {
                    NavigationLink(value: BakeLogListRoute(recipeId: recipe.id)) {
                        Text(LF("기록 모두 보기 (%d)", logs.count))
                    }
                }
            } header: {
                Text(L("베이킹 로그"))
            } footer: {
                if logs.isEmpty {
                    Text(L("이 레시피로 구운 날짜·별점·메모를 남겨 다음 굽기에 참고하세요."))
                }
            }
            .textCase(nil)
        }
        .readableFormWidth()
        .navigationDestination(for: BakeLogListRoute.self) { BakeLogListView(recipeId: $0.recipeId, sheet: $sheet) }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.sendToConverter(name: recipe.name, input: input)
                } label: {
                    Label(L("변환기로 보내기"), systemImage: "arrow.left.arrow.right")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(
                        item: ficheText(
                            name: recipe.name, input: input, stats: stats, pieces: recipe.pieces,
                            basis: model.pctBasis, precision: model.precision)
                    ) {
                        Label(L("배합표 텍스트"), systemImage: "doc.plaintext")
                    }
                    // 받은 사람이 앱의 JSON 가져오기(웹 포함)로 그대로 들여올 수 있는 파일
                    ShareLink(item: RecipesExport(recipes: [recipe]), preview: SharePreview(recipe.name)) {
                        Label(L("레시피 파일"), systemImage: "doc.badge.arrow.up")
                    }
                } label: {
                    Label(L("공유"), systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    /// 이름은 줄바꿈해 끝까지 보인다(인라인 제목은 잘린다). 주 동작은 폭 전체 버튼으로
    private func header(_ recipe: Recipe) -> some View {
        Section {
            // 이름 줄은 시스템 행 여백을 그대로 써서 아래 재료 이름과 같은 선에 선다 (iPad는 여백이 더 넓다)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let tags = recipe.tags, !tags.isEmpty {
                    Text(tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            Button {
                if model.calcIsDirty {
                    confirmLoad = true
                } else {
                    model.loadIntoCalculator(recipe)
                }
            } label: {
                // borderedProminent의 흰 글자는 다크 모드의 밝은 bottle 위에서 대비가 모자란다
                Label(L("계산기로 불러오기"), systemImage: "scalemass")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.paper)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("recipeDetail.load")
            .confirmationDialog(
                L("레시피를 불러올까요? 저장하지 않은 입력은 지워집니다."),
                isPresented: $confirmLoad, titleVisibility: .visible
            ) {
                Button(L("불러오기"), role: .destructive) { model.loadIntoCalculator(current) }
                Button(L("취소"), role: .cancel) {}
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        }
    }
}

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
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
            .navigationTitle(L("설정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("완료")) { dismiss() }
                }
            }
        }
        .adaptiveDetents([.medium, .large])
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

/// library.json 쓰기 실패 안내 — 다음 쓰기가 성공할 때까지 표시된다
struct LibraryWriteErrorLabel: View {
    var body: some View {
        Label(L("기기에 저장하지 못했습니다 — 저장 공간을 확인하세요"), systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(Color.danger)
    }
}

/// 웹앱과 호환되는 레시피 내보내기 — 공유 시점에만 인코딩한다
struct RecipesExport: Transferable {
    let recipes: [Recipe]

    static let libraryFileName = "doughmetry-recipes.json"

    /// 한 건이면 레시피 이름으로 — 경로 구분자는 파일 이름에 쓸 수 없다
    var fileName: String {
        guard recipes.count == 1 else { return Self.libraryFileName }
        let base = recipes[0].name
            .components(separatedBy: CharacterSet(charactersIn: "/:\\"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (base.isEmpty ? "doughmetry-recipe" : base) + ".json"
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            Data(try RecipeCodec.exportJSON(export.recipes).utf8)
        }
        .suggestedFileName { $0.fileName }
    }
}
