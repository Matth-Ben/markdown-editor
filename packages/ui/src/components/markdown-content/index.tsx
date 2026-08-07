"use client";

import ReactMarkdown, { type Components } from "react-markdown";
import { markdownRemarkPlugins } from "@nexus/core";
import { AmbianceTriggerButton, type AmbianceTriggerButtonProps } from "../ambiance-trigger-button";
import { CodexMentionTooltip } from "../codex-mention-tooltip";
import { CodexContext, type CodexEntrySummary } from "./codex-context";

const components = {
  "ambiance-trigger": AmbianceTriggerButton,
  "codex-mention": CodexMentionTooltip,
} as unknown as Components;

export function MarkdownContent({
  content,
  codexEntries = {},
}: {
  content: string;
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  return (
    <CodexContext.Provider value={codexEntries}>
      <ReactMarkdown remarkPlugins={markdownRemarkPlugins} components={components}>
        {content}
      </ReactMarkdown>
    </CodexContext.Provider>
  );
}

export type { AmbianceTriggerButtonProps, CodexEntrySummary };
