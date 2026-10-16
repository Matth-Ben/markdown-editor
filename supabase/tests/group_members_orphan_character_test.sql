-- Complète supabase/tests/group_member_without_character_test.sql (même
-- patron) : vérifie 20261016090000_group_members_orphan_character.sql --
-- supprimer un personnage engagé dans un groupe ne supprime plus la ligne
-- group_members (bug produit, 12-partage-et-groupes.md section 2) ; la
-- ligne devient ORPHELINE (character_id null, is_game_master false),
-- distincte du MJ VOLONTAIRE (character_id null, is_game_master true) --
-- les deux états ne doivent jamais se bloquer l'un l'autre dans l'index
-- unique partiel, et plusieurs orphelins doivent pouvoir coexister dans le
-- même groupe. Couvre aussi group_members_display_name.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- (depuis la racine du dépôt web, stack local démarré au préalable via
-- `supabase start`). BEGIN/ROLLBACK en fin de fichier : aucune donnée de
-- test ne persiste, le fichier est rejouable à volonté sans nettoyage
-- manuel ni collision avec des données réelles.

begin;

select plan(9);

-- Fixtures : un MJ volontaire (gm, owner du groupe, sans personnage dès le
-- départ), deux joueurs avec chacun leur personnage (player1/character1,
-- player2/character2) -- character1 sera supprimé pour simuler le bug, et
-- un joueur avec un nom de compte renseigné (full_name) pour
-- group_members_display_name. Insérés en tant que `postgres` (rôle
-- superuser du test runner pgTAP), qui contourne RLS.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('66666666-6666-6666-6666-666666666661', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-orphan-gm@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{"full_name": "MJ de test"}', now(), now()),
  ('66666666-6666-6666-6666-666666666662', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-orphan-player1@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('66666666-6666-6666-6666-666666666663', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-orphan-player2@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.groups (id, name, owner_id, invite_code)
values ('55555555-5555-5555-5555-555555555551', 'pgTAP group (orphelin)', '66666666-6666-6666-6666-666666666661', 'PGTAPORP1');

insert into public.characters (id, owner_id, name)
values
  ('44444444-4444-4444-4444-444444444441', '66666666-6666-6666-6666-666666666662', 'pgTAP Orphan Hero 1'),
  ('44444444-4444-4444-4444-444444444442', '66666666-6666-6666-6666-666666666663', 'pgTAP Orphan Hero 2');

-- Le MJ rejoint son propre groupe sans personnage, is_game_master=true
-- (comme le ferait désormais create-group pour un créateur sans personnage).
insert into public.group_members (group_id, character_id, user_id, role, is_game_master)
values ('55555555-5555-5555-5555-555555555551', null, '66666666-6666-6666-6666-666666666661', 'owner', true);

-- player1 et player2 rejoignent avec leur personnage respectif, comme le
-- ferait join-group pour un membre normal.
insert into public.group_members (group_id, character_id, user_id, role, is_game_master)
values
  ('55555555-5555-5555-5555-555555555551', '44444444-4444-4444-4444-444444444441', '66666666-6666-6666-6666-666666666662', 'membre', false),
  ('55555555-5555-5555-5555-555555555551', '44444444-4444-4444-4444-444444444442', '66666666-6666-6666-6666-666666666663', 'membre', false);

-- Test 1 : supprimer character1 (player1) ne doit plus supprimer sa ligne
-- group_members (bug corrigé) -- on delete set null, pas cascade.
delete from public.characters where id = '44444444-4444-4444-4444-444444444441';

select is(
  (select count(*)::int from public.group_members
    where group_id = '55555555-5555-5555-5555-555555555551'
      and user_id = '66666666-6666-6666-6666-666666666662'),
  1,
  'La suppression du personnage ne doit plus supprimer la ligne group_members du joueur (le groupe reste dans sa liste)'
);

-- Test 2 : cette ligne doit être ORPHELINE (character_id null,
-- is_game_master false), jamais confondue avec le MJ volontaire.
select is(
  (select row(character_id, is_game_master) from public.group_members
    where group_id = '55555555-5555-5555-5555-555555555551'
      and user_id = '66666666-6666-6666-6666-666666666662'),
  row(null::uuid, false),
  'La ligne du joueur dont le personnage a été supprimé doit devenir orpheline (character_id null, is_game_master false)'
);

-- Test 3 : le MJ volontaire existant (is_game_master=true) n'est pas
-- affecté -- toujours character_id null, is_game_master true.
select is(
  (select row(character_id, is_game_master) from public.group_members
    where group_id = '55555555-5555-5555-5555-555555555551'
      and user_id = '66666666-6666-6666-6666-666666666661'),
  row(null::uuid, true),
  'Le MJ volontaire reste inchangé (character_id null, is_game_master true) après la suppression du personnage d''un autre membre'
);

-- Test 4 : un DEUXIÈME membre orphelin dans le même groupe doit pouvoir
-- coexister avec le premier -- l'index scopé ne porte que sur
-- is_game_master=true, donc plusieurs orphelins ne se bloquent jamais entre
-- eux (contrairement à l'ancien index group_members_one_null_character_per_group
-- qui aurait rejeté ce deuxième null).
delete from public.characters where id = '44444444-4444-4444-4444-444444444442';

select is(
  (select count(*)::int from public.group_members
    where group_id = '55555555-5555-5555-5555-555555555551'
      and character_id is null and is_game_master = false),
  2,
  'Deux membres orphelins doivent pouvoir coexister dans le même groupe sans violer l''index unique'
);

-- Test 5 : un membre orphelin ne bloque PAS un nouveau MJ volontaire dans un
-- AUTRE groupe tout neuf (contrôle direct de l'index scopé : un insert avec
-- character_id null et is_game_master=true ne doit réussir que s'il n'y a
-- pas déjà de vrai MJ, jamais bloqué par la présence d'orphelins).
insert into public.groups (id, name, owner_id, invite_code)
values ('55555555-5555-5555-5555-555555555552', 'pgTAP group (second)', '66666666-6666-6666-6666-666666666661', 'PGTAPORP2');

select lives_ok(
  $$ insert into public.group_members (group_id, character_id, user_id, role, is_game_master)
     values ('55555555-5555-5555-5555-555555555552', null, '66666666-6666-6666-6666-666666666661', 'owner', true) $$,
  'Un MJ volontaire doit pouvoir rejoindre un groupe qui n''a pas encore de MJ, indépendamment des orphelins d''autres groupes'
);

-- Test 6 : un DEUXIÈME MJ volontaire dans le MÊME groupe reste rejeté --
-- l'index scopé protège toujours "un seul MJ volontaire par groupe".
select throws_ok(
  $$ insert into public.group_members (group_id, character_id, user_id, role, is_game_master)
     values ('55555555-5555-5555-5555-555555555552', null, '66666666-6666-6666-6666-666666666662', 'membre', true) $$,
  '23505',
  null,
  'Un deuxième MJ volontaire dans le même groupe doit toujours être rejeté par l''index unique scopé'
);

-- Test 7 : un membre orphelin supplémentaire dans CE MÊME groupe (celui qui
-- a déjà un MJ volontaire) ne doit PAS être rejeté -- confirme qu'un
-- orphelin ne rentre jamais en conflit avec le vrai MJ du groupe.
select lives_ok(
  $$ insert into public.group_members (group_id, character_id, user_id, role, is_game_master)
     values ('55555555-5555-5555-5555-555555555552', null, '66666666-6666-6666-6666-666666666663', 'membre', false) $$,
  'Un membre orphelin ne doit jamais entrer en conflit avec le MJ volontaire du même groupe'
);

-- Test 8 : group_members_display_name retourne le full_name du MJ (depuis
-- auth.users.raw_user_meta_data), vu par un membre du groupe.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '66666666-6666-6666-6666-666666666662', 'role', 'authenticated')::text,
  true
);

select is(
  (select public.group_members_display_name(gm)
    from public.group_members gm
    where gm.group_id = '55555555-5555-5555-5555-555555555551'
      and gm.user_id = '66666666-6666-6666-6666-666666666661'),
  'MJ de test',
  'group_members_display_name doit renvoyer le full_name du compte (raw_user_meta_data) pour le MJ'
);

reset role;

-- Test 9 : group_members_display_name renvoie null pour un membre sans
-- full_name renseigné (cas courant à court terme, voir le commentaire de
-- 20260906000000_add_stories_gm_display_name.sql).
select is(
  (select public.group_members_display_name(gm)
    from public.group_members gm
    where gm.group_id = '55555555-5555-5555-5555-555555555551'
      and gm.user_id = '66666666-6666-6666-6666-666666666662'),
  null::text,
  'group_members_display_name doit renvoyer null quand le compte n''a pas de full_name renseigné'
);

select * from finish();

rollback;
