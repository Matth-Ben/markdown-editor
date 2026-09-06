// Helper générique de fraîcheur temporelle, partagé par les fonctions du
// chantier "Notifications push/email" (send-rest-reminders,
// send-weekly-digest) qui appliquent toutes la même règle : "jamais fait, OU
// plus vieux que N jours" (repos long non pris, dernier rappel envoyé,
// dernier résumé email envoyé). Volontairement générique (pas de nom lié à
// un cas d'usage précis) pour éviter trois copies quasi identiques de la
// même comparaison de dates.

/** Vrai si `iso` est absent/vide/invalide, ou représente une date antérieure
 * à `now - days` jours. `now` est un paramètre (pas `new Date()` implicite)
 * pour que les appelants -- et leurs tests -- restent déterministes. */
export function isOlderThanDays(
  iso: string | null | undefined,
  days: number,
  now: Date = new Date(),
): boolean {
  if (!iso) return true;

  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return true;

  const thresholdMs = days * 24 * 60 * 60 * 1000;
  return now.getTime() - date.getTime() >= thresholdMs;
}
