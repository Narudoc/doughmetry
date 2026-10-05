import type { ReactNode } from 'react';

/** 프랑스어 원어 병기 — 화면 읽기 프로그램이 프랑스어로 읽도록 lang을 붙인다 */
export function Fr({ children, className = '' }: { children: ReactNode; className?: string }) {
  return (
    <span lang="fr" className={`italic ${className}`}>
      {children}
    </span>
  );
}
