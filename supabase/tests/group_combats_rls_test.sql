-- Tests de 20261114090000_create_group_combats.sql et 20261114091000_group_combat_rpcs.sql
-- (combat du groupe, PR0). Même patron que group_member_without_character_test.sql.
--
-- Couvre : aucun PV dans le schéma ; Realtime ; groupe sans MJ refusé ; second
-- lancement refusé ; un membre non-MJ ne peut ni lancer, ni terminer, ni toucher
-- aux PNJ, ni réordonner ; un joueur ne modifie que SA ligne (RPC) et aucune
-- écriture directe n'est possible ; un non-membre ne lit rien ; auto-numérotation
-- et limites des PNJ ; tri/égalités/réordonnancement ; retrait logique ;
-- départ d'un membre (ex-membre perd la lecture, ligne retirée) ; suppression
-- d'un personnage ; MJ parti = état lisible et fin possible par le MJ seul.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- BEGIN/ROLLBACK : rejouable, aucune donnée ne persiste.

begin;

select plan(52);

-- Fixtures (insérées en tant que postgres, qui contourne RLS) --------------------
-- c...01 : MJ (propriétaire de A, MJ sans personnage)   c...02 : joueur 1
-- c...03 : joueur 2                                      c...04 : tiers sans relation
-- c...05 : propriétaire de B qui joue avec un personnage (aucun MJ dans l'app)
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-combat-gm@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('c0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-combat-p1@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('c0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-combat-p2@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('c0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-combat-stranger@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('c0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-combat-solo@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.groups (id, name, owner_id, invite_code)
values
  ('d0000000-0000-0000-0000-000000000001', 'pgTAP combat A (avec MJ)', 'c0000000-0000-0000-0000-000000000001', 'PGTAPCA1'),
  ('d0000000-0000-0000-0000-000000000002', 'pgTAP combat B (sans MJ)', 'c0000000-0000-0000-0000-000000000005', 'PGTAPCB1');

insert into public.characters (id, owner_id, name)
values
  ('e0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 'Aelar'),
  ('e0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003', 'Brynn'),
  ('e0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005', 'Solo');

-- joined_at explicites et distincts : l'ordre d'arrivée des PJ en dépend.
insert into public.group_members (group_id, character_id, user_id, role, is_game_master, joined_at)
values
  ('d0000000-0000-0000-0000-000000000001', null, 'c0000000-0000-0000-0000-000000000001', 'owner', true, now() - interval '3 hours'),
  ('d0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', 'membre', false, now() - interval '2 hours'),
  ('d0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003', 'membre', false, now() - interval '1 hour'),
  ('d0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005', 'owner', false, now());

-- Contexte partagé (identifiants du combat courant), lisible par tous les rôles.
create temp table ctx (k text primary key, v uuid);
grant all on ctx to public;

-- Schéma -----------------------------------------------------------------------------

select is(
  (select count(*)::int from information_schema.columns
    where table_schema = 'public'
      and table_name in ('combats', 'combat_participants')
      and column_name ~* '(^|_)(hp|pv|hit_points|health|vitality|damage)(_|$)'),
  0,
  'Aucune colonne de PV/points de vie sur combats ni combat_participants'
);

select ok(
  (select count(*) = 2 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename in ('combats', 'combat_participants')),
  'combats et combat_participants sont publiées sur supabase_realtime'
);

-- Lancement ------------------------------------------------------------------------------

-- Groupe sans MJ dans l'app (propriétaire avec personnage) : refusé même pour son propriétaire.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000005', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.start_combat('d0000000-0000-0000-0000-000000000002') $$,
  'P0001', 'no_game_master',
  'Un groupe sans MJ dans l''app ne peut pas lancer de combat'
);
reset role;

-- Membre non-MJ : refusé.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.start_combat('d0000000-0000-0000-0000-000000000001') $$,
  '42501', 'not_group_owner',
  'Un membre non-MJ ne peut pas lancer de combat'
);
reset role;

-- Tiers sans relation : refusé sans révéler le groupe.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000004', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.start_combat('d0000000-0000-0000-0000-000000000001') $$,
  'P0002', 'group_not_found',
  'Un non-membre ne peut pas lancer de combat (groupe introuvable)'
);
reset role;

-- Le MJ lance.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ select public.start_combat('d0000000-0000-0000-0000-000000000001') $$,
  'Le MJ peut lancer un combat'
);
select throws_ok(
  $$ select public.start_combat('d0000000-0000-0000-0000-000000000001') $$,
  'P0001', 'combat_already_active',
  'Un second lancement alors qu''un combat est actif est refusé'
);
reset role;

insert into ctx select 'combat', id from public.combats where group_id = 'd0000000-0000-0000-0000-000000000001';

select is(
  (select round::text || '/' || coalesce(current_participant_id::text, 'null') || '/' || status
     from public.combats where id = (select v from ctx where k = 'combat')),
  '1/null/active',
  'Combat lancé : round 1, aucun tour courant, actif'
);
select is(
  (select count(*)::int from public.combat_participants
    where combat_id = (select v from ctx where k = 'combat')
      and kind = 'pc' and initiative is null and status = 'active'),
  2,
  'Une ligne PJ par membre ayant un personnage, initiative à saisir (le MJ sans personnage n''en a pas)'
);

