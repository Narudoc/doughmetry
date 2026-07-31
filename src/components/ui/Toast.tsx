import { useCallback, useState } from 'react';

export interface ToastItem {
  id: number;
  message: string;
}

let seq = 0;

export function useToasts() {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const show = useCallback((message: string) => {
    const id = ++seq;
    setToasts((ts) => [...ts, { id, message }]);
    window.setTimeout(() => setToasts((ts) => ts.filter((t) => t.id !== id)), 2600);
  }, []);
  return { toasts, show };
}

export function ToastStack({ toasts }: { toasts: ToastItem[] }) {
  return (
    <div
      className="no-print pointer-events-none fixed inset-x-0 bottom-4 z-50 flex flex-col items-center gap-2 px-4"
      role="status"
      aria-live="polite"
    >
      {toasts.map((t) => (
        <div
          key={t.id}
          className="toast-enter rounded bg-bottle-deep px-4 py-2.5 text-sm text-paper shadow-lg"
        >
          {t.message}
        </div>
      ))}
    </div>
  );
}
