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
  return (
    <section className="rounded-lg border border-line bg-white p-5">
      <div className="text-xs font-medium uppercase tracking-widest text-bottle">
        총 수분율 <span className="normal-case italic text-bottle/60">hydratation totale</span>
      </div>
      <div className="mt-1 font-display text-5xl font-bold tabular-nums text-brass">
        {stats.hydrationPct.toFixed(1)}
        <span className="text-2xl">%</span>
      </div>
      <dl className="mt-4 grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
        <Item label="총 밀가루" value={`${fmtGrams(stats.totalFlour, precision)} g`} />
        <Item label="총 반죽 무게" value={`${fmtGrams(stats.doughWeight, precision)} g`} />
        <Item label="총 물" value={`${fmtGrams(stats.totalWater, precision)} g`} />
        <Item label="소금" value={fmtPct(stats.saltPct)} />
        <Item label="발효종 밀가루 (PFF)" value={fmtPct(stats.pffPct)} />
        <Item
          label="분할"
          value={
            pieces && pieces > 0
              ? `${pieces} × ${fmtGrams(stats.doughWeight / pieces, precision)} g`
              : '—'
          }
        />
      </dl>
    </section>
  );
}
