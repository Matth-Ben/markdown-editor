-- Tests de 20261119090000_become_group_game_master_and_combat_active_guard.sql : « Devenir MJ du groupe » (A) et refus du
-- départ du propriétaire et de la dissolution du groupe pendant un combat actif (B). Même patron que
-- group_combats_rls_test.sql.
--
-- Couvre : droits, search_path et triggers ; A : anon, sans session, tiers, groupe inconnu, membre non propriétaire,
-- propriétaire parti (not_member), autre MJ déjà présent (mj_already_assigned, puis succès après son exclusion), combat actif
-- (état reconstruit : impossible par les RPC), succès (même ligne, personnage conservé, historique de combat et note
-- conservés, coéquipier qui ne lit plus le personnage), idempotence sans écriture (xmin) y compris pendant un combat,
-- start_combat possible ensuite, propriétaire orphelin ; B : départ et dissolution refusés pendant un combat actif
-- (authenticated, service_role, postgres), membres non propriétaires libres pendant le combat, départ et dissolution acceptés
-- après la fin du combat ou sans combat (cascades complètes, propriétaire seul), suppression du compte d'un propriétaire en
-- plein combat acceptée, dans les deux ordres possibles des cascades depuis auth.users.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- BEGIN/ROLLBACK : rejouable, aucune donnée ne persiste.

begin;

select plan(65);

-- Fixtures (insérées en tant que postgres, qui contourne RLS) ---------------------------------------------------------------
-- u01 Olga : propriétaire de G1, y joue C01          u02 Bran : membre de G1 (C02), de G2 et de G5
-- u03 : tiers sans relation                          u04 Cyra : membre de G1 (C04)
-- u05 : propriétaire MJ de G2 (jamais de combat)     u06 : propriétaire MJ de G3, seul dans son groupe
-- u07 : propriétaire de G4, y joue C07               u08 : membre NON propriétaire de G4, MJ sans personnage (join-group)
-- u09 : propriétaire de G5 sans ligne de membre      u10 : propriétaire orphelin de G6 (personnage supprimé)
-- u11 : propriétaire MJ de G7                        u12 Eryn : membre de G7 (C12)
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select ('f1000000-0000-4000-8000-0000000000' || n)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'pgtap-devenir-mj-' || n || '@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
  from (values ('01'), ('02'), ('03'), ('04'), ('05'), ('06'), ('07'), ('08'), ('09'), ('10'), ('11'), ('12')) v(n);

insert into public.groups (id, name, owner_id, invite_code)
values
  ('f2000000-0000-4000-8000-000000000001', 'pgTAP devenir MJ 1 (propriétaire joueur)', 'f1000000-0000-4000-8000-000000000001', 'PGTAPDM1'),
  ('f2000000-0000-4000-8000-000000000002', 'pgTAP devenir MJ 2 (sans combat)', 'f1000000-0000-4000-8000-000000000005', 'PGTAPDM2'),
  ('f2000000-0000-4000-8000-000000000003', 'pgTAP devenir MJ 3 (MJ seul)', 'f1000000-0000-4000-8000-000000000006', 'PGTAPDM3'),
  ('f2000000-0000-4000-8000-000000000004', 'pgTAP devenir MJ 4 (autre MJ)', 'f1000000-0000-4000-8000-000000000007', 'PGTAPDM4'),
  ('f2000000-0000-4000-8000-000000000005', 'pgTAP devenir MJ 5 (propriétaire parti)', 'f1000000-0000-4000-8000-000000000009', 'PGTAPDM5'),
  ('f2000000-0000-4000-8000-000000000006', 'pgTAP devenir MJ 6 (propriétaire orphelin)', 'f1000000-0000-4000-8000-000000000010', 'PGTAPDM6'),
  ('f2000000-0000-4000-8000-000000000007', 'pgTAP devenir MJ 7 (suppression de compte)', 'f1000000-0000-4000-8000-000000000011', 'PGTAPDM7');

