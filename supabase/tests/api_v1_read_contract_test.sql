-- Tests de 20261120091000_api_v1_read_contract_for_grimoire.sql : schéma api_v1, api_v1.my_gm_groups(),
-- api_v1.group_snapshot(uuid, text). Même patron que group_game_master_combat_guard_test.sql.
--
-- Couvre : droits du schéma et des fonctions (anon sans USAGE ni EXECUTE, PUBLIC sans EXECUTE, security definer et
-- search_path pour TOUTE fonction de api_v1) ; matrice : propriétaire avec ligne MJ, propriétaire qui joue, propriétaire SANS
-- ligne (jamais eue), propriétaire parti (ligne supprimée par lui-même), propriétaire orphelin, membre non propriétaire, tiers,
-- anonyme, connecté sans utilisateur, groupe inconnu, identifiant NULL ; contenu fermé (clés exactes, aucune donnée hors
-- contrat : code d'invitation, histoire, traits, notes, inventaire, jeton de partage, e-mail, carnet du groupe) ; valeurs
-- (pseudo, race, classes, niveaux, PV, états triés, mort, CA séparée et égale au calcul interne) ; compteurs identiques à la vue
-- group_character_status_overview et has_game_master identique à group_has_gm ; empreinte stable (deux appels, ordre physique
-- des lignes, ordre des états, données hors contrat), modifiée par un changement du contrat, réponse « unchanged ».
-- La taille réelle de l'instantané (5 personnages) est vérifiée : moins de 8 Ko.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- BEGIN/ROLLBACK : rejouable, aucune donnée ne persiste.

begin;

select plan(76);

-- Fixtures (insérées en tant que postgres, qui contourne la RLS) ------------------------------------------------------------------
-- u01 Olga : propriétaire de G1 (ligne MJ sans personnage, pseudo blanc) et de G7
-- u02 Bran, u03 Cyra, u04 Dorn, u05 Eryn, u06 Fael : membres de G1 avec un personnage chacun (5 personnages)
-- u07 Gwen : propriétaire de G2, y joue C07 (Bran y est aussi)
-- u08 Hugo : propriétaire de G3 SANS ligne de membre (jamais eue) ; Cyra y joue C03
-- u09 Ilse : propriétaire de G4, quitte son groupe pendant le test (propriétaire parti) ; Dorn y joue C04
-- u10 : tiers sans relation          u11 Jorn : propriétaire orphelin de G5 (son personnage a été supprimé)
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select ('a5000000-0000-4000-8000-0000000000' || n)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'pgtap-api-v1-' || n || '@test.local', crypt('password123', gen_salt('bf')), now(), '{}',
       case when pseudo is null then '{}'::jsonb else jsonb_build_object('full_name', pseudo) end, now(), now()
  from (values ('01', '   '), ('02', 'Bran le Brave'), ('03', 'Cyra'), ('04', 'Dorn'), ('05', null), ('06', 'Fael'),
               ('07', 'Gwen'), ('08', 'Hugo'), ('09', 'Ilse'), ('10', 'Tiers'), ('11', 'Jorn')) v(n, pseudo);

insert into public.groups (id, name, owner_id, invite_code, story_title, story_summary_public)
values
  ('a6000000-0000-4000-8000-000000000001', 'pgTAP api_v1 G1', 'a5000000-0000-4000-8000-000000000001', 'PGTAPAV1',
   'La Mine perdue', 'Résumé public de la campagne.'),
  ('a6000000-0000-4000-8000-000000000002', 'pgTAP api_v1 G2', 'a5000000-0000-4000-8000-000000000007', 'PGTAPAV2', null, null),
  ('a6000000-0000-4000-8000-000000000003', 'pgTAP api_v1 G3', 'a5000000-0000-4000-8000-000000000008', 'PGTAPAV3', null, null),
  ('a6000000-0000-4000-8000-000000000004', 'pgTAP api_v1 G4', 'a5000000-0000-4000-8000-000000000009', 'PGTAPAV4', null, null),
  ('a6000000-0000-4000-8000-000000000005', 'pgTAP api_v1 G5', 'a5000000-0000-4000-8000-000000000011', 'PGTAPAV5', null, null),
  ('a6000000-0000-4000-8000-000000000007', 'pgTAP api_v1 A (premier par nom)', 'a5000000-0000-4000-8000-000000000001', 'PGTAPAV7',
   null, null);

insert into public.characters (
  id, owner_id, name, race_id, race_custom_text, max_hp, current_hp, temporary_hp, is_dead, conditions, armor_class_bonus,
  portrait_url, backstory_text, traits_text, share_token, currency_gp
)
values
  ('a7000000-0000-4000-8000-000000000002', 'a5000000-0000-4000-8000-000000000002', 'Bran',
   (select min(entity_id::integer) from public.translations where entity_type = 'race' and field_name = 'name' and locale = 'fr' and value = 'Nain'),
   null, 30, 20, 5, false, '["prone", "poisoned", "prone"]', 1,
   'https://exemple.supabase.co/storage/v1/object/public/character-portraits/a5000000-0000-4000-8000-000000000002/bran.png',
   'SECRET-BACKSTORY', 'SECRET-TRAITS', 'SECRET-SHARE-TOKEN', 987654321),
  ('a7000000-0000-4000-8000-000000000003', 'a5000000-0000-4000-8000-000000000003', 'Cyra', null, 'Tieffeline des abysses',
   25, 0, 0, true, '[]', 0, null, '', '', null, 0),
  ('a7000000-0000-4000-8000-000000000004', 'a5000000-0000-4000-8000-000000000004', 'Dorn', null, null, 40, 10, 0, false, '[]', 0,
   null, '', '', null, 0),
  ('a7000000-0000-4000-8000-000000000005', 'a5000000-0000-4000-8000-000000000005', 'Eryn', null, null, 0, 0, 0, false, '[]', 0,
   null, '', '', null, 0),
  ('a7000000-0000-4000-8000-000000000006', 'a5000000-0000-4000-8000-000000000006', 'Fael', null, null, 12, 12, 0, false, '[]', 0,
   null, '', '', null, 0),
  ('a7000000-0000-4000-8000-000000000007', 'a5000000-0000-4000-8000-000000000007', 'Gwenaëlle', null, null, 20, 20, 0, false, '[]',
   0, null, '', '', null, 0),
  ('a7000000-0000-4000-8000-000000000011', 'a5000000-0000-4000-8000-000000000011', 'Personnage de Jorn', null, null, 10, 10, 0, false,
   '[]', 0, null, '', '', null, 0);

-- Bran : Guerrier 3 (principal) + Barbare 2 ; Dex 14 ; cuirasse et bouclier équipés -> CA 18, ajustement +1 -> 19.
insert into public.character_classes (character_id, class_id, subclass_id, level, is_primary)
select 'a7000000-0000-4000-8000-000000000002', min(entity_id::integer), null, 2, false
  from public.translations where entity_type = 'class' and field_name = 'name' and locale = 'fr' and value = 'Barbare';
insert into public.character_classes (character_id, class_id, subclass_id, level, is_primary)
select 'a7000000-0000-4000-8000-000000000002', min(entity_id::integer), null, 3, true
  from public.translations where entity_type = 'class' and field_name = 'name' and locale = 'fr' and value = 'Guerrier';
insert into public.character_ability_scores (character_id, ability_id, score)
values ('a7000000-0000-4000-8000-000000000002', 'dex', 14), ('a7000000-0000-4000-8000-000000000002', 'con', 16);
insert into public.character_inventory (character_id, item_id, equipped, notes)
select 'a7000000-0000-4000-8000-000000000002', t.entity_id::integer, true, 'SECRET-INVENTORY-NOTE'
  from public.translations t
 where t.entity_type = 'item' and t.field_name = 'name' and t.locale = 'fr' and t.value in ('Cuirasse', 'Bouclier');

insert into public.group_members (group_id, character_id, user_id, role, is_game_master, joined_at)
values
  ('a6000000-0000-4000-8000-000000000001', null, 'a5000000-0000-4000-8000-000000000001', 'owner', true, now() - interval '6 hours'),
  ('a6000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000002', 'a5000000-0000-4000-8000-000000000002', 'membre', false, now() - interval '5 hours'),
  ('a6000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000003', 'a5000000-0000-4000-8000-000000000003', 'membre', false, now() - interval '4 hours'),
  ('a6000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000004', 'a5000000-0000-4000-8000-000000000004', 'membre', false, now() - interval '3 hours'),
  ('a6000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000005', 'a5000000-0000-4000-8000-000000000005', 'membre', false, now() - interval '2 hours'),
  ('a6000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000006', 'a5000000-0000-4000-8000-000000000006', 'membre', false, now() - interval '1 hour'),
  ('a6000000-0000-4000-8000-000000000002', 'a7000000-0000-4000-8000-000000000007', 'a5000000-0000-4000-8000-000000000007', 'owner', false, now() - interval '2 hours'),
  ('a6000000-0000-4000-8000-000000000002', 'a7000000-0000-4000-8000-000000000002', 'a5000000-0000-4000-8000-000000000002', 'membre', false, now() - interval '1 hour'),
  ('a6000000-0000-4000-8000-000000000003', 'a7000000-0000-4000-8000-000000000003', 'a5000000-0000-4000-8000-000000000003', 'membre', false, now()),
  ('a6000000-0000-4000-8000-000000000004', null, 'a5000000-0000-4000-8000-000000000009', 'owner', true, now() - interval '1 hour'),
  ('a6000000-0000-4000-8000-000000000004', 'a7000000-0000-4000-8000-000000000004', 'a5000000-0000-4000-8000-000000000004', 'membre', false, now()),
  ('a6000000-0000-4000-8000-000000000005', 'a7000000-0000-4000-8000-000000000011', 'a5000000-0000-4000-8000-000000000011', 'owner', false, now()),
  ('a6000000-0000-4000-8000-000000000007', null, 'a5000000-0000-4000-8000-000000000001', 'owner', true, now());

-- G5 : le personnage de Jorn est supprimé, sa ligne devient orpheline (20261016090000).
delete from public.characters where id = 'a7000000-0000-4000-8000-000000000011';

-- Données hors contrat qui ne doivent jamais sortir.
insert into public.group_notes (group_id, character_id, user_id, body)
values ('a6000000-0000-4000-8000-000000000001', 'a7000000-0000-4000-8000-000000000002', 'a5000000-0000-4000-8000-000000000002',
        'SECRET-GROUP-NOTE');

create temp table ctx (k text primary key, v jsonb);
grant all on ctx to public;

-- Liste triée des clés d'un objet jsonb.
create function pg_temp.keys(p jsonb) returns text
language sql immutable as $$ select string_agg(k, ',' order by k) from jsonb_object_keys(p) k $$;

-- Membre d'un instantané par user_id.
create function pg_temp.member(p_snap jsonb, p_user text) returns jsonb
language sql immutable as $$
  select m from jsonb_array_elements(p_snap -> 'members') m where m ->> 'user_id' = 'a5000000-0000-4000-8000-0000000000' || p_user
$$;

-- Schéma et droits ----------------------------------------------------------------------------------------------------------------
select ok(
  has_schema_privilege('authenticated', 'api_v1', 'usage')
  and not has_schema_privilege('anon', 'api_v1', 'usage')
  and not has_schema_privilege('anon', 'api_v1', 'create')
  and not has_schema_privilege('authenticated', 'api_v1', 'create'),
  'api_v1 : USAGE à authenticated seulement, CREATE à personne'
);
select is(
  (select count(*)::int from pg_namespace n, aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) x
    where n.nspname = 'api_v1' and x.grantee = 0),
  0,
  'api_v1 : aucun droit pour PUBLIC'
);
select is(
  (select count(*)::int from pg_proc p where p.pronamespace = 'api_v1'::regnamespace),
  2,
  'api_v1 contient exactement 2 fonctions'
);
select is(
  (select count(*)::int from pg_proc p
    where p.pronamespace = 'api_v1'::regnamespace
      and (not p.prosecdef or p.proconfig is distinct from array['search_path=public, pg_temp'] or p.provolatile <> 's')),
  0,
  'Toute fonction de api_v1 : security definer, stable, search_path = public, pg_temp'
);
select is(
  (select count(*)::int from pg_proc p
    where p.pronamespace = 'api_v1'::regnamespace
      and (has_function_privilege('anon', p.oid, 'execute') or not has_function_privilege('authenticated', p.oid, 'execute'))),
  0,
  'Toute fonction de api_v1 : EXECUTE à authenticated, jamais à anon'
);
select is(
  (select count(*)::int from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
    where p.pronamespace = 'api_v1'::regnamespace and x.grantee = 0),
  0,
  'Toute fonction de api_v1 : PUBLIC sans EXECUTE'
);
select is(
  (select count(*)::int from pg_class c where c.relnamespace = 'api_v1'::regnamespace),
  0,
  'api_v1 ne contient ni table ni vue'
);

