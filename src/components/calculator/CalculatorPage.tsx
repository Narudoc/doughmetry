import { useEffect, useMemo, useRef, useState } from 'react';
import type { RecipesApi } from '../../hooks/useRecipes';
import type { DoughInput } from '../../lib/dough';
import { computeStats, scaleDough } from '../../lib/dough';
import { ficheText } from '../../lib/fiche';
import { fmtGrams } from '../../lib/format';
import { newId } from '../../lib/id';
import type { CalcState } from '../../state';
import {
  LOAD_OVER_DIRTY_PROMPT,
  NEW_CALC_PROMPT,
  calcStateAfterSave,
  calcStateFromRecipe,
  currentDoughInput,
  currentPieces,
  isCalcDirty,
  overwriteTarget,
  resetCalcState,
  targetSpecFromForm,
} from '../../state';
import type { Recipe, Settings } from '../../types';
import { RecipePickerDialog } from '../recipes/RecipePickerDialog';
import { Button } from '../ui/Button';
import { Dialog, SaveRecipeDialog } from '../ui/Dialog';
import { Segmented } from '../ui/Segmented';
import { NumberField, TextField } from '../ui/fields';
import { BakersTable } from './BakersTable';
import { IngredientForm } from './IngredientForm';
import { PrintFiche } from './PrintFiche';
import { ResultSummary } from './ResultSummary';
import { ScaleDialog } from './ScaleDialog';
import { SummaryBar } from './SummaryBar';
import { TargetFormView } from './TargetFormView';

interface Props {
  state: CalcState;
  onChange: (s: CalcState) => void;
  settings: Settings;
  api: RecipesApi;
  onSendToConverter: (name: string, input: DoughInput) => void;
  toast: (message: string) => void;
}

