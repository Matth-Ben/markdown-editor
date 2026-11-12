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

select plan(118);

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


-- Fixtures du second jeu de tests (groupe C : MJ c...06, membres c...07 et c...08, arrivant c...09).
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select ('c0000000-0000-0000-0000-0000000000' || n)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'pgtap-combat-c' || n || '@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
  from (values ('06'), ('07'), ('08'), ('09')) v(n);
insert into public.groups (id, name, owner_id, invite_code)
values ('d0000000-0000-0000-0000-000000000003', 'pgTAP combat C', 'c0000000-0000-0000-0000-000000000006', 'PGTAPCC1');
insert into public.characters (id, owner_id, name) values
  ('e0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000007', 'Alpha'),
  ('e0000000-0000-0000-0000-000000000008', 'c0000000-0000-0000-0000-000000000008', 'Beta'),
  ('e0000000-0000-0000-0000-000000000018', 'c0000000-0000-0000-0000-000000000008', 'Gamma'),
  ('e0000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000009', 'Delta');
insert into public.group_members (group_id, character_id, user_id, role, is_game_master, joined_at) values
  ('d0000000-0000-0000-0000-000000000003', null, 'c0000000-0000-0000-0000-000000000006', 'owner', true, now() - interval '3 hours'),
  ('d0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000007', 'membre', false, now() - interval '2 hours'),
  ('d0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000008', 'c0000000-0000-0000-0000-000000000008', 'membre', false, now() - interval '1 hour');

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
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000002', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.set_my_initiative((select id from public.combats where group_id = 'd0000000-0000-0000-0000-000000000001' and status = 'active'), 7) $$,
  'P0001', 'gm_absent',
  'MJ parti : un joueur ne peut plus écrire (gm_absent)'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000001', 'role', 'authenticated')::text, true);
select lives_ok(
  $$ select public.end_combat((select id from public.combats where group_id = 'd0000000-0000-0000-0000-000000000001' and status = 'active')) $$,
  'MJ parti : le MJ peut terminer le combat'
);
reset role;


