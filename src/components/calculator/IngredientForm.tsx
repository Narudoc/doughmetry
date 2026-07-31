import type { DoughInput, DoughStats } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { GramRows } from './GramRows';
import { LevainControl } from './LevainControl';
import { NumberField } from '../ui/fields';

export function SectionTitle({ ko, fr }: { ko: string; fr: string }) {
  return (
    <h3 className="font-display text-sm font-semibold uppercase tracking-widest text-bottle">
      {ko} <span className="ml-1 font-normal normal-case italic text-bottle/60">{fr}</span>
    </h3>
  );
}

interface Props {
  input: DoughInput;
  onChange: (input: DoughInput) => void;
  stats: DoughStats;
  precision: Precision;
}

/** 모드 A 입력 폼 — 변환기의 '직접 입력'에서도 재사용 */
export function IngredientForm({ input, onChange, stats, precision }: Props) {
  const flourPcts = new Map(stats.flourPcts.map((p) => [p.id, p.pct]));
  const extraPcts = new Map(stats.extraPcts.map((p) => [p.id, p.pct]));

  return (
    <div className="space-y-5">
      <section className="space-y-2">
        <SectionTitle ko="밀가루" fr="farines" />
        <GramRows
          rows={input.flours}
          onChange={(flours) => onChange({ ...input, flours })}
          addLabel="밀가루 추가"
          namePlaceholder="밀가루"
          pcts={flourPcts}
          minRows={1}
        />
      </section>

      <section className="grid grid-cols-2 gap-3">
        <NumberField
          label="물 (eau)"
          unit="g"
          value={input.water}
          onChange={(water) => onChange({ ...input, water })}
        />
        <NumberField
          label="소금 (sel)"
          unit="g"
          value={input.salt}
          onChange={(salt) => onChange({ ...input, salt })}
        />
      </section>

      <section className="space-y-2">
        <SectionTitle ko="르방" fr="levain" />
        <LevainControl
          levain={input.levain}
          onChange={(levain) => onChange({ ...input, levain })}
          breakdown={{ flour: stats.levainFlour, water: stats.levainWater }}
          pff={stats.pffPct}
          precision={precision}
        />
      </section>

      <section className="space-y-2">
        <SectionTitle ko="기타 재료" fr="garnitures" />
        <GramRows
          rows={input.extras}
          onChange={(extras) => onChange({ ...input, extras })}
          addLabel="재료 추가"
          namePlaceholder="몰트, 씨앗…"
          pcts={extraPcts}
        />
        <p className="text-xs text-ink/50">v1에서는 기타 재료의 수분을 계산에 반영하지 않습니다.</p>
      </section>
    </div>
  );
}
