import Foundation

/// AI 가져오기 초안을 버린 까닭 — 앱은 진단 로그에 남기고, 확인 화면에서 규칙 결과로 폴백했다고 알린다
public enum ReconcileRejection: Error, Equatable, Sendable {
    /// 밀가루·르방·물이 하나도 없다
    case empty
    /// 르방·발효종이 밀가루·액체·기타 재료로 분류됐다
    case levainMisfiled
    /// 총 반죽 무게가 max(5 g, 1%)보다 더 다르다
    case weight
    /// 총 수분율이 2%p보다 더 다르다
    case hydration
    /// PFF가 2%p보다 더 다르다
    case pff
    /// 르방 무게가 max(10 g, 10%)보다 더 다르다
    case levainMass
    /// 기타 재료 가짓수가 규칙 결과보다 적다
    case extrasMissing
    /// 규칙 결과엔 이스트가 있는데 초안엔 없다
    case yeastMissing
}

/// 온디바이스 모델의 초안을 같은 텍스트의 규칙 파서 결과(`rules`)로 보정·검증한다.
/// 믿을 수 없는 초안은 .failure — 호출부가 규칙 결과로 폴백한다
public func reconcileAIDraft(
    _ draft: DoughInput, rules: ParsedRecipeText
) -> Result<DoughInput, ReconcileRejection> {
    var input = draft
    guard !input.flours.isEmpty || input.levain.grams > 0 || input.water > 0 else {
        return .failure(.empty)
    }
    // 르방·발효종이 밀가루·액체·기타로 분류되면 총 무게는 같아도 수분율·PFF가 틀어진다
    let names = input.flours.map(\.name) + input.liquids.map(\.name) + input.extras.map(\.name)
    if names.contains(where: RecipeTextParser.matchesLevain) {
        return .failure(.levainMisfiled)
    }

    // 규칙 파서가 키워드(리퀴드/뒤흐/stiff/30~150%/풀리시·비가)나 르방 빌드 비율로 정한 수분율은
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
    // 우유·계란은 모델이 추정한 수분율 대신 프리셋을 쓴다
    for i in input.liquids.indices {
        if let preset = RecipeTextParser.liquidPreset(forName: input.liquids[i].name) {
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
        if abs(ai.doughWeight - rs.doughWeight) > max(5, rs.doughWeight * 0.01) {
            return .failure(.weight)
        }
        if abs(ai.hydrationPct - rs.hydrationPct) > 2 { return .failure(.hydration) }
        if abs(ai.pffPct - rs.pffPct) > 2 { return .failure(.pff) }
        if abs(input.levain.grams - rulesLevain) > max(10, rulesLevain * 0.1) {
            return .failure(.levainMass)
        }
        if input.extras.count < rules.input.extras.count { return .failure(.extrasMissing) }
        if rules.input.yeast.grams > 0, input.yeast.grams == 0 { return .failure(.yeastMissing) }
    }
    return .success(input)
}
