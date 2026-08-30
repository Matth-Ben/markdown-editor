-- Complète supabase/tests/character_campaigns_rls_test.sql : vérifie la
-- policy ajoutée par 20260830100300_add_character_owner_stories_select.sql
-- (trou de RLS signalé par dev-flutter en implémentant la carte "Aventures"
-- côté mobile — voir le commentaire d'en-tête de cette migration).
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- (depuis la racine du dépôt web, stack local démarré au préalable).
-- BEGIN/ROLLBACK en fin de fichier : aucune donnée de test ne persiste, le
-- fichier est rejouable à volonté sans nettoyage manuel ni collision avec
-- des données réelles.

begin;

select plan(3);

-- Fixtures : un MJ propriétaire d'une histoire, un joueur propriétaire d'un
-- personnage rattaché à cette histoire via character_campaigns, et un tiers
-- sans aucune relation. Insérés en tant que `postgres` (rôle superuser du
-- test runner pgTAP), qui contourne RLS.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-gm2@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-player2@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('66666666-6666-6666-6666-666666666666', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-stranger2@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.stories (id, user_id, title, cover_image_path, invite_code, invite_code_enabled)
values ('aaaaaaaa-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', 'pgTAP joined story', 'covers/pgtap.png', 'PGTAP03', true);

insert into public.characters (id, owner_id, name)
values ('bbbbbbbb-0000-0000-0000-000000000002', '55555555-5555-5555-5555-555555555555', 'pgTAP Joiner');

insert into public.character_campaigns (character_id, story_id, role)
values ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000003', 'joueur');

-- Test 1 : le joueur propriétaire du personnage rattaché peut lire
-- title/cover_image_path de l'histoire rejointe (character_owner_can_read_joined_story).
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '55555555-5555-5555-5555-555555555555', 'role', 'authenticated')::text,
  true
);

select results_eq(
  $$ select title, cover_image_path from public.stories where id = 'aaaaaaaa-0000-0000-0000-000000000003' $$,
  $$ values ('pgTAP joined story'::text, 'covers/pgtap.png'::text) $$,
  'Le joueur propriétaire du personnage rattaché doit pouvoir lire title/cover_image_path de l''histoire rejointe'
);

-- Test 2 (compromis accepté, verrouillé explicitement — voir le commentaire
-- de fin de 20260830100300_add_character_owner_stories_select.sql) : cette
-- policy est row-level, pas column-level, donc le joueur rattaché peut
-- AUSSI lire invite_code (pas seulement title/cover_image_path). Ce test
-- n'affirme pas que c'est souhaitable, seulement que c'est l'état actuel,
-- assumé et documenté — pour détecter toute dérive future dans un sens
-- (resserrement accidentel qui casserait la carte "Aventures") ou dans
-- l'autre (élargissement qui exposerait davantage sans qu'on s'en rende
-- compte).
select is(
  (select invite_code from public.stories where id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  'PGTAP03'::text,
  'Compromis accepté et documenté : le joueur rattaché peut aussi lire invite_code de l''histoire rejointe (pas seulement title/cover_image_path) — voir 12-partage-et-groupes.md section 5.4 sur l''effet limité d''une régénération de code tant que ce joueur reste rattaché'
);

reset role;

-- Test 3 : un tiers sans relation (ni propriétaire du personnage rattaché,
-- ni MJ de l'histoire) ne doit rien voir.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '66666666-6666-6666-6666-666666666666', 'role', 'authenticated')::text,
  true
);

select is(
  (select count(*)::int from public.stories where id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  0,
  'Un tiers non rattaché (ni joueur, ni MJ) ne doit voir aucune ligne stories pour cette histoire'
);

reset role;

select * from finish();

rollback;