-- ===== Second jeu : groupe C =====
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);
select lives_ok($$ select public.start_combat('d0000000-0000-0000-0000-000000000003') $$, 'MJ 2 : lancement dans le groupe C');
reset role;
insert into ctx select 'cc', id from public.combats where group_id = 'd0000000-0000-0000-0000-000000000003' and status = 'active';
insert into ctx select 'm1row', id from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and user_id = 'c0000000-0000-0000-0000-000000000007';
insert into ctx select 'm2row', id from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and user_id = 'c0000000-0000-0000-0000-000000000008';
select throws_ok(
  $$ insert into public.combats (group_id) values ('d0000000-0000-0000-0000-000000000003') $$,
  '23505', null,
  'Insertion directe d''un second combat actif : refusée par l''index unique'
);
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order, initiative) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', 'X', 'npc', 90, 61) $$,
  '23514', null,
  'CHECK initiative > 60 refusé'
);
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order, initiative) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', 'X', 'npc', 90, -21) $$,
  '23514', null,
  'CHECK initiative < -20 refusé'
);
select lives_ok($$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order, initiative) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', 'Min', 'npc', 91, -20) $$, 'Borne -20 acceptée');
select lives_ok($$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order, initiative) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', 'Max', 'npc', 92, 60) $$, 'Borne 60 acceptée');
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', '', 'npc', 93) $$,
  '23514', null,
  'CHECK nom vide refusé'
);
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', repeat('a', 81), 'npc', 93) $$,
  '23514', null,
  'CHECK nom de 81 caractères refusé'
);
select lives_ok($$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', repeat('a', 80), 'npc', 93) $$, 'Nom de 80 caractères accepté');
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', 'X', 'pc', 94) $$,
  '23514', null,
  'CHECK kind_shape : un PJ sans user_id refusé'
);
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order, user_id) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', 'X', 'npc', 94, 'c0000000-0000-0000-0000-000000000007') $$,
  '23514', null,
  'CHECK kind_shape : un PNJ avec user_id refusé'
);
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', 'X', 'npc', 0) $$,
  '23514', null,
  'CHECK sort_order >= 1'
);
select throws_ok(
  $$ insert into public.combat_participants (combat_id, group_id, name, kind, sort_order, status) values ((select v from ctx where k = 'cc'), 'd0000000-0000-0000-0000-000000000003', 'X', 'npc', 95, 'inconnu') $$,
  '23514', null,
  'CHECK status participant'
);
select throws_ok(
  $$ insert into public.combats (group_id, status, ended_at) values ('d0000000-0000-0000-0000-000000000002', 'ended', null) $$,
  '23514', null,
  'CHECK combats : terminé sans ended_at refusé'
);
select throws_ok(
  $$ insert into public.combats (group_id, status, ended_at) values ('d0000000-0000-0000-0000-000000000002', 'active', now()) $$,
  '23514', null,
  'CHECK combats : actif avec ended_at refusé'
);
select throws_ok(
  $$ insert into public.combats (group_id, round) values ('d0000000-0000-0000-0000-000000000002', 0) $$,
  '23514', null,
  'CHECK round >= 1'
);
select throws_ok(
  $$ update public.combats set current_participant_id = (select p.id from public.combat_participants p where p.combat_id = (select v from ctx where k = 'combat') limit 1) where id = (select v from ctx where k = 'cc') $$,
  '23503', null,
  'FK composite : le tour courant doit appartenir au même combat'
);
delete from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and name in ('Min', 'Max', repeat('a', 80));
select is((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('start_combat','end_combat','set_my_initiative','set_participant_initiative','add_npc_participants','remove_participant','reorder_participant') and has_function_privilege('anon', p.oid, 'execute')), 0, 'anon/public sans EXECUTE sur les 7 RPC');
select is((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('start_combat','end_combat','set_my_initiative','set_participant_initiative','add_npc_participants','remove_participant','reorder_participant') and not has_function_privilege('authenticated', p.oid, 'execute')), 0, 'authenticated a EXECUTE sur les 7 RPC');
select is((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('group_has_gm','combat_lock_for_gm','combat_participant_combat_id','on_group_member_left_combat','on_combat_participant_deleted') and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 0, 'helpers internes et fonctions de trigger inaccessibles aux clients');
select is((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('is_group_owner') and (has_function_privilege('anon', p.oid, 'execute') or not has_function_privilege('authenticated', p.oid, 'execute'))), 0, 'is_group_owner : authenticated oui, anon non');
select is((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('start_combat','end_combat','set_my_initiative','set_participant_initiative','add_npc_participants','remove_participant','reorder_participant','group_has_gm','combat_lock_for_gm','combat_participant_combat_id','on_group_member_left_combat','on_combat_participant_deleted','is_group_owner') and p.prosecdef and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')), 0, 'Toutes les fonctions security definer fixent leur search_path');
select is((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('start_combat','end_combat','set_my_initiative','set_participant_initiative','add_npc_participants','remove_participant','reorder_participant','group_has_gm','combat_lock_for_gm','combat_participant_combat_id','on_group_member_left_combat','on_combat_participant_deleted','is_group_owner')), 13, 'Les 13 fonctions attendues existent');
select is((select count(*)::int from pg_proc where proname = 'combat_group_id'), 0, 'Fonction morte combat_group_id absente');
select ok(not (has_table_privilege('authenticated', 'public.combats', 'INSERT') or has_table_privilege('authenticated', 'public.combats', 'UPDATE') or has_table_privilege('authenticated', 'public.combats', 'DELETE') or has_table_privilege('authenticated', 'public.combat_participants', 'INSERT') or has_table_privilege('authenticated', 'public.combat_participants', 'UPDATE') or has_table_privilege('authenticated', 'public.combat_participants', 'DELETE')), 'authenticated sans INSERT/UPDATE/DELETE sur les deux tables');
select ok(has_table_privilege('authenticated', 'public.combats', 'SELECT') and has_table_privilege('authenticated', 'public.combat_participants', 'SELECT') and not has_table_privilege('anon', 'public.combats', 'SELECT') and not has_table_privilege('anon', 'public.combat_participants', 'SELECT'), 'SELECT pour authenticated, rien pour anon');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000004', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.end_combat((select v from ctx where k = 'cc')) $$,
  'P0002', 'combat_not_found',
  'Non-membre : end_combat -> combat_not_found'
);
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'cc'), 'Orc', 5, 1) $$,
  'P0002', 'combat_not_found',
  'Non-membre : add_npc_participants -> combat_not_found'
);
select throws_ok(
  $$ select public.remove_participant((select v from ctx where k = 'm1row')) $$,
  'P0002', 'combat_not_found',
  'Non-membre : remove_participant -> combat_not_found'
);
select throws_ok(
  $$ select public.set_participant_initiative((select v from ctx where k = 'm1row'), 5) $$,
  'P0002', 'combat_not_found',
  'Non-membre : set_participant_initiative -> combat_not_found'
);
select throws_ok(
  $$ select public.reorder_participant((select v from ctx where k = 'm1row'), 1) $$,
  'P0002', 'combat_not_found',
  'Non-membre : reorder_participant -> combat_not_found'
);
select throws_ok(
  $$ select public.remove_participant('00000000-0000-0000-0000-00000000dead') $$,
  'P0002', 'combat_not_found',
  'Participant inexistant : remove_participant -> combat_not_found'
);
select throws_ok(
  $$ select public.reorder_participant('00000000-0000-0000-0000-00000000dead', 1) $$,
  'P0002', 'combat_not_found',
  'Participant inexistant : reorder_participant -> combat_not_found'
);
select throws_ok(
  $$ select public.set_participant_initiative('00000000-0000-0000-0000-00000000dead', 1) $$,
  'P0002', 'combat_not_found',
  'Participant inexistant : set_participant_initiative -> combat_not_found'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);
