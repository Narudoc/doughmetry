import type { DoughInput, DoughStats } from '../../lib/dough';
import { addedFlourTotal, levainTypeFor } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct, rebasePct } from '../../lib/format';
import type { PctBasis } from '../../types';
import { Fr } from '../ui/Fr';

interface Props {
  stats: DoughStats;
  pieces?: number;
  precision: Precision;
  basis?: PctBasis;
  /** 모드 B의 역산 배합 — 맨 위에 입력한 목표 대신 계량할 그램을 보인다 (iOS 역산 결과·solvedChips와 같다) */
  solved?: DoughInput;
}

function Item({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-ink/70">{label}</dt>
      <dd className="mt-0.5 font-semibold tabular-nums">{value}</dd>
    </div>
  );
}

/** 모드 B에서 계량할 양 — 불가능한 조합의 음수는 결과값(brass)이 아니라 danger로 */
function SolvedAmounts({ dough, precision }: { dough: DoughInput; precision: Precision }) {
  const negative = (g: number) => g < -1e-9;
  const rows: Array<[string, number, boolean]> = [
    ['첨가 밀가루', addedFlourTotal(dough), dough.flours.some((f) => negative(f.grams))],
    ['본반죽 물', dough.water, negative(dough.water)],
    ['소금', dough.salt, false],
    [
      levainTypeFor(dough.levain.hydration) === 'liquide' ? '르방 리퀴드' : '르방 뒤흐',
      dough.levain.grams,
      false,
    ],
  ];
  return (
    <>
      <div className="text-xs font-medium uppercase tracking-widest text-bottle">역산 결과</div>
      <dl className="mt-2 grid grid-cols-2 gap-x-4 gap-y-3">
        {rows.map(([label, grams, infeasible]) => (
          <div key={label} className="min-w-0">
            <dt className="text-xs text-ink/70">{label}</dt>
            <dd
              className={`mt-0.5 whitespace-nowrap font-display text-3xl font-bold tabular-nums ${
                infeasible ? 'text-danger' : 'text-brass'
              }`}
            >
              {fmtGrams(grams, precision)}
              <span className="text-lg"> g</span>
            </dd>
          </div>
        ))}
      </dl>
    </>
  );
}

export function ResultSummary({ stats, pieces, precision, basis = 'total', solved }: Props) {
  // 소금·이스트 %만 표시 기준을 따르고, 총 수분율·PFF는 항상 총 밀가루 기준
  const items: Array<[string, string]> = [
    ['총 밀가루', `${fmtGrams(stats.totalFlour, precision)} g`],
    ['총 반죽 무게', `${fmtGrams(stats.doughWeight, precision)} g`],
    ['총 물', `${fmtGrams(stats.totalWater, precision)} g`],
    ['소금', fmtPct(rebasePct(stats, stats.saltPct, basis))],
    ['발효종 밀가루 (PFF)', fmtPct(stats.pffPct)],
  ];
  if (stats.yeastPct > 0) items.push(['이스트', fmtPct(rebasePct(stats, stats.yeastPct, basis), 2)]);
  items.push([
    '분할',
    pieces && pieces > 0
      ? `${pieces} × ${fmtGrams(stats.doughWeight / pieces, precision)} g`
      : '—',
  ]);
  if (solved) items.unshift(['총 수분율', fmtPct(stats.hydrationPct)]);

  return (
    <section className="rounded-lg border border-line bg-white p-5">
      {solved ? (
        <SolvedAmounts dough={solved} precision={precision} />
      ) : (
        <>
          <div className="text-xs font-medium uppercase tracking-widest text-bottle">
            총 수분율 <Fr className="normal-case text-bottle/80">hydratation totale</Fr>
          </div>
          <div className="mt-1 font-display text-5xl font-bold tabular-nums text-brass">
            {stats.hydrationPct.toFixed(1)}
            <span className="text-2xl">%</span>
          </div>
          {stats.liquidWater > 0 && (
            <p className="mt-1 text-xs tabular-nums text-ink/70">
              액체 재료 수분 {fmtGrams(stats.liquidWater, precision)} g 포함
            </p>
          )}
        </>
      )}
      <dl
        className={`mt-4 grid grid-cols-2 gap-x-4 gap-y-3 text-sm ${
          solved ? 'border-t border-line pt-4' : ''
        }`}
      >
        {items.map(([label, value]) => (
          <Item key={label} label={label} value={value} />
        ))}
      </dl>
    </section>
  );
}
