import { useEffect, useRef, useState } from 'react';
import { loadJson, saveJson } from '../lib/storage';

/** localStorage에 자동 저장되는 상태. sanitize가 null을 돌려주면 initial로 대체한다. */
export function usePersistedState<T>(
  key: string,
  initial: () => T,
  sanitize?: (loaded: unknown) => T | null,
) {
  const [value, setValue] = useState<T>(() => {
    const loaded = loadJson<unknown>(key);
    if (loaded === null) return initial();
    if (sanitize) return sanitize(loaded) ?? initial();
    return loaded as T;
  });

  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    saveJson(key, value);
  }, [key, value]);

  return [value, setValue] as const;
}
