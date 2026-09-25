import type { ReactNode } from 'react';
import { useEffect, useRef, useState } from 'react';
import { Button } from './Button';
import { TextField } from './fields';

/** 입력 중인 다이얼로그를 배경 클릭·Escape·취소로 닫을 때 묻는 문구 */
export const DISCARD_PROMPT = '저장하지 않은 내용이 사라집니다. 닫을까요?';

const FOCUSABLE =
  'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), ' +
  'textarea:not([disabled]), summary, [tabindex]:not([tabindex="-1"])';

interface DialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  /** 넓은 콘텐츠(가져오기 확인 등)용 */
  wide?: boolean;
  /** 버리면 아까운 입력이 있을 때 true — 배경 클릭·Escape로 닫기 전에 확인을 받는다 */
  confirmDismiss?: boolean;
}

export function Dialog(props: DialogProps) {
  if (!props.open) return null;
  return <DialogPanel {...props} />;
}

/** Tab/Shift+Tab이 패널 밖(뒤쪽 페이지)으로 나가지 않도록 처음·끝에서 되감는다 */
function trapTab(e: KeyboardEvent, panel: HTMLElement) {
  const items = Array.from(panel.querySelectorAll<HTMLElement>(FOCUSABLE)).filter(
    (el) => el.getClientRects().length > 0,
  );
  if (items.length === 0) {
    e.preventDefault();
    panel.focus();
    return;
  }
  const first = items[0];
  const last = items[items.length - 1];
  const active = document.activeElement;
  if (active === panel || !panel.contains(active)) {
    e.preventDefault();
    (e.shiftKey ? last : first).focus();
  } else if (e.shiftKey && active === first) {
    e.preventDefault();
    last.focus();
  } else if (!e.shiftKey && active === last) {
    e.preventDefault();
    first.focus();
  }
}

/** 열릴 때마다 새로 마운트된다 — 연 요소를 기억했다가 닫힐 때 포커스를 돌려준다 */
function DialogPanel({
  onClose,
  title,
  children,
  footer,
  wide = false,
  confirmDismiss = false,
}: DialogProps) {
  // autoFocus가 포커스를 옮기기 전(렌더 시점)에 읽어야 연 요소를 얻는다
  const [opener] = useState(() =>
    document.activeElement instanceof HTMLElement ? document.activeElement : null,
  );
  const panelRef = useRef<HTMLDivElement>(null);
  const restoreTo = useRef<HTMLElement | null>(null);
  const pressOnBackdrop = useRef(false);

  useEffect(() => {
    const panel = panelRef.current;
    const active = document.activeElement;
    if (restoreTo.current === null) {
      // 연 요소가 방금 닫힌 앞 다이얼로그 안에 있었다면(텍스트 입력 → 가져오기 확인) 그 다이얼로그가 포커스를 돌려준 곳으로 돌아간다
      restoreTo.current =
        !opener?.isConnected &&
        active instanceof HTMLElement &&
        active !== document.body &&
        !panel?.contains(active)
          ? active
          : opener;
    }
    if (panel && !panel.contains(active)) panel.focus();
    return () => {
      // 이어서 열린 다이얼로그가 포커스를 가져갔으면 건드리지 않는다
      const now = document.activeElement;
      const target = restoreTo.current;
      if (target?.isConnected && (now === null || now === document.body)) target.focus();
    };
  }, [opener]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const panel = panelRef.current;
      // 탭 전환(뒤로 가기 등)으로 숨은 페이지에 남은 다이얼로그는 키를 가로채지 않는다
      if (!panel || panel.getClientRects().length === 0) return;
      if (e.key === 'Escape' && !e.isComposing) {
        if (confirmDismiss && !window.confirm(DISCARD_PROMPT)) return;
        onClose();
      } else if (e.key === 'Tab') {
        trapTab(e, panel);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose, confirmDismiss]);

  return (
    <div
      className="no-print fixed inset-0 z-40 flex items-end justify-center bg-ink/40 p-4 sm:items-center"
      onPointerDown={(e) => {
        // 패널 안에서 누르고 배경에서 뗀 드래그(텍스트 선택)도 배경 click이 되므로, 누른 곳까지 배경일 때만 닫는다
        pressOnBackdrop.current = e.target === e.currentTarget;
      }}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) e.preventDefault(); // 배경을 눌러도 포커스가 패널 밖으로 빠지지 않게
      }}
      onClick={(e) => {
        const fromBackdrop = pressOnBackdrop.current && e.target === e.currentTarget;
        pressOnBackdrop.current = false;
        if (!fromBackdrop) return;
        if (confirmDismiss && !window.confirm(DISCARD_PROMPT)) return;
        onClose();
      }}
    >
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        className={`w-full ${wide ? 'max-w-2xl' : 'max-w-md'} rounded-lg bg-paper p-5 shadow-xl focus:outline-none`}
      >
        <h2 className="font-display text-lg font-semibold text-bottle">{title}</h2>
        <div className="mt-3">{children}</div>
        {footer && <div className="mt-5 flex justify-end gap-2">{footer}</div>}
      </div>
    </div>
  );
}

