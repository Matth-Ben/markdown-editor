import { UpdatePasswordForm } from "./update-password-form";

export default function UpdatePasswordPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold text-foreground">Nouveau mot de passe</h1>
      <UpdatePasswordForm />
    </div>
  );
}
