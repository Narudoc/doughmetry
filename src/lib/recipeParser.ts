import type { Extra, Flour, Liquid, Yeast } from '../types';
import type { DoughInput } from './dough';
import { LIQUID_PRESETS, levainTypeFor } from './dough';
import { newId } from './id';

/**
 * 레시피 텍스트 → 배합 규칙 기반 파서.
 * iOS(LevainCore/RecipeTextParser.swift)의 이식본 — 규칙이 바뀌면 두 곳을 함께 고칠 것.
 * 키워드는 한국어·영어·프랑스어 제빵 용어를 커버한다.
 *
 * 처리 순서: 머리 기호 제거 → SNS 토큰·키캡 번호 제거 → 온도·시간·차수 표기 제거 → 구분자 분할
 * → 섹션 인식(르방 빌드/본반죽/공정) → 재료 분류.
 */

export interface ParsedRecipeText {
  name: string | null;
  input: DoughInput;
  /** 재료로 인식된 줄 수 — 0이면 인식 실패로 판단 */
  matchedLineCount: number;
  /** 르방 수분율을 텍스트가 직접 밝혔는지(30~150% 또는 리퀴드/뒤흐 키워드) — 기본값·빌드 섹션 추정은 false */
  levainHydrationExplicit: boolean;
}

/** pct: %, mass: 무게 단위(g로 환산), measure: 컵·스푼·개수(그램이 아님), bare: 단위 없음 */
type NumberKind = 'pct' | 'mass' | 'measure' | 'bare';

interface NumberToken {
  value: number;
  kind: NumberKind;
}

/** 단위별 분류·g 환산 계수 — 표에 없는 단위(컵·스푼·개수)는 measure */
const UNITS: Record<string, [NumberKind, number]> = {
  '%': ['pct', 1],
  kg: ['mass', 1000],
  '㎏': ['mass', 1000],
  키로: ['mass', 1000],
  킬로: ['mass', 1000],
  g: ['mass', 1],
  gr: ['mass', 1],
  gram: ['mass', 1],
  grams: ['mass', 1],
  gramme: ['mass', 1],
  grammes: ['mass', 1],
  그램: ['mass', 1],
  ml: ['mass', 1],
  oz: ['mass', 28.349523125],
  ounce: ['mass', 28.349523125],
  ounces: ['mass', 28.349523125],
  lb: ['mass', 453.59237],
  lbs: ['mass', 453.59237],
  pound: ['mass', 453.59237],
  pounds: ['mass', 453.59237],
};

const KG_UNITS = new Set(['kg', '㎏', '키로', '킬로']);
const LB_UNITS = new Set(['lb', 'lbs', 'pound', 'pounds']);
const OZ_UNITS = new Set(['oz', 'ounce', 'ounces']);

/**
 * 1: 분수("1/2", "3 3/4") — 두 자리까지만, "350/370g" 같은 범위·두 배합 표기는 분수가 아니다
 * 2: 수 — 천 단위 구분은 쉼표·NBSP류 공백, 일반 공백은 무게 단위가 뒤따르고 앞자리가 한 자리일 때만
 *    ("1 000 g" — "type 65 500 g"·"Farine 100 500 g"의 앞 수는 별개)
 * 3: 단위 — 단어 중간("500g을", "gâteau")은 단위가 아니다
 */
const NUMBER_PATTERN =
  /(?:^|[^A-Za-z0-9])(?:((?:[0-9]+[ \t]+)?[0-9]{1,2}\/[0-9]{1,2}(?![0-9]))|([1-9](?:[ \u00A0\u202F\u2009][0-9]{3})+(?=[ \t\u00A0\u202F\u2009]*(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml)(?![\p{L}\p{M}\p{N}_]))|[0-9]{1,3}(?:[\u00A0\u202F\u2009][0-9]{3})+|[0-9]+(?:,[0-9]{3})*(?:[.,][0-9]+)?))(?:[ \t\u00A0\u202F\u2009]*(%|(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml|oz|ounces?|lbs?|pounds?|cups?|컵|tsp|tbsp|teaspoons?|tablespoons?|큰술|작은술|티스푼|개|large|medium|small)(?![\p{L}\p{M}\p{N}_])))?/giu;