-- Anonyme et connecté sans utilisateur ----------------------------------------------------------------------------------------------
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select * from api_v1.my_gm_groups() $$, '42501', 'permission denied for schema api_v1',
  'Anonyme : my_gm_groups refusée (schéma)');
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001') $$, '42501',
  'permission denied for schema api_v1', 'Anonyme : group_snapshot refusée (schéma)');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok($$ select * from api_v1.my_gm_groups() $$, '28000', 'not_authenticated', 'Sans utilisateur : my_gm_groups not_authenticated');
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001') $$, '28000', 'not_authenticated',
  'Sans utilisateur : group_snapshot not_authenticated');
reset role;

-- Propriétaire avec ligne MJ (Olga) -------------------------------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
insert into ctx select 'olga_groups', coalesce(jsonb_agg(to_jsonb(r)), '[]') from api_v1.my_gm_groups() r;
insert into ctx select 'g1', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001');
insert into ctx select 'g1_again', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001');
insert into ctx select 'g1_overview', to_jsonb(o) from public.group_character_status_overview o
 where o.group_id = 'a6000000-0000-4000-8000-000000000001';
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-0000000000ff') $$, 'P0002', 'group_not_found',
  'Olga : groupe inconnu -> group_not_found');
select throws_ok($$ select api_v1.group_snapshot(null) $$, 'P0002', 'group_not_found', 'Olga : identifiant NULL -> group_not_found');
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000002') $$, 'P0002', 'group_not_found',
  'Olga : groupe d''un autre propriétaire dont elle n''est pas membre -> group_not_found');
