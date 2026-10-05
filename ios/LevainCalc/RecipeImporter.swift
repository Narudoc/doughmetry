import Foundation
import ImageIO
import LevainCore
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 사진/텍스트 → 레시피 자동 인식 파이프라인.
/// 1) Vision OCR로 텍스트 추출 (전 기기, 온디바이스)
/// 2) Apple Intelligence(Foundation Models)로 구조화 — 지원 기기에서만
/// 3) 미지원·실패·건너뛰기 시 규칙 기반 파서(LevainCore.RecipeTextParser)로 폴백
/// 결과는 반드시 확인 화면을 거쳐 저장한다.

enum ImportEngine: Sendable {
    case appleIntelligence
    case rules
}

/// 가져오기 진행 단계 — 기다리는 동안 보이는 문구
enum ImportStage: Sendable {
    /// 사진에서 글자를 읽는 중 (Vision)
    case reading
    /// 온디바이스 모델이 재료를 정리하는 중
    case analyzing
}

struct ImportedRecipe: Identifiable, Sendable {
    let id = UUID()
    var name: String
    var input: DoughInput
    /// 공정(만드는 법) 원문 — 노트로 저장한다. 모델에 묻지 않고 규칙 파서가 잘라 낸 원문만 쓴다 (지어낸 공정 방지)
    var note: String
    /// 분량 표기("2개 분량")에서 읽은 분할 개수
    var pieces: Double?
    var engine: ImportEngine
    /// AI 초안이 규칙 분석과 어긋나 버리고 규칙 결과를 보이는 중 — 확인 화면이 물·르방을 다시 보라고 알린다
    var aiRejected = false
    var recognizedText: String
}

enum ImportError: Error {
    case unreadableImage
    case noText
    case noIngredients(recognizedText: String)
}

/// 가져오기 한 번의 모델 세션 — 사진 고르기·텍스트 붙여넣기 동안 미리 데워 두고,
/// '규칙 결과로 보기'로 모델 분석만 끊는다. 앞선 인식의 대화 기록이 섞이지 않게 가져오기마다 새로 만든다
@MainActor
final class ImportSession {
    /// LanguageModelSession (iOS 26+) — 저장 프로퍼티에는 가용성을 걸 수 없다
    private var model: (any Sendable)?
    private var cancelAnalysis: (@Sendable () -> Void)?
    private var skipped = false

    /// 새 세션 — 모델을 쓸 수 있는 기기면 모델 로드·지시문 처리를 미리 시작한다
    static func prewarmed() -> ImportSession {
        let session = ImportSession()
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), RecipeImporter.modelAvailable {
            let model = RecipeImporter.makeLanguageSession()
            model.prewarm()
            session.model = model
        }
        #endif
        return session
    }

    /// 모델 분석만 취소한다 — 가져오기는 이미 끝난 규칙 분석 결과로 이어진다
    func skipAnalysis() {
        skipped = true
        cancelAnalysis?()
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    fileprivate func takeLanguageSession() -> LanguageModelSession? {
        defer { model = nil }
        return model as? LanguageModelSession
    }
    #endif

    /// 분석 시작 전에 건너뛰기를 눌렀으면 바로 취소한다
    fileprivate func track(_ cancel: @escaping @Sendable () -> Void) {
        if skipped { cancel() } else { cancelAnalysis = cancel }
    }
}

enum RecipeImporter {
    // MARK: OCR

