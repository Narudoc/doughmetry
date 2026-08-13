import { describe, expect, it } from 'vitest';
import type { DoughInput } from './dough';
import {
  IDY_FACTOR,
  LIQUID_PRESETS,
  computeStats,
  convertFixedMass,
  convertFixedPff,
  convertYeast,
  maxConvertibleLevain,
  solveFromTarget,
  withLevainMass,
} from './dough';

/** v2 기본 필드를 채운 배합 생성 헬퍼 */
const makeInput = (partial: Partial<DoughInput> = {}): DoughInput => ({
  flours: [{ id: 'f1', name: 'T65', grams: 900 }],
  water: 620,
  bassinage: 0,
  salt: 20,
  levain: { type: 'liquide', hydration: 1, grams: 200 },
  liquids: [],
  yeast: { type: 'fresh', grams: 0 },
  extras: [],
  ...partial,
});

/** 케이스 1·2의 기준 레시피: 밀가루 900 / 물 620 / 소금 20 / 르방 리퀴드 200 (h=1.0) */
const baseRecipe = () => makeInput();

const addedFlour = (input: DoughInput) => input.flours.reduce((a, f) => a + f.grams, 0);

function expectInvariantsPreserved(a: DoughInput, b: DoughInput, tolerance = 1e-6) {
  const sa = computeStats(a);
  const sb = computeStats(b);
  expect(sb.totalFlour).toBeCloseTo(sa.totalFlour, 6);
  expect(sb.totalWater).toBeCloseTo(sa.totalWater, 6);
  expect(Math.abs(sb.hydrationPct - sa.hydrationPct)).toBeLessThan(tolerance);
  expect(sb.doughWeight).toBeCloseTo(sa.doughWeight, 6);
}

describe('케이스 1 — 기본 계산', () => {
  it('총 수분율 72.0% / 소금 2.0% / PFF 10.0% / 총 반죽 1740g', () => {
    const s = computeStats(baseRecipe());
    expect(s.levainFlour).toBeCloseTo(100, 6);
    expect(s.levainWater).toBeCloseTo(100, 6);
    expect(s.totalFlour).toBeCloseTo(1000, 6);
    expect(s.totalWater).toBeCloseTo(720, 6);
    expect(s.hydrationPct).toBeCloseTo(72.0, 6);
    expect(s.saltPct).toBeCloseTo(2.0, 6);
    expect(s.pffPct).toBeCloseTo(10.0, 6);
    expect(s.doughWeight).toBeCloseTo(1740, 6);
  });

  it('모드 B 역산이 같은 배합을 복원한다', () => {
    const solved = solveFromTarget({
      doughWeight: 1740,
      hydration: 0.72,
      saltRatio: 0.02,
      pff: 0.1,
      levainHydration: 1,
    });
    expect(addedFlour(solved)).toBeCloseTo(900, 6);
    expect(solved.water).toBeCloseTo(620, 6);
    expect(solved.salt).toBeCloseTo(20, 6);
    expect(solved.levain.grams).toBeCloseTo(200, 6);
    expect(computeStats(solved).hydrationPct).toBeCloseTo(72, 6);
  });
});

describe('v2 — 바시나주·액체 재료·이스트', () => {
  it('바시나주는 총 물과 총 반죽 무게에 더해진다', () => {
    const s = computeStats(makeInput({ bassinage: 50 }));
    expect(s.totalWater).toBeCloseTo(770, 6);
    expect(s.hydrationPct).toBeCloseTo(77.0, 6);
    expect(s.doughWeight).toBeCloseTo(1790, 6);
    expect(s.totalFlour).toBeCloseTo(1000, 6); // 밀가루에는 영향 없음
  });

  it('우유 88% / 계란 76% 수분율이 총 물에 반영된다 (USDA 기준)', () => {
    expect(LIQUID_PRESETS.milk.waterRatio).toBe(0.88);
    expect(LIQUID_PRESETS.egg.waterRatio).toBe(0.76);
    const s = computeStats(
      makeInput({
        liquids: [
          { id: 'l1', name: '우유', grams: 100, waterRatio: 0.88 },
          { id: 'l2', name: '계란', grams: 50, waterRatio: 0.76 },
        ],
      }),
    );
    expect(s.liquidWater).toBeCloseTo(88 + 38, 6);
    expect(s.totalWater).toBeCloseTo(720 + 126, 6);
    expect(s.hydrationPct).toBeCloseTo(84.6, 6);
    expect(s.doughWeight).toBeCloseTo(1740 + 150, 6); // 액체는 전체 무게로 합산
    expect(s.saltPct).toBeCloseTo(2.0, 6); // 소금·PFF는 여전히 총 밀가루 기준
  });

  it('생이스트 ↔ 인스턴트 드라이 변환 (IDY = 생이스트 × 0.4)', () => {
    expect(IDY_FACTOR).toBe(0.4);
    expect(convertYeast(20, 'fresh', 'instant')).toBeCloseTo(8, 9);
    expect(convertYeast(8, 'instant', 'fresh')).toBeCloseTo(20, 9);
    expect(convertYeast(15, 'fresh', 'fresh')).toBe(15);
    // 왕복 변환은 원래 값으로 돌아온다
    expect(convertYeast(convertYeast(13.7, 'fresh', 'instant'), 'instant', 'fresh')).toBeCloseTo(
      13.7,
      9,
    );
  });

  it('이스트는 반죽 무게와 %에만 반영되고 수분율에는 영향이 없다', () => {
    const s = computeStats(makeInput({ yeast: { type: 'fresh', grams: 10 } }));
    expect(s.doughWeight).toBeCloseTo(1750, 6);
    expect(s.yeastPct).toBeCloseTo(1.0, 6);
    expect(s.hydrationPct).toBeCloseTo(72.0, 6);
  });
});

