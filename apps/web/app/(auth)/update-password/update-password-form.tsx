"use client";

import { useActionState } from "react";
import { Button } from "@nexus/ui";
import { updatePassword, type AuthActionState } from "../actions";

const initialState: AuthActionState = { error: null };

export function UpdatePasswordForm() {
  const [state, formAction, isPending] = useActionState(updatePassword, initialState);

  return (
    <form action={formAction} noValidate className="space-y-4">
      <div className="space-y-1">
        <label htmlFor="password" className="block text-sm text-foreground">
          Nouveau mot de passe
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={6}
          required
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "update-password-error" : "password-hint"}
          className="w-full rounded-lg border border-white/10 bg-surface px-3 py-2 text-foreground focus-visible:border-accent-cyan"
        />
        <p id="password-hint" className="text-xs text-muted">
          6 caractères minimum.
        </p>
      </div>

      <div className="space-y-1">
        <label htmlFor="confirmPassword" className="block text-sm text-foreground">
          Confirmer le nouveau mot de passe
        </label>
        <input
          id="confirmPassword"
          name="confirmPassword"
          type="password"
          autoComplete="new-password"
          minLength={6}
          required
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "update-password-error" : undefined}
          className="w-full rounded-lg border border-white/10 bg-surface px-3 py-2 text-foreground focus-visible:border-accent-cyan"
        />
      </div>

      <div aria-live="polite">
        {state.error ? (
          <p id="update-password-error" role="alert" className="text-sm text-red-400">
            {state.error}
          </p>
        ) : null}
      </div>

      <Button type="submit" isLoading={isPending} className="w-full">
        {isPending ? "Mise à jour…" : "Mettre à jour le mot de passe"}
      </Button>
    </form>
  );
}
