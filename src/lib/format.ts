import type { Settings } from '../types';

export type Precision = Settings['precision'];

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
