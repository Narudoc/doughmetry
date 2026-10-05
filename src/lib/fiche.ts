import type { PctBasis } from '../types';
import type { DoughInput, DoughStats } from './dough';
import type { Precision } from './format';
import { fmtGrams, fmtPct, uiPct } from './format';

export interface FicheOptions {
  pieces?: number;
  precision: Precision;
  basis: PctBasis;
}

/**
 * 공유·복사용 배합표 텍스트 (iOS FicheRows.swift ficheText와 같은 줄 순서). 반올림은 format.ts에만 맡기고,
 * 재료 이름·빈 이름 대체는 배합표(BakersTable)와 같게 쓴다.
 * %는 표시 기준을 따르므로 마지막 줄에 기준을 적는다 — PFF와 총 수분율은 항상 총 밀가루 기준.
 * 형식을 바꾸면 recipeParser.test.ts ↔ RecipeTextParserTests.swift의 fiche 픽스처도 함께 고칠 것
 */
export function ficheText(
  name: string,
  input: DoughInput,
  stats: DoughStats,
  { pieces, precision, basis }: FicheOptions,
): string {
  const g = (grams: number) => `${fmtGrams(grams, precision)} g`;
  const pct = (grams: number) => fmtPct(uiPct(stats, grams, basis));
  const levainType = input.levain.type === 'liquide' ? '리퀴드 liquide' : '뒤흐 dur';
  const levainHydration = (input.levain.hydration * 100).toFixed(0);

  const lines: string[] = [`〔${name.trim() || '배합표'}〕 fiche technique`, ''];
  input.flours.forEach((f, i) => {
    lines.push(`${f.name || `밀가루 ${i + 1}`}  ${g(f.grams)}  (${pct(f.grams)})`);
  });
  lines.push(`물 (본반죽)  ${g(input.water)}`);
  if (input.bassinage > 0) lines.push(`바시나주  ${g(input.bassinage)}`);
  lines.push(`소금  ${g(input.salt)}  (${pct(input.salt)})`);
  lines.push(
    `르방 (${levainType} ${levainHydration}%)  ${g(input.levain.grams)}  (${pct(input.levain.grams)})`,
  );
  lines.push(`  ↳ 속 밀가루  ${g(stats.levainFlour)}  (PFF ${fmtPct(stats.pffPct)})`);
  // 액체는 수분 함량을 밝혀야 다시 가져올 때 이름과 무관하게 액체로 돌아온다 ("꿀  30.0 g  (3.0%) · 수분 17.0%")
  input.liquids.forEach((l, i) => {
    lines.push(
      `${l.name || `액체 ${i + 1}`}  ${g(l.grams)}  (${pct(l.grams)}) · 수분 ${fmtPct(l.waterRatio * 100)}`,
    );
  });
  if (input.yeast.grams > 0) {
    const yeast = input.yeast.type === 'fresh' ? '생이스트' : '인스턴트 드라이';
    lines.push(`이스트 (${yeast})  ${g(input.yeast.grams)}  (${pct(input.yeast.grams)})`);
  }
  input.extras.forEach((e, i) => {
    lines.push(`${e.name || `기타 ${i + 1}`}  ${g(e.grams)}  (${pct(e.grams)})`);
  });

  lines.push('');
  lines.push(`총 밀가루  ${g(stats.totalFlour)}`);
  lines.push(`총 물  ${g(stats.totalWater)}`);
  lines.push(`총 수분율  ${fmtPct(stats.hydrationPct)}`);
  lines.push(`총 반죽 무게  ${g(stats.doughWeight)}`);
  if (pieces && pieces > 0) lines.push(`분할 ${pieces}개 — 개당 ${g(stats.doughWeight / pieces)}`);
  lines.push('');
  lines.push(basis === 'added' ? '%는 첨가 밀가루 대비' : '%는 총 밀가루 대비');
  return lines.join('\n');
}
