import { describe, expect, it } from 'vitest';
import type { CalcState } from './state';
import {
  calcSnapshot,
  calcStateFromRecipe,
  currentDoughInput,
  defaultCalcState,
  isCalcDirty,
} from './state';
import type { Recipe } from './types';

const recipe = (): Recipe => ({
  id: 'r1',
  schemaVersion: 2,
  name: '바게트',
  note: '메모',
  tags: ['바게트'],
  createdAt: '2026-09-01T00:00:00.000Z',
  updatedAt: '2026-09-01T00:00:00.000Z',
  flours: [{ id: 'f1', name: 'T65', grams: 1000 }],
  water: 680,
  bassinage: 30,
  salt: 21,
  levain: { type: 'liquide', hydration: 1, grams: 350 },
  liquids: [],
  yeast: { type: 'fresh', grams: 0 },
  extras: [],
  pieces: 4,
});

describe('isCalcDirty (불러오기 전 저장하지 않은 입력 확인 — iOS calcIsDirty와 같은 판단)', () => {
  it('처음 기본 배합은 깨끗하다 — 재료 행 id가 달라도', () => {
    expect(isCalcDirty(defaultCalcState(), [])).toBe(false);
  });

  it('기본 배합을 고치면 저장하지 않은 입력이다', () => {
    const s = defaultCalcState();
    expect(isCalcDirty({ ...s, input: { ...s.input, water: 700 } }, [])).toBe(true);
    expect(isCalcDirty({ ...s, name: '내 빵' }, [])).toBe(true);
  });

  it('불러온 레시피 그대로면 깨끗하고, 이름·재료·분할을 고치면 저장하지 않은 입력이다', () => {
    const r = recipe();
    const loaded = calcStateFromRecipe(r);
    expect(isCalcDirty(loaded, [r])).toBe(false);
    expect(isCalcDirty({ ...loaded, name: '바게트 2' }, [r])).toBe(true);
    expect(isCalcDirty({ ...loaded, pieces: 5 }, [r])).toBe(true);
    const flours = [{ ...loaded.input.flours[0], grams: 900 }];
    expect(isCalcDirty({ ...loaded, input: { ...loaded.input, flours } }, [r])).toBe(true);
  });

  it('키 순서만 다른 같은 내용은 깨끗하다', () => {
    const r = recipe();
    const loaded = calcStateFromRecipe(r);
    const { levain, ...rest } = loaded.input;
    const reordered = { levain: { grams: levain.grams, hydration: levain.hydration, type: levain.type }, ...rest };
    expect(isCalcDirty({ ...loaded, input: reordered }, [r])).toBe(false);
  });

  it('목표 역산(모드 B)으로 바꾸거나 연결된 레시피가 지워지면 저장하지 않은 입력이다', () => {
    const r = recipe();
    const loaded = calcStateFromRecipe(r);
    expect(isCalcDirty({ ...loaded, mode: 'B' }, [r])).toBe(true);
    expect(isCalcDirty(loaded, [])).toBe(true);
  });

  /** CalculatorPage.handleSave와 같은 방식으로 저장한 직후 상태 */
  const saveAs = (s: CalcState, name: string, id: string): CalcState => {
    const saved = { ...s, name, recipeId: id };
    return { ...saved, savedSnapshot: calcSnapshot(saved) };
  };
  const recipeFrom = (s: CalcState, id: string): Recipe => ({
    ...recipe(),
    id,
    name: s.name,
    ...currentDoughInput(s),
  });

  it('모드 B에서 저장한 직후는 깨끗하고, 목표를 고치면 저장하지 않은 입력이다', () => {
    const b: CalcState = { ...defaultCalcState(), mode: 'B' };
    const saved = saveAs(b, '역산 빵', 'rb');
    const stored = recipeFrom(saved, 'rb');
    expect(isCalcDirty(saved, [stored])).toBe(false);
    const edited = { ...saved, target: { ...saved.target, hydrationPct: 75 } };
    expect(isCalcDirty(edited, [stored])).toBe(true);
  });

  it('목표 입력을 바꾼 채 모드 A로 저장해도 저장 직후는 깨끗하다 (새로 고침 뒤에도)', () => {
    const s = defaultCalcState();
    const withTarget = { ...s, target: { ...s.target, hydrationPct: 75 }, input: { ...s.input, water: 700 } };
    const saved = saveAs(withTarget, '내 캉파뉴', 'ra');
    const stored = recipeFrom(saved, 'ra');
    expect(isCalcDirty(saved, [stored])).toBe(false);
    // draft는 JSON으로 저장됐다 다시 읽힌다
    expect(isCalcDirty(JSON.parse(JSON.stringify(saved)), [stored])).toBe(false);
  });

  it('불러온 레시피의 이름을 레시피 탭에서 바꿔도 계산기는 깨끗하다', () => {
    const r = recipe();
    const loaded = calcStateFromRecipe(r);
    expect(isCalcDirty(loaded, [{ ...r, name: '이름 바꾼 바게트' }])).toBe(false);
  });
});
