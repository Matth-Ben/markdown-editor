"use client";

import { useActionState } from "react";
import { Button } from "@nexus/ui";
import { signUp, type AuthActionState } from "../actions";

const initialState: AuthActionState = { error: null };

export function RegisterForm() {
  const [state, formAction, isPending] = useActionState(signUp, initialState);

  if (state.success) {
    return (
      <p role="status" className="text-sm text-foreground">
        Un email de confirmation vient de t&apos;être envoyé. Clique sur le lien qu&apos;il
        contient pour activer ton compte.
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
          aria-describedby={state.error ? "register-error" : undefined}
          className="w-full rounded-lg border border-white/10 bg-surface px-3 py-2 text-foreground focus-visible:border-accent-cyan"
        />
      </div>

      <div className="space-y-1">
        <label htmlFor="password" className="block text-sm text-foreground">
          Mot de passe
        </label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={6}
          required
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "register-error" : "password-hint"}
          className="w-full rounded-lg border border-white/10 bg-surface px-3 py-2 text-foreground focus-visible:border-accent-cyan"
        />
        <p id="password-hint" className="text-xs text-muted">
          6 caractères minimum.
        </p>
      </div>

      <div className="space-y-1">
        <label htmlFor="confirmPassword" className="block text-sm text-foreground">
          Confirmer le mot de passe
        </label>
        <input
          id="confirmPassword"
          name="confirmPassword"
          type="password"
          autoComplete="new-password"
          minLength={6}
          required
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "register-error" : undefined}
          className="w-full rounded-lg border border-white/10 bg-surface px-3 py-2 text-foreground focus-visible:border-accent-cyan"
        />
      </div>

      <div aria-live="polite">
        {state.error ? (
          <p id="register-error" role="alert" className="text-sm text-red-400">
            {state.error}
          </p>
        ) : null}
      </div>

      <Button type="submit" isLoading={isPending} className="w-full">
        {isPending ? "Création…" : "Créer mon compte"}
      </Button>
    </form>
  );
}
