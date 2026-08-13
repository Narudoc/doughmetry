import { LIQUID_PRESETS } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct } from '../../lib/format';
import { newId } from '../../lib/id';
import type { Liquid } from '../../types';
import { Button } from '../ui/Button';
import { NumberField, TextField } from '../ui/fields';

interface Props {
  rows: Liquid[];
  onChange: (rows: Liquid[]) => void;
  precision: Precision;
  /** 각 행의 총 밀가루 대비 % (id → pct) */
  pcts?: Map<string, number>;
}

/** 수분율이 반영되는 액체 재료 (우유 88% · 계란 76%, USDA 기준 프리셋 + 직접 입력) */
export function LiquidRows({ rows, onChange, precision, pcts }: Props) {
  const update = (id: string, patch: Partial<Liquid>) =>
    onChange(rows.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  const add = (name: string, waterRatio: number) =>
    onChange([...rows, { id: newId(), name, grams: 0, waterRatio }]);

  return (
    <div className="space-y-2">
      {rows.map((row) => (
        <div key={row.id} className="flex flex-wrap items-center gap-2">
          <TextField
            className="min-w-[100px] flex-1"
            value={row.name}
            onChange={(name) => update(row.id, { name })}
            placeholder="우유, 계란…"
            ariaLabel="액체 재료 이름"
          />
          <NumberField
            className="w-28 shrink-0"
            value={row.grams}
            onChange={(grams) => update(row.id, { grams })}
            unit="g"
            ariaLabel={`${row.name || '액체'} 무게`}
          />
          <NumberField
            className="w-24 shrink-0"
            value={row.waterRatio * 100}
            onChange={(v) => update(row.id, { waterRatio: Math.min(100, v) / 100 })}
            unit="%"
            ariaLabel={`${row.name || '액체'} 수분율`}
          />
          <span className="w-24 shrink-0 text-right text-xs tabular-nums text-ink/60">
            수분 {fmtGrams(row.grams * row.waterRatio, precision)} g
          </span>
          {pcts && (
            <span className="w-12 shrink-0 text-right text-xs tabular-nums text-ink/60">
              {fmtPct(pcts.get(row.id) ?? 0)}
            </span>
          )}
          <Button
            small
            variant="ghost"
            aria-label={`${row.name || '액체'} 행 삭제`}
            onClick={() => onChange(rows.filter((r) => r.id !== row.id))}
            className="shrink-0"
          >
            ×
          </Button>
        </div>
      ))}
      <div className="flex flex-wrap gap-1">
        <Button
          small
          variant="ghost"
          onClick={() => add(LIQUID_PRESETS.milk.name, LIQUID_PRESETS.milk.waterRatio)}
        >
          + 우유 (수분 88%)
        </Button>
        <Button
          small
          variant="ghost"
          onClick={() => add(LIQUID_PRESETS.egg.name, LIQUID_PRESETS.egg.waterRatio)}
        >
          + 계란 (수분 76%)
        </Button>
        <Button small variant="ghost" onClick={() => add('', 1)}>
          + 직접 입력
        </Button>
      </div>
    </div>
  );
}