insert into public.characters (id, owner_id, name)
values
  ('f3000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Olga'),
  ('f3000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000002', 'Bran'),
  ('f3000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000004', 'Cyra'),
  ('f3000000-0000-4000-8000-000000000007', 'f1000000-0000-4000-8000-000000000007', 'Dorn'),
  ('f3000000-0000-4000-8000-000000000010', 'f1000000-0000-4000-8000-000000000010', 'Fael'),
  ('f3000000-0000-4000-8000-000000000012', 'f1000000-0000-4000-8000-000000000012', 'Eryn');

-- joined_at explicites et distincts dans G1 : l'ordre des PJ au lancement en dépend.
insert into public.group_members (group_id, character_id, user_id, role, is_game_master, joined_at)
values
  ('f2000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'owner', false, now() - interval '3 hours'),
  ('f2000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000002', 'membre', false, now() - interval '2 hours'),
  ('f2000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000004', 'f1000000-0000-4000-8000-000000000004', 'membre', false, now() - interval '1 hour'),
  ('f2000000-0000-4000-8000-000000000002', null, 'f1000000-0000-4000-8000-000000000005', 'owner', true, now()),
  ('f2000000-0000-4000-8000-000000000002', 'f3000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000002', 'membre', false, now()),
  ('f2000000-0000-4000-8000-000000000003', null, 'f1000000-0000-4000-8000-000000000006', 'owner', true, now()),
  ('f2000000-0000-4000-8000-000000000004', 'f3000000-0000-4000-8000-000000000007', 'f1000000-0000-4000-8000-000000000007', 'owner', false, now()),
  ('f2000000-0000-4000-8000-000000000004', null, 'f1000000-0000-4000-8000-000000000008', 'membre', true, now()),
  ('f2000000-0000-4000-8000-000000000005', 'f3000000-0000-4000-8000-000000000002', 'f1000000-0000-4000-8000-000000000002', 'membre', false, now()),
  ('f2000000-0000-4000-8000-000000000006', 'f3000000-0000-4000-8000-000000000010', 'f1000000-0000-4000-8000-000000000010', 'owner', false, now()),
  ('f2000000-0000-4000-8000-000000000007', null, 'f1000000-0000-4000-8000-000000000011', 'owner', true, now()),
  ('f2000000-0000-4000-8000-000000000007', 'f3000000-0000-4000-8000-000000000012', 'f1000000-0000-4000-8000-000000000012', 'membre', false, now());

-- G6 : le personnage du propriétaire est supprimé, sa ligne devient orpheline (20261016090000).
delete from public.characters where id = 'f3000000-0000-4000-8000-000000000010';

-- Carnet et journal personnels d'Olga dans G1 (doivent survivre à « devenir MJ »).
insert into public.group_notes (group_id, character_id, user_id, body)
values ('f2000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Note d''Olga');
insert into public.group_journal_entries (group_id, user_id, title, body)
values ('f2000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'Session 1', 'Entrée d''Olga');

-- Contexte partagé (identifiants), lisible par tous les rôles.
create temp table ctx (k text primary key, v uuid);
grant all on ctx to public;

-- Schéma et droits -------------------------------------------------------------------------------------------------------------

select ok(
  has_function_privilege('authenticated', 'public.become_group_game_master(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.become_group_game_master(uuid)', 'execute'),
  'become_group_game_master : authenticated oui, anon non'
);
select is(
  (select count(*)::int from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
    where p.oid = 'public.become_group_game_master(uuid)'::regprocedure and x.grantee = 0),
  0,
  'become_group_game_master : PUBLIC sans EXECUTE'
);
select is(
  (select count(*)::int from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('group_assert_no_active_combat', 'on_group_delete_combat_guard', 'on_group_member_delete_combat_guard')
      and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))),
  0,
  'Contrôle partagé et fonctions de trigger inaccessibles aux clients'
);
select is(
  (select count(*)::int from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prosecdef
      and p.proname in ('become_group_game_master', 'group_assert_no_active_combat', 'on_group_delete_combat_guard', 'on_group_member_delete_combat_guard')
      and p.proconfig = array['search_path=public, pg_temp']),
  4,
  'Les 4 fonctions security definer fixent search_path = public, pg_temp'
);
select is(
  (select count(*)::int from pg_trigger
    where not tgisinternal and tgenabled = 'O'
      and ((tgname = 'groups_before_delete_combat_guard' and tgrelid = 'public.groups'::regclass)
        or (tgname = 'group_members_before_delete_combat_guard' and tgrelid = 'public.group_members'::regclass))),
  2,
  'Les deux triggers BEFORE DELETE sont en place et actifs'
);