reset role;

select is(jsonb_array_length((select v from ctx where k = 'olga_groups')), 2, 'my_gm_groups (Olga) : ses 2 groupes, rien d''autre');
select is(
  (select string_agg(e ->> 'id', ',' order by ord) from jsonb_array_elements((select v from ctx where k = 'olga_groups')) with ordinality as x(e, ord)),
  'a6000000-0000-4000-8000-000000000007,a6000000-0000-4000-8000-000000000001',
  'my_gm_groups : triés par nom'
);
select is(
  pg_temp.keys((select v -> 0 from ctx where k = 'olga_groups')),
  'dead_count,has_game_master,id,low_hp_count,member_count,name,owner_has_member_row,owner_plays_character,story_title',
  'my_gm_groups : colonnes exactes du contrat'
);
select is(
  (select e - 'id' - 'name' from jsonb_array_elements((select v from ctx where k = 'olga_groups')) e
    where e ->> 'id' = 'a6000000-0000-4000-8000-000000000001'),
  '{"dead_count": 1, "story_title": "La Mine perdue", "low_hp_count": 1, "member_count": 6, "has_game_master": true, "owner_has_member_row": true, "owner_plays_character": false}'::jsonb,
  'my_gm_groups G1 : 6 membres, 1 mort, 1 PV bas (Eryn à max_hp 0 exclue), MJ présent, propriétaire avec ligne, sans personnage'
);
select is(
  (select (e ->> 'dead_count')::int || '/' || (e ->> 'low_hp_count')::int from jsonb_array_elements((select v from ctx where k = 'olga_groups')) e
    where e ->> 'id' = 'a6000000-0000-4000-8000-000000000001'),
  (select (v ->> 'dead_count')::int || '/' || (v ->> 'low_hp_count')::int from ctx where k = 'g1_overview'),
  'my_gm_groups : mêmes compteurs que la vue group_character_status_overview (seuil de PV bas identique)'
);

