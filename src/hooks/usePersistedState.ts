import { useEffect, useRef, useState } from 'react';
import { loadJson, saveJson } from '../lib/storage';

const NONE = Symbol('none');

function readStored<T>(key: string, initial: () => T, sanitize?: (loaded: unknown) => T | null): T {
  const loaded = loadJson<unknown>(key);
  if (loaded === null) return initial();
  if (sanitize) return sanitize(loaded) ?? initial();
  return loaded as T;
}

/**
 * localStorage에 자동 저장되는 상태. sanitize가 null을 돌려주면 initial로 대체한다.
 * syncTabs면 다른 탭에서 같은 키를 바꿀 때 따라간다 — 편집 중인 초안처럼 탭마다 따로 둬야 하는 값에는 쓰지 말 것.
 */
export function usePersistedState<T>(
  key: string,
  initial: () => T,
  sanitize?: (loaded: unknown) => T | null,
  { syncTabs = false }: { syncTabs?: boolean } = {},
) {
  const [value, setValue] = useState<T>(() => readStored(key, initial, sanitize));

  // 저장소에서 읽어 온 값(첫 값·다른 탭의 값)은 다시 쓰지 않는다 — 버전이 다른 두 탭이 sanitize 결과를 번갈아 고쳐 쓰지 않도록
  const fromStore = useRef<T | typeof NONE>(value);
  useEffect(() => {
    const skip = value === fromStore.current;
    fromStore.current = NONE;
    if (!skip) saveJson(key, value);
  }, [key, value]);

  useEffect(() => {
    if (!syncTabs) return;
    const onStorage = (e: StorageEvent) => {
      if (e.key !== key && e.key !== null) return;
      const next = readStored(key, initial, sanitize);
      fromStore.current = next;
      setValue(next);
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, syncTabs]);

  return [value, setValue] as const;
}
