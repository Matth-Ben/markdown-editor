-- Vérifie 20261008100000_apply_rest_transactional_rpc.sql (chantier
-- "Personnages", app mobile, D05 du registre de dette technique mobile) :
-- `apply_rest` est SECURITY DEFINER et écrit dans `characters` + plusieurs
-- tables enfant pour le compte de l'appelant -- même classe de fonction que
-- `create_character` (20261007110000), dont les privilèges EXECUTE ont déjà
-- été mal accordés deux fois sur ce projet par le passé (20260908094500,
-- 20261007090000, découverts seulement a posteriori par lecture manuelle).
--   1-3. Privilèges EXECUTE : anon et PUBLIC n'ont PAS le droit d'appeler
--        apply_rest ; authenticated l'a.
--   4-8. Repos LONG réussi, en tant qu'authenticated : PV courants au
--        maximum, PV temporaires à 0, horodatage du dernier repos long
--        renseigné, dés de vie récupérés (RAW 5e, moitié du niveau arrondie
--        à l'inférieur, au moins 1), emplacements de sorts recalculés et
--        remis à 0 pour la classe primaire lanceuse.
--   9-12. Repos COURT réussi : aptitudes à usage limité filtrées par
--        rest_type ('repos_court' rechargée, une aptitude à un autre
--        rest_type jamais écrite), magie de pacte de l'Occultiste remise à
--        zéro ET recalculée même au repos court (contrairement aux
--        emplacements classiques, repos long uniquement).
--   13-14. Atomicité : un class_features.uses_per_rest->>'amount' non
--        numérique fait échouer l'étape 6 (aptitudes) APRÈS qu'une écriture
--        réelle (dés de vie dépensés, étape "repos court") ait déjà eu
--        lieu dans le même appel -- aucune des deux écritures ne doit
--        persister (atomicité réelle, pas juste l'absence d'erreur).
--   15-16. Entrée malformée : un p_rest_type hors ('court', 'long') lève
--        une erreur explicite (P0001) plutôt que de deviner un
--        comportement, sans toucher à `characters`.
--
-- Lancer : supabase test db supabase/tests --local (depuis la racine du
-- dépôt web, stack locale démarrée au préalable via `supabase start`, base
-- réinitialisée via `supabase db reset`). BEGIN/ROLLBACK en fin de fichier :
-- aucune donnée de test ne persiste.

begin;

select plan(16);

-- Fixtures : un joueur authentifié, et les id des classes de référence
-- 'Magicien' (lanceur complet RAW, utilisé pour le repos long) et
-- 'Occultiste' (magie de pacte, utilisé pour le repos court) -- résolus par
-- nom traduit (fr), jamais un id supposé stable, même convention que la
-- fonction testée. Inséré en tant que `postgres` (rôle superuser du test
-- runner pgTAP), qui contourne RLS comme le ferait service_role.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('a2a2a2a2-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-apply-rest-owner@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

create temporary table pgtap_apply_rest_fixture on commit drop as
select
  (select c.id from public.classes c
     join public.translations t
       on t.entity_type = 'class' and t.entity_id = c.id::text
      and t.field_name = 'name' and t.locale = 'fr'
    where t.value = 'Magicien' limit 1) as magicien_id,
  (select c.id from public.classes c
     join public.translations t
       on t.entity_type = 'class' and t.entity_id = c.id::text
      and t.field_name = 'name' and t.locale = 'fr'
    where t.value = 'Occultiste' limit 1) as occultiste_id;
grant select on pgtap_apply_rest_fixture to anon, authenticated;

-- Tests 1-3 : privilèges EXECUTE.
select ok(
  not has_function_privilege(
    'anon',
    'public.apply_rest(uuid, text, text, int, int)',
    'execute'
  ),
  'anon n''a pas EXECUTE sur apply_rest'
);
select ok(
  not has_function_privilege(
    'public',
    'public.apply_rest(uuid, text, text, int, int)',
    'execute'
  ),
  'le pseudo-rôle PUBLIC n''a pas EXECUTE sur apply_rest'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.apply_rest(uuid, text, text, int, int)',
    'execute'
  ),
  'authenticated a EXECUTE sur apply_rest'
);

-- ===========================================================================
-- Tests 4-8 : repos LONG réussi (classe primaire Magicien niveau 5).
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('b1000000-0000-0000-0000-000000000001', 'a2a2a2a2-2222-2222-2222-222222222222', 20, 5, 3);

insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
values (
  'c1000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000001',
  (select magicien_id from pgtap_apply_rest_fixture),
  5, true, 4
);

-- Ligne héritée (stale) : total différent du calcul attendu, slots_used non
-- nul -- doit être intégralement recalculée par le repos long.
insert into public.character_spell_slots (character_id, slot_level, slots_total, slots_used)
values ('b1000000-0000-0000-0000-000000000001', 1, 1, 1);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a2a2a2a2-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);
select public.apply_rest(
  p_character_id => 'b1000000-0000-0000-0000-000000000001',
  p_rest_type => 'long',
  p_primary_class_name => 'Magicien'
);
reset role;

select is(
  (select current_hp from public.characters where id = 'b1000000-0000-0000-0000-000000000001'),
  20,
  'Repos long : current_hp remonte au maximum (20)'
);
select is(
  (select temporary_hp from public.characters where id = 'b1000000-0000-0000-0000-000000000001'),
  0,
  'Repos long : temporary_hp remis à 0'
);
select ok(
  (select last_long_rest_at from public.characters where id = 'b1000000-0000-0000-0000-000000000001') is not null,
  'Repos long : last_long_rest_at renseigné'
);
select is(
  (select hit_dice_spent from public.character_classes where id = 'c1000000-0000-0000-0000-000000000001'),
  2,
  'Repos long : dés de vie récupérés (4 - max(1, 5/2) = 2)'
);
select results_eq(
  $$ select slots_total, slots_used from public.character_spell_slots
     where character_id = 'b1000000-0000-0000-0000-000000000001' and slot_level = 1 $$,
  $$ values (4, 0) $$,
  'Repos long : emplacements de sorts niveau 1 recalculés (Magicien niveau 5 -> 4 total) et remis à 0'
);

