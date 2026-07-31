import { useCallback, useEffect, useState } from 'react';

export type TabId = 'calc' | 'convert' | 'recipes';

const parseHash = (): TabId => {
  const h = window.location.hash.replace('#', '');
  return h === 'convert' || h === 'recipes' ? h : 'calc';
};

export function useHashTab(): [TabId, (t: TabId) => void] {
  const [tab, setTabState] = useState<TabId>(parseHash);

  useEffect(() => {
    const onHash = () => setTabState(parseHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  const setTab = useCallback((t: TabId) => {
    window.location.hash = t;
  }, []);

  return [tab, setTab];
}
