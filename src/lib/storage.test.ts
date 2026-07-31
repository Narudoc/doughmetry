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
  schemaVersion: 1,
  name: '캉파뉴',
  tags: ['캉파뉴'],
  createdAt: '2026-07-31T00:00:00.000Z',
  updatedAt: '2026-07-31T00:00:00.000Z',
  flours: [{ id: 'f1', name: 'T65', grams: 900 }],
  water: 620,
  salt: 20,
  levain: { type: 'liquide', hydration: 1, grams: 200 },
  extras: [],
});

describe('validateRecipe', () => {
  it('정상 레시피를 통과시킨다', () => {
    const v = validateRecipe(sampleRecipe());
    expect(v.ok).toBe(true);
  });

  it('schemaVersion이 다르면 사유와 함께 거부한다', () => {
    const v = validateRecipe({ ...sampleRecipe(), schemaVersion: 2 });
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
    expect(result.recipes[0].levain.hydration).toBe(1);
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

  it('손상된 데이터는 빈 배열로 복구한다', () => {
    const store = memoryStore();
    store.setItem('levain-calc:recipes:v1', '{broken');
    expect(loadRecipes(store)).toEqual([]);
  });
});
