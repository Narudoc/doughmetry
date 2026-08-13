import type { Flour, LevainType, Recipe, YeastType } from '../types';
import { newId } from './id';

/**
 * 사워도우 반죽 계산 — 순수 함수 모듈.
 *
 * 규칙: 수분율·소금·PFF는 모두 총 밀가루(F_total = 첨가 밀가루 + 르방 속 밀가루) 기준.
 * 총 물 = 본반죽 물 + 바시나주 + 르방 속 물 + 액체 재료의 수분 (grams × waterRatio).
 * 내부 계산은 full precision으로 하고, 반올림은 표시 계층(format.ts)에서만 한다.
 */

export type DoughInput = Pick<
  Recipe,
  'flours' | 'water' | 'bassinage' | 'salt' | 'levain' | 'liquids' | 'yeast' | 'extras'
>;

export const DEFAULT_LEVAIN_HYDRATION: Record<LevainType, number> = {
  liquide: 1,
  dur: 0.5,
};

/** 액체 재료 수분율 프리셋 (소수). 출처: USDA FoodData Central per 100g */
export const LIQUID_PRESETS = {
  milk: { name: '우유', waterRatio: 0.88 }, // 전유 3.25% milkfat: 물 88.1g/100g
  egg: { name: '계란', waterRatio: 0.76 }, // 전란 생: 물 76.15g/100g
} as const;

/** 인스턴트 드라이 이스트 = 생이스트 × 0.4 */
export const IDY_FACTOR = 0.4;

export function convertYeast(grams: number, from: YeastType, to: YeastType): number {
  if (from === to) return grams;
  return from === 'fresh' ? grams * IDY_FACTOR : grams / IDY_FACTOR;
}

/** 수분율로 르방 타입 라벨을 정한다 (경계 0.75). */
export function levainTypeFor(hydration: number): LevainType {
  return hydration >= 0.75 ? 'liquide' : 'dur';
}

const EPS = 1e-9;
const sum = (xs: number[]): number => xs.reduce((a, b) => a + b, 0);

export const addedFlourTotal = (input: DoughInput): number =>
  sum(input.flours.map((f) => f.grams));

/** F_lev = L / (1 + h), W_lev = L − F_lev */
export function levainBreakdown(levain: { grams: number; hydration: number }): {
  flour: number;
  water: number;
} {
  const flour = levain.grams / (1 + levain.hydration);
  return { flour, water: levain.grams - flour };
}

export interface DoughStats {
  levainFlour: number; // F_lev
  levainWater: number; // W_lev
  liquidWater: number; // Σ liquid.grams × waterRatio
  totalFlour: number; // F_total
  totalWater: number; // W_total = 본반죽 물 + 바시나주 + W_lev + 액체 수분
  hydrationPct: number; // H = W_total / F_total × 100
  saltPct: number; // salt / F_total × 100
  pffPct: number; // F_lev / F_total × 100
  yeastPct: number; // yeast.grams / F_total × 100 (선택한 타입 기준)
  doughWeight: number; // D = 모든 재료 무게 합
  flourPcts: Array<{ id: string; pct: number }>; // 각 밀가루의 총 밀가루 대비 %
  liquidPcts: Array<{ id: string; pct: number }>;
  extraPcts: Array<{ id: string; pct: number }>;
}

export function computeStats(input: DoughInput): DoughStats {
  const { flour: levainFlour, water: levainWater } = levainBreakdown(input.levain);
  const addedFlour = addedFlourTotal(input);
  const liquidWater = sum(input.liquids.map((l) => l.grams * l.waterRatio));
  const liquidsTotal = sum(input.liquids.map((l) => l.grams));
  const extrasTotal = sum(input.extras.map((e) => e.grams));
  const totalFlour = addedFlour + levainFlour;
  const totalWater = input.water + input.bassinage + levainWater + liquidWater;
  const doughWeight =
    addedFlour +
    input.water +
    input.bassinage +
    input.levain.grams +
    input.salt +
    liquidsTotal +
    input.yeast.grams +
    extrasTotal;
  const pctOfFlour = (g: number): number => (totalFlour > EPS ? (g / totalFlour) * 100 : 0);
  return {
    levainFlour,
    levainWater,
    liquidWater,
    totalFlour,
    totalWater,
    hydrationPct: pctOfFlour(totalWater),
    saltPct: pctOfFlour(input.salt),
    pffPct: pctOfFlour(levainFlour),
    yeastPct: pctOfFlour(input.yeast.grams),
    doughWeight,
    flourPcts: input.flours.map((f) => ({ id: f.id, pct: pctOfFlour(f.grams) })),
    liquidPcts: input.liquids.map((l) => ({ id: l.id, pct: pctOfFlour(l.grams) })),
    extraPcts: input.extras.map((e) => ({ id: e.id, pct: pctOfFlour(e.grams) })),
  };
}

