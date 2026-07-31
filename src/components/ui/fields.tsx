import { useEffect, useState } from 'react';

const inputBase =
  'w-full min-h-[44px] rounded border border-line bg-white px-3 text-base ' +
  'focus-visible:ring-2 focus-visible:ring-brass focus-visible:outline-none';

function formatForEdit(v: number): string {
  if (!Number.isFinite(v)) return '';
  return String(Math.round(v * 1000) / 1000);
}

interface NumberFieldProps {
  label?: string;
  value: number;
  onChange: (v: number) => void;
  unit?: string;
  min?: number;
  className?: string;
  ariaLabel?: string;
  disabled?: boolean;
}

/** 숫자 입력 — inputMode="decimal"로 모바일 숫자 키패드, 내부는 문자열로 편집 */
export function NumberField({
  label,
  value,
  onChange,
  unit,
  min = 0,
  className = '',
  ariaLabel,
  disabled = false,
}: NumberFieldProps) {
  const [text, setText] = useState(() => formatForEdit(value));
  const [focused, setFocused] = useState(false);

  useEffect(() => {
    if (!focused) setText(formatForEdit(value));
  }, [value, focused]);

  const handleChange = (t: string) => {
    setText(t);
    const trimmed = t.trim();
    if (trimmed === '') {
      onChange(min);
      return;
    }
    const n = Number(trimmed.replace(',', '.'));
    if (Number.isFinite(n)) onChange(Math.max(min, n));
  };

  const input = (
    <div className="relative">
      <input
        type="text"
        inputMode="decimal"
        value={text}
        aria-label={ariaLabel ?? label}
        disabled={disabled}
        onFocus={() => setFocused(true)}
        onBlur={() => {
          setFocused(false);
          setText(formatForEdit(value));
        }}
        onChange={(e) => handleChange(e.target.value)}
        className={`${inputBase} text-right tabular-nums ${unit ? 'pr-9' : ''} disabled:bg-paper disabled:text-ink/50`}
      />
      {unit && (
        <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-ink/50">
          {unit}
        </span>
      )}
    </div>
  );

  if (!label) return <div className={className}>{input}</div>;
  return (
    <label className={`block ${className}`}>
      <span className="mb-1 block text-xs font-medium text-ink/70">{label}</span>
      {input}
    </label>
  );
}

interface TextFieldProps {
  label?: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  className?: string;
  ariaLabel?: string;
  autoFocus?: boolean;
}

export function TextField({
  label,
  value,
  onChange,
  placeholder,
  className = '',
  ariaLabel,
  autoFocus = false,
}: TextFieldProps) {
  const input = (
    <input
      type="text"
      value={value}
      placeholder={placeholder}
      aria-label={ariaLabel ?? label ?? placeholder}
      autoFocus={autoFocus}
      onChange={(e) => onChange(e.target.value)}
      className={inputBase}
    />
  );
  if (!label) return <div className={className}>{input}</div>;
  return (
    <label className={`block ${className}`}>
      <span className="mb-1 block text-xs font-medium text-ink/70">{label}</span>
      {input}
    </label>
  );
}
