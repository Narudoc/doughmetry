import { useCallback, useState } from 'react';
import { newId } from '../lib/id';
import { loadRecipes, persistRecipes } from '../lib/storage';
import type { Recipe } from '../types';

export interface RecipesApi {
  recipes: Recipe[];
  /** upsert — 같은 id가 있으면 덮어쓰기(createdAt 유지), 없으면 추가 */
  save(recipe: Recipe): void;
  rename(id: string, name: string): void;
  duplicate(id: string): void;
  remove(id: string): void;
  importAll(items: Recipe[]): void;
}

export function useRecipes(): RecipesApi {
  const [recipes, setRecipes] = useState<Recipe[]>(() => loadRecipes());

  const mutate = useCallback((fn: (prev: Recipe[]) => Recipe[]) => {
    setRecipes((prev) => {
      const next = fn(prev);
      persistRecipes(next);
      return next;
    });
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
    (items: Recipe[]) => {
      mutate((prev) => {
        const ids = new Set(prev.map((p) => p.id));
        const merged = [...prev];
        for (const item of items) {
          const id = ids.has(item.id) ? newId() : item.id;
          ids.add(id);
          merged.push({ ...item, id });
        }
        return merged;
      });
    },
    [mutate],
  );

  return { recipes, save, rename, duplicate, remove, importAll };
}
