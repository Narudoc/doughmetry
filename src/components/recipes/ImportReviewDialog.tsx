import { useMemo, useState } from 'react';
import type { DoughInput } from '../../lib/dough';
import { computeStats } from '../../lib/dough';
import { fmtGrams, fmtPct } from '../../lib/format';
import type { Settings } from '../../types';
import { IngredientForm } from '../calculator/IngredientForm';
import { Button } from '../ui/Button';
import { DISCARD_PROMPT, Dialog } from '../ui/Dialog';
import { NumberField, TextField } from '../ui/fields';

export interface ImportedDraft {
  name: string;
  input: DoughInput;
  /** 공정(만드는 법) 원문 — 노트로 저장한다 */
  note: string;
  /** 분량 표기에서 읽은 분할 개수 (0 = 사용 안 함) */
  pieces: number;
  recognizedText: string;
}

interface Props {
  onClose: () => void;
  draft: ImportedDraft;
  settings: Settings;
  /** note는 비었으면 undefined, pieces는 0이면 undefined */
  onSave: (name: string, input: DoughInput, note: string | undefined, pieces: number | undefined) => void;
}

/** 파서가 물을 바시나주로 잘못 나눴을 때의 신호 — iOS ImportReviewSheet.sanityHints와 같은 조건·문구 */
function sanityHint(input: DoughInput): string | null {
  const hasDough = input.flours.some((f) => f.grams > 0) || input.levain.grams > 0;
  if (hasDough && input.water === 0 && input.bassinage > 0) {
    return '본반죽 물이 0 g이고 바시나주만 있습니다 — 원본 텍스트와 대조하세요';
  }
  if (input.water > 0 && input.bassinage > input.water) return '바시나주가 본반죽 물보다 많습니다';
  return null;
}

/**
 * AI 인식 결과 확인 화면 — 저장 전 필수 단계. 재료 입력 폼을 그대로 재사용한다.
 * draft마다 새로 마운트해서(부모에서 조건부 렌더) 이전 가져오기 상태가 남지 않는다.
 */
export function ImportReviewDialog({ onClose, draft, settings, onSave }: Props) {
  const [name, setName] = useState(draft.name);
  const [input, setInput] = useState<DoughInput>(() => structuredClone(draft.input));
  const [note, setNote] = useState(draft.note);
  const [pieces, setPieces] = useState(draft.pieces);
  const stats = useMemo(() => computeStats(input), [input]);
  const draftJson = useMemo(() => JSON.stringify(draft.input), [draft.input]);
  const edited =
    name !== draft.name ||
    JSON.stringify(input) !== draftJson ||
    note !== draft.note ||
    pieces !== draft.pieces;
  const hint = sanityHint(input);

  return (
    <Dialog
      open
      onClose={onClose}
      title="가져오기 확인"
      wide
      // 인식 결과는 다시 만들려면 사진 인식부터 반복해야 하므로 수정 전이라도 배경·Escape로는 바로 닫지 않는다
      confirmDismiss
      footer={
        <>
          <Button
            onClick={() => {
              if (edited && !window.confirm(DISCARD_PROMPT)) return;
              onClose();
            }}
          >
            취소
          </Button>
          <Button
            variant="primary"
            onClick={() => {
              onSave(
                name.trim() || '가져온 레시피',
                input,
                note.trim() || undefined,
                pieces > 0 ? pieces : undefined,
              );
              onClose();
            }}
          >
            저장
          </Button>
        </>
      }
    >
      <div className="max-h-[68vh] scroll-pb-20 space-y-4 overflow-y-auto pr-1">
        <p className="rounded border border-bottle/20 bg-bottle/5 p-2.5 text-xs text-bottle">
          규칙 기반으로 분석했습니다 — 인식 결과를 확인·수정한 뒤 저장하세요.
        </p>
        {hint && (
          <p
            role="status"
            className="flex items-start gap-1.5 rounded border border-danger/40 bg-danger/5 p-2.5 text-xs text-danger"
          >
            <span aria-hidden="true">⚠</span>
            {hint}
          </p>
        )}
        <TextField label="레시피 이름" value={name} onChange={setName} placeholder="가져온 레시피" />
        <IngredientForm
          input={input}
          onChange={setInput}
          stats={stats}
          precision={settings.precision}
          basis={settings.pctBasis}
        />
        <NumberField
          label="분할 개수 (0 = 사용 안 함)"
          unit="개"
          value={pieces}
          onChange={setPieces}
          className="max-w-[200px]"
        />
        <label className="block">
          <span className="mb-1 block text-xs font-medium text-ink/70">노트</span>
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            rows={4}
            className="w-full rounded border border-line bg-white px-3 py-2 text-base focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brass"
          />
          <span className="mt-1 block text-xs text-ink/70">만드는 법은 노트로 저장됩니다</span>
        </label>
        {/* 인식 결과를 고치는 동안 지표가 스크롤 밖으로 사라지지 않게 */}
        <div className="sticky bottom-0 z-10 rounded border border-line bg-white p-3 text-sm tabular-nums shadow-sm">
          <span className="text-xs text-ink/70">지표 — </span>총 수분율{' '}
          <strong className="text-brass">{fmtPct(stats.hydrationPct)}</strong> · 총 반죽{' '}
          <strong>{fmtGrams(stats.doughWeight, settings.precision)} g</strong> · PFF{' '}
          <strong>{fmtPct(stats.pffPct)}</strong>
        </div>
        <details>
          <summary className="cursor-pointer text-xs text-ink/70">인식된 원본 텍스트</summary>
          <pre className="mt-1 max-h-40 overflow-y-auto whitespace-pre-wrap rounded bg-white p-2 text-xs text-ink/70">
            {draft.recognizedText}
          </pre>
        </details>
      </div>
    </Dialog>
  );
}