/**
 * 줄 단위 숫자 토큰.
 * "T65"처럼 영문자에 붙은 숫자는 양이 아니므로 제외 — 경계 문자를 함께 매칭한다.
 * 단위: % 는 수분율, kg류·oz·lb 는 g로 환산, 컵·스푼·개수는 그램이 아니다.
 */
function numberTokens(line: string): NumberToken[] {
  const tokens: NumberToken[] = [];
  // "1 lb 2 oz"는 한 수량 — lb 바로 뒤(공백 하나)의 oz는 앞 토큰에 더한다
  let lbEnd = -1;
  for (const match of line.matchAll(NUMBER_PATTERN)) {
    const unit = match[3]?.toLowerCase();
    let v: number;
    if (match[1] !== undefined) {
      const f = /^(?:([0-9]+)[ \t]+)?([0-9]+)\/([0-9]+)$/u.exec(match[1]);
      if (!f || Number(f[3]) === 0) continue;
      v = Number(f[1] ?? 0) + Number(f[2]) / Number(f[3]);
    } else {
      let raw = match[2].replace(/[ \u00A0\u202F\u2009]/gu, '');
      const isKg = unit !== undefined && KG_UNITS.has(unit);
      if (isKg && /^[0-9]{1,3},[0-9]{3}$/u.test(raw)) {
        // 프랑스식 소수 쉼표 — "0,700 kg"·"1,000 kg"은 1000배가 아니다.
        // 단위 없는 "0,700"은 kg 열 표("1,000 / 0,700")와 같은 배율이 되도록 천 단위로 둔다
        raw = raw.replace(/,/gu, '.');
      } else {
        // 천 단위 쉼표 제거 (쉼표 뒤 3자리), 남은 쉼표는 소수점으로
        raw = raw.replace(/,(?=[0-9]{3}(\D|$))/gu, '').replace(/,/gu, '.');
      }
      v = Number(raw);
    }
    const [kind, factor]: [NumberKind, number] =
      unit === undefined ? ['bare', 1] : (UNITS[unit] ?? ['measure', 1]);
    v *= factor;
    if (!Number.isFinite(v)) continue;
    if (unit !== undefined && OZ_UNITS.has(unit) && match.index === lbEnd && /^\s/u.test(match[0])) {
      tokens[tokens.length - 1].value += v;
      lbEnd = -1;
      continue;
    }
    tokens.push({ value: v, kind });
    lbEnd = unit !== undefined && LB_UNITS.has(unit) ? match.index + match[0].length : -1;
  }
  return tokens;
}

/**
 * 줄의 그램 수량 — 괄호 밖 무게 단위 → 전체 무게 단위 → 괄호 밖 단위 없는 수 → 전체 단위 없는 수 순.
 * 괄호 안 부연("500g (강력 400 + 통밀 100)")이 그램을 가리지 않고,
 * "1 1/2 cups (340g)"에서는 컵 수가 아니라 괄호 안 340g을 쓴다.
 * 같은 그룹에 수가 2개 이상이고 '+'가 있으면 합산("물 100g + 50g"), 아니면 마지막 값.
 */
function pickGrams(line: string): number | undefined {
  const outer = line.replace(/\([^)]*\)/gu, ' ');
  const outerTokens = numberTokens(outer);
  const allTokens = numberTokens(line);
  const groups: [NumberToken[], string][] = [
    [outerTokens.filter((t) => t.kind === 'mass'), outer],
    [allTokens.filter((t) => t.kind === 'mass'), line],
    [outerTokens.filter((t) => t.kind === 'bare'), outer],
    [allTokens.filter((t) => t.kind === 'bare'), line],
  ];
  for (const [tokens, source] of groups) {
    if (tokens.length === 0) continue;
    if (tokens.length >= 2 && source.includes('+')) {
      return tokens.reduce((a, t) => a + t.value, 0);
    }
    return tokens[tokens.length - 1].value;
  }
  return undefined;
}

