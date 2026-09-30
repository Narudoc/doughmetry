import type { DoughInput, TargetSpec } from './lib/dough';
import { solveFromTarget } from './lib/dough';
import { newId } from './lib/id';
import { stableJson } from './lib/storage';
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
  /**
   * 마지막으로 불러오거나 저장한 상태의 내용(calcSnapshot) — 지금 내용이 이것과 같으면 저장하지 않은 입력이 없다.
   * iOS calcBaseline에 해당하고, 웹은 draft와 함께 저장돼 새로 고침 뒤에도 유지된다
   */
  savedSnapshot?: string;
}

const defaultDoughInput = (): DoughInput => ({
  flours: [{ id: newId(), name: 'T65', grams: 900 }],
  water: 620,
  bassinage: 0,
  salt: 20,
  levain: { type: 'liquide', hydration: 1, grams: 200 },
  liquids: [],
  yeast: { type: 'fresh', grams: 0 },
  extras: [],
});

export const defaultCalcState = (): CalcState => ({
  mode: 'A',
  name: '캉파뉴',
  input: defaultDoughInput(),
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

/** 저장된 draft가 v1 형태여도 새 필드를 기본값으로 채워 살린다 */
export function sanitizeDoughInput(x: unknown): DoughInput | null {
  if (typeof x !== 'object' || x === null) return null;
  const d = x as DoughInput;
  if (!d.levain || !Array.isArray(d.flours)) return null;
  return {
    ...defaultDoughInput(),
    ...d,
    bassinage: typeof d.bassinage === 'number' ? d.bassinage : 0,
    liquids: Array.isArray(d.liquids) ? d.liquids : [],
    yeast:
      d.yeast && typeof d.yeast.grams === 'number'
        ? { type: d.yeast.type === 'instant' ? 'instant' : 'fresh', grams: d.yeast.grams }
        : { type: 'fresh', grams: 0 },
  };
}

export function sanitizeCalcState(loaded: unknown): CalcState | null {
  if (typeof loaded !== 'object' || loaded === null) return null;
  const s = loaded as CalcState;
  const input = sanitizeDoughInput(s.input);
  if (!input || !s.target) return null;
  return { ...defaultCalcState(), ...s, input };
}

export function sanitizeSettings(loaded: unknown): Settings | null {
  if (typeof loaded !== 'object' || loaded === null) return null;
  const s = loaded as Settings;
  if (s.precision !== 1 && s.precision !== 0.1) return null;
  return {
    precision: s.precision,
    pctBasis: s.pctBasis === 'added' ? 'added' : 'total',
  };
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

export function doughInputFromRecipe(r: Recipe): DoughInput {
  return structuredClone({
    flours: r.flours,
    water: r.water,
    bassinage: r.bassinage,
    salt: r.salt,
    levain: r.levain,
    liquids: r.liquids,
    yeast: r.yeast,
    extras: r.extras,
  });
}

export function calcStateFromRecipe(r: Recipe): CalcState {
  const state: CalcState = {
    ...defaultCalcState(),
    mode: 'A',
    name: r.name,
    recipeId: r.id,
    input: doughInputFromRecipe(r),
    pieces: r.pieces ?? 0,
  };
  return { ...state, savedSnapshot: calcSnapshot(state) };
}

/** 재료 행 id를 뺀 배합 — 불러올 때마다·역산할 때마다 새로 붙는 id는 내용이 아니다 */
function doughContent(d: DoughInput): string {
  const strip = <T extends { id: string }>(rows: T[]) => rows.map(({ id: _id, ...rest }) => rest);
  return stableJson({
    ...d,
    flours: strip(d.flours),
    liquids: strip(d.liquids),
    extras: strip(d.extras),
  });
}

/** 저장하지 않은 계산기 입력 위로 레시피를 불러올 때 묻는 문구 (iOS와 같다) */
export const LOAD_OVER_DIRTY_PROMPT = '레시피를 불러올까요? 저장하지 않은 입력은 지워집니다.';

/** 저장하지 않은 입력을 판단하는 내용 — 재료 행 id는 뺀다 */
export function calcSnapshot(s: CalcState): string {
  return stableJson({
    mode: s.mode,
    name: s.name,
    pieces: s.pieces,
    target: s.target,
    input: doughContent(s.input),
  });
}

/**
 * 계산기에 저장하지 않은 입력이 있는가 — 불러오기가 덮어쓰기 전에 확인한다 (iOS AppModel.calcIsDirty와 같은 판단).
 * 마지막으로 불러오거나 저장한 상태와 같으면 깨끗하다. 그 기록이 없으면(예전 draft) 연결된 레시피를 불러온 상태나
 * 처음 기본 배합과 비교한다.
 * 목표 역산(모드 B) 입력은 레시피에 저장되지 않으므로 모드 B는 항상 저장하지 않은 입력으로 본다.
 */
export function isCalcDirty(state: CalcState, recipes: Recipe[]): boolean {
  const linked = state.recipeId ? recipes.find((r) => r.id === state.recipeId) : undefined;
  // 연결된 레시피가 지워졌으면 그 내용은 계산기에만 남아 있다 — 불러오기 전에 묻는다
  if (state.recipeId && !linked) return true;
  // 마지막으로 불러오거나 저장한 그대로면 깨끗하다 (모드 B 저장·목표 입력을 바꾼 채 저장·레시피 이름 변경 포함)
  if (state.savedSnapshot !== undefined && calcSnapshot(state) === state.savedSnapshot) return false;
  if (state.mode !== 'A') return true;
  const base = linked ? calcStateFromRecipe(linked) : defaultCalcState();
  return (
    state.name !== base.name ||
    state.pieces !== base.pieces ||
    stableJson(state.target) !== stableJson(base.target) ||
    doughContent(state.input) !== doughContent(base.input)
  );
}
