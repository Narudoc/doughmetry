import { useEffect, useMemo, useRef, useState } from 'react';
import type { RecipesApi } from '../../hooks/useRecipes';
import type { DoughInput } from '../../lib/dough';
import { computeStats } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtDate, fmtGrams, fmtPct } from '../../lib/format';
import { newId } from '../../lib/id';
import { OcrError, recognizeImage } from '../../lib/ocr';
import { cleanForParsing, parseRecipeText } from '../../lib/recipeParser';
import { exportJson, importJson } from '../../lib/storage';
import { doughInputFromRecipe } from '../../state';
import type { Recipe, Settings } from '../../types';
import { Button } from '../ui/Button';
import { ConfirmDialog, Dialog, PromptDialog } from '../ui/Dialog';
import { TextField } from '../ui/fields';
import { ImportReviewDialog, type ImportedDraft } from './ImportReviewDialog';

interface Props {
  api: RecipesApi;
  settings: Settings;
  onOpenInCalculator: (r: Recipe) => void;
  onSendToConverter: (r: Recipe) => void;
  toast: (message: string) => void;
}

function downloadText(filename: string, text: string) {
  const blob = new Blob([text], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function RecipesPage({ api, settings, onOpenInCalculator, onSendToConverter, toast }: Props) {
  const [query, setQuery] = useState('');
  const [activeTag, setActiveTag] = useState<string | null>(null);
  const [renameTarget, setRenameTarget] = useState<Recipe | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Recipe | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  // AI 레시피 가져오기 (사진·텍스트 → 규칙 기반 파서 → 확인 후 저장)
  const imageRef = useRef<HTMLInputElement>(null);
  const [textImportOpen, setTextImportOpen] = useState(false);
  const [reviewDraft, setReviewDraft] = useState<ImportedDraft | null>(null);
  const [aiImportFail, setAiImportFail] = useState<{
    message: string;
    recognizedText?: string;
  } | null>(null);
  const [ocrProgress, setOcrProgress] = useState<number | null>(null);

  const allTags = useMemo(
    () => [...new Set(api.recipes.flatMap((r) => r.tags ?? []))].sort(),
    [api.recipes],
  );

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return api.recipes
      .filter((r) => {
        if (activeTag && !(r.tags ?? []).includes(activeTag)) return false;
        if (!q) return true;
        const haystack = [r.name, r.note ?? '', ...(r.tags ?? [])].join(' ').toLowerCase();
        return haystack.includes(q);
      })
      .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }, [api.recipes, query, activeTag]);

  const handleImportFile = async (file: File) => {
    let text: string;
    try {
      text = await file.text();
    } catch {
      setImportError('파일을 읽을 수 없습니다');
      return;
    }
    const res = importJson(text);
    if (res.ok) {
      api.importAll(res.recipes);
      setImportError(null);
      toast(`${res.recipes.length}개 레시피를 가져왔습니다`);
    } else {
      setImportError(res.reason);
    }
  };

  /** 텍스트 → 파서 → 확인 다이얼로그 (사진·텍스트 공통 경로) */
  const handleRecognizedText = (raw: string) => {
    const text = cleanForParsing(raw);
    const parsed = parseRecipeText(text);
    if (parsed.matchedLineCount === 0) {
      setAiImportFail({
        message: '재료를 인식하지 못했습니다. 재료와 g 수량이 줄 단위로 적힌 텍스트가 필요합니다.',
        recognizedText: text.trim() || undefined,
      });
      return;
    }
    setAiImportFail(null);
    setReviewDraft({ name: parsed.name ?? '', input: parsed.input, recognizedText: text });
  };

  const handleImageFile = async (file: File) => {
    setOcrProgress(0);
    try {
      const text = await recognizeImage(file, (p) => setOcrProgress(p));
      // iOS와 동일하게 '글자 없음'은 사진 경로에서만 판정한다
      if (text.trim() === '') {
        setAiImportFail({ message: '사진에서 글자를 찾지 못했습니다.' });
        return;
      }
      handleRecognizedText(text);
    } catch (e) {
      setAiImportFail({
        message:
          e instanceof OcrError && e.kind === 'unreadable-image'
            ? '이미지를 읽을 수 없습니다. 다른 사진으로 다시 시도하세요.'
            : '문자 인식(OCR) 모듈을 불러오지 못했습니다. 네트워크 연결을 확인한 뒤 다시 시도하세요.',
      });
    } finally {
      setOcrProgress(null);
    }
  };

  const handleReviewSave = (name: string, input: DoughInput) => {
    const now = new Date().toISOString();
    const recipe: Recipe = {
      id: newId(),
      schemaVersion: 2,
      name,
      createdAt: now,
      updatedAt: now,
      ...structuredClone(input),
    };
    api.save(recipe);
    toast(`'${name}' 레시피를 가져왔습니다`);
  };

  return (
    <div className="no-print space-y-5">
      <div className="flex flex-wrap items-center gap-2">
        <TextField
          value={query}
          onChange={setQuery}
          placeholder="이름·태그·메모 검색"
          ariaLabel="레시피 검색"
          className="min-w-[200px] flex-1"
        />
        <Button disabled={ocrProgress !== null} onClick={() => imageRef.current?.click()}>
          {ocrProgress !== null
            ? `사진 인식 중… ${Math.round(ocrProgress * 100)}%`
            : '사진에서 가져오기'}
        </Button>
        <Button disabled={ocrProgress !== null} onClick={() => setTextImportOpen(true)}>
          텍스트에서 가져오기
        </Button>
        <Button disabled={ocrProgress !== null} onClick={() => fileRef.current?.click()}>
          JSON 가져오기
        </Button>
        <Button
          disabled={api.recipes.length === 0}
          onClick={() => {
            downloadText('levain-calc-recipes.json', exportJson(api.recipes));
            toast('전체 레시피를 JSON으로 내보냈습니다');
          }}
        >
          전체 내보내기
        </Button>
        <input
          ref={fileRef}
          type="file"
          accept=".json,application/json"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) void handleImportFile(f);
            e.target.value = '';
          }}
        />
        <input
          ref={imageRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) void handleImageFile(f);
            e.target.value = '';
          }}
        />
      </div>

      {importError && (
        <div className="rounded border border-danger/40 bg-danger/5 p-3 text-sm text-danger">
          가져오기 실패: {importError}
        </div>
      )}

      {aiImportFail && (
        <div className="space-y-2 rounded border border-danger/40 bg-danger/5 p-3 text-sm">
          <p className="font-medium text-danger">{aiImportFail.message}</p>
          {aiImportFail.recognizedText && (
            <details>
              <summary className="cursor-pointer text-xs text-ink/60">인식된 원본 텍스트</summary>
              <pre className="mt-1 max-h-40 overflow-y-auto whitespace-pre-wrap rounded bg-white p-2 text-xs text-ink/60">
                {aiImportFail.recognizedText}
              </pre>
            </details>
          )}
          <Button small onClick={() => setAiImportFail(null)}>
            닫기
          </Button>
        </div>
      )}

      {allTags.length > 0 && (
        <div className="flex flex-wrap gap-1.5" role="group" aria-label="태그 필터">
          <TagChip label="전체" active={activeTag === null} onClick={() => setActiveTag(null)} />
          {allTags.map((t) => (
            <TagChip
              key={t}
              label={t}
              active={activeTag === t}
              onClick={() => setActiveTag(activeTag === t ? null : t)}
            />
          ))}
        </div>
      )}

      {filtered.length === 0 ? (
        <p className="rounded-lg border border-dashed border-line bg-white/50 p-8 text-center text-sm text-ink/50">
          {api.recipes.length === 0
            ? '저장된 레시피가 없습니다. 계산기에서 레시피를 만들어 저장해 보세요.'
            : '검색 결과가 없습니다.'}
        </p>
      ) : (
        <ul className="grid gap-3 sm:grid-cols-2">
          {filtered.map((r) => (
            <RecipeCard
              key={r.id}
              recipe={r}
              precision={settings.precision}
              onOpen={() => onOpenInCalculator(r)}
              onConvert={() => onSendToConverter(r)}
              onRename={() => setRenameTarget(r)}
              onDuplicate={() => {
                api.duplicate(r.id);
                toast(`'${r.name}' 레시피를 복제했습니다`);
              }}
              onExport={() => downloadText(`${r.name}.json`, exportJson([r]))}
              onDelete={() => setDeleteTarget(r)}
            />
          ))}
        </ul>
      )}

      <PromptDialog
        open={renameTarget !== null}
        onClose={() => setRenameTarget(null)}
        title="이름 변경"
        label="레시피 이름"
        initialValue={renameTarget?.name ?? ''}
        submitLabel="변경"
        onSubmit={(name) => {
          if (renameTarget) {
            api.rename(renameTarget.id, name);
            toast('이름을 변경했습니다');
          }
        }}
      />
      <ConfirmDialog
        open={deleteTarget !== null}
        onClose={() => setDeleteTarget(null)}
        title="레시피 삭제"
        message={`'${deleteTarget?.name}' 레시피를 삭제할까요? 되돌릴 수 없습니다.`}
        onConfirm={() => {
          if (deleteTarget) {
            api.remove(deleteTarget.id);
            toast(`'${deleteTarget.name}' 레시피를 삭제했습니다`);
          }
        }}
      />
      <TextImportDialog
        open={textImportOpen}
        onClose={() => setTextImportOpen(false)}
        onSubmit={handleRecognizedText}
      />
      {reviewDraft !== null && (
        <ImportReviewDialog
          onClose={() => setReviewDraft(null)}
          draft={reviewDraft}
          settings={settings}
          onSave={handleReviewSave}
        />
      )}
    </div>
  );
}

