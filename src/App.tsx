import { useCallback, useEffect, useRef, useState } from 'react';
import { CalculatorPage } from './components/calculator/CalculatorPage';
import { ConverterPage } from './components/converter/ConverterPage';
import { RecipesPage } from './components/recipes/RecipesPage';
import { Fr } from './components/ui/Fr';
import { ToastStack, useToasts } from './components/ui/Toast';
import { useHashTab, type TabId } from './hooks/useHashTab';
import { usePersistedState } from './hooks/usePersistedState';
import { useRecipes } from './hooks/useRecipes';
import { useWakeLock, wakeLockSupported } from './hooks/useWakeLock';
import { DRAFT_KEY, SETTINGS_KEY } from './lib/storage';
import {
  LOAD_OVER_DIRTY_PROMPT,
  calcStateFromRecipe,
  converterDoughFromCalc,
  converterDoughFromRecipe,
  defaultCalcState,
  defaultSettings,
  isCalcDirty,
  sanitizeCalcState,
  sanitizeSettings,
  type CalcState,
  type ConverterDough,
} from './state';
import type { Recipe, Settings } from './types';

const TABS: Array<{ id: TabId; label: string }> = [
  { id: 'calc', label: '레시피 계산기' },
  { id: 'convert', label: '르방 변환기' },
  { id: 'recipes', label: '저장된 레시피' },
];

/** iOS 설정의 화면 켜두기 토글과 같은 문구 — 웹은 배합표가 있는 계산기 탭에서 켜 둔다 */
const KEEP_AWAKE_LABEL = '배합표·레시피를 보는 동안 화면 켜두기';

const FOOTER_LINK =
  'inline-flex min-h-[36px] items-center underline underline-offset-2 hover:text-bottle';

export interface ConverterSource extends ConverterDough {
  seq: number;
}

