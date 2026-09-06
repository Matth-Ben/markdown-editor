-- Chantier "Notifications push/email" (app mobile "Personnages") —
-- 15-profil-parametres.md section 3.
--
-- `send-rest-reminders` (edge function, chantier suivant) ne doit relancer un
-- même utilisateur qu'une fois tous les 7 jours au maximum, même si le seuil
-- "repos long non pris depuis 7 jours" reste dépassé jour après jour tant que
-- l'utilisateur n'a pas refait de repos long. Ce suivi ne peut reposer sur
-- aucune colonne existante (`characters.last_long_rest_at` décrit le
-- personnage, pas la dernière notification envoyée à son propriétaire, et un
-- même propriétaire peut avoir plusieurs personnages concernés
-- simultanément) — d'où cette colonne sur `notification_preferences`, une
-- ligne par utilisateur, cohérente avec `last_email_digest_sent_at` déjà
-- présente sur la même table pour le même usage côté résumé email
-- (20260906155351_create_notification_infrastructure.sql).
alter table public.notification_preferences
  add column last_rest_reminder_sent_at timestamptz;

comment on column public.notification_preferences.last_rest_reminder_sent_at is
  'Horodatage du dernier rappel de repos long envoyé à cet utilisateur (send-rest-reminders), pour ne pas le relancer plus d''une fois tous les 7 jours tant que le seuil reste dépassé. Null == jamais notifié (traité comme "dû" par send-rest-reminders).';
