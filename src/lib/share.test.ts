import { describe, expect, it } from 'vitest';
import type { ShareTarget } from './share';
import { canShareText, shareOrCopy } from './share';

/** 공유 시트·클립보드 대역 */
function fakeNav({ share, clipboard = true }: { share?: () => Promise<void>; clipboard?: boolean | 'fail' }) {
  const calls = { shared: [] as Array<{ title?: string; text?: string }>, copied: [] as string[] };
  const nav: ShareTarget = {
    share: share
      ? (data) => {
          calls.shared.push(data);
          return share();
        }
      : undefined,
    clipboard: clipboard
      ? {
          writeText: (text) => {
            if (clipboard === 'fail') return Promise.reject(new Error('denied'));
            calls.copied.push(text);
            return Promise.resolve();
          },
        }
      : undefined,
  };
  return { nav, calls };
}

async function run(nav: ShareTarget) {
  const toasts: string[] = [];
  await shareOrCopy('캉파뉴 (뒤흐 50%)', '배합표', (m) => toasts.push(m), nav);
  return toasts;
}

describe('shareOrCopy (계산기·변환기의 배합표 공유)', () => {
  it('공유 시트가 있으면 공유하고 복사하지 않는다', async () => {
    const { nav, calls } = fakeNav({ share: () => Promise.resolve() });
    expect(canShareText(nav)).toBe(true);
    expect(await run(nav)).toEqual([]);
    expect(calls.shared).toEqual([{ title: '캉파뉴 (뒤흐 50%)', text: '배합표' }]);
    expect(calls.copied).toEqual([]);
  });

  it('공유 시트를 닫으면 아무것도 하지 않는다', async () => {
    const { nav, calls } = fakeNav({ share: () => Promise.reject(new DOMException('cancel', 'AbortError')) });
    expect(await run(nav)).toEqual([]);
    expect(calls.copied).toEqual([]);
  });

  it('공유가 실패하거나 공유 시트가 없으면 복사하고 알린다', async () => {
    const failed = fakeNav({ share: () => Promise.reject(new DOMException('no', 'NotAllowedError')) });
    expect(await run(failed.nav)).toEqual(['배합표를 복사했습니다']);
    expect(failed.calls.copied).toEqual(['배합표']);
    const none = fakeNav({});
    expect(canShareText(none.nav)).toBe(false);
    expect(await run(none.nav)).toEqual(['배합표를 복사했습니다']);
  });

  it('복사도 못 하면 그렇게 알린다', async () => {
    expect(await run(fakeNav({ clipboard: 'fail' }).nav)).toEqual(['복사하지 못했습니다']);
    expect(await run(fakeNav({ clipboard: false }).nav)).toEqual(['복사하지 못했습니다']);
    expect(await run(undefined as unknown as ShareTarget)).toEqual(['복사하지 못했습니다']);
  });
});
