import { describe, expect, it } from 'vitest';
import type { PickerItem, PickerSection } from './recipePicker';
import { RECENT_COUNT, foldForSearch, pickerSections } from './recipePicker';

// iOS RecipePickerTests.swift와 같은 벡터 — 한쪽을 바꾸면 함께 고칠 것
function item(id: string, name: string, tags: string[], createdAt: string, updatedAt: string): PickerItem {
  return { id, name, tags, createdAt, updatedAt };
}

const r1 = item('r1', '캉파뉴', ['T65'], '2026-09-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
const r2 = item('r2', '바게트', [], '2026-09-02T00:00:00.000Z', '2026-10-05T00:00:00.000Z');
const r3 = item('r3', 'Pain de campagne', ['french'], '2026-09-03T00:00:00.000Z', '2026-09-20T00:00:00.000Z');
const r4 = item('r4', '캉파뉴 10', [], '2026-09-04T00:00:00.000Z', '2026-10-03T00:00:00.000Z');
const r5 = item('r5', '캉파뉴 2', ['호밀'], '2026-09-05T00:00:00.000Z', '2026-10-03T00:00:00.000Z');
const r6 = item('r6', 'brioche', [], '2026-09-06T00:00:00.000Z', '2026-09-10T00:00:00Z');
const r7 = item('r7', 'Écrasé', [], '2026-09-07T00:00:00.000Z', '2026-09-15T00:00:00.000Z');
const all = [r1, r2, r3, r4, r5, r6, r7];

const ids = (sections: PickerSection<PickerItem>[]) =>
  sections.map((s) => ({ kind: s.kind, ids: s.recipes.map((r) => r.id) }));

describe('pickerSections', () => {
  it('검색어가 없고 RECENT_COUNT개를 넘으면 최근 5개 + 전체(가나다순)', () => {
    expect(RECENT_COUNT).toBe(5);
    expect(ids(pickerSections(all, ''))).toEqual([
      { kind: 'recent', ids: ['r2', 'r5', 'r4', 'r1', 'r3'] },
      { kind: 'all', ids: ['r2', 'r1', 'r5', 'r4', 'r6', 'r7', 'r3'] },
    ]);
  });

  it('RECENT_COUNT개 이하면 저장된 레시피 하나로 (최근 순)', () => {
    expect(ids(pickerSections([r1, r2, r3], ''))).toEqual([{ kind: 'saved', ids: ['r2', 'r1', 'r3'] }]);
    expect(pickerSections(all.slice(0, RECENT_COUNT), '').map((s) => s.kind)).toEqual(['saved']);
    expect(pickerSections([], '')).toEqual([{ kind: 'saved', recipes: [] }]);
  });

  it('검색 — 이름·태그, 대소문자·발음 구별 기호 무시, 결과는 가나다순', () => {
    const results = (q: string) => ids(pickerSections(all, q));
    expect(results('캉파')).toEqual([{ kind: 'results', ids: ['r1', 'r5', 'r4'] }]);
    expect(results('ecrase')).toEqual([{ kind: 'results', ids: ['r7'] }]);
    expect(results('PAIN')).toEqual([{ kind: 'results', ids: ['r3'] }]);
    expect(results('호밀')).toEqual([{ kind: 'results', ids: ['r5'] }]);
    expect(results('t65')).toEqual([{ kind: 'results', ids: ['r1'] }]);
    expect(results('없는이름')).toEqual([{ kind: 'results', ids: [] }]);
  });

  it('공백뿐인 검색어는 빈 검색어와 같다', () => {
    expect(pickerSections(all, '  ')).toEqual(pickerSections(all, ''));
    expect(pickerSections(all, ' 캉파 ')).toEqual(pickerSections(all, '캉파'));
  });

  it('해석할 수 없는 updatedAt은 최근 순에서 맨 뒤', () => {
    const bad = item('r0', 'Zzz', [], '2026-10-30T00:00:00.000Z', 'garbage');
    const [saved] = pickerSections([bad, r6, r3], '');
    expect(saved.recipes.map((r) => r.id)).toEqual(['r3', 'r6', 'r0']);
    expect(ids(pickerSections([...all, bad], ''))[0]).toEqual({
      kind: 'recent',
      ids: ['r2', 'r5', 'r4', 'r1', 'r3'],
    });
  });

  it('시각이 모두 같으면 id 오름차순, 같은 이름은 최근 순', () => {
    const t = '2026-10-01T00:00:00.000Z';
    const a = item('b', '같은 이름', [], t, t);
    const b = item('a', '같은 이름', [], t, t);
    const c = item('c', '같은 이름', [], t, '2026-10-02T00:00:00.000Z');
    expect(ids(pickerSections([a, b, c], ''))).toEqual([{ kind: 'saved', ids: ['c', 'a', 'b'] }]);
    expect(ids(pickerSections([a, b, c], '같은'))).toEqual([{ kind: 'results', ids: ['c', 'a', 'b'] }]);
    // updatedAt이 같으면 나중에 만든 쪽이 앞 (r4·r5)
    expect(ids(pickerSections([r4, r5], ''))).toEqual([{ kind: 'saved', ids: ['r5', 'r4'] }]);
  });

  it('입력 배열을 바꾸지 않는다', () => {
    const input = [...all];
    pickerSections(input, '');
    pickerSections(input, '캉파');
    expect(input).toEqual(all);
  });
});

describe('foldForSearch', () => {
  it('대소문자·발음 구별 기호·전각을 접고 한글은 그대로', () => {
    expect(foldForSearch('Écrasé')).toBe('ecrase');
    expect(foldForSearch('ＰＡＩＮ')).toBe('pain');
    expect(foldForSearch('캉파뉴')).toBe('캉파뉴');
  });
});
