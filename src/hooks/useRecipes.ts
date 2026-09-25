import { useCallback, useEffect, useRef, useState } from 'react';
import { newId } from '../lib/id';
import {
  RECIPES_KEY,
  loadRecipeList,
  mergeImported,
  reloadRecipes,
  updateRecipes,
} from '../lib/storage';
import type { Recipe } from '../types';

export interface ImportSummary {
  added: number;
  updated: number;
  skipped: number;
}

export interface RecipesApi {
  recipes: Recipe[];
  /** 마지막 변경을 이 브라우저 저장소에 쓰지 못했다 — 목록에는 있지만 새로 고치면 사라진다 */
  writeFailed: boolean;
  /** 쓰기 실패 횟수 — 실패할 때마다 늘어나므로 알림을 띄우는 데 쓴다 */
  writeFailCount: number;
  /** upsert — 같은 id가 있으면 덮어쓰기(createdAt 유지), 없으면 추가 */
  save(recipe: Recipe): void;
  rename(id: string, name: string): void;
  duplicate(id: string): void;
  remove(id: string): void;
  /** id 기준 병합 — 규칙은 storage.mergeImported */
  importAll(items: Recipe[]): ImportSummary;
}

export function useRecipes(): RecipesApi {
  const [list, setList] = useState(() => loadRecipeList());
  const latest = useRef(list);
  const [writeFailCount, setWriteFailCount] = useState(0);

  // 저장(부수 효과)과 newId가 두 번 실행되지 않도록 setState 업데이터 밖에서 처리한다 (StrictMode)
  const mutate = useCallback((fn: (current: Recipe[]) => Recipe[]) => {
    const next = updateRecipes(fn, latest.current);
    latest.current = next;
    setList(next);
    if (!next.persisted) setWriteFailCount((n) => n + 1);
  }, []);

  // 다른 탭에서 바뀐 목록을 화면에 반영 (key가 null이면 저장소 전체가 비워진 것)
  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key !== RECIPES_KEY && e.key !== null) return;
      latest.current = reloadRecipes(latest.current);
      setList(latest.current);
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  const save = useCallback(
    (recipe: Recipe) => {
      mutate((prev) => {
        const now = new Date().toISOString();
        const existing = prev.find((p) => p.id === recipe.id);
        const next: Recipe = {
          ...recipe,
          createdAt: existing?.createdAt ?? recipe.createdAt,
          updatedAt: now,
        };
        return existing ? prev.map((p) => (p.id === next.id ? next : p)) : [...prev, next];
      });
    },
    [mutate],
  );

  const rename = useCallback(
    (id: string, name: string) => {
      mutate((prev) =>
        prev.map((p) =>
          p.id === id ? { ...p, name, updatedAt: new Date().toISOString() } : p,
        ),
      );
    },
    [mutate],
  );

  const duplicate = useCallback(
    (id: string) => {
      mutate((prev) => {
        const src = prev.find((p) => p.id === id);
        if (!src) return prev;
        const now = new Date().toISOString();
        const copy: Recipe = {
          ...structuredClone(src),
          id: newId(),
          name: `${src.name} (복사)`,
          createdAt: now,
          updatedAt: now,
        };
        return [...prev, copy];
      });
    },
    [mutate],
  );

  const remove = useCallback(
    (id: string) => {
      mutate((prev) => prev.filter((p) => p.id !== id));
    },
    [mutate],
  );

  const importAll = useCallback(
    (items: Recipe[]): ImportSummary => {
      let summary: ImportSummary = { added: 0, updated: 0, skipped: 0 };
      mutate((prev) => {
        const { recipes: merged, ...counts } = mergeImported(prev, items);
        summary = counts;
        return merged;
      });
      return summary;
    },
    [mutate],
  );

  return {
    recipes: list.recipes,
    writeFailed: !list.persisted,
    writeFailCount,
    save,
    rename,
    duplicate,
    remove,
    importAll,
  };
}