/** 텍스트 붙여넣기 입력 다이얼로그 */
function TextImportDialog({
  open,
  onClose,
  onSubmit,
}: {
  open: boolean;
  onClose: () => void;
  onSubmit: (text: string) => void;
}) {
  const [text, setText] = useState('');
  useEffect(() => {
    if (open) setText('');
  }, [open]);

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="텍스트에서 가져오기"
      footer={
        <>
          <Button onClick={onClose}>취소</Button>
          <Button
            variant="primary"
            disabled={text.trim() === ''}
            onClick={() => {
              onClose();
              onSubmit(text);
            }}
          >
            분석
          </Button>
        </>
      }
    >
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        rows={10}
        autoFocus
        placeholder={'레시피 텍스트를 붙여넣으세요\n\n예)\n캉파뉴\nT65 900g\n물 620g\n소금 20g\n르방 리퀴드 200g'}
        className="w-full rounded border border-line bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brass"
      />
    </Dialog>
  );
}

function TagChip({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      aria-pressed={active}
      onClick={onClick}
      className={`min-h-[32px] rounded-full border px-3 text-xs font-medium transition-colors motion-reduce:transition-none ${
        active
          ? 'border-bottle bg-bottle text-paper'
          : 'border-line bg-white text-ink/70 hover:border-bottle/40'
      }`}
    >
      {label}
    </button>
  );
}

