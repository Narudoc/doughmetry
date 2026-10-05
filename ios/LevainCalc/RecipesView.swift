import CoreTransferable
import LevainCore
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
    @State private var search = ""
    @AppStorage("recipeSort") private var sort: RecipeSort = .updated
    @State private var showImporter = false
    @State private var importError: String?
    @State private var importResult: (added: Int, skipped: Int)?
    @State private var showSettings = false
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
        NavigationStack {
            content
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
            .navigationDestination(for: String.self) { id in
                if let recipe = model.recipes.first(where: { $0.id == id }) {
                    RecipeDetailView(recipe: recipe)
                } else {
                    // 다른 기기에서 삭제된 레시피가 동기화로 사라진 경우
                    ContentUnavailableView(
                        L("삭제된 레시피"), systemImage: "trash",
                        description: Text(L("이 레시피는 다른 기기에서 삭제되었습니다.")))
                }
            }
            .toolbar { toolbarContent }
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
                        ? LF("%d개를 가져왔고, %d개는 기기에 같거나 더 새로운 버전이 있어 건너뛰었습니다.", added, skipped)
                        : LF("%d개의 레시피를 가져왔습니다.", count: added))
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
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
            .sheet(
                isPresented: $showTextSheet,
                onDismiss: { if !importingAI { importSession = nil } }
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
                    model.save(
                        Recipe(
                            name: name, note: note, createdAt: now, updatedAt: now, input: input,
                            pieces: pieces))
                    importSaved.toggle()
                }
            }
            .overlay {
                if importingAI {
                    importProgress
                }
            }
            .sensoryFeedback(.success, trigger: importSaved)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.recipes.isEmpty {
            emptyState
        } else {
            List {
                ForEach(filtered) { recipe in
                    row(recipe)
                }
            }
            .readableFormWidth()
            .searchable(
                text: $search, placement: .navigationBarDrawer(displayMode: .always),
                prompt: L("이름·메모·태그 검색"))
        }
    }

    private func row(_ recipe: Recipe) -> some View {
        NavigationLink(value: recipe.id) {
            RecipeRow(recipe: recipe, precision: model.precision)
        }
        .accessibilityIdentifier("recipes.row")
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
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showSettings = true
            } label: {
                Label(L("설정"), systemImage: "gearshape")
            }
        }
        if model.recipes.count > 1 {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(L("정렬"), selection: $sort) {
                        Text(L("최근 수정")).tag(RecipeSort.updated)
                        Text(L("최근 구움")).tag(RecipeSort.lastBaked)
                        Text(L("이름")).tag(RecipeSort.name)
                    }
                } label: {
                    Label(L("정렬"), systemImage: "arrow.up.arrow.down")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showImportDialog = true
            } label: {
                // iOS 26+ 툴바는 Label의 labelStyle(.titleAndIcon)을 무시하고 아이콘만 그린다
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text(L("가져오기"))
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
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
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
            } label: {
                Label(L("가져오기/내보내기"), systemImage: "ellipsis.circle")
            }
        }
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
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    Button {
                        model.selectedTab = .calculator
                    } label: {
                        // 테두리 없는 버튼은 글자 높이만 눌린다 — 44pt 탭 영역
                        Text(L("계산기로 가기"))
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

    /// 예시 배합을 라이브러리에 넣는다 — 일반 저장과 같은 경로(updatedAt 갱신, 지웠던 예시의 묘비 해제)
    private func addSamples() {
        // save는 맨 앞에 넣으므로 역순으로 — 정의한 순서대로 보인다
        for recipe in SampleRecipes.make(now: isoNow(), localize: L).reversed() {
            model.save(recipe)
        }
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
        guard !importingAI, review == nil else { return }
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
                review = result
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

struct RecipeRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let recipe: Recipe
    let precision: Precision

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
                Text(fmtDay(iso: recipe.updatedAt))
                    .lineLimit(1)
                if let bake {
                    if !ax { Text("·") }
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
        parts.append(LF("수정 %@", fmtSpokenDate(recipe.updatedAt)))
        if let bake {
            parts.append(LF("구운 횟수 %d, 최근 %@", bake.count, fmtSpokenDate(bake.latestBakedAt)))
        }
        return parts.joined(separator: ", ")
    }
}

/// 화면용 날짜 — 한국어는 웹과 같은 2026.10.01, 영어는 Oct 1, 2026
func fmtDay(iso: String) -> String {
    guard Lang.shared.current != .ko else { return fmtDate(iso: iso) }
    guard let date = parseISO(iso) else { return "" }
    var style = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Lang.shared.current.locale)
    // 사용자 달력(불교력·일본력 등)과 무관하게 — fmtDate와 같은 그레고리력 보장
    style.calendar = Calendar(identifier: .gregorian)
    return date.formatted(style)
}

/// VoiceOver용 날짜 (2025년 10월 20일 / October 20, 2025) — 점 표기는 숫자 나열로 읽힌다
func fmtSpokenDate(_ iso: String) -> String {
    guard let date = parseISO(iso) else { return "" }
    var style = Date.FormatStyle.dateTime.year().month(.wide).day().locale(Lang.shared.current.locale)
    style.calendar = Calendar(identifier: .gregorian)
    return date.formatted(style)
}

struct RecipeDetailView: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe

    @State private var showNoteEdit = false
    @State private var showNewLog = false
    @State private var editingLog: BakeLog?
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
                    showNoteEdit = true
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
            Section {
                Button {
                    showNewLog = true
                } label: {
                    Label(L("기록 추가"), systemImage: "plus.circle")
                }
                ForEach(logs.prefix(recentLogCount)) { log in
                    EditableBakeLogRow(log: log) { editingLog = log }
                }
                if logs.count > recentLogCount {
                    NavigationLink {
                        BakeLogListView(recipeId: recipe.id)
                    } label: {
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
        }
        .readableFormWidth()
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
        .sheet(isPresented: $showNoteEdit) {
            NoteEditSheet(initial: recipe.note ?? "") { text in
                model.updateNote(recipeId: recipe.id, note: text)
            }
        }
        .newBakeLogSheet(isPresented: $showNewLog, recipeId: recipe.id)
        .sheet(item: $editingLog) { log in
            BakeLogSheet(recipeId: recipe.id, existing: log) { model.saveLog($0) }
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
                    LabeledContent(L("상태")) {
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
                Section {
                    Picker(L("언어"), selection: Bindable(Lang.shared).current) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                } footer: {
                    Text(L("검색 같은 시스템 화면은 앱을 다시 열면 바뀝니다. 공유 시트의 일부 항목은 기기 언어를 따릅니다."))
                }
                Section {
                    Picker(L("% 표기"), selection: $model.pctBasis) {
                        Text(L("총 밀가루 기준")).tag(PctBasis.totalFlour)
                        Text(L("베이커스 퍼센트")).tag(PctBasis.addedFlour)
                    }
                    NavigationLink(L("용어 설명")) { GlossaryView() }
                } footer: {
                    Text(L("표시만 바뀝니다 — 계산과 총 수분율·PFF는 항상 총 밀가루 기준입니다."))
                }
                Section {
                    Picker(L("표시 자릿수"), selection: $model.precision) {
                        ForEach(Precision.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    Toggle(L("배합표를 보는 동안 화면 켜두기"), isOn: $keepAwake)
                } footer: {
                    Text(L("내부 계산은 항상 full precision — 반올림은 표시에만 적용됩니다."))
                }
                Section {
                    LabeledContent(L("버전"), value: "\(AppInfo.version) (\(AppInfo.build))")
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
            }
            .navigationTitle(L("설정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("완료")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
