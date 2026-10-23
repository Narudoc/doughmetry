import type { ReactNode } from 'react';
import { useEffect, useId, useRef, useState } from 'react';
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
        {footer && <div className="mt-5 flex flex-wrap justify-end gap-2">{footer}</div>}
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
  /** 되돌릴 수 없는 동작이 아니면 primary */
  confirmVariant?: 'danger' | 'primary';
  onConfirm: () => void;
}

export function ConfirmDialog({
  open,
  onClose,
  title,
  message,
  confirmLabel = '삭제',
  confirmVariant = 'danger',
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
            variant={confirmVariant}
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
  /**
   * 불러온 레시피가 있어 덮어쓰기가 가능한 경우 — 저장 버튼 대신 '덮어쓰기'·'새 레시피로 저장' 두 버튼.
   * 덮어쓸지는 누르는 순간 고른다 (미리 켜 둔 체크는 놓치기 쉽다, iOS SaveRecipeSheet와 같다)
   */
  allowOverwrite?: boolean;
  /** 덮어쓸 레시피의 저장된 이름 — 덮어쓰기 버튼이 어느 레시피를 바꾸는지, 이름도 바뀌는지 밝힌다 */
  loadedName?: string;
  /** 입력 칸 위에 보이는, 함께 저장되는 내용 (변환 결과의 분할 등) */
  preview?: ReactNode;
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
  preview,
  onSave,
}: SaveRecipeDialogProps) {
  const [name, setName] = useState(initialName);
  const [tags, setTags] = useState(initialTags.join(', '));
  const [note, setNote] = useState(initialNote);
  // 계산기 이름 칸에서 이미 바꾼 이름도 밝히도록 페이지 이름이 아니라 저장된 이름과 비교한다
  const target = (loadedName ?? initialName).trim();
  const overwriteDetail =
    name.trim() === '' || name.trim() === target
      ? `'${target}' 레시피를 바꿉니다`
      : `'${target}' 레시피를 바꾸고 이름을 '${name.trim()}'(으)로 고칩니다`;

  useEffect(() => {
    if (open) {
      setName(initialName);
      setTags(initialTags.join(', '));
      setNote(initialNote);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const submit = (overwrite: boolean) => {
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
  };
  const blank = name.trim() === '';

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
          {!allowOverwrite && (
            <Button variant="primary" disabled={blank} onClick={() => submit(false)}>
              저장
            </Button>
          )}
        </>
      }
    >
      <div className="space-y-3">
        {preview}
        <TextField label="이름" value={name} onChange={setName} autoFocus />
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
          <div className="space-y-2 pt-1">
            <SaveChoice
              title="덮어쓰기"
              detail={overwriteDetail}
              disabled={blank}
              onClick={() => submit(true)}
            />
            <SaveChoice
              title="새 레시피로 저장"
              detail="원래 레시피는 그대로 둡니다"
              disabled={blank}
              onClick={() => submit(false)}
            />
          </div>
        )}
      </div>
    </Dialog>
  );
}

function SaveChoice({
  title,
  detail,
  disabled,
  onClick,
}: {
  title: string;
  detail: string;
  disabled: boolean;
  onClick: () => void;
}) {
  const id = useId();
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      aria-labelledby={`${id}-title`}
      aria-describedby={`${id}-detail`}
      className="flex min-h-[44px] w-full flex-col items-start gap-0.5 rounded border border-line bg-white px-4 py-2.5 text-left transition-colors hover:border-bottle/40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brass disabled:pointer-events-none disabled:opacity-40 motion-reduce:transition-none"
    >
      <span id={`${id}-title`} className="font-medium text-bottle">
        {title}
      </span>
      <span id={`${id}-detail`} className="text-xs text-ink/70 [overflow-wrap:anywhere]">
        {detail}
      </span>
    </button>
  );
}
