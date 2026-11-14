-- Phase 0, étape 3 : contraintes CHECK `NOT VALID` (20261115094000_phase0_add_not_valid_checks.sql)
-- et leur validation différée (supabase/deferred/20261115100000_phase0_validate_checks.sql).
--
-- Couvre : présence et statut « non validée » des 10 contraintes ; refus (SQLSTATE 23514) d'une valeur
-- hors borne pour chacune ; acceptation des valeurs limites ; cycle de vie NOT VALID : une ligne fautive
-- déjà présente est tolérée à l'ajout, bloque tout UPDATE de cette ligne (risque documenté), fait échouer la
-- validation tant qu'elle n'est pas corrigée, puis la validation réussit.
-- Lancer : supabase test db supabase/tests --local   (BEGIN/ROLLBACK : rien ne persiste)

begin;

select plan(31);

-- Fixtures (postgres contourne la RLS) -----------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
values ('f0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-checks@test.local', now(), now());
insert into public.characters (id, owner_id, name)
values ('f1000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001', 'Test checks');
insert into public.groups (id, name, owner_id, invite_code)
values ('f2000000-0000-4000-8000-000000000001', 'pgTAP checks', 'f0000000-0000-4000-8000-000000000001', 'PGTAPCK1');
insert into public.group_treasure (group_id) values ('f2000000-0000-4000-8000-000000000001') on conflict do nothing;
insert into public.character_inventory (id, character_id, custom_name)
values ('f3000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', 'objet');
insert into public.character_classes (id, character_id, class_id, level)
values ('f4000000-0000-4000-8000-000000000001', 'f1000000-0000-4000-8000-000000000001', (select min(id) from public.classes), 1);
insert into public.character_spell_slots (character_id, slot_level) values ('f1000000-0000-4000-8000-000000000001', 1);
insert into public.character_pact_slots (character_id, slot_level) values ('f1000000-0000-4000-8000-000000000001', 1);
insert into public.character_feature_uses (character_id, class_feature_id)
values ('f1000000-0000-4000-8000-000000000001', (select min(id) from public.class_features));

-- 1. Les 10 contraintes existent et sont NOT VALID (validation séparée) ---------------------------------
select is((select count(*) from pg_constraint
            where contype = 'c' and connamespace = 'public'::regnamespace and not convalidated
              and conname in ('characters_hp_nonnegative', 'characters_xp_nonnegative', 'characters_currency_nonnegative',
                              'group_treasure_currency_nonnegative', 'group_treasure_items_is_array',
                              'character_inventory_quantity_nonnegative', 'character_classes_level_positive',
                              'character_spell_slots_counts_nonnegative', 'character_pact_slots_counts_nonnegative',
                              'character_feature_uses_remaining_nonnegative'))::int,
          10, '10 contraintes présentes, toutes NOT VALID');

