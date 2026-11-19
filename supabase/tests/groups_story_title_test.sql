-- Tests de 20261119120000_groups_story_title_and_public_summary.sql : titre et résumé public de la campagne sur `groups`
-- (étape 4 de FEUILLE-DE-ROUTE.md). Même patron que group_game_master_combat_guard_test.sql.
--
-- Couvre : schéma (colonnes text nullables sans défaut, 4 contraintes validées, politiques de `groups` inchangées, aucun
-- trigger UPDATE, classe de blancs indépendante de la collation : C, libc UTF-8, ICU) ; limites (200 et 500 caractères,
-- comptés en caractères et non en octets, y compris hors plan de base ; chaîne vide ou blanche refusée, dont U+00A0, U+202F
-- et U+200B ; espaces de bord conservés ; retours à la ligne admis ; NULL accepté) ; écriture : propriétaire accepté (y compris parti de
-- son groupe), membre, MJ non propriétaire, tiers, propriétaire d'un autre groupe et anonyme sans effet, insertion directe
-- refusée ; lecture : propriétaire, membre et MJ oui, tiers et anonyme non ; non-régression : renommage et nouveau code
-- (Nexus, Grimoire), création et rollback à la create-group, résolution d'un code à la preview-group-invite, suppression du
-- compte d'un membre puis du propriétaire.
--
-- Lancer : node_modules/.bin/supabase test db --local
-- BEGIN/ROLLBACK : rejouable, aucune donnée ne persiste.

begin;

select plan(63);

-- Fixtures (insérées en tant que postgres, qui contourne RLS) ---------------------------------------------------------------
-- u01 Olga : propriétaire de G1, y joue C01          u02 Bran : membre de G1 (C02)
-- u03 : tiers sans relation                          u04 Cyra : membre de G1, MJ sans personnage, NON propriétaire
-- u05 Dara : propriétaire de G2, a quitté son groupe u06 Eli : propriétaire MJ de G3
-- u07 Finn : membre de G3 (C07)
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select ('e1000000-0000-4000-8000-0000000000' || n)::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'pgtap-etiquette-' || n || '@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()
  from (values ('01'), ('02'), ('03'), ('04'), ('05'), ('06'), ('07')) v(n);

-- Insertion sans les nouvelles colonnes, comme create-group.
insert into public.groups (id, name, owner_id, invite_code)
values
  ('e2000000-0000-4000-8000-000000000001', 'pgTAP étiquette 1', 'e1000000-0000-4000-8000-000000000001', 'PGTAPET1'),
  ('e2000000-0000-4000-8000-000000000002', 'pgTAP étiquette 2 (propriétaire parti)', 'e1000000-0000-4000-8000-000000000005', 'PGTAPET2'),
  ('e2000000-0000-4000-8000-000000000003', 'pgTAP étiquette 3 (suppression de compte)', 'e1000000-0000-4000-8000-000000000006', 'PGTAPET3');

insert into public.characters (id, owner_id, name)
values
  ('e3000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000001', 'Olga'),
  ('e3000000-0000-4000-8000-000000000002', 'e1000000-0000-4000-8000-000000000002', 'Bran'),
  ('e3000000-0000-4000-8000-000000000007', 'e1000000-0000-4000-8000-000000000007', 'Finn');

insert into public.group_members (group_id, character_id, user_id, role, is_game_master)
values
  ('e2000000-0000-4000-8000-000000000001', 'e3000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000001', 'owner', false),
  ('e2000000-0000-4000-8000-000000000001', 'e3000000-0000-4000-8000-000000000002', 'e1000000-0000-4000-8000-000000000002', 'membre', false),
  ('e2000000-0000-4000-8000-000000000001', null, 'e1000000-0000-4000-8000-000000000004', 'membre', true),
  ('e2000000-0000-4000-8000-000000000003', null, 'e1000000-0000-4000-8000-000000000006', 'owner', true),
  ('e2000000-0000-4000-8000-000000000003', 'e3000000-0000-4000-8000-000000000007', 'e1000000-0000-4000-8000-000000000007', 'membre', false);

