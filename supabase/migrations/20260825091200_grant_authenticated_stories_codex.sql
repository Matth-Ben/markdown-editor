-- Complète 20260825091100_grant_authenticated_privileges.sql : les tables
-- `stories`/`codex_entries` (créées par 20260716212008_create_stories.sql et
-- 20260721214647_create_codex_entries.sql, avant le chantier "Personnages")
-- n'ont jamais reçu de GRANT explicite pour `authenticated` non plus.
--
-- Comme pour les tables de Phase 1, un `supabase db reset` local frais
-- renvoie "permission denied for table stories/codex_entries" au rôle
-- `authenticated` sans ce GRANT — avant même que RLS n'intervienne. Que ça
-- fonctionne aujourd'hui sur le projet distant `nexus-jdr` tient probablement
-- à un privilège par défaut hérité de l'ancien comportement de la plateforme
-- (voir `auto_expose_new_tables` dans supabase/config.toml), pas vérifié
-- faute d'accès direct (CLI non liée, pas de clé service_role locale). Cette
-- migration ne dépend pas de cette hypothèse : GRANT est idempotent, donc
-- sans effet si le privilège existait déjà, et corrige le cas contraire.
--
-- Seul `authenticated` reçoit des privilèges, cohérent avec les policies RLS
-- existantes (auth.uid() = user_id) : aucun accès anonyme n'est prévu pour
-- ces tables.

grant select, insert, update, delete on table
  public.stories,
  public.codex_entries
to authenticated;
