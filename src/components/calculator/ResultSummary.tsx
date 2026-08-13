import type { DoughStats } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct } from '../../lib/format';

interface Props {
  stats: DoughStats;
  pieces?: number;
  precision: Precision;
}

function Item({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-ink/60">{label}</dt>
      <dd className="mt-0.5 font-semibold tabular-nums">{value}</dd>
    </div>
  );
}

export function ResultSummary({ stats, pieces, precision }: Props) {
  const items: Array<[string, string]> = [
    ['총 밀가루', `${fmtGrams(stats.totalFlour, precision)} g`],
    ['총 반죽 무게', `${fmtGrams(stats.doughWeight, precision)} g`],
    ['총 물', `${fmtGrams(stats.totalWater, precision)} g`],
    ['소금', fmtPct(stats.saltPct)],
    ['발효종 밀가루 (PFF)', fmtPct(stats.pffPct)],
  ];
  if (stats.yeastPct > 0) items.push(['이스트', fmtPct(stats.yeastPct, 2)]);
  items.push([
    '분할',
    pieces && pieces > 0
      ? `${pieces} × ${fmtGrams(stats.doughWeight / pieces, precision)} g`
      : '—',
  ]);

  return (
    <section className="rounded-lg border border-line bg-white p-5">
      <div className="text-xs font-medium uppercase tracking-widest text-bottle">
        총 수분율 <span className="normal-case italic text-bottle/60">hydratation totale</span>
      </div>
      <div className="mt-1 font-display text-5xl font-bold tabular-nums text-brass">
        {stats.hydrationPct.toFixed(1)}
        <span className="text-2xl">%</span>
      </div>
      {stats.liquidWater > 0 && (
        <p className="mt-1 text-xs tabular-nums text-ink/50">
          액체 재료 수분 {fmtGrams(stats.liquidWater, precision)} g 포함
        </p>
      )}
      <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
        {items.map(([label, value]) => (
          <Item key={label} label={label} value={value} />
        ))}
      </dl>
    </section>
  );
}