-- Résultats des sondes exécutées sous un autre rôle (lisible et modifiable par tous les rôles).
create temp table probe (k text primary key, n int);
grant all on probe to public;

-- Schéma ---------------------------------------------------------------------------------------------------------------------

select has_column('public', 'groups', 'story_title', 'groups.story_title existe');
select has_column('public', 'groups', 'story_summary_public', 'groups.story_summary_public existe');
select col_type_is('public', 'groups', 'story_title', 'text', 'story_title : text');
select col_type_is('public', 'groups', 'story_summary_public', 'text', 'story_summary_public : text');
select col_is_null('public', 'groups', 'story_title', 'story_title : nullable');
select col_is_null('public', 'groups', 'story_summary_public', 'story_summary_public : nullable');
select col_hasnt_default('public', 'groups', 'story_title', 'story_title : sans valeur par défaut');
select col_hasnt_default('public', 'groups', 'story_summary_public', 'story_summary_public : sans valeur par défaut');

select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.groups'::regclass and contype = 'c' and convalidated
      and conname in ('groups_story_title_not_blank', 'groups_story_title_max_length',
                      'groups_story_summary_public_not_blank', 'groups_story_summary_public_max_length')),
  4,
  'Les 4 contraintes CHECK sont présentes et validées'
);

select is(
  (select count(*)::int from public.groups
    where id::text like 'e2000000-%' and (story_title is not null or story_summary_public is not null)),
  0,
  'Groupe inséré sans ces colonnes (comme create-group) : NULL'
);

select is(
  (select string_agg(policyname || ':' || cmd || ':' || array_to_string(roles, ','), ' | ' order by policyname)
     from pg_policies where schemaname = 'public' and tablename = 'groups'),
  'Member can select their groups:SELECT:authenticated | Owner can dissolve their groups:DELETE:authenticated | '
  || 'Owner can select their groups:SELECT:authenticated | Owner can update their groups:UPDATE:authenticated',
  'Politiques de groups inchangées : une seule UPDATE, aucune pour anon, aucune INSERT'
);

select is(
  (select qual || ' / ' || with_check from pg_policies
    where schemaname = 'public' and tablename = 'groups' and policyname = 'Owner can update their groups'),
  '(( SELECT auth.uid() AS uid) = owner_id) / (( SELECT auth.uid() AS uid) = owner_id)',
  'La seule politique UPDATE est réservée au propriétaire (USING et WITH CHECK)'
);

select is(
  (select count(*)::int from pg_trigger
    where tgrelid = 'public.groups'::regclass and not tgisinternal and (tgtype & 16) <> 0),
  0,
  'Aucun trigger UPDATE sur groups (aucune normalisation cachée)'
);

-- Indépendance vis-à-vis de la locale : la classe de blancs réellement posée sur groups_story_title_not_blank (et la même
-- sur le résumé) est évaluée sous chaque collation disponible parmi C, POSIX, C.utf8, en_US.utf8 (libc) et und-x-icu,
-- fr-FR-x-icu (ICU) : les 28 blancs de la classe sont refusés et des caractères ordinaires acceptés, partout.
do $$
declare
  v_title_class text;
  v_summary_class text;
  v_coll record;
  v_cp int;
  v_match boolean;
  v_blank_ok int := 0;
  v_text_ko int := 0;
  v_tested int := 0;
  v_libc_utf8 int := 0;
  v_icu int := 0;
