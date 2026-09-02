import { DEFAULT_LEVAIN_HYDRATION, levainTypeFor } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct } from '../../lib/format';
import type { Levain, LevainType } from '../../types';
import { Segmented } from '../ui/Segmented';
import { NumberField, TextField } from '../ui/fields';

interface Props {
  levain: Levain;
  onChange: (l: Levain) => void;
  breakdown: { flour: number; water: number };
  pff: number;
  /** 표시 기준에 따른 르방 행 % — total이면 PFF, added면 르방 무게/첨가 밀가루 */
  levainPct: number;
  basisAdded: boolean;
  precision: Precision;
}

export function LevainControl({
  levain,
  onChange,
  breakdown,
  pff,
  levainPct,
  basisAdded,
  precision,
}: Props) {
  return (
    <div className="space-y-3">
      <Segmented<LevainType>
        ariaLabel="르방 타입"
        value={levain.type}
        onChange={(type) =>
          onChange({ ...levain, type, hydration: DEFAULT_LEVAIN_HYDRATION[type] })
        }
        options={[
          {
            value: 'liquide',
            label: (
              <span>
                리퀴드 <span className="italic opacity-70">liquide</span> 100%
              </span>
            ),
          },
          {
            value: 'dur',
            label: (
              <span>
                뒤흐 <span className="italic opacity-70">dur</span> 50%
              </span>
            ),
          },
        ]}
      />
      <div className="grid grid-cols-2 gap-3">
        <NumberField
          label="르방 수분율"
          unit="%"
          min={1}
          value={levain.hydration * 100}
          onChange={(v) =>
            onChange({ ...levain, hydration: v / 100, type: levainTypeFor(v / 100) })
          }
        />
        <NumberField
          label="르방 양"
          unit="g"
          value={levain.grams}
          onChange={(grams) => onChange({ ...levain, grams })}
        />
      </div>
      <TextField
        label="르방 밀가루 (표시용)"
        value={levain.flourName ?? ''}
        onChange={(flourName) => onChange({ ...levain, flourName: flourName || undefined })}
        placeholder="T65"
      />
      <p className="text-xs tabular-nums text-ink/60">
        {basisAdded ? (
          <>
            속 밀가루 {fmtGrams(breakdown.flour, precision)} g · 속 물{' '}
            {fmtGrams(breakdown.water, precision)} g · 첨가 밀가루 대비 르방 {fmtPct(levainPct)}{' '}
            (PFF {fmtPct(pff)})
          </>
        ) : (
          <>
            속 밀가루 {fmtGrams(breakdown.flour, precision)} g (PFF {fmtPct(pff)}) · 속 물{' '}
            {fmtGrams(breakdown.water, precision)} g
          </>
        )}
      </p>
    </div>
  );
}