select lives_ok($$ select public.add_npc_participants((select v from ctx where k = 'cc'), 'Orc', 5, 1) $$, 'MJ 2 ajoute un Orc');
reset role;
insert into ctx select 'orc', id from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and name = 'Orc';
insert into public.group_members (group_id, character_id, user_id, role, is_game_master) values ('d0000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000009', 'membre', false);
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000009', 'role', 'authenticated')::text, true);
select is((select name from public.set_my_initiative((select v from ctx where k = 'cc'), 20)), 'Delta', 'Un membre arrivé après le lancement obtient sa ligne à la première saisie');
reset role;
select is((select string_agg(name, ',' order by sort_order) from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and name in ('Alpha','Beta','Delta','Orc')), 'Alpha,Beta,Delta,Orc', 'La ligne créée paresseusement est insérée avant le premier PNJ');
update public.group_members set character_id = 'e0000000-0000-0000-0000-000000000018' where group_id = 'd0000000-0000-0000-0000-000000000003' and user_id = 'c0000000-0000-0000-0000-000000000008';
select is((select status from public.combat_participants where id = (select v from ctx where k = 'm2row')), 'removed', 'Changement de personnage : l''ancienne ligne PJ est retirée');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000008', 'role', 'authenticated')::text, true);
select is((select name from public.set_my_initiative((select v from ctx where k = 'cc'), 11)), 'Gamma', 'Changement de personnage : nouvelle ligne créée à la saisie');
reset role;
select is((select count(*)::int from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and user_id = 'c0000000-0000-0000-0000-000000000008' and status <> 'removed'), 1, 'Un seul PJ vivant pour ce joueur');
update public.group_members set character_id = 'e0000000-0000-0000-0000-000000000008' where group_id = 'd0000000-0000-0000-0000-000000000003' and user_id = 'c0000000-0000-0000-0000-000000000008';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000008', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.set_my_initiative((select v from ctx where k = 'cc'), 12) $$,
  'P0001', 'participant_removed',
  'Retour à un personnage dont la ligne a été retirée : participant_removed'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);
select is((select initiative from public.set_participant_initiative((select v from ctx where k = 'm1row'), 10)), 10, 'MJ fixe l''initiative d''un PJ');
select is((select initiative from public.set_participant_initiative((select v from ctx where k = 'm1row'), null)), null::integer, 'set_participant_initiative(NULL) remet à saisir');
select throws_ok(
  $$ select public.set_participant_initiative((select v from ctx where k = 'm2row'), 5) $$,
  'P0001', 'participant_removed',
  'MJ : participant retiré non modifiable'
);
select lives_ok($$ select public.add_npc_participants((select v from ctx where k = 'cc'), 'Rat', 1, 20) $$, 'Lot de 20');
select lives_ok($$ select public.add_npc_participants((select v from ctx where k = 'cc'), 'Rat', 1, 20) $$, 'Second lot de 20');
select lives_ok($$ select public.add_npc_participants((select v from ctx where k = 'cc'), 'Rat', 1, 19) $$, 'Troisième lot : 60 PNJ non retirés avec l''Orc');
select throws_ok(
  $$ select public.add_npc_participants((select v from ctx where k = 'cc'), 'Rat', 1, 1) $$,
  'P0001', 'npc_limit_per_combat',
  '61e PNJ non retiré refusé'
);
select is((select name from public.remove_participant((select id from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and name = 'Rat 1'))), 'Rat 1', 'Retrait d''un Rat');
select is((select name from public.add_npc_participants((select v from ctx where k = 'cc'), 'Rat', 1, 1)), 'Rat', 'Un PNJ retiré libère une place sous la limite de 60');
reset role;
-- Numérotation après retrait : les noms retirés restent comptés (pas de doublon).
update public.combat_participants set status = 'removed'
 where combat_id = (select v from ctx where k = 'cc') and name in ('Rat 10', 'Rat 11', 'Rat 12', 'Rat 13', 'Rat 14');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);
