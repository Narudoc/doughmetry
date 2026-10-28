import Foundation
import DoughmetryCore
import Observation
import SwiftUI

/// 인앱 언어 설정 — 한국어(기본) / 영어.
/// UI 문자열은 한국어 원문을 키로 쓰고, 영어일 때만 테이블에서 치환한다.
/// 주 라벨은 UI 언어의 제빵 용어로 쓴다 (영어: liquid/stiff levain, starter). 프랑스어 원어는
/// 언어와 무관하게 BilingualLabel의 이탤릭 병기로만 붙인다.

enum AppLanguage: String, CaseIterable {
    case ko
    case en

    /// "ko-KR", "en_GB" 같은 언어 태그 → 앱 언어 (한·영 외는 nil)
    init?(languageTag: String) {
        self.init(rawValue: String(languageTag.prefix { $0 != "-" && $0 != "_" }).lowercased())
    }

    var label: String {
        switch self {
        case .ko: return "한국어"
        case .en: return "English"
        }
    }

    /// 날짜·시각 서식과 DatePicker의 로캘. 시스템 로캘(Locale.current)은 앱 언어를 모른다.
    /// 언어가 같으면 기기 로캘을 그대로 써서 지역 서식·24시간제 설정을 살리고, 다르면 언어만 바꾼다
    var locale: Locale {
        let device = Locale.autoupdatingCurrent
        if device.language.languageCode?.identifier == rawValue { return device }
        return Locale(languageCode: Locale.LanguageCode(rawValue), languageRegion: device.region)
    }
}

@Observable
final class Lang {
    // 읽기·쓰기는 전부 메인 스레드다 — 뷰 body, @MainActor인 TimelineNotifier, 설정 화면의 Picker.
    // TimelineNotifier.followLanguage의 onChange 클로저는 Lang을 읽지 않고 메인 액터 Task로 넘긴다.
    // Lang을 @MainActor로 바꾸지 말 것 — L()/LF()를 부르는 비격리 함수(stageName, flourLabel, fmtTime,
    // CodecError.localizedMessage, CalcState.name 기본값 등)가 컴파일되지 않는다
    nonisolated(unsafe) static let shared = Lang()

    var current: AppLanguage {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(current.rawValue, forKey: "appLanguage")
            // 앱 도메인의 AppleLanguages = iOS의 앱별 언어. 검색 취소·사진 선택처럼 UIKit이 그리는
            // 문자열은 이것만 따르고, 다음 실행부터 적용된다. 공유 시트의 활동 이름(미리 알림·더 보기·
            // 파일에 저장)은 시스템이 기기 언어로 채워 이것으로도 바뀌지 않는다
            defaults.set([current.rawValue], forKey: "AppleLanguages")
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        // 인앱 선택은 AppleLanguages에도 같이 쓰므로, 둘이 다르면 그 뒤에 iOS 설정 → 앱 → 언어에서 바꾼 것이다.
        // 영속 도메인끼리만 비교한다 — 실행 인자(-appLanguage)는 저장값을 바꾸지 않아야 한다
        if let domain = Bundle.main.bundleIdentifier.flatMap(defaults.persistentDomain(forName:)),
            let saved = domain["appLanguage"] as? String,
            let picked = (domain["AppleLanguages"] as? [String])?.first.flatMap(AppLanguage.init(languageTag:)),
            picked.rawValue != saved
        {
            defaults.set(picked.rawValue, forKey: "appLanguage")
        }
        if let raw = defaults.string(forKey: "appLanguage"),
            let lang = AppLanguage(rawValue: raw)
        {
            current = lang
        } else {
            // 최초 실행: iOS가 번들에 고른 현지화를 따른다 — 시스템이 그리는 문자열(편집·취소·삭제 등)과
            // 같은 언어가 되도록. developmentRegion(en)과 한 쌍이다: 그것이 ko면 한/영 외 기기가 한국어가 된다
            current = Bundle.main.preferredLocalizations.first == "ko" ? .ko : .en
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

/// 개수 템플릿 (%d 하나) — 영어는 1일 때 단수형(enOne)을 쓴다. 한국어는 단·복수 형태가 같다
func LF(_ ko: String, count: Int) -> String {
    if Lang.shared.current == .en, count == 1, let one = enOne[ko] {
        return String(format: one, count)
    }
    return LF(ko, count)
}

/// 밀가루 행 이름. 목표 역산이 붙이는 이름 "밀가루"(기존 저장본·웹 JSON 포함)도 빈 이름처럼 현재 언어로 보인다
func flourLabel(_ flour: Flour) -> String {
    flour.name.isEmpty || flour.name == "밀가루" ? L("밀가루") : flour.name
}

/// 시각 (오전 7:30 / 7:30 AM) — `Date.formatted()`의 기본 로캘은 앱 언어가 아니라 기기 로캘이다
func fmtTime(_ date: Date) -> String {
    date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Lang.shared.current.locale))
}

/// 월·일 (9. 27. / 9/27)
func fmtMonthDay(_ date: Date) -> String {
    date.formatted(Date.FormatStyle.dateTime.month(.defaultDigits).day().locale(Lang.shared.current.locale))
}

/// EditButton 대체 — 시스템 EditButton의 "편집/완료"는 앱 언어가 아니라 번들 현지화를 따른다
struct LocalizedEditButton: View {
    @Environment(\.editMode) private var editMode

