import { useMemo, useState } from 'react';
import type { RecipesApi } from '../../hooks/useRecipes';
import type { DoughInput } from '../../lib/dough';
import { computeStats } from '../../lib/dough';
import { fmtGrams } from '../../lib/format';
import { newId } from '../../lib/id';
import type { CalcState } from '../../state';
import {
  calcStateFromRecipe,
  currentDoughInput,
  currentPieces,
  targetSpecFromForm,
} from '../../state';
import type { Recipe, Settings } from '../../types';
import { Button } from '../ui/Button';
import { SaveRecipeDialog } from '../ui/Dialog';
import { Segmented } from '../ui/Segmented';
import { NumberField, TextField } from '../ui/fields';
import { BakersTable } from './BakersTable';
import { IngredientForm } from './IngredientForm';
import { PrintFiche } from './PrintFiche';
import { ResultSummary } from './ResultSummary';
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

  const loadedRecipe = state.recipeId
    ? api.recipes.find((r) => r.id === state.recipeId)
    : undefined;

  // 모드 B에서 목표 조합이 물리적으로 불가능한 경우 (첨가 물/밀가루 음수)
  const negativeWater = state.mode === 'B' && dough.water < -1e-9;
  const negativeFlour = state.mode === 'B' && dough.flours.some((f) => f.grams < -1e-9);

  const handleSave = (data: {
    name: string;
    tags: string[];
    note?: string;
    overwrite: boolean;
  }) => {
    const overwrite = data.overwrite && !!loadedRecipe;
    const id = overwrite && loadedRecipe ? loadedRecipe.id : newId();
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
    api.save(recipe);
    onChange({ ...state, name: data.name, recipeId: id });
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
              <label className="block min-w-[180px] flex-1 sm:max-w-[240px]">
                <span className="mb-1 block text-xs font-medium text-ink/70">
                  저장된 레시피 불러오기
                </span>
                <select
                  value={
                    state.recipeId && api.recipes.some((r) => r.id === state.recipeId)
                      ? state.recipeId
                      : ''
                  }
                  onChange={(e) => {
                    const r = api.recipes.find((x) => x.id === e.target.value);
                    if (r) {
                      onChange(calcStateFromRecipe(r));
                      toast(`'${r.name}' 레시피를 불러왔습니다`);
                    }
                  }}
                  className="min-h-[44px] w-full rounded border border-line bg-white px-3 text-base focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brass"
                >
                  <option value="">선택…</option>
                  {api.recipes.map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.name}
                    </option>
                  ))}
                </select>
              </label>
            )}
          </div>
          <TextField
            label="레시피 이름"
            value={state.name}
            onChange={(name) => onChange({ ...state, name })}
            placeholder="캉파뉴"
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
              <NumberField
                label="분할 개수 (0 = 사용 안 함)"
                unit="개"
                value={state.pieces}
                onChange={(p) => onChange({ ...state, pieces: p })}
                className="max-w-[200px]"
              />
            </>
          ) : (
            <TargetFormView
              target={state.target}
              onChange={(target) => onChange({ ...state, target })}
            />
          )}
        </div>

        <div className="no-print space-y-4 lg:sticky lg:top-4 lg:self-start">
          <ResultSummary stats={stats} pieces={pieces} precision={precision} basis={basis} />
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
            <Button onClick={() => onSendToConverter(state.name, structuredClone(dough))}>
              변환기로 보내기
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
        allowOverwrite={!!loadedRecipe}
        onSave={handleSave}
      />
    </div>
  );
}
