-- Chantier "Personnages" (app mobile) — GRANT explicite pour `service_role`
-- sur `public.bug_reports`, table lue/écrite par l'edge function
-- `report-bug` (supabase/functions/report-bug/).
--
-- Même constat/pattern que 20260830100200_grant_service_role_join_story.sql :
-- `service_role` n'a, sur ce projet, aucun privilège explicite de table par
-- défaut. report-bug n'utilise le client service_role que pour l'étape 3
-- (mise à jour de status/github_issue_number/github_issue_url/error_message
-- après l'appel à l'API GitHub, hors périmètre de la RLS utilisateur) --
-- l'insertion initiale (étape 1) passe par le client scoped-utilisateur, déjà
-- couvert par le GRANT `authenticated` de
-- 20260903100000_create_bug_reports.sql. On n'accorde donc que `update` ici,
-- au plus près de ce qui est réellement utilisé (même discipline que le
-- commentaire de 20260830100200 sur le principe de moindre privilège).

grant update on table public.bug_reports to service_role;
