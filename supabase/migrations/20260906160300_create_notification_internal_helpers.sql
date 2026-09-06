-- Chantier "Notifications push/email" (app mobile "Personnages") —
-- 15-profil-parametres.md section 3.
--
-- Socle technique pour déclencher des edge functions depuis Postgres, dans
-- les deux cas de ce chantier : un trigger AFTER DELETE (retrait d'accès MJ,
-- migration suivante) et deux jobs pg_cron (rappels de repos / résumé email,
-- migration après celle du trigger).
--
-- `pg_net` est déjà activé sur ce projet (constaté sur le stack local — voir
-- `select * from pg_extension where extname = 'pg_net'`, schéma
-- `extensions`) ; `create extension if not exists` reste idempotent si ce
-- n'était pas déjà le cas sur un autre environnement.
create extension if not exists pg_net with schema extensions;

-- `pg_cron` n'a en revanche jamais été utilisé dans ce dépôt jusqu'ici.
create extension if not exists pg_cron with schema extensions;

-- Schéma dédié aux fonctions internes, jamais exposées via PostgREST
-- (absent de `supabase/config.toml` -> `[api].schemas`, qui ne liste que
-- `public`/`graphql_public`) — défense en profondeur en plus de l'absence de
-- GRANT EXECUTE à `anon`/`authenticated` sur ces fonctions.
create schema if not exists private;

comment on schema private is
  'Fonctions internes (triggers, jobs pg_cron) non exposées via PostgREST. Jamais de GRANT à anon/authenticated ici.';

-- ---------------------------------------------------------------------------
-- Secrets nécessaires à `private.invoke_edge_function` — À CONFIGURER
-- MANUELLEMENT PAR L'UTILISATEUR, séparément sur le stack local ET sur le
-- projet distant `nexus-jdr`, via Supabase Vault (jamais en dur dans une
-- migration : la clé service_role et l'URL des fonctions diffèrent par
-- environnement, et la clé service_role ne doit jamais transiter par
-- l'historique git). Tant que ces deux secrets Vault n'existent pas,
-- `private.invoke_edge_function` journalise un WARNING et renvoie `null`
-- sans lever d'erreur — le trigger/les jobs cron qui l'appellent restent
-- donc sans effet (pas de notification envoyée) mais ne bloquent jamais
-- l'opération SQL qui les a déclenchés (DELETE, cron). Commandes à exécuter
-- une fois par environnement (SQL Editor du Dashboard, ou psql local) :
--
--   select vault.create_secret(
--     '<clé service_role de CET environnement>',
--     'service_role_key',
--     'Clé service_role utilisée par les triggers/jobs pg_cron internes pour appeler les edge functions (send-push-notification, send-rest-reminders, send-weekly-digest).'
--   );
--
--   -- Local (voir `supabase status` -> API URL, jamais accessible tel quel
--   -- depuis le conteneur Postgres -> passer par Kong, atteignable depuis
--   -- le réseau docker interne) :
--   select vault.create_secret(
--     'http://kong:8000/functions/v1',
--     'project_functions_url',
--     'Base URL des edge functions, sans slash final, pour cet environnement.'
--   );
--   -- Distant (remplacer <project-ref>) :
--   -- select vault.create_secret('https://<project-ref>.supabase.co/functions/v1', 'project_functions_url', '...');
--
-- Pour mettre à jour un secret déjà créé : `select vault.update_secret(id, new_value)`
-- (id visible via `select id, name from vault.secrets`).
-- ---------------------------------------------------------------------------

create or replace function private.get_service_role_key()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key' limit 1;
$$;

create or replace function private.get_functions_base_url()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'project_functions_url' limit 1;
$$;

-- Point d'entrée unique pour tout appel HTTP interne vers une edge function
-- de ce projet, utilisé par le trigger `character_campaigns` (retrait
-- d'accès) et par les jobs pg_cron (rappels de repos, résumé hebdomadaire).
-- Ne lève jamais : toute erreur (secrets absents, échec pg_net) est
-- journalisée en WARNING et renvoie `null`, pour ne jamais faire échouer
-- l'opération SQL appelante (DELETE, job cron) à cause d'un problème du
-- système de notification — même philosophie que le "best effort" de
-- `report-bug` (supabase/functions/report-bug/index.ts) côté edge function.
create or replace function private.invoke_edge_function(p_function_name text, p_body jsonb)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_service_role_key text := private.get_service_role_key();
  v_base_url text := private.get_functions_base_url();
  v_request_id bigint;
begin
  if v_service_role_key is null or v_base_url is null then
    raise warning 'private.invoke_edge_function(%): secrets Vault "service_role_key"/"project_functions_url" non configurés — appel ignoré.', p_function_name;
    return null;
  end if;

  select net.http_post(
    url := v_base_url || '/' || p_function_name,
    body := p_body,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    timeout_milliseconds := 5000
  ) into v_request_id;

  return v_request_id;
exception when others then
  raise warning 'private.invoke_edge_function(%): erreur pg_net (%): %', p_function_name, sqlstate, sqlerrm;
  return null;
end;
$$;

comment on function private.invoke_edge_function(text, jsonb) is
  'Appelle POST {project_functions_url}/{p_function_name} avec le corps p_body et un header Authorization: Bearer <service_role_key> (secrets lus depuis Supabase Vault, voir commentaire plus haut). Ne lève jamais — renvoie null (et journalise un WARNING) si les secrets sont absents ou si pg_net échoue, pour ne jamais faire échouer l''opération SQL appelante.';
