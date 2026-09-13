import CoreTransferable
import LevainCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RecipesView: View {
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var showImporter = false
    @State private var importError: String?
    @State private var importedCount: Int?
    @State private var showSettings = false
    @State private var showImportDialog = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showTextSheet = false
    @State private var importingAI = false
    @State private var review: ImportedRecipe?
    @State private var importSaved = false

    private var filtered: [Recipe] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.recipes }
        return model.recipes.filter { r in
            r.name.localizedCaseInsensitiveContains(q)
                || (r.tags ?? []).contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.recipes.isEmpty {
                    ContentUnavailableView(
                        L("저장된 레시피가 없습니다"),
                        systemImage: "book.closed",
                        description: Text(L("계산기에서 배합을 만들고 저장하세요.")))
                } else {
                    List {
                        ForEach(filtered) { recipe in
                            NavigationLink(value: recipe.id) {
                                RecipeRow(recipe: recipe, precision: model.precision)
                            }
                        }
                        .onDelete { offsets in
                            // 삭제로 filtered가 재계산되기 전에 id를 먼저 확정한다
                            let ids = Set(offsets.map { filtered[$0].id })
                            model.delete(ids: ids)
                        }
                    }
                    .searchable(text: $search, prompt: L("이름·태그 검색"))
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Label(L("설정"), systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImportDialog = true
                    } label: {
                        Label(L("AI로 가져오기"), systemImage: "sparkles")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !model.recipes.isEmpty {
                            ShareLink(
                                item: RecipesExport(recipes: model.recipes),
                                preview: SharePreview("doughmetry-recipes.json")
                            ) {
                                Label(L("JSON 내보내기"), systemImage: "square.and.arrow.up")
                            }
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label(L("JSON 가져오기"), systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Label(L("가져오기/내보내기"), systemImage: "ellipsis.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .plainText]
            ) { result in
                handleImport(result)
            }
            .alert(
                L("가져오기 실패"), isPresented: .init(
                    get: { importError != nil }, set: { if !$0 { importError = nil } })
            ) {
                Button(L("확인"), role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .alert(
                L("가져오기 완료"), isPresented: .init(
                    get: { importedCount != nil }, set: { if !$0 { importedCount = nil } })
            ) {
                Button(L("확인"), role: .cancel) {}
            } message: {
                Text(LF("%d개의 레시피를 가져왔습니다.", importedCount ?? 0))
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .confirmationDialog(
                L("AI로 가져오기"), isPresented: $showImportDialog, titleVisibility: .visible
            ) {
                Button(L("사진에서 가져오기")) { showPhotoPicker = true }
                Button(L("텍스트 붙여넣기")) { showTextSheet = true }
                Button(L("취소"), role: .cancel) {}
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                runImport {
                    guard let data = try await item.loadTransferable(type: Data.self),
                        let image = UIImage(data: data)
                    else { throw ImportError.unreadableImage }
                    return try await RecipeImporter.importRecipe(from: image)
                }
            }
            .sheet(isPresented: $showTextSheet) {
                TextImportSheet { text in
                    runImport { try await RecipeImporter.importRecipe(from: text) }
                }
            }
            .sheet(item: $review) { imported in
                ImportReviewSheet(imported: imported) { name, input in
                    let now = isoNow()
                    model.save(Recipe(name: name, createdAt: now, updatedAt: now, input: input))
                    importSaved.toggle()
                }
            }
            .overlay {
                if importingAI {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView(L("인식 중…"))
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .sensoryFeedback(.success, trigger: importSaved)
        }
    }

    /// AI 인식 파이프라인 실행 — 결과는 확인 시트로, 실패는 알림으로
    private func runImport(_ work: @escaping () async throws -> ImportedRecipe) {
        importingAI = true
        Task { @MainActor in
            defer { importingAI = false }
            do {
                review = try await work()
            } catch let error as ImportError {
                switch error {
                case .unreadableImage:
                    importError = L("이미지를 읽을 수 없습니다")
                case .noText:
                    importError = L("이미지에서 텍스트를 찾지 못했습니다")
                case .noIngredients:
                    importError = L("재료를 인식하지 못했습니다. 더 선명한 사진이나 정리된 텍스트로 다시 시도해 주세요.")
                }
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
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
                // 같은 id는 덮어쓰기, 새 레시피는 앞에 추가 (웹과 동일)
                for recipe in imported.reversed() {
                    model.save(recipe, touch: false)  // 백업의 updatedAt 보존
                }
                importedCount = imported.count
            }
        }
    }
}

struct RecipeRow: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe
    let precision: Precision

    var body: some View {
        let stats = computeStats(recipe.doughInput)
        let logs = model.logs(for: recipe.id)
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.name)
                .font(.headline)
            HStack(spacing: 8) {
                StatValue(value: fmtPct(stats.hydrationPct), size: 13)
                Text("·").foregroundStyle(.tertiary)
                Text("\(fmtGrams(stats.doughWeight, precision)) g")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Text(recipe.levain.hydration >= 0.75 ? L("리퀴드") : L("뒤흐"))
                    .font(.footnote)
                    .foregroundStyle(Color.bottle)
                if let tags = recipe.tags, !tags.isEmpty {
                    Text(tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            HStack(spacing: 6) {
                Text(fmtDate(iso: recipe.updatedAt))
                if let last = logs.first {
                    Text("·")
                    Image(systemName: "flame")
                    Text(LF("%d회 구움 · 최근 %@", logs.count, fmtDate(iso: last.bakedAt)))
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct RecipeDetailView: View {
    @Environment(AppModel.self) private var model
    let recipe: Recipe

    @State private var showNoteEdit = false
    @State private var showNewLog = false
    @State private var editingLog: BakeLog?

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
            Section {
                Button {
                    showNoteEdit = true
                } label: {
                    if let note = recipe.note, !note.isEmpty {
                        Text(note)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Label(L("노트 추가"), systemImage: "square.and.pencil")
                    }
                }
            } header: {
                Text(L("노트"))
            }
            Section {
                ForEach(logs) { log in
                    Button {
                        editingLog = log
                    } label: {
                        BakeLogRow(log: log)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .onDelete { offsets in
                    let ids = offsets.map { logs[$0].id }
                    for id in ids { model.deleteLog(id) }
                }
                Button {
                    showNewLog = true
                } label: {
                    Label(L("기록 추가"), systemImage: "plus.circle")
                }
            } header: {
                Text(L("베이킹 로그"))
            } footer: {
                if logs.isEmpty {
                    Text(L("이 레시피로 구운 날짜·별점·메모를 남겨 다음 굽기에 참고하세요."))
                }
            }
            Section(L("재료")) {
                ForEach(input.flours) { f in
                    TableRow(
                        name: f.name.isEmpty ? L("밀가루") : f.name,
                        grams: fmtGrams(f.grams, model.precision),
                        pct: fmtPct(stats.uiPct(grams: f.grams, basis: model.pctBasis)))
                }
                TableRow(name: L("본반죽 물"), grams: fmtGrams(input.water, model.precision), pct: nil)
                if input.bassinage > 0 {
                    TableRow(
                        name: L("바시나주"), grams: fmtGrams(input.bassinage, model.precision), pct: nil)
                }
                TableRow(
                    name: L("소금"), grams: fmtGrams(input.salt, model.precision),
                    pct: fmtPct(stats.uiPct(grams: input.salt, basis: model.pctBasis)))
                TableRow(
                    name: recipe.levain.hydration >= 0.75 ? L("르방 리퀴드") : L("르방 뒤흐"),
                    grams: fmtGrams(recipe.levain.grams, model.precision),
                    pct: fmtPct(
                        stats.uiLevainPct(
                            levainGrams: recipe.levain.grams, basis: model.pctBasis)))
                ForEach(input.liquids) { l in
                    TableRow(
                        name: l.name.isEmpty ? L("액체") : l.name,
                        grams: fmtGrams(l.grams, model.precision),
                        pct: fmtPct(stats.uiPct(grams: l.grams, basis: model.pctBasis)))
                }
                if input.yeast.grams > 0 {
                    TableRow(
                        name: input.yeast.type == .fresh ? L("생이스트") : L("인스턴트 이스트"),
                        grams: fmtGrams(input.yeast.grams, model.precision),
                        pct: fmtPct(stats.uiPct(grams: input.yeast.grams, basis: model.pctBasis)))
                }
                ForEach(input.extras) { e in
                    TableRow(
                        name: e.name.isEmpty ? L("기타") : e.name,
                        grams: fmtGrams(e.grams, model.precision),
                        pct: fmtPct(stats.uiPct(grams: e.grams, basis: model.pctBasis)))
                }
            }
            Section(L("지표")) {
                LabeledContent(L("총 수분율")) { StatValue(value: fmtPct(stats.hydrationPct)) }
                LabeledContent(L("총 반죽 무게")) {
                    StatValue(value: fmtGrams(stats.doughWeight, model.precision) + " g")
                }
                LabeledContent("PFF") { StatValue(value: fmtPct(stats.pffPct)) }
                if let pieces = recipe.pieces, pieces > 0 {
                    LabeledContent(L("분할")) {
                        StatValue(
                            value:
                                LF("%d개 × %@ g", Int(pieces), fmtGrams(stats.doughWeight / pieces, model.precision))
                        )
                    }
                }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("계산기로 불러오기")) {
                    model.loadIntoCalculator(recipe)
                }
            }
        }
        .sheet(isPresented: $showNoteEdit) {
            NoteEditSheet(initial: recipe.note ?? "") { text in
                model.updateNote(recipeId: recipe.id, note: text)
            }
        }
        .sheet(isPresented: $showNewLog) {
            BakeLogSheet(recipeId: recipe.id, existing: nil) { model.saveLog($0) }
        }
        .sheet(item: $editingLog) { log in
            BakeLogSheet(recipeId: recipe.id, existing: log) { model.saveLog($0) }
        }
    }
}

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var cloudStatusText: String {
        switch model.cloud.status {
        case .checking: return L("확인 중…")
        case .unavailable: return L("사용 불가 — iCloud 로그인 또는 앱 권한 필요")
        case .disabled: return L("꺼짐")
        case .syncing: return L("동기화 중…")
        case .error(let message): return message
        case .idle:
            if let at = model.cloud.lastSyncAt {
                return LF("마지막 동기화 %@", at.formatted(date: .omitted, time: .shortened))
            }
            return L("대기 중")
        }
    }

    var body: some View {
        @Bindable var model = model
        @Bindable var cloud = model.cloud
        NavigationStack {
            Form {
                Section {
                    Toggle(L("iCloud 동기화"), isOn: $cloud.enabled)
                        .disabled(!cloud.isAvailable)
                    LabeledContent(L("상태")) {
                        Text(cloudStatusText)
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
                }
                Section {
                    Picker(L("% 표기"), selection: $model.pctBasis) {
                        Text(L("총 밀가루 기준")).tag(PctBasis.totalFlour)
                        Text(L("베이커스 퍼센트")).tag(PctBasis.addedFlour)
                    }
                } footer: {
                    Text(L("표시만 바뀝니다 — 계산과 총 수분율·PFF는 항상 총 밀가루 기준입니다."))
                }
                Section {
                    Picker(L("표시 자릿수"), selection: $model.precision) {
                        ForEach(Precision.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                } footer: {
                    Text(L("내부 계산은 항상 full precision — 반올림은 표시에만 적용됩니다."))
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
        .presentationDetents([.medium])
    }
}

/// 웹앱과 호환되는 레시피 내보내기 — 공유 시점에만 인코딩한다
struct RecipesExport: Transferable {
    let recipes: [Recipe]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            Data(try RecipeCodec.exportJSON(export.recipes).utf8)
        }
        .suggestedFileName("doughmetry-recipes.json")
    }
}