-- Instantané de G1 : forme ----------------------------------------------------------------------------------------------------------
select is(pg_temp.keys((select v from ctx where k = 'g1')), 'fingerprint,group,members,unchanged,v', 'Instantané : clés de premier niveau exactes');
select is((select (v ->> 'v')::int from ctx where k = 'g1'), 1, 'Instantané : version 1');
select is((select (v -> 'unchanged')::text from ctx where k = 'g1'), 'false', 'Instantané : unchanged = false sans empreinte connue');
select ok((select v ->> 'fingerprint' ~ '^v1:[0-9a-f]{64}$' from ctx where k = 'g1'), 'Empreinte : « v1: » + sha256 hexadécimal');
select is(
  (select v -> 'group' from ctx where k = 'g1'),
  '{"id": "a6000000-0000-4000-8000-000000000001", "name": "pgTAP api_v1 G1", "story_title": "La Mine perdue", "has_game_master": true, "story_summary_public": "Résumé public de la campagne."}'::jsonb,
  'Groupe : id, nom, titre, résumé public, présence d''un MJ (rien d''autre)'
);
select is(jsonb_array_length((select v -> 'members' from ctx where k = 'g1')), 6, 'G1 : 6 membres');
select is(
  (select count(*)::int from jsonb_array_elements((select v -> 'members' from ctx where k = 'g1')) m
    where pg_temp.keys(m) <> 'character,display_name,is_game_master,is_owner,membership_id,role,user_id'),
  0,
  'Chaque membre : clés exactes du contrat'
);
select is(
  (select count(*)::int from jsonb_array_elements((select v -> 'members' from ctx where k = 'g1')) m
    where m -> 'character' <> 'null'::jsonb
      and pg_temp.keys(m -> 'character') <> 'armor_class,armor_class_bonus,armor_class_total,classes,conditions,current_hp,id,is_dead,max_hp,name,portrait_url,race_name,temporary_hp,total_level'),
  0,
  'Chaque personnage : clés exactes du contrat'
);
select is(
  (select count(*)::int from jsonb_array_elements((select v -> 'members' from ctx where k = 'g1')) m
    where m -> 'character' <> 'null'::jsonb),
  5,
  'G1 : 5 personnages'
);
select is(
  pg_temp.keys(pg_temp.member((select v from ctx where k = 'g1'), '02') -> 'character' -> 'classes' -> 0),
  'class_id,class_name,level,subclass_id,subclass_name',
  'Chaque classe : clés exactes du contrat'
);
select is(
  (select v -> 'members' -> 0 ->> 'user_id' from ctx where k = 'g1'),
  'a5000000-0000-4000-8000-000000000001',
  'Membres : le propriétaire en premier'
);
select is(
  (select string_agg(m ->> 'user_id', ',' order by ord) from jsonb_array_elements((select v -> 'members' from ctx where k = 'g1')) with ordinality as x(m, ord)),
  'a5000000-0000-4000-8000-000000000001,a5000000-0000-4000-8000-000000000002,a5000000-0000-4000-8000-000000000003,a5000000-0000-4000-8000-000000000004,a5000000-0000-4000-8000-000000000005,a5000000-0000-4000-8000-000000000006',
  'Membres : puis par date d''adhésion'
);

