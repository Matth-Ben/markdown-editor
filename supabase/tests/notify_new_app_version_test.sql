-- Vérifie 20261014100000_notify_new_app_version.sql (et la colonne ajoutée
-- par 20261014090000_add_notification_push_new_version_available.sql) :
-- le trigger sur public.app_versions notifie bien sur INSERT et sur UPDATE
-- avec changement réel de latest_version, reste muet sur un UPDATE sans
-- changement réel (même valeur, ou colonne non touchée), respecte
-- notification_preferences.push_enabled/push_new_version_available (défaut
-- true si absent de ligne), et isole l'échec d'un destinataire du reste du
-- lot (étape 5 -- le `begin/exception` par destinataire dans la boucle de
-- notify_new_app_version()).
--
-- `private.invoke_edge_function` est remplacée ici par un double de test qui
-- capture ses appels dans une table temporaire au lieu de faire un vrai
-- appel réseau (pg_net) -- le `create or replace function` est du DDL
-- transactionnel comme le reste de ce fichier : le `rollback` final restaure
-- la définition réelle (20260906160300_create_notification_internal_helpers.sql)
-- sans qu'aucun nettoyage manuel soit nécessaire. Ce double capture
-- systématiquement, qu'il y ait ou non des secrets Vault configurés sur ce
-- stack -- contrairement à la vraie fonction, il ne dépend donc pas de leur
-- présence pour que ce test soit significatif.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- (depuis la racine du dépôt web, stack local démarré au préalable via
-- `supabase start`).

begin;

select plan(10);