begin
  select substring(pg_get_constraintdef(oid) from $re$~ '(.*)'::text$re$) into v_title_class
    from pg_constraint where conrelid = 'public.groups'::regclass and conname = 'groups_story_title_not_blank';
  select substring(pg_get_constraintdef(oid) from $re$~ '(.*)'::text$re$) into v_summary_class
    from pg_constraint where conrelid = 'public.groups'::regclass and conname = 'groups_story_summary_public_not_blank';
  insert into probe (k, n) values ('same_class', case when v_title_class = v_summary_class then 1 else 0 end);

  for v_coll in
    select collname, collprovider from pg_collation
     where collname in ('C', 'POSIX', 'C.utf8', 'en_US.utf8', 'und-x-icu', 'fr-FR-x-icu')
       and collencoding in (-1, pg_char_to_encoding(current_setting('server_encoding')))
  loop
    v_tested := v_tested + 1;
    if v_coll.collprovider = 'c' and v_coll.collname not in ('C', 'POSIX') then v_libc_utf8 := v_libc_utf8 + 1; end if;
    if v_coll.collprovider = 'i' then v_icu := v_icu + 1; end if;
    for v_cp in
      select unnest(array[9, 10, 11, 12, 13, 32, 133, 160, 5760, 8232, 8233, 8239, 8287, 8288, 12288, 65279])
      union all select generate_series(8192, 8203)
    loop
      execute format('select ($1 collate %I) ~ $2', v_coll.collname) into v_match using repeat(chr(v_cp), 3), v_title_class;
      if v_match then v_blank_ok := v_blank_ok + 1; end if;
    end loop;
    for v_cp in select unnest(array[97, 233, 48, 45, 128009]) loop
      execute format('select ($1 collate %I) ~ $2', v_coll.collname) into v_match using chr(8239) || chr(v_cp) || chr(160), v_title_class;
      if not v_match then v_text_ko := v_text_ko + 1; end if;
    end loop;
  end loop;

  insert into probe (k, n) values
    ('blank_ok', v_blank_ok), ('text_ko', v_text_ko),
    ('coll_ok', case when v_tested >= 3 and v_libc_utf8 >= 1 and v_icu >= 1 then 1 else 0 end);
end
$$;

select is(
  (select n from probe where k = 'same_class') + (select n from probe where k = 'coll_ok'),
  2,
  'Classe de blancs : identique pour le titre et le résumé, éprouvée sous au moins une collation libc UTF-8 et une ICU'
);
select is(
  (select n from probe where k = 'blank_ok'),
  0,
  'Classe de blancs : aucun des 28 blancs (dont U+00A0, U+2007, U+200B, U+202F) accepté, sous aucune collation'
);
select is(
  (select n from probe where k = 'text_ko'),
  0,
  'Classe de blancs : un caractère ordinaire entouré de blancs est accepté sous toutes les collations'
);

-- Limites (en tant que propriétaire : ce que reçoit un client) ----------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);

with u as (
  update public.groups set story_title = repeat('t', 200), story_summary_public = repeat('r', 500)
   where id = 'e2000000-0000-4000-8000-000000000001' returning 1
)
select is(count(*)::int, 1, 'Propriétaire : titre de 200 et résumé de 500 caractères acceptés') from u;

select throws_ok(
  $$ update public.groups set story_title = repeat('t', 201) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_title_max_length"',
  'Titre de 201 caractères refusé'
);
select throws_ok(
  $$ update public.groups set story_summary_public = repeat('r', 501) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_summary_public_max_length"',
  'Résumé de 501 caractères refusé'
);
select throws_ok(
  $$ update public.groups set story_title = '' where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_title_not_blank"',
  'Titre vide refusé (pas converti en NULL)'
);
select throws_ok(
  $$ update public.groups set story_title = '   ' where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_title_not_blank"',
  'Titre fait d''espaces refusé'
);
select throws_ok(
  $$ update public.groups set story_title = E' \t\r\n ' where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_title_not_blank"',
  'Titre fait de tabulations et retours à la ligne refusé'
);
select throws_ok(
  $$ update public.groups set story_summary_public = '' where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_summary_public_not_blank"',
  'Résumé vide refusé'
);
select throws_ok(
  $$ update public.groups set story_summary_public = E'\n\n  ' where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_summary_public_not_blank"',
  'Résumé fait de blancs refusé'
);

