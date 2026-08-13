import { useEffect, useMemo, useState } from 'react';
import type { ConverterSource } from '../../App';
import type { RecipesApi } from '../../hooks/useRecipes';
import type { ConvertError, DeltaDistribution, DoughInput } from '../../lib/dough';
import {
  computeStats,
  convertFixedMass,
  convertFixedPff,
  withLevainMass,
} from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct } from '../../lib/format';
import { newId } from '../../lib/id';
import { defaultCalcState, doughInputFromRecipe } from '../../state';
import type { Recipe, Settings } from '../../types';
import { IngredientForm } from '../calculator/IngredientForm';
import { Button } from '../ui/Button';
import { SaveRecipeDialog } from '../ui/Dialog';
import { Segmented } from '../ui/Segmented';
import { NumberField, TextField } from '../ui/fields';
import { BeforeAfter } from './BeforeAfter';

type ConvMode = 'fixed-mass' | 'fixed-pff';

interface Props {
  source: ConverterSource | null;
  api: RecipesApi;
  calcName: string;
  getCalcDough: () => DoughInput;
  settings: Settings;
  toast: (message: string) => void;
}

const MODE_DESC: Record<ConvMode, string> = {
  'fixed-mass':
    '르방 무게를 그대로 두고 첨가 밀가루·물을 조정합니다 — PFF(발효종 밀가루 비율)가 변합니다.',
  'fixed-pff':
    '발효종 밀가루 양(PFF)을 유지합니다 — 필요한 르방 무게가 달라지고, 첨가 물이 그만큼 조정됩니다.',
};

