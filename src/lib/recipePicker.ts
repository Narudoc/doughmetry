/**
 * 레시피 불러오기 선택 목록 (계산기·변환기 공용) — 정렬·검색·묶음 규칙.
 * iOS DoughmetryCore RecipePicker.swift와 같은 규칙·같은 테스트 벡터 — 한쪽을 바꾸면 양쪽 테스트를 함께 고칠 것.
 */

/** 검색어가 없고 레시피가 이보다 많으면 '최근' 묶음을 따로 보인다 */
export const RECENT_COUNT = 5;

export type PickerSectionKind = 'recent' | 'all' | 'saved' | 'results';

/** 정렬·검색에 쓰는 레시피 필드 */
export interface PickerItem {
  id: string;
  name: string;
  tags?: string[];
  createdAt: string;
  updatedAt: string;
}

export interface PickerSection<T extends PickerItem> {
  kind: PickerSectionKind;
  recipes: T[];
}

/** 해석하지 못한 시각은 -Infinity — 최근 순에서 맨 뒤로 간다 */
function instant(iso: string): number {
  const t = Date.parse(iso);
  return Number.isNaN(t) ? -Infinity : t;
}

/** 최근 순: updatedAt 내림차순 → createdAt 내림차순 → id 오름차순 */
function byRecency(a: PickerItem, b: PickerItem): number {
  const ua = instant(a.updatedAt);
  const ub = instant(b.updatedAt);
  if (ua !== ub) return ub > ua ? 1 : -1;
  const ca = instant(a.createdAt);
  const cb = instant(b.createdAt);
  if (ca !== cb) return cb > ca ? 1 : -1;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

// iOS compare(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive, .numeric], locale: ko)와 같은 순서 — 한글이 라틴 문자보다 앞
const nameCollator = new Intl.Collator('ko', { numeric: true, sensitivity: 'base' });

function byName(a: PickerItem, b: PickerItem): number {
  return nameCollator.compare(a.name, b.name) || byRecency(a, b);
}

/** 대소문자·발음 구별 기호·전각/반각을 지운 비교용 문자열 (로캘과 무관) — iOS range(of:options:)의 같은 옵션과 같은 결과 */
export function foldForSearch(s: string): string {
  return s.normalize('NFKD').replace(/\p{Mn}/gu, '').normalize('NFC').toLowerCase();
}

/**
 * 선택 목록의 묶음.
 * 검색어 없음: 레시피가 RECENT_COUNT개 이하면 [saved: 전부, 최근 순], 넘으면 [recent: 최근 순 앞 RECENT_COUNT개, all: 전부, 이름 순].
 * 검색어 있음: [results: 이름이나 태그에 검색어가 든 레시피, 이름 순] (빈 배열일 수 있다).
 */
export function pickerSections<T extends PickerItem>(
  recipes: readonly T[],
  query: string,
): PickerSection<T>[] {
  const q = foldForSearch(query.trim());
  if (q !== '') {
    const matches = recipes.filter(
      (r) =>
        foldForSearch(r.name).includes(q) ||
        (r.tags ?? []).some((t) => foldForSearch(t).includes(q)),
    );
    return [{ kind: 'results', recipes: matches.sort(byName) }];
  }
  const recent = [...recipes].sort(byRecency);
  if (recipes.length <= RECENT_COUNT) return [{ kind: 'saved', recipes: recent }];
  return [
    { kind: 'recent', recipes: recent.slice(0, RECENT_COUNT) },
    { kind: 'all', recipes: [...recipes].sort(byName) },
  ];
}
