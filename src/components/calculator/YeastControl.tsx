import { convertYeast } from '../../lib/dough';
import { fmtGrams, fmtPct } from '../../lib/format';
import type { Yeast, YeastType } from '../../types';
import { Segmented } from '../ui/Segmented';
import { NumberField } from '../ui/fields';

const LABEL: Record<YeastType, string> = {
  fresh: '생이스트',
  instant: '인스턴트 드라이',
};

interface Props {
  yeast: Yeast;
  onChange: (y: Yeast) => void;
  /** 총 밀가루 대비 % */
  pct: number;
}

/** 이스트 — 생이스트 기본, 인스턴트 드라이 전환 시 40% 비율로 자동 환산 */
export function YeastControl({ yeast, onChange, pct }: Props) {
  const other: YeastType = yeast.type === 'fresh' ? 'instant' : 'fresh';

  return (
    <div className="space-y-3">
      <Segmented<YeastType>
        ariaLabel="이스트 종류"
        value={yeast.type}
        onChange={(type) =>
          onChange({ type, grams: convertYeast(yeast.grams, yeast.type, type) })
        }
        options={[
          { value: 'fresh', label: LABEL.fresh },
          { value: 'instant', label: `${LABEL.instant} (IDY)` },
        ]}
      />
      <NumberField
        label={`${LABEL[yeast.type]} 양 (0 = 사용 안 함)`}
        unit="g"
        value={yeast.grams}
        onChange={(grams) => onChange({ ...yeast, grams })}
        className="max-w-[220px]"
      />
      {yeast.grams > 0 && (
        <p className="text-xs tabular-nums text-ink/60">
          = {LABEL[other]} {fmtGrams(convertYeast(yeast.grams, yeast.type, other), 0.1)} g (환산
          비율 40%) · 총 밀가루 대비 {fmtPct(pct, 2)}
        </p>
      )}
    </div>
  );
}
