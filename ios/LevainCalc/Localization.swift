import Foundation
import LevainCore
import Observation

/// 인앱 언어 설정 — 한국어(기본) / 영어.
/// UI 문자열은 한국어 원문을 키로 쓰고, 영어일 때만 테이블에서 치환한다.
/// 프랑스어 병기(levain liquide 등)는 언어와 무관하게 유지.

enum AppLanguage: String, CaseIterable {
    case ko
    case en

    var label: String {
        switch self {
        case .ko: return "한국어"
        case .en: return "English"
        }
    }
}

@Observable
final class Lang {
    static let shared = Lang()

    var current: AppLanguage {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appLanguage") }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "appLanguage"),
            let lang = AppLanguage(rawValue: raw)
        {
            current = lang
        } else {
            // 최초 실행: 시스템 언어를 따른다
            current = (Locale.preferredLanguages.first ?? "").hasPrefix("ko") ? .ko : .en
        }
    }
}

/// UI 문자열 치환 — 뷰 body 안에서 호출하면 언어 변경 시 자동 갱신된다 (Observation 추적)
func L(_ ko: String) -> String {
    guard Lang.shared.current == .en else { return ko }
    return en[ko] ?? ko
}

/// 포맷 템플릿 버전 (%d, %@)
func LF(_ ko: String, _ args: CVarArg...) -> String {
    String(format: L(ko), arguments: args)
}

