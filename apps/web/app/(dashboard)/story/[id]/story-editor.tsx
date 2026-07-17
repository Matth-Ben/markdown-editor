"use client";

import { useActionState, useEffect, useState } from "react";
import { Button, MarkdownContent } from "@nexus/ui";
import { updateStoryContent, type UpdateStoryState } from "./actions";

type Layout = "split" | "tabs";

const LAYOUT_STORAGE_KEY = "nexus:editor-layout";
const initialState: UpdateStoryState = { error: null };

export function StoryEditor({
  storyId,
  initialContent,
}: {
  storyId: string;
  initialContent: string;
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

  return (
    <div className="space-y-4">
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
            <EditorTextarea content={content} onChange={setContent} />
          ) : (
            <div className="prose prose-invert max-w-none rounded-lg border border-white/10 bg-surface p-4">
              <MarkdownContent content={content} />
            </div>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <EditorTextarea content={content} onChange={setContent} />
          <div className="prose prose-invert max-w-none rounded-lg border border-white/10 bg-surface p-4">
            <MarkdownContent content={content} />
          </div>
        </div>
      )}
    </div>
  );
}

function EditorTextarea({
  content,
  onChange,
}: {
  content: string;
  onChange: (value: string) => void;
}) {
  return (
    <div className="space-y-1">
      <label htmlFor="story-content" className="sr-only">
        Contenu Markdown de l&apos;histoire
      </label>
      <textarea
        id="story-content"
        value={content}
        onChange={(event) => onChange(event.target.value)}
        rows={20}
        className="w-full resize-y rounded-lg border border-white/10 bg-background p-4 font-mono text-sm text-foreground focus-visible:border-accent-cyan"
      />
    </div>
  );
}
