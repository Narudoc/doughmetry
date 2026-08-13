import { describe, expect, it } from 'vitest';
import type { Recipe } from '../types';
import type { KeyValueStore } from './storage';
import { exportJson, importJson, loadRecipes, persistRecipes, validateRecipe } from './storage';

function memoryStore(): KeyValueStore {
  const map = new Map<string, string>();
  return {
    getItem: (k) => map.get(k) ?? null,
    setItem: (k, v) => void map.set(k, v),
    removeItem: (k) => void map.delete(k),
  };
}

const sampleRecipe = (): Recipe => ({
  id: 'r1',
  schemaVersion: 2,
  name: '캉파뉴',
  tags: ['캉파뉴'],
  createdAt: '2026-07-31T00:00:00.000Z',
  updatedAt: '2026-07-31T00:00:00.000Z',
  flours: [{ id: 'f1', name: 'T65', grams: 900 }],
  water: 620,
  bassinage: 50,
  salt: 20,
  levain: { type: 'liquide', hydration: 1, grams: 200 },
  liquids: [{ id: 'l1', name: '우유', grams: 100, waterRatio: 0.88 }],
  yeast: { type: 'fresh', grams: 10 },
  extras: [],
});

describe('validateRecipe', () => {
  it('정상 v2 레시피를 통과시킨다', () => {
    const v = validateRecipe(sampleRecipe());
    expect(v.ok).toBe(true);
    if (v.ok) {
      expect(v.recipe.bassinage).toBe(50);
      expect(v.recipe.liquids[0].waterRatio).toBe(0.88);
      expect(v.recipe.yeast.grams).toBe(10);
    }
  });

  it('v1 레시피는 v2로 마이그레이션된다 (bassinage 0, liquids [], yeast 0)', () => {
    const v1 = {
      id: 'old',
      schemaVersion: 1,
      name: '옛날 레시피',
      createdAt: '2026-07-01T00:00:00.000Z',
      updatedAt: '2026-07-01T00:00:00.000Z',
      flours: [{ id: 'f1', name: 'T65', grams: 900 }],
      water: 620,
      salt: 20,
      levain: { type: 'liquide', hydration: 1, grams: 200 },
      extras: [],
    };
    const v = validateRecipe(v1);
    expect(v.ok).toBe(true);
    if (v.ok) {
      expect(v.recipe.schemaVersion).toBe(2);
      expect(v.recipe.bassinage).toBe(0);
      expect(v.recipe.liquids).toEqual([]);
      expect(v.recipe.yeast).toEqual({ type: 'fresh', grams: 0 });
    }
  });

  it('schemaVersion이 지원 범위 밖이면 사유와 함께 거부한다', () => {
    const v = validateRecipe({ ...sampleRecipe(), schemaVersion: 3 });
    expect(v.ok).toBe(false);
    if (!v.ok) expect(v.reason).toContain('schemaVersion');
  });

  it('grams가 음수면 거부한다', () => {
    const bad = sampleRecipe();
    bad.flours[0].grams = -10;
    const v = validateRecipe(bad);
    expect(v.ok).toBe(false);
    if (!v.ok) expect(v.reason).toContain('grams');
  });

  it('liquids.waterRatio가 0~1을 벗어나면 거부한다', () => {
    const bad = sampleRecipe();
    bad.liquids[0].waterRatio = 88; // %가 아니라 소수여야 한다
    const v = validateRecipe(bad);
    expect(v.ok).toBe(false);
    if (!v.ok) expect(v.reason).toContain('waterRatio');
  });

  it('levain.hydration이 0 이하면 거부한다', () => {
    const bad = sampleRecipe();
    bad.levain.hydration = 0;
    const v = validateRecipe(bad);
    expect(v.ok).toBe(false);
    if (!v.ok) expect(v.reason).toContain('hydration');
  });
});

describe('내보내기 / 가져오기', () => {
  it('exportJson → importJson 왕복이 레시피를 보존한다', () => {
    const result = importJson(exportJson([sampleRecipe()]));
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.recipes).toHaveLength(1);
    expect(result.recipes[0].name).toBe('캉파뉴');
    expect(result.recipes[0].bassinage).toBe(50);
    expect(result.recipes[0].liquids[0].waterRatio).toBe(0.88);
    expect(result.recipes[0].yeast).toEqual({ type: 'fresh', grams: 10 });
  });

  it('JSON이 아니면 파싱 실패 사유를 알려준다', () => {
    const result = importJson('밀가루 900g');
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.reason).toContain('JSON 파싱 실패');
  });

  it('여러 건 중 하나라도 잘못되면 몇 번째가 왜 실패했는지 알려준다', () => {
    const broken = { ...sampleRecipe(), salt: '20g' };
    const result = importJson(JSON.stringify({ recipes: [sampleRecipe(), broken] }));
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.reason).toContain('2번째');
      expect(result.reason).toContain('salt');
    }
  });
});

describe('localStorage 저장', () => {
  it('persistRecipes → loadRecipes 왕복', () => {
    const store = memoryStore();
    persistRecipes([sampleRecipe()], store);
    const loaded = loadRecipes(store);
    expect(loaded).toHaveLength(1);
    expect(loaded[0].id).toBe('r1');
  });

  it('저장돼 있던 v1 레시피도 로드하며 마이그레이션한다', () => {
    const store = memoryStore();
    const v1 = { ...sampleRecipe(), schemaVersion: 1 } as Record<string, unknown>;
    delete v1.bassinage;
    delete v1.liquids;
    delete v1.yeast;
    store.setItem('levain-calc:recipes:v1', JSON.stringify([v1]));
    const loaded = loadRecipes(store);
    expect(loaded).toHaveLength(1);
    expect(loaded[0].schemaVersion).toBe(2);
    expect(loaded[0].bassinage).toBe(0);
  });

  it('손상된 데이터는 빈 배열로 복구한다', () => {
    const store = memoryStore();
    store.setItem('levain-calc:recipes:v1', '{broken');
    expect(loadRecipes(store)).toEqual([]);
  });
});
