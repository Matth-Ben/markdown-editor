-- Complète supabase/tests/character_campaigns_rls_test.sql (même patron) :
-- vérifie 20261013100000_group_member_without_character.sql -- un joueur
-- peut créer/rejoindre un groupe SANS personnage (MJ sans personnage,
-- décision du 12/10/2026, 12-partage-et-groupes.md section 2), au plus UN
-- par groupe, et sans régression sur l'accès en lecture déjà en place
-- (`is_group_member`, `group_member_can_read_character`,
-- `get_group_member_character`) pour ce nouveau cas comme pour le cas
-- normal (membre avec personnage).
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- (depuis la racine du dépôt web, stack local démarré au préalable via
-- `supabase start`). BEGIN/ROLLBACK en fin de fichier : aucune donnée de
-- test ne persiste, le fichier est rejouable à volonté sans nettoyage
-- manuel ni collision avec des données réelles.

begin;

select plan(7);

-- Fixtures : un MJ sans personnage (gm, owner du groupe), deux joueurs avec
-- chacun leur personnage (player1/character1, player2/character2), et un
-- tiers sans aucune relation (stranger). Insérés en tant que `postgres`
-- (rôle superuser du test runner pgTAP), qui contourne RLS.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('77777777-7777-7777-7777-777777777771', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-gm-no-char@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('77777777-7777-7777-7777-777777777772', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-group-player1@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('77777777-7777-7777-7777-777777777773', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-group-player2@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('77777777-7777-7777-7777-777777777774', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-group-stranger@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.groups (id, name, owner_id, invite_code)
values ('88888888-8888-8888-8888-888888888881', 'pgTAP group (MJ sans personnage)', '77777777-7777-7777-7777-777777777771', 'PGTAPGR1');

insert into public.characters (id, owner_id, name)
values
  ('99999999-9999-9999-9999-999999999991', '77777777-7777-7777-7777-777777777772', 'pgTAP Group Hero 1'),
  ('99999999-9999-9999-9999-999999999992', '77777777-7777-7777-7777-777777777773', 'pgTAP Group Hero 2');

-- Le MJ rejoint son propre groupe sans personnage (character_id = null),
-- comme le ferait désormais create-group pour un créateur sans personnage.
insert into public.group_members (group_id, character_id, user_id, role)
values ('88888888-8888-8888-8888-888888888881', null, '77777777-7777-7777-7777-777777777771', 'owner');

-- player1 rejoint le même groupe avec son personnage, comme le ferait
-- join-group pour un membre normal.
insert into public.group_members (group_id, character_id, user_id, role)
values ('88888888-8888-8888-8888-888888888881', '99999999-9999-9999-9999-999999999991', '77777777-7777-7777-7777-777777777772', 'membre');

-- Test 1 : un deuxième membre SANS personnage dans le même groupe doit être
-- rejeté par l'index unique partiel group_members_one_null_character_per_group
-- ("un seul MJ sans personnage par groupe").
select throws_ok(
  $$ insert into public.group_members (group_id, character_id, user_id, role)
     values ('88888888-8888-8888-8888-888888888881', null, '77777777-7777-7777-7777-777777777773', 'membre') $$,
  '23505',
  null,
  'Un deuxième membre sans personnage dans le même groupe doit être rejeté (au plus un MJ sans personnage par groupe)'
);

-- Test 2 : un personnage ne peut toujours pas rejoindre deux fois le même
-- groupe (index unique partiel group_members_group_id_character_id_key,
-- qui remplace l'ancienne garantie de l'unicité implicite de la PK
-- composite (group_id, character_id)). Utilise volontairement un user_id
-- différent de celui qui possède déjà character1 dans ce groupe : la
-- contrainte testée ici porte sur (group_id, character_id), indépendamment
-- de group_members_group_id_user_id_key qui, elle, ne porte que sur
-- (group_id, user_id).
select throws_ok(
  $$ insert into public.group_members (group_id, character_id, user_id, role)
     values ('88888888-8888-8888-8888-888888888881', '99999999-9999-9999-9999-999999999991', '77777777-7777-7777-7777-777777777774', 'membre') $$,
  '23505',
  null,
  'Un même personnage ne peut pas rejoindre deux fois le même groupe (index unique partiel group_id/character_id)'
);

-- Test 3 (contrôle positif, cas normal) : is_group_member reste vrai pour un
-- membre avec personnage -- aucune régression du cas déjà en place.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '77777777-7777-7777-7777-777777777772', 'role', 'authenticated')::text,
  true
);

select ok(
  (select public.is_group_member('88888888-8888-8888-8888-888888888881')),
  'is_group_member doit rester vrai pour un membre normal (avec personnage)'
);

reset role;

-- Test 4 : is_group_member est vrai pour le MJ SANS personnage -- la
-- fonction ne déréférence jamais character_id, voir le commentaire de
-- 20261013100000_group_member_without_character.sql.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '77777777-7777-7777-7777-777777777771', 'role', 'authenticated')::text,
  true
);

select ok(
  (select public.is_group_member('88888888-8888-8888-8888-888888888881')),
  'is_group_member doit être vrai pour le MJ sans personnage (viewer identifié par user_id, jamais par character_id)'
);

-- Test 5 : group_member_can_read_character laisse le MJ sans personnage lire
-- la fiche complète de player1 (characters), via la policy "Group member
-- can select teammates' characters" -- toujours en tant que
-- 77777777-7777-7777-7777-777777777771 (set plus haut).
select is(
  (select count(*)::int from public.characters where id = '99999999-9999-9999-9999-999999999991'),
  1,
  'Le MJ sans personnage doit pouvoir lire la fiche complète (characters) d''un coéquipier du même groupe'
);

-- Test 6 : get_group_member_character renvoie bien la fiche complète de
-- player1 pour le MJ sans personnage appelant (toujours
-- 77777777-7777-7777-7777-777777777771).
select ok(
  (select public.get_group_member_character(
    '88888888-8888-8888-8888-888888888881',
    '99999999-9999-9999-9999-999999999991'
  ) is not null),
  'get_group_member_character doit renvoyer la fiche complète d''un coéquipier pour un appelant MJ sans personnage'
);

reset role;

-- Test 7 (contrôle négatif) : un tiers sans aucune ligne group_members pour
-- ce groupe ne doit rien voir -- confirme que le nouvel index partiel n'a
-- pas élargi l'accès à qui que ce soit d'autre qu'un membre réel.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '77777777-7777-7777-7777-777777777774', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.characters where id = '99999999-9999-9999-9999-999999999991'),
  0,
  'Un tiers sans relation avec le groupe ne doit voir aucune ligne characters d''un membre de ce groupe'
);

reset role;

select * from finish();

rollback;