function hasAmount(tokens: NumberToken[]): boolean {
  return tokens.some((t) => t.kind === 'mass' || t.kind === 'bare');
}

function contains(line: string, keywords: string[]): boolean {
  const lower = line.toLowerCase();
  return keywords.some((k) => lower.includes(k.toLowerCase()));
}

/**
 * 단어 경계 매칭 — Swift(ICU)의 \b는 한글·악센트 문자도 단어 문자로 취급하므로
 * JS의 ASCII \b 대신 유니코드 lookaround로 같은 의미를 구현한다.
 * (예: "lait fermenté"의 ferment는 단어 경계가 아니다)
 */
function containsWord(line: string, word: string): boolean {
  return new RegExp(`(?<![\\p{L}\\p{M}\\p{N}_])${word}(?![\\p{L}\\p{M}\\p{N}_])`, 'iu').test(line);
}

function matchesFlour(line: string): boolean {
  // "코코아가루"·"시나몬가루"는 가루지만 밀가루가 아니다
  if (contains(line, ['코코아', '카카오', '시나몬', '계피', '말차', '녹차', '커피'])) return false;
  // T45/T65/T110 … — "밀T65"처럼 문자가 붙으면 매칭하지 않는다 (ICU \b 의미)
  if (/(?<![\p{L}\p{M}\p{N}_])t[0-9]{2,3}(?![\p{L}\p{M}\p{N}_])/iu.test(line)) return true;
  return contains(line, [
    '밀가루', '가루', '강력', '중력', '박력', '호밀', '통밀', '스펠트', '세몰리나', '듀럼',
    '트레디션', 'flour', 'farine', 'rye', 'wheat', 'spelt', 'semolina', 'durum',
    'tradition', 'grau', '메밀', '옥수수가루',
  ]);
}

const LEVAIN_KEYWORDS = [
  '르방', 'levain', '스타터', 'starter', '발효종', '사전반죽', '풀리시', 'poolish', 'biga',
];

/** 르방(사전발효종) 줄·이름 — '르뱅쿠키'는 과자 이름, 'leavening'은 팽창제라 제외 */
function matchesLevain(line: string): boolean {
  return (
    contains(line, LEVAIN_KEYWORDS) ||
    containsWord(line, 'ferment') ||
    containsWord(line, 'leaven') ||
    /르뱅(?!\s*쿠키)/u.test(line)
  );
}

/** 물 — 물엿·시럽과 '물'이 들어간 다른 단어(곡물·식물성 …)는 제외, eau는 단어 단위(gâteau 방지) */
function matchesWater(line: string): boolean {
  return (
    (contains(line, ['물', 'water']) &&
      !contains(line, ['물엿', '시럽', 'syrup', '곡물', '식물성', '동물성', '해산물'])) ||
    containsWord(line, 'eau')
  );
}

// ── 전처리 ──────────────────────────────────────────────────────────

/**
 * SNS 표기 제거 — @멘션은 재료 이름이 아니고, #해시태그는 잡음이다 ("@75%"처럼 숫자뿐이면 멘션이 아니다).
 * 키캡 번호("1️⃣ 르방 만들기", 🔟)는 섹션·단계 번호라 수량이 아니다
 */
