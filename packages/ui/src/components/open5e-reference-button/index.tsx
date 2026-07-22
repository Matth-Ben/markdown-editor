"use client";

import { useState } from "react";
import type { Open5eKind } from "@nexus/core";
import { Modal } from "../modal";
import { Open5eDetailContent } from "../open5e-detail-content";

export function Open5eReferenceButton({
  kind,
  entryKey,
  label,
  className,
}: {
  kind: Open5eKind;
  entryKey: string;
  label: string;
  className?: string;
}) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className={
          className ??
          "rounded-full border border-accent-cyan/40 bg-background px-2 py-0.5 text-xs text-foreground hover:bg-surface"
        }
      >
        {label}
      </button>
      <Modal open={open} onClose={() => setOpen(false)} title={label}>
        <Open5eDetailContent kind={kind} entryKey={entryKey} />
      </Modal>
    </>
  );
}
