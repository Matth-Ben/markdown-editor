-- Premier test pgTAP de ce dépôt (voir aussi supabase/functions/join-story/index.test.ts,
-- premier test Deno.test). Jusqu'ici, la vérification des policies RLS de
-- ce projet reposait uniquement sur des sessions psql manuelles (voir
-- l'historique de la session qui a introduit character_campaigns). On pose
-- ce précédent parce que le flux MJ <-> joueur (12-partage-et-groupes.md
-- section 5.4 du cahier des charges de l'app mobile) est exactement le
-- genre de logique d'autorisation inter-utilisateurs où une régression
-- silencieuse (ex. un futur "grant update" ou une policy trop permissive
-- ajoutée par erreur) coûte cher : un MJ qui pourrait écrire sur la fiche
-- d'un joueur, ou un tiers qui pourrait lire un personnage qui ne le
-- concerne pas.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- (depuis la racine du dépôt web, stack local démarré au préalable via
-- `supabase start`). BEGIN/ROLLBACK en fin de fichier : aucune donnée de
-- test ne persiste, le fichier est rejouable à volonté sans nettoyage
-- manuel ni collision avec des données réelles.

begin;

select plan(3);

-- Fixtures : un MJ (propriétaire de deux histoires), un joueur
-- (propriétaire d'un personnage rattaché à la première histoire via
-- character_campaigns), et un tiers sans aucune relation avec l'un ou
-- l'autre. Insérés en tant que `postgres` (rôle superuser du test runner
-- pgTAP), qui contourne RLS comme le ferait service_role.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-gm@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-player@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-stranger@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.stories (id, user_id, title, invite_code, invite_code_enabled)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'pgTAP story (linked)', 'PGTAP01', true),
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'pgTAP story (target of blocked insert)', 'PGTAP02', true);

insert into public.characters (id, owner_id, name)
values ('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'pgTAP Hero');

-- Rattachement déjà effectif (comme le ferait l'edge function join-story),
-- pour tester l'accès en lecture du MJ à un personnage réellement lié.
insert into public.character_campaigns (character_id, story_id, role)
values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'joueur');

-- Test 1 : un insert direct sur character_campaigns, tenté par le joueur
-- lui-même (propriétaire légitime du personnage), doit être rejeté par
-- RLS. Aucune policy `insert` n'existe sur cette table (voir
-- 20260830100100_create_character_campaigns.sql) : seule l'edge function
-- join-story (service_role) peut créer une ligne.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

select throws_ok(
  $$ insert into public.character_campaigns (character_id, story_id, role)
     values ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'joueur') $$,
  '42501',
  null,
  'Un insert direct sur character_campaigns doit être rejeté par RLS (aucune policy insert, RLS activée = deny-all)'
);

reset role;

-- Test 2 (contrôle positif) : le MJ propriétaire de l'histoire liée peut
-- lire le personnage rattaché, via la policy "Story owner can select
-- linked characters" (public.story_owner_can_read_character).
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '22222222-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.characters where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  1,
  'Le MJ propriétaire de l''histoire liée doit pouvoir lire le personnage rattaché (contrôle positif, valide la fixture avant le test 3)'
);

reset role;

-- Test 3 : un tiers sans relation (ni propriétaire du personnage, ni MJ
-- d'une histoire à laquelle il est rattaché) ne doit rien voir.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '33333333-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.characters where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  0,
  'Un tiers non-MJ, non-propriétaire ne doit voir aucune ligne characters pour un personnage rattaché à une autre histoire'
);

reset role;

select * from finish();

rollback;
