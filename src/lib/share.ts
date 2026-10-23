/** navigator 중 공유·복사에 쓰는 부분 — 테스트에서 대역을 넣는다 */
export interface ShareTarget {
  share?: (data: { title?: string; text?: string }) => Promise<void>;
  clipboard?: { writeText(text: string): Promise<void> };
}

/** 공유 시트가 있는 브라우저인가 — 없으면 공유 버튼이 클립보드 복사가 된다 */
export function canShareText(nav: ShareTarget | undefined = globalThis.navigator): boolean {
  return typeof nav?.share === 'function';
}

/**
 * 배합표 텍스트 공유 — 공유 시트가 없거나 실패하면 클립보드에 복사하고 알린다.
 * 사용자가 공유 시트를 닫은 것(AbortError)은 실패가 아니라 아무것도 하지 않는다
 */
export async function shareOrCopy(
  title: string,
  text: string,
  toast: (message: string) => void,
  nav: ShareTarget | undefined = globalThis.navigator,
): Promise<void> {
  if (nav && typeof nav.share === 'function') {
    try {
      await nav.share({ title, text });
      return;
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') return;
    }
  }
  try {
    if (!nav?.clipboard) throw new Error('clipboard unavailable');
    await nav.clipboard.writeText(text);
    toast('배합표를 복사했습니다');
  } catch {
    toast('복사하지 못했습니다');
  }
}
