import type { Extra, Flour, Liquid, Yeast } from '../types';
import type { DoughInput } from './dough';
import { LIQUID_PRESETS, levainTypeFor } from './dough';
import { newId } from './id';

/**
 * 레시피 텍스트 → 배합 규칙 기반 파서.
 * iOS(LevainCore/RecipeTextParser.swift)의 이식본 — 규칙이 바뀌면 두 곳을 함께 고칠 것.
 * 키워드는 한국어·영어·프랑스어 제빵 용어를 커버한다.
 *
 * 처리 순서: 머리 기호 제거 → SNS 토큰 제거 → 온도 표기 제거 → 구분자 분할
 * → 섹션 인식(르방 빌드/본반죽/공정) → 재료 분류.
 */

export interface ParsedRecipeText {
  name: string | null;
  input: DoughInput;
  /** 재료로 인식된 줄 수 — 0이면 인식 실패로 판단 */
  matchedLineCount: number;
}

interface NumberToken {
  value: number;
  isPercent: boolean;
}

/**
 * 줄 단위 숫자 토큰: (값, %) 여부.
 * "T65"처럼 영문자에 붙은 숫자는 양이 아니므로 제외 — 경계 문자를 함께 매칭한다.
 * 단위: % 는 수분율, kg/㎏/키로/킬로 는 g로 환산(×1000)
 */