-- Caractères, pas octets : « é » (2 octets) et U+1F409 (4 octets, 2 unités UTF-16).
select lives_ok(
  $$ update public.groups set story_title = repeat(chr(233), 200) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  'Titre de 200 « é » (400 octets) accepté'
);
select lives_ok(
  $$ update public.groups set story_title = repeat(chr(128009), 200) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  'Titre de 200 caractères hors plan de base (800 octets, 400 unités UTF-16) accepté'
);
select throws_ok(
  $$ update public.groups set story_title = repeat(chr(128009), 201) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_title_max_length"',
  'Titre de 201 caractères hors plan de base refusé'
);
select lives_ok(
  $$ update public.groups set story_summary_public = repeat(chr(128009), 500) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  'Résumé de 500 caractères hors plan de base (2 000 octets, 1 000 unités UTF-16) accepté'
);
select throws_ok(
  $$ update public.groups set story_summary_public = repeat(chr(128009), 501) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_summary_public_max_length"',
  'Résumé de 501 caractères hors plan de base refusé'
);

-- Blancs Unicode que `\S` laisse passer selon la locale (U+00A0, U+202F sous libc) ou partout (U+200B).
select throws_ok(
  $$ update public.groups set story_title = repeat(chr(160), 3) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_title_not_blank"',
  'Titre fait d''espaces insécables (U+00A0) refusé'
);
select throws_ok(
  $$ update public.groups set story_title = repeat(chr(8239), 3) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_title_not_blank"',
  'Titre fait d''espaces fines insécables (U+202F) refusé'
);
select throws_ok(
  $$ update public.groups set story_title = repeat(chr(8203), 3) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_title_not_blank"',
  'Titre fait d''espaces sans chasse (U+200B) refusé'
);
select throws_ok(
  $$ update public.groups set story_summary_public = repeat(chr(160), 3) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_summary_public_not_blank"',
  'Résumé fait d''espaces insécables (U+00A0) refusé'
);
select throws_ok(
  $$ update public.groups set story_summary_public = repeat(chr(8239), 3) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_summary_public_not_blank"',
  'Résumé fait d''espaces fines insécables (U+202F) refusé'
);
select throws_ok(
  $$ update public.groups set story_summary_public = repeat(chr(8203), 3) where id = 'e2000000-0000-4000-8000-000000000001' $$,
  '23514', 'new row for relation "groups" violates check constraint "groups_story_summary_public_not_blank"',
  'Résumé fait d''espaces sans chasse (U+200B) refusé'
);

update public.groups set story_title = '  Titre avec espaces  ', story_summary_public = E'Ligne 1\nLigne 2'
 where id = 'e2000000-0000-4000-8000-000000000001';
select is(
  (select story_title || '|' || story_summary_public from public.groups where id = 'e2000000-0000-4000-8000-000000000001'),
  E'  Titre avec espaces  |Ligne 1\nLigne 2',
  'Espaces de bord conservés tels quels (non normalisés), retours à la ligne admis dans le résumé'
);

with u as (
  update public.groups set story_title = null, story_summary_public = null
   where id = 'e2000000-0000-4000-8000-000000000001' returning story_title is null and story_summary_public is null as cleared
)
select is(bool_and(cleared), true, 'Propriétaire : effacement (NULL) accepté') from u;

-- Valeur de référence pour la suite.
with u as (
  update public.groups set story_title = 'Les Mines de Phandelver', story_summary_public = 'Une accroche sans secret.'
   where id = 'e2000000-0000-4000-8000-000000000001' returning 1
)
select is(count(*)::int, 1, 'Propriétaire : titre et résumé écrits (1 ligne)') from u;

-- Renommage et nouveau code (Nexus renameGroup/regenerateInviteCode, Grimoire rename/regenerateInviteCode) : inchangés.
with u as (
  update public.groups set name = 'pgTAP étiquette 1 renommé' where id = 'e2000000-0000-4000-8000-000000000001' returning 1
)
select is(count(*)::int, 1, 'Propriétaire : renommage inchangé') from u;
with u as (
  update public.groups set invite_code = 'PGTAPEU1' where id = 'e2000000-0000-4000-8000-000000000001' returning 1
)
select is(count(*)::int, 1, 'Propriétaire : nouveau code inchangé') from u;
reset role;

