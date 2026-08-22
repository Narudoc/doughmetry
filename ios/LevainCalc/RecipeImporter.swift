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

    /// 관측된 텍스트 조각을 표의 행 단위로 재조립 —
    /// y가 비슷한 조각을 한 줄로 묶고 왼쪽부터 정렬한다 ("재료 | 양" 표 대응)
    static func assembleRows(_ observations: [VNRecognizedTextObservation]) -> String {
        struct Piece {
            let text: String
            let box: CGRect
        }
        let pieces = observations.compactMap { obs -> Piece? in
            guard let top = obs.topCandidates(1).first else { return nil }
            return Piece(text: top.string, box: obs.boundingBox)
        }
        guard !pieces.isEmpty else { return "" }

        let avgHeight = pieces.map(\.box.height).reduce(0, +) / CGFloat(pieces.count)
        let threshold = max(avgHeight * 0.6, 0.008)

        var rows: [[Piece]] = []
        // Vision 좌표계는 좌하단 원점 — 위에서 아래로 정렬
        for piece in pieces.sorted(by: { $0.box.midY > $1.box.midY }) {
            if var last = rows.last, let refY = last.first?.box.midY,
                abs(refY - piece.box.midY) < threshold
            {
                last.append(piece)
                rows[rows.count - 1] = last
            } else {
                rows.append([piece])
            }
        }
        return rows
            .map { row in
                row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
            }
            .joined(separator: "\n")
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
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability,
                let result = try? await parseWithAppleIntelligence(text)
            {
                return result
            }
        }
        #endif
        let parsed = RecipeTextParser.parse(text)
        guard parsed.matchedLineCount > 0 else {
            throw ImportError.noIngredients(recognizedText: text)
        }
        return ImportedRecipe(
            name: parsed.name ?? "", input: parsed.input, engine: .rules, recognizedText: text)
    }

    // MARK: Apple Intelligence (Foundation Models)

    #if canImport(FoundationModels)
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
        @Guide(description: "르방 수분율 % — 리퀴드는 100, 뒤흐는 50, 명시된 값이 있으면 그 값")
        var levainHydrationPct: Double
        @Guide(description: "우유·계란 등 수분을 포함한 액체 재료")
        var liquids: [AILiquid]
        @Guide(description: "이스트 g, 없으면 0")
        var yeastGrams: Double
        @Guide(description: "이스트 종류 — fresh(생) 또는 instant(인스턴트/드라이)")
        var yeastType: String
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
        @Guide(description: "수분율 % — 우유 88, 계란 76, 물 100")
        var waterRatioPct: Double
    }

    @available(iOS 26.0, *)
    static func parseWithAppleIntelligence(_ text: String) async throws -> ImportedRecipe {
        let session = LanguageModelSession(
            instructions: """
                사워도우 빵 레시피 텍스트에서 재료를 추출한다. 규칙:
                - 각 재료의 무게는 그 재료 이름 옆에 적힌 숫자다. 다른 재료의 숫자를 가져오지 않는다.
                - 르방·스타터는 flours가 아니라 levainGrams에 넣는다.
                - 르방 리퀴드(levain liquide)는 수분율 100%, 르방 뒤흐(levain dur)는 50%.
                - 바시나주(bassinage)는 본반죽 물(waterGrams)과 구분한다.
                - 합계·총계·베이커스 퍼센트·수분율 줄은 재료가 아니므로 무시한다.
                - 무게 단위는 전부 g. 표기가 kg이면 g로 환산한다.
                - 확실하지 않은 재료는 extras에 넣는다.

                예시 입력:
                캉파뉴
                T65 800
                호밀 200
                물 700
                르방 리퀴드 250
                소금 18
                예시 출력: name="캉파뉴", flours=[T65 800g, 호밀 200g], waterGrams=700,
                levainGrams=250, levainHydrationPct=100, saltGrams=18, bassinageGrams=0
                """)
        let draft = try await session.respond(to: text, generating: AIDraft.self).content

        let hydration = max(0.01, draft.levainHydrationPct / 100)
        let input = DoughInput(
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
                type: draft.yeastType.lowercased().contains("instant") ? .instant : .fresh,
                grams: max(0, draft.yeastGrams)),
            extras: draft.extras
                .filter { $0.grams > 0 }
                .map { Extra(name: $0.name, grams: $0.grams) })

        guard !input.flours.isEmpty || input.levain.grams > 0 || input.water > 0 else {
            throw ImportError.noIngredients(recognizedText: text)
        }

        // 교차 검증 — 규칙 파서와 크게 어긋나면 AI 결과를 버리고 규칙 결과를 쓴다
        // (온디바이스 소형 모델이 표 형식에서 숫자를 섞는 경우 방어)
        let levainWords = ["르방", "levain", "스타터", "starter", "발효종"]
        if input.flours.contains(where: { f in
            levainWords.contains { f.name.localizedCaseInsensitiveContains($0) }
        }) {
            throw ImportError.noIngredients(recognizedText: text)
        }
        let rules = RecipeTextParser.parse(text)
        if rules.matchedLineCount >= 3 {
            let aiWeight = computeStats(input).doughWeight
            let ruleWeight = computeStats(rules.input).doughWeight
            if abs(aiWeight - ruleWeight) > max(50, ruleWeight * 0.1) {
                throw ImportError.noIngredients(recognizedText: text)
            }
        }
        return ImportedRecipe(
            name: draft.name, input: input, engine: .appleIntelligence, recognizedText: text)
    }
    #endif
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