export function CalculatorPage({ state, onChange, settings, api, onSendToConverter, toast }: Props) {
  const dough = useMemo(() => currentDoughInput(state), [state]);
  const stats = useMemo(() => computeStats(dough), [dough]);
  const pieces = currentPieces(state);
  const precision = settings.precision;
  const basis = settings.pctBasis;
  const [saveOpen, setSaveOpen] = useState(false);
  const [newOpen, setNewOpen] = useState(false);
  const [scaleOpen, setScaleOpen] = useState(false);
  const [pickerOpen, setPickerOpen] = useState(false);
  const resultsRef = useRef<HTMLDivElement>(null);
  const summaryRef = useRef<HTMLDivElement>(null);
  const [summaryOnScreen, setSummaryOnScreen] = useState(false);

  const loadedRecipe = state.recipeId
    ? api.recipes.find((r) => r.id === state.recipeId)
    : undefined;
  const replaceable = overwriteTarget(state, api.recipes);
  const newOverDirty = newOpen && isCalcDirty(state, api.recipes);

  // 결과 요약이 화면에 보이는 동안에는 하단 요약 바가 같은 숫자를 겹쳐 보이지 않게 숨긴다
  useEffect(() => {
    const el = summaryRef.current;
    if (!el || typeof IntersectionObserver === 'undefined') return;
    const observer = new IntersectionObserver(
      ([entry]) => setSummaryOnScreen(entry.isIntersecting && entry.intersectionRatio >= 0.5),
      { threshold: [0, 0.5, 1] },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const showResults = () => {
    const el = resultsRef.current;
    if (!el) return;
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    el.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' });
    el.focus({ preventScroll: true });
  };

  const canShare = typeof navigator !== 'undefined' && typeof navigator.share === 'function';
  const shareFiche = async () => {
    const text = ficheText(state.name, dough, stats, { pieces, precision, basis });
    if (canShare) {
      try {
        await navigator.share({ title: state.name.trim() || '배합표', text });
        return;
      } catch (e) {
        if (e instanceof DOMException && e.name === 'AbortError') return;
      }
    }
    try {
      await navigator.clipboard.writeText(text);
      toast('배합표를 복사했습니다');
    } catch {
      toast('복사하지 못했습니다');
    }
  };

  const startNew = (empty: boolean) => {
    onChange(resetCalcState(empty));
    setNewOpen(false);
    toast('새 배합을 시작했습니다');
  };

  /** 저장하지 않은 입력이 있으면 덮어쓰기 전에 묻는다 (iOS calcIsDirty 확인과 같다) */
  const confirmLoad = () =>
    !isCalcDirty(state, api.recipes) || window.confirm(LOAD_OVER_DIRTY_PROMPT);

  const loadRecipe = (r: Recipe) => {
    if (!confirmLoad()) return;
    onChange(calcStateFromRecipe(r));
    setPickerOpen(false);
    toast(`'${r.name}' 레시피를 불러왔습니다`);
  };

  // 모드 B에서 목표 조합이 물리적으로 불가능한 경우 (첨가 물/밀가루 음수)
  const negativeWater = state.mode === 'B' && dough.water < -1e-9;
  const negativeFlour = state.mode === 'B' && dough.flours.some((f) => f.grams < -1e-9);

  const handleSave = (data: {
    name: string;
    tags: string[];
    note?: string;
    overwrite: boolean;
  }) => {
    const overwrite = data.overwrite && replaceable !== undefined;
    const id = overwrite ? replaceable.id : newId();
    const now = new Date().toISOString();
    const recipe: Recipe = {
      id,
      schemaVersion: 2,
      name: data.name,
      note: data.note,
      tags: data.tags.length > 0 ? data.tags : undefined,
      createdAt: now,
      updatedAt: now,
      ...structuredClone(dough),
      targetDoughWeight:
        state.mode === 'B' ? targetSpecFromForm(state.target).doughWeight : undefined,
      pieces,
    };
    // 저장소에 쓰지 못했으면 실패 알림만 남기고 계산기는 저장하지 않은 입력 그대로 둔다
    if (!api.save(recipe)) return;
    onChange(calcStateAfterSave(state, { name: data.name, id }, api.recipes));
    toast(overwrite ? '레시피를 덮어썼습니다' : '새 레시피로 저장했습니다');
  };

  return (
    <div className="space-y-6">
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_340px]">
        <div className="no-print space-y-5">
          <div className="flex flex-wrap items-end gap-3">
            <Segmented<'A' | 'B'>
              ariaLabel="입력 모드"
              value={state.mode}
              onChange={(mode) => onChange({ ...state, mode })}
              options={[
                { value: 'A', label: '재료 입력 (모드 A)' },
                { value: 'B', label: '목표 역산 (모드 B)' },
              ]}
            />
            {api.recipes.length > 0 && (
              <Button onClick={() => setPickerOpen(true)}>저장된 레시피 불러오기</Button>
            )}
            <Button variant="ghost" onClick={() => setNewOpen(true)}>
              새 배합
            </Button>
          </div>
          <TextField
            label="레시피 이름"
            value={state.name}
            onChange={(name) => onChange({ ...state, name })}
            placeholder="예: 캉파뉴"
          />
          {state.mode === 'A' ? (
            <>
              <IngredientForm
                input={state.input}
                onChange={(input) => onChange({ ...state, input })}
                stats={stats}
                precision={precision}
                basis={basis}
              />
              <div className="flex flex-wrap items-end gap-3">
                <NumberField
                  label="분할 개수 (0 = 사용 안 함)"
                  unit="개"
                  value={state.pieces}
                  onChange={(p) => onChange({ ...state, pieces: p })}
                  className="max-w-[200px]"
                />
                <Button disabled={!(stats.doughWeight > 0)} onClick={() => setScaleOpen(true)}>
                  배율 조정
                </Button>
              </div>
            </>
          ) : (
            <TargetFormView
              target={state.target}
              onChange={(target) => onChange({ ...state, target })}
              precision={precision}
            />
          )}
        </div>

        <div
          ref={resultsRef}
          tabIndex={-1}
          className="no-print space-y-4 focus:outline-none lg:sticky lg:top-4 lg:self-start"
        >
          <div ref={summaryRef}>
            <ResultSummary stats={stats} pieces={pieces} precision={precision} basis={basis} />
          </div>
          {(negativeWater || negativeFlour) && (
            <div className="rounded border border-danger/40 bg-danger/5 p-3 text-sm text-danger">
              {negativeWater && (
                <p>
                  이 조합에서는 첨가 물이 음수({fmtGrams(dough.water, precision)} g)가 됩니다. PFF를
                  낮추거나 총 수분율을 높이세요.
                </p>
              )}
              {negativeFlour && <p>르방 속 밀가루가 총 밀가루를 초과합니다. PFF를 낮추세요.</p>}
            </div>
          )}
          <div className="flex flex-wrap gap-2">
            <Button
              variant="primary"
              disabled={negativeWater || negativeFlour}
              onClick={() => setSaveOpen(true)}
            >
              레시피 저장
            </Button>
            <Button
              disabled={negativeWater || negativeFlour}
              onClick={() => onSendToConverter(state.name, structuredClone(dough))}
            >
              변환기로 보내기
            </Button>
            <Button disabled={negativeWater || negativeFlour} onClick={() => void shareFiche()}>
              {canShare ? '공유' : '텍스트 복사'}
            </Button>
            <Button onClick={() => window.print()}>인쇄</Button>
          </div>
        </div>
      </div>

      <div className="no-print">
        <BakersTable input={dough} stats={stats} precision={precision} pieces={pieces} basis={basis} />
      </div>

      <PrintFiche
        name={state.name}
        input={dough}
        stats={stats}
        pieces={pieces}
        precision={precision}
        basis={basis}
      />

      <SaveRecipeDialog
        open={saveOpen}
        onClose={() => setSaveOpen(false)}
        initialName={state.name}
        initialTags={loadedRecipe?.tags ?? []}
        initialNote={loadedRecipe?.note ?? ''}
        allowOverwrite={!!replaceable}
        loadedName={replaceable?.name}
        onSave={handleSave}
      />

      <RecipePickerDialog
        open={pickerOpen}
        onClose={() => setPickerOpen(false)}
        recipes={api.recipes}
        precision={precision}
        onPick={loadRecipe}
      />

      <ScaleDialog
        open={scaleOpen}
        onClose={() => setScaleOpen(false)}
        doughWeight={stats.doughWeight}
        pieces={state.pieces}
        precision={precision}
        onApply={(factor, p) => {
          onChange({ ...state, input: scaleDough(state.input, factor), pieces: p ?? state.pieces });
          toast('배율을 적용했습니다');
        }}
      />

      <Dialog
        open={newOpen}
        onClose={() => setNewOpen(false)}
        title="새 배합"
        footer={
          <>
            <Button onClick={() => setNewOpen(false)}>취소</Button>
            <Button onClick={() => startNew(false)}>예시 배합으로 시작 (캉파뉴)</Button>
            <Button variant={newOverDirty ? 'danger' : 'primary'} onClick={() => startNew(true)}>
              빈 배합으로 시작
            </Button>
          </>
        }
      >
        <p className="text-sm text-ink/80">
          {newOverDirty ? NEW_CALC_PROMPT : '빈 배합 또는 예시 배합으로 새로 시작합니다.'}
        </p>
      </Dialog>

      {!summaryOnScreen && (
        <SummaryBar
          stats={stats}
          pieces={pieces}
          precision={precision}
          infeasible={negativeWater || negativeFlour}
          onExpand={showResults}
        />
      )}
    </div>
  );
}
