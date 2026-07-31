import { useMemo, useRef, useState } from 'react';
import type { RecipesApi } from '../../hooks/useRecipes';
import { computeStats } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtDate, fmtGrams, fmtPct } from '../../lib/format';
import { exportJson, importJson } from '../../lib/storage';
import { doughInputFromRecipe } from '../../state';
import type { Recipe, Settings } from '../../types';
import { Button } from '../ui/Button';
import { ConfirmDialog, PromptDialog } from '../ui/Dialog';
import { TextField } from '../ui/fields';

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
    const text = await file.text();
    const res = importJson(text);
    if (res.ok) {
      api.importAll(res.recipes);
      setImportError(null);
      toast(`${res.recipes.length}개 레시피를 가져왔습니다`);
    } else {
      setImportError(res.reason);
    }
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
        <Button onClick={() => fileRef.current?.click()}>JSON 가져오기</Button>
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
      </div>

      {importError && (
        <div className="rounded border border-danger/40 bg-danger/5 p-3 text-sm text-danger">
          가져오기 실패: {importError}
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
    </div>
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
