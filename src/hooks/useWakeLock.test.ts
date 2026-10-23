import { describe, expect, it } from 'vitest';
import type { VisibilityTarget, WakeLockLike, WakeLockSentinelLike } from './useWakeLock';
import { holdScreenWakeLock, wakeLockSupported } from './useWakeLock';

class FakeSentinel implements WakeLockSentinelLike {
  released = false;
  private listeners: Array<() => void> = [];
  addEventListener(_type: 'release', listener: () => void) {
    this.listeners.push(listener);
  }
  release() {
    if (!this.released) {
      this.released = true;
      this.listeners.forEach((l) => l());
    }
    return Promise.resolve();
  }
}

/** navigator.wakeLock 대역 — 요청마다 잠금 하나, 브라우저처럼 가려지면 스스로 푼다 */
class FakeWakeLock implements WakeLockLike {
  sentinels: FakeSentinel[] = [];
  requests = 0;
  reject = false;
  /** 요청을 바로 끝내지 않고 settle()을 기다린다 */
  hold = false;
  private waiting: Array<() => void> = [];
  request(_type: 'screen') {
    this.requests++;
    if (this.reject) return Promise.reject(new DOMException('denied', 'NotAllowedError'));
    const s = new FakeSentinel();
    this.sentinels.push(s);
    if (!this.hold) return Promise.resolve(s);
    return new Promise<FakeSentinel>((resolve) => this.waiting.push(() => resolve(s)));
  }
  settle() {
    this.waiting.splice(0).forEach((f) => f());
  }
  get held() {
    return this.sentinels.filter((s) => !s.released).length;
  }
}

class FakeDocument implements VisibilityTarget {
  visibilityState: DocumentVisibilityState = 'visible';
  private listeners = new Set<() => void>();
  constructor(private lock?: FakeWakeLock) {}
  addEventListener(_type: 'visibilitychange', listener: () => void) {
    this.listeners.add(listener);
  }
  removeEventListener(_type: 'visibilitychange', listener: () => void) {
    this.listeners.delete(listener);
  }
  get listenerCount() {
    return this.listeners.size;
  }
  setVisible(visible: boolean) {
    this.visibilityState = visible ? 'visible' : 'hidden';
    if (!visible) this.lock?.sentinels.forEach((s) => void s.release());
    this.listeners.forEach((l) => l());
  }
}

const flush = () => new Promise<void>((r) => setTimeout(r, 0));

describe('holdScreenWakeLock (계산기 탭 화면 켜두기)', () => {
  it('보이는 페이지에서 화면 잠금을 요청하고, 그만두면 푼다', async () => {
    const lock = new FakeWakeLock();
    const doc = new FakeDocument(lock);
    const stop = holdScreenWakeLock(lock, doc);
    await flush();
    expect(lock.requests).toBe(1);
    expect(lock.held).toBe(1);
    stop();
    await flush();
    expect(lock.held).toBe(0);
    expect(doc.listenerCount).toBe(0);
  });

  it('가려졌다 다시 보이면 새로 요청한다 — 브라우저가 가려질 때 잠금을 푼다', async () => {
    const lock = new FakeWakeLock();
    const doc = new FakeDocument(lock);
    const stop = holdScreenWakeLock(lock, doc);
    await flush();
    doc.setVisible(false);
    await flush();
    expect(lock.held).toBe(0);
    expect(lock.requests).toBe(1);
    doc.setVisible(true);
    await flush();
    expect(lock.requests).toBe(2);
    expect(lock.held).toBe(1);
    stop();
    await flush();
    expect(lock.held).toBe(0);
  });

  it('잠금이 있는 동안 visibilitychange가 와도 겹쳐 요청하지 않는다', async () => {
    const lock = new FakeWakeLock();
    const doc = new FakeDocument();
    const stop = holdScreenWakeLock(lock, doc);
    await flush();
    doc.setVisible(true);
    await flush();
    expect(lock.requests).toBe(1);
    stop();
  });

  it('가려진 채 시작하면 보일 때까지 기다린다', async () => {
    const lock = new FakeWakeLock();
    const doc = new FakeDocument(lock);
    doc.visibilityState = 'hidden';
    const stop = holdScreenWakeLock(lock, doc);
    await flush();
    expect(lock.requests).toBe(0);
    doc.setVisible(true);
    await flush();
    expect(lock.held).toBe(1);
    stop();
  });

  it('요청을 기다리는 동안 그만두면 받은 잠금을 바로 푼다', async () => {
    const lock = new FakeWakeLock();
    lock.hold = true;
    const doc = new FakeDocument(lock);
    const stop = holdScreenWakeLock(lock, doc);
    stop();
    lock.settle();
    await flush();
    expect(lock.requests).toBe(1);
    expect(lock.held).toBe(0);
  });

  it('기다리는 동안 가려졌다 다시 보였으면 끝난 뒤 다시 요청한다', async () => {
    const lock = new FakeWakeLock();
    lock.hold = true;
    const doc = new FakeDocument(lock);
    const stop = holdScreenWakeLock(lock, doc);
    doc.setVisible(false);
    doc.setVisible(true);
    lock.hold = false;
    lock.settle();
    await flush();
    expect(lock.requests).toBe(2);
    expect(lock.held).toBe(1);
    stop();
    await flush();
    expect(lock.held).toBe(0);
  });

  it('거절되면 조용히 넘어가고, 다음에 보일 때 다시 요청한다', async () => {
    const lock = new FakeWakeLock();
    lock.reject = true;
    const doc = new FakeDocument(lock);
    const stop = holdScreenWakeLock(lock, doc);
    await flush();
    expect(lock.requests).toBe(1);
    expect(lock.held).toBe(0);
    lock.reject = false;
    doc.setVisible(false);
    doc.setVisible(true);
    await flush();
    expect(lock.held).toBe(1);
    stop();
  });

  it('요청이 바로 예외를 던져도 밖으로 내보내지 않는다', () => {
    const throwing: WakeLockLike = {
      request: () => {
        throw new TypeError('not allowed');
      },
    };
    expect(() => holdScreenWakeLock(throwing, new FakeDocument())()).not.toThrow();
  });

  it('API가 없으면 아무 일도 하지 않는다', () => {
    expect(wakeLockSupported(undefined)).toBe(false);
    expect(wakeLockSupported({} as WakeLockLike)).toBe(false);
    expect(wakeLockSupported(new FakeWakeLock())).toBe(true);
    const doc = new FakeDocument();
    const stop = holdScreenWakeLock(undefined, doc);
    expect(doc.listenerCount).toBe(0);
    expect(() => stop()).not.toThrow();
    // 테스트 환경(node)에는 navigator.wakeLock도 document도 없다
    expect(() => holdScreenWakeLock()()).not.toThrow();
  });
});
