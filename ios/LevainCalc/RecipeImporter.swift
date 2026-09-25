import Foundation
import LevainCore
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 사진/텍스트 → 레시피 자동 인식 파이프라인.
/// 1) Vision OCR로 텍스트 추출 (전 기기, 온디바이스)
/// 2) Apple Intelligence(Foundation Models)로 구조화 — 지원 기기에서만
/// 3) 미지원·실패 시 규칙 기반 파서(LevainCore.RecipeTextParser)로 폴백
/// 결과는 반드시 확인 화면을 거쳐 저장한다.

enum ImportEngine {
    case appleIntelligence
    case rules
}

struct ImportedRecipe: Identifiable {
    let id = UUID()
    var name: String
    var input: DoughInput
    var engine: ImportEngine
    var recognizedText: String
}

enum ImportError: Error {
    case unreadableImage
    case noText
    case noIngredients(recognizedText: String)
}

enum RecipeImporter {
    // MARK: OCR

    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw ImportError.unreadableImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US", "fr-FR"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            let observations = request.results ?? []
            return assembleRows(observations)
        }.value
    }

    static func assembleRows(_ observations: [VNRecognizedTextObservation]) -> String {
        OCRLayout.assembleRows(
            observations.compactMap { obs in
                obs.topCandidates(1).first.map { (text: $0.string, box: obs.boundingBox) }
            })
    }

    // MARK: 파이프라인

    static func importRecipe(from image: UIImage) async throws -> ImportedRecipe {
        let text = try await recognizeText(in: image)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.noText
        }
        return try await importRecipe(from: text)
    }

    static func importRecipe(from text: String) async throws -> ImportedRecipe {
        // @멘션·#해시태그는 어느 경로에서도 재료 정보가 아니다
        let text = RecipeTextParser.cleanForParsing(text)
        let parsed = RecipeTextParser.parse(text)
        // g 수량 줄이 하나도 없으면 모델에 넘기지 않는다 — 온디바이스 모델은 재료 없는 텍스트에도
        // 지시문의 예시(flour 1000g, 호밀 200g, 캉파뉴 전체)를 베껴 레시피를 지어낸다
        guard parsed.matchedLineCount > 0 else {
            throw ImportError.noIngredients(recognizedText: text)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability,
                let result = try? await parseWithAppleIntelligence(text, rules: parsed)
            {
                return result
            }
        }
        #endif
        return ImportedRecipe(
            name: parsed.name ?? "", input: parsed.input, engine: .rules, recognizedText: text)
    }

    // MARK: Apple Intelligence (Foundation Models)

    #if canImport(FoundationModels)
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
        @Guide(description: "르방(사워도우 스타터) 무게 g, 없으면 0")
        var levainGrams: Double
        @Guide(
            description: "르방 수분율 % — 리퀴드는 100, 뒤흐는 50, 명시된 값이 있으면 그 값, 르방이 없으면 100",
            .range(30...150))
        var levainHydrationPct: Double
        @Guide(description: "우유·계란 등 수분을 포함한 액체 재료 — 물·바시나주·르방·풀리시 같은 발효종은 넣지 않는다")
        var liquids: [AILiquid]
        @Guide(description: "이스트 g, 없으면 0")
        var yeastGrams: Double
        @Guide(description: "이스트 종류 — fresh(생이스트) 또는 instant(인스턴트·드라이·sèche)")
        var yeastType: AIYeastType
        @Guide(description: "견과·건과일 등 수분 없는 기타 재료")
        var extras: [AIIngredient]
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
    static func parseWithAppleIntelligence(
        _ text: String, rules: ParsedRecipeText
    ) async throws -> ImportedRecipe {
        let session = LanguageModelSession(
            instructions: """
                사워도우 빵 레시피 텍스트에서 재료를 추출한다. 규칙:
                - 각 재료의 무게는 그 재료 이름 옆에 적힌 숫자다. 다른 재료의 숫자를 가져오지 않는다.
                - 한 재료는 한 곳에만 넣는다.
                - 르방·스타터는 flours가 아니라 levainGrams에 넣는다.
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
                levainGrams=250, levainHydrationPct=100, saltGrams=18, bassinageGrams=0,
                liquids=[]

                예시 입력 2 (숫자가 앞에 오는 SNS 스타일):
                1kg flour
                350 ferment ( starter stiff )
                730 water
                10 yeast fresh
                20 sea salt
                예시 출력 2: flours=[flour 1000g], levainGrams=350, levainHydrationPct=50
                (stiff/dur는 50), waterGrams=730, yeastGrams=10 + yeastType=fresh,
                saltGrams=20, bassinageGrams=0, liquids=[]
                """)
        // 같은 텍스트는 같은 결과가 나오도록 탐욕 샘플링
        let draft = try await session.respond(
            to: text, generating: AIDraft.self,
            options: GenerationOptions(samplingMode: .greedy)
        ).content

        // 30~150% 밖은 베이커스 %("르방 100g (20%)")를 수분율로 읽은 값 — 규칙 파서와 같이 기본값으로
        let aiPct = draft.levainHydrationPct
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
                grams: max(0, draft.levainGrams)),
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

        let input = try reconcile(draftInput, rules: rules, text: text)
        return ImportedRecipe(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines), input: input,
            engine: .appleIntelligence, recognizedText: text)
    }
    #endif

    /// AI 초안을 규칙 파서 결과(같은 text를 parse한 것)로 보정·검증한다. 초안을 믿을 수 없으면 throw —
    /// 호출부가 규칙 파서 결과로 폴백한다.
    static func reconcile(
        _ draft: DoughInput, rules: ParsedRecipeText, text: String
    ) throws -> DoughInput {
        var input = draft
        guard !input.flours.isEmpty || input.levain.grams > 0 || input.water > 0 else {
            throw ImportError.noIngredients(recognizedText: text)
        }
        // 르방·발효종이 밀가루·액체·기타로 분류되면 총 무게는 같아도 수분율·PFF가 틀어진다
        let names = input.flours.map(\.name) + input.liquids.map(\.name) + input.extras.map(\.name)
        if names.contains(where: RecipeTextParser.matchesLevain) {
            throw ImportError.noIngredients(recognizedText: text)
        }

        // 규칙 파서가 키워드(리퀴드/뒤흐/stiff/30~150%)나 르방 빌드 비율로 정한 수분율은
        // 온디바이스 모델의 추정보다 신뢰한다
        if rules.input.levain.grams > 0,
            rules.levainHydrationExplicit || rules.input.levain.hydration != 1.0
        {
            input.levain.hydration = rules.input.levain.hydration
            input.levain.type = rules.input.levain.type
        }
        if input.levain.grams == 0 {
            input.levain.hydration = 1.0
            input.levain.type = .liquide
        }
        for i in input.liquids.indices {
            if let preset = liquidPreset(for: input.liquids[i].name) {
                input.liquids[i].waterRatio = preset.waterRatio
            }
        }
        if rules.input.yeast.grams > 0, rules.input.yeast.type == .instant {
            input.yeast.type = .instant
        }

        // 교차 검증 — 보정 후에도 규칙 파서와 어긋나면 AI 결과를 버린다
        // (온디바이스 소형 모델이 표 형식에서 숫자를 섞거나 재료를 빠뜨리는 경우 방어).
        // 제대로 읽은 초안은 보정 후 총 무게가 규칙 파서와 같다 — 남은 차이는 빠뜨리거나 지어낸 재료이고,
        // 무게 허용치에 묻히는 소량 재료(몰트·이스트)는 가짓수로 본다
        if rules.matchedLineCount >= 3 {
            let ai = computeStats(input)
            let rs = computeStats(rules.input)
            let rulesLevain = rules.input.levain.grams
            if abs(ai.doughWeight - rs.doughWeight) > max(5, rs.doughWeight * 0.01)
                || abs(ai.hydrationPct - rs.hydrationPct) > 2
                || abs(ai.pffPct - rs.pffPct) > 2
                || abs(input.levain.grams - rulesLevain) > max(10, rulesLevain * 0.1)
                || input.extras.count < rules.input.extras.count
                || (rules.input.yeast.grams > 0 && input.yeast.grams == 0)
            {
                throw ImportError.noIngredients(recognizedText: text)
            }
        }
        return input
    }

    /// 우유·계란은 모델이 추정한 수분율 대신 프리셋을 쓴다 — 키워드는 RecipeTextParser의 액체 분기와 같다
    static func liquidPreset(for name: String) -> LiquidPreset? {
        func has(_ words: [String]) -> Bool {
            words.contains { name.localizedCaseInsensitiveContains($0) }
        }
        if has(["우유", "milk", "lait"]) { return .milk }
        if has(["계란", "달걀", "전란", "egg", "oeuf", "œuf"]) { return .egg }
        return nil
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
