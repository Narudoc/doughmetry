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
    "캉파뉴": "Campagne",
    "새 배합": "New recipe",
    "새 배합을 시작할까요? 저장하지 않은 입력은 지워집니다.":
        "Start a new recipe? Unsaved input will be cleared.",
    "빈 배합으로 시작": "Start empty",
    "예시 배합으로 시작 (캉파뉴)": "Start from example (campagne)",
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
    "계산기 배합 가져오기": "Use calculator dough",
    "불러오기": "Load",
    "저장된 레시피": "Saved recipes",
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

    // 베이킹 로그 · 노트
    "노트 추가": "Add a note",
    "노트 편집": "Edit note",
    "배합 메모, 발효 시간, 결과 등을 적어두세요": "Notes on the formula, fermentation times, results…",
    "베이킹 로그": "Bake log",
    "기록 추가": "Add bake",
    "기록 편집": "Edit bake",
    "구운 날짜": "Baked on",
    "별점": "Rating",
    "메모": "Notes",
    "이 레시피로 구운 날짜·별점·메모를 남겨 다음 굽기에 참고하세요.":
        "Log each bake — date, rating, notes — to refer to next time.",
    "%d회 구움 · 최근 %@": "Baked %d× · last %@",

    "삭제된 레시피": "Recipe deleted",
    "이 레시피는 다른 기기에서 삭제되었습니다.": "This recipe was deleted on another device.",
    "없음": "None",

    // iCloud
    "iCloud 동기화": "iCloud sync",
    "상태": "Status",
    "확인 중…": "Checking…",
    "사용 불가 — iCloud 로그인 또는 앱 권한 필요": "Unavailable — sign in to iCloud or app lacks permission",
    "꺼짐": "Off",
    "동기화 중…": "Syncing…",
    "마지막 동기화 %@": "Last synced %@",
    "대기 중": "Ready",
    "레시피·베이킹 로그를 iCloud로 기기 간 동기화합니다. 충돌 시 최신 수정본이 유지됩니다.":
        "Syncs recipes and bake logs across your devices via iCloud. On conflict, the most recent edit wins.",

    // 도구 탭
    "도구": "Tools",
    "르방 빌드 계산기": "Levain build",
    "필요한 르방을 종 + 밀가루 + 물로 역산": "Work back from the levain you need to chef + flour + water",
    "물 온도 계산기": "Water temperature",
    "목표 반죽 온도(DDT)에 맞는 물 온도": "Water temp for your desired dough temperature (DDT)",
    "타임라인": "Timeline",
    "오토리즈부터 굽기까지 단계별 시각 + 알림": "Stage-by-stage times from autolyse to bake, with alerts",
    "필요한 르방": "Levain needed",
    "계산기 배합에서 가져오기": "Use levain from calculator",
    "종 입력": "Chef input",
    "르방 대비 %": "% of levain",
    "그램": "grams",
    "종 비율": "Chef ratio",
    "종 무게": "Chef weight",
    "종 수분율 = 르방과 같음": "Chef hydration = same as levain",
    "종 수분율": "Chef hydration",
    "종": "Chef",
    "종은 이전 르방(스타터)에서 남긴 씨앗입니다. 보통 르방 무게의 10~20%.":
        "The chef is the seed kept from your previous levain — typically 10–20% of the levain weight.",
    "물": "Water",
    "비율 (종 : 밀가루 : 물)": "Ratio (chef : flour : water)",
    "리프레시 배합": "Refresh formula",
    "종을 밀가루·물과 섞어 발효시키면 목표 무게·수분율의 르방이 됩니다.":
        "Mix the chef with this flour and water; once fermented you have the levain at the target weight and hydration.",
    "계산 불가": "Cannot compute",
    "종이 너무 많습니다 — 밀가루나 물이 음수가 됩니다.": "Too much chef — flour or water would be negative.",
    "최대 종 적용 — %@ g": "Use max chef — %@ g",
    "목표 반죽 온도 (DDT)": "Desired dough temp (DDT)",
    "사워도우는 보통 24~26°C. 벌크 발효 속도를 좌우하는 가장 중요한 변수입니다.":
        "Sourdough is usually 24–26 °C. It's the biggest lever on bulk fermentation speed.",
    "현재 온도": "Current temperatures",
    "실온": "Room",
    "르방 사용": "Using levain",
    "마찰계수": "Friction factor",
    "손반죽": "By hand",
    "스탠드 믹서": "Stand mixer",
    "믹싱 마찰로 오르는 온도. 손반죽 1~2°C, 스탠드 믹서 6~10°C — 본인 환경에 맞게 조정하세요.":
        "Heat added by mixing. Hand ≈ 1–2 °C, stand mixer ≈ 6–10 °C — tune to your setup.",
    "사용할 물 온도": "Water temperature to use",
    "얼음물이 필요합니다 — 얼음을 넣어 물 온도를 맞추세요.": "You'll need iced water — add ice to hit this temperature.",
    "너무 뜨겁습니다 — 40°C 이상은 르방 활성을 해칠 수 있습니다.": "Too hot — above 40 °C can harm the levain.",
    "결과": "Result",
    "물 온도 = DDT × 4 − (밀가루 + 실온 + 르방 + 마찰계수)": "Water = DDT × 4 − (flour + room + levain + friction)",
    "물 온도 = DDT × 3 − (밀가루 + 실온 + 마찰계수)": "Water = DDT × 3 − (flour + room + friction)",

    // 타임라인
    "르방 빌드": "Levain build",
    "오토리즈": "Autolyse",
    "믹싱": "Mix",
    "벌크 발효": "Bulk fermentation",
    "벤치 타임": "Bench rest",
    "성형": "Shaping",
    "최종 발효": "Final proof",
    "냉장 발효": "Cold retard",
    "굽기": "Bake",
    "사용자 단계": "Custom stage",
    "다음 단계: %@": "Next: %@",
    "완성! 빵을 꺼낼 시간": "Done — time to take the bread out",
    "%@ 끝": "%@ finished",
    "기준": "Anchor",
    "시작 시각": "Start time",
    "완성 시각": "Finish time",
    "빵이 완성될 시각": "Bread ready at",
    "첫 단계 시작": "First stage starts",
    "지금 시작": "Start now",
    "총 소요": "Total time",
    "일정": "Schedule",
    "단계": "Stages",
    "분": "min",
    "단계 추가": "Add stage",
    "길게 눌러 순서를 바꾸고, 밀어서 삭제합니다. 냉장 발효는 12시간(720분)이 기본입니다.":
        "Drag to reorder, swipe to delete. Cold retard defaults to 12 h (720 min).",
    "단계 알림 예약": "Schedule stage alerts",
    "예약된 알림": "Scheduled alerts",
    "%d개": "%d",
    "알림 취소": "Cancel alerts",
    "각 단계가 끝나는 시각에 다음 단계 알림이 옵니다. 앱을 닫아도 울립니다.":
        "You'll be notified when each stage ends, even with the app closed.",
    "알림 권한이 꺼져 있습니다": "Notifications are off",
    "설정 앱 → 알림에서 이 앱의 알림을 허용해 주세요.": "Allow notifications for this app in Settings → Notifications.",
    "내일": "Tomorrow",
    "%d시간 %d분": "%dh %dm",
    "%d분": "%d min",

    // 설정
    "언어": "Language",
    "% 표기": "Percent display",
    "총 밀가루 기준": "Of total flour",
    "베이커스 퍼센트": "Baker's %",
    "표시만 바뀝니다 — 계산과 총 수분율·PFF는 항상 총 밀가루 기준입니다.":
        "Display only — calculations, total hydration, and PFF always use total flour.",
    "%는 첨가 밀가루 기준(베이커스 퍼센트)입니다.": "Percentages are baker's % — of added flour.",
    "%는 첨가 밀가루 대비 르방 무게입니다.": "% is levain weight relative to added flour.",
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