private let en: [String: String] = [
    // 탭 · 공통
    "계산기": "Calculator",
    "변환": "Convert",
    "레시피": "Recipes",
    "저장": "Save",
    "취소": "Cancel",
    "닫기": "Close",
    "완료": "Done",
    "확인": "OK",
    "직접": "Custom",
    "이름": "Name",

    // 계산기
    "재료 입력": "Ingredients",
    "목표 역산": "From target",
    "레시피 이름": "Recipe name",
    "밀가루 (첨가)": "Flour (added)",
    "밀가루 이름 (T65, 호밀…)": "Flour name (T65, rye…)",
    "밀가루 추가": "Add flour",
    "%는 총 밀가루(첨가 + 르방 속) 기준입니다.": "Percentages are based on total flour (added + in levain).",
    "물 · 소금": "Water · Salt",
    "본반죽 물": "Mixing water",
    "바시나주": "Bassinage",
    "bassinage — 본반죽 후 추가하는 물": "bassinage — water added after mixing",
    "소금": "Salt",
    "르방": "Levain",
    "르방 종류": "Levain type",
    "리퀴드 100%": "Liquide 100%",
    "뒤흐 50%": "Dur 50%",
    "르방 무게": "Levain weight",
    "수분율": "Hydration",
    "르방 밀가루 (표시용)": "Levain flour (display only)",
    "속 밀가루": "Flour inside",
    "속 물": "Water inside",
    "%는 PFF — 총 밀가루 중 르방 속 밀가루의 비율.": "% is PFF — the share of total flour prefermented in the levain.",
    "액체 재료": "Liquids",
    "액체 재료 추가": "Add liquid",
    "수분": "water",
    "직접 입력": "Custom",
    "우유": "Milk",
    "계란": "Egg",
    "우유·계란 등 — 수분율만큼 총 물에 반영됩니다 (USDA 기준: 우유 88%, 계란 76%).":
        "Milk, eggs, etc. — counted toward total water by their water ratio (USDA: milk 88%, egg 76%).",
    "이스트 (선택)": "Yeast (optional)",
    "이스트 종류": "Yeast type",
    "생이스트": "Fresh yeast",
    "인스턴트": "Instant",
    "인스턴트 이스트": "Instant yeast",
    "투입량": "Amount",
    "= 인스턴트": "= instant",
    "= 생이스트": "= fresh",
    "인스턴트 = 생이스트 × 0.4. 무게·%에만 반영, 수분율 미반영.":
        "Instant = fresh × 0.4. Counts toward weight and % only, not hydration.",
    "기타 재료": "Other ingredients",
    "이름 (호두, 건포도…)": "Name (walnuts, raisins…)",
    "기타 재료 추가": "Add ingredient",
    "무게에만 합산되고 수분 계산에서 제외 — 수분이 있는 재료는 액체 재료로.":
        "Counted toward weight only, excluded from hydration — put moist ingredients under liquids.",
    "분할": "Dividing",
    "분할 개수 (0 = 사용 안 함)": "Pieces (0 = off)",
    "개": "pcs",
    "변환기로": "To converter",
    "입력 모드": "Input mode",

    // 모드 B
    "목표": "Target",
    "무게 입력": "Weight input",
    "총 반죽 무게": "Total dough weight",
    "개수 × 개당": "Pieces × each",
    "분할 개수": "Pieces",
    "개당 무게": "Weight per piece",
    "비율 (총 밀가루 기준)": "Ratios (of total flour)",
    "총 수분율": "Total hydration",
    "르방 수분율": "Levain hydration",
    "밀가루·물·소금·르방만 역산합니다. 바시나주·액체·이스트는 재료 입력 모드에서.":
        "Solves flour, water, salt, and levain only. Bassinage, liquids, and yeast live in ingredients mode.",
    "역산 결과": "Solved recipe",
    "첨가 밀가루": "Added flour",
    "르방 리퀴드": "Levain liquide",
    "르방 뒤흐": "Levain dur",
    "이 조합에서는 첨가 물이 음수(%@ g)가 됩니다. PFF를 낮추거나 총 수분율을 높이세요.":
        "Added water would be negative (%@ g). Lower PFF or raise total hydration.",
    "르방 속 밀가루가 총 밀가루를 초과합니다. PFF를 낮추세요.":
        "Flour in the levain exceeds total flour. Lower PFF.",

    // 결과 · 배합표
    "총 반죽": "Total dough",
    "개당": "Each",
    "재료": "Ingredients",
    "합계": "Totals",
    "총 밀가루": "Total flour",
    "총 물": "Total water",
    "배합표": "Formula",
    "기타": "Other",
    "액체": "Liquid",
    "밀가루": "Flour",
    "분할 %d개 — 개당": "Divide by %d — each",
    "%d개 × %@ g": "%d × %@ g",

    // 저장 시트
    "레시피 저장": "Save recipe",
    "태그 (쉼표로 구분)": "Tags (comma-separated)",
    "노트": "Notes",
    "불러온 레시피에 덮어쓰기": "Overwrite loaded recipe",

    // 변환기
    "르방 변환": "Levain conversion",
    "원본 배합": "Source recipe",
    "저장된 레시피 불러오기": "Load saved recipe",
    "현재 르방": "Current levain",
    "원본 직접 편집": "Edit source",
    "변환 설정": "Conversion settings",
    "변환 모드": "Conversion mode",
    "르방 질량 고정": "Fixed levain mass",
    "PFF 고정": "Fixed PFF",
    "르방 무게를 그대로 두고 첨가 밀가루·물을 조정합니다 — PFF(발효종 밀가루 비율)가 변합니다.":
        "Keeps the levain weight and adjusts added flour and water — PFF (prefermented flour) changes.",
    "발효종 밀가루 양(PFF)을 유지합니다 — 필요한 르방 무게가 달라지고, 첨가 물이 그만큼 조정됩니다.":
        "Keeps the prefermented flour (PFF) — the levain weight changes and mixing water compensates.",
    "목표 르방 수분율": "Target levain hydration",
    "밀가루 증감 배분": "Flour adjustment",
    "비례 배분": "Pro rata",
    "이름 없음": "Unnamed",
    "변환 결과 — 재료": "Result — ingredients",
    "지표": "Metrics",
    "변환 불가": "Cannot convert",
    "리퀴드": "liquide",
    "뒤흐": "dur",
    "르방 속 밀가루가 총 밀가루를 초과합니다.": "Flour in the levain exceeds total flour.",
    "본반죽 물이 부족해서 이 수분율로 변환할 수 없습니다.":
        "Not enough mixing water to convert to this hydration.",
    "지정한 밀가루가 부족합니다 (필요 %@ g, 보유 %@ g). 비례 배분을 선택하거나 다른 밀가루를 지정하세요.":
        "The selected flour is insufficient (needs %@ g, has %@ g). Use pro rata or pick another flour.",
    "최대 르방 질량 적용 — %@ g": "Apply max levain mass — %@ g",
    "ΔF = %@ g — 르방 속 밀가루 증감분을 첨가 밀가루에서 빼고 본반죽 물에 더했습니다.":
        "ΔF = %@ g — the change in levain flour was taken from added flour and added to mixing water.",

    // 레시피 탭
    "저장된 레시피가 없습니다": "No saved recipes",
    "계산기에서 배합을 만들고 저장하세요.": "Build a recipe in the calculator and save it.",
    "이름·태그 검색": "Search name or tags",
    "설정": "Settings",
    "JSON 내보내기": "Export JSON",
    "JSON 가져오기": "Import JSON",
    "가져오기/내보내기": "Import / Export",
    "가져오기 실패": "Import failed",
    "가져오기 완료": "Import complete",
    "%d개의 레시피를 가져왔습니다.": "Imported %d recipes.",
    "파일을 읽을 수 없습니다": "Could not read the file",
    "계산기로 불러오기": "Load into calculator",

    // 코어 검증 오류
    "레시피가 객체가 아닙니다": "The recipe is not an object",
    "지원하지 않는 schemaVersion입니다 (기대: 1 또는 2)": "Unsupported schemaVersion (expected 1 or 2)",
    "name이 비어 있습니다": "name is empty",
    "%@가 배열이 아닙니다": "%@ is not an array",
    "%@[%d]가 객체가 아닙니다": "%@[%d] is not an object",
    "%@[%d].grams가 0 이상의 숫자가 아닙니다": "%@[%d].grams is not a number ≥ 0",
    "liquids[%d].waterRatio가 0~1 사이의 소수가 아닙니다 (예: 0.88)":
        "liquids[%d].waterRatio is not a decimal between 0 and 1 (e.g. 0.88)",
    "yeast가 객체가 아닙니다": "yeast is not an object",
    "yeast.grams가 0 이상의 숫자가 아닙니다": "yeast.grams is not a number ≥ 0",
    "water가 0 이상의 숫자가 아닙니다": "water is not a number ≥ 0",
    "bassinage가 0 이상의 숫자가 아닙니다": "bassinage is not a number ≥ 0",
    "salt가 0 이상의 숫자가 아닙니다": "salt is not a number ≥ 0",
    "levain이 없습니다": "levain is missing",
    "levain.grams가 0 이상의 숫자가 아닙니다": "levain.grams is not a number ≥ 0",
    "levain.hydration이 0보다 큰 숫자가 아닙니다 (소수, 예: 1.0)":
        "levain.hydration is not a number > 0 (decimal, e.g. 1.0)",
    "JSON 파싱 실패: %@": "JSON parse failed: %@",
    "recipes 필드가 배열이 아닙니다": "The recipes field is not an array",
    "레시피 목록을 찾을 수 없습니다": "No recipe list found",
    "가져올 레시피가 없습니다": "No recipes to import",
    "%d번째 레시피: %@": "Recipe %d: %@",

    // AI 가져오기
    "AI로 가져오기": "Import with AI",
    "사진에서 가져오기": "From photo",
    "텍스트 붙여넣기": "Paste text",
    "텍스트에서 가져오기": "Import from text",
    "레시피 텍스트를 붙여넣으세요": "Paste your recipe text here",
    "분석": "Analyze",
    "인식 중…": "Recognizing…",
    "가져오기 확인": "Review import",
    "인식 결과를 확인·수정한 뒤 저장하세요.": "Review and edit the recognized recipe, then save.",
    "Apple Intelligence로 분석했습니다.": "Parsed with Apple Intelligence.",
    "규칙 기반으로 분석했습니다.": "Parsed with the built-in rule parser.",
    "인식된 원본 텍스트": "Recognized text",
    "가져온 레시피": "Imported recipe",
    "이미지를 읽을 수 없습니다": "Could not read the image",
    "이미지에서 텍스트를 찾지 못했습니다": "No text found in the image",
    "재료를 인식하지 못했습니다. 더 선명한 사진이나 정리된 텍스트로 다시 시도해 주세요.":
        "Could not recognize any ingredients. Try a clearer photo or tidier text.",

    // 설정
    "언어": "Language",
    "표시 자릿수": "Display precision",
    "내부 계산은 항상 full precision — 반올림은 표시에만 적용됩니다.":
        "Internal math is always full precision — rounding applies to display only.",
]

