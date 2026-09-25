import { describe, expect, it } from 'vitest';
import type { Recipe } from '../types';
import type { KeyValueStore } from './storage';
import {
  exportJson,
  importJson,
  loadRecipeList,
  loadRecipes,
  mergeImported,
  persistRecipes,
  reloadRecipes,
  saveJson,
  updateRecipes,
  validateRecipe,
} from './storage';

function memoryStore(): KeyValueStore {
  const map = new Map<string, string>();
  return {
    getItem: (k) => map.get(k) ?? null,
    setItem: (k, v) => void map.set(k, v),
    removeItem: (k) => void map.delete(k),
  };
}

/** failing이 true인 동안 쓰기마다 QuotaExceededError를 던지는 저장소 */
function quotaStore(): KeyValueStore & { failing: boolean } {
  const inner = memoryStore();
  const store = {
    failing: true,
    getItem: inner.getItem,
    removeItem: inner.removeItem,
    setItem(k: string, v: string) {
      if (store.failing) throw new DOMException('quota exceeded', 'QuotaExceededError');
      inner.setItem(k, v);
    },
  };
  return store;
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

describe('여러 탭에서 저장 (저장소 기준 읽기-적용-쓰기)', () => {
  it('먼저 연 탭이 나중에 저장해도 다른 탭이 저장한 레시피가 남는다', () => {
    const store = memoryStore();
    persistRecipes([sampleRecipe()], store);
    // 두 탭이 같은 시점에 목록을 읽어 둔 상태
    const tabA = loadRecipeList(store);
    const tabB = loadRecipeList(store);
    expect(tabA.recipes).toHaveLength(1);
    expect(tabB.recipes).toHaveLength(1);

    updateRecipes(
      (cur) => [...cur, { ...sampleRecipe(), id: 'b1', name: 'B 탭 레시피' }],
      tabB,
      store,
    );
    const afterA = updateRecipes(
      (cur) => [...cur, { ...sampleRecipe(), id: 'a1', name: 'A 탭 레시피' }],
      tabA,
      store,
    );

    expect(afterA.persisted).toBe(true);
    expect(afterA.recipes.map((r) => r.id)).toEqual(['r1', 'b1', 'a1']);
    expect(loadRecipes(store).map((r) => r.id)).toEqual(['r1', 'b1', 'a1']);
  });

  it('다른 탭에서 지운 레시피는 이후 변경으로 되살아나지 않는다', () => {
    const store = memoryStore();
    persistRecipes([sampleRecipe(), { ...sampleRecipe(), id: 'r2', name: '바게트' }], store);
    const tabA = loadRecipeList(store);
    updateRecipes((cur) => cur.filter((r) => r.id !== 'r2'), loadRecipeList(store), store);
    updateRecipes(
      (cur) => cur.map((r) => (r.id === 'r1' ? { ...r, name: '새 이름' } : r)),
      tabA,
      store,
    );
    expect(loadRecipes(store).map((r) => [r.id, r.name])).toEqual([['r1', '새 이름']]);
  });

  it('저장소와 같은 동안은 다른 탭의 변경을 다시 읽는다', () => {
    const store = memoryStore();
    const tab = loadRecipeList(store);
    persistRecipes([sampleRecipe()], store);
    expect(reloadRecipes(tab, store).recipes.map((r) => r.id)).toEqual(['r1']);
  });
});

describe('저장소 쓰기 실패 (저장 공간 초과·저장소 없음)', () => {
  const recipe = (id: string, name = id): Recipe => ({ ...sampleRecipe(), id, name });

  it('saveJson은 성공 여부를 돌려준다', () => {
    expect(saveJson('k', 1, memoryStore())).toBe(true);
    expect(saveJson('k', 1, quotaStore())).toBe(false);
    expect(saveJson('k', 1, null)).toBe(false);
  });

  it('쓰기가 실패해도 앞서 저장하지 못한 레시피가 목록에 남는다', () => {
    const store = quotaStore();
    const a = updateRecipes((cur) => [...cur, recipe('a')], loadRecipeList(store), store);
    const b = updateRecipes((cur) => [...cur, recipe('b')], a, store);
    expect(a.persisted).toBe(false);
    expect(b.persisted).toBe(false);
    expect(b.recipes.map((r) => r.id)).toEqual(['a', 'b']);
    expect(loadRecipes(store)).toEqual([]);
  });

  it('도중에 저장 공간이 차도 목록이 유지되고, 다시 쓸 수 있게 되면 목록 전체가 저장된다', () => {
    const store = quotaStore();
    store.failing = false;
    persistRecipes([recipe('x')], store);
    const tab = loadRecipeList(store);

    store.failing = true;
    const added = updateRecipes((cur) => [...cur, recipe('a')], tab, store);
    const copied = updateRecipes((cur) => [...cur, recipe('x2', 'x (복사)')], added, store);
    expect(copied.recipes.map((r) => r.id)).toEqual(['x', 'a', 'x2']);

    store.failing = false;
    const renamed = updateRecipes(
      (cur) => cur.map((r) => (r.id === 'a' ? { ...r, name: 'A' } : r)),
      copied,
      store,
    );
    expect(renamed.persisted).toBe(true);
    expect(loadRecipes(store).map((r) => [r.id, r.name])).toEqual([
      ['x', 'x'],
      ['a', 'A'],
      ['x2', 'x (복사)'],
    ]);
  });

  it('저장소가 뒤처진 동안에는 다른 탭의 변경으로 목록을 덮어쓰지 않는다', () => {
    const store = quotaStore();
    const tab = updateRecipes((cur) => [...cur, recipe('a')], loadRecipeList(store), store);
    expect(reloadRecipes(tab, store)).toBe(tab);
  });

  it('저장소가 없으면(localStorage 꺼짐) 메모리 목록에 쌓인다', () => {
    const a = updateRecipes((cur) => [...cur, recipe('a')], loadRecipeList(null), null);
    const b = updateRecipes((cur) => [...cur, recipe('b')], a, null);
    expect(b.persisted).toBe(false);
    expect(b.recipes.map((r) => r.id)).toEqual(['a', 'b']);
  });
});

describe('mergeImported (JSON 가져오기 병합 — iOS와 같은 규칙)', () => {
  const at = (iso: string, over: Partial<Recipe> = {}): Recipe => ({
    ...sampleRecipe(),
    updatedAt: iso,
    ...over,
  });

  it('같은 내보내기 파일을 두 번 가져와도 개수가 늘지 않는다', () => {
    const exported = importJson(exportJson([sampleRecipe(), { ...sampleRecipe(), id: 'r2' }]));
    if (!exported.ok) throw new Error(exported.reason);
    const once = mergeImported([], exported.recipes);
    expect(once).toMatchObject({ added: 2, updated: 0, skipped: 0 });
    const twice = mergeImported(once.recipes, exported.recipes);
    expect(twice.recipes).toHaveLength(2);
    expect(twice).toMatchObject({ added: 0, updated: 0, skipped: 2 });
  });

  it('updatedAt이 같으면 내용이 달라도 건너뛴다 (iCloud 병합과 같은 기준)', () => {
    const local = at('2026-08-01T00:00:00.000Z', { water: 750 });
    const res = mergeImported([local], [at('2026-08-01T00:00:00.000Z', { water: 600 })]);
    expect(res).toMatchObject({ updated: 0, skipped: 1 });
    expect(res.recipes[0].water).toBe(750);
  });

  it('더 새롭더라도 내용이 같으면 건너뛴다', () => {
    const local = at('2026-08-01T00:00:00.000Z');
    const res = mergeImported([local], [at('2026-08-02T00:00:00.000Z')]);
    expect(res).toMatchObject({ updated: 0, skipped: 1 });
    expect(res.recipes[0].updatedAt).toBe('2026-08-01T00:00:00.000Z');
  });

  it('파일 안에서 같은 id가 반복되면 첫 행만 쓴다', () => {
    const res = mergeImported(
      [],
      [at('2026-08-01T00:00:00.000Z', { water: 600 }), at('2026-08-02T00:00:00.000Z', { water: 750 })],
    );
    expect(res).toMatchObject({ added: 1, updated: 0, skipped: 1 });
    expect(res.recipes).toHaveLength(1);
    expect(res.recipes[0].water).toBe(600);
  });

  it('updatedAt이 더 새로우면 교체하고 로컬 createdAt은 유지한다', () => {
    const local = at('2026-08-01T00:00:00.000Z', { createdAt: '2026-07-01T00:00:00.000Z' });
    const incoming = at('2026-08-02T00:00:00.000Z', {
      createdAt: '2026-07-20T00:00:00.000Z',
      water: 750,
    });
    const res = mergeImported([local], [incoming]);
    expect(res).toMatchObject({ added: 0, updated: 1, skipped: 0 });
    expect(res.recipes).toHaveLength(1);
    expect(res.recipes[0].water).toBe(750);
    expect(res.recipes[0].updatedAt).toBe('2026-08-02T00:00:00.000Z');
    expect(res.recipes[0].createdAt).toBe('2026-07-01T00:00:00.000Z');
  });

  it('updatedAt이 더 오래되면 건너뛴다', () => {
    const local = at('2026-08-02T00:00:00.000Z', { water: 750 });
    const res = mergeImported([local], [at('2026-08-01T00:00:00.000Z', { water: 600 })]);
    expect(res).toMatchObject({ added: 0, updated: 0, skipped: 1 });
    expect(res.recipes[0].water).toBe(750);
  });

  it('시각은 문자열이 아니라 실제 시각으로 비교한다', () => {
    // 문자열로는 '2026-08-01T09:00:00+09:00' > '2026-08-01T01:00:00.000Z'지만 실제로는 같은 시각 이전(00:00Z)
    const local = at('2026-08-01T01:00:00.000Z', { water: 750 });
    const res = mergeImported([local], [at('2026-08-01T09:00:00+09:00', { water: 600 })]);
    expect(res).toMatchObject({ updated: 0, skipped: 1 });
  });

  it('한쪽이라도 해석되지 않는 시각이면 문자열로 비교한다 (iOS와 같은 결과)', () => {
    const valid = at('2026-09-01T00:00:00Z', { water: 750 });
    expect(mergeImported([valid], [at('zzz', { water: 600 })])).toMatchObject({ updated: 1 });
    expect(
      mergeImported([at('garbage', { water: 750 })], [at('2026-09-01T00:00:00Z', { water: 600 })]),
    ).toMatchObject({ updated: 0, skipped: 1 });
    // 날짜만 있는 문자열은 Date.parse가 받아 주지만(08-02 00:00Z, 더 늦음) iOS는 해석하지 않는다 → 문자열로는 더 작다
    const local = at('2026-08-02T01:00:00+09:00', { water: 750 });
    expect(mergeImported([local], [at('2026-08-02', { water: 600 })])).toMatchObject({
      updated: 0,
      skipped: 1,
    });
  });

  // iOS LibrarySyncTests importMatchesWebTimeGrammar와 같은 쌍 — (기기 updatedAt, 가져온 updatedAt, 받는가)
  it.each([
    ['2026-09-03T10:00:00.1234Z', '2026-09-03T10:00:00.1235Z', false],
    ['2026-09-03T10:00:00.123Z', '2026-09-03T10:00:00.123400Z', false],
    ['2026-09-03T10:00:00Z', '2026-09-03T10:00:00z', true],
    ['2026-09-03T10:00:00Z', '2026-9-3T10:00:00Z', true],
    ['2026-09-03T19:00:00+09:00', '2026-09-03T10:60:00Z', false],
    ['2026-09-03T10:00:00Z', '2026-09-03T19:00:00+09', true],
    ['2026-09-03T10:00:00Z', '2026-09-03T10:00:00Z ', true],
    ['2026-09-03T10:00:00Z', '2026-09-03T19:00:01+0900', true],
    ['2026-09-04T00:00:00Z', '2026-09-03T24:00:00.000Z', false],
    ['2026-09-03T23:59:59Z', '2026-09-03T24:00:00Z', true],
    ['2026-03-03T00:00:00Z', '2026-02-31T00:00:00Z', false],
  ] as const)('시각 문법이 iOS와 같다: %s ← %s → 받음 %s', (local, incoming, accepted) => {
    const res = mergeImported([at(local, { water: 750 })], [at(incoming, { water: 600 })]);
    expect(res.updated).toBe(accepted ? 1 : 0);
  });

  it('없는 id는 id를 유지한 채 뒤에 추가한다', () => {
    const res = mergeImported([sampleRecipe()], [at('2026-01-01T00:00:00.000Z', { id: 'new' })]);
    expect(res).toMatchObject({ added: 1, updated: 0, skipped: 0 });
    expect(res.recipes.map((r) => r.id)).toEqual(['r1', 'new']);
  });
});
