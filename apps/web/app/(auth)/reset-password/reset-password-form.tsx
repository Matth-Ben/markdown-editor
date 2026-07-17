"use client";

import { useActionState } from "react";
import { Button } from "@nexus/ui";
import { requestPasswordReset, type AuthActionState } from "../actions";

const initialState: AuthActionState = { error: null };

export function ResetPasswordForm() {
  const [state, formAction, isPending] = useActionState(requestPasswordReset, initialState);

  if (state.success) {
    return (
      <p role="status" className="text-sm text-foreground">
        Si un compte existe avec cet email, un lien de réinitialisation vient de lui être
        envoyé.
      </p>
    );
  }

  return (
    <form action={formAction} noValidate className="space-y-4">
      <div className="space-y-1">
        <label htmlFor="email" className="block text-sm text-foreground">
          Email
        </label>
        <input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "reset-error" : undefined}
          className="w-full rounded-lg border border-white/10 bg-surface px-3 py-2 text-foreground focus-visible:border-accent-cyan"
        />
      </div>

      <div aria-live="polite">
        {state.error ? (
          <p id="reset-error" role="alert" className="text-sm text-red-400">
            {state.error}
          </p>
        ) : null}
      </div>

      <Button type="submit" isLoading={isPending} className="w-full">
        {isPending ? "Envoi…" : "Envoyer le lien de réinitialisation"}
      </Button>
    </form>
  );
}
