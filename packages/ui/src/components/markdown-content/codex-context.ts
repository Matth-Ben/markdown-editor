"use client";

import { createContext, useContext } from "react";

export interface CodexEntrySummary {
  category: string;
  summary: string;
}

export const CodexContext = createContext<Record<string, CodexEntrySummary>>({});

export function useCodexEntry(name: string): CodexEntrySummary | undefined {
  const entries = useContext(CodexContext);
  return entries[name.trim().toLowerCase()];
}
