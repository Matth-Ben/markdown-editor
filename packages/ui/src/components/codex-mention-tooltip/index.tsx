"use client";

import { useId, useState } from "react";
import { useCodexEntry } from "../markdown-content/codex-context";

export interface CodexMentionTooltipProps {
  entityName: string;
}

export function CodexMentionTooltip({ entityName }: CodexMentionTooltipProps) {
  const entry = useCodexEntry(entityName);
  const [open, setOpen] = useState(false);
  const tooltipId = useId();

  if (!entry) {
    return <span className="text-muted underline decoration-dotted">{entityName}</span>;
  }

  return (
    <span className="relative inline-block">
      <button
        type="button"
        aria-describedby={open ? tooltipId : undefined}
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => setOpen(false)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
        className="text-foreground underline decoration-accent-cyan decoration-2 underline-offset-2"
      >
        {entityName}
      </button>
      {open ? (
        <span
          id={tooltipId}
          role="tooltip"
          className="absolute bottom-full left-0 z-10 mb-1 w-56 rounded-lg border border-white/10 bg-surface p-2 text-xs shadow-lg"
        >
          <span className="block text-[10px] uppercase tracking-wide text-muted">
            {entry.category}
          </span>
          {entry.summary}
        </span>
      ) : null}
    </span>
  );
}
