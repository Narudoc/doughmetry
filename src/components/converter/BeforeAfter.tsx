import type { ConvertSuccess, DoughInput } from '../../lib/dough';
import { levainTypeFor } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct, fmtSigned } from '../../lib/format';
import { Fr } from '../ui/Fr';

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
/** 1 g 표시에서는 반올림하면 0이 되는 증감(+0 g)을 강조하지 않는다 (iOS deltaText와 동일) */
const CHANGE_THRESHOLD_WHOLE_G = 0.5;

/** 변환 전/후 좌우 대조 표 — 변경 값 강조 + 증감분 표시 */
export function BeforeAfter({ result, inputBefore, precision }: Props) {
  const { output, before, after } = result;
  const levainLabel = (h: number) => (levainTypeFor(h) === 'liquide' ? '리퀴드' : '뒤흐');

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
    {
      key: 'water',
      label: '물 (본반죽)',
      before: inputBefore.water,
      after: output.water,
      unit: 'g',
    },
    ...(inputBefore.bassinage > 0 || output.bassinage > 0
      ? [
          {
            key: 'bassinage',
            label: '바시나주',
            before: inputBefore.bassinage,
            after: output.bassinage,
            unit: 'g' as const,
          },
        ]
      : []),
    { key: 'salt', label: '소금', before: inputBefore.salt, after: output.salt, unit: 'g' },
    ...inputBefore.liquids.map((l, i) => ({
      key: `liquid-${l.id}`,
      label: `${l.name || `액체 ${i + 1}`} (수분 ${(l.waterRatio * 100).toFixed(0)}%)`,
      before: l.grams,
      after: output.liquids.find((x) => x.id === l.id)?.grams ?? l.grams,
      unit: 'g' as const,
    })),
    ...(inputBefore.yeast.grams > 0
      ? [
          {
            key: 'yeast',
            label: `이스트 (${inputBefore.yeast.type === 'fresh' ? '생' : 'IDY'})`,
            before: inputBefore.yeast.grams,
            after: output.yeast.grams,
            unit: 'g' as const,
          },
        ]
      : []),
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

  const isChanged = (line: Line) => {
    const threshold =
      line.unit === 'g' && precision === 1 ? CHANGE_THRESHOLD_WHOLE_G : CHANGE_THRESHOLD;
    return Math.abs(line.after - line.before) >= threshold;
  };

  const deltaChip = (line: Line) => {
    const delta = line.after - line.before;
    return isChanged(line) ? (
      <span className="inline-block rounded bg-brass/10 px-1.5 py-0.5 text-xs font-semibold tabular-nums text-brass">
        {line.unit === 'g' ? `${fmtSigned(delta, precision)} g` : `${fmtSigned(delta, 0.1)}%p`}
      </span>
    ) : (
      <span aria-hidden="true" className="text-xs text-ink/40">—</span>
    );
  };

  // 좁은 화면에서는 증감 열을 숨기고 변환 후 값 아래에 칩을 붙인다 — 변환 후 값이 화면 밖으로 밀려나지 않게
  const renderRow = (line: Line) => {
    const changed = isChanged(line);
    return (
      <tr
        key={line.key}
        className={`border-b border-line ${line.indent ? 'text-ink/70' : ''} ${line.emphasize ? 'bg-brass/5' : ''}`}
      >
        <td className={`px-2 py-2 sm:px-3 ${line.indent ? 'pl-5 text-xs sm:pl-7' : ''}`}>{line.label}</td>
        <td className="px-2 py-2 text-right tabular-nums sm:px-3">{renderValue(line.before, line.unit)}</td>
        <td
          className={`border-l border-line px-2 py-2 text-right tabular-nums sm:px-3 ${
            changed ? 'font-semibold text-brass' : ''
          }`}
        >
          {renderValue(line.after, line.unit)}
          {changed && <span className="mt-0.5 block sm:hidden">{deltaChip(line)}</span>}
        </td>
        <td className="hidden px-2 py-2 text-right sm:table-cell sm:px-3">{deltaChip(line)}</td>
      </tr>
    );
  };

  return (
    <div className="overflow-x-auto rounded-lg border-2 border-bottle bg-white">
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="bg-bottle text-paper">
            <th className="px-2 py-2.5 text-left font-medium sm:px-3">항목</th>
            <th className="px-2 py-2.5 text-right font-medium sm:px-3">
              변환 전 <Fr className="font-normal opacity-70">avant</Fr>
            </th>
            <th className="border-l border-paper/20 px-2 py-2.5 text-right font-medium sm:px-3">
              변환 후 <Fr className="font-normal opacity-70">après</Fr>
            </th>
            <th className="hidden px-2 py-2.5 text-right font-medium sm:table-cell sm:px-3">증감</th>
          </tr>
        </thead>
        <tbody>
          {lines.map(renderRow)}
          <tr className="border-b border-line bg-paper">
            <td colSpan={4} className="px-2 py-1.5 text-xs font-medium uppercase tracking-widest text-bottle/80 sm:px-3">
              지표
            </td>
          </tr>
          {statLines.map(renderRow)}
        </tbody>
      </table>
    </div>
  );
}