insert into ctx select 'p1', id from public.combat_participants
  where combat_id = (select v from ctx where k = 'combat') and user_id = 'c0000000-0000-0000-0000-000000000002';
insert into ctx select 'p2', id from public.combat_participants
  where combat_id = (select v from ctx where k = 'combat') and user_id = 'c0000000-0000-0000-0000-000000000003';

-- Joueur : sa propre initiative, rien d'autre ------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);

select lives_ok(
  $$ select public.set_my_initiative((select v from ctx where k = 'combat'), 15) $$,
  'Un joueur peut saisir sa propre initiative'
);
select is(
  (select initiative from public.combat_participants where id = (select v from ctx where k = 'p1')),
  15,
  'L''initiative du joueur 1 est enregistrée sur sa ligne'
);
select is(
  (select initiative from public.combat_participants where id = (select v from ctx where k = 'p2')),
  null::integer,
  'La ligne du joueur 2 n''est pas modifiée'
);
select throws_ok(
  $$ select public.set_my_initiative((select v from ctx where k = 'combat'), 99) $$,
  '22023', 'invalid_initiative',
  'Initiative hors bornes refusée'
);
select throws_ok(
  $$ update public.combat_participants set initiative = 1 where id = (select v from ctx where k = 'p2') $$,
  '42501', null,
  'UPDATE direct sur combat_participants refusé à un joueur'
);
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order)
     values ((select v from ctx where k = 'combat'), 'd0000000-0000-0000-0000-000000000001', 'Triche', 'npc', 99) $$,
  '42501', null,
  'INSERT direct sur combat_participants refusé à un joueur'
);
select throws_ok(
  $$ update public.combats set round = 9 where id = (select v from ctx where k = 'combat') $$,
  '42501', null,
  'UPDATE direct sur combats refusé à un joueur'
);
select throws_ok(
  $$ select public.set_participant_initiative((select v from ctx where k = 'p2'), 3) $$,
  '42501', 'not_group_owner',
  'Un joueur ne peut pas modifier l''initiative d''un autre'
);
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Gobelin', 10, 1) $$,
  '42501', 'not_group_owner',
  'Un joueur ne peut pas ajouter de monstre'
);
select throws_ok(
  $$ select public.remove_participant((select v from ctx where k = 'p2')) $$,
  '42501', 'not_group_owner',
  'Un joueur ne peut pas retirer un participant'
);
select throws_ok(
  $$ select public.reorder_participant((select v from ctx where k = 'p2'), 1) $$,
  '42501', 'not_group_owner',
  'Un joueur ne peut pas réordonner'
);
select throws_ok(
  $$ select public.end_combat((select v from ctx where k = 'combat')) $$,
  '42501', 'not_group_owner',
  'Un joueur ne peut pas terminer le combat'
);
select is(
  (select count(*)::int from public.combat_participants where combat_id = (select v from ctx where k = 'combat')),
  2,
  'Un membre lit les participants de son groupe'
);
reset role;

-- MJ sans personnage : pas de ligne PJ.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.set_my_initiative((select v from ctx where k = 'combat'), 5) $$,
  'P0001', 'no_character',
  'Le MJ sans personnage n''a pas de ligne PJ à renseigner'
);

-- Monstres : numérotation et limites -------------------------------------------------------------
select is(
  (select string_agg(name, ',' order by sort_order)
     from public.add_npc_participants((select v from ctx where k = 'combat'), 'Gobelin', 12, 3)),
  'Gobelin 1,Gobelin 2,Gobelin 3',
  'Ajout en lot : auto-numérotation Gobelin 1/2/3'
);
select is(
  (select string_agg(name, ',' order by sort_order)
     from public.add_npc_participants((select v from ctx where k = 'combat'), 'Gobelin', 12, 2)),
  'Gobelin 4,Gobelin 5',
  'Un second lot continue la numérotation'
);
select is(
  (select name from public.add_npc_participants((select v from ctx where k = 'combat'), 'Gobelin Chef', 15, 1)),
  'Gobelin Chef',
  'Un PNJ seul garde son nom tel quel'
);
select is(
  (select string_agg(name, ',' order by sort_order)
     from public.add_npc_participants((select v from ctx where k = 'combat'), 'Gobelin', null, 2)),
  'Gobelin 6,Gobelin 7',
  'Un nom de base suivi d''un mot non numérique n''est pas compté dans la numérotation'
);
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Orc', 10, 21) $$,
  'P0001', 'npc_limit_per_call', 'Plus de 20 monstres par appel refusé'
);
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Orc', 10, 0) $$,
  '22023', 'invalid_count', 'Quantité nulle refusée'
);
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), '   ', 10, 1) $$,
  '22023', 'invalid_name', 'Nom vide refusé'
);
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Orc', 61, 1) $$,
  '22023', 'invalid_initiative', 'Initiative de monstre hors bornes refusée'
);
-- 8 PNJ déjà présents (3+2+1+2) : +20 +20 +12 = 60, puis un de plus est refusé.
select lives_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Squelette', 5, 20) $$,
  'Lot de 20 accepté'
);
select lives_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Zombie', 5, 20) $$,
  'Second lot de 20 accepté'
);
select lives_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Rat', 5, 12) $$,
  'Lot jusqu''à 60 PNJ accepté'
);
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Rat', 5, 1) $$,
  'P0001', 'npc_limit_per_combat', 'Au-delà de 60 PNJ par combat refusé'
);

