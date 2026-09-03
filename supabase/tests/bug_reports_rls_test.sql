-- Vérifie la RLS de public.bug_reports (20260903100000_create_bug_reports.sql),
-- table alimentée par l'edge function report-bug (signalement de bug ->
-- issue GitHub, voir supabase/functions/report-bug/). Même méthodologie que
-- supabase/tests/character_campaigns_rls_test.sql : le harnais pgTAP a les
-- pleins pouvoirs (rôle postgres) pour les fixtures, le reste des requêtes
-- passe par `set local role authenticated` + `request.jwt.claims` pour
-- simuler exactement ce que verrait PostgREST pour un utilisateur donné.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- (depuis la racine du dépôt web, stack local démarré au préalable).
-- BEGIN/ROLLBACK en fin de fichier : aucune donnée de test ne persiste, le
-- fichier est rejouable à volonté sans nettoyage manuel ni collision avec
-- des données réelles.

begin;

select plan(6);

-- Fixtures : deux utilisateurs authentifiés (A rapporte un bug, B est un
-- tiers sans relation avec le signalement de A).
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-reporter-a@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('88888888-8888-8888-8888-888888888888', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-reporter-b@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

-- Test 1 : A peut insérer un signalement pour lui-même (reporter_id =
-- auth.uid()) -- c'est le chemin utilisé par l'étape 1 de report-bug.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '77777777-7777-7777-7777-777777777777', 'role', 'authenticated')::text,
  true
);

select lives_ok(
  $$ insert into public.bug_reports (id, reporter_id, title, description, severity)
     values ('cccccccc-0000-0000-0000-000000000001', '77777777-7777-7777-7777-777777777777', 'pgTAP bug', 'Description du bug pgTAP', 'mineur') $$,
  'Un utilisateur authentifié doit pouvoir insérer un bug_reports pour lui-même (reporter_id = auth.uid())'
);

-- Test 2 : A peut relire son propre signalement.
select is(
  (select count(*)::int from public.bug_reports where id = 'cccccccc-0000-0000-0000-000000000001'),
  1,
  'Le rapporteur doit pouvoir relire son propre signalement (policy select reporter_id = auth.uid())'
);

-- Test 3 : A ne peut pas insérer un signalement au nom de B (impersonation).
select throws_ok(
  $$ insert into public.bug_reports (id, reporter_id, title, description, severity)
     values ('cccccccc-0000-0000-0000-000000000002', '88888888-8888-8888-8888-888888888888', 'pgTAP bug impersonation', 'Ne doit jamais passer', 'majeur') $$,
  '42501',
  null,
  'Un utilisateur ne doit jamais pouvoir insérer un bug_reports pour un autre reporter_id (policy insert with check auth.uid() = reporter_id)'
);

-- Test 4 : A ne peut pas modifier son propre signalement (aucune policy
-- update -- RLS activée + aucune policy = deny-all, seule l'edge function
-- via service_role peut faire évoluer status/github_issue_*/error_message).
select throws_ok(
  $$ update public.bug_reports set status = 'synced' where id = 'cccccccc-0000-0000-0000-000000000001' $$,
  '42501',
  null,
  'Aucun client authenticated ne doit pouvoir modifier un bug_reports, même le sien (aucune policy update, seule service_role le peut)'
);

reset role;

-- Test 5 : B ne voit pas le signalement de A.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '88888888-8888-8888-8888-888888888888', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.bug_reports where id = 'cccccccc-0000-0000-0000-000000000001'),
  0,
  'Un tiers (autre reporter_id) ne doit voir aucune ligne bug_reports d''un autre utilisateur'
);

reset role;

-- Test 6 : aucun accès anonyme -- pas de GRANT pour `anon` sur cette table
-- (même politique que le reste du schéma : lecture publique authentifiée au
-- mieux, jamais anonyme, cf. 20260825091100_grant_authenticated_privileges.sql).
set local role anon;

select throws_ok(
  $$ select count(*) from public.bug_reports $$,
  '42501',
  null,
  'Le rôle anon ne doit avoir aucun privilège de table sur bug_reports (permission denied, pas seulement filtré par RLS)'
);

reset role;

select * from finish();

rollback;
