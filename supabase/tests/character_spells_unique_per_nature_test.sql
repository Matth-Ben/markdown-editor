-- Vérifie 20261009090000_character_spells_unique_per_nature.sql (chantier
-- "Personnages", app mobile, D10 du registre de dette technique mobile,
-- suite de D56/D09) :
--   1-6. Les deux index uniques partiels empêchent bien un second doublon de
--        MÊME nature sur (character_id, spell_id) -- y compris un doublon
--        "ordinaire" qui change de status ('connu' puis 'préparé' sur le
--        même sort, pas juste une ligne identique répétée) -- mais
--        n'empêchent PAS la coexistence légitime d'une ligne 'inné' et d'une
--        ligne ordinaire pour le même sort (cas D43, déjà testé par
--        character_spells_innate_uses_test.sql pour la colonne
--        innate_uses_spent -- ce fichier teste la contrainte d'unicité, pas
--        cette colonne).
--   7-12. La requête de détection donnée en commentaire dans la migration
--        (reprise ici à l'identique, par nature) ne remonte rien tant qu'il
--        n'y a pas de doublon réel (7), puis les deux index sont retirés
--        temporairement pour injecter un vrai doublon de chaque nature sur
--        un second personnage, et la requête détecte alors exactement ces
--        deux groupes avec le bon compte de lignes (8). Après nettoyage
--        manuel (suppression de la ligne en trop, comme la migration le
--        demande), les deux index se recréent sans erreur (9-10), la requête
--        de détection ne remonte plus rien (11), et les index recréés sont
--        bien marqués uniques dans le catalogue système (12).
--
-- Lancer : supabase test db supabase/tests --local (depuis la racine du
-- dépôt web, stack locale démarrée au préalable via `supabase start`, base
-- réinitialisée via `supabase db reset`). BEGIN/ROLLBACK en fin de fichier :
-- aucune donnée de test ne persiste, y compris le DROP/CREATE INDEX du bloc
-- 8-10 (transactionnel comme le reste en PostgreSQL).

begin;

select plan(12);

-- Fixtures : un joueur propriétaire de deux personnages (l'un pour le test
-- de contrainte sous RLS, l'autre pour le test de détection qui a besoin de
-- vraies lignes dupliquées en base), et trois sorts distincts.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('b1b1b1b1-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-uniquespell-owner@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.characters (id, owner_id, name)
values
  ('eeeeeeee-0000-0000-0000-000000000001', 'b1b1b1b1-1111-1111-1111-111111111111', 'pgTAP Unique Spell Hero'),
  ('eeeeeeee-0000-0000-0000-000000000002', 'b1b1b1b1-1111-1111-1111-111111111111', 'pgTAP Unique Spell Hero 2 (detection)');

create temporary table pgtap_unique_spell_fixture on commit drop as
select
  (select id from public.spells order by id limit 1) as spell_1,
  (select id from public.spells order by id offset 1 limit 1) as spell_2,
  (select id from public.spells order by id offset 2 limit 1) as spell_3;
grant select on pgtap_unique_spell_fixture to anon, authenticated;

-- Bloc 1 : les index empêchent un doublon de même nature, sous RLS (en tant
-- que le propriétaire, filtre réel de l'app).
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b1b1b1b1-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true
);

-- Test 1 : une première ligne 'connu' sur spell_1 s'insère normalement.
select lives_ok(
  $$ insert into public.character_spells (character_id, spell_id, status)
     select 'eeeeeeee-0000-0000-0000-000000000001', spell_1, 'connu'
     from pgtap_unique_spell_fixture $$,
  'Une première ligne ''connu'' sur (character_id, spell_id) s''insère normalement'
);

-- Test 2 : une seconde ligne 'connu' sur le même sort est un doublon exact
-- (même nature ordinaire) -- rejetée par character_spells_unique_ordinary_per_spell.
select throws_ok(
  $$ insert into public.character_spells (character_id, spell_id, status)
     select 'eeeeeeee-0000-0000-0000-000000000001', spell_1, 'connu'
     from pgtap_unique_spell_fixture $$,
  '23505',
  null,
  'Un doublon exact (même status ''connu'') sur le même sort est rejeté (23505)'
);

-- Test 3 : une ligne 'préparé' sur le MÊME sort est aussi un doublon, même si
-- le status diffère -- 'connu' et 'préparé' sont la même "nature ordinaire"
-- pour cet index (status <> 'inné'), ce n'est pas une comparaison de status
-- exact.
select throws_ok(
  $$ insert into public.character_spells (character_id, spell_id, status)
     select 'eeeeeeee-0000-0000-0000-000000000001', spell_1, 'préparé'
     from pgtap_unique_spell_fixture $$,
  '23505',
  null,
  'Un changement de status (''préparé'') sur un sort déjà ''connu'' est aussi rejeté : même nature ordinaire (23505)'
);

-- Test 4 : une ligne 'inné' sur ce MÊME sort, elle, s'insère sans problème --
-- cas légitime D43 (sort racial inné appris aussi comme sort de classe).
select lives_ok(
  $$ insert into public.character_spells (character_id, spell_id, status)
     select 'eeeeeeee-0000-0000-0000-000000000001', spell_1, 'inné'
     from pgtap_unique_spell_fixture $$,
  'Une ligne ''inné'' coexiste avec la ligne ''connu'' du même sort (cas D43), les deux index sont disjoints'
);

-- Test 5 : une seconde ligne 'inné' sur ce sort, elle, est un doublon de
-- nature 'inné' -- rejetée par character_spells_unique_innate_per_spell.
select throws_ok(
  $$ insert into public.character_spells (character_id, spell_id, status)
     select 'eeeeeeee-0000-0000-0000-000000000001', spell_1, 'inné'
     from pgtap_unique_spell_fixture $$,
  '23505',
  null,
  'Un doublon ''inné'' sur un sort déjà ''inné'' est rejeté (23505)'
);

-- Test 6 : l'état final est exactement les deux lignes légitimes (D43),
-- aucune des tentatives rejetées n'a laissé de trace.
select results_eq(
  $$ select status from public.character_spells
     where character_id = 'eeeeeeee-0000-0000-0000-000000000001'
     order by status $$,
  $$ values ('connu'::text), ('inné'::text) $$,
  'Seules les deux lignes légitimes (une ordinaire, une inné) persistent pour ce sort'
);

reset role;

-- Bloc 2 : la requête de détection donnée dans la migration (en tant que
-- postgres, pour pouvoir retirer temporairement les index et injecter de
-- vrais doublons -- impossible sous RLS tant que les index existent).

-- Requête de détection réutilisée telle que documentée dans
-- 20261009090000_character_spells_unique_per_nature.sql, restreinte aux
-- personnages de ce test pour ne pas dépendre de ce qui existe par ailleurs.
create temporary table pgtap_unique_spell_detected on commit drop as
select character_id, spell_id, status, count(*) as nb_lignes
from public.character_spells
where character_id in ('eeeeeeee-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002')
  and status = 'inné'
group by character_id, spell_id, status
having count(*) > 1
union all
select character_id, spell_id, status, count(*) as nb_lignes
from public.character_spells
where character_id in ('eeeeeeee-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002')
  and status <> 'inné'
group by character_id, spell_id, status
having count(*) > 1;

-- Test 7 : avant toute manipulation, aucun doublon réel -- la requête ne
-- remonte rien (les deux lignes du bloc 1 sont de nature différente).
select is(
  (select count(*)::int from pgtap_unique_spell_detected),
  0,
  'La requête de détection ne remonte rien tant qu''aucun doublon réel n''existe'
);
drop table pgtap_unique_spell_detected;

-- On retire temporairement les deux index pour pouvoir injecter de vrais
-- doublons (sinon l'insertion elle-même échouerait -- exactement ce que le
-- bloc 1 vient de vérifier). Transactionnel comme le reste du fichier :
-- annulé par le ROLLBACK final, les index ne sont jamais réellement perdus.
drop index public.character_spells_unique_ordinary_per_spell;
drop index public.character_spells_unique_innate_per_spell;

-- Doublon "ordinaire" réel sur spell_2 (deux lignes 'connu').
insert into public.character_spells (character_id, spell_id, status)
select 'eeeeeeee-0000-0000-0000-000000000002', spell_2, 'connu' from pgtap_unique_spell_fixture;
insert into public.character_spells (character_id, spell_id, status)
select 'eeeeeeee-0000-0000-0000-000000000002', spell_2, 'connu' from pgtap_unique_spell_fixture;

-- Doublon "inné" réel sur spell_3 (deux lignes 'inné').
insert into public.character_spells (character_id, spell_id, status)
select 'eeeeeeee-0000-0000-0000-000000000002', spell_3, 'inné' from pgtap_unique_spell_fixture;
insert into public.character_spells (character_id, spell_id, status)
select 'eeeeeeee-0000-0000-0000-000000000002', spell_3, 'inné' from pgtap_unique_spell_fixture;

create temporary table pgtap_unique_spell_detected on commit drop as
select character_id, spell_id, status, count(*) as nb_lignes
from public.character_spells
where character_id in ('eeeeeeee-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002')
  and status = 'inné'
group by character_id, spell_id, status
having count(*) > 1
union all
select character_id, spell_id, status, count(*) as nb_lignes
from public.character_spells
where character_id in ('eeeeeeee-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002')
  and status <> 'inné'
group by character_id, spell_id, status
having count(*) > 1;

-- Test 8 : la requête détecte exactement les deux groupes injectés, avec le
-- bon compte de lignes chacun.
select results_eq(
  $$ select character_id, spell_id, status, nb_lignes
     from pgtap_unique_spell_detected
     order by status $$,
  $$ select 'eeeeeeee-0000-0000-0000-000000000002'::uuid, f.spell_2, 'connu'::text, 2::bigint from pgtap_unique_spell_fixture f
     union all
     select 'eeeeeeee-0000-0000-0000-000000000002'::uuid, f.spell_3, 'inné'::text, 2::bigint from pgtap_unique_spell_fixture f
     order by 3 $$,
  'La requête de détection remonte exactement les deux groupes dupliqués injectés, un par nature, avec 2 lignes chacun'
);
drop table pgtap_unique_spell_detected;

-- Nettoyage manuel comme demandé par le message d'erreur de la migration :
-- on supprime la ligne en trop de chaque groupe (choix arbitraire ici, sans
-- portée sur de vraies données -- ce sont des lignes de test injectées).
delete from public.character_spells
where character_id = 'eeeeeeee-0000-0000-0000-000000000002'
  and spell_id = (select spell_2 from pgtap_unique_spell_fixture)
  and status = 'connu'
  and id = (
    select id from public.character_spells
    where character_id = 'eeeeeeee-0000-0000-0000-000000000002'
      and spell_id = (select spell_2 from pgtap_unique_spell_fixture)
      and status = 'connu'
    limit 1
  );
delete from public.character_spells
where character_id = 'eeeeeeee-0000-0000-0000-000000000002'
  and spell_id = (select spell_3 from pgtap_unique_spell_fixture)
  and status = 'inné'
  and id = (
    select id from public.character_spells
    where character_id = 'eeeeeeee-0000-0000-0000-000000000002'
      and spell_id = (select spell_3 from pgtap_unique_spell_fixture)
      and status = 'inné'
    limit 1
  );

-- Tests 9-10 : une fois le doublon nettoyé à la main, les deux index se
-- recréent sans erreur -- exactement ce que la migration demande de faire
-- avant de la rejouer.
select lives_ok(
  $$ create unique index character_spells_unique_ordinary_per_spell
       on public.character_spells (character_id, spell_id)
       where status <> 'inné' $$,
  'Après nettoyage manuel du doublon ordinaire, l''index unique se recrée sans erreur'
);
select lives_ok(
  $$ create unique index character_spells_unique_innate_per_spell
       on public.character_spells (character_id, spell_id)
       where status = 'inné' $$,
  'Après nettoyage manuel du doublon inné, l''index unique se recrée sans erreur'
);

-- Test 11 : la requête de détection ne remonte plus rien après nettoyage.
select is(
  (
    select count(*)::int from (
      select character_id, spell_id
      from public.character_spells
      where character_id in ('eeeeeeee-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002')
        and status = 'inné'
      group by character_id, spell_id
      having count(*) > 1
      union all
      select character_id, spell_id
      from public.character_spells
      where character_id in ('eeeeeeee-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002')
        and status <> 'inné'
      group by character_id, spell_id
      having count(*) > 1
    ) d
  ),
  0,
  'La requête de détection ne remonte plus rien une fois le doublon nettoyé à la main'
);

-- Test 12 : les index recréés sont bien de vrais index uniques du catalogue
-- (pas juste "n'a pas levé d'erreur") -- vérifie qu'ils apparaissent avec le
-- bon flag indisunique.
select ok(
  (select indisunique from pg_index where indexrelid = 'public.character_spells_unique_ordinary_per_spell'::regclass)
  and (select indisunique from pg_index where indexrelid = 'public.character_spells_unique_innate_per_spell'::regclass),
  'Les deux index recréés sont bien marqués uniques dans le catalogue système'
);

select * from finish();

rollback;
