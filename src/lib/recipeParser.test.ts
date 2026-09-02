import { describe, expect, it } from 'vitest';
import { computeStats } from './dough';
import { parseRecipeText } from './recipeParser';

/** iOS RecipeTextParserTests.swift의 이식본 — 케이스·기대값을 동일하게 유지할 것 */
describe('레시피 텍스트 파서 (규칙 기반)', () => {
  it('표 형식 OCR 텍스트 — 사워도우 바게트 샘플', () => {
    const r = parseRecipeText(
      [
        'G. 사워도우 바게트 (Baguette au levain)',
        '1. 재료',
        '재 료 양 (g)',
        'T65 트레디션 1000',
        '물 680',
        '르방 리퀴드 350',
        '소금 21',
        '바시나쥬 물 30',
      ].join('\n'),
    );
    expect(r.name).toBe('사워도우 바게트 (Baguette au levain)');
    expect(r.input.flours).toHaveLength(1);
    expect(r.input.flours[0].grams).toBe(1000);
    expect(r.input.flours[0].name).toContain('T65');
    expect(r.input.water).toBe(680);
    expect(r.input.levain.grams).toBe(350);
    expect(r.input.levain.hydration).toBe(1.0);
    expect(r.input.salt).toBe(21);
    expect(r.input.bassinage).toBe(30);
    expect(r.matchedLineCount).toBe(5);
    expect(r.input.extras).toHaveLength(0); // "1. 재료" 헤더가 재료로 오인되지 않는다
    // 합산 수분율 검증: (680+30+175)/(1000+175) ≈ 75.3%
    const s = computeStats(r.input);
    expect(Math.abs(s.hydrationPct - ((680 + 30 + 175) / 1175) * 100)).toBeLessThan(1e-9);
  });

  it('자유 서술형 + 다중 밀가루 + 이스트·우유', () => {
    const r = parseRecipeText(
      [
        '캉파뉴',
        '강력분 700g',
        '호밀가루 300 g',
        '물 650',
        '우유 100',
        '르방 뒤흐 200',
        '소금 20',
        '인스턴트 이스트 4',
        '호두 80',
        '총 반죽 무게 2054',
      ].join('\n'),
    );
    expect(r.name).toBe('캉파뉴');
    expect(r.input.flours).toHaveLength(2);
    expect(r.input.flours[1].grams).toBe(300);
    expect(r.input.water).toBe(650);
    expect(r.input.levain.hydration).toBe(0.5);
    expect(r.input.levain.type).toBe('dur');
    expect(r.input.yeast).toEqual({ type: 'instant', grams: 4 });
    expect(r.input.liquids).toHaveLength(1);
    expect(r.input.liquids[0].waterRatio).toBe(0.88);
    expect(r.input.extras).toHaveLength(1);
    expect(r.input.extras[0].name).toContain('호두');
    // "총 반죽 무게" 줄은 무시된다
    expect(computeStats(r.input).doughWeight).toBe(700 + 300 + 650 + 100 + 200 + 20 + 4 + 80);
  });

  it('천 단위 쉼표와 르방 수분율 % 표기', () => {
    const r = parseRecipeText('T65 1,000\n물 700\n르방 80% 300\n소금 20');
    expect(r.input.flours[0].grams).toBe(1000);
    expect(r.input.levain.grams).toBe(300);
    expect(Math.abs(r.input.levain.hydration - 0.8)).toBeLessThan(1e-9);
  });

  it('온도 표기가 있어도 재료 줄이 살아남는다', () => {
    const r = parseRecipeText('T65 1000\n물 680 (30°C)\n소금 20 30℃\n르방 리퀴드 200');
    expect(r.input.water).toBe(680);
    expect(r.input.salt).toBe(20);
    expect(r.input.flours[0].grams).toBe(1000);
    expect(r.matchedLineCount).toBe(4);
  });

  it('물엿·시럽은 물이 아니라 기타 재료로 분류된다', () => {
    const r = parseRecipeText('강력분 500\n물 350\n물엿 30');
    expect(r.input.water).toBe(350);
    expect(r.input.extras).toHaveLength(1);
    expect(r.input.extras[0].grams).toBe(30);
  });

  it('인스타그램 스타일 — kg 단위·@멘션·stiff starter·숫자 선행', () => {
    const r = parseRecipeText(
      [
        'Sun is shinning .... baguettes dough ... #dome action later !',
        '1kg flour ( @wessexmill )',
        '350 ferment ( starter stiff )',
        '730 water',
        '10 yeast fresh',
        '20 sea salt',
        'Large scoop of love or more...',
      ].join('\n'),
    );
    expect(r.input.flours).toHaveLength(1);
    expect(r.input.flours[0].grams).toBe(1000); // 1kg → 1000g
    expect(r.input.flours[0].name).not.toContain('@');
    expect(r.input.flours[0].name).not.toContain('wessexmill');
    expect(r.input.levain.grams).toBe(350);
    expect(r.input.levain.hydration).toBe(0.5); // stiff starter → 뒤흐
    expect(r.input.levain.type).toBe('dur');
    expect(r.input.water).toBe(730);
    expect(r.input.yeast).toEqual({ type: 'fresh', grams: 10 });
    expect(r.input.salt).toBe(20);
    expect(r.input.bassinage).toBe(0);
    expect(r.input.extras).toHaveLength(0);
  });

  it('kg 표기 변형 — 1.5kg, 1키로, ㎏', () => {
    const r = parseRecipeText('강력분 1.5kg\n통밀 1키로\n물 1㎏\n소금 30');
    expect(r.input.flours[0].grams).toBe(1500);
    expect(r.input.flours[1].grams).toBe(1000);
    expect(r.input.water).toBe(1000);
    expect(r.input.salt).toBe(30);
  });

  it("한국식 온도 표기 — '30도'가 물 양을 가리지 않는다", () => {
    const a = parseRecipeText('강력분 500g\n물 350g (30도)\n소금 10g');
    expect(a.input.water).toBe(350);
    const b = parseRecipeText('강력분 500g\n물 350g 30도\n소금 10g');
    expect(b.input.water).toBe(350);
    // '도'로 끝나는 재료명은 건드리지 않는다
    const c = parseRecipeText('강력분 500\n물 350\n포도 100');
    expect(c.input.extras[0]?.grams).toBe(100);
  });

  it("'수분율/hydration' 단어가 있어도 그램이 있는 재료 줄은 살아남는다", () => {
    const a = parseRecipeText('강력분 500g\n물 350g\n소금 10g\n르방 150g (수분율 100%)');
    expect(a.input.levain.grams).toBe(150);
    expect(a.input.levain.hydration).toBe(1.0);
    expect(a.matchedLineCount).toBe(4);

    const b = parseRecipeText(
      'bread flour 500g\nwater 350g\nsalt 10g\n100% hydration starter 150g',
    );
    expect(b.input.levain.grams).toBe(150);
    expect(b.input.levain.hydration).toBe(1.0);

    // 그램 없는 통계 줄은 여전히 걸러진다
    const c = parseRecipeText('강력분 500\n물 350\nHydration: 75%\n수분율 70%');
    expect(c.matchedLineCount).toBe(2);
  });

  it("괄호 안 분해 표기 — '500g (강력 400 + 통밀 100)'은 500g", () => {
    const r = parseRecipeText('밀가루 500g (강력 400 + 통밀 100)\n물 350g\n소금 10g');
    expect(r.input.flours).toHaveLength(1);
    expect(r.input.flours[0].grams).toBe(500);
    expect(r.input.water).toBe(350);
  });

  it("슬래시 한 줄 표기 분할 — '강력분 500 / 물 350 / 소금 10 / 르방 100'", () => {
    const r = parseRecipeText('강력분 500 / 물 350 / 소금 10 / 르방 100');
    expect(r.input.flours[0]?.grams).toBe(500);
    expect(r.input.water).toBe(350);
    expect(r.input.salt).toBe(10);
    expect(r.input.levain.grams).toBe(100);
    expect(r.matchedLineCount).toBe(4);
    // 이름 속 슬래시는 분할하지 않는다
    const b = parseRecipeText('밀가루(강력/T65) 500g\n물 350');
    expect(b.input.flours).toHaveLength(1);
    expect(b.input.flours[0].grams).toBe(500);
  });

  it('르방 빌드 섹션은 본반죽에 이중 합산되지 않는다', () => {
    const r = parseRecipeText(
      [
        '르방 만들기',
        '스타터 20g',
        '밀가루 60g',
        '물 60g',
        '',
        '본반죽',
        '밀가루 440g',
        '물 290g',
        '소금 9g',
        '르방 140g',
      ].join('\n'),
    );
    expect(r.input.flours).toHaveLength(1);
    expect(r.input.flours[0].grams).toBe(440);
    expect(r.input.water).toBe(290);
    expect(r.input.salt).toBe(9);
    expect(r.input.levain.grams).toBe(140);
    expect(r.input.levain.hydration).toBe(1.0); // 60/60에서 추정
    expect(computeStats(r.input).doughWeight).toBe(879);
  });

  it('빌드 섹션만 있으면 빌드 총량이 르방이 된다', () => {
    const r = parseRecipeText('르방 만들기\n스타터 20g\n밀가루 90g\n물 90g');
    expect(r.input.levain.grams).toBe(200);
    expect(r.input.levain.hydration).toBe(1.0);
    expect(r.input.flours).toHaveLength(0);
  });

  it("'만드는 법' 이후 서술부는 흡수하지 않는다", () => {
    const r = parseRecipeText(
      [
        '깜빠뉴',
        '강력분 500g',
        '물 350g',
        '소금 10g',
        '르방 100g',
        '',
        '만드는 법',
        '물 340g에 르방을 풀어주세요',
        '밀가루와 소금을 넣고 30분 휴지',
        '나머지 물 10g을 넣고 2분 믹싱',
      ].join('\n'),
    );
    expect(r.name).toBe('깜빠뉴');
    expect(r.input.flours[0]?.grams).toBe(500);
    expect(r.input.water).toBe(350);
    expect(r.input.salt).toBe(10);
    expect(r.input.levain.grams).toBe(100);
    expect(r.matchedLineCount).toBe(4);
  });

  it('조절수·조정수는 바시나주로 분류된다', () => {
    const r = parseRecipeText('강력분 500g\n물 320g\n조절수 30g\n소금 10g\n르방 100g');
    expect(r.input.water).toBe(320);
    expect(r.input.bassinage).toBe(30);
    const s = computeStats(r.input);
    expect(Math.abs(s.hydrationPct - ((320 + 30 + 50) / 550) * 100)).toBeLessThan(1e-9);
  });

  it('재료가 없으면 matchedLineCount 0', () => {
    const r = parseRecipeText('오늘의 일기\n빵을 굽고 싶다');
    expect(r.matchedLineCount).toBe(0);
  });
});