function stripSocialTokens(line: string): string {
  return line
    .replace(/(?:[0-9#*]\u{FE0F}?\u{20E3}|\u{1F51F}\u{FE0F}?)[.)]?[ \t]*/gu, '')
    .replace(/@(?=[A-Za-z0-9_.]*[A-Za-z_])[A-Za-z0-9_.]+/gu, '')
    .replace(/#\S+/gu, '');
}

/** Swift CharacterSet.newlines와 동일한 줄 분리 (U+2028/2029, NEL, 단독 \r 포함) */
const NEWLINES = /\r\n|[\n\r\v\f\u0085\u2028\u2029]/;

/** 파싱 전 전체 텍스트 정리 (NFC 정규화 — iOS localizedCaseInsensitiveContains의 정준 동등성 대응) */
export function cleanForParsing(text: string): string {
  return text
    .normalize('NFC')
    .split(NEWLINES)
    .map((l) => stripSocialTokens(l))
    .join('\n');
}

/**
 * 온도 표기 제거 — "물 350g (30°C)"·"물 350g 30도" 같은 줄이 오염되지 않도록
 * 괄호 안 온도와 "30°C"/"30℃"/"30도" 토큰을 걷어낸다
 * ("도" 뒤에 글자가 이어지면(포도·도우 등) 매칭하지 않는다)
 */
function stripTemperatures(line: string): string {
  return line
    .replace(/\([^)]*(?:°|℃|온도|[0-9][ \t]*도)[^)]*\)/g, '')
    .replace(/[0-9]+(?:[.,][0-9]+)?[ \t]*(?:°[CcFf]?|℃|도씨?(?![가-힣A-Za-z]))/g, '');
}

/**
 * 시간·차수 표기 제거 — "실온 6시간 발효", "30분 휴지", "1차 발효 3~4시간", "3회 폴딩" 같은 줄의 숫자가
 * 그램으로 합산되지 않도록 한다 (르방 빌드 섹션에서 특히 치명적). 범위("3~4시간", "3-4 hours" — 대시는 붙여 쓴 것만)는 앞 수까지 지운다.
 * 숫자가 앞서는 재료("50 초코칩", "20 분유", "4분할")는 시간이 아니고,
 * 차·회·번 뒤에 다른 글자가 붙으면("1회분", "번데기") 차수가 아니다.
 */
function stripDurations(line: string): string {
  return line
    .replace(
      /(?:[0-9]+(?:[.,][0-9]+)?(?:[ \t]*[~〜～][ \t]*|[–-]))?[0-9]+(?:[.,][0-9]+)?[ \t]*(?:시간|분(?!유|당|말|할)|초(?!코|콜)|hours?|hrs?|minutes?|mins?|seconds?|secs?)(?![A-Za-z])/giu,
      '',
    )
    .replace(
      /(?<![0-9.,])(?:[0-9]{1,2}(?:[ \t]*[~〜～][ \t]*|[–-]))?[0-9]{1,2}[ \t]*(?:차|회차?|번째?)(?=[^가-힣A-Za-z0-9]|$|발효|반죽|폴딩|접기|펀칭|성형|휴지|믹싱|오토리즈)/gu,
      '',
    );
}

/**
 * 한 줄에 여러 재료를 쓰는 표기("강력분 500 / 물 350 / 소금 10") 분할.
 * 그램 수량을 가진 조각이 2개 이상일 때만 분할을 채택한다 —
 * "밀가루(강력/T65) 500g" 같은 줄은 그대로 둔다. 분수(1/2)의 /는 구분자가 아니다.
 */
function splitSegments(line: string): string[] {
  let work = line.replace(/,(?=\s)/g, '⎮');
  work = work.replace(/(?<![0-9])\/|\/(?![0-9])/g, '⎮');
  for (const sep of ['|', '·', '•', ';']) {
    work = work.split(sep).join('⎮');
  }
  const parts = work.split('⎮');
  if (parts.length <= 1) return [line];
  const numeric = parts.filter((p) => hasAmount(numberTokens(p)));
  return numeric.length >= 2 ? parts : [line];
}

/**
 * 재료가 아닌 줄 (헤더·합계 등).
 * 수분율/hydration/온도는 그램 수량이 함께 있으면 재료 줄이므로 거르지 않는다.
 */
function shouldSkip(line: string): boolean {
  const t = line.trim();
  if (t === '') return true;
  // 합계 표기는 괄호 밖·머리 기호("- ", "• ") 뒤에서 본다 — "물 700g (총 수분율 75%)"는 재료 줄.
  // 괄호 밖에 양이 없으면("재료 (총 960g)"·"(합계 960g)") 괄호 안까지 본다
  let outer = t.replace(/\([^)]*\)/gu, ' ');
  if (!/\p{L}/u.test(outer) || !hasAmount(numberTokens(outer))) outer = t.replace(/[()]/gu, ' ');
  outer = outer.replace(/^[^\p{L}\p{N}]+/u, '');
  if (/(?<![가-힣A-Za-z0-9])총|총\s*(?:계|량|중량|무게)|합\s*계|^계(?![가-힣A-Za-z0-9])/u.test(outer)) {
    return true;
  }
  if (!matchesLevain(outer) && /전체\s*반죽|반죽\s*(?:무게|중량)|분할/u.test(outer)) return true;
  if (contains(outer, ['total', '재 료', '베이커', 'baker'])) return true;
  if (contains(t, ['수분율', 'hydration', '온도']) && !hasAmount(numberTokens(t))) {
    return true; // "수분율 75%" 같은 통계·표기 줄
  }
  // "물 340g에 르방을 풀어주세요" 같은 서술문
  if (/(하세요|해주세요|주세요|해 주세요|니다)/u.test(t)) return true;
  // "양 (g)" / "g" 같은 표 헤더
  if (/^(재\s*료|양|무게|amount|quantity|ingr)[^0-9]*$/i.test(t)) return true;
  return false;
}

/** 숫자·단위를 걷어낸 재료 이름 */
function ingredientName(line: string): string {
  let s = line.replace(
    /(?<![A-Za-z0-9])(?:[0-9]+[ \t]+)?[0-9]+(?:\/[0-9]+|(?:[ \u00A0\u202F\u2009][0-9]{3})*(?:[.,][0-9]+)?)[ \t\u00A0\u202F\u2009]*(?:%|(?:kg|㎏|키로|킬로|g|gr|gram(?:me)?s?|그램|ml|oz|ounces?|lbs?|pounds?|cups?|컵|tsp|tbsp|teaspoons?|tablespoons?|큰술|작은술|티스푼|개|large|medium|small)(?![\p{L}\p{M}\p{N}_]))?/giu,
    '',
  );
  s = s.replace(/\([ \t]*\)/g, '');
  return trimCharacters(s, ' \t\u00A0\u202F\u2009:·.-—|');
}

function trimCharacters(s: string, chars: string): string {
  const set = new Set(chars);
  let start = 0;
  let end = s.length;
  while (start < end && set.has(s[start])) start++;
  while (end > start && set.has(s[end - 1])) end--;
  return s.slice(start, end);
}

/** 제목 후보에서 "G." "1)" 같은 머리 기호 제거 */
function cleanTitle(line: string): string {
  return line.trim().replace(/^[A-Za-z0-9]{1,3}[.)][ \t]*/, '').trim();
}