export function ConverterPage({ source, api, calcName, getCalcDough, settings, toast }: Props) {
  const precision = settings.precision;
  const [name, setName] = useState('캉파뉴');
  const [input, setInput] = useState<DoughInput>(() => defaultCalcState().input);
  const [targetHydrationPct, setTargetHydrationPct] = useState(50);
  const [convMode, setConvMode] = useState<ConvMode>('fixed-mass');
  const [distFlourId, setDistFlourId] = useState('');
  const [editOpen, setEditOpen] = useState(false);
  const [saveOpen, setSaveOpen] = useState(false);
  const [selectedRecipeId, setSelectedRecipeId] = useState('');

  // 반대 방향 프리셋: 현재 르방이 리퀴드 계열이면 뒤흐(50%)로, 아니면 리퀴드(100%)로
  const suggestTarget = (d: DoughInput) =>
    setTargetHydrationPct(d.levain.hydration >= 0.75 ? 50 : 100);

  const adoptInput = (n: string, d: DoughInput) => {
    setName(n);
    setInput(d);
    suggestTarget(d);
    setDistFlourId('');
  };

  useEffect(() => {
    if (source) adoptInput(source.name, structuredClone(source.input));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [source?.seq]);

  const sourceStats = useMemo(() => computeStats(input), [input]);
  const newHydration = targetHydrationPct / 100;
  const dist: DeltaDistribution = distFlourId
    ? { mode: 'single', flourId: distFlourId }
    : { mode: 'pro-rata' };

  const result = useMemo(
    () =>
      convMode === 'fixed-mass'
        ? convertFixedMass(input, newHydration, dist)
        : convertFixedPff(input, newHydration),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [input, newHydration, convMode, distFlourId],
  );

  const presetValue =
    targetHydrationPct === 50 ? 'dur' : targetHydrationPct === 100 ? 'liquide' : 'custom';

  const handleSave = (data: { name: string; tags: string[]; note?: string }) => {
    if (!result.ok) return;
    const now = new Date().toISOString();
    const recipe: Recipe = {
      id: newId(),
      schemaVersion: 2,
      name: data.name,
      note: data.note,
      tags: data.tags.length > 0 ? data.tags : undefined,
      createdAt: now,
      updatedAt: now,
      ...structuredClone(result.output),
    };
    api.save(recipe);
    toast('변환 결과를 새 레시피로 저장했습니다');
  };

  return (
    <div className="no-print space-y-6">
      {/* 소스 선택 + 변환 설정 */}
      <section className="space-y-4 rounded-lg border border-line bg-white p-4">
        <div className="flex flex-wrap items-end gap-2">
          <TextField
            label="레시피 이름"
            value={name}
            onChange={setName}
            className="min-w-[180px] flex-1"
          />
          <label className="block min-w-[200px] flex-1">
            <span className="mb-1 block text-xs font-medium text-ink/70">저장된 레시피 불러오기</span>
            <select
              value={selectedRecipeId}
              onChange={(e) => {
                const r = api.recipes.find((x) => x.id === e.target.value);
                setSelectedRecipeId(e.target.value);
                if (r) adoptInput(r.name, doughInputFromRecipe(r));
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
          <Button onClick={() => adoptInput(calcName, getCalcDough())}>계산기 배합 가져오기</Button>
          <Button onClick={() => setEditOpen((v) => !v)}>
            {editOpen ? '편집 닫기' : '원본 직접 편집'}
          </Button>
        </div>

        {editOpen && (
          <div className="rounded border border-line bg-paper p-4">
            <IngredientForm
              input={input}
              onChange={setInput}
              stats={sourceStats}
              precision={precision}
            />
          </div>
        )}

        <div className="flex flex-wrap items-end gap-3">
          <div>
            <span className="mb-1 block text-xs font-medium text-ink/70">목표 르방 수분율</span>
            <div className="flex items-center gap-2">
              <Segmented<'dur' | 'liquide' | 'custom'>
                ariaLabel="목표 르방 수분율 프리셋"
                value={presetValue}
                onChange={(v) => {
                  if (v === 'dur') setTargetHydrationPct(50);
                  else if (v === 'liquide') setTargetHydrationPct(100);
                }}
                options={[
                  { value: 'dur', label: '뒤흐 50%' },
                  { value: 'liquide', label: '리퀴드 100%' },
                  { value: 'custom', label: '직접 입력' },
                ]}
              />
              <NumberField
                value={targetHydrationPct}
                onChange={setTargetHydrationPct}
                unit="%"
                min={1}
                className="w-24"
                ariaLabel="목표 르방 수분율 (%)"
              />
            </div>
          </div>
          <div>
            <span className="mb-1 block text-xs font-medium text-ink/70">변환 모드</span>
            <Segmented<ConvMode>
              ariaLabel="변환 모드"
              value={convMode}
              onChange={setConvMode}
              options={[
                { value: 'fixed-mass', label: '르방 질량 고정' },
                { value: 'fixed-pff', label: 'PFF 고정' },
              ]}
            />
          </div>
          {convMode === 'fixed-mass' && input.flours.length > 1 && (
            <label className="block">
              <span className="mb-1 block text-xs font-medium text-ink/70">ΔF 배분</span>
              <select
                value={distFlourId}
                onChange={(e) => setDistFlourId(e.target.value)}
                className="min-h-[44px] rounded border border-line bg-white px-3 text-base focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brass"
              >
                <option value="">모든 밀가루에 비례 배분 (기본)</option>
                {input.flours.map((f, i) => (
                  <option key={f.id} value={f.id}>
                    '{f.name || `밀가루 ${i + 1}`}'에서만 증감
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>
        <p className="text-xs text-ink/60">{MODE_DESC[convMode]}</p>
      </section>

      {result.ok ? (
        <>
          <BeforeAfter result={result} inputBefore={input} precision={precision} />
          <InvariantChecklist result={result} precision={precision} />
          <AdviceNotes result={result} mode={convMode} precision={precision} />
          <Button variant="primary" onClick={() => setSaveOpen(true)}>
            변환 결과를 새 레시피로 저장
          </Button>
        </>
      ) : (
        <ErrorPanel
          error={result.error}
          input={input}
          precision={precision}
          onApplyMax={(grams) => setInput(withLevainMass(input, grams))}
        />
      )}

      <SaveRecipeDialog
        open={saveOpen}
        onClose={() => setSaveOpen(false)}
        title="변환 결과 저장"
        initialName={`${name} (르방 ${targetHydrationPct}%)`}
        onSave={(d) => handleSave(d)}
      />
    </div>
  );
}

// ── 보존 체크리스트 ────────────────────────────────────────────────

function InvariantChecklist({
  result,
  precision,
}: {
  result: Extract<ReturnType<typeof convertFixedMass>, { ok: true }>;
  precision: Precision;
}) {
  const { before, after } = result;
  const items: Array<{ label: string; b: number; a: number; unit: string }> = [
    { label: '총 밀가루', b: before.totalFlour, a: after.totalFlour, unit: 'g' },
    { label: '총 물', b: before.totalWater, a: after.totalWater, unit: 'g' },
    { label: '총 수분율', b: before.hydrationPct, a: after.hydrationPct, unit: '%' },
    { label: '총 반죽 무게', b: before.doughWeight, a: after.doughWeight, unit: 'g' },
  ];
  return (
    <section className="rounded-lg border border-line bg-white p-4">
      <h3 className="font-display text-sm font-semibold uppercase tracking-widest text-bottle">
        보존되는 값
      </h3>
      <ul className="mt-2 grid gap-1.5 text-sm sm:grid-cols-2">
        {items.map((it) => {
          const kept = Math.abs(it.a - it.b) < 0.01;
          const value = it.unit === 'g' ? `${fmtGrams(it.a, precision)} g` : fmtPct(it.a);
          return (
            <li key={it.label} className="flex items-center gap-2 tabular-nums">
              <span
                aria-hidden="true"
                className={`inline-flex h-5 w-5 items-center justify-center rounded-full text-xs font-bold ${
                  kept ? 'bg-bottle text-paper' : 'bg-danger text-white'
                }`}
              >
                {kept ? '✓' : '!'}
              </span>
              <span>
                {it.label} {value} {kept ? '유지' : '변동'}
              </span>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

// ── PFF·풍미 안내 ─────────────────────────────────────────────────

function AdviceNotes({
  result,
  mode,
  precision,
}: {
  result: Extract<ReturnType<typeof convertFixedMass>, { ok: true }>;
  mode: ConvMode;
  precision: Precision;
}) {
  const { before, after, output } = result;
  const pffUp = after.pffPct > before.pffPct + 0.005;
  const pffDown = after.pffPct < before.pffPct - 0.005;
  const pffChanged = pffUp || pffDown;

  return (
    <div className="space-y-3">
      <div className="rounded border border-bottle/30 bg-bottle/5 p-3 text-sm">
        {mode === 'fixed-mass' ? (
          pffChanged ? (
            <p>
              르방 양은 같지만 발효종 밀가루 비율(PFF)이{' '}
              <strong className="tabular-nums">
                {fmtPct(before.pffPct)} → {fmtPct(after.pffPct)}
              </strong>
              로 {pffUp ? '올라갑니다' : '내려갑니다'}. 같은 온도라면 1차 발효가 다소{' '}
              {pffUp ? '빨라질' : '느려질'} 수 있습니다.
            </p>
          ) : (
            <p>발효종 밀가루 비율(PFF)이 사실상 변하지 않아 발효 속도 특성이 유지됩니다.</p>
          )
        ) : (
          <p>
            발효종 밀가루 비율(PFF <span className="tabular-nums">{fmtPct(after.pffPct)}</span>)이
            유지되어 발효 속도 특성이 비슷하게 유지됩니다. 르방은{' '}
            <strong className="tabular-nums">
              {fmtGrams(before.levainFlour + before.levainWater, precision)} g 대신{' '}
              {fmtGrams(output.levain.grams, precision)} g
            </strong>
            을 수분율 {(output.levain.hydration * 100).toFixed(0)}%로 준비하세요.
          </p>
        )}
      </div>
      <div className="rounded border border-line bg-white p-3 text-sm text-ink/70">
        르방 뒤흐는 초산(acetic acid) 생성이 상대적으로 우세해 산미가 날카롭고 향이 강해지는 경향이
        있고, 르방 리퀴드는 젖산(lactic acid) 우세로 산미가 부드럽습니다.
      </div>
    </div>
  );
}

// ── 오류 안내 ─────────────────────────────────────────────────────

function ErrorPanel({
  error,
  input,
  precision,
  onApplyMax,
}: {
  error: ConvertError;
  input: DoughInput;
  precision: Precision;
  onApplyMax: (grams: number) => void;
}) {
  let message: string;
  let maxLevain: number | null = null;

  if (error.code === 'F_ADD_NEGATIVE') {
    message = '르방 속 밀가루가 총 밀가루를 초과합니다. 르방 양을 줄이세요.';
    maxLevain = error.maxLevainGrams;
  } else if (error.code === 'W_ADD_NEGATIVE') {
    message =
      '이 수분율에서는 르방 양을 유지한 채 변환할 수 없습니다. 르방 양을 줄이거나 총 수분율을 높이세요.';
    maxLevain = error.maxLevainGrams;
  } else {
    const flour = input.flours.find((f) => f.id === error.flourId);
    message = `'${flour?.name || '선택한 밀가루'}'에서 ${fmtGrams(error.needed, precision)} g을 빼야 하지만 ${fmtGrams(error.available, precision)} g뿐입니다. 비례 배분을 사용하거나 다른 밀가루를 선택하세요.`;
  }

  return (
    <section className="space-y-3 rounded-lg border border-danger/40 bg-danger/5 p-4">
      <p className="text-sm font-medium text-danger">{message}</p>
      {maxLevain !== null && Number.isFinite(maxLevain) && (
        <div className="flex flex-wrap items-center gap-3 text-sm">
          <span className="tabular-nums">
            변환 가능한 최대 르방: <strong>{fmtGrams(maxLevain, precision)} g</strong>
            <span className="text-ink/50"> (총 밀가루·총 물 유지 기준)</span>
          </span>
          <Button small onClick={() => onApplyMax(maxLevain)}>
            최대 르방 질량 적용
          </Button>
        </div>
      )}
    </section>
  );
}