-- A. Devenir MJ : refus ------------------------------------------------------------------------------------------------------

set local role anon;
select set_config('request.jwt.claims', '', true);
select throws_ok(
  $$ select public.become_group_game_master('f2000000-0000-4000-8000-000000000001') $$,
  '42501', 'permission denied for function become_group_game_master',
  'Anonyme : appel refusé'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$ select public.become_group_game_master('f2000000-0000-4000-8000-000000000001') $$,
  '28000', 'not_authenticated',
  'Sans utilisateur : not_authenticated'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000003', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.become_group_game_master('f2000000-0000-4000-8000-000000000001') $$,
  'P0002', 'group_not_found',
  'Tiers sans relation : group_not_found (le groupe n''est pas révélé)'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.become_group_game_master('f2000000-0000-4000-8000-0000000000ff') $$,
  'P0002', 'group_not_found',
  'Groupe inconnu : group_not_found'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000002', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.become_group_game_master('f2000000-0000-4000-8000-000000000001') $$,
  '42501', 'not_group_owner',
  'Membre non propriétaire : not_group_owner'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000009', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.become_group_game_master('f2000000-0000-4000-8000-000000000005') $$,
  'P0002', 'not_member',
  'Propriétaire sans ligne de membre (parti) : not_member'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000007', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.become_group_game_master('f2000000-0000-4000-8000-000000000004') $$,
  'P0001', 'mj_already_assigned',
  'Un autre membre est déjà MJ sans personnage : mj_already_assigned'
);
reset role;
select is(
  (select character_id::text || '/' || is_game_master::text from public.group_members
    where group_id = 'f2000000-0000-4000-8000-000000000004' and user_id = 'f1000000-0000-4000-8000-000000000007'),
  'f3000000-0000-4000-8000-000000000007/false',
  'mj_already_assigned : la ligne du propriétaire n''est pas modifiée'
);

-- Le problème résolu : un propriétaire qui joue ne peut pas lancer de combat.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.start_combat('f2000000-0000-4000-8000-000000000001') $$,
  'P0001', 'no_game_master',
  'Avant : le propriétaire joueur ne peut pas lancer de combat (no_game_master)'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000002', 'role', 'authenticated')::text, true);
select is(
  (select count(*)::int from public.characters where id = 'f3000000-0000-4000-8000-000000000001'),
  1,
  'Avant : un coéquipier lit le personnage du propriétaire (partagé avec le groupe)'
);
reset role;

