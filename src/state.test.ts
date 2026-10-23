import { describe, expect, it } from 'vitest';
import type { CalcState } from './state';
import { computeStats, convertFixedMass, convertFixedPff } from './lib/dough';
import {
  CALC_STATUS_LABEL,
  calcSaveStatus,
  calcStateAfterSave,
  calcStateFromDough,
  calcStateFromRecipe,
  convertedDoughName,
  converterDoughFromCalc,
  converterDoughFromRecipe,
  currentDoughInput,
  defaultCalcState,
  defaultSettings,
  isCalcDirty,
  overwriteTarget,
  recipeFromConversion,
  resetCalcState,
  sanitizeSettings,
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
  const saveAs = (s: CalcState, name: string, id: string, recipes: Recipe[] = []): CalcState =>
    calcStateAfterSave(s, { name, id }, recipes);
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

  it('모드 A 입력을 고친 채 모드 B로 저장해도 그 입력은 저장하지 않은 입력으로 남는다 (iOS markCalcSaved와 같다)', () => {
    const r = recipe();
    const loaded = calcStateFromRecipe(r);
    const edited: CalcState = { ...loaded, input: { ...loaded.input, water: 700 } };
    const saved = saveAs({ ...edited, mode: 'B' }, '역산 바게트', 'rb', [r]);
    const library = [r, recipeFrom(saved, 'rb')];
    expect(isCalcDirty(saved, library)).toBe(true);
    expect(isCalcDirty({ ...saved, mode: 'A' }, library)).toBe(true);
    // 새로 시작한 배합(기록 없음 포함)을 고친 경우도
    for (const start of [resetCalcState(false), defaultCalcState()]) {
      const touched: CalcState = { ...start, mode: 'B', input: { ...start.input, water: 700 } };
      const after = saveAs(touched, '역산', 'rc');
      expect(isCalcDirty({ ...after, mode: 'A' }, [recipeFrom(after, 'rc')])).toBe(true);
    }
  });

  it('모드 A 입력이 그대로면 모드 B 저장 직후는 깨끗하다 — 불러온 레시피·처음 기본 배합 모두', () => {
    const r = recipe();
    const fromRecipe = saveAs({ ...calcStateFromRecipe(r), mode: 'B' }, '역산', 'rb', [r]);
    expect(isCalcDirty(fromRecipe, [r, recipeFrom(fromRecipe, 'rb')])).toBe(false);
    expect(isCalcDirty({ ...fromRecipe, mode: 'A' }, [r, recipeFrom(fromRecipe, 'rb')])).toBe(false);
    // 목표를 바꿔 저장해도 모드 A로 돌아오면 깨끗하다 — 목표는 저장한 기준과 비교한다 (iOS calcIsDirty와 같다)
    const linked = calcStateFromRecipe(r);
    const retargeted = saveAs(
      { ...linked, mode: 'B', target: { ...linked.target, doughWeight: 2000 } },
      '2kg 역산',
      'rd',
      [r],
    );
    expect(isCalcDirty({ ...retargeted, mode: 'A' }, [r, recipeFrom(retargeted, 'rd')])).toBe(false);
    // 첫 실행 — 아직 기준 기록이 없는 기본 배합. 저장은 깨끗하지만, 이어진 레시피가 없는 모드 A는
    // 기준(모드 B)과 달라 iOS처럼 저장하지 않은 입력으로 본다
    const fresh = saveAs({ ...defaultCalcState(), mode: 'B' }, '역산', 'rc');
    expect(isCalcDirty(fresh, [recipeFrom(fresh, 'rc')])).toBe(false);
    expect(isCalcDirty({ ...fresh, mode: 'A' }, [recipeFrom(fresh, 'rc')])).toBe(true);
  });

  it('모드 A 분할 개수를 고친 채 모드 B로 저장해도 그 개수는 저장하지 않은 입력이다 (iOS markCalcSaved와 같다)', () => {
    const r = recipe();
    for (const start of [calcStateFromRecipe(r), resetCalcState(false), defaultCalcState()]) {
      const saved = saveAs({ ...start, pieces: 3, mode: 'B' }, '역산', 'rb', [r]);
      const library = [r, recipeFrom(saved, 'rb')];
      expect(isCalcDirty(saved, library)).toBe(true);
      expect(isCalcDirty({ ...saved, mode: 'A' }, library)).toBe(true);
    }
  });

  it('모드 B 저장은 계산기를 새 레시피에 잇지 않는다 — 모드 A 덮어쓰기 대상은 처음 불러온 레시피거나 없다', () => {
    const r = recipe();
    const b: CalcState = { ...calcStateFromRecipe(r), mode: 'B' };
    expect(overwriteTarget(b, [r])).toBeUndefined();
    const saved = saveAs(b, '2kg 역산', 'rb', [r]);
    const library = [r, recipeFrom(saved, 'rb')];
    expect(saved.recipeId).toBe('r1');
    expect(saved.name).toBe('바게트');
    expect(overwriteTarget({ ...saved, mode: 'A' }, library)?.id).toBe('r1');

    const fresh = saveAs({ ...resetCalcState(false), mode: 'B' }, '2kg 역산', 'rc');
    expect(fresh.recipeId).toBeUndefined();
    expect(overwriteTarget({ ...fresh, mode: 'A' }, [recipeFrom(fresh, 'rc')])).toBeUndefined();
  });

  it('모드 A 저장은 계산기를 저장한 레시피에 잇고 이름을 따른다', () => {
    const saved = saveAs(resetCalcState(false), '내 캉파뉴', 'ra');
    const stored = recipeFrom(saved, 'ra');
    expect(saved.recipeId).toBe('ra');
    expect(saved.name).toBe('내 캉파뉴');
    expect(overwriteTarget(saved, [stored])?.id).toBe('ra');
    expect(isCalcDirty(saved, [stored])).toBe(false);
  });

  it('불러온 레시피의 이름을 레시피 탭에서 바꿔도 계산기는 깨끗하다', () => {
    const r = recipe();
    const loaded = calcStateFromRecipe(r);
    expect(isCalcDirty(loaded, [{ ...r, name: '이름 바꾼 바게트' }])).toBe(false);
  });
});

