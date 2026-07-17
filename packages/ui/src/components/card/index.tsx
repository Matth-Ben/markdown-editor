import type { ReactNode } from "react";

export interface CardProps {
  children: ReactNode;
  className?: string;
}

export function Card({ children, className = "" }: CardProps) {
  return (
    <div className={`overflow-hidden rounded-xl border border-white/10 bg-surface ${className}`}>
      {children}
    </div>
  );
}
