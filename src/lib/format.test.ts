import { describe, expect, it } from 'vitest';
import { computeStats } from './dough';
import { fmtGrams, fmtPct, fmtSigned, rebasePct, uiLevainPct, uiPct } from './format';

// iOS FormatTests.swift와 같은 벡터 — 두 플랫폼이 같은 레시피를 같은 숫자로 보여야 한다.

describe('반올림 — 정확한 2진 동점은 0에서 먼 쪽으로 (toFixed)', () => {
  it('1g 단위', () => {
    expect(fmtGrams(12.5, 1)).toBe('13');
    expect(fmtGrams(2.5, 1)).toBe('3');
    expect(fmtGrams(500.5, 1)).toBe('501');
  });

  it('0.1 단위 %·그램', () => {
    expect(fmtPct((5 / 400) * 100)).toBe('1.3%');
    expect(fmtPct((289 / 400) * 100)).toBe('72.3%');
    expect(fmtPct((9 / 400) * 100)).toBe('2.3%');
    expect(fmtGrams(0.25)).toBe('0.3');
  });

  it('동점이 아닌 값은 2진 값 그대로 반올림한다', () => {
    // 18.5/1000×100 = 1.8499999999999999 — ×10을 먼저 하면 18.5가 되어 1.9로 틀린다
    expect(fmtPct((18.5 / 1000) * 100)).toBe('1.8%');
    expect(fmtGrams(1.45)).toBe('1.4'); // 1.4499999999999999556
    expect(fmtGrams(0.05)).toBe('0.1'); // 0.0500000000000000028
  });

  it('음수·−0·증감분', () => {
    expect(fmtGrams(-2.5, 1)).toBe('-3');
    expect(fmtGrams(-0.25)).toBe('-0.3');
    expect(fmtGrams(-0.01)).toBe('-0.0');
    expect(fmtGrams(-0)).toBe('0.0');
    expect(fmtSigned(-12.5, 1)).toBe('−13');
    expect(fmtSigned(12.5, 1)).toBe('+13');
    expect(fmtSigned(-0)).toBe('+0.0');
  });

  it('유한하지 않은 값', () => {
    expect(fmtPct(Number.NaN)).toBe('NaN%');
    expect(fmtGrams(Number.POSITIVE_INFINITY)).toBe('Infinity');
    expect(fmtGrams(Number.NEGATIVE_INFINITY, 1)).toBe('-Infinity');
  });
});

// iOS FormatTests.swift PctBasisDisplay와 같은 벡터
describe('% 표기 기준 — 분모만 바뀌고 계산 지표는 그대로', () => {
  const stats = computeStats({
    flours: [{ id: 'f1', name: 'T65', grams: 900 }],
    water: 620,
    bassinage: 0,
    salt: 20,
    levain: { type: 'liquide', hydration: 1, grams: 200 },
    liquids: [],
    yeast: { type: 'fresh', grams: 0 },
    extras: [],
  });
  const near = (a: number, b: number) => Math.abs(a - b) < 1e-9;

  it('총 밀가루 기준은 첨가 + 르방 속 밀가루(1000g), 베이커스 퍼센트는 첨가 밀가루(900g)로 나눈다', () => {
    expect(near(uiPct(stats, 620, 'total'), 62)).toBe(true);
    expect(near(uiPct(stats, 620, 'added'), (620 / 900) * 100)).toBe(true);
    expect(fmtPct(uiPct(stats, 620, 'added'))).toBe('68.9%');
    expect(near(uiPct(stats, 900, 'added'), 100)).toBe(true);
    // 표시 기준과 무관하게 계산 지표는 총 밀가루 기준
    expect(near(stats.hydrationPct, 72)).toBe(true);
  });

  it('총 밀가루 기준 % 환산 — 베이커스 퍼센트면 × 총 밀가루 / 첨가 밀가루', () => {
    expect(near(stats.saltPct, 2)).toBe(true);
    expect(near(rebasePct(stats, stats.saltPct, 'total'), 2)).toBe(true);
    expect(near(rebasePct(stats, stats.saltPct, 'added'), (20 / 900) * 100)).toBe(true);
    expect(near(rebasePct(stats, stats.saltPct, 'added'), uiPct(stats, 20, 'added'))).toBe(true);
  });

  it('르방 칩 — 총 밀가루 기준은 PFF, 베이커스 퍼센트는 르방 무게 / 첨가 밀가루', () => {
    expect(near(uiLevainPct(stats, 200, 'total'), 10)).toBe(true);
    expect(near(uiLevainPct(stats, 200, 'added'), (200 / 900) * 100)).toBe(true);
  });

  it('밀가루가 없으면 0 (NaN이 아니다)', () => {
    const empty = computeStats({
      flours: [],
      water: 100,
      bassinage: 0,
      salt: 0,
      levain: { type: 'liquide', hydration: 1, grams: 0 },
      liquids: [],
      yeast: { type: 'fresh', grams: 0 },
      extras: [],
    });
    for (const basis of ['total', 'added'] as const) {
      expect(uiPct(empty, 100, basis)).toBe(0);
      expect(rebasePct(empty, 0, basis)).toBe(0);
      expect(uiLevainPct(empty, 0, basis)).toBe(0);
    }
  });
});
