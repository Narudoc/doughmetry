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

/** raised: 좁은 화면의 계산기 하단 요약 바 위로 올린다 */
export function ToastStack({ toasts, raised = false }: { toasts: ToastItem[]; raised?: boolean }) {
  return (
    <div
      className={`no-print pointer-events-none fixed inset-x-0 z-50 flex flex-col items-center gap-2 px-4 ${
        raised ? 'bottom-24 lg:bottom-4' : 'bottom-4'
      }`}
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
