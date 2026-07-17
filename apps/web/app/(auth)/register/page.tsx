import Link from "next/link";
import { RegisterForm } from "./register-form";

export default function RegisterPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-foreground">Créer un compte</h1>
      <RegisterForm />
      <p className="text-sm text-muted">
        Déjà un compte ?{" "}
        <Link href="/login" className="underline underline-offset-4 hover:text-foreground">
          Se connecter
        </Link>
      </p>
    </div>
  );
}
