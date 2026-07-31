import type { ConvertSuccess, DoughInput } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct, fmtSigned } from '../../lib/format';

interface Props {
  result: ConvertSuccess;
  inputBefore: DoughInput;
  precision: Precision;
}

interface Line {
  key: string;
  label: string;
  before: number;
  after: number;
  unit: 'g' | '%';
  indent?: boolean;
  emphasize?: boolean;
}

const CHANGE_THRESHOLD = 0.05;

/** 변환 전/후 좌우 대조 표 — 변경 값 강조 + 증감분 표시 */
export function BeforeAfter({ result, inputBefore, precision }: Props) {
  const { output, before, after } = result;
  const levainLabel = (h: number) => (h >= 0.75 ? '리퀴드' : '뒤흐');

  // 밀가루 행: 변환 전 순서 기준, 변환으로 새로 생긴 행은 뒤에
  const beforeFlours = new Map(inputBefore.flours.map((f) => [f.id, f]));
  const afterFlours = new Map(output.flours.map((f) => [f.id, f]));
  const flourIds = [
    ...inputBefore.flours.map((f) => f.id),
    ...output.flours.filter((f) => !beforeFlours.has(f.id)).map((f) => f.id),
  ];

  const lines: Line[] = [
    ...flourIds.map((id, i) => {
      const b = beforeFlours.get(id);
      const a = afterFlours.get(id);
      return {
        key: `flour-${id}`,
        label: b?.name || a?.name || `밀가루 ${i + 1}`,
        before: b?.grams ?? 0,
        after: a?.grams ?? 0,
        unit: 'g' as const,
      };
    }),
    { key: 'water', label: '물', before: inputBefore.water, after: output.water, unit: 'g' },
    { key: 'salt', label: '소금', before: inputBefore.salt, after: output.salt, unit: 'g' },
    {
      key: 'levain',
      label: `르방 (${levainLabel(inputBefore.levain.hydration)} ${(inputBefore.levain.hydration * 100).toFixed(0)}% → ${levainLabel(output.levain.hydration)} ${(output.levain.hydration * 100).toFixed(0)}%)`,
      before: inputBefore.levain.grams,
      after: output.levain.grams,
      unit: 'g',
    },
    {
      key: 'levain-flour',
      label: '↳ 속 밀가루',
      before: before.levainFlour,
      after: after.levainFlour,
      unit: 'g',
      indent: true,
    },
    {
      key: 'levain-water',
      label: '↳ 속 물',
      before: before.levainWater,
      after: after.levainWater,
      unit: 'g',
      indent: true,
    },
    ...inputBefore.extras.map((e, i) => ({
      key: `extra-${e.id}`,
      label: e.name || `기타 ${i + 1}`,
      before: e.grams,
      after: output.extras.find((x) => x.id === e.id)?.grams ?? e.grams,
      unit: 'g' as const,
    })),
  ];

  const statLines: Line[] = [
    { key: 'hydration', label: '총 수분율', before: before.hydrationPct, after: after.hydrationPct, unit: '%' },
    { key: 'pff', label: '발효종 밀가루 (PFF)', before: before.pffPct, after: after.pffPct, unit: '%', emphasize: true },
    { key: 'weight', label: '총 반죽 무게', before: before.doughWeight, after: after.doughWeight, unit: 'g' },
  ];

  const renderValue = (v: number, unit: 'g' | '%') =>
    unit === 'g' ? `${fmtGrams(v, precision)} g` : fmtPct(v);

  const renderRow = (line: Line) => {
    const delta = line.after - line.before;
    const changed = Math.abs(delta) > CHANGE_THRESHOLD;
    return (
      <tr
        key={line.key}
        className={`border-b border-line ${line.indent ? 'text-ink/60' : ''} ${line.emphasize ? 'bg-brass/5' : ''}`}
      >
        <td className={`px-3 py-2 ${line.indent ? 'pl-7 text-xs' : ''}`}>{line.label}</td>
        <td className="px-3 py-2 text-right tabular-nums">{renderValue(line.before, line.unit)}</td>
        <td
          className={`border-l border-line px-3 py-2 text-right tabular-nums ${
            changed ? 'font-semibold text-brass' : ''
          }`}
        >
          {renderValue(line.after, line.unit)}
        </td>
        <td className="px-3 py-2 text-right">
          {changed ? (
            <span className="inline-block rounded bg-brass/10 px-1.5 py-0.5 text-xs font-semibold tabular-nums text-brass">
              {fmtSigned(delta, precision)}
              {line.unit === 'g' ? ' g' : '%p'}
            </span>
          ) : (
            <span className="text-xs text-ink/40">—</span>
          )}
        </td>
      </tr>
    );
  };

  return (
    <div className="overflow-x-auto rounded-lg border-2 border-bottle bg-white">
      <table className="w-full min-w-[540px] border-collapse text-sm">
        <thead>
          <tr className="bg-bottle text-paper">
            <th className="px-3 py-2.5 text-left font-medium">항목</th>
            <th className="px-3 py-2.5 text-right font-medium">
              변환 전 <span className="font-normal italic opacity-70">avant</span>
            </th>
            <th className="border-l border-paper/20 px-3 py-2.5 text-right font-medium">
              변환 후 <span className="font-normal italic opacity-70">après</span>
            </th>
            <th className="px-3 py-2.5 text-right font-medium">증감</th>
          </tr>
        </thead>
        <tbody>
          {lines.map(renderRow)}
          <tr className="border-b border-line bg-paper">
            <td colSpan={4} className="px-3 py-1.5 text-xs font-medium uppercase tracking-widest text-bottle/70">
              지표
            </td>
          </tr>
          {statLines.map(renderRow)}
        </tbody>
      </table>
    </div>
  );
}
