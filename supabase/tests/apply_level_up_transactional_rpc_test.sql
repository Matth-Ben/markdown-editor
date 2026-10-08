-- Vérifie 20261009090000_apply_level_up_transactional_rpc.sql (chantier
-- "Personnages", app mobile, dernier morceau de D05 du registre de dette
-- technique mobile). Mêmes garanties déjà testées pour `create_character`
-- et `apply_rest` (privilèges EXECUTE, atomicité réelle sur un échec forcé
-- après une écriture déjà faite, entrée malformée explicite), plus une
-- couverture volontairement large des branches mutuellement exclusives de
-- cette fonction (bien plus nombreuses que les deux précédentes) :
--   1-3.   Privilèges EXECUTE.
--   4-12.  Continuation de niveau, choix ASI (répartition de
--          caractéristiques sur 2 caractéristiques, dont une qui change le
--          modificateur de Constitution -> PV rétroactifs).
--   13-16. Continuation de niveau, choix "don" sans augmentation de
--          caractéristique (Robuste physiquement) -> PV rétroactifs
--          uniquement via `featTakenBonus` (2 x niveau total).
--   17-19. Continuation de niveau, choix "don" avec augmentation de
--          caractéristique ET bonus de don simultanés (Faveur de
--          robustesse, +40, caractéristique non choisie ici pour isoler le
--          bonus pur).
--   20-23. Continuation de niveau, choix "don" avec augmentation de
--          caractéristique SEULE (Robuste, pas de bonus de don -- isole le
--          bonus rétroactif de Constitution).
--   24-27. Multiclassage réussi (prérequis revérifiés), emplacements de
--          sorts recalculés au niveau de lanceur combiné multiclasse.
--   28-29. Multiclassage refusé : prérequis de la NOUVELLE classe non
--          rempli.
--   30.    Multiclassage refusé : classe déjà possédée.
--   31.    Multiclassage refusé : prérequis d'une classe déjà possédée
--          (défense en profondeur) non rempli.
--   32-34. Multiclassage dans l'Occultiste : magie de pacte recalculée et
--          `slots_used` existant plafonné (pas remis à zéro).
--   35-37. Choix "style de combat" (character_class_options), aucun PV
--          rétroactif.
--   38-39. Choix "sous-classe" : `subclass_id` écrit dans la même ligne que
--          le niveau, aucune autre table touchée.
--   40-45. Sorts de départ + invocations + sorts innés raciaux (avec
--          déduplication contre un sort déjà connu).
--   46-48. Atomicité : une caractéristique absente de
--          `character_ability_scores` fait échouer l'étape ASI APRÈS que
--          `characters`/`character_classes` aient déjà été réellement
--          écrits dans le même appel -- rien ne doit persister.
--   49-50. Entrée malformée : `p_choice->>'kind'` inconnu lève une erreur
--          explicite (P0001), sans aucune écriture.
--
-- Lancer : supabase test db supabase/tests --local (stack locale Docker
-- démarrée au préalable via `supabase start`, base réinitialisée via
-- `supabase db reset`). BEGIN/ROLLBACK en fin de fichier : aucune donnée de
-- test ne persiste.

begin;