export default function App() {
  const [tab, setTab] = useHashTab();
  const { toasts, show } = useToasts();
  const api = useRecipes();
  const [settings, setSettings] = usePersistedState<Settings>(
    SETTINGS_KEY,
    defaultSettings,
    sanitizeSettings,
    { syncTabs: true },
  );
  const [calc, setCalc] = usePersistedState<CalcState>(
    DRAFT_KEY,
    defaultCalcState,
    sanitizeCalcState,
  );
  const [convSource, setConvSource] = useState<ConverterSource | null>(null);
  const convSeq = useRef(0);
  // 지원하지 않는 브라우저에는 지키지 못할 설정을 보이지 않는다
  const [canKeepAwake] = useState(() => wakeLockSupported());
  useWakeLock(tab === 'calc' && settings.keepScreenAwake);

  const panelRefs = {
    calc: useRef<HTMLDivElement>(null),
    convert: useRef<HTMLDivElement>(null),
    recipes: useRef<HTMLDivElement>(null),
  };
  // 다른 탭에서 넘겨받을 때만 새 탭의 맨 위에서 시작한다 — 탭 버튼·뒤로 가기는 브라우저의 스크롤 복원에 맡긴다
  const pendingHandoff = useRef<TabId | null>(null);
  const focusPanel = (t: TabId) => {
    window.scrollTo({ top: 0 });
    panelRefs[t].current?.focus({ preventScroll: true });
  };

  // 첫 화면(계산기)은 index.html의 제목 그대로 — 검색·공유 미리보기가 읽는 제목이다
  const homeTitle = useRef(document.title);
  useEffect(() => {
    const label = TABS.find((t) => t.id === tab)?.label;
    document.title = tab === 'calc' ? homeTitle.current : `${label} · 도우메트리 Doughmetry`;
    // hashchange가 비동기로 오므로 이때는 새 탭의 hidden이 이미 풀려 있다
    if (pendingHandoff.current !== tab) return;
    pendingHandoff.current = null;
    focusPanel(tab);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab]);

  const handOff = useCallback(
    (target: TabId) => {
      if (tab === target) {
        focusPanel(target);
        return;
      }
      pendingHandoff.current = target;
      setTab(target);
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [tab, setTab],
  );

  const sendToConverter = useCallback(
    (dough: ConverterDough) => {
      convSeq.current += 1;
      setConvSource({ ...dough, seq: convSeq.current });
      handOff('convert');
      show(`'${dough.name || '이름 없는 배합'}' 배합을 변환기로 불러왔습니다`);
    },
    [handOff, show],
  );

  const openInCalculator = useCallback(
    (r: Recipe) => {
      if (isCalcDirty(calc, api.recipes) && !window.confirm(LOAD_OVER_DIRTY_PROMPT)) return;
      setCalc(calcStateFromRecipe(r));
      handOff('calc');
      show(`'${r.name}' 레시피를 계산기로 열었습니다`);
    },
    [calc, api.recipes, setCalc, handOff, show],
  );

  const markExported = useCallback(
    () => setSettings((s) => ({ ...s, lastExportAt: new Date().toISOString() })),
    [setSettings],
  );

  return (
    <div className="flex min-h-screen flex-col">
      <header className="no-print bg-bottle text-paper">
        <div className="mx-auto w-full max-w-5xl px-4 pt-5">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h1 className="font-display text-2xl font-bold uppercase tracking-[0.2em]">
                Doughmetry
              </h1>
              <p className="mt-0.5 text-xs text-paper/70">
                도우메트리 — 사워도우 레시피 계산기 · <Fr>pain au levain</Fr>
              </p>
            </div>
            <div className="mt-1 flex flex-wrap gap-2 sm:flex-col sm:items-end sm:gap-1">
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
                    className={`min-h-[36px] whitespace-nowrap rounded px-2.5 font-medium tabular-nums transition-colors motion-reduce:transition-none ${
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
                    className={`min-h-[36px] whitespace-nowrap rounded px-2.5 font-medium transition-colors motion-reduce:transition-none ${
                      settings.pctBasis === b ? 'bg-paper text-bottle' : 'text-paper/70 hover:text-paper'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
              {canKeepAwake && (
                <div className="inline-flex rounded border border-paper/30 p-0.5 text-xs">
                  <button
                    type="button"
                    role="switch"
                    aria-checked={settings.keepScreenAwake}
                    aria-label={KEEP_AWAKE_LABEL}
                    title={KEEP_AWAKE_LABEL}
                    onClick={() =>
                      setSettings({ ...settings, keepScreenAwake: !settings.keepScreenAwake })
                    }
                    className={`inline-flex min-h-[36px] items-center gap-2 whitespace-nowrap rounded px-2.5 font-medium transition-colors motion-reduce:transition-none ${
                      settings.keepScreenAwake ? 'text-paper' : 'text-paper/70 hover:text-paper'
                    }`}
                  >
                    <span
                      aria-hidden="true"
                      className={`relative h-4 w-7 shrink-0 rounded-full transition-colors motion-reduce:transition-none ${
                        settings.keepScreenAwake ? 'bg-paper' : 'bg-paper/30'
                      }`}
                    >
                      <span
                        className={`absolute top-0.5 h-3 w-3 rounded-full transition-[left] motion-reduce:transition-none ${
                          settings.keepScreenAwake ? 'left-3.5 bg-bottle' : 'left-0.5 bg-paper'
                        }`}
                      />
                    </span>
                    화면 켜두기
                  </button>
                </div>
              )}
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
        <div
          ref={panelRefs.calc}
          hidden={tab !== 'calc'}
          tabIndex={-1}
          role="region"
          aria-label="레시피 계산기"
          className="outline-none focus-visible:ring-0 focus-visible:ring-offset-0"
        >
          <CalculatorPage
            state={calc}
            onChange={setCalc}
            settings={settings}
            api={api}
            onSendToConverter={sendToConverter}
            toast={show}
          />
        </div>
        <div
          ref={panelRefs.convert}
          hidden={tab !== 'convert'}
          tabIndex={-1}
          role="region"
          aria-label="르방 변환기"
          className="outline-none focus-visible:ring-0 focus-visible:ring-offset-0"
        >
          <ConverterPage
            source={convSource}
            api={api}
            getCalcDough={() => converterDoughFromCalc(calc, api.recipes)}
            settings={settings}
            toast={show}
          />
        </div>
        <div
          ref={panelRefs.recipes}
          hidden={tab !== 'recipes'}
          tabIndex={-1}
          role="region"
          aria-label="저장된 레시피"
          className="outline-none focus-visible:ring-0 focus-visible:ring-offset-0"
        >
          <RecipesPage
            api={api}
            settings={settings}
            onExportedAll={markExported}
            onOpenInCalculator={openInCalculator}
            onSendToConverter={(r) => sendToConverter(converterDoughFromRecipe(r))}
            toast={show}
          />
        </div>
      </main>

      <footer className="no-print mx-auto w-full max-w-5xl space-y-1 px-4 pb-8 text-xs text-ink/70">
        <p>레시피는 이 브라우저에만 저장됩니다 · 저장된 레시피 탭의 '전체 내보내기'로 백업하세요</p>
        <p>한 번 열어 둔 뒤에는 오프라인에서도 동작합니다 (사진 인식 제외)</p>
        <nav aria-label="사이트 정보" className="flex flex-wrap gap-x-4">
          <a href={`${import.meta.env.BASE_URL}privacy.html`} className={FOOTER_LINK}>
            개인정보 처리방침&nbsp;<i lang="en">Privacy</i>
          </a>
          <a href={`${import.meta.env.BASE_URL}support.html`} className={FOOTER_LINK}>
            지원&nbsp;<i lang="en">Support</i>
          </a>
          <a href="https://github.com/Narudoc/doughmetry" className={FOOTER_LINK}>
            GitHub
          </a>
        </nav>
      </footer>
      {/* 화면 아래 고정 요약 바(SummaryBar, 계산기 탭·모바일)가 푸터 링크를 가리지 않게 */}
      {tab === 'calc' && <div className="no-print h-20 lg:hidden" aria-hidden="true" />}

      <ToastStack toasts={toasts} raised={tab === 'calc'} />
    </div>
  );
}
