import Foundation

/// 계산기·변환기의 레시피 불러오기 목록 — 정렬·검색·묶음.
/// 웹 src/lib/recipePicker.ts와 같은 규칙·같은 테스트 벡터 (한쪽을 바꾸면 RecipePickerTests.swift ↔ recipePicker.test.ts를 함께).
public enum RecipePicker {
    /// 레시피가 이보다 많으면 '최근' 몇 개를 위에 따로 두고 아래에 전체를 이름순으로
    public static let recentCount = 5

    public enum Kind: Sendable, Hashable {
        /// 최근 수정한 recentCount개 (전체에도 다시 나온다)
        case recent
        /// 전체, 이름순
        case all
        /// recentCount개 이하일 때의 전체, 최근 수정순
        case saved
        /// 검색 결과, 이름순 (비어 있을 수 있다)
        case results
    }

    public struct Section: Sendable, Equatable {
        public let kind: Kind
        public let recipes: [Recipe]

        public init(kind: Kind, recipes: [Recipe]) {
            self.kind = kind
            self.recipes = recipes
        }
    }

    /// 검색어는 앞뒤 공백을 떼고, 비면 거르지 않는다
    public static func sections(_ recipes: [Recipe], query: String) -> [Section] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            return [Section(kind: .results, recipes: byName(recipes.filter { matches($0, query: q) }))]
        }
        let recent = byRecency(recipes)
        guard recipes.count > recentCount else { return [Section(kind: .saved, recipes: recent)] }
        return [
            Section(kind: .recent, recipes: Array(recent.prefix(recentCount))),
            Section(kind: .all, recipes: byName(recipes)),
        ]
    }

    /// 이름이나 태그 하나에 검색어가 들어 있으면 — 대소문자·발음 구별 기호·전각/반각 무시, 로캘과 무관.
    /// 웹은 NFKD → 결합 기호(Mn) 제거 → NFC → 소문자로 접어 includes — 벡터에서 같은 답을 내야 한다
    static func matches(_ recipe: Recipe, query: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        if recipe.name.range(of: query, options: options) != nil { return true }
        return (recipe.tags ?? []).contains { $0.range(of: query, options: options) != nil }
    }

    /// 최근 수정순 — updatedAt 내림차순, 같으면 createdAt 내림차순, 같으면 id 오름차순 (JS 문자열 비교와 같은 UTF-16 순).
    /// 시각은 기기 사이에서 같은 값을 내는 syncInstant로 읽고(웹은 Date.parse), 읽지 못하는 시각은 맨 뒤로
    static func byRecency(_ recipes: [Recipe]) -> [Recipe] {
        recipes
            .map { (recipe: $0, updated: millis($0.updatedAt), created: millis($0.createdAt)) }
            .sorted { a, b in
                if a.updated != b.updated { return newerFirst(a.updated, b.updated) }
                if a.created != b.created { return newerFirst(a.created, b.created) }
                return a.recipe.id.utf16.lexicographicallyPrecedes(b.recipe.id.utf16)
            }
            .map(\.recipe)
    }

    /// 이름순 — 한국어 정렬(한글 다음 로마자), 대소문자·발음 구별 기호·전각/반각 무시, 숫자는 값으로 (캉파뉴 2 < 캉파뉴 10).
    /// 웹은 Intl.Collator('ko', { numeric: true, sensitivity: 'base' }). 같은 이름은 최근 수정순
    static func byName(_ recipes: [Recipe]) -> [Recipe] {
        let rank = Dictionary(
            byRecency(recipes).enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let locale = Locale(identifier: "ko")
        return recipes.sorted { a, b in
            switch a.name.compare(
                b.name, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .numeric],
                range: nil, locale: locale)
            {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return (rank[a.id] ?? 0) < (rank[b.id] ?? 0)
            }
        }
    }

    private static func millis(_ iso: String) -> Double? {
        LibrarySync.syncInstant(iso).map { ($0.timeIntervalSince1970 * 1000).rounded() }
    }

    /// 둘이 다를 때만 부른다 — nil(읽지 못한 시각)은 늘 뒤
    private static func newerFirst(_ a: Double?, _ b: Double?) -> Bool {
        guard let a else { return false }
        guard let b else { return true }
        return a > b
    }
}