describe('케이스 2 — 리퀴드 → 뒤흐 변환 (르방 질량 고정)', () => {
  it('첨가 밀가루 866.67g / 물 653.33g, 불변량 보존, PFF 10 → 13.33%', () => {
    const result = convertFixedMass(baseRecipe(), 0.5);
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    expect(result.deltaFlour).toBeCloseTo(33.333333, 4);
    expect(addedFlour(result.output)).toBeCloseTo(866.67, 1);
    expect(result.output.water).toBeCloseTo(653.33, 1);
    expect(result.output.salt).toBe(20);
    expect(result.output.levain.grams).toBe(200);
    expect(result.after.levainFlour).toBeCloseTo(133.33, 1);
    expect(result.after.levainWater).toBeCloseTo(66.67, 1);

    expect(result.after.totalFlour).toBeCloseTo(1000, 6);
    expect(result.after.totalWater).toBeCloseTo(720, 6);
    expect(result.after.hydrationPct).toBeCloseTo(72.0, 6);
    expect(result.after.doughWeight).toBeCloseTo(1740, 6);
    expect(result.before.pffPct).toBeCloseTo(10.0, 6);
    expect(result.after.pffPct).toBeCloseTo(13.3333, 3);
    expect(result.output.levain.type).toBe('dur');
  });

  it('바시나주·액체·이스트는 변환에서 그대로 보존되고 본반죽 물만 조정된다', () => {
    const input = makeInput({
      bassinage: 60,
      liquids: [{ id: 'l1', name: '우유', grams: 100, waterRatio: 0.88 }],
      yeast: { type: 'fresh', grams: 10 },
    });
    const result = convertFixedMass(input, 0.5);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.output.bassinage).toBe(60);
    expect(result.output.liquids).toEqual(input.liquids);
    expect(result.output.yeast).toEqual(input.yeast);
    expect(result.output.water).toBeCloseTo(620 + result.deltaFlour, 6);
    expectInvariantsPreserved(input, result.output);
  });

  it('다중 밀가루 비례 배분: 비율이 유지된다', () => {
    const input = makeInput({
      flours: [
        { id: 'a', name: 'T65', grams: 700 },
        { id: 'b', name: 'T110', grams: 150 },
        { id: 'c', name: '호밀', grams: 50 },
      ],
    });
    const result = convertFixedMass(input, 0.5);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    const [a, b, c] = result.output.flours;
    // 700:150:50 비율 유지
    expect(a.grams / b.grams).toBeCloseTo(700 / 150, 6);
    expect(b.grams / c.grams).toBeCloseTo(150 / 50, 6);
    expect(addedFlour(result.output)).toBeCloseTo(900 - result.deltaFlour, 6);
    expectInvariantsPreserved(input, result.output);
  });

  it('단일 밀가루 지정 배분: 지정한 행에서만 증감', () => {
    const input = makeInput({
      flours: [
        { id: 'a', name: 'T65', grams: 700 },
        { id: 'b', name: 'T110', grams: 200 },
      ],
    });
    const result = convertFixedMass(input, 0.5, { mode: 'single', flourId: 'b' });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.output.flours[0].grams).toBe(700);
    expect(result.output.flours[1].grams).toBeCloseTo(200 - result.deltaFlour, 6);
    expectInvariantsPreserved(input, result.output);
  });

  it('단일 밀가루가 부족하면 SINGLE_FLOUR_INSUFFICIENT', () => {
    const input = makeInput({
      flours: [
        { id: 'a', name: 'T65', grams: 880 },
        { id: 'b', name: '호밀', grams: 20 },
      ],
    });
    const result = convertFixedMass(input, 0.5, { mode: 'single', flourId: 'b' });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error.code).toBe('SINGLE_FLOUR_INSUFFICIENT');
  });
});

