import type { DoughInput, DoughStats } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct } from '../../lib/format';
import { BakersTable } from './BakersTable';

interface Props {
  name: string;
  input: DoughInput;
  stats: DoughStats;
  pieces?: number;
  precision: Precision;
}

/** 인쇄 전용 — A4 한 장짜리 fiche technique */
export function PrintFiche({ name, input, stats, pieces, precision }: Props) {
  const today = new Date();
  const date = `${today.getFullYear()}.${String(today.getMonth() + 1).padStart(2, '0')}.${String(today.getDate()).padStart(2, '0')}`;

  return (
    <section className="print-only">
      <div className="mb-4 border-b-2 border-black pb-3">
        <p className="font-display text-xs uppercase tracking-[0.2em]">
          Fiche technique · pain au levain
        </p>
        <h1 className="font-display text-3xl font-bold">{name || '이름 없는 레시피'}</h1>
        <p className="mt-1 text-sm tabular-nums">
          {date} · 총 수분율 {fmtPct(stats.hydrationPct)} · 소금 {fmtPct(stats.saltPct)} · PFF{' '}
          {fmtPct(stats.pffPct)} · 총 반죽 {fmtGrams(stats.doughWeight, precision)} g
          {pieces && pieces > 0
            ? ` · 분할 ${pieces} × ${fmtGrams(stats.doughWeight / pieces, precision)} g`
            : ''}
        </p>
      </div>
      <BakersTable input={input} stats={stats} precision={precision} pieces={pieces} />
    </section>
  );
}
