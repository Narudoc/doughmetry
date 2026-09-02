import type { PctBasis, Settings } from '../types';
import type { DoughStats } from './dough';

export type Precision = Settings['precision'];

/**
 * 표시 계층의 % 계산 — 설정(PctBasis)에 따라 분모만 달라진다.
 * 계산 코어의 지표(총 수분율·PFF)는 항상 총 밀가루 기준으로 유지된다.
 */
export function uiPct(stats: DoughStats, grams: number, basis: PctBasis): number {
  const denom = basis === 'added' ? stats.totalFlour - stats.levainFlour : stats.totalFlour;
  return denom > 1e-9 ? (grams / denom) * 100 : 0;
}

/** 총 밀가루 기준으로 이미 계산된 %를 표시 기준으로 환산 */
export function rebasePct(stats: DoughStats, pctOfTotal: number, basis: PctBasis): number {
  if (basis === 'total') return pctOfTotal;
  const added = stats.totalFlour - stats.levainFlour;
  return added > 1e-9 ? (pctOfTotal * stats.totalFlour) / added : 0;
}

/** 르방 행의 % — 총 밀가루 기준일 땐 PFF, 베이커스 퍼센트일 땐 르방 무게/첨가 밀가루 */
export function uiLevainPct(stats: DoughStats, levainGrams: number, basis: PctBasis): number {
  return basis === 'added' ? uiPct(stats, levainGrams, basis) : stats.pffPct;
}

/** 그램 표시 — 내부는 full precision, 표시만 반올림 (0.1g 또는 1g) */
export function fmtGrams(g: number, precision: Precision = 0.1): string {
  return precision === 1 ? g.toFixed(0) : g.toFixed(1);
}

export function fmtPct(p: number, digits = 1): string {
  return `${p.toFixed(digits)}%`;
}

/** 증감분 표시: +33.3 / −33.3 (U+2212) */
export function fmtSigned(g: number, precision: Precision = 0.1): string {
  const abs = fmtGrams(Math.abs(g), precision);
  return g < 0 ? `−${abs}` : `+${abs}`;
}

export function fmtDate(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())}`;
}