-- Instantané de G1 : valeurs ----------------------------------------------------------------------------------------------------------
select is(
  pg_temp.member((select v from ctx where k = 'g1'), '01') - 'membership_id',
  '{"role": "owner", "user_id": "a5000000-0000-4000-8000-000000000001", "is_owner": true, "character": null, "display_name": null, "is_game_master": true}'::jsonb,
  'Propriétaire MJ : sans personnage, pseudo blanc -> null'
);
select is(
  (select m ->> 'membership_id' from jsonb_array_elements((select v -> 'members' from ctx where k = 'g1')) m
    where m ->> 'user_id' = 'a5000000-0000-4000-8000-000000000002'),
  (select id::text from public.group_members where group_id = 'a6000000-0000-4000-8000-000000000001' and user_id = 'a5000000-0000-4000-8000-000000000002'),
  'membership_id = group_members.id (filtre des DELETE temps réel)'
);
select is(pg_temp.member((select v from ctx where k = 'g1'), '02') ->> 'display_name', 'Bran le Brave', 'Pseudo du membre');
select is(pg_temp.member((select v from ctx where k = 'g1'), '05') -> 'display_name', 'null'::jsonb, 'Pseudo absent -> null');
select is(
  (pg_temp.member((select v from ctx where k = 'g1'), '02') -> 'character') - 'classes',
  '{"id": "a7000000-0000-4000-8000-000000000002", "name": "Bran", "max_hp": 30, "is_dead": false, "race_name": "Nain", "conditions": ["poisoned", "prone"], "current_hp": 20, "armor_class": 18, "total_level": 5, "portrait_url": "https://exemple.supabase.co/storage/v1/object/public/character-portraits/a5000000-0000-4000-8000-000000000002/bran.png", "temporary_hp": 5, "armor_class_bonus": 1, "armor_class_total": 19}'::jsonb,
  'Bran : nom, portrait, race, niveau total, PV, états triés sans doublon, CA 18 + ajustement 1 = 19'
);
select is(
  pg_temp.member((select v from ctx where k = 'g1'), '02') -> 'character' -> 'classes',
  (select jsonb_build_array(
     jsonb_build_object('class_id', (select min(entity_id::int) from public.translations where entity_type = 'class' and locale = 'fr' and field_name = 'name' and value = 'Guerrier'),
                        'class_name', 'Guerrier', 'subclass_id', null, 'subclass_name', null, 'level', 3),
     jsonb_build_object('class_id', (select min(entity_id::int) from public.translations where entity_type = 'class' and locale = 'fr' and field_name = 'name' and value = 'Barbare'),
                        'class_name', 'Barbare', 'subclass_id', null, 'subclass_name', null, 'level', 2))),
  'Bran : classes et niveaux, classe principale en premier, noms français'
);
select is(pg_temp.member((select v from ctx where k = 'g1'), '03') -> 'character' ->> 'race_name', 'Tieffeline des abysses',
  'Race personnalisée prioritaire (comme la fiche de Nexus)');
select is(pg_temp.member((select v from ctx where k = 'g1'), '03') -> 'character' -> 'is_dead', 'true'::jsonb, 'Mort : is_dead');
select is(
  (pg_temp.member((select v from ctx where k = 'g1'), '06') -> 'character') - 'id' - 'name',
  '{"max_hp": 12, "classes": [], "is_dead": false, "race_name": null, "conditions": [], "current_hp": 12, "armor_class": 10, "total_level": 0, "portrait_url": null, "temporary_hp": 0, "armor_class_bonus": 0, "armor_class_total": 10}'::jsonb,
  'Personnage sans classe ni score ni objet : listes vides, niveau 0, CA 10, valeurs nulles explicites'
);
select is(
  (select count(*)::int
     from jsonb_array_elements((select v -> 'members' from ctx where k = 'g1')) m
     join private.character_armor_class((m -> 'character' ->> 'id')::uuid) ac on true
    where m -> 'character' <> 'null'::jsonb
      and ((m -> 'character' ->> 'armor_class')::int, (m -> 'character' ->> 'armor_class_bonus')::int, (m -> 'character' ->> 'armor_class_total')::int)
          is distinct from (ac.armor_class, ac.armor_class_bonus, ac.armor_class_total)),
  0,
  'CA de chaque personnage = private.character_armor_class'
);