-- Combat actif alors que le propriétaire joue : impossible par les RPC (start_combat exige un MJ), reconstruit en direct
-- pour éprouver le garde-fou (données antérieures, futur chemin d'écriture). Le PJ d'Olga y participe.
insert into public.combats (group_id, started_by)
values ('f2000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001');
insert into ctx select 'legacy', id from public.combats where group_id = 'f2000000-0000-4000-8000-000000000001' and status = 'active';
insert into public.combat_participants (combat_id, group_id, character_id, user_id, name, kind, initiative, sort_order)
values ((select v from ctx where k = 'legacy'), 'f2000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000001',
        'f1000000-0000-4000-8000-000000000001', 'Olga', 'pc', 14, 1);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.become_group_game_master('f2000000-0000-4000-8000-000000000001') $$,
  'P0001', 'combat_active',
  'Combat actif : devenir MJ refusé (combat_active)'
);
reset role;
select is(
  (select character_id::text || '/' || is_game_master::text from public.group_members
    where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000001'),
  'f3000000-0000-4000-8000-000000000001/false',
  'combat_active : la ligne du propriétaire n''est pas modifiée'
);

-- Fin du combat reconstruit : il reste dans l'historique.
update public.combats set status = 'ended', ended_at = now() where id = (select v from ctx where k = 'legacy');

-- A. Devenir MJ : succès ------------------------------------------------------------------------------------------------------

create temp table owner_before as
  select id, joined_at from public.group_members
   where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000001';
grant all on owner_before to public;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select is(
  (select coalesce(character_id::text, 'null') || '/' || is_game_master::text || '/' || role
     from public.become_group_game_master('f2000000-0000-4000-8000-000000000001')),
  'null/true/owner',
  'Le propriétaire qui jouait devient MJ sans personnage (ligne renvoyée)'
);
select is(
  (select count(*)::int from public.characters where id = 'f3000000-0000-4000-8000-000000000001'),
  1,
  'Le propriétaire lit toujours son personnage'
);
reset role;

select is(
  (select count(*)::int from public.group_members m join owner_before b on b.id = m.id and b.joined_at = m.joined_at
    where m.group_id = 'f2000000-0000-4000-8000-000000000001' and m.user_id = 'f1000000-0000-4000-8000-000000000001'
      and m.character_id is null and m.is_game_master and m.role = 'owner'),
  1,
  'Même ligne de membre (id, joined_at, role inchangés), passée en MJ sans personnage'
);
select is(
  (select count(*)::int from public.characters
    where id = 'f3000000-0000-4000-8000-000000000001' and owner_id = 'f1000000-0000-4000-8000-000000000001'),
  1,
  'Le personnage existe toujours dans la liste de son propriétaire'
);
select is(
  (select count(*)::int from public.combat_participants
    where combat_id = (select v from ctx where k = 'legacy') and character_id = 'f3000000-0000-4000-8000-000000000001'),
  1,
  'Historique : la ligne du personnage dans le combat terminé est conservée'
);
select is(
  (select character_id from public.group_notes
    where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000001'),
  'f3000000-0000-4000-8000-000000000001'::uuid,
  'Le carnet de notes du propriétaire est conservé tel quel'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000002', 'role', 'authenticated')::text, true);
select is(
  (select count(*)::int from public.characters where id = 'f3000000-0000-4000-8000-000000000001'),
  0,
  'Le personnage a quitté le groupe : un coéquipier ne le lit plus'
);
reset role;

-- Idempotence : aucune écriture (xmin de la ligne inchangé), même ligne renvoyée.
create temp table row_before as
  select to_jsonb(m) as j, m.xmin::text as x from public.group_members m
   where m.group_id = 'f2000000-0000-4000-8000-000000000001' and m.user_id = 'f1000000-0000-4000-8000-000000000001';
grant all on row_before to public;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select is(
  (select to_jsonb(r) from public.become_group_game_master('f2000000-0000-4000-8000-000000000001') r),
  (select j from row_before),
  'Idempotent : déjà MJ sans personnage, la même ligne est renvoyée'
);
reset role;
select is(
  (select m.xmin::text from public.group_members m
    where m.group_id = 'f2000000-0000-4000-8000-000000000001' and m.user_id = 'f1000000-0000-4000-8000-000000000001'),
  (select x from row_before),
  'Idempotent : aucune écriture (xmin inchangé)'
);

-- Après être devenu MJ, le combat est possible ; le MJ n'y a pas de ligne PJ.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ select public.start_combat('f2000000-0000-4000-8000-000000000001') $$,
  'Après être devenu MJ, le propriétaire peut lancer un combat'
);
reset role;
insert into ctx select 'active', id from public.combats where group_id = 'f2000000-0000-4000-8000-000000000001' and status = 'active';
select is(
  (select string_agg(name, ',' order by sort_order) from public.combat_participants where combat_id = (select v from ctx where k = 'active')),
  'Bran,Cyra',
  'Combat lancé : une ligne PJ par joueur, aucune pour le MJ'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select is(
  (select coalesce(character_id::text, 'null') || '/' || is_game_master::text
     from public.become_group_game_master('f2000000-0000-4000-8000-000000000001')),
  'null/true',
  'Idempotent pendant un combat actif : déjà MJ, rien ne change, pas de refus'
);
reset role;

-- Propriétaire orphelin (personnage supprimé) : il peut devenir MJ.
select is(
  (select coalesce(character_id::text, 'null') || '/' || is_game_master::text from public.group_members
    where group_id = 'f2000000-0000-4000-8000-000000000006'),
  'null/false',
  'Avant : le propriétaire de G6 est orphelin (personnage supprimé)'
);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000010', 'role', 'authenticated')::text, true);
select is(
  (select coalesce(character_id::text, 'null') || '/' || is_game_master::text || '/' || role
     from public.become_group_game_master('f2000000-0000-4000-8000-000000000006')),
  'null/true/owner',
  'Propriétaire orphelin : devient MJ'
);
reset role;

-- Autre MJ : après l'avoir exclu, le propriétaire peut devenir MJ.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000007', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ delete from public.group_members
      where group_id = 'f2000000-0000-4000-8000-000000000004' and user_id = 'f1000000-0000-4000-8000-000000000008' $$,
  'Le propriétaire exclut l''autre MJ (non propriétaire)'
);
select is(
  (select coalesce(character_id::text, 'null') || '/' || is_game_master::text
     from public.become_group_game_master('f2000000-0000-4000-8000-000000000004')),
  'null/true',
  'Une fois l''autre MJ exclu, le propriétaire devient MJ'
);
reset role;
select is(
  (select count(*)::int from public.characters where id = 'f3000000-0000-4000-8000-000000000007'),
  1,
  'Le personnage du propriétaire de G4 est conservé'
);

-- B. Combat actif dans G1 : ni départ du propriétaire, ni dissolution -------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ delete from public.group_members
      where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000001' $$,
  'P0001', 'combat_active',
  'Combat actif : le propriétaire ne peut pas quitter le groupe'
);
select throws_ok(
  $$ delete from public.groups where id = 'f2000000-0000-4000-8000-000000000001' $$,
  'P0001', 'combat_active',
  'Combat actif : le propriétaire ne peut pas dissoudre le groupe'
);
reset role;

set local role service_role;
select throws_ok(
  $$ delete from public.group_members
      where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000001' $$,
  'P0001', 'combat_active',
  'Combat actif : service_role ne peut pas non plus retirer le propriétaire'
);
select throws_ok(
  $$ delete from public.groups where id = 'f2000000-0000-4000-8000-000000000001' $$,
  'P0001', 'combat_active',
  'Combat actif : service_role ne peut pas non plus dissoudre le groupe'
);
reset role;

select throws_ok(
  $$ delete from public.groups where id = 'f2000000-0000-4000-8000-000000000001' $$,
  'P0001', 'combat_active',
  'Combat actif : refus même pour le rôle postgres (propriétaire des tables)'
);
select is(
  (select count(*)::int from public.group_members
    where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000001')::text
  || '/' || (select count(*)::int from public.groups where id = 'f2000000-0000-4000-8000-000000000001')::text
  || '/' || (select count(*)::int from public.combats where group_id = 'f2000000-0000-4000-8000-000000000001' and status = 'active')::text,
  '1/1/1',
  'Après les refus : propriétaire toujours membre, groupe et combat actif intacts'
);

-- Les autres membres restent libres pendant le combat.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ delete from public.group_members
      where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000004' $$,
  'Combat actif : le propriétaire peut toujours exclure un membre'
);
reset role;
select is(
  (select status from public.combat_participants
    where combat_id = (select v from ctx where k = 'active') and user_id = 'f1000000-0000-4000-8000-000000000004'),
  'removed',
  'Le membre exclu est retiré du combat (trigger de départ de la PR #47 inchangé)'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000002', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ delete from public.group_members
      where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000002' $$,
  'Combat actif : un membre non propriétaire peut quitter le groupe'
);
reset role;
select is(
  (select count(*)::int from public.group_members
    where group_id = 'f2000000-0000-4000-8000-000000000001' and user_id = 'f1000000-0000-4000-8000-000000000002')::text
  || '/' || (select status from public.combat_participants
              where combat_id = (select v from ctx where k = 'active') and user_id = 'f1000000-0000-4000-8000-000000000002'),
  '0/removed',
  'Le membre parti n''est plus dans le groupe et sa ligne PJ est retirée'
);

-- Fin du combat : la dissolution passe, avec toutes ses cascades.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select is(
  (select status from public.end_combat((select v from ctx where k = 'active'))),
  'ended',
  'Le MJ termine le combat'
);
select lives_ok(
  $$ delete from public.groups where id = 'f2000000-0000-4000-8000-000000000001' $$,
  'Combats terminés : le propriétaire (toujours membre) dissout le groupe'
);
reset role;
select is(
  (select count(*)::int from public.groups where id = 'f2000000-0000-4000-8000-000000000001')
  + (select count(*)::int from public.group_members where group_id = 'f2000000-0000-4000-8000-000000000001')
  + (select count(*)::int from public.group_treasure where group_id = 'f2000000-0000-4000-8000-000000000001')
  + (select count(*)::int from public.group_notes where group_id = 'f2000000-0000-4000-8000-000000000001')
  + (select count(*)::int from public.group_journal_entries where group_id = 'f2000000-0000-4000-8000-000000000001')
  + (select count(*)::int from public.combats where group_id = 'f2000000-0000-4000-8000-000000000001')
  + (select count(*)::int from public.combat_participants where group_id = 'f2000000-0000-4000-8000-000000000001'),
  0,
  'Dissolution : groupe, membres, trésor, notes, journal, combats et participants supprimés en cascade'
);
select is(
  (select count(*)::int from public.characters
    where id in ('f3000000-0000-4000-8000-000000000001', 'f3000000-0000-4000-8000-000000000002', 'f3000000-0000-4000-8000-000000000004')),
  3,
  'Dissolution : les personnages des joueurs ne sont pas touchés'
);

-- G2 : aucun combat, dissolution directe (cascade de la ligne du propriétaire et d'un membre).
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000005', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ delete from public.groups where id = 'f2000000-0000-4000-8000-000000000002' $$,
  'Sans aucun combat : le propriétaire dissout le groupe'
);
reset role;
select is(
  (select count(*)::int from public.groups where id = 'f2000000-0000-4000-8000-000000000002')
  + (select count(*)::int from public.group_members where group_id = 'f2000000-0000-4000-8000-000000000002'),
  0,
  'Sans combat : groupe et membres (propriétaire compris) supprimés'
);

-- G3 : propriétaire MJ seul, combat actif puis terminé.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000006', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ select public.start_combat('f2000000-0000-4000-8000-000000000003') $$,
  'Propriétaire seul : lance un combat'
);
select throws_ok(
  $$ delete from public.group_members
      where group_id = 'f2000000-0000-4000-8000-000000000003' and user_id = 'f1000000-0000-4000-8000-000000000006' $$,
  'P0001', 'combat_active',
  'Propriétaire seul, combat actif : départ refusé'
);
select lives_ok(
  $$ select public.end_combat((select id from public.combats where group_id = 'f2000000-0000-4000-8000-000000000003' and status = 'active')) $$,
  'Propriétaire seul : termine le combat'
);
select lives_ok(
  $$ delete from public.group_members
      where group_id = 'f2000000-0000-4000-8000-000000000003' and user_id = 'f1000000-0000-4000-8000-000000000006' $$,
  'Propriétaire seul, combat terminé : départ accepté'
);
select lives_ok(
  $$ delete from public.groups where id = 'f2000000-0000-4000-8000-000000000003' $$,
  'Propriétaire parti, combat terminé : dissolution acceptée'
);
reset role;
select is(
  (select count(*)::int from public.groups where id = 'f2000000-0000-4000-8000-000000000003')
  + (select count(*)::int from public.combats where group_id = 'f2000000-0000-4000-8000-000000000003'),
  0,
  'Propriétaire seul : groupe et combat terminé supprimés'
);

