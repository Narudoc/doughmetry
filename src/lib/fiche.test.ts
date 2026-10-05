import { describe, expect, it } from 'vitest';
import type { DoughInput } from './dough';
import { computeStats, levainTypeFor } from './dough';
import { ficheText } from './fiche';
import { cleanForParsing, parseRecipeText } from './recipeParser';

const base = (): DoughInput => ({
  flours: [{ id: 'f1', name: 'T65', grams: 900 }],
  water: 620,
  bassinage: 0,
  salt: 20,
  levain: { type: 'liquide', hydration: 1, grams: 200 },
  liquids: [],
  yeast: { type: 'fresh', grams: 0 },
  extras: [],
});

const text = (input: DoughInput, opts: Partial<Parameters<typeof ficheText>[3]> = {}, name = '캉파뉴') =>
  ficheText(name, input, computeStats(input), { precision: 0.1, basis: 'total', ...opts });

describe('ficheText (공유·복사용 배합표)', () => {
  it('iOS와 같은 줄 순서로 쓴다', () => {
    expect(text(base()).split('\n')).toEqual([
      '〔캉파뉴〕 fiche technique',
      '',
      'T65  900.0 g  (90.0%)',
      '물 (본반죽)  620.0 g',
      '소금  20.0 g  (2.0%)',
      '르방 (리퀴드 liquide 100%)  200.0 g  (20.0%)',
      '  ↳ 속 밀가루  100.0 g  (PFF 10.0%)',
      '',
      '총 밀가루  1000.0 g',
      '총 물  720.0 g',
      '총 수분율  72.0%',
      '총 반죽 무게  1740.0 g',
      '',
      '%는 총 밀가루 대비',
    ]);
  });

  it('바시나주·이스트는 0이면 빼고 있으면 넣는다', () => {
    const plain = text(base());
    expect(plain).not.toContain('바시나주');
    expect(plain).not.toContain('이스트');
    const withBoth = text({ ...base(), bassinage: 30, yeast: { type: 'instant', grams: 2 } });
    expect(withBoth).toContain('바시나주  30.0 g');
    expect(withBoth).toContain('이스트 (인스턴트 드라이)  2.0 g  (0.2%)');
  });

  it('분할 개수가 있으면 개당 무게 줄을 붙인다', () => {
    expect(text(base(), { pieces: 2 })).toContain('분할 2개 — 개당 870.0 g');
    expect(text(base(), { pieces: 0 })).not.toContain('분할');
  });

  it('표시 자릿수 1 g', () => {
    const t = text({ ...base(), water: 620.4 }, { precision: 1 });
    expect(t).toContain('물 (본반죽)  620 g');
    expect(t).toContain('총 반죽 무게  1740 g');
  });

  it('% 기준은 재료 %와 마지막 줄만 바꾸고, PFF·총 수분율은 그대로 둔다', () => {
    const total = text(base()).split('\n');
    const added = text(base(), { basis: 'added' }).split('\n');
    expect(added[2]).toBe('T65  900.0 g  (100.0%)');
    expect(added[added.length - 1]).toBe('%는 첨가 밀가루 대비');
    const keep = (lines: string[]) =>
      lines.filter((l) => l.includes('PFF') || l.startsWith('총 수분율'));
    expect(keep(added)).toEqual(keep(total));
  });

  it('빈 이름은 배합표와 같은 대체 이름을 쓴다', () => {
    const t = text(
      {
        ...base(),
        flours: [{ id: 'f1', name: '', grams: 900 }],
        liquids: [{ id: 'l1', name: '', grams: 50, waterRatio: 0.88 }],
        extras: [{ id: 'e1', name: '', grams: 30 }],
      },
      {},
      '  ',
    );
    expect(t.split('\n')[0]).toBe('〔배합표〕 fiche technique');
    expect(t).toContain('밀가루 1  900.0 g');
    expect(t).toContain('액체 1  50.0 g  (5.0%) · 수분 88.0%');
    expect(t).toContain('기타 1  30.0 g  (3.0%)');
  });
});

/** 앱이 공유한 텍스트를 앱이 다시 가져온다 — iOS는 같은 형식의 픽스처로 RecipeTextParserTests.swift에서 검사한다 */
describe('공유 텍스트 → 가져오기 왕복', () => {
  const custom = (h: number): DoughInput => ({
    flours: [
      { id: 'f1', name: 'Manitoba', grams: 500 },
      { id: 'f2', name: 'Tipo 00', grams: 400 },
      { id: 'f3', name: '통밀', grams: 100 },
    ],
    water: 560,
    bassinage: 30,
    salt: 20,
    levain: { type: levainTypeFor(h), hydration: h, grams: 180 },
    liquids: [
      { id: 'l1', name: '', grams: 100, waterRatio: 0.9 },
      { id: 'l2', name: '꿀', grams: 30, waterRatio: 0.17 },
      { id: 'l3', name: '우유', grams: 50, waterRatio: 0.88 },
    ],
    yeast: { type: 'instant', grams: 2 },
    extras: [{ id: 'e1', name: '호두', grams: 80 }],
  });

  it.each([0.5, 0.6, 0.65, 0.8, 1, 1.25])(
    '르방 수분율 %s — 재료 종류·양·수분 함량과 합계가 그대로 돌아온다',
    (h) => {
      const options = [{}, { precision: 1 as const }, { basis: 'added' as const }, { pieces: 2 }];
      for (const opts of options) {
        const input = custom(h);
        const label = JSON.stringify(opts);
        const r = parseRecipeText(cleanForParsing(text(input, opts, '피자')));
        expect(r.name, label).toBe('피자');
        expect(r.input.flours.map((f) => [f.name, f.grams]), label).toEqual([
          ['Manitoba', 500],
          ['Tipo 00', 400],
          ['통밀', 100],
        ]);
        expect(r.input.water, label).toBe(560);
        expect(r.input.bassinage, label).toBe(30);
        expect(r.input.salt, label).toBe(20);
        expect(r.input.levain, label).toEqual({ ...input.levain, flourName: undefined });
        expect(r.levainHydrationExplicit, label).toBe(true);
        expect(r.input.liquids.map((l) => [l.name, l.grams, l.waterRatio]), label).toEqual([
          ['액체 1', 100, 0.9],
          ['꿀', 30, 0.17],
          ['우유', 50, 0.88],
        ]);
        expect(r.input.yeast, label).toEqual({ type: 'instant', grams: 2 });
        expect(r.input.extras.map((e) => [e.name, e.grams]), label).toEqual([['호두', 80]]);
        expect(r.pieces, label).toBe('pieces' in opts ? 2 : null);
        const want = computeStats(input);
        const got = computeStats(r.input);
        for (const k of ['totalFlour', 'totalWater', 'hydrationPct', 'pffPct', 'doughWeight'] as const) {
          expect(Math.abs(got[k] - want[k]), `${label} ${k}`).toBeLessThan(1e-9);
        }
      }
    },
  );
});
