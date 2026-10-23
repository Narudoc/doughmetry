import type { TargetForm } from '../../state';
import type { Precision } from '../../lib/format';
import { fmtGrams } from '../../lib/format';
import { Button } from '../ui/Button';
import { Fr } from '../ui/Fr';
import { NumberField } from '../ui/fields';
import { Segmented } from '../ui/Segmented';
import { SectionTitle } from './IngredientForm';

interface Props {
  target: TargetForm;
  onChange: (t: TargetForm) => void;
  precision: Precision;
}

/** 모드 B — 목표 반죽 무게에서 역산 */
export function TargetFormView({ target, onChange, precision }: Props) {
  const patch = (p: Partial<TargetForm>) => onChange({ ...target, ...p });

  return (
    <div className="space-y-5">
      <section className="space-y-2">
        <SectionTitle ko="목표 반죽" fr="pâte" />
        <Segmented<'total' | 'pieces'>
          ariaLabel="반죽 무게 입력 방식"
          value={target.byPieces ? 'pieces' : 'total'}
          onChange={(v) => patch({ byPieces: v === 'pieces' })}
          options={[
            { value: 'total', label: '총 무게' },
            { value: 'pieces', label: '개수 × 개당 무게' },
          ]}
        />
        {target.byPieces ? (
          <div className="grid grid-cols-2 gap-3">
            <NumberField
              label="분할 개수"
              unit="개"
              value={target.pieces}
              onChange={(pieces) => patch({ pieces })}
            />
            <NumberField
              label="개당 무게"
              unit="g"
              value={target.pieceWeight}
              onChange={(pieceWeight) => patch({ pieceWeight })}
            />
            <p className="col-span-2 text-xs tabular-nums text-ink/70">
              총 반죽 무게 = {fmtGrams(target.pieces * target.pieceWeight, precision)} g
            </p>
          </div>
        ) : (
          <NumberField
            label="목표 총 반죽 무게"
            unit="g"
            value={target.doughWeight}
            onChange={(doughWeight) => patch({ doughWeight })}
            className="max-w-[220px]"
          />
        )}
      </section>

      <section className="space-y-2">
        <SectionTitle ko="목표 비율" fr="proportions" />
        <div className="grid grid-cols-2 gap-3">
          <NumberField
            label={
              <>
                총 수분율 <Fr>hydratation</Fr>
              </>
            }
            unit="%"
            value={target.hydrationPct}
            onChange={(hydrationPct) => patch({ hydrationPct })}
          />
          <NumberField
            label="소금 (총 밀가루 대비)"
            unit="%"
            value={target.saltPct}
            onChange={(saltPct) => patch({ saltPct })}
          />
          <NumberField
            label="발효종 밀가루 PFF"
            unit="%"
            value={target.pffPct}
            onChange={(pffPct) => patch({ pffPct })}
          />
          <div>
            <NumberField
              label="르방 수분율"
              unit="%"
              min={1}
              value={target.levainHydrationPct}
              onChange={(levainHydrationPct) => patch({ levainHydrationPct })}
            />
            <div className="mt-1 flex gap-1">
              <Button small variant="ghost" onClick={() => patch({ levainHydrationPct: 100 })}>
                리퀴드 100%
              </Button>
              <Button small variant="ghost" onClick={() => patch({ levainHydrationPct: 50 })}>
                뒤흐 50%
              </Button>
            </div>
          </div>
        </div>
        <p className="text-xs text-ink/70">
          밀가루·물·소금·르방만 역산합니다. 바시나주·액체·이스트는 재료 입력 모드에서.
        </p>
      </section>
    </div>
  );
}