-- Suppression du compte d'un propriétaire en plein combat (droit RGPD) : jamais bloquée.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'f1000000-0000-4000-8000-000000000011', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ select public.start_combat('f2000000-0000-4000-8000-000000000007') $$,
  'G7 : le MJ lance un combat'
);
reset role;
select is(
  (select count(*)::int from public.combats where group_id = 'f2000000-0000-4000-8000-000000000007' and status = 'active'),
  1,
  'G7 : un combat est actif'
);
select lives_ok(
  $$ delete from auth.users where id = 'f1000000-0000-4000-8000-000000000011' $$,
  'Suppression du compte du propriétaire pendant un combat actif : acceptée'
);
select is(
  (select count(*)::int from public.groups where id = 'f2000000-0000-4000-8000-000000000007')
  + (select count(*)::int from public.group_members where group_id = 'f2000000-0000-4000-8000-000000000007')
  + (select count(*)::int from public.combats where group_id = 'f2000000-0000-4000-8000-000000000007')
  + (select count(*)::int from public.combat_participants where group_id = 'f2000000-0000-4000-8000-000000000007'),
  0,
  'Suppression de compte : le groupe, ses membres, le combat et ses participants partent en cascade'
);
select is(
  (select count(*)::int from auth.users where id = 'f1000000-0000-4000-8000-000000000012')::text
  || '/' || (select count(*)::int from public.characters where id = 'f3000000-0000-4000-8000-000000000012')::text,
  '1/1',
  'Suppression de compte : le compte et le personnage du joueur restent intacts'
);