const emptyExtras = (): Pick<DoughInput, 'bassinage' | 'liquids' | 'yeast' | 'extras'> => ({
  bassinage: 0,
  liquids: [],
  yeast: { type: 'fresh', grams: 0 },
  extras: [],
});

/** 모드 B — 목표 반죽 무게에서 역산. 비율 값은 전부 소수(0.72 = 72%).
 *  v2에서도 밀가루·물·소금·르방만 역산한다 (바시나주·액체·이스트는 모드 A에서). */
export interface TargetSpec {
  doughWeight: number; // D
  hydration: number; // H
  saltRatio: number; // s
  pff: number; // p
  levainHydration: number; // h
  othersRatio?: number; // o = 기타 재료의 총 밀가루 대비 비율 합 (기본 0)
}

export function solveFromTarget(spec: TargetSpec): DoughInput {
  const o = spec.othersRatio ?? 0;
  const totalFlour = spec.doughWeight / (1 + spec.hydration + spec.saltRatio + o);
  const levainFlour = spec.pff * totalFlour;
  const levainGrams = levainFlour * (1 + spec.levainHydration);
  const levainWater = levainGrams - levainFlour;
  return {
    flours: [{ id: newId(), name: '밀가루', grams: totalFlour - levainFlour }],
    water: spec.hydration * totalFlour - levainWater,
    salt: spec.saltRatio * totalFlour,
    levain: {
      type: levainTypeFor(spec.levainHydration),
      hydration: spec.levainHydration,
      grams: levainGrams,
    },
    ...emptyExtras(),
  };
}

/** 르방 변환 시 ΔF를 첨가 밀가루 여러 행에 배분하는 방식 */
export type DeltaDistribution =
  | { mode: 'pro-rata' } // 기본: 현재 비율대로 비례 배분
  | { mode: 'single'; flourId: string }; // 특정 밀가루에서만 증감

export type ConvertError =
  | { code: 'F_ADD_NEGATIVE'; maxLevainGrams: number } // 르방 속 밀가루가 총 밀가루를 초과
  | { code: 'W_ADD_NEGATIVE'; maxLevainGrams: number } // 본반죽 물이 부족한 경우
  | { code: 'SINGLE_FLOUR_INSUFFICIENT'; flourId: string; needed: number; available: number };

export interface ConvertSuccess {
  ok: true;
  output: DoughInput;
  before: DoughStats;
  after: DoughStats;
  /** ΔF = F_lev_new − F_lev_old (르방 속 밀가루 증가량, g) */
  deltaFlour: number;
}

export type ConvertResult = ConvertSuccess | { ok: false; error: ConvertError };

/**
 * 르방 질량 고정 모드에서, 원본의 총 밀가루·총 물을 유지하면서
 * 목표 수분율 h_new로 변환 가능한 최대 르방 질량.
 * 변환이 조정할 수 있는 물은 본반죽 물뿐이므로(바시나주·액체 수분은 고정),
 * 물 쪽 상한은 조정 가능 풀(본반죽 물 + 르방 속 물) 기준이다.
 * F_add_new ≥ 0 → L ≤ F_total × (1 + h_new)
 * W_add_new ≥ 0 → L ≤ (W_add + W_lev) × (1 + h_new) / h_new
 */
export function maxConvertibleLevain(input: DoughInput, newHydration: number): number {
  const s = computeStats(input);
  const adjustableWater = input.water + s.levainWater;
  const byFlour = s.totalFlour * (1 + newHydration);
  const byWater =
    newHydration > EPS ? (adjustableWater * (1 + newHydration)) / newHydration : Infinity;
  return Math.min(byFlour, byWater);
}

function distributeFlourDelta(
  flours: Flour[],
  delta: number, // 첨가 밀가루 총량에 더할 양 (음수 = 감소)
  dist: DeltaDistribution,
): { value: Flour[] } | { error: ConvertError } {
  if (Math.abs(delta) < EPS) return { value: flours.map((f) => ({ ...f })) };

  if (dist.mode === 'single') {
    const target = flours.find((f) => f.id === dist.flourId);
    if (target) {
      const next = target.grams + delta;
      if (next < -EPS) {
        return {
          error: {
            code: 'SINGLE_FLOUR_INSUFFICIENT',
            flourId: target.id,
            needed: -delta,
            available: target.grams,
          },
        };
      }
      return {
        value: flours.map((f) =>
          f.id === target.id ? { ...f, grams: Math.max(0, next) } : { ...f },
        ),
      };
    }
    // 지정한 밀가루 행이 없으면 비례 배분으로 진행
  }

  if (flours.length === 0) {
    return { value: delta > 0 ? [{ id: newId(), name: '밀가루', grams: delta }] : [] };
  }
  const total = sum(flours.map((f) => f.grams));
  if (total < EPS) {
    const each = delta / flours.length;
    return { value: flours.map((f) => ({ ...f, grams: Math.max(0, f.grams + each) })) };
  }
  const ratio = 1 + delta / total;
  return { value: flours.map((f) => ({ ...f, grams: Math.max(0, f.grams * ratio) })) };
}