function numberTokens(line: string): NumberToken[] {
  const tokens: NumberToken[] = [];
  const pattern = /(?:^|[^A-Za-z0-9])([0-9]+(?:,[0-9]{3})*(?:[.,][0-9]+)?)[ \t]*(%|[kK][gG]|㎏|키로|킬로)?/g;
  for (const match of line.matchAll(pattern)) {
    let raw = match[1];
    // 천 단위 쉼표 제거 (쉼표 뒤 3자리), 남은 쉼표는 소수점으로
    raw = raw.replace(/,(?=[0-9]{3}(\D|$))/g, '');
    raw = raw.replace(/,/g, '.');
    let v = Number(raw);
    if (!Number.isFinite(v)) continue;
    const unit = match[2]?.toLowerCase();
    if (unit && unit !== '%') v *= 1000; // kg 계열
    tokens.push({ value: v, isPercent: unit === '%' });
  }
  return tokens;
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

function matchesLevain(line: string): boolean {
  return contains(line, LEVAIN_KEYWORDS) || containsWord(line, 'ferment');
}

// ── 전처리 ──────────────────────────────────────────────────────────

/** SNS 표기 제거 — @멘션은 재료 이름이 아니고, #해시태그는 잡음이다 */
function stripSocialTokens(line: string): string {
  return line.replace(/@[A-Za-z0-9_.]+/g, '').replace(/#\S+/g, '');
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
 * 시간 표기 제거 — "실온 6시간 발효", "30분 휴지" 같은 줄의 숫자가
 * 그램으로 합산되지 않도록 한다 (르방 빌드 섹션에서 특히 치명적)
 */
function stripDurations(line: string): string {
  return line.replace(
    /[0-9]+(?:[.,][0-9]+)?[ \t]*(?:시간|분|초|hours?|hrs?|minutes?|mins?|seconds?|secs?)(?![A-Za-z])/gi,
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
  const numeric = parts.filter((p) => numberTokens(p).some((t) => !t.isPercent));
  return numeric.length >= 2 ? parts : [line];
}

/**
 * 재료가 아닌 줄 (헤더·합계 등).
 * 수분율/hydration/온도는 그램 수량이 함께 있으면 재료 줄이므로 거르지 않는다.
 */
function shouldSkip(line: string): boolean {
  const t = line.trim();
  if (t === '') return true;
  if (contains(t, ['합계', '총계', '총량', '총 ', 'total', '재 료', '베이커', 'baker'])) return true;
  if (
    contains(t, ['수분율', 'hydration', '온도']) &&
    !numberTokens(t).some((tok) => !tok.isPercent)
  ) {
    return true; // "수분율 75%" 같은 통계·표기 줄
  }
  // "물 340g에 르방을 풀어주세요" 같은 서술문
  if (/(하세요|해주세요|주세요|합니다|해 주세요)/.test(t)) return true;
  // "양 (g)" / "g" 같은 표 헤더
  if (/^(재\s*료|양|무게|amount|quantity|ingr)[^0-9]*$/i.test(t)) return true;
  return false;
}

/** 숫자·단위를 걷어낸 재료 이름 */
function ingredientName(line: string): string {
  let s = line.replace(
    /(?<![A-Za-z0-9])[0-9]+(?:[.,][0-9]+)?[ \t]*(?:%|g(?![\p{L}\p{M}\p{N}_])|그램|kg(?![\p{L}\p{M}\p{N}_])|㎏|키로|킬로)?/giu,
    '',
  );
  s = s.replace(/\([ \t]*\)/g, '');
  return trimCharacters(s, ' \t:·.-—|');
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
    contains(line, ['만드는 법', '만드는법', '만들기', '공정', '과정', 'method', 'instruction', 'direction', 'préparation'])
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
  const segments: string[] = [];
  for (const rawLine of text.normalize('NFC').split(NEWLINES)) {
    // "G." "1)" 같은 머리 기호를 먼저 떼야 헤더("1. 재료")를 제대로 거른다
    const line = stripDurations(stripTemperatures(stripSocialTokens(cleanTitle(rawLine))));
    segments.push(...splitSegments(line));
  }

  for (const segment of segments) {
    const line = segment.trim();
    if (section === 'stopped') continue;
    if (shouldSkip(line)) continue;

    // 괄호 안 부연("500g (강력 400 + 통밀 100)")이 그램을 가리지 않도록,
    // 그램은 괄호를 뗀 텍스트에서 먼저 찾고 없으면 전체에서 찾는다.
    // %는 괄호 안("(수분율 100%)")에도 오므로 전체에서 찾는다.
    const parenStripped = line.replace(/\([^)]*\)/g, ' ');
    const fullTokens = numberTokens(line);
    const strippedTokens = numberTokens(parenStripped);
    const strippedGrams = strippedTokens.filter((t) => !t.isPercent);
    let grams: number | undefined;
    if (strippedGrams.length >= 2 && parenStripped.includes('+')) {
      // "물 100g + 50g" 합산 표기
      grams = strippedGrams.reduce((a, t) => a + t.value, 0);
    } else {
      grams =
        strippedGrams[strippedGrams.length - 1]?.value ??
        [...fullTokens].reverse().find((t) => !t.isPercent)?.value;
    }
    const percent = fullTokens.find((t) => t.isPercent)?.value;

    if (grams === undefined || grams <= 0) {
      // 숫자 없는 줄: 섹션 헤더 또는 제목 후보
      if (isLevainBuildHeader(line)) {
        section = 'levainBuild';
      } else if (isMainDoughHeader(line)) {
        section = 'main';
      } else if (matched >= 2 && isMethodHeader(line)) {
        section = 'stopped';
      } else if (name === null && fullTokens.length === 0 && section === 'main') {
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
      } else if (
        (contains(line, ['물', 'water']) && !contains(line, ['물엿', '시럽', 'syrup'])) ||
        containsWord(line, 'eau')
      ) {
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
      } else if (contains(line, ['뒤흐', 'dur', '스티프', 'stiff'])) {
        levainHydration = 0.5;
        levainHydrationExplicit = true;
      } else if (percent !== undefined && percent >= 30 && percent <= 150) {
        // 30~150% 밖의 %는 수분율이 아니라 베이커스 퍼센트 표기일 가능성이 높다
        // (예: "르방 100g (20%)") — 무시하고 기본 수분율을 유지한다
        levainHydration = percent / 100;
        levainHydrationExplicit = true;
      }
    } else if (contains(line, ['소금', 'salt', 'sel', '천일염', '소곰'])) {
      salt += grams;
    } else if (contains(line, ['이스트', 'yeast', 'levure', '효모'])) {
      yeast.grams += grams;
      if (contains(line, ['인스턴트', '드라이', 'instant', 'dry', 'sèche'])) {
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
    } else if (
      (contains(line, ['물', 'water']) && !contains(line, ['물엿', '시럽', 'syrup'])) ||
      containsWord(line, 'eau')
    ) {
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
  const flourName =
    levainName && !contains(levainName, ['르방', 'levain', '스타터', 'starter'])
      ? levainName
      : undefined;

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
  return { name, input, matchedLineCount: matched };
}
