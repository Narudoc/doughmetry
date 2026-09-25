import { describe, expect, it } from 'vitest';
import { parseDecimalInput } from './fields';

describe('parseDecimalInput', () => {
  it('자릿수가 맞는 천 단위 쉼표는 구분 기호로 읽는다', () => {
    expect(parseDecimalInput('1,000')).toBe(1000);
    expect(parseDecimalInput('12,345,678')).toBe(12345678);
    expect(parseDecimalInput('1,000.5')).toBe(1000.5);
  });

  it('그 밖의 쉼표는 소수점으로 읽는다', () => {
    expect(parseDecimalInput('72,5')).toBe(72.5);
    expect(parseDecimalInput('0,125')).toBe(0.125);
    expect(parseDecimalInput('1.5')).toBe(1.5);
  });

  it('입력 도중의 값은 그 시점까지로 해석한다', () => {
    expect(parseDecimalInput('1,')).toBe(1);
    expect(parseDecimalInput('1,00')).toBe(1);
  });

  it('해석할 수 없으면 NaN (이전 값 유지)', () => {
    expect(parseDecimalInput('1,000,5')).toBeNaN();
    expect(parseDecimalInput('1.000.5')).toBeNaN();
  });
});