select is(
  (select string_agg(name, ',' order by sort_order) from public.add_npc_participants((select v from ctx where k = 'cc'), 'Gobelin', 8, 3)),
  'Gobelin 1,Gobelin 2,Gobelin 3',
  'Numérotation : premier lot'
);
select is(
  (select status from public.remove_participant((select id from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and name = 'Gobelin 3'))),
  'removed',
  'Retrait de Gobelin 3'
);
select is(
  (select string_agg(name, ',' order by sort_order) from public.add_npc_participants((select v from ctx where k = 'cc'), 'Gobelin', 8, 2)),
  'Gobelin 4,Gobelin 5',
  'Numérotation après retrait : Gobelin 3 reste compté, pas de doublon'
);
reset role;
update public.combats set current_participant_id = (select v from ctx where k = 'm1row') where id = (select v from ctx where k = 'cc');
delete from public.group_members where group_id = 'd0000000-0000-0000-0000-000000000003' and user_id = 'c0000000-0000-0000-0000-000000000007';
select is((select status from public.combat_participants where id = (select v from ctx where k = 'm1row')), 'removed', 'Départ du joueur au tour courant : ligne retirée');
select is((select current_participant_id from public.combats where id = (select v from ctx where k = 'cc')), (select v from ctx where k = 'm1row'), 'Le tour courant n''est pas modifié par le départ');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);
select is((select status from public.end_combat((select v from ctx where k = 'cc'))), 'ended', 'Fin du combat C');
reset role;
-- Idempotence : on antidate ended_at (superuser) pour que now() ne masque pas une réécriture.
update public.combats set ended_at = now() - interval '1 hour' where id = (select v from ctx where k = 'cc');
create temp table ended_before as select ended_at from public.combats where id = (select v from ctx where k = 'cc');
grant all on ended_before to public;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000006', 'role', 'authenticated')::text, true);
select is((select ended_at from public.end_combat((select v from ctx where k = 'cc'))), (select ended_at from ended_before), 'end_combat idempotent : renvoie exactement l''ended_at antidaté');
reset role;
select is((select ended_at from public.combats where id = (select v from ctx where k = 'cc')), (select ended_at from ended_before), 'end_combat idempotent : la table n''est pas modifiée');
-- MJ absent + combat terminé : l'état du combat prime sur gm_absent.
delete from public.group_members where group_id = 'd0000000-0000-0000-0000-000000000003' and user_id = 'c0000000-0000-0000-0000-000000000006';
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000009', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.set_my_initiative((select v from ctx where k = 'cc'), 3) $$,
  'P0001', 'combat_not_active',
  'MJ absent + combat terminé : combat_not_active (statut avant gm_absent)'
);
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'c0000000-0000-0000-0000-000000000009', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ select public.set_my_initiative((select v from ctx where k = 'cc'), 3) $$,
  'P0001', 'combat_not_active',
  'Combat terminé : écriture joueur refusée'
);
reset role;
update public.combats set current_participant_id = (select v from ctx where k = 'orc') where id = (select v from ctx where k = 'cc');
delete from public.combat_participants where id = (select v from ctx where k = 'orc');
select is((select current_participant_id from public.combats where id = (select v from ctx where k = 'cc')), null::uuid, 'Suppression directe du participant au tour courant : current_participant_id remis à NULL');
update public.combats set current_participant_id = (select id from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and user_id = 'c0000000-0000-0000-0000-000000000009') where id = (select v from ctx where k = 'cc');
select lives_ok($$ delete from auth.users where id = 'c0000000-0000-0000-0000-000000000009' $$, 'Suppression en cascade d''un utilisateur dont la ligne est le tour courant');
select is((select current_participant_id from public.combats where id = (select v from ctx where k = 'cc')), null::uuid, 'Cascade utilisateur : tour courant remis à NULL');
update public.combats set current_participant_id = (select id from public.combat_participants where combat_id = (select v from ctx where k = 'cc') and name = 'Rat 2') where id = (select v from ctx where k = 'cc');
select lives_ok($$ delete from public.groups where id = 'd0000000-0000-0000-0000-000000000003' $$, 'Suppression en cascade du groupe (combat + participants, tour courant renseigné)');
select is((select count(*)::int from public.combats where group_id = 'd0000000-0000-0000-0000-000000000003') + (select count(*)::int from public.combat_participants where group_id = 'd0000000-0000-0000-0000-000000000003'), 0, 'Cascade groupe : plus aucun combat ni participant');

select * from finish();

rollback;
