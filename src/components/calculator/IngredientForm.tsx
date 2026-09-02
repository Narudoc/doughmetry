import type { DoughInput, DoughStats } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { uiLevainPct, uiPct } from '../../lib/format';
import type { PctBasis } from '../../types';
import { GramRows } from './GramRows';
import { LevainControl } from './LevainControl';
import { LiquidRows } from './LiquidRows';
import { YeastControl } from './YeastControl';
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
  basis: PctBasis;
}

/** 모드 A 입력 폼 — 변환기의 '직접 입력'에서도 재사용 */
export function IngredientForm({ input, onChange, stats, precision, basis }: Props) {
  const flourPcts = new Map(input.flours.map((f) => [f.id, uiPct(stats, f.grams, basis)]));
  const liquidPcts = new Map(input.liquids.map((l) => [l.id, uiPct(stats, l.grams, basis)]));
  const extraPcts = new Map(input.extras.map((e) => [e.id, uiPct(stats, e.grams, basis)]));

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
        <p className="text-xs text-ink/50">
          {basis === 'added'
            ? '%는 첨가 밀가루 기준(베이커스 퍼센트)입니다.'
            : '%는 총 밀가루(첨가 + 르방 속) 기준입니다.'}
        </p>
      </section>

      <section className="space-y-2">
        <SectionTitle ko="물 · 소금" fr="eau & sel" />
        <div className="grid grid-cols-2 gap-3">
          <NumberField
            label="본반죽 물"
            unit="g"
            value={input.water}
            onChange={(water) => onChange({ ...input, water })}
          />
          <NumberField
            label="바시나주 (bassinage)"
            unit="g"
            value={input.bassinage}
            onChange={(bassinage) => onChange({ ...input, bassinage })}
          />
          <NumberField
            label="소금 (sel)"
            unit="g"
            value={input.salt}
            onChange={(salt) => onChange({ ...input, salt })}
          />
        </div>
        <p className="text-xs text-ink/50">
          바시나주는 반죽 후반에 추가하는 물로, 총 수분율에 합산됩니다.
        </p>
      </section>

      <section className="space-y-2">
        <SectionTitle ko="르방" fr="levain" />
        <LevainControl
          levain={input.levain}
          onChange={(levain) => onChange({ ...input, levain })}
          breakdown={{ flour: stats.levainFlour, water: stats.levainWater }}
          pff={stats.pffPct}
          levainPct={uiLevainPct(stats, input.levain.grams, basis)}
          basisAdded={basis === 'added'}
          precision={precision}
        />
      </section>

      <section className="space-y-2">
        <SectionTitle ko="액체 재료" fr="liquides" />
        <LiquidRows
          rows={input.liquids}
          onChange={(liquids) => onChange({ ...input, liquids })}
          precision={precision}
          pcts={liquidPcts}
        />
        <p className="text-xs text-ink/50">
          각 재료의 수분율만큼 총 수분율에 반영됩니다 (우유 88% · 계란 76%, USDA 기준).
        </p>
      </section>

      <section className="space-y-2">
        <SectionTitle ko="이스트" fr="levure" />
        <YeastControl
          yeast={input.yeast}
          onChange={(yeast) => onChange({ ...input, yeast })}
          pct={uiPct(stats, input.yeast.grams, basis)}
          pctLabel={basis === 'added' ? '첨가 밀가루 대비' : '총 밀가루 대비'}
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
        <p className="text-xs text-ink/50">
          기타 재료는 무게에만 합산되고 수분 계산에서 제외됩니다. 수분이 있는 재료는 위의 액체
          재료에 입력하세요.
        </p>
      </section>
    </div>
  );
}