interface CardProps {
  recipe: Recipe;
  precision: Precision;
  onOpen: () => void;
  onConvert: () => void;
  onRename: () => void;
  onDuplicate: () => void;
  onExport: () => void;
  onDelete: () => void;
}

function RecipeCard({
  recipe,
  precision,
  onOpen,
  onConvert,
  onRename,
  onDuplicate,
  onExport,
  onDelete,
}: CardProps) {
  const stats = useMemo(() => computeStats(doughInputFromRecipe(recipe)), [recipe]);
  const levainLabel = recipe.levain.type === 'liquide' ? '리퀴드' : '뒤흐';

  return (
    <li className="rounded-lg border border-line bg-white p-4">
      <div className="flex items-start justify-between gap-2">
        <h3 className="font-semibold">{recipe.name}</h3>
        <span className="shrink-0 text-xs tabular-nums text-ink/50">{fmtDate(recipe.updatedAt)}</span>
      </div>
      {recipe.tags && recipe.tags.length > 0 && (
        <div className="mt-1 flex flex-wrap gap-1">
          {recipe.tags.map((t) => (
            <span key={t} className="rounded-full bg-bottle/10 px-2 py-0.5 text-xs text-bottle">
              {t}
            </span>
          ))}
        </div>
      )}
      <p className="mt-2 text-sm tabular-nums text-ink/70">
        수분율 {fmtPct(stats.hydrationPct)} · {fmtGrams(stats.doughWeight, precision)} g · 르방{' '}
        {levainLabel} {(recipe.levain.hydration * 100).toFixed(0)}%
      </p>
      {recipe.note && <p className="mt-1 truncate text-xs text-ink/50">{recipe.note}</p>}
      <div className="mt-3 flex flex-wrap gap-1.5">
        <Button small onClick={onOpen}>
          계산기로
        </Button>
        <Button small onClick={onConvert}>
          변환기로
        </Button>
        <Button small variant="ghost" onClick={onRename}>
          이름 변경
        </Button>
        <Button small variant="ghost" onClick={onDuplicate}>
          복제
        </Button>
        <Button small variant="ghost" onClick={onExport}>
          JSON
        </Button>
        <Button small variant="ghost" className="text-danger hover:bg-danger/5" onClick={onDelete}>
          삭제
        </Button>
      </div>
    </li>
  );
}
