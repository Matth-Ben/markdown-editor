-- Vérifie 20261007100000_character_spells_innate_uses_and_shared_source_class.sql
-- (chantier "Personnages", app mobile) :
--   1. character_spells.innate_uses_spent : présent, 0 par défaut, jamais
--      négatif, modifiable par le propriétaire UNIQUEMENT (ni un tiers, ni le
--      MJ d'une histoire liée, qui garde un accès en lecture seule) ;
--   (et 20261007090000_revoke_build_character_sheet_json_execute.sql : voir
--   le bloc "Privilèges" en fin de fichier)
--   2. get_shared_character (donc build_character_sheet_json, corps commun
--      avec get_group_member_character) expose source_class_id et
--      innate_uses_spent pour chaque sort.
--
-- JAMAIS EXÉCUTÉ à ce jour (2026-10-07) : la base locale disponible lors de
-- l'écriture n'en était qu'à 19 migrations sur 121 et n'avait pas pgTAP.
-- Vérifié seulement par relecture, et par des contrôles manuels équivalents
-- (colonne, CHECK, policies UPDATE, privilèges) dans une transaction annulée
-- sur cette base partielle -- jamais l'appel réel de get_shared_character.
-- Hypothèse à confirmer à la première exécution : les tables temporaires
-- pgtap_innate_fixture et pgtap_innate_token, créées en tant que `postgres`,
-- sont lues sous les rôles anon et authenticated, ce qui suppose que ces
-- rôles ont le privilège TEMP sur la base. Si ce n'est pas le cas, les tests
-- concernés échoueront en "permission denied for schema pg_temp_N" : c'est
-- alors le test qu'il faut adapter, pas la migration.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- (depuis la racine du dépôt web, stack local démarré au préalable via
-- `supabase start`). BEGIN/ROLLBACK en fin de fichier : aucune donnée de
-- test ne persiste, le fichier est rejouable à volonté sans nettoyage
-- manuel ni collision avec des données réelles.

begin;

select plan(15);

-- Fixtures : un joueur propriétaire d'un personnage, un tiers sans aucune
-- relation, et un MJ propriétaire d'une histoire à laquelle le personnage
-- est rattaché. Insérés en tant que `postgres` (rôle superuser du test
-- runner pgTAP), qui contourne RLS comme le ferait service_role.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('a1a1a1a1-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-innate-owner@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('a2a2a2a2-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-innate-stranger@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('a3a3a3a3-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-innate-gm@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.characters (id, owner_id, name)
values ('dddddddd-0000-0000-0000-000000000001', 'a1a1a1a1-1111-1111-1111-111111111111', 'pgTAP Innate Hero');

-- Deux sorts distincts, quels qu'ils soient (les id sont générés par les
-- seeds) : le plus petit id devient un sort de classe ('connu', rattaché à
-- une classe), le suivant un sort inné racial ('inné', sans classe).
create temporary table pgtap_innate_fixture on commit drop as
select
  (select id from public.spells order by id limit 1) as class_spell_id,
  (select id from public.spells order by id offset 1 limit 1) as innate_spell_id,
  (select id from public.classes order by id limit 1) as class_id;
grant select on pgtap_innate_fixture to anon, authenticated;

insert into public.character_spells (character_id, spell_id, status, source_class_id)
select 'dddddddd-0000-0000-0000-000000000001', f.class_spell_id, 'connu', f.class_id
from pgtap_innate_fixture f;

-- innate_uses_spent volontairement omis : la valeur par défaut doit suffire
-- (c'est ce que font les versions de l'app antérieures à cette colonne).
insert into public.character_spells (character_id, spell_id, status, source_class_id)
select 'dddddddd-0000-0000-0000-000000000001', f.innate_spell_id, 'inné', null
from pgtap_innate_fixture f;

insert into public.stories (id, user_id, title, invite_code, invite_code_enabled)
values ('aaaaaaaa-0000-0000-0000-000000000007', 'a3a3a3a3-3333-3333-3333-333333333333', 'pgTAP GM story (innate test)', 'PGTAP07', true);

insert into public.character_campaigns (character_id, story_id, role)
values ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000007', 'joueur');

-- Test 1 : la colonne existe, NOT NULL, 0 par défaut.
select col_not_null('public', 'character_spells', 'innate_uses_spent', 'innate_uses_spent est NOT NULL');
select is(
  (select count(*)::int from public.character_spells
   where character_id = 'dddddddd-0000-0000-0000-000000000001' and innate_uses_spent = 0),
  2,
  'innate_uses_spent vaut 0 par défaut quand l''insert ne la nomme pas (anciennes versions de l''app)'
);

-- Test 2 : le propriétaire peut consommer un usage de son sort inné, avec
-- le filtre exact utilisé par l'app (character_id + spell_id + status).
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a1a1a1a1-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

update public.character_spells
set innate_uses_spent = 1
where character_id = 'dddddddd-0000-0000-0000-000000000001'
  and spell_id = (select innate_spell_id from pgtap_innate_fixture)
  and status = 'inné';

select results_eq(
  $$ select status, innate_uses_spent from public.character_spells
     where character_id = 'dddddddd-0000-0000-0000-000000000001'
     order by status $$,
  $$ values ('connu'::text, 0), ('inné'::text, 1) $$,
  'Le propriétaire peut mettre à jour innate_uses_spent de son sort inné, sans toucher à la ligne non innée'
);

-- Test 3 : une valeur négative est rejetée par la contrainte CHECK.
select throws_ok(
  $$ update public.character_spells
     set innate_uses_spent = -1
     where character_id = 'dddddddd-0000-0000-0000-000000000001' and status = 'inné' $$,
  '23514',
  null,
  'innate_uses_spent ne peut pas être négatif (CHECK >= 0)'
);

-- Test 4 : aucune borne haute en base -- la fréquence d'usage est une règle
-- de l'app, pas une contrainte de schéma.
select lives_ok(
  $$ update public.character_spells
     set innate_uses_spent = 3
     where character_id = 'dddddddd-0000-0000-0000-000000000001' and status = 'inné' $$,
  'innate_uses_spent n''est pas borné en base (fréquence par race/don laissée à l''app)'
);

-- Remise à l'état "un usage dépensé" pour la suite.
update public.character_spells
set innate_uses_spent = 1
where character_id = 'dddddddd-0000-0000-0000-000000000001' and status = 'inné';

reset role;

-- Test 5 : un tiers ne voit pas la ligne et ne peut pas la modifier (la
-- policy UPDATE filtre la ligne : 0 ligne touchée, pas d'erreur).
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a2a2a2a2-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);

with attempted as (
  update public.character_spells
  set innate_uses_spent = 0
  where character_id = 'dddddddd-0000-0000-0000-000000000001'
  returning id
)
select is(
  (select count(*)::int from attempted),
  0,
  'Un tiers ne peut modifier innate_uses_spent d''aucun sort du personnage d''un autre'
);

reset role;

-- Test 6 : le MJ de l'histoire liée LIT la valeur (policy "Story owner can
-- select linked character_spells") mais ne peut pas l'écrire.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a3a3a3a3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);

select results_eq(
  $$ select innate_uses_spent from public.character_spells
     where character_id = 'dddddddd-0000-0000-0000-000000000001' and status = 'inné' $$,
  $$ values (1) $$,
  'Le MJ d''une histoire liée lit innate_uses_spent (lecture seule)'
);
with attempted as (
  update public.character_spells
  set innate_uses_spent = 0
  where character_id = 'dddddddd-0000-0000-0000-000000000001'
  returning id
)
select is(
  (select count(*)::int from attempted),
  0,
  'Le MJ d''une histoire liée ne peut pas modifier innate_uses_spent'
);

reset role;

-- Les deux tentatives d'écriture ci-dessus n'ont rien changé.
select is(
  (select innate_uses_spent from public.character_spells
   where character_id = 'dddddddd-0000-0000-0000-000000000001' and status = 'inné'),
  1,
  'La valeur écrite par le propriétaire est intacte après les tentatives du tiers et du MJ'
);

-- Tests 7 et 8 : la fiche partagée expose source_class_id et innate_uses_spent
-- pour chaque sort. Le propriétaire active le partage, un lecteur anonyme
-- lit avec le token.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a1a1a1a1-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);
select public.regenerate_character_share_token('dddddddd-0000-0000-0000-000000000001');
reset role;

