import Link from "next/link";
import { LoginForm } from "./login-form";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-foreground">Connexion</h1>

      {error === "confirmation" ? (
        <p role="alert" className="text-sm text-red-400">
          Le lien utilisé a expiré ou n&apos;est plus valide. Réessaie de te connecter ou de
          demander un nouveau lien.
        </p>
      ) : null}

      <LoginForm />

      <p className="text-sm text-muted">
        <Link href="/reset-password" className="underline underline-offset-4 hover:text-foreground">
          Mot de passe oublié ?
        </Link>
      </p>
      <p className="text-sm text-muted">
        Pas encore de compte ?{" "}
        <Link href="/register" className="underline underline-offset-4 hover:text-foreground">
          Créer un compte
        </Link>
      </p>
    </div>
  );
}
