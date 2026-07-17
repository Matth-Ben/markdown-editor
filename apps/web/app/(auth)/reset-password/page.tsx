import Link from "next/link";
import { ResetPasswordForm } from "./reset-password-form";

export default function ResetPasswordPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-foreground">Mot de passe oublié</h1>
      <ResetPasswordForm />
      <p className="text-sm text-muted">
        <Link href="/login" className="underline underline-offset-4 hover:text-foreground">
          Retour à la connexion
        </Link>
      </p>
    </div>
  );
}
