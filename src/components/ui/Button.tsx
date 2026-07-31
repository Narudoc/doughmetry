import type { ButtonHTMLAttributes } from 'react';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';

const styles: Record<Variant, string> = {
  primary: 'bg-bottle text-paper hover:bg-bottle-deep border border-transparent',
  secondary: 'bg-white text-ink border border-line hover:border-bottle/40',
  ghost: 'bg-transparent text-bottle hover:bg-bottle/5 border border-transparent',
  danger: 'bg-danger text-white hover:bg-danger/90 border border-transparent',
};

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  small?: boolean;
}

export function Button({ variant = 'secondary', small = false, className = '', ...rest }: Props) {
  return (
    <button
      type="button"
      className={[
        'inline-flex items-center justify-center gap-1 rounded font-medium',
        'transition-colors motion-reduce:transition-none',
        'disabled:pointer-events-none disabled:opacity-40',
        small ? 'min-h-[36px] px-3 text-sm' : 'min-h-[44px] px-4',
        styles[variant],
        className,
      ].join(' ')}
      {...rest}
    />
  );
}