-- Même chose dans l'autre ordre de cascade. PostgreSQL déclenche les triggers RI de auth.users dans l'ordre alphabétique de
-- leur nom (RI_ConstraintTrigger_a_<oid>), qui dépend de l'histoire de la base : en production, la cascade vers
-- group_members peut passer AVANT celle vers groups. La ligne du propriétaire est alors supprimée alors que son groupe existe
-- encore : seule la dérogation « compte supprimé » du trigger de group_members la laisse passer. On recrée la FK
-- groups.owner_id (transaction annulée) pour forcer cet ordre, et on le vérifie.
alter table public.groups drop constraint groups_owner_id_fkey;
alter table public.groups
  add constraint groups_owner_id_fkey foreign key (owner_id) references auth.users (id) on delete cascade;
select ok(
  (select min(t.tgname) from pg_trigger t join pg_constraint c on c.oid = t.tgconstraint
    where t.tgrelid = 'auth.users'::regclass and c.conname = 'group_members_user_id_fkey' and t.tgtype & 8 = 8)
  < (select min(t.tgname) from pg_trigger t join pg_constraint c on c.oid = t.tgconstraint
    where t.tgrelid = 'auth.users'::regclass and c.conname = 'groups_owner_id_fkey' and t.tgtype & 8 = 8),
  'Précondition : la cascade vers group_members est déclenchée avant celle vers groups'
);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select ('f1000000-0000-4000-8000-0000000000' || n)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'pgtap-devenir-mj-' || n || '@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
  from (values ('13'), ('14')) v(n);
