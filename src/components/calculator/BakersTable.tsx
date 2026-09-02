import type { DoughInput, DoughStats } from '../../lib/dough';
import { convertYeast } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct, uiPct } from '../../lib/format';
import type { PctBasis } from '../../types';

interface Props {
  input: DoughInput;
  stats: DoughStats;
  precision: Precision;
  pieces?: number;
  basis?: PctBasis;
}

interface RowData {
  key: string;
  name: string;
  grams: number;
  pct: number;
  note: string;
  indent?: boolean;
}

export function BakersTable({ input, stats, precision, pieces, basis = 'total' }: Props) {
  // 표시 기준(설정)에 따른 % — PFF와 르방 분해 행은 항상 총 밀가루 기준
  const pctOf = (g: number) => uiPct(stats, g, basis);
  const pctTotal = (g: number) => (stats.totalFlour > 0 ? (g / stats.totalFlour) * 100 : 0);
  const levainLabel = input.levain.type === 'liquide' ? '리퀴드 liquide' : '뒤흐 dur';
  const yeastLabel = input.yeast.type === 'fresh' ? '생이스트' : '인스턴트 드라이';
  const yeastOther = input.yeast.type === 'fresh' ? '인스턴트 드라이' : '생이스트';

  const rows: RowData[] = [
    ...input.flours.map((f, i) => ({
      key: `flour-${f.id}`,
      name: f.name || `밀가루 ${i + 1}`,
      grams: f.grams,
      pct: pctOf(f.grams),
      note: '첨가 밀가루',
    })),
    {
      key: 'water',
      name: '물 (본반죽)',
      grams: input.water,
      pct: pctOf(input.water),
      note: '첨가 물',
    },
    ...(input.bassinage > 0
      ? [
          {
            key: 'bassinage',
            name: '바시나주',
            grams: input.bassinage,
            pct: pctOf(input.bassinage),
            note: 'bassinage — 후반 급수',
          },
        ]
      : []),
    { key: 'salt', name: '소금', grams: input.salt, pct: pctOf(input.salt), note: '' },
    {
      key: 'levain',
      name: `르방 (${levainLabel})`,
      grams: input.levain.grams,
      pct: pctOf(input.levain.grams),
      note: `수분율 ${(input.levain.hydration * 100).toFixed(0)}%${input.levain.flourName ? ` · ${input.levain.flourName}` : ''}`,
    },
    {
      key: 'levain-flour',
      name: '↳ 속 밀가루',
      grams: stats.levainFlour,
      pct: stats.pffPct,
      note: '발효종 밀가루 (PFF)',
      indent: true,
    },
    {
      key: 'levain-water',
      name: '↳ 속 물',
      grams: stats.levainWater,
      pct: pctTotal(stats.levainWater),
      note: '',
      indent: true,
    },
    ...input.liquids.map((l, i) => ({
      key: `liquid-${l.id}`,
      name: l.name || `액체 ${i + 1}`,
      grams: l.grams,
      pct: pctOf(l.grams),
      note: `수분 ${(l.waterRatio * 100).toFixed(0)}% = ${fmtGrams(l.grams * l.waterRatio, precision)} g`,
    })),
    ...(input.yeast.grams > 0
      ? [
          {
            key: 'yeast',
            name: `이스트 (${yeastLabel})`,
            grams: input.yeast.grams,
            pct: pctOf(input.yeast.grams),
            note: `= ${yeastOther} ${fmtGrams(convertYeast(input.yeast.grams, input.yeast.type, input.yeast.type === 'fresh' ? 'instant' : 'fresh'), precision)} g`,
          },
        ]
      : []),
    ...input.extras.map((e, i) => ({
      key: `extra-${e.id}`,
      name: e.name || `기타 ${i + 1}`,
      grams: e.grams,
      pct: pctOf(e.grams),
      note: '수분 계산 제외',
    })),
  ];

  return (
    <div className="overflow-x-auto">
      <table className="bakers-table w-full min-w-[480px] border-collapse text-sm">
        <caption className="mb-2 text-left font-display text-sm font-semibold uppercase tracking-widest text-bottle">
          베이커스 퍼센트{' '}
          <span className="font-normal normal-case italic text-bottle/60">
            {basis === 'added'
              ? '— %는 첨가 밀가루 대비 (베이커스 퍼센트)'
              : '— %는 총 밀가루(첨가 + 르방 속) 대비'}
          </span>
        </caption>
        <thead>
          <tr className="bg-bottle text-left text-paper">
            <th className="rounded-l-sm px-3 py-2 font-medium">재료</th>
            <th className="px-3 py-2 text-right font-medium">무게 (g)</th>
            <th className="px-3 py-2 text-right font-medium">%</th>
            <th className="rounded-r-sm px-3 py-2 font-medium">비고</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.key} className={`border-b border-line ${r.indent ? 'text-ink/60' : ''}`}>
              <td className={`px-3 py-2 ${r.indent ? 'pl-7 text-xs' : ''}`}>{r.name}</td>
              <td className="px-3 py-2 text-right tabular-nums">{fmtGrams(r.grams, precision)}</td>
              <td className="px-3 py-2 text-right tabular-nums">{fmtPct(r.pct)}</td>
              <td className="px-3 py-2 text-xs text-ink/50">{r.note}</td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr className="border-t-2 border-bottle font-semibold">
            <td className="px-3 py-2">합계 (반죽)</td>
            <td className="px-3 py-2 text-right tabular-nums">
              {fmtGrams(stats.doughWeight, precision)}
            </td>
            <td className="px-3 py-2 text-right tabular-nums">{fmtPct(stats.hydrationPct)}</td>
            <td className="px-3 py-2 text-xs text-ink/60">
              {pieces && pieces > 0
                ? `분할 ${pieces} × ${fmtGrams(stats.doughWeight / pieces, precision)} g`
                : '총 수분율 기준'}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
  );
}