select is(
  (select story_title || ' / ' || story_summary_public from public.groups where id = 'e2000000-0000-4000-8000-000000000001'),
  'Les Mines de Phandelver / Une accroche sans secret.',
  'Renommage et nouveau code ne touchent pas le titre ni le résumé'
);

-- Écriture refusée (0 ligne, sans erreur : comportement de la RLS) ----------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000002', 'role', 'authenticated')::text, true);
with u as (
  update public.groups set story_title = 'Bran', story_summary_public = 'Bran' where id = 'e2000000-0000-4000-8000-000000000001' returning 1
)
select is(count(*)::int, 0, 'Membre (joueur) : 0 ligne modifiée') from u;
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000004', 'role', 'authenticated')::text, true);
with u as (
  update public.groups set story_title = 'Cyra', story_summary_public = 'Cyra' where id = 'e2000000-0000-4000-8000-000000000001' returning 1
)
select is(count(*)::int, 0, 'MJ sans personnage NON propriétaire : 0 ligne modifiée') from u;
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000003', 'role', 'authenticated')::text, true);
with u as (
  update public.groups set story_title = 'Tiers' where id = 'e2000000-0000-4000-8000-000000000001' returning 1
)
select is(count(*)::int, 0, 'Tiers authentifié (privilèges de table D229) : 0 ligne modifiée') from u;
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000006', 'role', 'authenticated')::text, true);
with u as (
  update public.groups set story_title = 'Eli' where id = 'e2000000-0000-4000-8000-000000000001' returning 1
)
select is(count(*)::int, 0, 'Propriétaire d''un AUTRE groupe : 0 ligne modifiée') from u;
reset role;

-- Anonyme : refusé par la RLS aujourd'hui (aucune politique pour anon) ; si D229 retire un jour les privilèges de table
-- d'anon, le refus devient « permission denied » : la sonde accepte les deux, seul compte le résultat.
set local role anon;
select set_config('request.jwt.claims', '', true);
do $$
begin
  update public.groups set story_title = 'Anonyme', story_summary_public = 'Anonyme'
   where id = 'e2000000-0000-4000-8000-000000000001';
exception when insufficient_privilege then
  null;
end
$$;
reset role;

select is(
  (select story_title || ' / ' || story_summary_public from public.groups where id = 'e2000000-0000-4000-8000-000000000001'),
  'Les Mines de Phandelver / Une accroche sans secret.',
  'Après les tentatives du membre, du MJ non propriétaire, du tiers, d''un autre propriétaire et d''anon : valeurs intactes'
);

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select throws_ok(
  $$ insert into public.groups (name, owner_id, invite_code, story_title)
     values ('Groupe direct', 'e1000000-0000-4000-8000-000000000001', 'PGTAPEX1', 'Titre') $$,
  '42501', 'new row violates row-level security policy for table "groups"',
  'Insertion directe d''un groupe avec titre refusée (création par create-group seulement)'
);
reset role;

-- Propriétaire parti de son groupe (sans ligne group_members) : même règle que pour name et invite_code.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000005', 'role', 'authenticated')::text, true);
with u as (
  update public.groups set story_title = 'Titre de Dara' where id = 'e2000000-0000-4000-8000-000000000002' returning 1
)
select is(count(*)::int, 1, 'Propriétaire parti de son groupe : écriture acceptée (politique propriétaire inchangée)') from u;
reset role;

