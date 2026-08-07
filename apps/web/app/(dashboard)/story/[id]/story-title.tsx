"use client";

import { useRef, useState, useTransition, type KeyboardEvent } from "react";
import { updateStoryTitle } from "./actions";

export function StoryTitle({ storyId, title }: { storyId: string; title: string }) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(title);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const inputRef = useRef<HTMLInputElement>(null);

  function startEditing() {
    setValue(title);
    setError(null);
    setEditing(true);
    requestAnimationFrame(() => inputRef.current?.select());
  }

  function cancel() {
    setEditing(false);
    setError(null);
  }

  function save() {
    const trimmed = value.trim();
    if (!trimmed || trimmed === title) {
      setEditing(false);
      return;
    }

    startTransition(async () => {
      const result = await updateStoryTitle(storyId, trimmed);
      if (result.error) {
        setError(result.error);
        return;
      }
      setEditing(false);
    });
  }

  function handleKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Enter") {
      event.preventDefault();
      save();
    } else if (event.key === "Escape") {
      event.preventDefault();
      cancel();
    }
  }

  if (editing) {
    return (
      <div className="min-w-0 flex-1">
        <input
          ref={inputRef}
          value={value}
          onChange={(event) => setValue(event.target.value)}
          onBlur={save}
          onKeyDown={handleKeyDown}
          disabled={isPending}
          autoFocus
          aria-label="Titre de l'histoire"
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? "story-title-error" : undefined}
          className="w-full rounded-lg border border-accent-cyan bg-background px-2 py-1 text-2xl font-semibold text-foreground focus-visible:outline-none"
        />
        {error ? (
          <p id="story-title-error" role="alert" className="mt-1 text-sm text-red-400">
            {error}
          </p>
        ) : null}
      </div>
    );
  }

  return (
    <button
      type="button"
      onClick={startEditing}
      title="Cliquer pour modifier le titre"
      className="max-w-full truncate rounded-lg px-2 py-1 text-left text-2xl font-semibold text-foreground hover:bg-surface"
    >
      {title}
    </button>
  );
}