-- Tri, égalités, réordonnancement ---------------------------------------------------------------------
select lives_ok(
  $$ select public.set_participant_initiative((select v from ctx where k = 'p2'), 15) $$,
  'Le MJ édite l''initiative d''un joueur'
);
insert into ctx select 'chef', id from public.combat_participants
  where combat_id = (select v from ctx where k = 'combat') and name = 'Gobelin Chef';

select is(
  (select string_agg(name, ',' order by initiative desc nulls last, sort_order)
     from (select * from public.combat_participants
            where combat_id = (select v from ctx where k = 'combat') and initiative >= 15) t),
  'Aelar,Brynn,Gobelin Chef',
  'Égalité à 15 : PJ avant PNJ, puis ordre d''arrivée (sort_order serveur)'
);
select is(
  (select name from public.reorder_participant((select v from ctx where k = 'chef'), 1) limit 1),
  'Gobelin Chef',
  'Le MJ réordonne : le PNJ passe en première position de départage'
);
select is(
  (select string_agg(name, ',' order by initiative desc nulls last, sort_order)
     from (select * from public.combat_participants
            where combat_id = (select v from ctx where k = 'combat') and initiative >= 15) t),
  'Gobelin Chef,Aelar,Brynn',
  'Après réordonnancement, le PNJ passe avant les PJ à égalité'
);
select throws_ok(
  $$ select public.reorder_participant((select v from ctx where k = 'chef'), 0) $$,
  '22023', 'invalid_sort_order', 'Position invalide refusée'
);
reset role;

-- Départ d'un membre / suppression de personnage ------------------------------------------------------------
delete from public.group_members
 where group_id = 'd0000000-0000-0000-0000-000000000001' and user_id = 'c0000000-0000-0000-0000-000000000003';

select is(
  (select status from public.combat_participants where id = (select v from ctx where k = 'p2')),
  'removed',
  'Le membre parti est retiré du combat actif (pas de fantôme)'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000003', 'role', 'authenticated')::text, true);
select is(
  (select count(*)::int from public.combats) + (select count(*)::int from public.combat_participants),
  0,
  'Un ex-membre perd la lecture du combat et des participants'
);
select throws_ok(
  $$ select public.set_my_initiative((select v from ctx where k = 'combat'), 3) $$,
  'P0002', 'combat_not_found',
  'Un ex-membre ne peut plus écrire'
);
reset role;

-- Un non-membre ne lit rien.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000004', 'role', 'authenticated')::text, true);
select is(
  (select count(*)::int from public.combats) + (select count(*)::int from public.combat_participants),
  0,
  'Un non-membre ne lit aucun combat ni participant'
);
reset role;

-- Suppression du personnage du joueur 1 : sa ligne est retirée, il n'a plus de personnage.
delete from public.characters where id = 'e0000000-0000-0000-0000-000000000002';
select is(
  (select status from public.combat_participants where id = (select v from ctx where k = 'p1')),
  'removed',
  'La suppression du personnage retire la ligne PJ du combat actif'
);

-- Le MJ retire un monstre (retrait logique) puis termine, relance, et quitte.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select is(
  (select status from public.remove_participant((select v from ctx where k = 'chef'))),
  'removed',
  'Le MJ retire un monstre (soft-delete)'
);
select is(
  (select count(*)::int from public.combat_participants where id = (select v from ctx where k = 'chef')),
  1,
  'La ligne retirée existe toujours (retrait logique)'
);
select is(
  (select status from public.end_combat((select v from ctx where k = 'combat'))),
  'ended',
  'Le MJ termine le combat'
);
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'combat'), 'Orc', 10, 1) $$,
  'P0001', 'combat_not_active', 'Plus d''écriture sur un combat terminé'
);
reset role;

-- MJ parti : le combat actif d'un nouveau lancement reste lisible et seul le MJ peut le terminer.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ select public.start_combat('d0000000-0000-0000-0000-000000000001') $$,
  'Après la fin du précédent, un nouveau combat peut être lancé'
);
reset role;
delete from public.group_members
 where group_id = 'd0000000-0000-0000-0000-000000000001' and user_id = 'c0000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select is(
  (select count(*)::int from public.combats where group_id = 'd0000000-0000-0000-0000-000000000001' and status = 'active'),
  1,
  'MJ parti : le MJ (propriétaire) lit encore le combat actif'
);
select lives_ok(
  $$ select public.end_combat((select id from public.combats where group_id = 'd0000000-0000-0000-0000-000000000001' and status = 'active')) $$,
  'MJ parti : le MJ peut terminer le combat'
);
reset role;

select * from finish();

rollback;