-- ===========================================================================
-- Tests 9-12 : repos COURT réussi (classe primaire Occultiste niveau 3).
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('b2000000-0000-0000-0000-000000000002', 'a2a2a2a2-2222-2222-2222-222222222222', 20, 10, 0);

insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
values (
  'c2000000-0000-0000-0000-000000000002',
  'b2000000-0000-0000-0000-000000000002',
  (select occultiste_id from pgtap_apply_rest_fixture),
  3, true, 0
);

insert into public.class_features (id, class_id, level, uses_per_rest)
overriding system value
values
  (900001, (select occultiste_id from pgtap_apply_rest_fixture), 1, '{"amount": 2, "rest_type": "repos_court"}'::jsonb),
  (900002, (select occultiste_id from pgtap_apply_rest_fixture), 1, '{"amount": 3, "rest_type": "repos_long"}'::jsonb);

-- Charges de pacte déjà partiellement consommées avant ce repos court, sur
-- un palier différent de celui attendu au niveau 3 -- doit être
-- intégralement recalculée (slot_level, slots_total) ET remise à 0
-- (slots_used), même au repos court (seule la magie de pacte recharge aux
-- deux types de repos).
insert into public.character_pact_slots (character_id, slot_level, slots_total, slots_used)
values ('b2000000-0000-0000-0000-000000000002', 1, 1, 1);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a2a2a2a2-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);
select public.apply_rest(
  p_character_id => 'b2000000-0000-0000-0000-000000000002',
  p_rest_type => 'court'
);
reset role;

select is(
  (select uses_remaining from public.character_feature_uses
     where character_id = 'b2000000-0000-0000-0000-000000000002' and class_feature_id = 900001),
  2,
  'Repos court : aptitude rest_type=repos_court rechargée (uses_remaining = 2)'
);
select is(
  (select count(*)::int from public.character_feature_uses
     where character_id = 'b2000000-0000-0000-0000-000000000002' and class_feature_id = 900002),
  0,
  'Repos court : aptitude rest_type=repos_long jamais écrite (pas rechargée par un repos court)'
);
select results_eq(
  $$ select slot_level, slots_total, slots_used from public.character_pact_slots
     where character_id = 'b2000000-0000-0000-0000-000000000002' $$,
  $$ values (2, 2, 0) $$,
  'Repos court : magie de pacte recalculée pour Occultiste niveau 3 (2 charges, emplacement niveau 2) et remise à 0'
);
select is(
  (select hit_dice_spent from public.character_classes where id = 'c2000000-0000-0000-0000-000000000002'),
  0,
  'Repos court sans dés de vie dépensés (p_dice_spent par défaut 0) : hit_dice_spent inchangé'
);

-- ===========================================================================
-- Tests 13-14 : atomicité -- un class_features.uses_per_rest->>'amount' non
-- numérique fait échouer l'étape "aptitudes" APRÈS que l'étape "dés de vie"
-- (repos court avec p_dice_spent > 0) ait déjà réellement écrit
-- hit_dice_spent dans la même transaction.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('b3000000-0000-0000-0000-000000000003', 'a2a2a2a2-2222-2222-2222-222222222222', 15, 10, 0);

insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
values (
  'c3000000-0000-0000-0000-000000000003',
  'b3000000-0000-0000-0000-000000000003',
  (select magicien_id from pgtap_apply_rest_fixture),
  5, true, 0
);

insert into public.class_features (id, class_id, level, uses_per_rest)
overriding system value
values (
  900003,
  (select magicien_id from pgtap_apply_rest_fixture),
  1,
  '{"amount": "pas-un-nombre", "rest_type": "repos_court"}'::jsonb
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a2a2a2a2-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.apply_rest(
       p_character_id => 'b3000000-0000-0000-0000-000000000003',
       p_rest_type => 'court',
       p_dice_spent => 1
     ) $$,
  '22P02',
  null,
  'uses_per_rest->>''amount'' non numérique fait échouer tout l''appel (22P02), après l''écriture réelle des dés de vie'
);
reset role;

select is(
  (select hit_dice_spent from public.character_classes where id = 'c3000000-0000-0000-0000-000000000003'),
  0,
  'Aucune écriture ne persiste après l''échec : hit_dice_spent toujours à 0 (pas 1), atomicité réelle'
);

-- ===========================================================================
-- Tests 15-16 : entrée malformée -- p_rest_type hors ('court', 'long').
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('b4000000-0000-0000-0000-000000000004', 'a2a2a2a2-2222-2222-2222-222222222222', 10, 8, 0);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'a2a2a2a2-2222-2222-2222-222222222222', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.apply_rest(
       p_character_id => 'b4000000-0000-0000-0000-000000000004',
       p_rest_type => 'invalide'
     ) $$,
  'P0001',
  null,
  'p_rest_type invalide lève une erreur explicite (P0001) plutôt que de deviner un comportement'
);
reset role;

select is(
  (select current_hp from public.characters where id = 'b4000000-0000-0000-0000-000000000004'),
  8,
  'p_rest_type invalide : aucune écriture, current_hp inchangé'
);

select * from finish();

rollback;
