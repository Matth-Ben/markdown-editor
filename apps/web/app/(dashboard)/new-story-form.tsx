"use client";

import { useActionState } from "react";
import { Button } from "@nexus/ui";
import { createStory, type CreateStoryState } from "./actions";

const initialState: CreateStoryState = { error: null };

export function NewStoryForm() {
  const [state, formAction, isPending] = useActionState(createStory, initialState);

  return (
    <form
      action={formAction}
      noValidate
      className="flex flex-wrap items-end gap-4 rounded-lg border border-white/10 bg-surface p-4"
    >
      <div className="min-w-48 flex-1 space-y-1">
        <label htmlFor="title" className="block text-sm text-foreground">
          Titre de l&apos;histoire
        </label>
        <input
          id="title"
          name="title"
          type="text"
          required
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "new-story-error" : undefined}
          className="w-full rounded-lg border border-white/10 bg-background px-3 py-2 text-foreground focus-visible:border-accent-cyan"
        />
      </div>

      <div className="space-y-1">
        <label htmlFor="cover" className="block text-sm text-foreground">
          Couverture (optionnel)
        </label>
        <input id="cover" name="cover" type="file" accept="image/*" className="text-sm text-muted" />
      </div>

      <Button type="submit" isLoading={isPending}>
        {isPending ? "Création…" : "Créer"}
      </Button>

      <div aria-live="polite" className="w-full">
        {state.error ? (
          <p id="new-story-error" role="alert" className="text-sm text-red-400">
            {state.error}
          </p>
        ) : null}
      </div>
    </form>
  );
}