select plan(50);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('b3b3b3b3-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-apply-level-up-owner@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

-- Fixtures de référence : classes, dons, sorts, invocation, et une ligne
-- class_features dédiée pour le choix "style de combat" -- résolus par nom
-- traduit (fr), jamais un id supposé stable, même convention que les deux
-- migrations précédentes.
create temporary table lvlup_fixture on commit drop as
select
  (select c.id from public.classes c join public.translations t
     on t.entity_type = 'class' and t.entity_id = c.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Magicien' limit 1) as magicien_id,
  (select c.id from public.classes c join public.translations t
     on t.entity_type = 'class' and t.entity_id = c.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Rôdeur' limit 1) as rodeur_id,
  (select c.id from public.classes c join public.translations t
     on t.entity_type = 'class' and t.entity_id = c.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Occultiste' limit 1) as occultiste_id,
  (select c.id from public.classes c join public.translations t
     on t.entity_type = 'class' and t.entity_id = c.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Guerrier' limit 1) as guerrier_id,
  (select c.id from public.classes c join public.translations t
     on t.entity_type = 'class' and t.entity_id = c.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Clerc' limit 1) as clerc_id,
  (select c.id from public.classes c join public.translations t
     on t.entity_type = 'class' and t.entity_id = c.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Moine' limit 1) as moine_id,
  (select c.id from public.classes c join public.translations t
     on t.entity_type = 'class' and t.entity_id = c.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Roublard' limit 1) as roublard_id,
  (select f.id from public.feats f join public.translations t
     on t.entity_type = 'feat' and t.entity_id = f.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Robuste physiquement' limit 1) as tough_feat_id,
  (select f.id from public.feats f join public.translations t
     on t.entity_type = 'feat' and t.entity_id = f.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Faveur de robustesse' limit 1) as fortitude_boon_feat_id,
  (select f.id from public.feats f join public.translations t
     on t.entity_type = 'feat' and t.entity_id = f.id::text and t.field_name = 'name' and t.locale = 'fr'
   where t.value = 'Robuste' limit 1) as resilient_feat_id,
  (select id from public.spells order by id limit 1 offset 0) as spell_a_id,
  (select id from public.spells order by id limit 1 offset 1) as spell_b_id,
  (select id from public.spells order by id limit 1 offset 2) as spell_c_id,
  (select id from public.invocations order by id limit 1) as invocation_a_id,
  (select id from public.subclasses limit 1) as subclass_a_id;
grant select on lvlup_fixture to anon, authenticated;

insert into public.class_features (id, class_id, level, choice_type)
overriding system value
select 920001, guerrier_id, 2, 'style_combat' from lvlup_fixture;

-- Tests 1-3 : privilèges EXECUTE.
select ok(
  not has_function_privilege(
    'anon',
    'public.apply_level_up(uuid, int, text, boolean, int, text, int, jsonb, int[], int[], int[])',
    'execute'
  ),
  'anon n''a pas EXECUTE sur apply_level_up'
);
select ok(
  not has_function_privilege(
    'public',
    'public.apply_level_up(uuid, int, text, boolean, int, text, int, jsonb, int[], int[], int[])',
    'execute'
  ),
  'le pseudo-rôle PUBLIC n''a pas EXECUTE sur apply_level_up'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.apply_level_up(uuid, int, text, boolean, int, text, int, jsonb, int[], int[], int[])',
    'execute'
  ),
  'authenticated a EXECUTE sur apply_level_up'
);

-- ===========================================================================
-- Tests 4-12 : continuation de niveau (Magicien niveau 4 -> 5), choix ASI
-- répartissant +1/+1 entre Force et Constitution -- la Constitution change
-- de modificateur (13 -> 14), donc PV rétroactifs = 1 x niveau total (5).
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a1000000-0000-0000-0000-000000000001', 'b3b3b3b3-3333-3333-3333-333333333333', 30, 25, 0);

insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', magicien_id, 4, true, 1
from lvlup_fixture;

insert into public.character_ability_scores (character_id, ability_id, score)
values
  ('a1000000-0000-0000-0000-000000000001', 'str', 10),
  ('a1000000-0000-0000-0000-000000000001', 'dex', 10),
  ('a1000000-0000-0000-0000-000000000001', 'con', 13),
  ('a1000000-0000-0000-0000-000000000001', 'int', 16),
  ('a1000000-0000-0000-0000-000000000001', 'wis', 10),
  ('a1000000-0000-0000-0000-000000000001', 'cha', 10);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
create temporary table lvlup_result_asi on commit drop as
select public.apply_level_up(
  p_character_id => 'a1000000-0000-0000-0000-000000000001',
  p_class_id => (select magicien_id from lvlup_fixture),
  p_class_name => 'Magicien',
  p_is_multiclassing => false,
  p_hp_rolled => 4,
  p_hp_method => 'moyenne',
  p_hp_gain => 6,
  p_choice => '{"kind": "ability_score_improvement", "ability_allocations": {"str": 1, "con": 1}}'::jsonb
) as result;
reset role;

select is(
  (select (result ->> 'new_level')::int from lvlup_result_asi),
  5,
  'ASI : nouveau niveau total renvoyé (5)'
);
select is(
  (select (result ->> 'new_max_hp')::int from lvlup_result_asi),
  36 + 5,
  'ASI : PV max = 30 + 6 (gain) + 5 (rétroactif Constitution 13->14, x niveau 5)'
);
select is(
  (select (result ->> 'new_current_hp')::int from lvlup_result_asi),
  25 + 6 + 5,
  'ASI : PV courants incrémentés du même total'
);
select is(
  (select max_hp from public.characters where id = 'a1000000-0000-0000-0000-000000000001'),
  41,
  'ASI : characters.max_hp effectivement écrit en base (36 + 5)'
);
select is(
  (select level from public.character_classes where id = 'c1000000-0000-0000-0000-000000000001'),
  5,
  'ASI : character_classes.level incrémenté (4 -> 5)'
);
select is(
  (select score from public.character_ability_scores
     where character_id = 'a1000000-0000-0000-0000-000000000001' and ability_id = 'str'),
  11,
  'ASI : Force incrémentée (10 -> 11)'
);
select is(
  (select score from public.character_ability_scores
     where character_id = 'a1000000-0000-0000-0000-000000000001' and ability_id = 'con'),
  14,
  'ASI : Constitution incrémentée (13 -> 14)'
);
select results_eq(
  $$ select ability_id, increase, source from public.character_ability_increases
     where character_id = 'a1000000-0000-0000-0000-000000000001' order by ability_id $$,
  $$ values ('con', 1, 'asi'), ('str', 1, 'asi') $$,
  'ASI : character_ability_increases trace les deux augmentations (source = asi)'
);
select is(
  (select count(*)::int from public.character_level_hp
     where character_id = 'a1000000-0000-0000-0000-000000000001' and level = 5 and hp_rolled = 4 and method = 'moyenne'),
  1,
  'ASI : character_level_hp historise le niveau 5'
);

-- ===========================================================================
-- Tests 13-16 : don "Robuste physiquement" (pas d'augmentation de
-- caractéristique) -- Guerrier niveau 2 -> 3, PV rétroactifs = 2 x 3 = 6.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a2000000-0000-0000-0000-000000000002', 'b3b3b3b3-3333-3333-3333-333333333333', 20, 18, 0);

insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c2000000-0000-0000-0000-000000000002', 'a2000000-0000-0000-0000-000000000002', guerrier_id, 2, true, 0
from lvlup_fixture;

insert into public.character_ability_scores (character_id, ability_id, score)
select 'a2000000-0000-0000-0000-000000000002', a, 10
from unnest(array['str','dex','con','int','wis','cha']) as a;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
create temporary table lvlup_result_tough on commit drop as
select public.apply_level_up(
  p_character_id => 'a2000000-0000-0000-0000-000000000002',
  p_class_id => (select guerrier_id from lvlup_fixture),
  p_class_name => 'Guerrier',
  p_is_multiclassing => false,
  p_hp_rolled => 7,
  p_hp_method => 'lance',
  p_hp_gain => 7,
  p_choice => (select jsonb_build_object('kind', 'ability_score_improvement', 'feat_id', tough_feat_id) from lvlup_fixture)
) as result;
reset role;

select is(
  (select (result ->> 'new_max_hp')::int from lvlup_result_tough),
  20 + 7 + 6,
  'Don Robuste physiquement : PV max = 20 + 7 (gain) + 6 (2 x niveau total 3)'
);
select is(
  (select count(*)::int from public.character_feats
     where character_id = 'a2000000-0000-0000-0000-000000000002'
       and feat_id = (select tough_feat_id from lvlup_fixture) and level_taken = 3),
  1,
  'Don Robuste physiquement : character_feats trace le don pris au niveau 3'
);
select is(
  (select count(*)::int from public.character_ability_increases
     where character_id = 'a2000000-0000-0000-0000-000000000002'),
  0,
  'Don Robuste physiquement : aucune augmentation de caractéristique (don sans ability_increase)'
);
select is(
  (select level from public.character_classes where id = 'c2000000-0000-0000-0000-000000000002'),
  3,
  'Don Robuste physiquement : character_classes.level incrémenté (2 -> 3)'
);

-- ===========================================================================
-- Tests 17-19 : don "Faveur de robustesse" sans caractéristique choisie
-- (isole le bonus pur de +40) -- Clerc niveau 1 -> 2.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a3000000-0000-0000-0000-000000000003', 'b3b3b3b3-3333-3333-3333-333333333333', 10, 10, 0);

insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c3000000-0000-0000-0000-000000000003', 'a3000000-0000-0000-0000-000000000003', clerc_id, 1, true, 0
from lvlup_fixture;

insert into public.character_ability_scores (character_id, ability_id, score)
select 'a3000000-0000-0000-0000-000000000003', a, 10
from unnest(array['str','dex','con','int','wis','cha']) as a;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
create temporary table lvlup_result_boon on commit drop as
select public.apply_level_up(
  p_character_id => 'a3000000-0000-0000-0000-000000000003',
  p_class_id => (select clerc_id from lvlup_fixture),
  p_class_name => 'Clerc',
  p_is_multiclassing => false,
  p_hp_rolled => 5,
  p_hp_method => 'moyenne',
  p_hp_gain => 5,
  p_choice => (select jsonb_build_object('kind', 'ability_score_improvement', 'feat_id', fortitude_boon_feat_id) from lvlup_fixture)
) as result;
reset role;

select is(
  (select (result ->> 'new_max_hp')::int from lvlup_result_boon),
  10 + 5 + 40,
  'Faveur de robustesse sans caractéristique choisie : PV max = 10 + 5 (gain) + 40 (bonus pur)'
);
select is(
  (select count(*)::int from public.character_ability_increases
     where character_id = 'a3000000-0000-0000-0000-000000000003'),
  0,
  'Faveur de robustesse sans caractéristique choisie : aucune augmentation de caractéristique écrite'
);
select is(
  (select count(*)::int from public.character_feats
     where character_id = 'a3000000-0000-0000-0000-000000000003'
       and feat_id = (select fortitude_boon_feat_id from lvlup_fixture)),
  1,
  'Faveur de robustesse : character_feats trace le don pris'
);

-- ===========================================================================
-- Tests 20-23 : don "Robuste" (ability_increase sans bonus de don particulier)
-- avec caractéristique choisie -- isole le bonus rétroactif de Constitution
-- SEUL (featTakenBonus = 0 pour ce don). Magicien niveau 1 -> 2.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a4000000-0000-0000-0000-000000000004', 'b3b3b3b3-3333-3333-3333-333333333333', 8, 8, 0);

insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c4000000-0000-0000-0000-000000000004', 'a4000000-0000-0000-0000-000000000004', magicien_id, 1, true, 0
from lvlup_fixture;

insert into public.character_ability_scores (character_id, ability_id, score)
values
  ('a4000000-0000-0000-0000-000000000004', 'str', 10),
  ('a4000000-0000-0000-0000-000000000004', 'dex', 10),
  ('a4000000-0000-0000-0000-000000000004', 'con', 13),
  ('a4000000-0000-0000-0000-000000000004', 'int', 15),
  ('a4000000-0000-0000-0000-000000000004', 'wis', 10),
  ('a4000000-0000-0000-0000-000000000004', 'cha', 10);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
create temporary table lvlup_result_resilient on commit drop as
select public.apply_level_up(
  p_character_id => 'a4000000-0000-0000-0000-000000000004',
  p_class_id => (select magicien_id from lvlup_fixture),
  p_class_name => 'Magicien',
  p_is_multiclassing => false,
  p_hp_rolled => 3,
  p_hp_method => 'moyenne',
  p_hp_gain => 3,
  p_choice => (select jsonb_build_object('kind', 'ability_score_improvement', 'feat_id', resilient_feat_id, 'feat_ability', 'con') from lvlup_fixture)
) as result;
reset role;

select is(
  (select (result ->> 'new_max_hp')::int from lvlup_result_resilient),
  8 + 3 + 2,
  'Don Robuste (+1 Constitution 13->14) : PV max = 8 + 3 (gain) + 2 (1 x niveau total 2), pas de bonus de don pur'
);
select is(
  (select score from public.character_ability_scores
     where character_id = 'a4000000-0000-0000-0000-000000000004' and ability_id = 'con'),
  14,
  'Don Robuste : Constitution incrémentée (13 -> 14)'
);
select results_eq(
  $$ select ability_id, increase, source from public.character_ability_increases
     where character_id = 'a4000000-0000-0000-0000-000000000004' $$,
  $$ values ('con', 1, 'feat') $$,
  'Don Robuste : character_ability_increases trace l''augmentation (source = feat)'
);
select is(
  (select count(*)::int from public.character_feats
     where character_id = 'a4000000-0000-0000-0000-000000000004'
       and feat_id = (select resilient_feat_id from lvlup_fixture)),
  1,
  'Don Robuste : character_feats trace le don pris'
);

-- ===========================================================================
-- Tests 24-29 : multiclassage réussi (Magicien niveau 4 déjà possédé, int
-- suffisant ; multiclasse dans Rôdeur, dex/wis suffisants) -- emplacements
-- de sorts recalculés au niveau de lanceur combiné (4 + 1/2 = 4, table des
-- lanceurs complets niveau 4 : [4,3,0,...]), slots_used préservé/plafonné
-- sur une ligne déjà existante.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a5000000-0000-0000-0000-000000000005', 'b3b3b3b3-3333-3333-3333-333333333333', 25, 20, 0);

insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c5000000-0000-0000-0000-000000000005', 'a5000000-0000-0000-0000-000000000005', magicien_id, 4, true, 0
from lvlup_fixture;

insert into public.character_ability_scores (character_id, ability_id, score)
values
  ('a5000000-0000-0000-0000-000000000005', 'str', 10),
  ('a5000000-0000-0000-0000-000000000005', 'dex', 14),
  ('a5000000-0000-0000-0000-000000000005', 'con', 12),
  ('a5000000-0000-0000-0000-000000000005', 'int', 16),
  ('a5000000-0000-0000-0000-000000000005', 'wis', 14),
  ('a5000000-0000-0000-0000-000000000005', 'cha', 10);

-- Ligne de sorts niveau 1 déjà existante avec slots_used=3 -- doit être
-- plafonnée (pas remise à zéro) au nouveau total recalculé (4).
insert into public.character_spell_slots (character_id, slot_level, slots_total, slots_used)
values ('a5000000-0000-0000-0000-000000000005', 1, 2, 2);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
create temporary table lvlup_result_multiclass on commit drop as
select public.apply_level_up(
  p_character_id => 'a5000000-0000-0000-0000-000000000005',
  p_class_id => (select rodeur_id from lvlup_fixture),
  p_class_name => 'Rôdeur',
  p_is_multiclassing => true,
  p_hp_rolled => 6,
  p_hp_method => 'moyenne',
  p_hp_gain => 6
) as result;
reset role;

select is(
  (select (result ->> 'new_level')::int from lvlup_result_multiclass),
  5,
  'Multiclassage : niveau total = 4 (Magicien) + 1 (nouveau Rôdeur) = 5'
);
select is(
  (select count(*)::int from public.character_classes
     where character_id = 'a5000000-0000-0000-0000-000000000005'
       and class_id = (select rodeur_id from lvlup_fixture) and level = 1 and is_primary = false and hit_dice_spent = 0),
  1,
  'Multiclassage : nouvelle ligne character_classes (Rôdeur, niveau 1, jamais primaire)'
);
select results_eq(
  $$ select slot_level, slots_total, slots_used from public.character_spell_slots
     where character_id = 'a5000000-0000-0000-0000-000000000005' order by slot_level $$,
  $$ values (1, 4, 2), (2, 3, 0) $$,
  'Multiclassage : emplacements de sorts combinés (niveau de lanceur 4) -- slots_used=2 préservé (pas remis à 0)'
);
select is(
  (select max_hp from public.characters where id = 'a5000000-0000-0000-0000-000000000005'),
  31,
  'Multiclassage : PV max = 25 + 6 (gain, aucun choix donc aucun rétroactif)'
);

-- Multiclassage refusé : prérequis de la nouvelle classe (Moine, dex+wis
-- >= 13) non rempli -- caractéristiques insuffisantes.
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a6000000-0000-0000-0000-000000000006', 'b3b3b3b3-3333-3333-3333-333333333333', 20, 20, 0);
insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c6000000-0000-0000-0000-000000000006', 'a6000000-0000-0000-0000-000000000006', guerrier_id, 3, true, 0
from lvlup_fixture;
insert into public.character_ability_scores (character_id, ability_id, score)
select 'a6000000-0000-0000-0000-000000000006', a, 10
from unnest(array['str','dex','con','int','wis','cha']) as a;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.apply_level_up(
       p_character_id => 'a6000000-0000-0000-0000-000000000006',
       p_class_id => (select moine_id from lvlup_fixture),
       p_class_name => 'Moine',
       p_is_multiclassing => true,
       p_hp_rolled => 5,
       p_hp_method => 'moyenne',
       p_hp_gain => 5
     ) $$,
  'P0001',
  null,
  'Multiclassage refusé : prérequis de la nouvelle classe (Moine, dex+wis >= 13) non rempli'
);
reset role;
select is(
  (select count(*)::int from public.character_classes where character_id = 'a6000000-0000-0000-0000-000000000006'),
  1,
  'Multiclassage refusé pour prérequis : aucune ligne character_classes ajoutée'
);

-- Multiclassage refusé : classe déjà possédée.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.apply_level_up(
       p_character_id => 'a6000000-0000-0000-0000-000000000006',
       p_class_id => (select guerrier_id from lvlup_fixture),
       p_class_name => 'Guerrier',
       p_is_multiclassing => true,
       p_hp_rolled => 5,
       p_hp_method => 'moyenne',
       p_hp_gain => 5
     ) $$,
  'P0001',
  null,
  'Multiclassage refusé : classe déjà possédée (Guerrier)'
);
reset role;

-- Multiclassage refusé : la classe déjà possédée (Guerrier, str=8 ET dex=8
-- ici -- le prérequis du Guerrier est un OU entre les deux, donc les DEUX
-- doivent être insuffisantes) ne remplit plus son propre prérequis --
-- défense en profondeur, même si la NOUVELLE classe (Clerc, wis=14, un
-- prérequis totalement indépendant de str/dex) serait éligible.
update public.character_ability_scores
   set score = 8
 where character_id = 'a6000000-0000-0000-0000-000000000006' and ability_id in ('str', 'dex');
update public.character_ability_scores
   set score = 14
 where character_id = 'a6000000-0000-0000-0000-000000000006' and ability_id = 'wis';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.apply_level_up(
       p_character_id => 'a6000000-0000-0000-0000-000000000006',
       p_class_id => (select clerc_id from lvlup_fixture),
       p_class_name => 'Clerc',
       p_is_multiclassing => true,
       p_hp_rolled => 5,
       p_hp_method => 'moyenne',
       p_hp_gain => 5
     ) $$,
  'P0001',
  null,
  'Multiclassage refusé : la classe déjà possédée (Guerrier, str=8 et dex=8) ne remplit plus son propre prérequis, même si la nouvelle classe (Clerc, wis=14) serait éligible'
);
reset role;

-- ===========================================================================
-- Tests 34-36 : multiclassage dans l'Occultiste -- magie de pacte recalculée
-- (niveau 1 : 1 charge, emplacement niveau 1), slots_used existant (3)
-- plafonné à la nouvelle charge disponible (1), jamais remis à 0.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a7000000-0000-0000-0000-000000000007', 'b3b3b3b3-3333-3333-3333-333333333333', 15, 15, 0);
insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c7000000-0000-0000-0000-000000000007', 'a7000000-0000-0000-0000-000000000007', guerrier_id, 2, true, 0
from lvlup_fixture;
insert into public.character_ability_scores (character_id, ability_id, score)
values
  ('a7000000-0000-0000-0000-000000000007', 'str', 13),
  ('a7000000-0000-0000-0000-000000000007', 'dex', 10),
  ('a7000000-0000-0000-0000-000000000007', 'con', 10),
  ('a7000000-0000-0000-0000-000000000007', 'int', 10),
  ('a7000000-0000-0000-0000-000000000007', 'wis', 10),
  ('a7000000-0000-0000-0000-000000000007', 'cha', 14);
insert into public.character_pact_slots (character_id, slot_level, slots_total, slots_used)
values ('a7000000-0000-0000-0000-000000000007', 3, 2, 3);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
select public.apply_level_up(
  p_character_id => 'a7000000-0000-0000-0000-000000000007',
  p_class_id => (select occultiste_id from lvlup_fixture),
  p_class_name => 'Occultiste',
  p_is_multiclassing => true,
  p_hp_rolled => 4,
  p_hp_method => 'moyenne',
  p_hp_gain => 4
);
reset role;

select results_eq(
  $$ select slot_level, slots_total, slots_used from public.character_pact_slots
     where character_id = 'a7000000-0000-0000-0000-000000000007' $$,
  $$ values (1, 1, 1) $$,
  'Multiclassage Occultiste : magie de pacte niveau 1 (1 charge), slots_used plafonné (3 -> 1), jamais remis à 0'
);
select is(
  (select count(*)::int from public.character_classes
     where character_id = 'a7000000-0000-0000-0000-000000000007'
       and class_id = (select occultiste_id from lvlup_fixture) and level = 1),
  1,
  'Multiclassage Occultiste : nouvelle ligne character_classes'
);
select is(
  (select count(*)::int from public.character_spell_slots
     where character_id = 'a7000000-0000-0000-0000-000000000007'),
  0,
  'Multiclassage Occultiste seul (aucune classe lanceuse "non-pacte") : aucun emplacement de sort classique créé'
);

-- ===========================================================================
-- Tests 37-39 : choix "style de combat" (character_class_options), aucun PV
-- rétroactif -- Guerrier niveau 1 -> 2.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a8000000-0000-0000-0000-000000000008', 'b3b3b3b3-3333-3333-3333-333333333333', 12, 12, 0);
insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c8000000-0000-0000-0000-000000000008', 'a8000000-0000-0000-0000-000000000008', guerrier_id, 1, true, 0
from lvlup_fixture;
insert into public.character_ability_scores (character_id, ability_id, score)
select 'a8000000-0000-0000-0000-000000000008', a, 10
from unnest(array['str','dex','con','int','wis','cha']) as a;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
create temporary table lvlup_result_style on commit drop as
select public.apply_level_up(
  p_character_id => 'a8000000-0000-0000-0000-000000000008',
  p_class_id => (select guerrier_id from lvlup_fixture),
  p_class_name => 'Guerrier',
  p_is_multiclassing => false,
  p_hp_rolled => 6,
  p_hp_method => 'moyenne',
  p_hp_gain => 6,
  p_choice => jsonb_build_object('kind', 'fighting_style', 'class_feature_id', 920001, 'chosen_value', 'Défense')
) as result;
reset role;

select is(
  (select (result ->> 'new_max_hp')::int from lvlup_result_style),
  18,
  'Style de combat : PV max = 12 + 6 (gain), aucun rétroactif'
);
select results_eq(
  $$ select class_feature_id, level, chosen_value from public.character_class_options
     where character_id = 'a8000000-0000-0000-0000-000000000008' $$,
  $$ values (920001, 2, 'Défense') $$,
  'Style de combat : character_class_options trace le choix au niveau 2'
);
select is(
  (select count(*)::int from public.character_ability_increases
     where character_id = 'a8000000-0000-0000-0000-000000000008'),
  0,
  'Style de combat : aucune caractéristique modifiée'
);

-- ===========================================================================
-- Tests 40-41 : choix "sous-classe" -- subclass_id écrit dans la même ligne
-- que le niveau, aucune autre table touchée, aucun PV rétroactif.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('a9000000-0000-0000-0000-000000000009', 'b3b3b3b3-3333-3333-3333-333333333333', 14, 14, 0);
insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'c9000000-0000-0000-0000-000000000009', 'a9000000-0000-0000-0000-000000000009', guerrier_id, 2, true, 0
from lvlup_fixture;
insert into public.character_ability_scores (character_id, ability_id, score)
select 'a9000000-0000-0000-0000-000000000009', a, 10
from unnest(array['str','dex','con','int','wis','cha']) as a;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
select public.apply_level_up(
  p_character_id => 'a9000000-0000-0000-0000-000000000009',
  p_class_id => (select guerrier_id from lvlup_fixture),
  p_class_name => 'Guerrier',
  p_is_multiclassing => false,
  p_hp_rolled => 6,
  p_hp_method => 'moyenne',
  p_hp_gain => 6,
  p_choice => (select jsonb_build_object('kind', 'subclass', 'subclass_id', subclass_a_id) from lvlup_fixture)
);
reset role;

select is(
  (select subclass_id from public.character_classes where id = 'c9000000-0000-0000-0000-000000000009'),
  (select subclass_a_id from lvlup_fixture),
  'Sous-classe : subclass_id écrit dans la même ligne character_classes que le niveau'
);
select is(
  (select level from public.character_classes where id = 'c9000000-0000-0000-0000-000000000009'),
  3,
  'Sous-classe : le niveau est aussi mis à jour dans la même écriture (2 -> 3)'
);

-- ===========================================================================
-- Tests 42-47 : sorts de départ + invocations + sorts innés raciaux, avec
-- déduplication contre un sort déjà connu -- multiclassage Occultiste.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('aa000000-0000-0000-0000-00000000000a', 'b3b3b3b3-3333-3333-3333-333333333333', 16, 16, 0);
insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'ca000000-0000-0000-0000-00000000000a', 'aa000000-0000-0000-0000-00000000000a', guerrier_id, 1, true, 0
from lvlup_fixture;
-- str=13 : le Guerrier déjà possédé doit lui-même rester éligible (défense
-- en profondeur revalidée à chaque multiclassage, voir plus haut), sans
-- quoi cet appel échouerait sur la classe déjà possédée plutôt que de
-- tester ce que ce bloc vise réellement (sorts/invocations/dédup).
insert into public.character_ability_scores (character_id, ability_id, score)
values
  ('aa000000-0000-0000-0000-00000000000a', 'str', 13),
  ('aa000000-0000-0000-0000-00000000000a', 'dex', 10),
  ('aa000000-0000-0000-0000-00000000000a', 'con', 10),
  ('aa000000-0000-0000-0000-00000000000a', 'int', 10),
  ('aa000000-0000-0000-0000-00000000000a', 'wis', 10),
  ('aa000000-0000-0000-0000-00000000000a', 'cha', 14);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
select public.apply_level_up(
  p_character_id => 'aa000000-0000-0000-0000-00000000000a',
  p_class_id => (select occultiste_id from lvlup_fixture),
  p_class_name => 'Occultiste',
  p_is_multiclassing => true,
  p_hp_rolled => 4,
  p_hp_method => 'moyenne',
  p_hp_gain => 4,
  p_initial_spell_ids => (select array[spell_a_id, spell_b_id] from lvlup_fixture),
  p_invocation_ids => (select array[invocation_a_id] from lvlup_fixture),
  p_racial_innate_spell_ids => (select array[spell_b_id, spell_c_id] from lvlup_fixture)
);
reset role;

select is(
  (select count(*)::int from public.character_spells
     where character_id = 'aa000000-0000-0000-0000-00000000000a'
       and spell_id = (select spell_a_id from lvlup_fixture)
       and status = 'connu'
       and source_class_id = (select occultiste_id from lvlup_fixture)),
  1,
  'Sorts de départ : spell_a connu, source_class_id = Occultiste (pas un lanceur "préparé")'
);
select is(
  (select count(*)::int from public.character_spells
     where character_id = 'aa000000-0000-0000-0000-00000000000a' and spell_id = (select spell_b_id from lvlup_fixture)),
  1,
  'Déduplication : spell_b (dans les sorts de départ ET les sorts innés raciaux) n''a qu''UNE seule ligne'
);
select is(
  (select status from public.character_spells
     where character_id = 'aa000000-0000-0000-0000-00000000000a' and spell_id = (select spell_b_id from lvlup_fixture)),
  'connu',
  'Déduplication : spell_b garde son statut de sort de départ (''connu''), pas réécrit en ''inné'''
);
select is(
  (select count(*)::int from public.character_spells
     where character_id = 'aa000000-0000-0000-0000-00000000000a'
       and spell_id = (select spell_c_id from lvlup_fixture) and status = 'inné' and source_class_id is null),
  1,
  'Sorts innés raciaux : spell_c (nouveau) inséré avec status=inné et source_class_id NULL'
);
select is(
  (select count(*)::int from public.character_invocations
     where character_id = 'aa000000-0000-0000-0000-00000000000a' and invocation_id = (select invocation_a_id from lvlup_fixture)),
  1,
  'Invocations : invocation_a écrite dans character_invocations'
);
select is(
  (select count(*)::int from public.character_spells where character_id = 'aa000000-0000-0000-0000-00000000000a'),
  3,
  'Total : 3 lignes character_spells (spell_a, spell_b une seule fois, spell_c) -- pas 4'
);

-- ===========================================================================
-- Tests 48-50 : atomicité -- une caractéristique absente de
-- character_ability_scores fait échouer l'étape ASI APRÈS que
-- characters/character_classes aient déjà été réellement écrits dans le
-- même appel.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('ab000000-0000-0000-0000-00000000000b', 'b3b3b3b3-3333-3333-3333-333333333333', 20, 20, 0);
insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'cb000000-0000-0000-0000-00000000000b', 'ab000000-0000-0000-0000-00000000000b', guerrier_id, 3, true, 0
from lvlup_fixture;
-- Volontairement incomplet : pas de ligne 'con' dans character_ability_scores.
insert into public.character_ability_scores (character_id, ability_id, score)
select 'ab000000-0000-0000-0000-00000000000b', a, 10
from unnest(array['str','dex','int','wis','cha']) as a;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.apply_level_up(
       p_character_id => 'ab000000-0000-0000-0000-00000000000b',
       p_class_id => (select guerrier_id from lvlup_fixture),
       p_class_name => 'Guerrier',
       p_is_multiclassing => false,
       p_hp_rolled => 7,
       p_hp_method => 'moyenne',
       p_hp_gain => 7,
       p_choice => '{"kind": "ability_score_improvement", "ability_allocations": {"con": 1}}'::jsonb
     ) $$,
  'P0001',
  null,
  'Caractéristique Constitution absente : échoue explicitement après l''écriture réelle du niveau/PV'
);
reset role;

select is(
  (select level from public.character_classes where id = 'cb000000-0000-0000-0000-00000000000b'),
  3,
  'Atomicité : aucune écriture ne persiste après l''échec -- level toujours 3 (pas 4)'
);
select is(
  (select max_hp from public.characters where id = 'ab000000-0000-0000-0000-00000000000b'),
  20,
  'Atomicité : aucune écriture ne persiste après l''échec -- max_hp toujours 20 (pas 27)'
);

-- ===========================================================================
-- Tests 51-52 : entrée malformée -- p_choice->>'kind' hors des 5 valeurs
-- connues lève une erreur explicite (P0001), sans aucune écriture.
-- ===========================================================================
insert into public.characters (id, owner_id, max_hp, current_hp, temporary_hp)
values ('ac000000-0000-0000-0000-00000000000c', 'b3b3b3b3-3333-3333-3333-333333333333', 9, 9, 0);
insert into public.character_classes (id, character_id, class_id, level, is_primary, hit_dice_spent)
select 'cc000000-0000-0000-0000-00000000000c', 'ac000000-0000-0000-0000-00000000000c', guerrier_id, 1, true, 0
from lvlup_fixture;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', 'b3b3b3b3-3333-3333-3333-333333333333', 'role', 'authenticated')::text,
  true
);
select throws_ok(
  $$ select public.apply_level_up(
       p_character_id => 'ac000000-0000-0000-0000-00000000000c',
       p_class_id => (select guerrier_id from lvlup_fixture),
       p_class_name => 'Guerrier',
       p_is_multiclassing => false,
       p_hp_rolled => 6,
       p_hp_method => 'moyenne',
       p_hp_gain => 6,
       p_choice => '{"kind": "invalide"}'::jsonb
     ) $$,
  'P0001',
  null,
  'p_choice->>''kind'' invalide lève une erreur explicite plutôt que de deviner un comportement'
);
reset role;

select is(
  (select max_hp from public.characters where id = 'ac000000-0000-0000-0000-00000000000c'),
  9,
  'Entrée malformée : aucune écriture ne persiste -- max_hp toujours 9'
);

select * from finish();

rollback;