-- Le token est relevé en tant que `postgres` : le rôle anon ne lit pas
-- public.characters (RLS), il ne connaît que le token qu'on lui transmet.
create temporary table pgtap_innate_token on commit drop as
select share_token from public.characters
where id = 'dddddddd-0000-0000-0000-000000000001';
grant select on pgtap_innate_token to anon;

set local role anon;
select results_eq(
  $$ select
       spell->>'status',
       (spell->>'spell_id')::int,
       (spell->>'source_class_id')::int,
       (spell->>'innate_uses_spent')::int
     from jsonb_array_elements(
       public.get_shared_character(
         (select share_token from pgtap_innate_token)
       )->'spells'
     ) as spell
     order by 1 $$,
  $$ select 'connu'::text, f.class_spell_id, f.class_id, 0 from pgtap_innate_fixture f
     union all
     select 'inné'::text, f.innate_spell_id, null::int, 1 from pgtap_innate_fixture f
     order by 1 $$,
  'get_shared_character expose source_class_id et innate_uses_spent pour chaque sort'
);
-- La clé est présente (valeur JSON null) même sans classe d'origine, pour
-- que le client distingue "sans classe" de "fonction pas encore migrée".
select ok(
  (
    select bool_and(spell ? 'source_class_id' and spell ? 'innate_uses_spent')
    from jsonb_array_elements(
      public.get_shared_character(
        (select share_token from pgtap_innate_token)
      )->'spells'
    ) as spell
  ),
  'Les clés source_class_id et innate_uses_spent sont toujours présentes dans les objets de spells'
);
reset role;

-- Privilèges (20261007090000_revoke_build_character_sheet_json_execute.sql) :
-- build_character_sheet_json est SECURITY DEFINER et sans contrôle d'accès
-- propre, elle ne doit JAMAIS être appelable directement -- ni par anon, ni
-- par authenticated (un `revoke ... from public` seul ne suffit pas sur ce
-- projet, voir l'en-tête de cette migration). get_shared_character, elle,
-- doit rester appelable par anon : c'est le lien public par token (les
-- tests 7 et 8 ci-dessus l'appellent d'ailleurs réellement sous ce rôle).
select ok(
  not has_function_privilege('anon', 'public.build_character_sheet_json(uuid)', 'execute'),
  'anon n''a pas EXECUTE sur build_character_sheet_json'
);
select ok(
  not has_function_privilege('authenticated', 'public.build_character_sheet_json(uuid)', 'execute'),
  'authenticated n''a pas EXECUTE sur build_character_sheet_json'
);
select ok(
  has_function_privilege('anon', 'public.get_shared_character(text)', 'execute'),
  'anon garde EXECUTE sur get_shared_character (lien public par token)'
);
-- Le refus est effectif à l'appel, pas seulement dans le catalogue.
set local role authenticated;
select throws_ok(
  $$ select public.build_character_sheet_json('dddddddd-0000-0000-0000-000000000001') $$,
  '42501',
  null,
  'Un appel direct à build_character_sheet_json par authenticated est refusé (42501)'
);
reset role;

select * from finish();

rollback;
