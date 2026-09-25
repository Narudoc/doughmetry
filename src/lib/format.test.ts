import { describe, expect, it } from 'vitest';
import { fmtGrams, fmtPct, fmtSigned } from './format';

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