/** Swift String.count(자소 클러스터 수)와 동일한 길이 — 이모지 하나는 1 */
const graphemeSegmenter =
  typeof Intl !== 'undefined' && 'Segmenter' in Intl ? new Intl.Segmenter() : null;

function graphemeCount(s: string): number {
  if (graphemeSegmenter) return [...graphemeSegmenter.segment(s)].length;
  return [...s].length; // 폴백: 코드포인트 수
}

// ── 섹션 헤더 ───────────────────────────────────────────────────────

/** 르방 빌드 섹션 헤더 — "르방 만들기", "스타터 리프레시" 등 (숫자 없는 줄) */
function isLevainBuildHeader(line: string): boolean {
  return (
    matchesLevain(line) &&
    contains(line, ['만들기', '만드는', '빌드', 'build', '리프레시', 'refresh', '키우기', '밥주기', '먹이주기'])
  );
}

/** 본반죽 섹션 헤더 */
function isMainDoughHeader(line: string): boolean {
  return contains(line, ['본반죽', '본 반죽', '최종반죽', '최종 반죽', 'main dough', 'final dough']);
}

/** 공정(만드는 법) 섹션 헤더 — 이후 줄은 서술부로 보고 파싱을 멈춘다 */
function isMethodHeader(line: string): boolean {
  return (
    !matchesLevain(line) &&
    (contains(line, [
      '만드는 법', '만드는법', '방법', '만들기', '순서', '공정', '과정',
      'method', 'instruction', 'direction', 'préparation', 'étapes',
    ]) ||
      containsWord(line, 'steps') ||
      containsWord(line, 'how to') ||
      containsWord(line, 'procedures?'))
  );
}