-- Minimisation : aucune donnée hors contrat ----------------------------------------------------------------------------------------
select is(
  (select count(*)::int from ctx, unnest(array['PGTAPAV1', 'SECRET-BACKSTORY', 'SECRET-TRAITS', 'SECRET-SHARE-TOKEN',
                                               'SECRET-INVENTORY-NOTE', 'SECRET-GROUP-NOTE', '987654321', '@test.local', 'invite',
                                               'owner_id', 'joined_at', 'updated_at', 'notes', 'inventory'])
                                        as s(marker)
    where ctx.k = 'g1' and strpos(ctx.v::text, s.marker) > 0),
  0,
  'Ni code d''invitation, ni histoire, traits, jeton de partage, notes, monnaie, e-mail, dates, inventaire'
);

-- Empreinte -------------------------------------------------------------------------------------------------------------------------
select is((select v from ctx where k = 'g1_again'), (select v from ctx where k = 'g1'), 'Deux appels successifs : même instantané, même empreinte');

-- Ordre physique des lignes, ordre des états, données hors contrat : l'empreinte ne bouge pas.
update public.group_members set role = role where group_id = 'a6000000-0000-4000-8000-000000000001';
update public.character_classes set level = level where character_id = 'a7000000-0000-4000-8000-000000000002';
update public.characters set name = name, backstory_text = 'AUTRE-HISTOIRE', currency_gp = 1
 where id in (select character_id from public.group_members where group_id = 'a6000000-0000-4000-8000-000000000001');
update public.characters set conditions = '["poisoned", "prone"]' where id = 'a7000000-0000-4000-8000-000000000002';
update public.groups set invite_code = 'PGTAPAV9' where id = 'a6000000-0000-4000-8000-000000000001';
-- La ligne de Bran est supprimée puis réinsérée à l'identique (nouvel emplacement physique).
create temp table bran_row as
  select * from public.group_members where group_id = 'a6000000-0000-4000-8000-000000000001' and user_id = 'a5000000-0000-4000-8000-000000000002';
delete from public.group_members where id = (select id from bran_row);
insert into public.group_members select * from bran_row;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
insert into ctx select 'g1_reordered', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001');
insert into ctx select 'g1_unchanged', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001', (select v ->> 'fingerprint' from ctx where k = 'g1'));
insert into ctx select 'g1_wrong_fp', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001', 'v1:0000');
reset role;

select is((select v from ctx where k = 'g1_reordered'), (select v from ctx where k = 'g1'),
  'Lignes réécrites ou réinsérées, états réordonnés, histoire, monnaie, code d''invitation et updated_at changés : même instantané');
select is(
  (select v from ctx where k = 'g1_unchanged'),
  jsonb_build_object('v', 1, 'unchanged', true, 'fingerprint', (select v ->> 'fingerprint' from ctx where k = 'g1')),
  'Empreinte connue égale : {v, unchanged: true, fingerprint} sans contenu'
);
select is((select v from ctx where k = 'g1_wrong_fp'), (select v from ctx where k = 'g1'), 'Empreinte connue différente : instantané complet');

-- Changements du contrat : l'empreinte change.
create function pg_temp.fp_after(p_label text) returns text
language plpgsql as $$
declare
  v text;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
  v := api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001') ->> 'fingerprint';
  reset role;
  insert into ctx values (p_label, to_jsonb(v));
  return v;
end;
$$;

update public.characters set current_hp = 19 where id = 'a7000000-0000-4000-8000-000000000002';
select isnt(pg_temp.fp_after('fp_hp'), (select v ->> 'fingerprint' from ctx where k = 'g1'), 'PV actuels changés : nouvelle empreinte');
update public.character_inventory set equipped = false
 where character_id = 'a7000000-0000-4000-8000-000000000002'
   and item_id = (select min(entity_id::int) from public.translations where entity_type = 'item' and locale = 'fr' and field_name = 'name' and value = 'Bouclier');
