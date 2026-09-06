-- Chantier "Notifications push/email" (app mobile "Personnages") —
-- 15-profil-parametres.md section 3.
--
-- Planifie les deux fonctions périodiques via pg_cron (activé par
-- 20260906160300_create_notification_internal_helpers.sql) :
--   - `send-rest-reminders` : quotidien, 10h UTC.
--   - `send-weekly-digest` : hebdomadaire, lundi 9h UTC.
-- Les deux appels passent par `private.invoke_edge_function` (voir cette
-- fonction pour le détail des secrets Vault requis et le comportement en
-- leur absence — aucun échec bloquant, juste un WARNING journalisé et aucun
-- appel HTTP tant qu'ils ne sont pas configurés).
--
-- `cron.schedule(job_name, ...)` avec un nom déjà existant met à jour ce job
-- plutôt que d'échouer (comportement pg_cron >= 1.4) : cette migration reste
-- donc rejouable sans erreur (utile pour `supabase db reset`).
select cron.schedule(
  'send-rest-reminders-daily',
  '0 10 * * *',
  $$select private.invoke_edge_function('send-rest-reminders', '{}'::jsonb);$$
);

select cron.schedule(
  'send-weekly-digest-weekly',
  '0 9 * * 1',
  $$select private.invoke_edge_function('send-weekly-digest', '{}'::jsonb);$$
);
