-- Vérifie 20261007110000_create_character_transactional_rpc.sql
-- (chantier "Personnages", app mobile, D05 du registre de dette technique
-- mobile) : `create_character` est SECURITY DEFINER et écrit dans
-- `characters` + plusieurs tables enfant pour le compte de l'appelant --
-- exactement la classe de fonction dont les privilèges EXECUTE ont déjà été
-- mal accordés deux fois sur ce projet par le passé (20260908094500,
-- 20261007090000, découverts seulement a posteriori par lecture manuelle).
--   1. Privilèges EXECUTE : anon et le pseudo-rôle PUBLIC n'ont PAS le droit
--      d'appeler create_character ; authenticated l'a.
--   2. Appel réussi en tant qu'authenticated : owner_id de la ligne
--      characters créée correspond au JWT utilisé pour l'appel, et la table
--      enfant character_classes est bien écrite dans la même transaction.
--   3. Atomicité : un paramètre qui viole une contrainte (FK class_id
--      inexistante) après que characters a déjà été inséré ne doit laisser
--      persister AUCUNE ligne characters -- le test que la seule relecture du
--      code ne peut pas garantir (une exception PL/pgSQL non interceptée
--      annule tout l'appel, voir le commentaire de tête de la migration).
--   4. Un jsonb malformé (p_ability_scores sans la clé "score" attendue)
--      produit une erreur Postgres (contrainte NOT NULL sur
--      character_ability_scores.score) plutôt qu'une insertion silencieuse
--      d'une valeur fausse.
--
-- Lancer : supabase test db supabase/tests --local (depuis la racine du
-- dépôt web, stack locale démarrée au préalable via `supabase start`, base
-- réinitialisée via `supabase db reset` pour rejouer toutes les migrations
-- depuis zéro). BEGIN/ROLLBACK en fin de fichier : aucune donnée de test ne
-- persiste, le fichier est rejouable à volonté sans nettoyage manuel ni
-- collision avec des données réelles.

begin;

select plan(9);

-- Fixtures : un joueur authentifié (propriétaire visé par les appels RPC
-- réussis) et une classe de référence quelconque (peu importe laquelle, les
-- id sont générés par les seeds). Inséré en tant que `postgres` (rôle
-- superuser du test runner pgTAP), qui contourne RLS comme le ferait
-- service_role.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('c1c1c1c1-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-create-character-owner@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

create temporary table pgtap_create_character_fixture on commit drop as
select (select id from public.classes order by id limit 1) as class_id;
grant select on pgtap_create_character_fixture to anon, authenticated;

-- Tests 1-3 : privilèges EXECUTE. Le pseudo-rôle "public" (PUBLIC) est
-- vérifiable directement par has_function_privilege, comme pour les rôles
-- nommés -- c'est ce qui distingue un `revoke ... from anon, authenticated,
-- public` complet d'un simple `revoke ... from public` qui ne suffirait pas
-- sur ce projet (privilèges par défaut accordés directement à anon et
-- authenticated, voir le commentaire de tête de la migration).
select ok(
  not has_function_privilege(
    'anon',
    'public.create_character(text, int, int, int, text, int, int, int, text, int, int, int, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, int, jsonb, jsonb, jsonb, jsonb, int[], jsonb, jsonb)',
    'execute'
  ),
  'anon n''a pas EXECUTE sur create_character'
);
select ok(
  not has_function_privilege(
    'public',
    'public.create_character(text, int, int, int, text, int, int, int, text, int, int, int, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, int, jsonb, jsonb, jsonb, jsonb, int[], jsonb, jsonb)',
    'execute'
  ),
  'le pseudo-rôle PUBLIC n''a pas EXECUTE sur create_character'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_character(text, int, int, int, text, int, int, int, text, int, int, int, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, int, jsonb, jsonb, jsonb, jsonb, int[], jsonb, jsonb)',
    'execute'
  ),
  'authenticated a EXECUTE sur create_character'
);

-- Tests 4-5 : appel réussi en tant qu'authenticated. owner_id vient
-- exclusivement de auth.uid() (jamais d'un paramètre), et la table enfant
-- character_classes est écrite dans le même appel.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'c1c1c1c1-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

create temporary table pgtap_create_character_result on commit drop as
select public.create_character(
  p_name => 'pgTAP RPC Hero',
  p_class_id => (select class_id from pgtap_create_character_fixture),
  p_hp_rolled => 8,
  p_max_hp => 10
) as character_id;
reset role;

select results_eq(
  $$ select owner_id from public.characters
     where id = (select character_id from pgtap_create_character_result) $$,
  $$ select 'c1c1c1c1-1111-1111-1111-111111111111'::uuid $$,
  'owner_id de la ligne characters créée correspond au JWT utilisé pour l''appel'
);
select results_eq(
  $$ select class_id, level, is_primary from public.character_classes
     where character_id = (select character_id from pgtap_create_character_result) $$,
  $$ select f.class_id, 1, true from pgtap_create_character_fixture f $$,
  'character_classes est écrit dans le même appel transactionnel (classe niveau 1, primaire)'
);

-- Tests 6-7 : atomicité. p_class_id inexistant viole la FK NOT NULL de
-- character_classes.class_id, APRÈS que characters ait déjà été inséré à
-- l'étape précédente de la fonction -- aucune ligne characters ne doit
-- persister.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'c1c1c1c1-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.create_character(
       p_name => 'pgTAP RPC FK Fail',
       p_class_id => -999,
       p_hp_rolled => 8,
       p_max_hp => 10
     ) $$,
  '23503',
  null,
  'p_class_id inexistant (FK) fait échouer tout l''appel (23503)'
);
reset role;

select is(
  (select count(*)::int from public.characters where name = 'pgTAP RPC FK Fail'),
  0,
  'Aucune ligne characters ne persiste après l''échec de la FK sur class_id (atomicité réelle, pas juste l''absence d''erreur)'
);

-- Tests 8-9 : jsonb malformé. p_ability_scores sans la clé "score" attendue
-- -> jsonb_to_recordset extrait NULL pour score -> la contrainte NOT NULL de
-- character_ability_scores.score lève une erreur, plutôt que d'insérer
-- silencieusement une valeur fausse (ex. 0).
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'c1c1c1c1-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.create_character(
       p_name => 'pgTAP RPC Malformed JSON',
       p_class_id => (select class_id from pgtap_create_character_fixture),
       p_hp_rolled => 8,
       p_max_hp => 10,
       p_ability_scores => '[{"ability_id":"str"}]'::jsonb
     ) $$,
  '23502',
  null,
  'p_ability_scores sans la clé "score" leve une erreur NOT NULL plutot qu''une insertion silencieuse (23502)'
);
reset role;

select is(
  (select count(*)::int from public.characters where name = 'pgTAP RPC Malformed JSON'),
  0,
  'Aucune ligne characters ne persiste après l''échec du jsonb malformé'
);

select * from finish();

rollback;
