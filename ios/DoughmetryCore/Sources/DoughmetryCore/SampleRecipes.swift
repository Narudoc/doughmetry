import Foundation

/// 빈 레시피 탭의 "예시 레시피 추가" — 사용자가 누를 때만 넣는다 (자동으로 넣지 않는다).
/// id는 고정이다: 두 기기에서 따로 눌러도 iCloud 병합 뒤 한 벌만 남는다. 웹 JSON 스키마와 그대로 호환
public enum SampleRecipes {
    /// 앱이 넣는 예시의 시각 — 어떤 실제 편집·묘비보다 오래다.
    /// 넣는 시각을 쓰면 다른 기기(새로 설치해 아직 내려받기 전, iCloud 꺼짐)에서 누른 예시가
    /// 병합에서 이 기기의 예시 편집을 되돌리고 지운 예시를 되살린다.
    /// 이 기기에서 지운 예시를 다시 넣을 때는 저장(LibrarySync.savedRecipe)이 묘비 뒤로 민다
    public static let epoch = "2000-01-01T00:00:00.000Z"

    /// 이름·재료명은 넣는 순간의 앱 언어로 쓴다 — 저장된 뒤엔 사용자 데이터라 언어를 바꿔도 그대로다
    /// localize는 앱의 L — 코어엔 앱 사전이 없다. 앱은 now에 epoch를 넘기고 touch: false로 저장한다
    public static func make(now: String, localize: (String) -> String) -> [Recipe] {
        let tags = [localize("예시")]
        func recipe(_ id: String, _ name: String, pieces: Double, _ input: DoughInput) -> Recipe {
            Recipe(
                id: id, name: localize(name), tags: tags, createdAt: now, updatedAt: now,
                input: input, pieces: pieces)
        }
        let samples = [
            // 계산기 기본 예시와 같은 수치 — 총 수분율 72%, 소금 2%, PFF 10%
            recipe(
                "sample-campagne", "팽 드 캉파뉴", pieces: 2,
                DoughInput(
                    flours: [Flour(id: "sample-campagne-t65", name: "T65", grams: 900)],
                    water: 620, salt: 20, levain: Levain(type: .liquide, hydration: 1, grams: 200))),
            // 통밀 위주 — 총 수분율 78%, 소금 2%, PFF 10%
            recipe(
                "sample-complet", "팽 콩플레 (통밀빵)", pieces: 2,
                DoughInput(
                    flours: [
                        Flour(id: "sample-complet-t150", name: "T150", grams: 700),
                        Flour(id: "sample-complet-t65", name: "T65", grams: 200),
                    ],
                    water: 680, salt: 20, levain: Levain(type: .liquide, hydration: 1, grams: 200))),
            // 르방 뒤흐 + 바시나주 + 생이스트 약간 — 총 수분율 70%, 소금 2%, PFF 7.7%
            recipe(
                "sample-baguette", "바게트 오 르방", pieces: 3,
                DoughInput(
                    flours: [Flour(id: "sample-baguette-t65", name: "T65", grams: 600)],
                    water: 405, bassinage: 25, salt: 13, levain: Levain(type: .dur, hydration: 0.5, grams: 75),
                    yeast: Yeast(type: .fresh, grams: 2))),
            // 우유·계란은 액체(수분율만큼 총 물), 버터·설탕은 기타 재료 — 총 수분율 58.6%, PFF 10%
            recipe(
                "sample-brioche", "브리오슈 오 르방", pieces: 2,
                DoughInput(
                    flours: [Flour(id: "sample-brioche-t45", name: "T45", grams: 450)],
                    water: 0, salt: 10, levain: Levain(type: .liquide, hydration: 1, grams: 100),
                    liquids: [
                        Liquid(
                            id: "sample-brioche-egg", name: localize(LiquidPreset.egg.name), grams: 250,
                            waterRatio: LiquidPreset.egg.waterRatio),
                        Liquid(
                            id: "sample-brioche-milk", name: localize(LiquidPreset.milk.name), grams: 60,
                            waterRatio: LiquidPreset.milk.waterRatio),
                    ],
                    extras: [
                        Extra(id: "sample-brioche-butter", name: localize("버터"), grams: 200),
                        Extra(id: "sample-brioche-sugar", name: localize("설탕"), grams: 60),
                    ])),
        ]
        // 저장 순서(정규 순서)는 createdAt 최신순·같으면 id다 — 1초씩 앞당겨 다시 읽어도 정의한 순서로 보이게
        let base = parseISO(now) ?? Date()
        return samples.enumerated().map { i, r in
            var r = r
            r.createdAt = isoString(from: base.addingTimeInterval(-Double(i)))
            r.updatedAt = r.createdAt
            return r
        }
    }
}
