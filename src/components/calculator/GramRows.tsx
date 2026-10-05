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
  /** 이름 칸이 비었을 때 화면 읽기 프로그램이 부르는 이름 (행 이름·무게·삭제) */
  namePlaceholder: string;
  /** 이름 칸에 보이는 예시 — 없으면 namePlaceholder */
  nameExample?: string;
  /** 각 행의 총 밀가루 대비 % (id → pct) */
  pcts?: Map<string, number>;
  minRows?: number;
}

export function GramRows({
  rows,
  onChange,
  addLabel,
  namePlaceholder,
  nameExample,
  pcts,
  minRows = 0,
}: Props) {
  const update = (id: string, patch: Partial<Row>) =>
    onChange(rows.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  return (
    <div className="space-y-2">
      {rows.map((row) => (
        // 이름 칸이 7rem보다 좁아질 자리(좁은 다이얼로그 등)에서는 무게·%·삭제를 묶어 다음 줄 오른쪽으로 내린다
        <div key={row.id} className="flex flex-wrap items-center gap-2">
          <TextField
            className="min-w-[7rem] flex-1 basis-28"
            value={row.name}
            onChange={(name) => update(row.id, { name })}
            placeholder={nameExample ?? namePlaceholder}
            ariaLabel={`${namePlaceholder} 이름`}
          />
          <div className="ml-auto flex shrink-0 items-center gap-2">
            <NumberField
              className="w-28 shrink-0"
              value={row.grams}
              onChange={(grams) => update(row.id, { grams })}
              unit="g"
              ariaLabel={`${row.name || namePlaceholder} 무게`}
            />
            {pcts && (
              <span className="w-14 shrink-0 text-right text-xs tabular-nums text-ink/70">
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