insert into public.groups (id, name, owner_id, invite_code)
values ('f2000000-0000-4000-8000-000000000008', 'pgTAP devenir MJ 8 (suppression de compte, autre ordre)', 'f1000000-0000-4000-8000-000000000013', 'PGTAPDM8');
insert into public.characters (id, owner_id, name)
values ('f3000000-0000-4000-8000-000000000014', 'f1000000-0000-4000-8000-000000000014', 'Gwen');
insert into public.group_members (group_id, character_id, user_id, role, is_game_master)
values
  ('f2000000-0000-4000-8000-000000000008', null, 'f1000000-0000-4000-8000-000000000013', 'owner', true),
  ('f2000000-0000-4000-8000-000000000008', 'f3000000-0000-4000-8000-000000000014', 'f1000000-0000-4000-8000-000000000014', 'membre', false);

-- Combat actif inséré directement, SANS started_by : dans cet ordre, la cascade « started_by set null » passerait avant la
-- suppression du groupe et, la ligne combats ayant été insérée dans la MÊME transaction, PostgreSQL revérifierait sa FK
-- group_id après la cascade (règle des lignes insérées par la transaction courante) : artefact de test pur. En production, le
-- combat date d'une transaction antérieure ; ce cas (start_combat validé, puis suppression du compte) a été vérifié à part,
-- voir la PR.
select lives_ok(
  $$ insert into public.combats (group_id) values ('f2000000-0000-4000-8000-000000000008') $$,
  'G8 : un combat est actif'
);
select lives_ok(
  $$ delete from auth.users where id = 'f1000000-0000-4000-8000-000000000013' $$,
  'Autre ordre de cascade : suppression du compte du propriétaire pendant un combat actif acceptée'
);
select is(
  (select count(*)::int from public.groups where id = 'f2000000-0000-4000-8000-000000000008')
  + (select count(*)::int from public.group_members where group_id = 'f2000000-0000-4000-8000-000000000008')
  + (select count(*)::int from public.combats where group_id = 'f2000000-0000-4000-8000-000000000008'),
  0,
  'Autre ordre de cascade : groupe, membres et combat supprimés'
);

select * from finish();

rollback;
