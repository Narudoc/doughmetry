import type { DoughInput, TargetSpec } from './lib/dough';
import { levainTypeFor, solveFromTarget } from './lib/dough';
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

/** 새 배합용 빈 입력 (iOS CalcState.emptyDoughInput과 같다) */
const emptyDoughInput = (): DoughInput => ({
  flours: [{ id: newId(), name: '', grams: 0 }],
  water: 0,
  bassinage: 0,
  salt: 0,
  levain: { type: 'liquide', hydration: 1, grams: 0 },
  liquids: [],
  yeast: { type: 'fresh', grams: 0 },
  extras: [],
});

export const emptyCalcState = (): CalcState => ({
  ...defaultCalcState(),
  name: '',
  input: emptyDoughInput(),
});

/** 새 배합 시작 전에 묻는 문구 (iOS와 같다) */
export const NEW_CALC_PROMPT = '새 배합을 시작할까요? 저장하지 않은 입력은 지워집니다.';

/**
 * 계산기 초기화 — 빈 배합 또는 예시 배합(캉파뉴)으로 새로 시작하고 레시피 연결을 끊는다 (iOS resetCalc(empty:)).
 * 시작한 그대로는 저장하지 않은 입력이 없다
 */
export function resetCalcState(empty: boolean): CalcState {
  const state = empty ? emptyCalcState() : defaultCalcState();
  return { ...state, savedSnapshot: calcSnapshot(state) };
}

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

export const defaultSettings = (): Settings => ({
  precision: 0.1,
  pctBasis: 'total',
  keepScreenAwake: true,
});