    /// 사진 데이터 → 텍스트. 디코딩한 비트맵은 이 안에서만 살아 있다 — 모델을 기다리는 동안 들고 있지 않는다
    static func recognizeText(in data: Data) async throws -> String {
        let recognition = TextRecognition()
        // 분리된 작업은 취소를 물려받지 않는다 — Vision 요청을 직접 끊는다
        let text = try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try recognition.perform(on: RecipeImporter.downsampledImage(data))
            }.value
        } onCancel: {
            recognition.cancel()
        }
        try Task.checkCancellation()
        return text
    }

    /// 넓이 상한(12 MP)까지 줄여 디코딩한다 — EXIF 회전도 여기서 적용된다.
    /// 긴 변이 아니라 넓이로 자른다: 이어 붙인 세로 스크린숏(1290×12000)을 긴 변 4032로 줄이면 글자가 뭉개진다
    static func downsampledImage(_ data: Data) throws -> CGImage {
        guard
            let source = CGImageSourceCreateWithData(
                data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { throw ImportError.unreadableImage }
        let maxArea = 4032.0 * 3024
        var maxPixel = 4032
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let w = props[kCGImagePropertyPixelWidth] as? Int,
            let h = props[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0
        {
            let area = Double(w) * Double(h)
            let longSide = max(w, h)
            maxPixel = area <= maxArea ? longSide : Int(Double(longSide) * (maxArea / area).squareRoot())
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImportError.unreadableImage
        }
        return image
    }

    static func assembleRows(_ observations: [VNRecognizedTextObservation]) -> String {
        OCRLayout.assembleRows(
            observations.compactMap { obs in
                obs.topCandidates(1).first.map { (text: $0.string, box: obs.boundingBox) }
            })
    }

    // MARK: 파이프라인

    static func importRecipe(
        from data: Data, session: ImportSession? = nil,
        onStage: @escaping @MainActor @Sendable (ImportStage) -> Void = { _ in }
    ) async throws -> ImportedRecipe {
        await onStage(.reading)
        let text = try await recognizeText(in: data)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.noText
        }
        return try await importRecipe(from: text, session: session, onStage: onStage)
    }

    static func importRecipe(
        from text: String, session: ImportSession? = nil,
        onStage: @escaping @MainActor @Sendable (ImportStage) -> Void = { _ in }
    ) async throws -> ImportedRecipe {
        // @멘션·#해시태그는 어느 경로에서도 재료 정보가 아니다
        let text = RecipeTextParser.cleanForParsing(text)
        let parsed = RecipeTextParser.parse(text)
        // g 수량 줄이 하나도 없으면 모델에 넘기지 않는다 — 온디바이스 모델은 재료 없는 텍스트에도
        // 지시문의 예시(flour 1000g, 호밀 200g, 캉파뉴 전체)를 베껴 레시피를 지어낸다
        guard parsed.matchedLineCount > 0 else {
            throw ImportError.noIngredients(recognizedText: text)
        }
        var aiRejected = false
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), modelAvailable {
            await onStage(.analyzing)
            do {
                if let result = try await analyze(text, rules: parsed, session: session) {
                    return result
                }
                Log.importer.notice("AI 분석 시간 초과 — 규칙 결과로")
            } catch let reason as ReconcileRejection {
                Log.importer.notice("AI 초안 기각: \(String(describing: reason), privacy: .public)")
                aiRejected = reason != .empty
            } catch {
                // 건너뛰기(취소)·모델 오류 — 규칙 결과로
            }
        }
        #endif
        try Task.checkCancellation()
        return ImportedRecipe(
            name: parsed.name ?? "", input: parsed.input, note: parsed.methodNote ?? "",
            pieces: parsed.pieces, engine: .rules, aiRejected: aiRejected, recognizedText: text)
    }

    /// operation이 seconds 안에 끝나지 않으면 nil — 남은 작업은 취소한다
    static func withDeadline<T: Sendable>(
        seconds: Double, _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                return nil
            }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
    }

    // MARK: Apple Intelligence (Foundation Models)

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    static var modelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    @available(iOS 26.0, *)
    @Generable
    enum AIYeastType {
        case fresh
        case instant
    }

    @available(iOS 26.0, *)
    @Generable
    struct AIDraft {
        @Guide(description: "레시피 이름 (제목이 없으면 빈 문자열)")
        var name: String
        @Guide(description: "첨가 밀가루 목록 — 르방 속 밀가루는 제외")
        var flours: [AIIngredient]
        @Guide(description: "본반죽 물의 g (바시나주 제외)")
        var waterGrams: Double
        @Guide(description: "바시나주(bassinage) 물의 g, 없으면 0")
        var bassinageGrams: Double
        @Guide(description: "소금 g")
        var saltGrams: Double
        @Guide(description: "르방(사워도우 스타터)")
        var levain: AILevain
        @Guide(description: "우유·계란 등 수분을 포함한 액체 재료 — 물·바시나주·르방·풀리시 같은 발효종은 넣지 않는다")
        var liquids: [AILiquid]
        @Guide(description: "이스트 g, 없으면 0")
        var yeastGrams: Double
        @Guide(description: "이스트 종류 — fresh(생이스트) 또는 instant(인스턴트·드라이·sèche)")
        var yeastType: AIYeastType
        @Guide(description: "견과·건과일 등 수분 없는 기타 재료")
        var extras: [AIIngredient]
    }

    /// name은 결과에 쓰지 않지만 무게보다 먼저 받아야 한다 — 무게만 물으면 모델이 '르방 리퀴드'·'Liquid levain'·
    /// '스타터'·'starter (stiff)' 줄을 르방으로 짚지 못하고 "없으면 0"을 적는다 (르방이 빠진 초안은 무게 검증에서 버려진다).
    /// 줄 이름을 먼저 옮겨 적게 하면 그 줄의 숫자를 무게로 쓴다
    @available(iOS 26.0, *)
    @Generable
    struct AILevain {
        @Guide(description: "르방·스타터·발효종 줄에 적힌 이름 그대로 (예: 르방 리퀴드, 스타터, 풀리시, levain, starter), 없으면 빈 문자열")
        var name: String
        @Guide(description: "르방 무게 g, 없으면 0")
        var grams: Double
        @Guide(
            description: "르방 수분율 % — 리퀴드는 100, 뒤흐는 50, 명시된 값이 있으면 그 값, 르방이 없으면 100",
            .range(30...150))
        var hydrationPct: Double
    }

    @available(iOS 26.0, *)
    @Generable
    struct AIIngredient {
        @Guide(description: "재료 이름")
        var name: String
        @Guide(description: "무게 g")
        var grams: Double
    }

    @available(iOS 26.0, *)
    @Generable
    struct AILiquid {
        var name: String
        var grams: Double
        @Guide(description: "수분율 % — 우유 88, 계란 76", .range(0...100))
        var waterRatioPct: Double
    }

    @available(iOS 26.0, *)
    static func makeLanguageSession() -> LanguageModelSession {
        LanguageModelSession(
            instructions: """
                사워도우 빵 레시피 텍스트에서 재료를 추출한다. 규칙:
                - 각 재료의 무게는 그 재료 이름 옆에 적힌 숫자다. 다른 재료의 숫자를 가져오지 않는다.
                - 한 재료는 한 곳에만 넣는다.
                - 르방·스타터와 풀리시·비가 같은 발효종은 flours가 아니라 levain에 넣는다.
                - liquids에는 우유·계란처럼 물이 아닌 액체만 넣는다. 없으면 빈 목록.
                - 르방 리퀴드(levain liquide)는 수분율 100%, 르방 뒤흐(levain dur)는 50%.
                - 바시나주(bassinage)는 본반죽 물(waterGrams)과 구분한다.
                - 합계·총계·베이커스 퍼센트·수분율 줄은 재료가 아니므로 무시한다.
                - 무게 단위는 전부 g. 표기가 kg이면 g로 환산한다.
                - 확실하지 않은 재료는 extras에 넣는다.

                예시 입력 1:
                캉파뉴
                T65 800
                호밀 200
                물 700
                르방 리퀴드 250
                소금 18
                예시 출력 1: name="캉파뉴", flours=[T65 800g, 호밀 200g], waterGrams=700,
                levain={name="르방 리퀴드", grams=250, hydrationPct=100}, saltGrams=18,
                bassinageGrams=0, liquids=[]

                예시 입력 2 (숫자가 앞에 오는 SNS 스타일):
                1kg flour
                350 ferment ( starter stiff )
                730 water
                10 yeast fresh
                20 sea salt
                예시 출력 2: flours=[flour 1000g], levain={name="ferment ( starter stiff )",
                grams=350, hydrationPct=50} (stiff/dur는 50), waterGrams=730, yeastGrams=10 +
                yeastType=fresh, saltGrams=20, bassinageGrams=0, liquids=[]
                """)
    }

    /// 모델 분석 — 시간 초과(nil)·건너뛰기(취소)·교차 검증 기각(ReconcileRejection)이면 호출부가 규칙 결과를 쓴다.
    /// 실측 응답이 3.5초 안팎이라 기한은 넉넉히 10초
    @available(iOS 26.0, *)
    static func analyze(
        _ text: String, rules: ParsedRecipeText, session: ImportSession?
    ) async throws -> ImportedRecipe? {
        let model = await session?.takeLanguageSession() ?? makeLanguageSession()
        let analysis = Task {
            try await withDeadline(seconds: 10) {
                try await parseWithAppleIntelligence(text, rules: rules, session: model)
            }
        }
        await session?.track { analysis.cancel() }
        return try await withTaskCancellationHandler {
            try await analysis.value
        } onCancel: {
            analysis.cancel()
        }
    }

    @available(iOS 26.0, *)
    static func parseWithAppleIntelligence(
        _ text: String, rules: ParsedRecipeText, session: LanguageModelSession
    ) async throws -> ImportedRecipe {
        // 같은 텍스트는 같은 결과가 나오도록 탐욕 샘플링
        let draft = try await session.respond(
            to: text, generating: AIDraft.self,
            options: GenerationOptions(samplingMode: .greedy)
        ).content

        // 30~150% 밖은 베이커스 %("르방 100g (20%)")를 수분율로 읽은 값 — 규칙 파서와 같이 기본값으로
        let aiPct = draft.levain.hydrationPct
        let hydration = (30...150).contains(aiPct) ? aiPct / 100 : 1.0
        let draftInput = DoughInput(
            flours: draft.flours
                .filter { $0.grams > 0 }
                .map { Flour(name: $0.name, grams: $0.grams) },
            water: max(0, draft.waterGrams),
            bassinage: max(0, draft.bassinageGrams),
            salt: max(0, draft.saltGrams),
            levain: Levain(
                type: levainTypeFor(hydration: hydration),
                hydration: hydration,
                grams: max(0, draft.levain.grams)),
            liquids: draft.liquids
                .filter { $0.grams > 0 }
                .map {
                    Liquid(
                        name: $0.name, grams: $0.grams,
                        waterRatio: min(1, max(0, $0.waterRatioPct / 100)))
                },
            yeast: Yeast(
                type: draft.yeastType == .instant ? .instant : .fresh,
                grams: max(0, draft.yeastGrams)),
            extras: draft.extras
                .filter { $0.grams > 0 }
                .map { Extra(name: $0.name, grams: $0.grams) })

        let input = try reconcileAIDraft(draftInput, rules: rules).get()
        return ImportedRecipe(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines), input: input,
            note: rules.methodNote ?? "", pieces: rules.pieces,
            engine: .appleIntelligence, recognizedText: text)
    }
    #endif
}

/// Vision 글자 인식 한 번 — 취소 핸들러(다른 스레드)에서 요청을 끊을 수 있게 요청을 들고 있다.
/// VNRequest.cancel()은 수행 중인 다른 스레드에서 불러도 된다
private final class TextRecognition: @unchecked Sendable {
    private let request: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US", "fr-FR"]
        request.usesLanguageCorrection = true
        return request
    }()

    func cancel() { request.cancel() }

    /// image는 회전이 이미 적용된 비트맵이다 (downsampledImage)
    func perform(on image: CGImage) throws -> String {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try handler.perform([request])
        return RecipeImporter.assembleRows(request.results ?? [])
    }
}
