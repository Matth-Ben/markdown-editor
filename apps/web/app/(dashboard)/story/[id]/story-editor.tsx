"use client";

import { useActionState, useEffect, useRef, useState, type KeyboardEvent } from "react";
import { Button, MarkdownContent, MarkdownToolbar, type CodexEntrySummary } from "@nexus/ui";
import type { CodexEntry } from "@nexus/core";
import { updateStoryContent, type UpdateStoryState } from "./actions";
import { CodexSidebar } from "./codex-sidebar";
import { getCaretCoordinates } from "./caret-position";

type Layout = "split" | "tabs";

interface SuggestionState {
  query: string;
  triggerIndex: number;
  position: { top: number; left: number };
  activeIndex: number;
}

const LAYOUT_STORAGE_KEY = "nexus:editor-layout";
const initialState: UpdateStoryState = { error: null };

export function StoryEditor({
  storyId,
  initialContent,
  entries = [],
  codexEntries,
}: {
  storyId: string;
  initialContent: string;
  entries?: CodexEntry[];
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  const [content, setContent] = useState(initialContent);
  const [layout, setLayout] = useState<Layout>("split");
  const [activeTab, setActiveTab] = useState<"edit" | "preview">("edit");
  const [state, formAction, isPending] = useActionState(updateStoryContent, initialState);

  useEffect(() => {
    const stored = window.localStorage.getItem(LAYOUT_STORAGE_KEY);
    if (stored === "split" || stored === "tabs") setLayout(stored);
  }, []);

  function handleLayoutChange(next: Layout) {
    setLayout(next);
    window.localStorage.setItem(LAYOUT_STORAGE_KEY, next);
  }

  const codexEntryNames = entries.map((entry) => entry.name);

  return (
    <div className="flex flex-col gap-4 lg:flex-row lg:items-start">
      <div className="min-w-0 flex-1 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div role="radiogroup" aria-label="Disposition de l'éditeur" className="flex gap-2">
            <button
              type="button"
              role="radio"
              aria-checked={layout === "split"}
              onClick={() => handleLayoutChange("split")}
              className={`rounded-lg px-3 py-1.5 text-sm ${
                layout === "split" ? "bg-accent-violet text-white" : "bg-surface text-muted"
              }`}
            >
              Vue scindée
            </button>
            <button
              type="button"
              role="radio"
              aria-checked={layout === "tabs"}
              onClick={() => handleLayoutChange("tabs")}
              className={`rounded-lg px-3 py-1.5 text-sm ${
                layout === "tabs" ? "bg-accent-violet text-white" : "bg-surface text-muted"
              }`}
            >
              Onglets
            </button>
          </div>

          <form action={formAction}>
            <input type="hidden" name="storyId" value={storyId} />
            <input type="hidden" name="content" value={content} />
            <Button type="submit" isLoading={isPending}>
              {isPending ? "Enregistrement…" : "Enregistrer"}
            </Button>
          </form>
        </div>

        <div aria-live="polite">
          {state.error ? (
            <p role="alert" className="text-sm text-red-400">
              {state.error}
            </p>
          ) : null}
        </div>

        {layout === "tabs" ? (
          <div>
            <div
              role="tablist"
              aria-label="Mode d'affichage"
              className="mb-2 flex gap-2 border-b border-white/10"
            >
              <button
                type="button"
                role="tab"
                aria-selected={activeTab === "edit"}
                onClick={() => setActiveTab("edit")}
                className={`px-3 py-2 text-sm ${
                  activeTab === "edit"
                    ? "border-b-2 border-accent-cyan text-foreground"
                    : "text-muted"
                }`}
              >
                Édition
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={activeTab === "preview"}
                onClick={() => setActiveTab("preview")}
                className={`px-3 py-2 text-sm ${
                  activeTab === "preview"
                    ? "border-b-2 border-accent-cyan text-foreground"
                    : "text-muted"
                }`}
              >
                Aperçu
              </button>
            </div>

            {activeTab === "edit" ? (
              <EditorTextarea
                content={content}
                onChange={setContent}
                codexEntryNames={codexEntryNames}
              />
            ) : (
              <div className="prose prose-invert max-w-none rounded-lg border border-white/10 bg-surface p-4">
                <MarkdownContent content={content} codexEntries={codexEntries} />
              </div>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            <EditorTextarea
              content={content}
              onChange={setContent}
              codexEntryNames={codexEntryNames}
            />
            <div className="prose prose-invert max-w-none rounded-lg border border-white/10 bg-surface p-4">
              <MarkdownContent content={content} codexEntries={codexEntries} />
            </div>
          </div>
        )}
      </div>

      <CodexSidebar storyId={storyId} entries={entries} codexEntries={codexEntries} />
    </div>
  );
}

function EditorTextarea({
  content,
  onChange,
  codexEntryNames,
}: {
  content: string;
  onChange: (value: string) => void;
  codexEntryNames: string[];
}) {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [suggestion, setSuggestion] = useState<SuggestionState | null>(null);

  const matches = suggestion
    ? codexEntryNames
        .filter((name) => name.toLowerCase().includes(suggestion.query.toLowerCase()))
        .slice(0, 6)
    : [];

  function updateSuggestionFromCaret(value: string, cursor: number) {
    const textarea = textareaRef.current;
    if (!textarea) {
      setSuggestion(null);
      return;
    }

    const uptoCursor = value.slice(0, cursor);
    const match = /\[\[([^[\]]*)$/.exec(uptoCursor);
    if (!match) {
      setSuggestion(null);
      return;
    }

    const triggerIndex = cursor - match[1].length - 2;
    const position = getCaretCoordinates(textarea, cursor);
    setSuggestion({ query: match[1], triggerIndex, position, activeIndex: 0 });
  }

  function handleChange(event: React.ChangeEvent<HTMLTextAreaElement>) {
    const value = event.target.value;
    onChange(value);
    updateSuggestionFromCaret(value, event.target.selectionStart ?? value.length);
  }

  function completeSuggestion(name: string) {
    const textarea = textareaRef.current;
    if (!suggestion || !textarea) return;

    const cursor = textarea.selectionStart ?? content.length;
    const before = content.slice(0, suggestion.triggerIndex);
    const after = content.slice(cursor);
    const inserted = `[[${name}]]`;
    const nextValue = `${before}${inserted}${after}`;

    onChange(nextValue);
    setSuggestion(null);

    requestAnimationFrame(() => {
      const nextCursor = before.length + inserted.length;
      textarea.setSelectionRange(nextCursor, nextCursor);
      textarea.focus();
    });
  }

  function handleKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (!suggestion || matches.length === 0) return;

    if (event.key === "ArrowDown") {
      event.preventDefault();
      setSuggestion((current) =>
        current ? { ...current, activeIndex: (current.activeIndex + 1) % matches.length } : current,
      );
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setSuggestion((current) =>
        current
          ? { ...current, activeIndex: (current.activeIndex - 1 + matches.length) % matches.length }
          : current,
      );
    } else if (event.key === "Tab" || event.key === "Enter") {
      event.preventDefault();
      completeSuggestion(matches[suggestion.activeIndex]);
    } else if (event.key === "Escape") {
      setSuggestion(null);
    }
  }

  return (
    <div className="relative space-y-1">
      <label htmlFor="story-content" className="sr-only">
        Contenu Markdown de l&apos;histoire
      </label>
      <MarkdownToolbar textareaRef={textareaRef} value={content} onChange={onChange} />
      <textarea
        ref={textareaRef}
        id="story-content"
        value={content}
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        onBlur={() => setSuggestion(null)}
        rows={20}
        className="w-full resize-y rounded-b-lg rounded-t-none border border-white/10 bg-background p-4 font-mono text-sm text-foreground focus-visible:border-accent-cyan"
      />

      {suggestion && matches.length > 0 ? (
        <ul
          role="listbox"
          aria-label="Suggestions de mentions Codex"
          style={{ top: suggestion.position.top + 20, left: suggestion.position.left }}
          className="absolute z-20 max-h-48 w-56 overflow-auto rounded-lg border border-white/10 bg-surface py-1 shadow-lg"
        >
          {matches.map((name, index) => (
            <li key={name} role="option" aria-selected={index === suggestion.activeIndex}>
              <button
                type="button"
                onMouseDown={(event) => {
                  event.preventDefault();
                  completeSuggestion(name);
                }}
                className={`block w-full px-3 py-1.5 text-left text-sm ${
                  index === suggestion.activeIndex
                    ? "bg-accent-violet text-white"
                    : "text-foreground hover:bg-background"
                }`}
              >
                {name}
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}