/** Swift(ICU) 의미에 맞춘 회귀 케이스 — 적대적 검증 워크플로에서 발견된 차이들 */
describe('플랫폼 패리티 회귀', () => {
  it("'lait fermenté'는 르방이 아니라 우유다 (유니코드 단어 경계)", () => {
    const r = parseRecipeText('farine T80 450g\neau 340g\nsel 9g\nlait fermenté 250g');
    expect(r.input.levain.grams).toBe(0);
    expect(r.input.liquids).toHaveLength(1);
    expect(r.input.liquids[0].grams).toBe(250);
    expect(r.input.liquids[0].waterRatio).toBe(0.88);
    expect(r.input.flours[0].grams).toBe(450);
    expect(r.input.water).toBe(340);
  });

  it("'pâte fermentée'는 기타 재료로 분류된다 (iOS와 동일)", () => {
    const r = parseRecipeText('farine T80 450g\neau 340g\nsel 9g\npâte fermentée 150g');
    expect(r.input.levain.grams).toBe(0);
    expect(r.input.extras).toHaveLength(1);
    expect(r.input.extras[0].grams).toBe(150);
  });

  it("문자가 붙은 T번호('밀T65')는 밀가루 판정하지 않는다", () => {
    const r = parseRecipeText('밀T65 500g\n물 350');
    expect(r.input.flours).toHaveLength(0);
    expect(r.input.extras[0]?.grams).toBe(500);
    expect(r.input.water).toBe(350);
  });

  it('U+2028·단독 \\r 개행도 줄로 분리된다', () => {
    const a = parseRecipeText('강력분 500 물 350g 소금 10g');
    expect(a.input.flours[0]?.grams).toBe(500);
    expect(a.input.water).toBe(350);
    expect(a.input.salt).toBe(10);
    expect(a.matchedLineCount).toBe(3);
    const b = parseRecipeText('강력분 500\r물 350g\r소금 10g');
    expect(b.input.water).toBe(350);
    expect(b.input.salt).toBe(10);
  });

  it('이모지 한 글자 줄은 제목이 되지 않는다 (자소 기준 길이)', () => {
    const r = parseRecipeText('🥖\n깜빠뉴\n강력분 500\n물 350');
    expect(r.name).toBe('깜빠뉴');
  });

  it("'르방 100g (20%)'의 베이커스 퍼센트는 수분율로 오독하지 않는다", () => {
    const r = parseRecipeText('강력분 500\n물 350\n르방 100g (20%)');
    expect(r.input.levain.grams).toBe(100);
    expect(r.input.levain.hydration).toBe(1.0);
    expect(r.input.levain.type).toBe('liquide');
  });

  it('르방 빌드 섹션의 물엿은 수분율 추정에 들어가지 않는다', () => {
    const r = parseRecipeText('르방 만들기\n밀가루 100\n물엿 100\n물 50');
    expect(r.input.levain.grams).toBe(250); // 총량에는 포함
    expect(r.input.levain.hydration).toBe(0.5); // 50/100 — 물엿 제외
  });

  it("'총량 950g' 합계 줄은 유령 재료가 되지 않는다", () => {
    const r = parseRecipeText('강력분 500\n물 350\n총량 950g');
    expect(r.input.extras).toHaveLength(0);
    expect(r.matchedLineCount).toBe(2);
  });

  it('시간 표기(6시간·30분)는 그램으로 합산되지 않는다', () => {
    const build = parseRecipeText('르방 만들기\n스타터 20g\n밀가루 90g\n물 90g\n실온 6시간 발효');
    expect(build.input.levain.grams).toBe(200); // 6이 더해지면 206
    expect(build.input.levain.hydration).toBe(1.0);
    const main = parseRecipeText('강력분 500\n물 350\n벌크 발효 4시간');
    expect(main.matchedLineCount).toBe(2);
    expect(main.input.extras).toHaveLength(0);
  });

  it("'물 100g + 50g' 합산 표기는 더해서 계산한다", () => {
    const r = parseRecipeText('강력분 500\n물 100g + 50g\n소금 10');
    expect(r.input.water).toBe(150);
    // 괄호 분해 표기는 여전히 바깥 값 하나만
    const b = parseRecipeText('밀가루 500g (강력 400 + 통밀 100)\n물 350g');
    expect(b.input.flours[0].grams).toBe(500);
  });

  it('NFD로 분해된 텍스트도 NFC 정규화 후 파싱된다', () => {
    const r = parseRecipeText('강력분 500\n물 350'.normalize('NFD'));
    expect(r.input.water).toBe(350);
    expect(r.input.flours[0]?.grams).toBe(500);
  });
});