// ── 파싱 ────────────────────────────────────────────────────────────

export function parseRecipeText(text: string): ParsedRecipeText {
  let name: string | null = null;
  const flours: Flour[] = [];
  let water = 0;
  let bassinage = 0;
  let salt = 0;
  let levainGrams = 0;
  let levainHydration = 1.0;
  let levainHydrationExplicit = false;
  let levainName: string | null = null;
  const liquids: Liquid[] = [];
  const yeast: Yeast = { type: 'fresh', grams: 0 };
  const extras: Extra[] = [];
  let matched = 0;

  // 섹션 상태 — 르방 빌드 섹션 재료는 본반죽에 합산하지 않는다
  type Section = 'main' | 'levainBuild' | 'stopped';
  let section: Section = 'main';
  let buildFlour = 0;
  let buildWater = 0;
  let buildTotal = 0;

  // 전처리 + 구분자 분할
  const segments: { text: string; hadDuration: boolean }[] = [];
  for (const rawLine of text.normalize('NFC').split(NEWLINES)) {
    // "G." "1)" 같은 머리 기호를 먼저 떼야 헤더("1. 재료")를 제대로 거른다
    const pre = stripTemperatures(stripSocialTokens(cleanTitle(rawLine)));
    const line = stripDurations(pre);
    // 시간·차수만 남았던 공정 줄("벌크 발효 4시간", "1차 발효")은 제목 후보가 아니다
    const hadDuration = line !== pre;
    for (const part of splitSegments(line)) segments.push({ text: part, hadDuration });
  }

  for (const segment of segments) {
    const line = segment.text.trim();
    if (section === 'stopped') continue;
    if (shouldSkip(line)) continue;

    const grams = pickGrams(line);
    // %는 괄호 안("(수분율 100%)")에도 오므로 전체에서 찾되,
    // "(총 수분율 75%)"처럼 반죽 전체를 가리키는 괄호는 이 재료의 %가 아니다
    const percent = numberTokens(line.replace(/\([^)]*(?:총|반죽|total)[^)]*\)/giu, ' ')).find(
      (t) => t.kind === 'pct',
    )?.value;

    if (grams === undefined || grams <= 0) {
      // 괄호 밖에 컵·스푼·개수만 있는 줄은 그램을 모르는 재료 줄 — 섹션 헤더·제목 후보가 아니다
      // ("본반죽 (빵 2개 분량)"은 머리글)
      const outer = line.replace(/\([^)]*\)/gu, ' ');
      if (numberTokens(outer).some((t) => t.kind === 'measure')) continue;
      // 숫자 없는 줄: 섹션 헤더 또는 제목 후보
      if (isLevainBuildHeader(line)) {
        section = 'levainBuild';
      } else if (isMainDoughHeader(line)) {
        section = 'main';
      } else if (matched >= 2 && isMethodHeader(line)) {
        section = 'stopped';
      } else if (
        name === null &&
        numberTokens(line).length === 0 &&
        section === 'main' &&
        !segment.hadDuration
      ) {
        const t = cleanTitle(line);
        if (graphemeCount(t) >= 2) name = t;
      }
      continue;
    }

    matched += 1;

    // 르방 빌드 섹션: 밀가루/물 비율로 수분율을 추정하고 총량만 기억한다
    if (section === 'levainBuild') {
      buildTotal += grams;
      if (matchesLevain(line)) {
        // 종(chef) — 총량에만 반영
      } else if (matchesWater(line)) {
        buildWater += grams;
      } else if (matchesFlour(line)) {
        buildFlour += grams;
      }
      continue;
    }

    if (contains(line, ['바시나주', '바시나쥬', 'bassinage', '조절수', '조정수'])) {
      bassinage += grams;
    } else if (matchesLevain(line)) {
      levainGrams += grams;
      levainName = ingredientName(line);
      if (contains(line, ['리퀴드', 'liquide', 'liquid'])) {
        levainHydration = 1.0;
        levainHydrationExplicit = true;
      } else if (
        contains(line, ['뒤흐', '뒤르', '듀르', '스티프', 'stiff']) ||
        containsWord(line, 'dur')
      ) {
        levainHydration = 0.5;
        levainHydrationExplicit = true;
      } else if (percent !== undefined && percent >= 30 && percent <= 150) {
        // 30~150% 밖의 %는 수분율이 아니라 베이커스 퍼센트 표기일 가능성이 높다
        // (예: "르방 100g (20%)") — 무시하고 기본 수분율을 유지한다
        levainHydration = percent / 100;
        levainHydrationExplicit = true;
      }
    } else if (
      contains(line, ['소금', '천일염', '소곰']) ||
      containsWord(line, 'salt') ||
      containsWord(line, 'sel')
    ) {
      salt += grams;
    } else if (contains(line, ['이스트', 'yeast', 'levure', '효모']) || containsWord(line, 'IDY')) {
      yeast.grams += grams;
      if (contains(line, ['인스턴트', '드라이', 'instant', 'dry', 'sèche']) || containsWord(line, 'IDY')) {
        yeast.type = 'instant';
      }
    } else if (contains(line, ['우유', 'milk', 'lait'])) {
      liquids.push({
        id: newId(),
        name: ingredientName(line),
        grams,
        waterRatio: LIQUID_PRESETS.milk.waterRatio,
      });
    } else if (contains(line, ['계란', '달걀', '전란', 'egg', 'oeuf', 'œuf'])) {
      liquids.push({
        id: newId(),
        name: ingredientName(line),
        grams,
        waterRatio: LIQUID_PRESETS.egg.waterRatio,
      });
    } else if (matchesWater(line)) {
      water += grams;
    } else if (matchesFlour(line)) {
      flours.push({ id: newId(), name: ingredientName(line), grams });
    } else {
      extras.push({ id: newId(), name: ingredientName(line), grams });
    }
  }

  // 르방 빌드 섹션 정산:
  // 본반죽에 르방 g가 명시돼 있으면 빌드 재료는 그 내역이므로 버리고,
  // 없으면 빌드 총량이 곧 르방이다. 수분율은 빌드의 물/밀가루 비로 추정.
  if (buildTotal > 0) {
    if (levainGrams === 0) levainGrams = buildTotal;
    if (!levainHydrationExplicit && buildFlour > 0) {
      const h = buildWater / buildFlour;
      if (h >= 0.3 && h <= 1.5) levainHydration = h;
    }
  }

  // "르방 리퀴드" 자체는 표시용 이름으로 의미 없음
  const flourName = levainName && !matchesLevain(levainName) ? levainName : undefined;

  const input: DoughInput = {
    flours,
    water,
    bassinage,
    salt,
    levain: {
      type: levainTypeFor(levainHydration),
      hydration: levainHydration,
      grams: levainGrams,
      flourName: flourName || undefined,
    },
    liquids,
    yeast,
    extras,
  };
  return { name, input, matchedLineCount: matched, levainHydrationExplicit };
}