describe('resetCalcState (새 배합 — iOS resetCalc(empty:)와 같다)', () => {
  it('빈 배합·예시 배합 모두 레시피 연결이 없고, 시작한 그대로는 깨끗하다', () => {
    for (const empty of [true, false]) {
      const s = resetCalcState(empty);
      expect(s.recipeId).toBeUndefined();
      expect(s.mode).toBe('A');
      expect(isCalcDirty(s, [recipe()])).toBe(false);
      // draft로 저장됐다 다시 읽혀도
      expect(isCalcDirty(JSON.parse(JSON.stringify(s)), [])).toBe(false);
    }
  });

  it('빈 배합은 이름·재료가 비어 있고 예시 배합은 캉파뉴다', () => {
    const blank = resetCalcState(true);
    expect(blank.name).toBe('');
    expect(blank.input.flours).toHaveLength(1);
    expect(blank.input.flours[0]).toMatchObject({ name: '', grams: 0 });
    expect(blank.input.water).toBe(0);
    expect(blank.input.levain.grams).toBe(0);
    expect(blank.pieces).toBe(0);
    expect(resetCalcState(false).name).toBe('캉파뉴');
  });

  it('시작한 뒤 무엇이든 고치면 저장하지 않은 입력이다', () => {
    const blank = resetCalcState(true);
    expect(isCalcDirty({ ...blank, input: { ...blank.input, water: 400 } }, [])).toBe(true);
    expect(isCalcDirty({ ...blank, name: '바게트' }, [])).toBe(true);
    const example = resetCalcState(false);
    expect(isCalcDirty({ ...example, pieces: 2 }, [])).toBe(true);
  });

  it('빈 배합의 지표는 NaN이 아니라 0이다', () => {
    const stats = computeStats(resetCalcState(true).input);
    expect(stats.hydrationPct).toBe(0);
    expect(stats.pffPct).toBe(0);
    expect(stats.saltPct).toBe(0);
    expect(stats.doughWeight).toBe(0);
  });
});