interface ConfirmDialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  message: ReactNode;
  confirmLabel?: string;
  onConfirm: () => void;
}

export function ConfirmDialog({
  open,
  onClose,
  title,
  message,
  confirmLabel = '삭제',
  onConfirm,
}: ConfirmDialogProps) {
  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={title}
      footer={
        <>
          <Button onClick={onClose}>취소</Button>
          <Button
            variant="danger"
            onClick={() => {
              onConfirm();
              onClose();
            }}
          >
            {confirmLabel}
          </Button>
        </>
      }
    >
      <p className="text-sm text-ink/80">{message}</p>
    </Dialog>
  );
}

interface PromptDialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  label: string;
  initialValue: string;
  submitLabel?: string;
  onSubmit: (value: string) => void;
}

export function PromptDialog({
  open,
  onClose,
  title,
  label,
  initialValue,
  submitLabel = '확인',
  onSubmit,
}: PromptDialogProps) {
  const [value, setValue] = useState(initialValue);
  useEffect(() => {
    if (open) setValue(initialValue);
  }, [open, initialValue]);

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={title}
      confirmDismiss={value !== initialValue}
      footer={
        <>
          <Button onClick={onClose}>취소</Button>
          <Button
            variant="primary"
            disabled={value.trim() === ''}
            onClick={() => {
              onSubmit(value.trim());
              onClose();
            }}
          >
            {submitLabel}
          </Button>
        </>
      }
    >
      <TextField label={label} value={value} onChange={setValue} autoFocus />
    </Dialog>
  );
}

export interface SaveRecipeData {
  name: string;
  tags: string[];
  note?: string;
  overwrite: boolean;
}

interface SaveRecipeDialogProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  initialName: string;
  initialTags?: string[];
  initialNote?: string;
  /** 불러온 레시피가 있어 덮어쓰기가 가능한 경우 */
  allowOverwrite?: boolean;
  /** 불러온 레시피의 저장된 이름 — 이름이 이와 다르면 덮어쓰기를 끈 채로 시작한다 */
  loadedName?: string;
  onSave: (data: SaveRecipeData) => void;
}

export function SaveRecipeDialog({
  open,
  onClose,
  title = '레시피 저장',
  initialName,
  initialTags = [],
  initialNote = '',
  allowOverwrite = false,
  loadedName,
  onSave,
}: SaveRecipeDialogProps) {
  // 계산기 이름 칸에서 이미 바꾼 이름도 걸러내도록 페이지 이름이 아니라 저장된 이름과 비교한다
  const baseName = (loadedName ?? initialName).trim();
  const initialOverwrite = allowOverwrite && initialName.trim() === baseName;
  const [name, setName] = useState(initialName);
  const [tags, setTags] = useState(initialTags.join(', '));
  const [note, setNote] = useState(initialNote);
  const [overwrite, setOverwrite] = useState(initialOverwrite);

  useEffect(() => {
    if (open) {
      setName(initialName);
      setTags(initialTags.join(', '));
      setNote(initialNote);
      setOverwrite(initialOverwrite);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={title}
      confirmDismiss={
        name !== initialName || tags !== initialTags.join(', ') || note !== initialNote
      }
      footer={
        <>
          <Button onClick={onClose}>취소</Button>
          <Button
            variant="primary"
            disabled={name.trim() === ''}
            onClick={() => {
              onSave({
                name: name.trim(),
                tags: tags
                  .split(',')
                  .map((t) => t.trim())
                  .filter(Boolean),
                note: note.trim() || undefined,
                overwrite,
              });
              onClose();
            }}
          >
            저장
          </Button>
        </>
      }
    >
      <div className="space-y-3">
        <TextField
          label="이름"
          value={name}
          onChange={(v) => {
            setName(v);
            // 이름을 바꾸면 새 레시피로 저장하려는 것으로 보고 덮어쓰기를 해제한다 (다시 켤 수는 있음)
            if (allowOverwrite && v.trim() !== baseName) setOverwrite(false);
          }}
          autoFocus
        />
        <TextField
          label="태그 (쉼표로 구분)"
          value={tags}
          onChange={setTags}
          placeholder="캉파뉴, 바게트"
        />
        <label className="block">
          <span className="mb-1 block text-xs font-medium text-ink/70">메모</span>
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
            rows={3}
            className="w-full rounded border border-line bg-white px-3 py-2 text-base focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brass"
          />
        </label>
        {allowOverwrite && (
          <label className="flex min-h-[44px] items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={overwrite}
              onChange={(e) => setOverwrite(e.target.checked)}
              className="h-4 w-4 accent-[#1E4034]"
            />
            불러온 레시피에 덮어쓰기
          </label>
        )}
      </div>
    </Dialog>
  );
}
