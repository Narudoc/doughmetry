import { describe, expect, it } from 'vitest';
import type { DoughInput } from './dough';
import {
  computeStats,
  convertFixedMass,
  convertFixedPff,
  maxConvertibleLevain,
  solveFromTarget,
  withLevainMass,
} from './dough';

/** 케이스 1·2의 기준 레시피: 밀가루 900 / 물 620 / 소금 20 / 르방 리퀴드 200 (h=1.0) */
const baseRecipe = (): DoughInput => ({
  flours: [{ id: 'f1', name: 'T65', grams: 900 }],
  water: 620,
  salt: 20,
  levain: { type: 'liquide', hydration: 1, grams: 200 },
  extras: [],
});

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

describe('케이스 2 — 리퀴드 → 뒤흐 변환 (르방 질량 고정)', () => {
  it('첨가 밀가루 866.67g / 첨가 물 653.33g, 불변량 보존, PFF 10 → 13.33%', () => {
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

  it('다중 밀가루 비례 배분: 비율이 유지된다', () => {
    const input: DoughInput = {
      ...baseRecipe(),
      flours: [
        { id: 'a', name: 'T65', grams: 700 },
        { id: 'b', name: 'T110', grams: 150 },
        { id: 'c', name: '호밀', grams: 50 },
      ],
    };
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
    const input: DoughInput = {
      ...baseRecipe(),
      flours: [
        { id: 'a', name: 'T65', grams: 700 },
        { id: 'b', name: 'T110', grams: 200 },
      ],
    };
    const result = convertFixedMass(input, 0.5, { mode: 'single', flourId: 'b' });
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.output.flours[0].grams).toBe(700);
    expect(result.output.flours[1].grams).toBeCloseTo(200 - result.deltaFlour, 6);
    expectInvariantsPreserved(input, result.output);
  });

  it('단일 밀가루가 부족하면 SINGLE_FLOUR_INSUFFICIENT', () => {
    const input: DoughInput = {
      ...baseRecipe(),
      flours: [
        { id: 'a', name: 'T65', grams: 880 },
        { id: 'b', name: '호밀', grams: 20 },
      ],
    };
    const result = convertFixedMass(input, 0.5, { mode: 'single', flourId: 'b' });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error.code).toBe('SINGLE_FLOUR_INSUFFICIENT');
  });
});

describe('케이스 3 — 왕복 변환', () => {
  it('리퀴드 → 뒤흐 → 리퀴드가 원본을 복원한다 (±0.01g)', () => {
    const original = baseRecipe();
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
      const input: DoughInput = {
        flours,
        water: flourSum * between(0.45, 0.95),
        salt: flourSum * between(0.015, 0.025),
        levain: {
          type: 'liquide',
          hydration: between(0.4, 1.3),
          grams: flourSum * between(0.1, 0.5),
        },
        extras: rand() < 0.3 ? [{ id: 'x', name: '씨앗', grams: between(10, 100) }] : [],
      };
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
  const stiffInput = (): DoughInput => ({
    flours: [{ id: 'f1', name: 'T65', grams: 1000 }],
    water: 50,
    salt: 20,
    levain: { type: 'dur', hydration: 0.5, grams: 600 },
    extras: [],
  });

  it('W_ADD_NEGATIVE 오류가 발생하고 최대 르방 질량이 제시된다', () => {
    const result = convertFixedMass(stiffInput(), 1);
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error.code).toBe('W_ADD_NEGATIVE');
    // F_total=1400, W_total=250 → max = min(1400×2, 250×2/1) = 500
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

  it('르방 속 밀가루가 총 밀가루를 초과하면 F_ADD_NEGATIVE', () => {
    const input: DoughInput = {
      flours: [{ id: 'f1', name: 'T65', grams: 10 }],
      water: 500,
      salt: 5,
      levain: { type: 'liquide', hydration: 1, grams: 600 },
      extras: [],
    };
    // h 1.0 → 0.25: F_lev 300 → 480 > F_total 310
    const result = convertFixedMass(input, 0.25);
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error.code).toBe('F_ADD_NEGATIVE');
  });
});

describe('보조 모드 — PFF 고정', () => {
  it('르방 질량과 첨가 물이 바뀌고 F_add·PFF·수분율은 유지된다', () => {
    const result = convertFixedPff(baseRecipe(), 0.5);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.after.levainFlour).toBeCloseTo(100, 6); // F_lev 고정
    expect(result.output.levain.grams).toBeCloseTo(150, 6); // 100 × 1.5
    expect(result.output.water).toBeCloseTo(670, 6); // 720 − 50
    expect(addedFlour(result.output)).toBeCloseTo(900, 6); // F_add 불변
    expect(result.after.pffPct).toBeCloseTo(10, 6);
    expect(result.after.hydrationPct).toBeCloseTo(72, 6);
  });
});
