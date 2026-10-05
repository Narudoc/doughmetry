import type { ReactNode } from 'react';
import { useEffect, useId, useRef, useState } from 'react';

const inputBase =
  'w-full min-h-[44px] rounded border border-line bg-white px-3 text-base ' +
  'focus-visible:ring-2 focus-visible:ring-brass focus-visible:outline-none';

/**
 * 숫자 입력 해석. 자릿수가 맞는 천 단위 구분("1,000", "12,345,678", "1,000.5")만 쉼표를 지우고,
 * 그 밖의 쉼표는 소수점으로 본다("72,5", "0,125" — 쉼표 소수점 키패드). 해석할 수 없으면 NaN.
 */
export function parseDecimalInput(s: string): number {
  if (/^[1-9]\d{0,2}(,\d{3})+(\.\d*)?$/.test(s)) return Number(s.replace(/,/g, ''));
  return Number(s.replace(',', '.'));
}

/** 0은 빈 칸(자리 표시자 0)으로 보인다 — 글자 '0' 앞에 커서가 놓여 400이 4000이 되는 일을 막는다 (iOS NumberField와 같다) */
export function formatForEdit(v: number): string {
  if (!Number.isFinite(v) || v === 0) return '';
  return String(Math.round(v * 1000) / 1000);
}

interface NumberFieldProps {
  /** 프랑스어 병기(<Fr>)처럼 요소가 섞인 라벨은 그 글자 그대로 입력 칸의 이름이 된다 */
  label?: ReactNode;
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
  const pointerFocus = useRef(false);
  const labelId = useId();
  // 단위(g·%)까지 이름에 섞이지 않도록 감싼 <label> 전체가 아니라 라벨 글자만 이름으로 쓴다
  const name = ariaLabel ?? (typeof label === 'string' ? label : undefined);

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
    const n = parseDecimalInput(trimmed);
    if (Number.isFinite(n)) onChange(Math.max(min, n));
  };

  const input = (
    <div className="relative">
      <input
        type="text"
        inputMode="decimal"
        value={text}
        placeholder="0"
        aria-label={name}
        aria-labelledby={name === undefined && label ? labelId : undefined}
        disabled={disabled}
        onPointerDown={(e) => {
          pointerFocus.current = document.activeElement !== e.currentTarget;
        }}
        onFocus={(e) => {
          setFocused(true);
          // iOS Safari는 포커스 직후 커서를 놓으며 선택을 풀므로 다음 프레임에 다시 선택한다
          const el = e.currentTarget;
          el.select();
          requestAnimationFrame(() => {
            if (document.activeElement === el) el.setSelectionRange(0, el.value.length);
          });
        }}
        onMouseUp={(e) => {
          // 눌러서 들어온 클릭의 mouseup이 선택을 커서로 접지 않게 한다 — 이미 편집 중이면 클릭한 곳에 커서를 둔다
          if (!pointerFocus.current) return;
          pointerFocus.current = false;
          e.preventDefault();
        }}
        onBlur={() => {
          pointerFocus.current = false;
          setFocused(false);
          setText(formatForEdit(value));
        }}
        onChange={(e) => handleChange(e.target.value)}
        className={`${inputBase} text-right tabular-nums placeholder:text-ink/70 ${unit ? 'pr-9' : ''} disabled:bg-paper disabled:text-ink/50`}
      />
      {unit && (
        <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-sm text-ink/70">
          {unit}
        </span>
      )}
    </div>
  );

  if (!label) return <div className={className}>{input}</div>;
  return (
    <label className={`block ${className}`}>
      <span id={labelId} className="mb-1 block text-xs font-medium text-ink/70">
        {label}
      </span>
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
