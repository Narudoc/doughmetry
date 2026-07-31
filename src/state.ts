import type { DoughInput, TargetSpec } from './lib/dough';
import { solveFromTarget } from './lib/dough';
import { newId } from './lib/id';
import type { Recipe, Settings } from './types';

export type CalcMode = 'A' | 'B';

/** 모드 B 입력 폼 — 사용자 친화적으로 % 단위로 보관하고 계산 시 소수로 변환 */
export interface TargetForm {
  byPieces: boolean;
  doughWeight: number;
  pieces: number;
  pieceWeight: number;
  hydrationPct: number;
  saltPct: number;
  pffPct: number;
  levainHydrationPct: number;
}

export interface CalcState {
  mode: CalcMode;
  name: string;
  /** 저장된 레시피에서 불러온 경우 — 덮어쓰기 저장에 사용 */
  recipeId?: string;
  input: DoughInput;
  target: TargetForm;
  /** 모드 A의 분할 개수 (표시용) */
  pieces: number;
}

export const defaultCalcState = (): CalcState => ({
  mode: 'A',
  name: '캉파뉴',
  input: {
    flours: [{ id: newId(), name: 'T65', grams: 900 }],
    water: 620,
    salt: 20,
    levain: { type: 'liquide', hydration: 1, grams: 200 },
    extras: [],
  },
  target: {
    byPieces: false,
    doughWeight: 1740,
    pieces: 2,
    pieceWeight: 870,
    hydrationPct: 72,
    saltPct: 2,
    pffPct: 10,
    levainHydrationPct: 100,
  },
  pieces: 0,
});

export function sanitizeCalcState(loaded: unknown): CalcState | null {
  if (typeof loaded !== 'object' || loaded === null) return null;
  const s = loaded as CalcState;
  if (!s.input || !s.input.levain || !Array.isArray(s.input.flours) || !s.target) return null;
  return { ...defaultCalcState(), ...s };
}

export function sanitizeSettings(loaded: unknown): Settings | null {
  if (typeof loaded !== 'object' || loaded === null) return null;
  const p = (loaded as Settings).precision;
  return p === 1 || p === 0.1 ? { precision: p } : null;
}

export function targetSpecFromForm(t: TargetForm): TargetSpec {
  return {
    doughWeight: t.byPieces ? t.pieces * t.pieceWeight : t.doughWeight,
    hydration: t.hydrationPct / 100,
    saltRatio: t.saltPct / 100,
    pff: t.pffPct / 100,
    levainHydration: t.levainHydrationPct / 100,
  };
}

/** 현재 계산기 상태의 배합 — 모드 A는 그대로, 모드 B는 역산 결과 */
export function currentDoughInput(state: CalcState): DoughInput {
  return state.mode === 'A' ? state.input : solveFromTarget(targetSpecFromForm(state.target));
}

export function currentPieces(state: CalcState): number | undefined {
  if (state.mode === 'A') return state.pieces > 0 ? state.pieces : undefined;
  return state.target.byPieces && state.target.pieces > 0 ? state.target.pieces : undefined;
}

export function calcStateFromRecipe(r: Recipe): CalcState {
  const base = defaultCalcState();
  return {
    ...base,
    mode: 'A',
    name: r.name,
    recipeId: r.id,
    input: structuredClone({
      flours: r.flours,
      water: r.water,
      salt: r.salt,
      levain: r.levain,
      extras: r.extras,
    }),
    pieces: r.pieces ?? 0,
  };
}

export function doughInputFromRecipe(r: Recipe): DoughInput {
  return structuredClone({
    flours: r.flours,
    water: r.water,
    salt: r.salt,
    levain: r.levain,
    extras: r.extras,
  });
}
