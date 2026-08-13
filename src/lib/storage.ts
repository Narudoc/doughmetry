import type { Extra, Flour, Liquid, Recipe, Yeast } from '../types';
import { levainTypeFor } from './dough';
import { newId } from './id';

export const RECIPES_KEY = 'levain-calc:recipes:v1';
export const DRAFT_KEY = 'levain-calc:draft:v1';
export const SETTINGS_KEY = 'levain-calc:settings:v1';

export interface KeyValueStore {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

const browserStore: KeyValueStore | null =
  typeof localStorage === 'undefined' ? null : localStorage;

export function loadJson<T>(key: string, store: KeyValueStore | null = browserStore): T | null {
  if (!store) return null;
  try {
    const raw = store.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

export function saveJson(
  key: string,
  value: unknown,
  store: KeyValueStore | null = browserStore,
): void {
  if (!store) return;
  try {
    store.setItem(key, JSON.stringify(value));
  } catch {
    // 저장 공간 초과 등 — 앱 동작은 계속
  }
}

// ── 레시피 스키마 검증 (v1 → v2 마이그레이션 포함) ─────────────────

const isNonNegNumber = (x: unknown): x is number =>
  typeof x === 'number' && Number.isFinite(x) && x >= 0;

function parseRows(
  x: unknown,
  field: string,
): { ok: true; value: Flour[] | Extra[] } | { ok: false; reason: string } {
  if (x === undefined) return { ok: true, value: [] };
  if (!Array.isArray(x)) return { ok: false, reason: `${field}가 배열이 아닙니다` };
  const rows: Flour[] = [];
  for (let i = 0; i < x.length; i++) {
    const row = x[i] as Record<string, unknown>;
    if (typeof row !== 'object' || row === null) {
      return { ok: false, reason: `${field}[${i}]가 객체가 아닙니다` };
    }
    if (!isNonNegNumber(row.grams)) {
      return { ok: false, reason: `${field}[${i}].grams가 0 이상의 숫자가 아닙니다` };
    }
    rows.push({
      id: typeof row.id === 'string' && row.id ? row.id : newId(),
      name: typeof row.name === 'string' ? row.name : '',
      grams: row.grams,
    });
  }
  return { ok: true, value: rows };
}

function parseLiquids(
  x: unknown,
): { ok: true; value: Liquid[] } | { ok: false; reason: string } {
  if (x === undefined) return { ok: true, value: [] };
  if (!Array.isArray(x)) return { ok: false, reason: 'liquids가 배열이 아닙니다' };
  const rows: Liquid[] = [];
  for (let i = 0; i < x.length; i++) {
    const row = x[i] as Record<string, unknown>;
    if (typeof row !== 'object' || row === null) {
      return { ok: false, reason: `liquids[${i}]가 객체가 아닙니다` };
    }
    if (!isNonNegNumber(row.grams)) {
      return { ok: false, reason: `liquids[${i}].grams가 0 이상의 숫자가 아닙니다` };
    }
    const ratio = row.waterRatio;
    if (typeof ratio !== 'number' || !Number.isFinite(ratio) || ratio < 0 || ratio > 1) {
      return {
        ok: false,
        reason: `liquids[${i}].waterRatio가 0~1 사이의 소수가 아닙니다 (예: 0.88)`,
      };
    }
    rows.push({
      id: typeof row.id === 'string' && row.id ? row.id : newId(),
      name: typeof row.name === 'string' ? row.name : '',
      grams: row.grams,
      waterRatio: ratio,
    });
  }
  return { ok: true, value: rows };
}

function parseYeast(x: unknown): { ok: true; value: Yeast } | { ok: false; reason: string } {
  if (x === undefined) return { ok: true, value: { type: 'fresh', grams: 0 } };
  const y = x as Record<string, unknown>;
  if (typeof y !== 'object' || y === null) return { ok: false, reason: 'yeast가 객체가 아닙니다' };
  if (!isNonNegNumber(y.grams)) {
    return { ok: false, reason: 'yeast.grams가 0 이상의 숫자가 아닙니다' };
  }
  return {
    ok: true,
    value: { type: y.type === 'instant' ? 'instant' : 'fresh', grams: y.grams },
  };
}

export function validateRecipe(
  x: unknown,
): { ok: true; recipe: Recipe } | { ok: false; reason: string } {
  if (typeof x !== 'object' || x === null || Array.isArray(x)) {
    return { ok: false, reason: '레시피가 객체가 아닙니다' };
  }
  const r = x as Record<string, unknown>;

  // v1 레시피는 v2로 마이그레이션 (bassinage 0, liquids [], yeast 0)
  if (r.schemaVersion !== 1 && r.schemaVersion !== 2) {
    return {
      ok: false,
      reason: `지원하지 않는 schemaVersion입니다 (기대: 1 또는 2, 실제: ${JSON.stringify(r.schemaVersion)})`,
    };
  }
  if (typeof r.name !== 'string' || r.name.trim() === '') {
    return { ok: false, reason: 'name이 비어 있습니다' };
  }

  const flours = parseRows(r.flours, 'flours');
  if (!flours.ok) return { ok: false, reason: flours.reason };
  const extras = parseRows(r.extras, 'extras');
  if (!extras.ok) return { ok: false, reason: extras.reason };
  const liquids = parseLiquids(r.liquids);
  if (!liquids.ok) return { ok: false, reason: liquids.reason };
  const yeast = parseYeast(r.yeast);
  if (!yeast.ok) return { ok: false, reason: yeast.reason };

  if (!isNonNegNumber(r.water)) return { ok: false, reason: 'water가 0 이상의 숫자가 아닙니다' };
  if (r.bassinage !== undefined && !isNonNegNumber(r.bassinage)) {
    return { ok: false, reason: 'bassinage가 0 이상의 숫자가 아닙니다' };
  }
  if (!isNonNegNumber(r.salt)) return { ok: false, reason: 'salt가 0 이상의 숫자가 아닙니다' };

  const lev = r.levain as Record<string, unknown> | undefined;
  if (typeof lev !== 'object' || lev === null) {
    return { ok: false, reason: 'levain이 없습니다' };
  }
  if (!isNonNegNumber(lev.grams)) {
    return { ok: false, reason: 'levain.grams가 0 이상의 숫자가 아닙니다' };
  }
  if (typeof lev.hydration !== 'number' || !Number.isFinite(lev.hydration) || lev.hydration <= 0) {
    return { ok: false, reason: 'levain.hydration이 0보다 큰 숫자가 아닙니다 (소수, 예: 1.0)' };
  }

  const tags = Array.isArray(r.tags)
    ? r.tags.filter((t): t is string => typeof t === 'string')
    : undefined;

  const recipe: Recipe = {
    id: typeof r.id === 'string' && r.id ? r.id : newId(),
    schemaVersion: 2,
    name: r.name.trim(),
    note: typeof r.note === 'string' ? r.note : undefined,
    tags: tags && tags.length > 0 ? tags : undefined,
    createdAt: typeof r.createdAt === 'string' ? r.createdAt : new Date().toISOString(),
    updatedAt: typeof r.updatedAt === 'string' ? r.updatedAt : new Date().toISOString(),
    flours: flours.value,
    water: r.water,
    bassinage: isNonNegNumber(r.bassinage) ? r.bassinage : 0,
    salt: r.salt,
    levain: {
      type: lev.type === 'liquide' || lev.type === 'dur' ? lev.type : levainTypeFor(lev.hydration),
      hydration: lev.hydration,
      grams: lev.grams,
      flourName: typeof lev.flourName === 'string' ? lev.flourName : undefined,
    },
    liquids: liquids.value,
    yeast: yeast.value,
    extras: extras.value,
    targetDoughWeight: isNonNegNumber(r.targetDoughWeight) ? r.targetDoughWeight : undefined,
    pieces: isNonNegNumber(r.pieces) ? r.pieces : undefined,
  };
  return { ok: true, recipe };
}

// ── 저장/불러오기 ──────────────────────────────────────────────────

export function loadRecipes(store: KeyValueStore | null = browserStore): Recipe[] {
  const raw = loadJson<unknown>(RECIPES_KEY, store);
  if (!Array.isArray(raw)) return [];
  const recipes: Recipe[] = [];
  for (const item of raw) {
    const v = validateRecipe(item);
    if (v.ok) recipes.push(v.recipe);
  }
  return recipes;
}

export function persistRecipes(recipes: Recipe[], store: KeyValueStore | null = browserStore): void {
  saveJson(RECIPES_KEY, recipes, store);
}

// ── JSON 내보내기 / 가져오기 ───────────────────────────────────────

export function exportJson(recipes: Recipe[]): string {
  return JSON.stringify(
    { app: 'levain-calc', schemaVersion: 2, exportedAt: new Date().toISOString(), recipes },
    null,
    2,
  );
}

export function importJson(
  text: string,
): { ok: true; recipes: Recipe[] } | { ok: false; reason: string } {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (e) {
    return { ok: false, reason: `JSON 파싱 실패: ${e instanceof Error ? e.message : String(e)}` };
  }

  let items: unknown[];
  if (Array.isArray(parsed)) {
    items = parsed;
  } else if (typeof parsed === 'object' && parsed !== null && 'recipes' in parsed) {
    const rs = (parsed as { recipes: unknown }).recipes;
    if (!Array.isArray(rs)) return { ok: false, reason: 'recipes 필드가 배열이 아닙니다' };
    items = rs;
  } else if (typeof parsed === 'object' && parsed !== null) {
    items = [parsed]; // 단일 레시피 객체
  } else {
    return { ok: false, reason: '레시피 목록을 찾을 수 없습니다' };
  }

  if (items.length === 0) return { ok: false, reason: '가져올 레시피가 없습니다' };

  const recipes: Recipe[] = [];
  for (let i = 0; i < items.length; i++) {
    const v = validateRecipe(items[i]);
    if (!v.ok) return { ok: false, reason: `${i + 1}번째 레시피: ${v.reason}` };
    recipes.push(v.recipe);
  }
  return { ok: true, recipes };
}
