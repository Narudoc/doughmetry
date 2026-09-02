import { useMemo, useState } from 'react';
import type { DoughInput } from '../../lib/dough';
import { computeStats } from '../../lib/dough';
import { fmtGrams, fmtPct } from '../../lib/format';
import type { Settings } from '../../types';
import { IngredientForm } from '../calculator/IngredientForm';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { TextField } from '../ui/fields';

export interface ImportedDraft {
  name: string;
  input: DoughInput;
  recognizedText: string;
}

interface Props {
  onClose: () => void;
  draft: ImportedDraft;
  settings: Settings;
  onSave: (name: string, input: DoughInput) => void;
}

/**
 * AI 인식 결과 확인 화면 — 저장 전 필수 단계. 재료 입력 폼을 그대로 재사용한다.
 * draft마다 새로 마운트해서(부모에서 조건부 렌더) 이전 가져오기 상태가 남지 않는다.
 */
export function ImportReviewDialog({ onClose, draft, settings, onSave }: Props) {
  const [name, setName] = useState(draft.name);
  const [input, setInput] = useState<DoughInput>(() => structuredClone(draft.input));
  const stats = useMemo(() => computeStats(input), [input]);

  return (
    <Dialog
      open
      onClose={onClose}
      title="가져오기 확인"
      wide
      footer={
        <>
          <Button onClick={onClose}>취소</Button>
          <Button
            variant="primary"
            onClick={() => {
              onSave(name.trim() || '가져온 레시피', input);
              onClose();
            }}
          >
            저장
          </Button>
        </>
      }
    >
      <div className="max-h-[68vh] space-y-4 overflow-y-auto pr-1">
        <p className="rounded border border-bottle/20 bg-bottle/5 p-2.5 text-xs text-bottle">
          규칙 기반으로 분석했습니다 — 인식 결과를 확인·수정한 뒤 저장하세요.
        </p>
        <TextField label="레시피 이름" value={name} onChange={setName} placeholder="가져온 레시피" />
        <IngredientForm
          input={input}
          onChange={setInput}
          stats={stats}
          precision={settings.precision}
          basis={settings.pctBasis}
        />
        <div className="rounded border border-line bg-white p-3 text-sm tabular-nums">
          <span className="text-xs text-ink/60">지표 — </span>총 수분율{' '}
          <strong>{fmtPct(stats.hydrationPct)}</strong> · 총 반죽{' '}
          <strong>{fmtGrams(stats.doughWeight, settings.precision)} g</strong> · PFF{' '}
          <strong>{fmtPct(stats.pffPct)}</strong>
        </div>
        <details>
          <summary className="cursor-pointer text-xs text-ink/60">인식된 원본 텍스트</summary>
          <pre className="mt-1 max-h-40 overflow-y-auto whitespace-pre-wrap rounded bg-white p-2 text-xs text-ink/60">
            {draft.recognizedText}
          </pre>
        </details>
      </div>
    </Dialog>
  );
}