-- Lecture -----------------------------------------------------------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000002', 'role', 'authenticated')::text, true);
select is(
  (select story_title || ' / ' || story_summary_public from public.groups where id = 'e2000000-0000-4000-8000-000000000001'),
  'Les Mines de Phandelver / Une accroche sans secret.',
  'Membre (joueur) : lit le titre et le résumé'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000004', 'role', 'authenticated')::text, true);
select is(
  (select story_title from public.groups where id = 'e2000000-0000-4000-8000-000000000001'),
  'Les Mines de Phandelver',
  'MJ non propriétaire (membre) : lit le titre'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select is(
  (select story_title from public.groups where id = 'e2000000-0000-4000-8000-000000000001'),
  'Les Mines de Phandelver',
  'Propriétaire : lit le titre'
);
-- Nexus publié (fetchMyGroups) : embarquement explicite, inchangé.
select is(
  (select count(*)::int from public.group_members m join public.groups g on g.id = m.group_id
    where m.user_id = 'e1000000-0000-4000-8000-000000000001'),
  1,
  'Propriétaire : sa liste de groupes (group_members -> groups) inchangée'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000003', 'role', 'authenticated')::text, true);
select is(
  (select count(*)::int from public.groups where id = 'e2000000-0000-4000-8000-000000000001'),
  0,
  'Tiers authentifié : aucune ligne, donc ni titre ni résumé'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000007', 'role', 'authenticated')::text, true);
select is(
  (select count(*)::int from public.groups where id = 'e2000000-0000-4000-8000-000000000001'),
  0,
  'Membre d''un AUTRE groupe : aucune ligne'
);
reset role;

set local role anon;
select set_config('request.jwt.claims', '', true);
do $$
declare
  v_n int;
begin
  begin
    select count(*) into v_n from public.groups where id = 'e2000000-0000-4000-8000-000000000001';
  exception when insufficient_privilege then
    v_n := 0;
  end;
  insert into probe (k, n) values ('anon_read', v_n);
end
$$;
reset role;
select is((select n from probe where k = 'anon_read'), 0, 'Anonyme : aucune ligne (RLS aujourd''hui, privilège refusé après D229)');

-- Chemins des edge functions (service_role, qui contourne la RLS) -----------------------------------------------------------

set local role service_role;
-- create-group : insertion de name, owner_id, invite_code puis select("id, name, invite_code").
insert into public.groups (id, name, owner_id, invite_code)
values ('e2000000-0000-4000-8000-000000000004', 'pgTAP étiquette 4 (create-group)', 'e1000000-0000-4000-8000-000000000001', 'PGTAPET4');
select is(
  (select coalesce(story_title, 'NULL') || ' / ' || coalesce(story_summary_public, 'NULL') from public.groups
    where id = 'e2000000-0000-4000-8000-000000000004'),
  'NULL / NULL',
  'create-group : nouveau groupe sans titre ni résumé'
);
-- Rollback applicatif de create-group (groupe tout juste créé, sans combat).
select lives_ok(
  $$ delete from public.groups where id = 'e2000000-0000-4000-8000-000000000004' $$,
  'create-group : rollback (suppression du groupe tout juste créé) inchangé'
);
-- findJoinableGroup (join-group, preview-group-invite) : select("id, name, owner_id") par code.
select is(
  (select name from public.groups where invite_code = 'PGTAPEU1'),
  'pgTAP étiquette 1 renommé',
  'findJoinableGroup : résolution par code inchangée (les nouvelles colonnes ne sont pas lues)'
);
reset role;

-- Suppression de compte (delete-account -> auth.users -> cascades) -----------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'e1000000-0000-4000-8000-000000000006', 'role', 'authenticated')::text, true);
with u as (
  update public.groups set story_title = 'Campagne d''Eli', story_summary_public = 'Accroche d''Eli'
   where id = 'e2000000-0000-4000-8000-000000000003' returning 1
)
select is(count(*)::int, 1, 'G3 : titre écrit par son propriétaire') from u;
reset role;

select lives_ok(
  $$ delete from auth.users where id = 'e1000000-0000-4000-8000-000000000007' $$,
  'Suppression du compte d''un membre acceptée'
);
select is(
  (select story_title from public.groups where id = 'e2000000-0000-4000-8000-000000000003'),
  'Campagne d''Eli',
  'Après le départ (suppression de compte) d''un membre : le groupe garde son titre'
);
select lives_ok(
  $$ delete from auth.users where id = 'e1000000-0000-4000-8000-000000000006' $$,
  'Suppression du compte du propriétaire acceptée (titre renseigné)'
);
select is(
  (select count(*)::int from public.groups where id = 'e2000000-0000-4000-8000-000000000003'),
  0,
  'Après la suppression du compte du propriétaire : le groupe et son titre disparaissent (cascade inchangée)'
);

select * from finish();

rollback;