-- 2. Valeurs hors borne refusées (23514) -----------------------------------------------------------
select throws_ok($q$update public.characters set current_hp = -1 where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_hp_nonnegative"', 'characters : current_hp négatif refusé');
select throws_ok($q$update public.characters set temporary_hp = -1 where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_hp_nonnegative"', 'characters : temporary_hp négatif refusé');
select throws_ok($q$update public.characters set xp = -1 where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_xp_nonnegative"', 'characters : xp négatif refusé');
select throws_ok($q$update public.characters set currency_gp = -1 where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_currency_nonnegative"', 'characters : currency_gp négatif refusé');
select throws_ok($q$update public.characters set currency_pp = -1 where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_currency_nonnegative"', 'characters : currency_pp négatif refusé');
select throws_ok($q$update public.characters set currency_ep = -1 where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_currency_nonnegative"', 'characters : currency_ep négatif refusé');
select throws_ok($q$update public.characters set currency_sp = -1 where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_currency_nonnegative"', 'characters : currency_sp négatif refusé');
select throws_ok($q$update public.characters set currency_cp = -1 where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_currency_nonnegative"', 'characters : currency_cp négatif refusé');
select throws_ok($q$update public.group_treasure set currency_gp = -1 where group_id = 'f2000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "group_treasure" violates check constraint "group_treasure_currency_nonnegative"', 'group_treasure : or négatif refusé (S02/I03)');
select throws_ok($q$update public.group_treasure set currency_cp = -5 where group_id = 'f2000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "group_treasure" violates check constraint "group_treasure_currency_nonnegative"', 'group_treasure : cuivre négatif refusé');
select throws_ok($q$update public.group_treasure set items = '{}'::jsonb where group_id = 'f2000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "group_treasure" violates check constraint "group_treasure_items_is_array"', 'group_treasure : items non tableau refusé');
select throws_ok($q$update public.character_inventory set quantity = -1 where id = 'f3000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "character_inventory" violates check constraint "character_inventory_quantity_nonnegative"', 'character_inventory : quantité négative refusée');
select throws_ok($q$update public.character_classes set level = 0 where id = 'f4000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "character_classes" violates check constraint "character_classes_level_positive"', 'character_classes : niveau 0 refusé');
select throws_ok($q$update public.character_spell_slots set slots_used = -1 where character_id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "character_spell_slots" violates check constraint "character_spell_slots_counts_nonnegative"', 'character_spell_slots : slots_used négatif refusé');
select throws_ok($q$update public.character_spell_slots set slots_total = -1 where character_id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "character_spell_slots" violates check constraint "character_spell_slots_counts_nonnegative"', 'character_spell_slots : slots_total négatif refusé');
select throws_ok($q$update public.character_pact_slots set slots_used = -1 where character_id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "character_pact_slots" violates check constraint "character_pact_slots_counts_nonnegative"', 'character_pact_slots : slots_used négatif refusé');
select throws_ok($q$update public.character_feature_uses set uses_remaining = -1 where character_id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "character_feature_uses" violates check constraint "character_feature_uses_remaining_nonnegative"', 'character_feature_uses : usages négatifs refusés');

-- 3. Valeurs limites acceptées (aucune règle plus stricte que prévu) --------------------------------------
select lives_ok($q$update public.characters set current_hp = 0, temporary_hp = 0, xp = 0, currency_gp = 0, currency_pp = 0, currency_ep = 0, currency_sp = 0, currency_cp = 0 where id = 'f1000000-0000-4000-8000-000000000001'$q$, 'characters : zéro accepté');
select lives_ok($q$update public.characters set current_hp = 999, temporary_hp = 50, xp = 355000, currency_gp = 100000 where id = 'f1000000-0000-4000-8000-000000000001'$q$, 'characters : grandes valeurs acceptées (aucun plafond)');
select lives_ok($q$update public.group_treasure set currency_gp = 0, currency_pp = 12, items = '[]'::jsonb where group_id = 'f2000000-0000-4000-8000-000000000001'$q$, 'group_treasure : zéro et tableau acceptés');
select lives_ok($q$update public.character_inventory set quantity = 0 where id = 'f3000000-0000-4000-8000-000000000001'$q$, 'character_inventory : quantité 0 acceptée');
select lives_ok($q$update public.character_classes set level = 20 where id = 'f4000000-0000-4000-8000-000000000001'$q$, 'character_classes : niveau 20 accepté');
select lives_ok($q$update public.character_spell_slots set slots_total = 4, slots_used = 4 where character_id = 'f1000000-0000-4000-8000-000000000001'$q$, 'character_spell_slots : utilisés = total accepté');
select lives_ok($q$update public.character_pact_slots set slots_total = 2, slots_used = 0 where character_id = 'f1000000-0000-4000-8000-000000000001'$q$, 'character_pact_slots : valeurs normales acceptées');
select lives_ok($q$update public.character_feature_uses set uses_remaining = 0 where character_id = 'f1000000-0000-4000-8000-000000000001'$q$, 'character_feature_uses : zéro accepté');

-- 4. Cycle de vie NOT VALID / VALIDATE (ligne fautive historique) ------------------------------------------
alter table public.characters drop constraint characters_xp_nonnegative;
update public.characters set xp = -10 where id = 'f1000000-0000-4000-8000-000000000001';   -- ligne « historique » fautive
alter table public.characters add constraint characters_xp_nonnegative check (xp >= 0) not valid;

select is((select convalidated from pg_constraint where conname = 'characters_xp_nonnegative' and conrelid = 'public.characters'::regclass),
          false, 'ajout NOT VALID : la ligne fautive existante est tolérée');
select throws_ok($q$update public.characters set name = 'autre nom' where id = 'f1000000-0000-4000-8000-000000000001'$q$, '23514', 'new row for relation "characters" violates check constraint "characters_xp_nonnegative"',
                 'RISQUE DOCUMENTÉ : tout UPDATE de la ligne fautive échoue tant qu''elle n''est pas corrigée');
select throws_ok($q$alter table public.characters validate constraint characters_xp_nonnegative$q$, '23514', 'check constraint "characters_xp_nonnegative" of relation "characters" is violated by some row',
                 'validation refusée tant qu''une ligne viole la règle (rien n''est modifié)');
alter table public.characters drop constraint characters_xp_nonnegative;
update public.characters set xp = 0 where id = 'f1000000-0000-4000-8000-000000000001';             -- correction de la donnée
alter table public.characters add constraint characters_xp_nonnegative check (xp >= 0) not valid;
select lives_ok($q$alter table public.characters validate constraint characters_xp_nonnegative$q$, 'validation réussie après correction');
select is((select convalidated from pg_constraint where conname = 'characters_xp_nonnegative' and conrelid = 'public.characters'::regclass),
          true, 'contrainte validée');

select * from finish();
rollback;