describe('sanitizeSettings', () => {
  it('마지막 백업 시각은 해석되는 문자열일 때만 남긴다', () => {
    const at = '2026-09-30T10:00:00.000Z';
    expect(sanitizeSettings({ precision: 1, pctBasis: 'total', lastExportAt: at })?.lastExportAt).toBe(at);
    expect(sanitizeSettings({ precision: 1, pctBasis: 'total', lastExportAt: 'nope' })?.lastExportAt).toBeUndefined();
    expect(sanitizeSettings({ precision: 0.1, pctBasis: 'added', lastExportAt: 42 })?.lastExportAt).toBeUndefined();
    expect(sanitizeSettings({ precision: 0.1 })).toEqual({
      precision: 0.1,
      pctBasis: 'total',
      lastExportAt: undefined,
      keepScreenAwake: true,
    });
  });

  it('화면 켜두기는 기본 켬 — 이 설정이 없던 예전 저장값도 켬, 끈 것만 끈다', () => {
    expect(defaultSettings().keepScreenAwake).toBe(true);
    expect(sanitizeSettings({ precision: 1, pctBasis: 'total' })?.keepScreenAwake).toBe(true);
    expect(sanitizeSettings({ precision: 1, keepScreenAwake: false })?.keepScreenAwake).toBe(false);
    expect(sanitizeSettings({ precision: 1, keepScreenAwake: true })?.keepScreenAwake).toBe(true);
    expect(sanitizeSettings({ precision: 1, keepScreenAwake: 'off' })?.keepScreenAwake).toBe(true);
    // 저장했다 다시 읽어도 그대로
    const off = sanitizeSettings(JSON.parse(JSON.stringify({ ...defaultSettings(), keepScreenAwake: false })));
    expect(off).toEqual({ ...defaultSettings(), keepScreenAwake: false });
  });
});

describe('변환기 원본 — 분할 개수·태그를 이어받는다 (iOS sendToConverter와 같다)', () => {
  it('저장된 레시피에서: 분할 개수·태그를 넘기고 메모는 넘기지 않는다', () => {
    const d = converterDoughFromRecipe(recipe());
    expect(d.name).toBe('바게트');
    expect(d.pieces).toBe(4);
    expect(d.tags).toEqual(['바게트']);
    expect(d).not.toHaveProperty('note');
    expect(d.input.water).toBe(680);
    // 레시피의 태그 배열과 따로 논다
    d.tags?.push('x');
    expect(recipe().tags).toEqual(['바게트']);
  });

  it('분할·태그가 없는 레시피는 없음으로 넘긴다', () => {
    const d = converterDoughFromRecipe({ ...recipe(), pieces: 0, tags: undefined });
    expect(d.pieces).toBeUndefined();
    expect(d.tags).toBeUndefined();
  });

  it('계산기에서: 분할 개수와 이어진 레시피의 태그 — 이어진 레시피가 없으면 태그 없음', () => {
    const linked = calcStateFromRecipe(recipe());
    const d = converterDoughFromCalc({ ...linked, pieces: 3 }, [recipe()]);
    expect(d.pieces).toBe(3);
    expect(d.tags).toEqual(['바게트']);
    expect(converterDoughFromCalc(linked, []).tags).toBeUndefined();
    const fresh = defaultCalcState();
    expect(converterDoughFromCalc(fresh, [recipe()])).toMatchObject({ name: '캉파뉴', pieces: undefined, tags: undefined });
  });

  it('계산기 모드 B: 역산 배합과 개수 × 개당의 개수', () => {
    const s: CalcState = {
      ...defaultCalcState(),
      mode: 'B',
      target: { ...defaultCalcState().target, byPieces: true, pieces: 2, pieceWeight: 870 },
    };
    const d = converterDoughFromCalc(s, []);
    expect(d.pieces).toBe(2);
    expect(computeStats(d.input).doughWeight).toBeCloseTo(1740, 9);
  });

  it('변환 결과 레시피는 분할 개수를 이어받는다 — 두 변환 모두 총 반죽이 보존돼 개당 무게도 같다', () => {
    const src = converterDoughFromRecipe(recipe());
    const before = computeStats(src.input).doughWeight / 4;
    const mass = convertFixedMass(src.input, 0.5, { mode: 'pro-rata' });
    const pff = convertFixedPff(src.input, 0.5);
    if (!mass.ok || !pff.ok) throw new Error('변환 실패');
    const now = '2026-10-23T00:00:00.000Z';
    const saved = recipeFromConversion(mass.output, { name: '바게트 (르방 50%)', tags: src.tags ?? [] }, src.pieces, 'n1', now);
    expect(saved).toMatchObject({ id: 'n1', pieces: 4, tags: ['바게트'], createdAt: now, updatedAt: now });
    expect(saved.note).toBeUndefined();
    expect(computeStats(saved).doughWeight / saved.pieces!).toBeCloseTo(before, 9);
    const savedPff = recipeFromConversion(pff.output, { name: 'p', tags: [] }, src.pieces, 'n2', now);
    expect(savedPff.pieces).toBe(4);
    expect(savedPff.tags).toBeUndefined();
    expect(savedPff.levain.grams).not.toBeCloseTo(src.input.levain.grams, 3);
    expect(computeStats(savedPff).doughWeight / 4).toBeCloseTo(before, 9);
  });

  it('분할하지 않는 원본은 분할 없이 저장한다', () => {
    const r = recipeFromConversion(recipe(), { name: 'x', tags: [], note: '메모' }, undefined, 'n', '2026-10-23T00:00:00.000Z');
    expect(r.pieces).toBeUndefined();
    expect(r.note).toBe('메모');
    expect(recipeFromConversion(recipe(), { name: 'x', tags: [] }, 0, 'n', 'now').pieces).toBeUndefined();
  });
});

