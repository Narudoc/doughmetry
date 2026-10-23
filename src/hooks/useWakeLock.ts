import { useEffect } from 'react';

/** Screen Wake Lock API 중 쓰는 부분 — 테스트가 navigator.wakeLock 대신 넣는다 */
export interface WakeLockSentinelLike {
  readonly released: boolean;
  release(): Promise<void>;
  addEventListener(type: 'release', listener: () => void): void;
}

export interface WakeLockLike {
  request(type: 'screen'): Promise<WakeLockSentinelLike>;
}

export interface VisibilityTarget {
  readonly visibilityState: DocumentVisibilityState;
  addEventListener(type: 'visibilitychange', listener: () => void): void;
  removeEventListener(type: 'visibilitychange', listener: () => void): void;
}

const browserWakeLock = (): WakeLockLike | undefined =>
  typeof navigator === 'undefined'
    ? undefined
    : ((navigator as Partial<Navigator>).wakeLock as WakeLockLike | undefined);

/** 이 브라우저가 화면 켜두기를 지원하는가 — 지원하지 않으면 설정을 보이지 않는다 */
export function wakeLockSupported(wakeLock: WakeLockLike | undefined = browserWakeLock()): boolean {
  return typeof wakeLock?.request === 'function';
}

/**
 * 돌려준 함수를 부를 때까지 화면이 꺼지지 않게 한다. 지원하지 않거나 거절되면 아무 일도 하지 않는다 (예외를 던지지 않는다).
 * 브라우저는 페이지가 가려지면 잠금을 스스로 풀므로, 다시 보일 때(visibilitychange) 새로 요청한다
 */
export function holdScreenWakeLock(
  wakeLock: WakeLockLike | undefined = browserWakeLock(),
  doc: VisibilityTarget | undefined = typeof document === 'undefined' ? undefined : document,
): () => void {
  if (!wakeLock || !wakeLockSupported(wakeLock) || !doc) return () => undefined;
  let stopped = false;
  let pending = false;
  /** 요청을 기다리는 동안 페이지가 다시 보였다 — 그 visibilitychange는 이미 지나갔으니 끝나면 한 번 더 본다 */
  let missed = false;
  let sentinel: WakeLockSentinelLike | null = null;

  const releaseQuietly = (s: WakeLockSentinelLike) => {
    try {
      s.release().catch(() => undefined);
    } catch {
      // 이미 풀린 잠금
    }
  };

  const acquire = () => {
    if (stopped || doc.visibilityState !== 'visible') return;
    if (pending) {
      missed = true;
      return;
    }
    if (sentinel && !sentinel.released) return;
    pending = true;
    missed = false;
    let request: Promise<WakeLockSentinelLike>;
    try {
      request = wakeLock.request('screen');
    } catch {
      pending = false;
      return;
    }
    request.then(
      (s) => {
        pending = false;
        // 기다리는 동안 그만두라고 했으면 받자마자 푼다
        if (stopped) {
          releaseQuietly(s);
          return;
        }
        sentinel = s;
        s.addEventListener('release', () => {
          if (sentinel === s) sentinel = null;
        });
        if (missed) acquire();
      },
      () => {
        // 거절(배터리 절약 모드·권한 정책·가려진 페이지) — 다음에 보일 때 다시 요청한다
        pending = false;
        if (missed) acquire();
      },
    );
  };

  doc.addEventListener('visibilitychange', acquire);
  acquire();

  return () => {
    stopped = true;
    doc.removeEventListener('visibilitychange', acquire);
    const s = sentinel;
    sentinel = null;
    if (s && !s.released) releaseQuietly(s);
  };
}

/** active인 동안 화면을 켜 둔다 — false가 되거나 언마운트되면 푼다 */
export function useWakeLock(active: boolean): void {
  useEffect(() => {
    if (!active) return;
    return holdScreenWakeLock();
  }, [active]);
}
