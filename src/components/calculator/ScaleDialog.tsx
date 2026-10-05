import { useState } from 'react';
import type { Precision } from '../../lib/format';
import { fmtGrams } from '../../lib/format';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Segmented } from '../ui/Segmented';
import { NumberField } from '../ui/fields';

type Mode = 'factor' | 'weight' | 'pieces';

interface Props {
  open: boolean;
  onClose: () => void;
  /** 지금 총 반죽 무게 — 0 이하면 배율을 정할 수 없다 */
  doughWeight: number;
  pieces: number;
  precision: Precision;
  /** k는 유한한 양수. 개수 × 개당 모드면 분할 개수도 함께 */
  onApply: (factor: number, pieces?: number) => void;
}

/** 배율 조정 — 모든 재료의 그램을 같은 배율로 곱한다 (scaleDough). iOS ScaleRecipeSheet와 같은 선택지·범위 */
export function ScaleDialog(props: Props) {
  if (!props.open) return null;
  return <ScalePanel {...props} />;
}

function ScalePanel({ onClose, doughWeight, pieces, precision, onApply }: Props) {
  const [mode, setMode] = useState<Mode>('factor');
  const [factor, setFactor] = useState(1);
  const [weight, setWeight] = useState(0);
  const [count, setCount] = useState(pieces > 0 ? pieces : 0);
  const [each, setEach] = useState(0);

  // 배율은 0.01~100, 분할 개수는 분할 개수 칸과 같은 1~1000개 (iOS와 같다)
  const n = Math.round(count);
  const k =
    doughWeight > 0
      ? mode === 'factor'
        ? factor >= 0.01 && factor <= 100
          ? factor
          : NaN
        : mode === 'weight'
          ? weight / doughWeight
          : n >= 1 && n <= 1000
            ? (n * each) / doughWeight
            : NaN
      : NaN;
  const valid = Number.isFinite(k) && k > 0;

  const apply = (f: number) => {
    onApply(f, mode === 'pieces' ? n : undefined);
    onClose();
  };

  return (
    <Dialog
      open
      onClose={onClose}
      title="배율 조정"
      footer={
        <>
          <Button onClick={onClose}>취소</Button>
          <Button variant="primary" disabled={!valid} onClick={() => apply(k)}>
            적용
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <Segmented<Mode>
          ariaLabel="배율 조정 방식"
          value={mode}
          onChange={setMode}
          options={[
            { value: 'factor', label: '배율' },
            { value: 'weight', label: '총 반죽 무게' },
            { value: 'pieces', label: '개수 × 개당' },
          ]}
        />
        {mode === 'factor' && (
          <div className="flex flex-wrap items-end gap-2">
            <Button onClick={() => apply(0.5)}>절반으로 (×½)</Button>
            <Button onClick={() => apply(2)}>두 배로 (×2)</Button>
            <NumberField
              label="배율"
              unit="×"
              value={factor}
              onChange={setFactor}
              className="max-w-[160px]"
            />
          </div>
        )}
        {mode === 'weight' && (
          <NumberField
            label="총 반죽 무게"
            unit="g"
            value={weight}
            onChange={setWeight}
            className="max-w-[200px]"
          />
        )}
        {mode === 'pieces' && (
          <div className="flex flex-wrap gap-3">
            <NumberField
              label="분할 개수"
              unit="개"
              value={count}
              onChange={setCount}
              className="max-w-[160px]"
            />
            <NumberField
              label="개당 무게"
              unit="g"
              value={each}
              onChange={setEach}
              className="max-w-[160px]"
            />
          </div>
        )}
        <p className="text-sm tabular-nums text-ink/80" aria-live="polite">
          {fmtGrams(doughWeight, precision)} g →{' '}
          {valid ? (
            <>
              <strong className="text-brass">{fmtGrams(doughWeight * k, precision)} g</strong> (×
              {Math.round(k * 1000) / 1000})
            </>
          ) : (
            '—'
          )}
        </p>
        <p className="text-xs text-ink/70">
          모든 재료(바시나주·액체·이스트 포함)를 같은 배율로 늘리거나 줄여 수분율·소금·PFF는
          그대로입니다.
        </p>
      </div>
    </Dialog>
  );
}
