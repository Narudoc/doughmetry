import type { ReactNode } from 'react';
import { useEffect, useState } from 'react';
import { Button } from './Button';
import { TextField } from './fields';

interface DialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
}

export function Dialog({ open, onClose, title, children, footer }: DialogProps) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div
      className="no-print fixed inset-0 z-40 flex items-end justify-center bg-ink/40 p-4 sm:items-center"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="w-full max-w-md rounded-lg bg-paper p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
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
  onSave,
}: SaveRecipeDialogProps) {
  const [name, setName] = useState(initialName);
  const [tags, setTags] = useState(initialTags.join(', '));
  const [note, setNote] = useState(initialNote);
  const [overwrite, setOverwrite] = useState(allowOverwrite);

  useEffect(() => {
    if (open) {
      setName(initialName);
      setTags(initialTags.join(', '));
      setNote(initialNote);
      setOverwrite(allowOverwrite);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={title}
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