describe('케이스 3 — 왕복 변환', () => {
  it('리퀴드 → 뒤흐 → 리퀴드가 원본을 복원한다 (±0.01g)', () => {
    const original = makeInput({
      bassinage: 40,
      liquids: [{ id: 'l1', name: '계란', grams: 50, waterRatio: 0.76 }],
      yeast: { type: 'instant', grams: 4 },
    });
    const toDur = convertFixedMass(original, 0.5);
    expect(toDur.ok).toBe(true);
    if (!toDur.ok) return;
    const back = convertFixedMass(toDur.output, 1);
    expect(back.ok).toBe(true);
    if (!back.ok) return;
    expect(addedFlour(back.output)).toBeCloseTo(900, 2);
    expect(back.output.water).toBeCloseTo(620, 2);
    expect(back.output.salt).toBeCloseTo(20, 2);
    expect(back.output.levain.grams).toBeCloseTo(200, 2);
    expect(back.output.levain.hydration).toBe(1);
    expect(back.output.bassinage).toBe(40);
    expect(back.output.liquids).toEqual(original.liquids);
    expect(back.output.yeast).toEqual(original.yeast);
  });
});

describe('케이스 4 — 불변식 property test (무작위 100건)', () => {
  // 시드 고정 PRNG — 재현 가능한 무작위 입력
  function mulberry32(seed: number) {
    return function () {
      seed |= 0;
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  it('변환 전후 총 밀가루·총 물·총 수분율·총 반죽 무게가 보존된다', () => {
    const rand = mulberry32(20260731);
    const between = (lo: number, hi: number) => lo + rand() * (hi - lo);
    let successes = 0;

    for (let i = 0; i < 100; i++) {
      const flourCount = 1 + Math.floor(rand() * 3);
      const flours = Array.from({ length: flourCount }, (_, k) => ({
        id: `f${k}`,
        name: `밀가루${k}`,
        grams: between(50, 800),
      }));
      const flourSum = flours.reduce((a, f) => a + f.grams, 0);
      const input = makeInput({
        flours,
        water: flourSum * between(0.45, 0.95),
        bassinage: rand() < 0.4 ? flourSum * between(0.02, 0.1) : 0,
        salt: flourSum * between(0.015, 0.025),
        levain: {
          type: 'liquide',
          hydration: between(0.4, 1.3),
          grams: flourSum * between(0.1, 0.5),
        },
        liquids:
          rand() < 0.4
            ? [{ id: 'l', name: '우유', grams: between(30, 200), waterRatio: between(0.5, 1) }]
            : [],
        yeast: rand() < 0.3 ? { type: 'fresh', grams: between(2, 20) } : { type: 'fresh', grams: 0 },
        extras: rand() < 0.3 ? [{ id: 'x', name: '씨앗', grams: between(10, 100) }] : [],
      });
      const newHydration = between(0.4, 1.3);
      const result = convertFixedMass(input, newHydration);

      if (result.ok) {
        successes++;
        expectInvariantsPreserved(input, result.output);
        for (const f of result.output.flours) expect(f.grams).toBeGreaterThanOrEqual(0);
        expect(result.output.water).toBeGreaterThanOrEqual(0);
        // PFF 고정 모드도 같은 불변량을 보존해야 한다
        const pff = convertFixedPff(input, newHydration);
        if (pff.ok) {
          expectInvariantsPreserved(input, pff.output);
          expect(pff.after.pffPct).toBeCloseTo(pff.before.pffPct, 6);
        }
      } else {
        // 실패 시 제시된 최대 르방 질량으로 줄이면 변환이 성공해야 한다 (비례 배분에서
        // SINGLE_FLOUR_INSUFFICIENT는 발생하지 않는다)
        if ('maxLevainGrams' in result.error) {
          expect(Number.isFinite(result.error.maxLevainGrams)).toBe(true);
          const reduced = withLevainMass(input, result.error.maxLevainGrams);
          const retry = convertFixedMass(reduced, newHydration);
          expect(retry.ok).toBe(true);
        }
      }
    }
    expect(successes).toBeGreaterThan(50);
  });
});

describe('케이스 5 — 경계 조건 (W_add_new < 0)', () => {
  /** 저수분 + 대량 뒤흐 르방: 뒤흐 → 리퀴드 변환이 불가능한 배합 */
  const stiffInput = () =>
    makeInput({
      flours: [{ id: 'f1', name: 'T65', grams: 1000 }],
      water: 50,
      salt: 20,
      levain: { type: 'dur', hydration: 0.5, grams: 600 },
    });

  it('W_ADD_NEGATIVE 오류가 발생하고 최대 르방 질량이 제시된다', () => {
    const result = convertFixedMass(stiffInput(), 1);
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error.code).toBe('W_ADD_NEGATIVE');
    // F_total=1400, 조정 가능 물 = 50 + 200 = 250 → max = min(1400×2, 250×2/1) = 500
    if ('maxLevainGrams' in result.error) {
      expect(result.error.maxLevainGrams).toBeCloseTo(500, 6);
      expect(maxConvertibleLevain(stiffInput(), 1)).toBeCloseTo(500, 6);
    }
  });

  it('제시된 최대 르방 질량은 실제로 유효하다 (그 이하 성공, 초과 실패)', () => {
    const max = maxConvertibleLevain(stiffInput(), 1);

    const atMax = convertFixedMass(withLevainMass(stiffInput(), max), 1);
    expect(atMax.ok).toBe(true);
    if (atMax.ok) {
      expect(atMax.output.water).toBeCloseTo(0, 6);
      expectInvariantsPreserved(withLevainMass(stiffInput(), max), atMax.output);
    }

    const overMax = convertFixedMass(withLevainMass(stiffInput(), max + 1), 1);
    expect(overMax.ok).toBe(false);
  });

  it('바시나주는 조정 가능한 물이 아니다 — 물 상한은 본반죽 물 기준', () => {
    // 바시나주가 커도 본반죽 물이 적으면 변환 한도는 그만큼 낮아야 한다
    const input = makeInput({
      flours: [{ id: 'f1', name: 'T65', grams: 1000 }],
      water: 10,
      bassinage: 300,
      salt: 20,
      levain: { type: 'dur', hydration: 0.5, grams: 600 },
    });
    // 조정 가능 물 = 10 + 200 = 210 → max = min(1400×2, 210×2/1) = 420
    const max = maxConvertibleLevain(input, 1);
    expect(max).toBeCloseTo(420, 6);

    expect(convertFixedMass(input, 1).ok).toBe(false);
    const atMax = convertFixedMass(withLevainMass(input, max), 1);
    expect(atMax.ok).toBe(true);
    if (atMax.ok) {
      expect(atMax.output.water).toBeCloseTo(0, 6);
      expect(atMax.output.bassinage).toBe(300); // 바시나주는 손대지 않는다
    }
  });

  it('르방 속 밀가루가 총 밀가루를 초과하면 F_ADD_NEGATIVE', () => {
    const input = makeInput({
      flours: [{ id: 'f1', name: 'T65', grams: 10 }],
      water: 500,
      salt: 5,
      levain: { type: 'liquide', hydration: 1, grams: 600 },
    });
    // h 1.0 → 0.25: F_lev 300 → 480 > F_total 310
    const result = convertFixedMass(input, 0.25);
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error.code).toBe('F_ADD_NEGATIVE');
  });
});

describe('보조 모드 — PFF 고정', () => {
  it('르방 질량과 본반죽 물이 바뀌고 F_add·PFF·수분율은 유지된다', () => {
    const result = convertFixedPff(baseRecipe(), 0.5);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.after.levainFlour).toBeCloseTo(100, 6); // F_lev 고정
    expect(result.output.levain.grams).toBeCloseTo(150, 6); // 100 × 1.5
    expect(result.output.water).toBeCloseTo(670, 6); // 620 + (100 − 50)
    expect(addedFlour(result.output)).toBeCloseTo(900, 6); // F_add 불변
    expect(result.after.pffPct).toBeCloseTo(10, 6);
    expect(result.after.hydrationPct).toBeCloseTo(72, 6);
  });

  it('바시나주·액체가 있어도 불변량이 유지된다', () => {
    const input = makeInput({
      bassinage: 60,
      liquids: [{ id: 'l1', name: '우유', grams: 100, waterRatio: 0.88 }],
    });
    const result = convertFixedPff(input, 0.5);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.output.bassinage).toBe(60);
    expect(result.output.liquids).toEqual(input.liquids);
    expectInvariantsPreserved(input, result.output);
  });
});