describe('변환기 → 계산기 (iOS 변환기의 계산기로 보내기와 같다)', () => {
  it('변환한 배합의 이름은 새 르방 종류와 수분율을 붙인다', () => {
    expect(convertedDoughName('캉파뉴', 50)).toBe('캉파뉴 (뒤흐 50%)');
    expect(convertedDoughName('바게트', 100)).toBe('바게트 (리퀴드 100%)');
    expect(convertedDoughName('  바게트 ', 65.5)).toBe('바게트 (뒤흐 65.5%)');
    expect(convertedDoughName('', 80)).toBe('이름 없는 배합 (리퀴드 80%)');
  });

  it('모드 A로, 레시피에 잇지 않고 — 저장해도 원본 레시피를 덮어쓸 수 없다', () => {
    const r = recipe();
    const conv = convertFixedMass(converterDoughFromRecipe(r).input, 0.5, { mode: 'pro-rata' });
    if (!conv.ok) throw new Error('변환 실패');
    const s = calcStateFromDough({ name: '바게트 (뒤흐 50%)', input: conv.output, pieces: 4 }, calcStateFromRecipe(r));
    expect(s.mode).toBe('A');
    expect(s.recipeId).toBeUndefined();
    expect(s.name).toBe('바게트 (뒤흐 50%)');
    expect(s.pieces).toBe(4);
    expect(s.input.levain.hydration).toBe(0.5);
    expect(overwriteTarget(s, [r])).toBeUndefined();
    // 넘긴 배합과 따로 논다
    s.input.flours[0].grams = 1;
    expect(conv.output.flours[0].grams).not.toBe(1);
  });

  it('어디에도 저장되지 않은 배합이라 받은 그대로도 저장하지 않은 입력이다 (iOS처럼 기준을 옮기지 않는다)', () => {
    const r = recipe();
    const d = { name: '캉파뉴 (뒤흐 50%)', input: defaultCalcState().input };
    for (const prev of [calcStateFromRecipe(r), resetCalcState(false), resetCalcState(true), defaultCalcState()]) {
      const s = calcStateFromDough(d, prev);
      expect(s.pieces).toBe(0);
      expect(isCalcDirty(s, [r])).toBe(true);
      // draft로 저장됐다 다시 읽혀도
      expect(isCalcDirty(JSON.parse(JSON.stringify(s)), [r])).toBe(true);
    }
  });

  it('보낸 배합을 모드 B로 저장해도 보낸 모드 A 배합은 저장하지 않은 입력으로 남는다', () => {
    const r = recipe();
    const s = calcStateFromDough({ name: '바게트 (뒤흐 50%)', input: defaultCalcState().input }, calcStateFromRecipe(r));
    const saved = calcStateAfterSave({ ...s, mode: 'B' }, { name: '역산', id: 'rb' }, [r]);
    expect(isCalcDirty({ ...saved, mode: 'A' }, [r])).toBe(true);
  });

  it('보낸 배합을 모드 A로 저장하면 그 레시피에 이어지고 깨끗하다', () => {
    const s = calcStateFromDough({ name: '바게트 (뒤흐 50%)', input: defaultCalcState().input }, resetCalcState(false));
    const saved = calcStateAfterSave(s, { name: s.name, id: 'rn' }, []);
    const stored: Recipe = { ...recipe(), id: 'rn', name: s.name, ...saved.input, pieces: 0 };
    expect(saved.recipeId).toBe('rn');
    expect(isCalcDirty(saved, [stored])).toBe(false);
    expect(calcSaveStatus(saved, [stored])).toBe('saved');
  });
});

