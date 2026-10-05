import type { DoughStats } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct } from '../../lib/format';

interface Props {
  stats: DoughStats;
  pieces?: number;
  precision: Precision;
  /** 모드 B의 불가능한 목표 조합 — 경고를 스크롤하지 않아도 보이게 한다 */
  infeasible?: boolean;
  onExpand: () => void;
}

/**
 * 좁은 화면(lg 미만)의 하단 결과 요약 — 결과가 입력 폼 아래로 멀리 밀려나므로 iOS SummaryBar처럼 늘 보인다.
 * 표시만 하고, 누르면 전체 결과로 스크롤한다
 */
export function SummaryBar({ stats, pieces, precision, infeasible = false, onExpand }: Props) {
  const items: Array<[string, string, boolean?]> = [
    ['총 수분율', fmtPct(stats.hydrationPct), true],
    ['총 반죽', `${fmtGrams(stats.doughWeight, precision)} g`],
    ['PFF', fmtPct(stats.pffPct)],
  ];
  if (pieces && pieces > 0) items.push(['개당', `${fmtGrams(stats.doughWeight / pieces, precision)} g`]);

  return (
    <div
      className="no-print fixed inset-x-0 bottom-0 z-30 px-3 lg:hidden"
      style={{ paddingBottom: 'max(0.5rem, env(safe-area-inset-bottom))' }}
    >
      <button
        type="button"
        onClick={onExpand}
        className={`mx-auto flex min-h-[44px] w-full max-w-5xl items-center gap-2 rounded-lg bg-white/95 px-3 py-1.5 text-left shadow backdrop-blur ${
          infeasible ? 'border-2 border-danger' : 'border border-line'
        }`}
      >
        <span className="flex min-w-0 flex-1 justify-around gap-2">
          {items.map(([label, value, result]) => (
            <span key={label} className="min-w-0">
              <span className="block whitespace-nowrap text-[11px] leading-tight text-ink/70">{label}</span>
              <span
                className={`block whitespace-nowrap text-sm font-semibold tabular-nums ${
                  infeasible ? 'text-danger' : result ? 'text-brass' : ''
                }`}
              >
                {value}
              </span>
            </span>
          ))}
        </span>
        <span className="sr-only">
          {infeasible ? '— 목표 조합이 불가능합니다 ' : ''}— 눌러서 결과와 배합표 보기
        </span>
        <span aria-hidden="true" className="shrink-0 text-xs text-bottle">
          ▲
        </span>
      </button>
    </div>
  );
}