    var body: some View {
        let isEditing = editMode?.wrappedValue.isEditing == true
        Button {
            withAnimation { editMode?.wrappedValue = isEditing ? .inactive : .active }
        } label: {
            // 탭 영역은 레이블 안에서 넓힌다 — Button 바깥의 frame은 탭·접근성 영역을 늘리지 못한다
            Text(isEditing ? L("완료") : L("편집"))
                // 섹션 머리글 안에서 iOS 17·18이 대문자(EDIT)로 바꾸지 않게
                .textCase(nil)
                .frame(minWidth: 44, minHeight: 36, alignment: .trailing)
                .contentShape(Rectangle())
        }
    }
}

private let enOne: [String: String] = [
    "%d개의 레시피를 가져왔습니다.": "Imported %d recipe.",
    "아직 합치지 못한 충돌 사본 %d개를 iCloud에 그대로 보관 중입니다 — 이번에 읽지 못했거나 일부 항목이 손상된 사본이라 지우지 않습니다.":
        "Keeping %d conflicting copy in iCloud that hasn't been merged — it couldn't be read this time or is partly damaged, so it isn't deleted.",
]

private let en: [String: String] = [
    // 탭 · 공통
    "계산기": "Calculator",
    "변환": "Convert",
    "레시피": "Recipes",
    "레시피 검색": "Search Recipes",
    "저장": "Save",
    "취소": "Cancel",
    "닫기": "Close",
    "완료": "Done",
    "편집": "Edit",
    "변경 사항을 버릴까요?": "Discard changes?",
    "버리기": "Discard",
    "계속 편집": "Keep Editing",
    "삭제": "Delete",
    "확인": "OK",
    "직접": "Custom",
    "이름": "Name",

    // 계산기
    "재료 입력": "Ingredients",
    "목표 역산": "From target",
    "레시피 이름": "Recipe name",
    "밀가루 (첨가)": "Flour (added)",
    "밀가루 이름 (T65, 호밀…)": "Flour name (T65, rye…)",
    "밀가루 (T65…)": "Flour (T65…)",
    "밀가루 추가": "Add flour",
    "%는 총 밀가루(첨가 + 르방 속) 기준입니다.": "Percentages are based on total flour (added + in levain).",
    "총 밀가루의 %@": "%@ of total flour",
    "첨가 밀가루의 %@": "%@ of added flour",
    "PFF %@ — 총 밀가루 중 르방 속 밀가루": "PFF %@, flour in levain over total flour",
    "르방, 첨가 밀가루의 %@": "Levain, %@ of added flour",
    "물 · 소금": "Water · Salt",
    "본반죽 물": "Mixing water",
    "바시나주": "Bassinage",
    "bassinage — 본반죽 후 추가하는 물": "bassinage — water added after mixing",
    "소금": "Salt",
    "르방": "Levain",
    "르방 종류": "Levain type",
    "리퀴드 100%": "Liquid 100%",
    "뒤흐 50%": "Stiff 50%",
    "르방 무게": "Levain weight",
    "수분율": "Hydration",
    "르방 밀가루 (표시용)": "Levain flour type (label only)",
    "속 밀가루": "Flour in levain",
    "속 물": "Water in levain",
    "%는 PFF — 총 밀가루 중 르방 속 밀가루의 비율.": "% is PFF — the share of total flour prefermented in the levain.",
    "액체 재료": "Liquids",
    "액체 재료 추가": "Add liquid",
    "수분": "water",
    "직접 입력": "Custom",
    "우유": "Milk",
    "계란": "Egg",
    "수분 함량": "Water content",
    "%@ 수분 함량": "%@ water content",
    "액체 재료 이름": "Liquid name",
    "우유·계란 등 — 수분율만큼 총 물에 반영됩니다 (USDA 기준: 우유 88%, 계란 76%).":
        "Milk, eggs, etc. — counted toward total water by their water content (USDA: milk 88%, egg 76%).",
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
    "재료 (호두…)": "Item (nuts…)",
    "기타 재료 추가": "Add ingredient",
    "무게에만 합산되고 수분 계산에서 제외 — 수분이 있는 재료는 액체 재료로.":
        "Counted toward weight only, excluded from hydration — put moist ingredients under liquids.",
    "분할": "Divide",
    "0이면 분할하지 않습니다.": "0 = no dividing",
    "배율 조정": "Scale recipe",
    "배율": "Factor",
    "절반으로 (×½)": "Halve (×½)",
    "두 배로 (×2)": "Double (×2)",
    "적용": "Apply",
    "지금 총 반죽은 %@ g입니다. 모든 재료를 같은 배율로 늘리거나 줄여 수분율·소금·PFF는 그대로입니다.":
        "The dough is now %@ g. Every ingredient is scaled by the same factor, so hydration, salt and PFF stay the same.",
    "개": "pcs",
    "캉파뉴": "Campagne",
    "새 배합": "New recipe",
    "새 배합을 시작할까요? 저장하지 않은 입력은 지워집니다.":
        "Start a new recipe? Unsaved input will be cleared.",
    "레시피를 불러올까요? 저장하지 않은 입력은 지워집니다.": "Load this recipe? Unsaved input will be cleared.",
    "빈 배합으로 시작": "Start empty",
    "예시 배합으로 시작 (캉파뉴)": "Start from example (campagne)",
    "입력 모드": "Input mode",
    "새 배합 시작": "Start a new recipe",
    "이 배합으로 르방 변환": "Convert this dough's levain",
    "레시피를 덮어썼습니다": "Recipe overwritten",
    "'%@' 레시피를 저장했습니다": "Saved '%@'",
    "전체 배합표를 엽니다": "Opens the full formula",
    "총 수분율 %@, 총 반죽 %@그램": "Total hydration %@, total dough %@ grams",
    "밀가루 %@그램, 물 %@그램, 소금 %@그램, 르방 %@그램": "Flour %@ grams, water %@ grams, salt %@ grams, levain %@ grams",
    "'%@' 레시피를 불러왔습니다": "Loaded '%@'",
    "예시 배합": "Example dough",
    "새 배합 · 저장 안 됨": "New dough · not saved",
    "저장된 레시피 · 변경 없음": "Saved recipe · no changes",
    "수정됨 — 저장 안 됨": "Edited — not saved",
    "'%@'을(를) 계산기로 보냈습니다": "Sent '%@' to the calculator",

    // 레시피 불러오기 (계산기·변환기)
    "레시피 불러오기": "Load recipe",
    "이름·태그 검색": "Search name or tag",
    "최근": "Recent",
    "전체 (가나다순)": "All (A–Z)",
    "검색 결과": "Results",

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
    "르방 리퀴드": "Liquid levain",
    "르방 뒤흐": "Stiff levain",
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
    "분할 %@개 — 개당": "Divide by %@ — each",
    "공유": "Share",
    "%@그램": "%@ grams",
    "총 수분율 = 총 물 ÷ 총 밀가루. 총 물에는 본반죽 물·바시나주·르방 속 물·액체 재료의 수분이 모두 들어가서, 본반죽 물 ÷ 밀가루로 적은 레시피의 수분율보다 높게 나옵니다.":
        "Total hydration = total water ÷ total flour. Total water includes mixing water, bassinage, the levain's water and the water in liquids, so it reads higher than recipes that quote water ÷ flour.",
    "용어 설명": "Glossary",
    "총 물 ÷ 총 밀가루. 총 물 = 본반죽 물 + 바시나주 + 르방 속 물 + 액체 재료의 수분.":
        "Total water ÷ total flour. Total water = mixing water + bassinage + the levain's water + the water in liquids.",
    "르방 속 밀가루 ÷ 총 밀가루 — 미리 발효된 밀가루의 비율.":
        "Flour in the levain ÷ total flour — the share of flour that is prefermented.",
    "수분율 100% 안팎의 르방 (밀가루 1 : 물 1). 75% 이상이면 리퀴드로 봅니다.":
        "A levain at about 100% hydration (flour 1 : water 1). 75% and above counts as liquid.",
    "수분율 50% 안팎의 단단한 르방 (밀가루 1 : 물 0.5). 75% 미만이면 뒤흐로 봅니다.":
        "A stiff levain at about 50% hydration (flour 1 : water 0.5). Below 75% counts as stiff.",
    "본반죽을 섞은 뒤 나눠 넣는 물. 총 물과 총 수분율에 들어갑니다.":
        "Water added in stages after the main mix. It counts toward total water and total hydration.",

    // 저장 시트
    "레시피 저장": "Save recipe",
    "태그 (쉼표로 구분)": "Tags (comma-separated)",
    "노트": "Notes",
    "덮어쓰기": "Overwrite",
    "'%@' 레시피를 바꿉니다": "Replaces '%@'",
    "'%@' 레시피를 바꾸고 이름을 '%@'(으)로 고칩니다": "Replaces '%@' and renames it '%@'",
    "새 레시피로 저장": "Save as new recipe",
    "원래 레시피는 그대로 둡니다": "Leaves the original recipe unchanged",

    // 변환기
    "르방 변환": "Levain conversion",
    "원본 배합": "Source recipe",
    "저장된 레시피 불러오기": "Load saved recipe",
    "계산기 배합 가져오기": "Use calculator dough",
    "계산기 배합을 가져왔습니다": "Loaded the calculator dough",
    "불러오기": "Load",
    "저장된 레시피": "Saved recipes",
    "현재 르방": "Current levain",
    "원본 직접 편집": "Edit source",
    "펼침": "Expanded",
    "접힘": "Collapsed",
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
    "변환 결과 — 재료 (g)": "Result — ingredients (g)",
    "지표": "Metrics",
    "변환 불가": "Cannot convert",
    "리퀴드": "liquid",
    "뒤흐": "stiff",
    "르방 속 밀가루가 총 밀가루를 초과합니다.": "Flour in the levain exceeds total flour.",
    "본반죽 물이 부족해서 이 수분율로 변환할 수 없습니다.":
        "Not enough mixing water to convert to this hydration.",
    "지정한 밀가루가 부족합니다 (필요 %@ g, 보유 %@ g). 비례 배분을 선택하거나 다른 밀가루를 지정하세요.":
        "The selected flour is insufficient (needs %@ g, has %@ g). Use pro rata or pick another flour.",
    "최대 르방 질량 적용 — %@ g": "Apply max levain mass — %@ g",
    "ΔF = %@ g — 르방 속 밀가루 증감분을 첨가 밀가루에서 빼고 본반죽 물에 더했습니다.":
        "ΔF = %@ g — the change in levain flour was taken from added flour and added to mixing water.",
    "목표 조합이 불가능합니다 — 계산기에서 PFF를 낮추세요":
        "This target combination is impossible — lower PFF in the calculator",
    "예시 배합입니다 — 내 배합을 변환하려면 불러오세요": "This is a sample formula — load your own to convert it",
    "변환 결과로 이동합니다": "Scrolls to the conversion result",
    "변환 결과를 새 레시피로 저장했습니다": "Saved the conversion as a new recipe",
    "계산기로 보내기": "Send to Calculator",
    "배합표 공유": "Share formula",
    "변환 결과를 계산기로 보낼까요? 계산기에 저장하지 않은 입력은 지워집니다.":
        "Send the conversion to the calculator? Unsaved input in the calculator will be cleared.",
    "%@그램에서 %@그램으로": "%@ grams to %@ grams",
    "변화 없음": "no change",
    "%@에서 %@로": "%@ to %@",
    "보존됨": "preserved",

    // 레시피 탭
    "저장된 레시피가 없습니다": "No saved recipes",
    "사진·텍스트에서 레시피를 가져오거나 계산기에서 만든 배합을 저장하세요. 저장한 레시피에는 굽기마다 날짜·별점·메모를 남길 수 있습니다.":
        "Import a recipe from a photo or text, or save one you build in the calculator. Each saved recipe keeps a bake log with the date, rating and notes of every bake.",
    "이름·메모·태그 검색": "Search name, notes or tags",
    "'%@'에 대한 결과 없음": "No results for '%@'",
    "철자를 확인하거나 다른 검색어로 찾아보세요.": "Check the spelling or try a different search.",
    "레시피를 고르세요": "Select a recipe",
    "왼쪽 목록에서 레시피를 고르면 배합표와 베이킹 로그가 여기에 보입니다.":
        "Choose a recipe from the list to see its formula and bake log here.",
    "설정": "Settings",
    "JSON 내보내기": "Export JSON",
    "JSON 가져오기": "Import JSON",
    "더 보기": "More",
    "가져오기 실패": "Import failed",
    "가져오기 완료": "Import complete",
    "%d개의 레시피를 가져왔습니다.": "Imported %d recipes.",
    "%d개를 가져왔고, %d개는 이미 있는 버전이라 건너뛰었습니다.":
        "Imported %d; skipped %d already on this device.",
    "가져오는 중 오류가 발생했습니다. 다시 시도해 주세요.": "Something went wrong while importing. Please try again.",
    "'%@' 레시피를 삭제할까요?": "Delete the recipe '%@'?",
    "베이킹 기록 %d개도 함께 삭제되며 되돌릴 수 없습니다.":
        "This recipe's bake logs (%d) will also be deleted. This can't be undone.",
    "되돌릴 수 없습니다.": "This can't be undone.",
    "파일을 읽을 수 없습니다": "Could not read the file",
    "계산기로 불러오기": "Load into calculator",
    "계산기로 가기": "Go to Calculator",
    "예시 레시피 추가": "Add sample recipes",
    "예시": "Sample",
    "팽 드 캉파뉴": "Pain de campagne",
    "팽 콩플레 (통밀빵)": "Pain complet (whole wheat)",
    "바게트 오 르방": "Baguette au levain",
    "브리오슈 오 르방": "Brioche au levain",
    "버터": "Butter",
    "설탕": "Sugar",
    "정렬": "Sort",
    "최근 수정": "Recently edited",
    "최근 구움": "Recently baked",
    "총 수분율 %@": "Total hydration %@",
    "총 반죽 %@": "Dough %@",
    "르방 %@": "Levain %@",
    "태그 %@": "Tags %@",
    "수정 %@": "Updated %@",
    "구운 횟수 %d, 최근 %@": "Bakes %d, last %@",
    "기록 모두 보기 (%d)": "All bakes (%d)",
    "변환기로 보내기": "Send to Converter",
    "배합표 텍스트": "Formula as text",
    "레시피 파일": "Recipe file",
    "%@ 사본": "%@ copy",
    "복제": "Duplicate",
    "삭제…": "Delete…",
    "레시피 편집": "Edit recipe",
    "이름·태그·노트 편집": "Edit name, tags and notes",

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
    "JSON 파싱 실패 — 올바른 JSON 파일이 아닙니다": "JSON parse failed — this is not a valid JSON file",
    "recipes 필드가 배열이 아닙니다": "The recipes field is not an array",
    "레시피 목록을 찾을 수 없습니다": "No recipe list found",
    "가져올 레시피가 없습니다": "No recipes to import",
    "%d번째 레시피: %@": "Recipe %d: %@",

    // 사진·텍스트 가져오기
    "사진·텍스트에서 가져오기": "Import from photo or text",
    "가져오기": "Import",
    "사진에서 가져오기": "From photo",
    "텍스트 붙여넣기": "Paste text",
    "텍스트에서 가져오기": "Import from text",
    "레시피 텍스트를 붙여넣으세요": "Paste your recipe text here",
    "분석": "Analyze",
    "인식 중…": "Recognizing…",
    "텍스트 인식 중…": "Reading text…",
    "Apple Intelligence로 분석 중…": "Analyzing with Apple Intelligence…",
    "규칙 결과로 보기": "Use rule-based result",
    "붙여넣고 분석": "Paste and analyze",
    "가져오기 확인": "Review import",
    "인식 결과를 확인·수정한 뒤 저장하세요.": "Review and edit the recognized recipe, then save.",
    "Apple Intelligence로 분석했습니다.": "Parsed with Apple Intelligence.",
    "규칙 기반으로 분석했습니다.": "Parsed with the built-in rule parser.",
    "AI 결과가 규칙 분석과 달라 규칙 기반 결과를 표시합니다 — 물·르방 값을 확인하세요":
        "The AI result didn't match the rule-based parse, so the rule-based result is shown — check the water and levain values.",
    "본반죽 물이 0 g이고 바시나주만 있습니다 — 원본 텍스트와 대조하세요":
        "Mixing water is 0 g and only bassinage is set — compare with the original text.",
    "바시나주가 본반죽 물보다 많습니다": "Bassinage is more than the mixing water.",
    "만드는 법은 노트로 저장됩니다": "The method is saved as the recipe's notes.",
    "원본 텍스트를 노트에 넣기": "Put the original text in notes",
    "인식된 원본 텍스트": "Recognized text",
    "가져온 레시피": "Imported recipe",
    "이미지를 읽을 수 없습니다": "Could not read the image",
    "이미지에서 텍스트를 찾지 못했습니다": "No text found in the image",
    "재료를 인식하지 못했습니다. 재료와 g 수량이 줄 단위로 적힌 텍스트가 필요합니다.":
        "Could not recognize any ingredients. The text needs one ingredient per line with its amount in grams.",
    "텍스트 편집": "Edit text",

    // 베이킹 로그 · 노트
    "노트 추가": "Add a note",
    "노트 편집": "Edit note",
    "배합 메모, 발효 시간, 결과 등을 적어두세요": "Notes on the formula, fermentation times, results…",
    "베이킹 로그": "Bake log",
    "기록 추가": "Add bake",
    "기록 편집": "Edit bake",
    "구운 날짜": "Baked on",
    "별점": "Rating",
    "별 5개 중 %d개": "%d of 5 stars",
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
    "동기화하지 못했습니다 (%@) — 다음에 다시 시도합니다": "Sync failed (%@) — will try again later",
    "iCloud에서 라이브러리를 내려받는 중입니다 — 끝나면 동기화합니다":
        "Downloading your library from iCloud — will sync when it finishes",
    "iCloud에서 라이브러리를 내려받지 못했습니다 — 네트워크와 iCloud 저장 공간을 확인하세요. 다시 시도합니다":
        "Couldn't download your library from iCloud — check your network and iCloud storage. Will try again",
    "iCloud에 연결하지 못해 동기화를 미뤘습니다 — 연결되면 다시 시도합니다":
        "Couldn't reach iCloud, so sync was postponed — will try again when connected",
    "아직 합치지 못한 충돌 사본 %d개를 iCloud에 그대로 보관 중입니다 — 이번에 읽지 못했거나 일부 항목이 손상된 사본이라 지우지 않습니다.":
        "Keeping %d conflicting copies in iCloud that haven't been merged — they couldn't be read this time or are partly damaged, so they aren't deleted.",
    "새 버전 앱에서 저장한 데이터가 있습니다 — 이 기기의 앱을 업데이트하면 동기화됩니다":
        "Some data was saved by a newer version of the app — update the app on this device to sync",
    "기기에 저장하지 못했습니다 — 저장 공간을 확인하세요": "Couldn't save to this device — check your storage space",

    // 도구 탭
    "도구": "Tools",
    "르방 빌드 계산기": "Levain build",
    "필요한 르방을 종 + 밀가루 + 물로 역산": "Starter, flour and water to build the levain you need",
    "물 온도 계산기": "Water temperature",
    "목표 반죽 온도(DDT)에 맞는 물 온도": "Water temp for your desired dough temperature (DDT)",
    "타임라인": "Timeline",
    "르방 빌드부터 굽기까지 단계별 시각 + 알림": "Times for each stage, from levain build to bake, with alerts",
    // 줄바꿈 없는 공백으로 '·'를 앞 낱말에 붙인다 — 좁은 iPhone에서 둘째 줄이 '· iCloud'로 시작하지 않게
    "언어 · % 표기 · 표시 자릿수 · iCloud": "Language\u{00A0}· Percent display\u{00A0}· Precision\u{00A0}· iCloud",
    "필요한 르방": "Levain needed",
    "계산기 배합에서 가져오기": "Use levain from calculator",
    "종 입력": "Starter amount",
    "르방 대비 %": "% of levain",
    "그램": "Grams",
    "종 비율": "Starter %",
    "종 무게": "Starter weight",
    "종 수분율 = 르방과 같음": "Starter hydration = levain",
    "종 수분율": "Starter hydration",
    "종": "Starter",
    "종은 이전 르방(스타터)에서 남긴 씨앗입니다. 보통 르방 무게의 10~20%.":
        "The starter (chef) is the seed kept from your last levain — typically 10–20% of the levain weight.",
    "물": "Water",
    "비율 (종 : 밀가루 : 물)": "Ratio (starter : flour : water)",
    "리프레시 배합": "Refresh formula",
    "종을 밀가루·물과 섞어 발효시키면 목표 무게·수분율의 르방이 됩니다.":
        "Mix the starter with this flour and water; once fermented you have the levain at the target weight and hydration.",
    "계산 불가": "Cannot compute",
    "종이 너무 많습니다 — 밀가루나 물이 음수가 됩니다.": "Too much starter — flour or water would be negative.",
    "최대 종 적용 — %@ g": "Use max starter — %@ g",
    "타임라인에 르방 빌드 넣기 — 피크 알림": "Add levain build to timeline — peak alert",
    "완성 시각 기준이면 르방 빌드만큼 시작이 앞당겨져 르방을 먹일 시각이 나옵니다. 시작 시각 기준이면 이후 단계가 그만큼 뒤로 밀립니다.":
        "With a finish time, the start moves earlier by the levain build, showing when to feed the levain. With a start time, every later stage shifts back by that much.",
    "목표 반죽 온도 (DDT)": "Desired dough temp (DDT)",
    "온도 단위": "Temperature unit",
    "사워도우는 보통 %d~%d%@. 벌크 발효 속도를 좌우하는 가장 중요한 변수입니다.":
        "Sourdough is usually %d–%d %@. It's the biggest lever on bulk fermentation speed.",
    "현재 온도": "Current temperatures",
    "실온": "Room",
    "르방 사용": "Dough includes levain",
    "마찰계수": "Friction factor",
    "손반죽": "By hand",
    "믹서": "Mixer",
    "공식에 넣는 마찰 값 — 실제 반죽 상승 온도의 3~4배. 손반죽 %d~%d%@, 믹서(스탠드·버티컬·스파이럴) %d~%d%@. 오래·빠르게 칠수록 높게 잡으세요.":
        "The friction value for this formula — 3–4× the dough's actual rise. Hand %d–%d %@, mixer (stand, vertical or spiral) %d–%d %@. Use more for longer or faster mixing.",
    "사용할 물 온도": "Water temperature to use",
    "얼음물이 필요합니다 — 얼음을 넣어 물 온도를 맞추세요.": "You'll need iced water — add ice to hit this temperature.",
    "너무 뜨겁습니다 — %d%@ 이상은 르방 활성을 해칠 수 있습니다.": "Too hot — above %d %@ can harm the levain.",
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
    "르방 빌드 끝 — 피크인지 확인하세요": "Levain build done — check that it's at peak",
    "%@ 끝": "%@ finished",
    "지금 시작: %@": "Start now: %@",
    "타임라인을 시작할 시간입니다": "Time to start your timeline",
    "오븐 예열 시작 — 굽기 %d분 전": "Preheat the oven — baking in %d min",
    "더치 오븐을 쓴다면 함께 넣어 데우세요": "Using a Dutch oven? Put it in to heat up too.",
    "기준": "Anchor",
    "시작 시각": "Start time",
    "완성 시각": "Finish time",
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
    "오븐 예열 알림": "Oven preheat alert",
    "굽기 전": "Before baking",
    "굽기 단계가 없어 예열 알림은 울리지 않습니다.": "There's no bake stage, so no preheat alert will go off.",
    "첫 단계를 시작할 시각과 각 단계가 끝나는 시각에 알림이 옵니다. 앱을 닫아도 울립니다.":
        "You'll be notified when the first stage should start and when each stage ends, even with the app closed.",
    "알림 권한이 꺼져 있습니다": "Notifications are off",
    "설정 앱 → 알림에서 이 앱의 알림을 허용해 주세요.": "Allow notifications for this app in Settings → Notifications.",
    "모든 단계가 이미 지났습니다": "All stages are already past",
    "시작 시각을 바꾸거나 '지금 시작'을 누른 뒤 다시 예약하세요.":
        "Change the start time or tap 'Start now', then schedule again.",
    "완성 시각을 늦추거나 '지금 시작'을 누른 뒤 다시 예약하세요.": "Set a later finish time or tap 'Start now', then schedule again.",
    "알림을 예약하지 못했습니다": "Couldn't schedule alerts",
    "잠시 후 다시 시도하세요.": "Please try again in a moment.",
    "내일": "Tomorrow",
    "%d시간 %d분": "%dh %dm",
    "%d시간": "%dh",
    "%d분": "%d min",

    // 설정
    "언어": "Language",
    "검색 같은 시스템 화면은 앱을 다시 열면 바뀝니다. 공유 시트의 일부 항목은 기기 언어를 따릅니다.":
        "System screens such as search switch the next time you open the app. Some share-sheet items follow the device language.",
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
    "배합표·레시피를 보는 동안 화면 켜두기": "Keep screen on while viewing a formula or recipe",
    "정보": "About",
    "버전": "Version",
    "개인정보 처리방침": "Privacy Policy",
    "지원·문의": "Support",
    "웹 버전": "Web Version",
    "앱 평가하기": "Rate Doughmetry",
    "앱 공유하기": "Share Doughmetry",
    "광고·계정·추적 없음": "No ads, no accounts, no tracking",
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
        case .jsonParse:
            // detail은 시스템 localizedDescription — 기기 언어로 나오고 형식 오류 외의 정보도 없다
            return L("JSON 파싱 실패 — 올바른 JSON 파일이 아닙니다")
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
