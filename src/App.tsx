import { useCallback, useRef, useState } from 'react';
import { CalculatorPage } from './components/calculator/CalculatorPage';
import { ConverterPage } from './components/converter/ConverterPage';
import { RecipesPage } from './components/recipes/RecipesPage';
import { ToastStack, useToasts } from './components/ui/Toast';
import { useHashTab, type TabId } from './hooks/useHashTab';
import { usePersistedState } from './hooks/usePersistedState';
import { useRecipes } from './hooks/useRecipes';
import type { DoughInput } from './lib/dough';
import { DRAFT_KEY, SETTINGS_KEY } from './lib/storage';
import {
  calcStateFromRecipe,
  currentDoughInput,
  defaultCalcState,
  doughInputFromRecipe,
  sanitizeCalcState,
  sanitizeSettings,
  type CalcState,
} from './state';
import type { Recipe, Settings } from './types';

const TABS: Array<{ id: TabId; label: string }> = [
  { id: 'calc', label: '레시피 계산기' },
  { id: 'convert', label: '르방 변환기' },
  { id: 'recipes', label: '저장된 레시피' },
];

export interface ConverterSource {
  name: string;
  input: DoughInput;
  seq: number;
}

export default function App() {
  const [tab, setTab] = useHashTab();
  const { toasts, show } = useToasts();
  const api = useRecipes();
  const [settings, setSettings] = usePersistedState<Settings>(
    SETTINGS_KEY,
    () => ({ precision: 0.1, pctBasis: 'total' }),
    sanitizeSettings,
  );
  const [calc, setCalc] = usePersistedState<CalcState>(
    DRAFT_KEY,
    defaultCalcState,
    sanitizeCalcState,
  );
  const [convSource, setConvSource] = useState<ConverterSource | null>(null);
  const convSeq = useRef(0);

  const sendToConverter = useCallback(
    (name: string, input: DoughInput) => {
      convSeq.current += 1;
      setConvSource({ name, input, seq: convSeq.current });
      setTab('convert');
    },
    [setTab],
  );

  const openInCalculator = useCallback(
    (r: Recipe) => {
      setCalc(calcStateFromRecipe(r));
      setTab('calc');
      show(`'${r.name}' 레시피를 계산기로 열었습니다`);
    },
    [setCalc, setTab, show],
  );

  return (
    <div className="flex min-h-screen flex-col">
      <header className="no-print bg-bottle text-paper">
        <div className="mx-auto w-full max-w-5xl px-4 pt-5">
          <div className="flex items-start justify-between gap-3">
            <div>
              <h1 className="font-display text-2xl font-bold uppercase tracking-[0.2em]">
                Doughmetry
              </h1>
              <p className="mt-0.5 text-xs text-paper/70">
                도우메트리 — 사워도우 레시피 계산기 · <span className="italic">pain au levain</span>
              </p>
            </div>
            <div className="mt-1 flex flex-col items-end gap-1">
              <div
                role="radiogroup"
                aria-label="표시 자릿수"
                className="inline-flex rounded border border-paper/30 p-0.5 text-xs"
              >
                {([0.1, 1] as const).map((p) => (
                  <button
                    key={p}
                    type="button"
                    role="radio"
                    aria-checked={settings.precision === p}
                    onClick={() => setSettings({ ...settings, precision: p })}
                    className={`min-h-[32px] rounded px-2.5 font-medium tabular-nums transition-colors motion-reduce:transition-none ${
                      settings.precision === p ? 'bg-paper text-bottle' : 'text-paper/70 hover:text-paper'
                    }`}
                  >
                    {p === 0.1 ? '0.1 g' : '1 g'}
                  </button>
                ))}
              </div>
              <div
                role="radiogroup"
                aria-label="% 표기 기준"
                title="표시만 바뀝니다 — 계산과 총 수분율·PFF는 항상 총 밀가루 기준입니다."
                className="inline-flex rounded border border-paper/30 p-0.5 text-xs"
              >
                {(
                  [
                    ['total', '총 밀가루 %'],
                    ['added', '베이커스 %'],
                  ] as const
                ).map(([b, label]) => (
                  <button
                    key={b}
                    type="button"
                    role="radio"
                    aria-checked={settings.pctBasis === b}
                    onClick={() => setSettings({ ...settings, pctBasis: b })}
                    className={`min-h-[32px] rounded px-2.5 font-medium transition-colors motion-reduce:transition-none ${
                      settings.pctBasis === b ? 'bg-paper text-bottle' : 'text-paper/70 hover:text-paper'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
          </div>
          <nav className="mt-4 flex gap-1 overflow-x-auto" aria-label="주요 탭">
            {TABS.map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => setTab(t.id)}
                aria-current={tab === t.id ? 'page' : undefined}
                className={`min-h-[44px] whitespace-nowrap rounded-t px-4 text-sm font-medium transition-colors motion-reduce:transition-none ${
                  tab === t.id ? 'bg-paper text-bottle' : 'text-paper/70 hover:text-paper'
                }`}
              >
                {t.label}
              </button>
            ))}
          </nav>
        </div>
      </header>

      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-6">
        <div hidden={tab !== 'calc'}>
          <CalculatorPage
            state={calc}
            onChange={setCalc}
            settings={settings}
            api={api}
            onSendToConverter={sendToConverter}
            toast={show}
          />
        </div>
        <div hidden={tab !== 'convert'}>
          <ConverterPage
            source={convSource}
            api={api}
            calcName={calc.name}
            getCalcDough={() => structuredClone(currentDoughInput(calc))}
            settings={settings}
            toast={show}
          />
        </div>
        <div hidden={tab !== 'recipes'}>
          <RecipesPage
            api={api}
            settings={settings}
            onOpenInCalculator={openInCalculator}
            onSendToConverter={(r) => sendToConverter(r.name, doughInputFromRecipe(r))}
            toast={show}
          />
        </div>
      </main>

      <footer className="no-print mx-auto w-full max-w-5xl px-4 pb-8 text-xs text-ink/50">
        데이터는 이 브라우저의 localStorage에만 저장됩니다 · JSON 내보내기로 백업하세요
      </footer>

      <ToastStack toasts={toasts} />
    </div>
  );
}
