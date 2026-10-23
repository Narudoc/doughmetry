import { useId, useMemo, useState } from 'react';
import { computeStats } from '../../lib/dough';
import type { Precision } from '../../lib/format';
import { fmtGrams, fmtPct } from '../../lib/format';
import type { PickerSectionKind } from '../../lib/recipePicker';
import { pickerSections } from '../../lib/recipePicker';
import { doughInputFromRecipe } from '../../state';
import type { Recipe } from '../../types';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';

const SECTION_TITLE: Record<PickerSectionKind, string> = {
  recent: '최근',
  all: '전체 (가나다순)',
  saved: '저장된 레시피',
  results: '검색 결과',
};

/** 레시피 목록 카드의 요약 줄 — 총 수분율 · 총 반죽 무게 · 르방 */
export function recipeSummaryText(recipe: Recipe, precision: Precision): string {
  const stats = computeStats(doughInputFromRecipe(recipe));
  const levainLabel = recipe.levain.type === 'liquide' ? '리퀴드' : '뒤흐';
  return `수분율 ${fmtPct(stats.hydrationPct)} · ${fmtGrams(stats.doughWeight, precision)} g · 르방 ${levainLabel} ${(recipe.levain.hydration * 100).toFixed(0)}%`;
}

interface Props {
  open: boolean;
  onClose: () => void;
  recipes: Recipe[];
  precision: Precision;
  /** 고른 레시피 — 닫는 것은 부르는 쪽이 정한다 (덮어쓰기 확인에서 취소하면 열어 둔다) */
  onPick: (recipe: Recipe) => void;
  /** 목록 맨 위의 동작 (변환기의 '계산기 배합 가져오기') */
  topAction?: { label: string; onSelect: () => void };
}

/** 계산기·변환기 공용 레시피 불러오기 — 정렬·검색 규칙은 lib/recipePicker (iOS RecipePickerSheet와 같다) */
export function RecipePickerDialog({ open, onClose, recipes, precision, onPick, topAction }: Props) {
  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="레시피 불러오기"
      footer={<Button onClick={onClose}>취소</Button>}
    >
      <PickerBody recipes={recipes} precision={precision} onPick={onPick} topAction={topAction} />
    </Dialog>
  );
}

const searchInput =
  'w-full min-h-[44px] rounded border border-line bg-white pl-9 pr-3 text-base ' +
  'placeholder:text-ink/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brass';

// 좁은 화면에선 다이얼로그가 화면 높이를 채우고 목록만 안에서 스크롤한다 (제목·검색 칸·취소 버튼·여백 14.5rem)
const listBox =
  'overflow-y-auto overscroll-contain rounded-lg border border-line bg-white ' +
  'h-[calc(100vh-14.5rem)] supports-[height:100dvh]:h-[calc(100dvh-14.5rem)] ' +
  'sm:h-auto sm:max-h-[min(28rem,calc(100vh-14.5rem))]';

const rowButton =
  'flex min-h-[44px] w-full flex-col items-start justify-center gap-0.5 px-3 py-2 text-left ' +
  'transition-colors motion-reduce:transition-none hover:bg-bottle/5 ' +
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brass';

/** 다이얼로그를 열 때마다 새로 마운트된다 — 검색어는 매번 비어 있다 */
function PickerBody({ recipes, precision, onPick, topAction }: Omit<Props, 'open' | 'onClose'>) {
  const [query, setQuery] = useState('');
  const sections = useMemo(() => pickerSections(recipes, query), [recipes, query]);
  const summaries = useMemo(
    () => new Map(recipes.map((r) => [r.id, recipeSummaryText(r, precision)])),
    [recipes, precision],
  );
  const idBase = useId();
  const trimmed = query.trim();

  return (
    <div className="space-y-3">
      {/* 자동 포커스하지 않는다 — 좁은 화면에서 키보드가 목록을 가리지 않게 목록부터 보인다 */}
      {recipes.length > 0 && (
        <div className="relative">
          <svg
            aria-hidden="true"
            viewBox="0 0 20 20"
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink/70"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          >
            <circle cx="8.5" cy="8.5" r="5.5" />
            <path d="m13 13 4 4" />
          </svg>
          <input
            type="search"
            inputMode="search"
            enterKeyHint="search"
            autoComplete="off"
            spellCheck={false}
            value={query}
            placeholder="이름·태그 검색"
            aria-label="이름·태그 검색"
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => {
              // 검색어가 있으면 Esc는 검색어만 지운다 — 다이얼로그는 빈 칸에서 한 번 더 눌러 닫는다
              if (e.key === 'Escape' && !e.nativeEvent.isComposing && query !== '') {
                e.preventDefault();
                e.stopPropagation();
                setQuery('');
              }
            }}
            className={searchInput}
          />
        </div>
      )}
      <div className={listBox}>
        {topAction && (
          <button
            type="button"
            onClick={topAction.onSelect}
            className={`${rowButton} border-b border-line font-medium text-bottle`}
          >
            {topAction.label}
          </button>
        )}
        {recipes.length === 0 ? (
          <p className="px-3 py-6 text-center text-sm text-ink/70">저장된 레시피가 없습니다.</p>
        ) : (
          sections.map((section) =>
            section.kind === 'results' && section.recipes.length === 0 ? (
              <div
                key={section.kind}
                role="status"
                className="flex flex-col items-center gap-2 px-4 py-10 text-center text-sm text-ink/70"
              >
                <svg
                  aria-hidden="true"
                  viewBox="0 0 20 20"
                  className="h-6 w-6"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.75"
                  strokeLinecap="round"
                >
                  <circle cx="8.5" cy="8.5" r="5.5" />
                  <path d="m13 13 4 4" />
                </svg>
                <p className="[overflow-wrap:anywhere]">'{trimmed}'에 대한 결과 없음</p>
              </div>
            ) : (
              <section key={section.kind} aria-labelledby={`${idBase}-${section.kind}`}>
                <h3
                  id={`${idBase}-${section.kind}`}
                  className="sticky top-0 z-10 border-b border-line bg-paper px-3 py-1.5 text-xs font-semibold text-bottle/80"
                >
                  {SECTION_TITLE[section.kind]}
                </h3>
                <ul className="divide-y divide-line">
                  {section.recipes.map((r) => (
                    <li key={r.id}>
                      <button type="button" onClick={() => onPick(r)} className={rowButton}>
                        <span className="font-medium text-ink [overflow-wrap:anywhere]">{r.name}</span>
                        <span className="text-sm tabular-nums text-ink/70">{summaries.get(r.id)}</span>
                        {r.tags && r.tags.length > 0 && (
                          <span className="mt-0.5 flex flex-wrap gap-1">
                            {r.tags.map((t) => (
                              <span
                                key={t}
                                className="rounded-full bg-bottle/10 px-2 py-0.5 text-xs text-bottle [overflow-wrap:anywhere]"
                              >
                                {t}
                              </span>
                            ))}
                          </span>
                        )}
                      </button>
                    </li>
                  ))}
                </ul>
              </section>
            ),
          )
        )}
      </div>
    </div>
  );
}
