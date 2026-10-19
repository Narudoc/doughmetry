import Foundation

/// 가져오기/검증 오류 — 구조화된 종류(kind)로 전달하고,
/// 사용자에게 보여줄 문구는 앱 계층에서 언어에 맞게 만든다.
/// `message`는 한국어 기본 문구 (로그·테스트·CLI용).
public struct CodecError: Error, Equatable, Sendable, CustomStringConvertible, LocalizedError {
    public indirect enum Kind: Equatable, Sendable {
        case notAnObject
        case unsupportedSchemaVersion
        case emptyName
        case fieldNotArray(field: String)
        case rowNotObject(field: String, index: Int)
        case rowGramsInvalid(field: String, index: Int)
        case waterRatioInvalid(index: Int)
        case yeastNotObject
        case yeastGramsInvalid
        case waterInvalid
        case bassinageInvalid
        case saltInvalid
        case levainMissing
        case levainGramsInvalid
        case levainHydrationInvalid
        case jsonParse(detail: String)
        case recipesFieldNotArray
        case noRecipeList
        case emptyImport
        case recipeAt(index: Int, error: CodecError)
    }

    public let kind: Kind

    public init(_ kind: Kind) { self.kind = kind }

    /// 한국어 기본 메시지
    public var message: String {
        switch kind {
        case .notAnObject:
            return "레시피가 객체가 아닙니다"
        case .unsupportedSchemaVersion:
            return "지원하지 않는 schemaVersion입니다 (기대: 1 또는 2)"
        case .emptyName:
            return "name이 비어 있습니다"
        case .fieldNotArray(let field):
            return "\(field)가 배열이 아닙니다"
        case .rowNotObject(let field, let index):
            return "\(field)[\(index)]가 객체가 아닙니다"
        case .rowGramsInvalid(let field, let index):
            return "\(field)[\(index)].grams가 0 이상의 숫자가 아닙니다"
        case .waterRatioInvalid(let index):
            return "liquids[\(index)].waterRatio가 0~1 사이의 소수가 아닙니다 (예: 0.88)"
        case .yeastNotObject:
            return "yeast가 객체가 아닙니다"
        case .yeastGramsInvalid:
            return "yeast.grams가 0 이상의 숫자가 아닙니다"
        case .waterInvalid:
            return "water가 0 이상의 숫자가 아닙니다"
        case .bassinageInvalid:
            return "bassinage가 0 이상의 숫자가 아닙니다"
        case .saltInvalid:
            return "salt가 0 이상의 숫자가 아닙니다"
        case .levainMissing:
            return "levain이 없습니다"
        case .levainGramsInvalid:
            return "levain.grams가 0 이상의 숫자가 아닙니다"
        case .levainHydrationInvalid:
            return "levain.hydration이 0보다 큰 숫자가 아닙니다 (소수, 예: 1.0)"
        case .jsonParse(let detail):
            return "JSON 파싱 실패: \(detail)"
        case .recipesFieldNotArray:
            return "recipes 필드가 배열이 아닙니다"
        case .noRecipeList:
            return "레시피 목록을 찾을 수 없습니다"
        case .emptyImport:
            return "가져올 레시피가 없습니다"
        case .recipeAt(let index, let error):
            return "\(index)번째 레시피: \(error.message)"
        }
    }

    public var description: String { message }
    public var errorDescription: String? { message }
}