describe('calcSaveStatus (계산기 이름 칸 아래 저장 상태 — iOS 계산기의 상태 줄과 같다)', () => {
  it('처음 예시 배합 그대로면 예시 배합 — 재료 행 id가 달라도, 새로 시작한 예시도', () => {
    expect(calcSaveStatus(defaultCalcState(), [])).toBe('example');
    expect(calcSaveStatus(resetCalcState(false), [recipe()])).toBe('example');
    expect(calcSaveStatus(JSON.parse(JSON.stringify(resetCalcState(false))), [])).toBe('example');
  });

  it('예시를 고치거나, 빈 배합·모드 B·변환기에서 받은 배합은 새 배합', () => {
    const s = defaultCalcState();
    expect(calcSaveStatus({ ...s, input: { ...s.input, water: 700 } }, [])).toBe('new');
    expect(calcSaveStatus({ ...s, name: '내 빵' }, [])).toBe('new');
    expect(calcSaveStatus({ ...s, mode: 'B' }, [])).toBe('new');
    expect(calcSaveStatus(resetCalcState(true), [])).toBe('new');
    expect(calcSaveStatus(calcStateFromDough({ name: '캉파뉴 (뒤흐 50%)', input: s.input }, s), [])).toBe('new');
  });

  it('불러오거나 저장한 레시피 그대로면 저장됨, 고치면 수정됨', () => {
    const r = recipe();
    const loaded = calcStateFromRecipe(r);
    expect(calcSaveStatus(loaded, [r])).toBe('saved');
    expect(calcSaveStatus({ ...loaded, name: '바게트 2' }, [r])).toBe('edited');
    expect(calcSaveStatus({ ...loaded, pieces: 5 }, [r])).toBe('edited');
    expect(calcSaveStatus({ ...loaded, mode: 'B' }, [r])).toBe('edited');
    const saved = calcStateAfterSave({ ...defaultCalcState(), name: '내 캉파뉴' }, { name: '내 캉파뉴', id: 'ra' }, []);
    const stored: Recipe = { ...recipe(), id: 'ra', name: '내 캉파뉴', ...saved.input, pieces: 0 };
    expect(calcSaveStatus(saved, [stored])).toBe('saved');
  });

  it('이어지지 않는 모드 B 저장은 저장한 그대로면 저장됨, 고치면 새 배합', () => {
    const s = { ...defaultCalcState(), mode: 'B' as const };
    const saved = calcStateAfterSave(s, { name: '캉파뉴', id: 'rb' }, []);
    expect(saved.recipeId).toBeUndefined();
    expect(isCalcDirty(saved, [])).toBe(false);
    expect(calcSaveStatus(saved, [])).toBe('saved');
    expect(calcSaveStatus(JSON.parse(JSON.stringify(saved)), [])).toBe('saved');
    expect(calcSaveStatus({ ...saved, name: '바게트' }, [])).toBe('new');
    expect(calcSaveStatus({ ...saved, target: { ...saved.target, hydrationPct: 80 } }, [])).toBe('new');
    // 숨은 모드 A 입력이 저장되지 않은 채 남으면 (변환기에서 받은 배합) 새 배합
    const sent = calcStateFromDough({ name: '바게트 (뒤흐 50%)', input: { ...s.input, water: 700 } }, resetCalcState(false));
    expect(calcSaveStatus(calcStateAfterSave({ ...sent, mode: 'B' }, { name: '역산', id: 'rc' }, []), [])).toBe('new');
  });

  it('이어진 레시피가 지워졌으면 저장하면 새 레시피가 되므로 새 배합', () => {
    const loaded = calcStateFromRecipe(recipe());
    expect(calcSaveStatus(loaded, [])).toBe('new');
    // 지워진 레시피가 마침 예시 배합과 같아도 예시라고 하지 않는다
    expect(calcSaveStatus({ ...defaultCalcState(), recipeId: 'gone' }, [])).toBe('new');
  });

  it('문구는 iOS와 같다', () => {
    expect(CALC_STATUS_LABEL).toEqual({
      saved: '저장된 레시피 · 변경 없음',
      edited: '수정됨 — 저장 안 됨',
      new: '새 배합 · 저장 안 됨',
      example: '예시 배합',
    });
  });
});