/// 코어 검증 오류 → 현재 언어 문구
extension CodecError {
    var localizedMessage: String {
        switch kind {
        case .notAnObject:
            return L("레시피가 객체가 아닙니다")
        case .unsupportedSchemaVersion:
            return L("지원하지 않는 schemaVersion입니다 (기대: 1 또는 2)")
        case .emptyName:
            return L("name이 비어 있습니다")
        case .fieldNotArray(let field):
            return LF("%@가 배열이 아닙니다", field)
        case .rowNotObject(let field, let index):
            return LF("%@[%d]가 객체가 아닙니다", field, index)
        case .rowGramsInvalid(let field, let index):
            return LF("%@[%d].grams가 0 이상의 숫자가 아닙니다", field, index)
        case .waterRatioInvalid(let index):
            return LF("liquids[%d].waterRatio가 0~1 사이의 소수가 아닙니다 (예: 0.88)", index)
        case .yeastNotObject:
            return L("yeast가 객체가 아닙니다")
        case .yeastGramsInvalid:
            return L("yeast.grams가 0 이상의 숫자가 아닙니다")
        case .waterInvalid:
            return L("water가 0 이상의 숫자가 아닙니다")
        case .bassinageInvalid:
            return L("bassinage가 0 이상의 숫자가 아닙니다")
        case .saltInvalid:
            return L("salt가 0 이상의 숫자가 아닙니다")
        case .levainMissing:
            return L("levain이 없습니다")
        case .levainGramsInvalid:
            return L("levain.grams가 0 이상의 숫자가 아닙니다")
        case .levainHydrationInvalid:
            return L("levain.hydration이 0보다 큰 숫자가 아닙니다 (소수, 예: 1.0)")
        case .jsonParse(let detail):
            return LF("JSON 파싱 실패: %@", detail)
        case .recipesFieldNotArray:
            return L("recipes 필드가 배열이 아닙니다")
        case .noRecipeList:
            return L("레시피 목록을 찾을 수 없습니다")
        case .emptyImport:
            return L("가져올 레시피가 없습니다")
        case .recipeAt(let index, let error):
            return LF("%d번째 레시피: %@", index, error.localizedMessage)
        }
    }
}