export function sanitizeSettings(loaded: unknown): Settings | null {
  if (typeof loaded !== 'object' || loaded === null) return null;
  const s = loaded as Settings;
  if (s.precision !== 1 && s.precision !== 0.1) return null;
  return {
    precision: s.precision,
    pctBasis: s.pctBasis === 'added' ? 'added' : 'total',
    lastExportAt:
      typeof s.lastExportAt === 'string' && !Number.isNaN(Date.parse(s.lastExportAt))
        ? s.lastExportAt
        : undefined,
    keepScreenAwake: s.keepScreenAwake !== false,
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

/**
 * 변환기로 넘기는 배합 — 분할 개수와 태그도 함께 넘겨 변환 결과를 저장할 때 잃지 않는다 (iOS sendToConverter와 같다).
 * 메모는 넘기지 않는다 — 만드는 법이 새 르방에 맞지 않을 수 있다
 */
export interface ConverterDough {
  name: string;
  input: DoughInput;
  pieces?: number;
  tags?: string[];
}

export function converterDoughFromRecipe(r: Recipe): ConverterDough {
  return {
    name: r.name,
    input: doughInputFromRecipe(r),
    pieces: r.pieces !== undefined && r.pieces > 0 ? r.pieces : undefined,
    tags: r.tags && r.tags.length > 0 ? [...r.tags] : undefined,
  };
}

/** 계산기 배합 — 태그는 계산기가 이어진 레시피의 것 (계산기 저장 다이얼로그가 미리 채우는 태그와 같다) */
export function converterDoughFromCalc(state: CalcState, recipes: Recipe[]): ConverterDough {
  const linked = state.recipeId ? recipes.find((r) => r.id === state.recipeId) : undefined;
  return {
    name: state.name,
    input: structuredClone(currentDoughInput(state)),
    pieces: currentPieces(state),
    tags: linked?.tags && linked.tags.length > 0 ? [...linked.tags] : undefined,
  };
}

/** 변환한 배합의 이름 — "캉파뉴 (뒤흐 50%)" (iOS ConverterView suggestedSaveName과 같다) */
export function convertedDoughName(name: string, hydrationPct: number): string {
  const type = levainTypeFor(hydrationPct / 100) === 'liquide' ? '리퀴드' : '뒤흐';
  return `${name.trim() || '이름 없는 배합'} (${type} ${hydrationPct}%)`;
}

/** 저장하지 않은 계산기 입력 위로 변환 결과를 보낼 때 묻는 문구 (iOS와 같다) */
export const SEND_TO_CALC_PROMPT = '변환 결과를 계산기로 보낼까요? 계산기에 저장하지 않은 입력은 지워집니다.';

/**
 * 변환기에서 계산기로 보낸 배합 (iOS AppModel.sendToCalculator와 같다) — 모드 A, 레시피에 잇지 않는다: 이으면 다음
 * 저장이 원본 레시피를 변환한 배합으로 덮어쓴다. 어디에도 저장되지 않은 배합이라 앞 상태의 기준을 그대로 둔다 —
 * 다른 레시피를 불러오거나 새 배합을 시작할 때 확인을 묻는다
 */
export function calcStateFromDough(d: ConverterDough, prev: CalcState): CalcState {
  return {
    ...defaultCalcState(),
    mode: 'A',
    name: d.name,
    input: structuredClone(d.input),
    pieces: d.pieces !== undefined && d.pieces > 0 ? d.pieces : 0,
    savedSnapshot: prev.savedSnapshot,
  };
}

/** 변환 결과로 만드는 새 레시피 — 원본의 분할 개수를 이어받는다 (개당 무게는 변환된 총 반죽에서 다시 나뉜다) */
export function recipeFromConversion(
  output: DoughInput,
  data: { name: string; tags: string[]; note?: string },
  pieces: number | undefined,
  id: string,
  now: string,
): Recipe {
  return {
    id,
    schemaVersion: 2,
    name: data.name,
    note: data.note,
    tags: data.tags.length > 0 ? data.tags : undefined,
    createdAt: now,
    updatedAt: now,
    ...structuredClone(output),
    pieces: pieces !== undefined && pieces > 0 ? pieces : undefined,
  };
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
 * 모드 B 저장은 화면에 없는 모드 A 입력이 마지막 기준과 같을 때만 기준을 새로 잡는다(calcStateAfterSave) —
 * 그 밖의 모드 B는 목표 역산 입력이 레시피에 남지 않으므로 저장하지 않은 입력으로 본다.
 */
export function isCalcDirty(state: CalcState, recipes: Recipe[]): boolean {
  const linked = state.recipeId ? recipes.find((r) => r.id === state.recipeId) : undefined;
  // 연결된 레시피가 지워졌으면 그 내용은 계산기에만 남아 있다 — 불러오기 전에 묻는다
  if (state.recipeId && !linked) return true;
  // 마지막으로 불러오거나 저장한 그대로면 깨끗하다 (모드 A 입력을 고치지 않은 모드 B 저장·목표 입력을 바꾼 채 저장·레시피 이름 변경 포함)
  if (state.savedSnapshot !== undefined && calcSnapshot(state) === state.savedSnapshot) return false;
  if (state.mode !== 'A') return true;
  const saved = parseSnapshot(state.savedSnapshot);
  // 기준 기록과 다른데 이어진 레시피가 없으면 그 내용은 계산기에만 있다
  if (saved && !linked) return true;
  // 레시피엔 목표 역산 입력이 없다 — 기준의 목표와 다르면 불러오거나 저장한 뒤 고친 것
  const base = linked ? calcStateFromRecipe(linked) : defaultCalcState();
  return (
    state.name !== base.name ||
    state.pieces !== base.pieces ||
    stableJson(state.target) !== stableJson(saved ? saved.target : base.target) ||
    doughContent(state.input) !== doughContent(base.input)
  );
}

/** calcSnapshot으로 남긴 기준 기록 — 없거나 읽을 수 없으면 undefined */
function parseSnapshot(snapshot: string | undefined): { input?: unknown; pieces?: unknown; target?: unknown } | undefined {
  if (snapshot === undefined) return undefined;
  try {
    const parsed: unknown = JSON.parse(snapshot);
    return parsed && typeof parsed === 'object' ? parsed : undefined;
  } catch {
    return undefined;
  }
}

/**
 * 마지막으로 불러오거나 저장한 모드 A 배합의 내용과 분할 개수 — 그 기록이 없으면 isCalcDirty처럼 연결된 레시피나
 * 처음 기본 배합. 알 수 없으면 undefined
 */
function baselineModeA(state: CalcState, recipes: Recipe[]): { input?: string; pieces?: number } {
  if (state.savedSnapshot !== undefined) {
    const saved = parseSnapshot(state.savedSnapshot);
    return {
      input: typeof saved?.input === 'string' ? saved.input : undefined,
      pieces: typeof saved?.pieces === 'number' ? saved.pieces : undefined,
    };
  }
  const linked = state.recipeId ? recipes.find((r) => r.id === state.recipeId) : undefined;
  if (state.recipeId && !linked) return {};
  if (linked) return { input: doughContent(doughInputFromRecipe(linked)), pieces: linked.pieces ?? 0 };
  const start = defaultCalcState();
  return { input: doughContent(start.input), pieces: start.pieces };
}

/**
 * 레시피로 저장한 직후의 계산기 상태 (iOS 저장 시트의 완료 처리 + markCalcSaved와 같다).
 * - 모드 A 저장만 계산기를 그 레시피에 잇는다. 모드 B 저장은 늘 새 레시피라, 이으면 다음 모드 A 저장이
 *   역산 레시피를 관계없는 모드 A 배합으로 덮어쓴다
 * - 저장한 지금 상태가 새 기준이 된다. 모드 B 저장은 역산 결과만 담으므로, 화면에 없는 모드 A 입력이
 *   마지막 기준과 다르면 기준을 그대로 둔다 — 그 입력은 아직 저장하지 않은 입력이다
 */
export function calcStateAfterSave(
  state: CalcState,
  saved: { name: string; id: string },
  recipes: Recipe[],
): CalcState {
  if (state.mode === 'B') {
    // 분할 개수도 모드 B에선 숨은 모드 A 입력이다
    const base = baselineModeA(state, recipes);
    if (doughContent(state.input) !== base.input || state.pieces !== base.pieces) return state;
    return { ...state, savedSnapshot: calcSnapshot(state) };
  }
  const next: CalcState = { ...state, name: saved.name, recipeId: saved.id };
  return { ...next, savedSnapshot: calcSnapshot(next) };
}

/**
 * 저장 다이얼로그가 덮어쓸 수 있는 레시피 — 모드 A에서 불러오거나 저장한 레시피만.
 * 목표 역산 결과는 바시나주·액체·이스트·기타 재료가 없으므로 모드 B로 덮어쓰면 그 재료가 사라진다
 */
export function overwriteTarget(state: CalcState, recipes: Recipe[]): Recipe | undefined {
  if (state.mode !== 'A' || !state.recipeId) return undefined;
  return recipes.find((r) => r.id === state.recipeId);
}

/** 계산기 이름 칸 아래 저장 상태 (iOS 계산기의 상태 줄과 같은 판단·문구) */
export type CalcSaveStatus = 'saved' | 'edited' | 'new' | 'example';

export const CALC_STATUS_LABEL: Record<CalcSaveStatus, string> = {
  saved: '저장된 레시피 · 변경 없음',
  edited: '수정됨 — 저장 안 됨',
  new: '새 배합 · 저장 안 됨',
  example: '예시 배합',
};

/**
 * 이어진 레시피가 있으면 저장하지 않은 입력이 있는지(isCalcDirty), 없으면 처음 예시 배합 그대로인지,
 * 이어지지 않은 저장(모드 B) 그대로인지. 이어진 레시피가 지워졌으면 저장하면 새 레시피가 되므로 새 배합이다
 */
export function calcSaveStatus(state: CalcState, recipes: Recipe[]): CalcSaveStatus {
  const linked = state.recipeId ? recipes.find((r) => r.id === state.recipeId) : undefined;
  if (linked) return isCalcDirty(state, recipes) ? 'edited' : 'saved';
  const snapshot = calcSnapshot(state);
  if (!state.recipeId && snapshot === calcSnapshot(defaultCalcState())) return 'example';
  // 모드 B 저장은 레시피와 잇지 않는다 — 저장한 그대로면 저장된 것. 모드 A 저장은 늘 레시피와 이으므로 잇지 않은
  // 모드 A는 기준과 같아도 새 배합이다 (새로 시작한 빈 배합, 변환기에서 받은 배합을 원래 레시피대로 되돌린 것 포함)
  if (!state.recipeId && state.mode === 'B' && snapshot === state.savedSnapshot) return 'saved';
  return 'new';
}