select isnt(pg_temp.fp_after('fp_ac'), (select v #>> '{}' from ctx where k = 'fp_hp'), 'Bouclier retiré (CA 18 -> 16) : nouvelle empreinte');
update auth.users set raw_user_meta_data = '{"full_name": "Bran"}' where id = 'a5000000-0000-4000-8000-000000000002';
select isnt(pg_temp.fp_after('fp_pseudo'), (select v #>> '{}' from ctx where k = 'fp_ac'), 'Pseudo changé : nouvelle empreinte');
update public.groups set story_title = 'La Mine retrouvée' where id = 'a6000000-0000-4000-8000-000000000001';
select isnt(pg_temp.fp_after('fp_title'), (select v #>> '{}' from ctx where k = 'fp_pseudo'), 'Titre de campagne changé : nouvelle empreinte');

-- Taille réelle (5 personnages) --------------------------------------------------------------------------------------------------
select ok(
  (select octet_length(v::text) between 1000 and 8192 from ctx where k = 'g1'),
  'Instantané de 5 personnages : entre 1 et 8 Ko (' || (select octet_length(v::text) from ctx where k = 'g1') || ' octets)'
);

-- Propriétaire qui joue un personnage (Gwen) -----------------------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000007', 'role', 'authenticated')::text, true);
insert into ctx select 'gwen_groups', coalesce(jsonb_agg(to_jsonb(r)), '[]') from api_v1.my_gm_groups() r;
insert into ctx select 'g2', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000002');
reset role;
select is(
  (select (v -> 0) - 'name' - 'story_title' from ctx where k = 'gwen_groups'),
  '{"id": "a6000000-0000-4000-8000-000000000002", "dead_count": 0, "low_hp_count": 0, "member_count": 2, "has_game_master": false, "owner_has_member_row": true, "owner_plays_character": true}'::jsonb,
  'my_gm_groups (propriétaire qui joue) : pas de MJ, ligne avec personnage (« Devenir MJ » possible)'
);
select is(
  (select (m -> 'is_owner')::text || '/' || (m -> 'character' ->> 'name') from ctx, jsonb_array_elements(ctx.v -> 'members') m
    where ctx.k = 'g2' and m ->> 'user_id' = 'a5000000-0000-4000-8000-000000000007'),
  'true/Gwenaëlle',
  'Instantané (propriétaire qui joue) : servi, son propre personnage inclus'
);
select is((select v -> 'group' -> 'has_game_master' from ctx where k = 'g2'), 'false'::jsonb, 'Instantané G2 : has_game_master = false');

-- Propriétaire SANS ligne de membre (Hugo) : élargissement assumé ----------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000008', 'role', 'authenticated')::text, true);
insert into ctx select 'hugo_groups', coalesce(jsonb_agg(to_jsonb(r)), '[]') from api_v1.my_gm_groups() r;
insert into ctx select 'g3', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000003');
insert into ctx select 'hugo_rls', jsonb_build_object(
  'members', (select count(*) from public.group_members where group_id = 'a6000000-0000-4000-8000-000000000003'),
  'characters', (select count(*) from public.characters where id = 'a7000000-0000-4000-8000-000000000003'));
reset role;
select is(
  (select (v -> 0) - 'name' - 'story_title' from ctx where k = 'hugo_groups'),
  '{"id": "a6000000-0000-4000-8000-000000000003", "dead_count": 1, "low_hp_count": 0, "member_count": 1, "has_game_master": false, "owner_has_member_row": false, "owner_plays_character": false}'::jsonb,
  'my_gm_groups (propriétaire sans ligne) : listé, sans ligne ni MJ'
);
select is(
  (select v -> 'members' -> 0 -> 'character' ->> 'name' from ctx where k = 'g3'),
  'Cyra',
  'Instantané (propriétaire sans ligne) : servi, personnage du membre inclus'
);
select is(jsonb_array_length((select v -> 'members' from ctx where k = 'g3')), 1,
  'Instantané (propriétaire sans ligne) : seulement les membres de CE groupe (Cyra est aussi dans G1)');
select is((select v from ctx where k = 'hugo_rls'), '{"members": 0, "characters": 0}'::jsonb,
  'Lecture directe inchangée : la RLS ne lui donne toujours ni les membres ni la fiche (élargissement limité à l''instantané)');

-- Propriétaire parti (Ilse quitte son groupe elle-même) -------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000009', 'role', 'authenticated')::text, true);
insert into ctx select 'ilse_before', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000004');
delete from public.group_members where group_id = 'a6000000-0000-4000-8000-000000000004' and user_id = 'a5000000-0000-4000-8000-000000000009';
insert into ctx select 'ilse_groups', coalesce(jsonb_agg(to_jsonb(r)), '[]') from api_v1.my_gm_groups() r;
insert into ctx select 'g4', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000004');
reset role;
select is(jsonb_array_length((select v -> 'members' from ctx where k = 'ilse_before')), 2, 'Avant son départ : 2 membres');
select is(
  (select (v -> 0 ->> 'owner_has_member_row') || '/' || (v -> 0 ->> 'has_game_master') || '/' || (v -> 0 ->> 'member_count') from ctx where k = 'ilse_groups'),
  'false/false/1',
  'my_gm_groups (propriétaire parti) : toujours listé, sans ligne, sans MJ, 1 membre'
);
select is(
  (select (v -> 'members' -> 0 ->> 'user_id') || '/' || jsonb_array_length(v -> 'members') from ctx where k = 'g4'),
  'a5000000-0000-4000-8000-000000000004/1',
  'Instantané (propriétaire parti) : servi, sans sa ligne'
);
select isnt((select v ->> 'fingerprint' from ctx where k = 'g4'), (select v ->> 'fingerprint' from ctx where k = 'ilse_before'),
  'Départ du propriétaire : nouvelle empreinte');

-- Propriétaire orphelin (Jorn) ----------------------------------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000011', 'role', 'authenticated')::text, true);
insert into ctx select 'jorn_groups', coalesce(jsonb_agg(to_jsonb(r)), '[]') from api_v1.my_gm_groups() r;
insert into ctx select 'g5', api_v1.group_snapshot('a6000000-0000-4000-8000-000000000005');
reset role;
select is(
  (select (v -> 0 ->> 'owner_has_member_row') || '/' || (v -> 0 ->> 'owner_plays_character') || '/' || (v -> 0 ->> 'has_game_master') from ctx where k = 'jorn_groups'),
  'true/false/false',
  'my_gm_groups (propriétaire orphelin) : ligne sans personnage, pas MJ'
);
select is(
  (select (v -> 'members' -> 0 -> 'character')::text || '/' || (v -> 'members' -> 0 -> 'is_game_master')::text from ctx where k = 'g5'),
  'null/false',
  'Instantané (propriétaire orphelin) : personnage null, pas MJ'
);

-- Membre non propriétaire (Bran) ---------------------------------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000002', 'role', 'authenticated')::text, true);
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001') $$, '42501', 'not_group_owner',
  'Membre non propriétaire : not_group_owner');
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001', 'v1:0000') $$, '42501', 'not_group_owner',
  'Membre non propriétaire avec une empreinte : not_group_owner (les droits passent avant l''empreinte)');
select is((select count(*)::int from api_v1.my_gm_groups()), 0, 'Membre non propriétaire : my_gm_groups vide (aucun groupe à lui)');
reset role;

-- Tiers ----------------------------------------------------------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000010', 'role', 'authenticated')::text, true);
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000001') $$, 'P0002', 'group_not_found',
  'Tiers : group_not_found (existence non révélée)');
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000003') $$, 'P0002', 'group_not_found',
  'Tiers : group_not_found sur le groupe d''un propriétaire sans ligne');
select is((select count(*)::int from api_v1.my_gm_groups()), 0, 'Tiers : my_gm_groups vide');
reset role;

-- has_game_master = group_has_gm pour tous les groupes des fixtures ------------------------------------------------------------
select is(
  (select count(*)::int from ctx, jsonb_array_elements(ctx.v) e
    where ctx.k in ('olga_groups', 'gwen_groups', 'hugo_groups', 'ilse_groups', 'jorn_groups')
      and (e ->> 'has_game_master')::boolean is distinct from public.group_has_gm((e ->> 'id')::uuid)),
  0,
  'my_gm_groups.has_game_master = group_has_gm pour chaque groupe'
);
select is(
  (select count(*)::int from ctx where ctx.k in ('g1', 'g2', 'g3', 'g4', 'g5')
      and (ctx.v -> 'group' ->> 'has_game_master')::boolean is distinct from public.group_has_gm((ctx.v -> 'group' ->> 'id')::uuid)),
  0,
  'group_snapshot.group.has_game_master = group_has_gm'
);

-- Propriétaire NULL (hypothétique : groups.owner_id est NOT NULL aujourd'hui) -----------------------------------------------------
-- Si owner_id devenait nullable, `v_owner <> v_uid` vaudrait NULL et sauterait le refus : la fonction compare par
-- IS DISTINCT FROM. NOT NULL retiré dans la transaction du test seulement (annulée à la fin).
alter table public.groups alter column owner_id drop not null;
insert into public.groups (id, name, owner_id, invite_code)
values ('a6000000-0000-4000-8000-000000000008', 'pgTAP api_v1 G8 (sans propriétaire)', null, 'PGTAPAV8');
insert into public.group_members (group_id, character_id, user_id, role)
values ('a6000000-0000-4000-8000-000000000008', 'a7000000-0000-4000-8000-000000000003', 'a5000000-0000-4000-8000-000000000003', 'membre');
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000003', 'role', 'authenticated')::text, true);
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000008') $$, '42501', 'not_group_owner',
  'Propriétaire NULL, appelant membre : not_group_owner (refus jamais sauté)');
select is((select count(*)::int from api_v1.my_gm_groups() r where r.id = 'a6000000-0000-4000-8000-000000000008'), 0,
  'Propriétaire NULL : le groupe n''est dans la liste de personne');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'a5000000-0000-4000-8000-000000000010', 'role', 'authenticated')::text, true);
select throws_ok($$ select api_v1.group_snapshot('a6000000-0000-4000-8000-000000000008') $$, 'P0002', 'group_not_found',
  'Propriétaire NULL, appelant tiers : group_not_found');
reset role;

-- Aucune écriture ------------------------------------------------------------------------------------------------------------------
select is(
  (select count(*)::int from pg_proc p
    where p.pronamespace = 'api_v1'::regnamespace
      and pg_get_functiondef(p.oid) ~* '\m(insert|update|delete|truncate)\M'),
  0,
  'Les fonctions de api_v1 ne contiennent aucune écriture'
);

select * from finish();
rollback;
