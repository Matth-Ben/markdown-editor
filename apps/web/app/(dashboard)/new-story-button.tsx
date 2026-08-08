"use client";

import { useActionState } from "react";
import { Button } from "@nexus/ui";
import { createStory, type CreateStoryState } from "./actions";

const initialState: CreateStoryState = { error: null };

export function NewStoryButton() {
  const [state, formAction, isPending] = useActionState(createStory, initialState);

  return (
    <form action={formAction} className="space-y-2">
      <Button type="submit" isLoading={isPending}>
        {isPending ? "Création…" : "+ Nouveau"}
      </Button>

      <div aria-live="polite">
        {state.error ? (
          <p role="alert" className="text-sm text-red-400">
            {state.error}
          </p>
        ) : null}
      </div>
    </form>
  );
}
