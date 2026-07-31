import { fmtPct } from '../../lib/format';
import { newId } from '../../lib/id';
import { Button } from '../ui/Button';
import { NumberField, TextField } from '../ui/fields';

interface Row {
  id: string;
  name: string;
  grams: number;
}

interface Props {
  rows: Row[];
  onChange: (rows: Row[]) => void;
  addLabel: string;
  namePlaceholder: string;
  /** 각 행의 총 밀가루 대비 % (id → pct) */
  pcts?: Map<string, number>;
  minRows?: number;
}

export function GramRows({ rows, onChange, addLabel, namePlaceholder, pcts, minRows = 0 }: Props) {
  const update = (id: string, patch: Partial<Row>) =>
    onChange(rows.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  return (
    <div className="space-y-2">
      {rows.map((row) => (
        <div key={row.id} className="flex items-center gap-2">
          <TextField
            className="min-w-0 flex-1"
            value={row.name}
            onChange={(name) => update(row.id, { name })}
            placeholder={namePlaceholder}
            ariaLabel={`${namePlaceholder} 이름`}
          />
          <NumberField
            className="w-28 shrink-0"
            value={row.grams}
            onChange={(grams) => update(row.id, { grams })}
            unit="g"
            ariaLabel={`${row.name || namePlaceholder} 무게`}
          />
          {pcts && (
            <span className="w-14 shrink-0 text-right text-xs tabular-nums text-ink/60">
              {fmtPct(pcts.get(row.id) ?? 0)}
            </span>
          )}
          <Button
            small
            variant="ghost"
            aria-label={`${row.name || namePlaceholder} 행 삭제`}
            disabled={rows.length <= minRows}
            onClick={() => onChange(rows.filter((r) => r.id !== row.id))}
            className="shrink-0"
          >
            ×
          </Button>
        </div>
      ))}
      <Button
        small
        variant="ghost"
        onClick={() => onChange([...rows, { id: newId(), name: '', grams: 0 }])}
      >
        + {addLabel}
      </Button>
    </div>
  );
}