/** 변환 결과에서 바시나주·액체·이스트·기타는 그대로 복사한다 */
const cloneFixedParts = (input: DoughInput) => ({
  bassinage: input.bassinage,
  liquids: input.liquids.map((l) => ({ ...l })),
  yeast: { ...input.yeast },
  extras: input.extras.map((e) => ({ ...e })),
});

/**
 * 기본 모드 — 르방 질량 L 고정, 총 수분율 보존.
 * ΔF = L/(1+h_new) − L/(1+h_old)를 첨가 밀가루에서 빼고 본반죽 물에 더한다.
 * 총 밀가루·총 물·총 수분율·총 반죽 무게가 모두 보존된다 (PFF는 변함).
 */
export function convertFixedMass(
  input: DoughInput,
  newHydration: number,
  dist: DeltaDistribution = { mode: 'pro-rata' },
): ConvertResult {
  const before = computeStats(input);
  const levainFlourNew = input.levain.grams / (1 + newHydration);
  const deltaFlour = levainFlourNew - before.levainFlour;
  const addedFlourNew = before.totalFlour - levainFlourNew;
  const addedWaterNew = input.water + deltaFlour;

  if (addedFlourNew < -EPS) {
    return {
      ok: false,
      error: { code: 'F_ADD_NEGATIVE', maxLevainGrams: maxConvertibleLevain(input, newHydration) },
    };
  }
  if (addedWaterNew < -EPS) {
    return {
      ok: false,
      error: { code: 'W_ADD_NEGATIVE', maxLevainGrams: maxConvertibleLevain(input, newHydration) },
    };
  }

  const flours = distributeFlourDelta(input.flours, -deltaFlour, dist);
  if ('error' in flours) return { ok: false, error: flours.error };

  const output: DoughInput = {
    flours: flours.value,
    water: Math.max(0, addedWaterNew),
    salt: input.salt,
    levain: { ...input.levain, type: levainTypeFor(newHydration), hydration: newHydration },
    ...cloneFixedParts(input),
  };
  return { ok: true, output, before, after: computeStats(output), deltaFlour };
}

/**
 * 보조 모드 — PFF(F_lev) 고정. 르방 질량 L과 본반죽 물이 변하고,
 * 총 밀가루·총 물·총 수분율·PFF는 유지된다.
 */
export function convertFixedPff(input: DoughInput, newHydration: number): ConvertResult {
  const before = computeStats(input);
  const levainFlour = before.levainFlour; // 고정
  const levainGramsNew = levainFlour * (1 + newHydration);
  const levainWaterNew = levainGramsNew - levainFlour;
  const addedWaterNew = input.water + before.levainWater - levainWaterNew;

  if (addedWaterNew < -EPS) {
    // F_lev ≤ (본반죽 물 + W_lev) / h_new → 원본 수분율 기준 최대 르방 질량으로 환산
    const maxLevainGrams =
      newHydration > EPS
        ? ((input.water + before.levainWater) / newHydration) * (1 + input.levain.hydration)
        : Infinity;
    return { ok: false, error: { code: 'W_ADD_NEGATIVE', maxLevainGrams } };
  }

  const output: DoughInput = {
    flours: input.flours.map((f) => ({ ...f })),
    water: Math.max(0, addedWaterNew),
    salt: input.salt,
    levain: {
      ...input.levain,
      type: levainTypeFor(newHydration),
      hydration: newHydration,
      grams: levainGramsNew,
    },
    ...cloneFixedParts(input),
  };
  return { ok: true, output, before, after: computeStats(output), deltaFlour: 0 };
}

/**
 * 총 밀가루·총 물을 유지한 채 르방 질량만 바꾼 배합을 만든다.
 * 첨가 밀가루의 증감분은 비례 배분, 물 보정은 본반죽 물에서.
 * (오류 시 "최대 르방 질량 적용"에 사용)
 */
export function withLevainMass(input: DoughInput, grams: number): DoughInput {
  const before = computeStats(input);
  const levainFlour = grams / (1 + input.levain.hydration);
  const levainWater = grams - levainFlour;
  const targetAddedFlour = before.totalFlour - levainFlour;
  const dist = distributeFlourDelta(
    input.flours,
    targetAddedFlour - addedFlourTotal(input),
    { mode: 'pro-rata' },
  );
  return {
    ...input,
    flours: 'value' in dist ? dist.value : input.flours.map((f) => ({ ...f })),
    water: Math.max(0, input.water + before.levainWater - levainWater),
    levain: { ...input.levain, grams },
    ...cloneFixedParts(input),
  };
}