-- ---------------------------------------------------------------------------
-- Double de test de private.invoke_edge_function (voir commentaire d'en-tête)
-- ---------------------------------------------------------------------------
create temporary table captured_invoke_calls (
  function_name text,
  body jsonb
) on commit drop;

create or replace function private.invoke_edge_function(p_function_name text, p_body jsonb)
returns bigint
language plpgsql
as $$
begin
  insert into captured_invoke_calls (function_name, body) values (p_function_name, p_body);
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures : trois utilisateurs pgTAP, préférences distinctes.
--   - userA : aucune ligne notification_preferences -> défauts (true, true),
--     doit être notifié.
--   - userB : push_enabled = false -> jamais notifié, quel que soit
--     push_new_version_available.
--   - userC : push_enabled = true mais push_new_version_available = false ->
--     exclu spécifiquement de CE déclencheur.
-- Insérés en tant que `postgres` (rôle superuser du test runner pgTAP), qui
-- contourne RLS -- même patron que supabase/tests/group_member_without_character_test.sql.
-- ---------------------------------------------------------------------------
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('66660000-6666-6666-6666-666600000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-new-version-a@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('66660000-6666-6666-6666-666600000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-new-version-b@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('66660000-6666-6666-6666-666600000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-new-version-c@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.notification_preferences (user_id, push_enabled, push_new_version_available)
values
  ('66660000-6666-6666-6666-666600000002', false, true),
  ('66660000-6666-6666-6666-666600000003', true, false);

-- ---------------------------------------------------------------------------
-- Étape 1 : INSERT. La ligne 'android' seedée par
-- 20260914090000_create_app_versions.sql est supprimée puis réinsérée (PK =
-- platform) pour déclencher un vrai INSERT plutôt qu'un UPDATE.
-- ---------------------------------------------------------------------------
delete from public.app_versions where platform = 'android';

insert into public.app_versions (platform, min_supported_version, latest_version)
values ('android', '1.0.0', '2.0.0');

select is(
  (select count(*)::int from captured_invoke_calls where body->>'userId' = '66660000-6666-6666-6666-666600000001'),
  1,
  'INSERT sur app_versions doit notifier un utilisateur sans ligne notification_preferences (défauts true/true)'
);

select is(
  (select count(*)::int from captured_invoke_calls where body->>'userId' = '66660000-6666-6666-6666-666600000002'),
  0,
  'INSERT sur app_versions ne doit pas notifier un utilisateur avec push_enabled = false'
);

select is(
  (select count(*)::int from captured_invoke_calls where body->>'userId' = '66660000-6666-6666-6666-666600000003'),
  0,
  'INSERT sur app_versions ne doit pas notifier un utilisateur avec push_new_version_available = false'
);

select ok(
  (
    select body->>'title' = 'Nouvelle version disponible'
      and body->'data'->>'type' = 'new_version'
      and body->'data'->>'platform' = 'android'
      and body->'data'->>'version' = '2.0.0'
    from captured_invoke_calls
    where body->>'userId' = '66660000-6666-6666-6666-666600000001'
  ),
  'Le payload envoyé à send-push-notification doit contenir le titre, type, plateforme et version attendus'
);

-- ---------------------------------------------------------------------------
-- Étape 2 : UPDATE avec changement réel de latest_version -> doit notifier.
-- ---------------------------------------------------------------------------
truncate captured_invoke_calls;

update public.app_versions set latest_version = '2.0.1' where platform = 'android';

select is(
  (
    select body->'data'->>'version'
    from captured_invoke_calls
    where body->>'userId' = '66660000-6666-6666-6666-666600000001'
  ),
  '2.0.1',
  'UPDATE avec changement réel de latest_version doit notifier avec la nouvelle version'
);

-- ---------------------------------------------------------------------------
-- Étape 3 : UPDATE sans changement réel (même valeur réaffectée) -> le
-- trigger se déclenche (latest_version fait partie du SET) mais le garde
-- `old.latest_version is not distinct from new.latest_version` doit stopper
-- la fonction avant toute notification.
-- ---------------------------------------------------------------------------
truncate captured_invoke_calls;

update public.app_versions set latest_version = latest_version where platform = 'android';

select is(
  (select count(*)::int from captured_invoke_calls),
  0,
  'UPDATE qui réaffecte la même valeur à latest_version ne doit notifier personne'
);

-- ---------------------------------------------------------------------------
-- Étape 4 : UPDATE d'une colonne non surveillée (min_supported_version) ->
-- `AFTER UPDATE OF latest_version` ne doit même pas déclencher le trigger.
-- ---------------------------------------------------------------------------
truncate captured_invoke_calls;

update public.app_versions set min_supported_version = '1.0.1' where platform = 'android';

select is(
  (select count(*)::int from captured_invoke_calls),
  0,
  'UPDATE qui ne touche pas latest_version ne doit même pas déclencher le trigger'
);

-- ---------------------------------------------------------------------------
-- Étape 5 : un échec individuel (exception non rattrapée par
-- private.invoke_edge_function elle-même) pour UN destinataire ne doit
-- jamais empêcher les destinataires suivants du même lot d'être notifiés --
-- voir le `begin/exception` par destinataire dans la boucle de
-- notify_new_app_version(). userD (inséré avant userE) est configuré pour
-- faire lever une exception dans le double de test ; userE, inséré après
-- lui, sert à prouver que l'itération se poursuit malgré l'échec de userD.
-- ---------------------------------------------------------------------------
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('66660000-6666-6666-6666-666600000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-new-version-d@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('66660000-6666-6666-6666-666600000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-new-version-e@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

-- Remplace le double par une variante qui simule un échec pour userD
-- spécifiquement (ni prefs ni filtrage en cause -- un pur incident), avant
-- d'insérer dans captured_invoke_calls pour tous les autres.
create or replace function private.invoke_edge_function(p_function_name text, p_body jsonb)
returns bigint
language plpgsql
as $$
begin
  if p_body->>'userId' = '66660000-6666-6666-6666-666600000004' then
    raise exception 'pgtap: échec simulé pour vérifier l''isolation par destinataire';
  end if;
  insert into captured_invoke_calls (function_name, body) values (p_function_name, p_body);
  return null;
end;
$$;

truncate captured_invoke_calls;

update public.app_versions set latest_version = '2.0.2' where platform = 'android';

select is(
  (select count(*)::int from captured_invoke_calls where body->>'userId' = '66660000-6666-6666-6666-666600000004'),
  0,
  'userD (échec simulé) ne doit avoir aucune ligne capturée -- son propre échec ne lui envoie rien, sans surprise'
);

select is(
  (select count(*)::int from captured_invoke_calls where body->>'userId' = '66660000-6666-6666-6666-666600000001'),
  1,
  'userA doit toujours être notifié malgré l''échec simulé sur un autre destinataire du même lot'
);

select is(
  (select count(*)::int from captured_invoke_calls where body->>'userId' = '66660000-6666-6666-6666-666600000005'),
  1,
  'userE (inséré après userD) doit être notifié -- preuve que la boucle se poursuit après l''échec de userD au lieu de s''arrêter net'
);

select * from finish();

rollback;
