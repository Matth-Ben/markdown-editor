-- Chantier "Notifications push/email" (app mobile "Personnages") —
-- notifier les joueurs quand une nouvelle version de l'app devient
-- disponible (voir la migration suivante, 20261014100000, pour le trigger
-- lui-même).
--
-- Ajoute la préférence correspondante à notification_preferences, même
-- convention exacte que push_rest_reminder/push_access_revoked déjà
-- présentes (20260906155351_create_notification_infrastructure.sql) :
-- colonne booléenne, défaut `true` (opt-out, pas opt-in) — absence de ligne
-- notification_preferences == valeurs par défaut, comme pour les deux
-- autres déclencheurs.
alter table public.notification_preferences
  add column push_new_version_available boolean not null default true;

comment on column public.notification_preferences.push_new_version_available is
  'Opt-out (défaut true) de la notification push envoyée quand une nouvelle version de l''app mobile devient disponible (public.app_versions.latest_version) — voir notify_new_app_version().';
