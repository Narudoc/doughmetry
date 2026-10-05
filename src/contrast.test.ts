import { describe, expect, it } from 'vitest';

// 글자 대비(WCAG 1.4.3, 4.5:1) — 보조 글자는 ink/70(종이 위 5.4:1)·bottle/80(5.8:1) 이상.
// 그보다 옅은 글자는 비활성(disabled:)이나 장식(aria-hidden)에만 쓴다
const sources = import.meta.glob<string>('./**/*.tsx', { query: '?raw', import: 'default', eager: true });

const MIN_ALPHA: Record<string, number> = { ink: 70, bottle: 80 };
const TEXT_COLOR = /((?:[\w-]+:)*)text-(ink|bottle)\/(\d+)/g;

describe('보조 글자 대비', () => {
  it('ink/70·bottle/80보다 옅은 글자는 비활성·장식에만 쓴다', () => {
    const offenders: string[] = [];
    for (const [file, src] of Object.entries(sources)) {
      src.split('\n').forEach((line, i) => {
        for (const [match, variants, color, alpha] of line.matchAll(TEXT_COLOR)) {
          if (Number(alpha) >= MIN_ALPHA[color]) continue;
          if (variants.includes('disabled:') || line.includes('aria-hidden')) continue;
          offenders.push(`${file}:${i + 1} ${match}`);
        }
      });
    }
    expect(Object.keys(sources).length).toBeGreaterThan(10);
    expect(offenders).toEqual([]);
  });
});
