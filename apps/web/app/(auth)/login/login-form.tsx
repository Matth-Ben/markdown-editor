"use client";

import { useActionState } from "react";
import { Button } from "@nexus/ui";
import { signIn, type AuthActionState } from "../actions";

const initialState: AuthActionState = { error: null };

export function LoginForm() {
  const [state, formAction, isPending] = useActionState(signIn, initialState);

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
          aria-describedby={state.error ? "login-error" : undefined}
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
          autoComplete="current-password"
          required
          aria-invalid={state.error ? true : undefined}
          aria-describedby={state.error ? "login-error" : undefined}
          className="w-full rounded-lg border border-white/10 bg-surface px-3 py-2 text-foreground focus-visible:border-accent-cyan"
        />
      </div>

      <div aria-live="polite">
        {state.error ? (
          <p id="login-error" role="alert" className="text-sm text-red-400">
            {state.error}
          </p>
        ) : null}
      </div>

      <Button type="submit" isLoading={isPending} className="w-full">
        {isPending ? "Connexion…" : "Se connecter"}
      </Button>
    </form>
  );
}
