import ReactMarkdown, { type Components } from "react-markdown";
import { markdownRemarkPlugins } from "@nexus/core";
import { AmbianceTriggerButton, type AmbianceTriggerButtonProps } from "../ambiance-trigger-button";

const components = {
  "ambiance-trigger": AmbianceTriggerButton,
} as unknown as Components;

export function MarkdownContent({ content }: { content: string }) {
  return (
    <ReactMarkdown remarkPlugins={markdownRemarkPlugins} components={components}>
      {content}
    </ReactMarkdown>
  );
}

export type { AmbianceTriggerButtonProps };
