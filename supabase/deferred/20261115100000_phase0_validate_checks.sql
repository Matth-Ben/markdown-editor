-- Phase 0 (étape DIFFÉRÉE, après la 9/9) : validation des 10 contraintes CHECK ajoutées en NOT VALID par
-- 20261115094000_phase0_add_not_valid_checks.sql.
--
-- CE FICHIER N'EST VOLONTAIREMENT PAS DANS supabase/migrations/ : `db push` appliquerait toutes les migrations en attente d'un coup.
-- DÉPLACEMENT (à faire par Matthias, une fois les contrôles faits) :
--   1. relancer la requête de violations C6 : elle doit renvoyer 0 partout (condition NON négociable) ;
--   2. RENOMMER le fichier avec un horodatage STRICTEMENT POSTÉRIEUR à la dernière migration déjà appliquée en production (sinon le CLI
--      le refuse ou demande --include-all), p. ex. `git mv supabase/deferred/20261115100000_phase0_validate_checks.sql
--      supabase/migrations/<AAAAMMJJHHMMSS>_phase0_validate_checks.sql` ;
--   3. dry-run, puis application HORS HEURES DE POINTE. Une contrainte est validée par transaction : le bloc ci-dessous les valide
--      toutes dans la même transaction ; sur de grosses tables, scinder (une contrainte par fichier : dupliquer ce fichier en ne gardant
--      qu'un nom dans la liste) pour limiter la durée de chaque lecture complète.
--
-- EFFET : `validate constraint` parcourt la table et vérifie les lignes existantes. Verrou
-- SHARE UPDATE EXCLUSIVE : les lectures ET les écritures continuent pendant la validation. Si une
-- ligne viole la règle, la commande échoue et rien n'est modifié (la contrainte reste NOT VALID).
-- Idempotent : une contrainte déjà validée est ignorée.
-- RETOUR ARRIÈRE : une contrainte validée ne se « dé-valide » pas ; pour la retirer, `drop constraint`
-- (voir la migration 20261115094000).

set local lock_timeout = '10s';

do $lt$
begin
  raise notice 'lock_timeout=%', current_setting('lock_timeout');
  if current_setting('lock_timeout') <> '10s' then
    raise exception 'lock_timeout=% (attendu 10s) : cette migration doit s''exécuter dans UNE transaction (connexion directe ou pooler en mode session ; jamais l''éditeur du tableau de bord sans avoir vu ce NOTICE, ni le pooler en mode transaction)', current_setting('lock_timeout');
  end if;
end
$lt$;

do $phase0$
declare
  r record;
  v_done int := 0;
begin
  for r in
    select c.conrelid::regclass::text as tbl, c.conname
      from pg_constraint c
     where c.contype = 'c'
       and not c.convalidated
       and c.connamespace = 'public'::regnamespace
       and c.conname in (
         'characters_hp_nonnegative', 'characters_xp_nonnegative', 'characters_currency_nonnegative',
         'group_treasure_currency_nonnegative', 'group_treasure_items_is_array',
         'character_inventory_quantity_nonnegative', 'character_classes_level_positive',
         'character_spell_slots_counts_nonnegative', 'character_pact_slots_counts_nonnegative',
         'character_feature_uses_remaining_nonnegative'
       )
  loop
    execute format('alter table %s validate constraint %I', r.tbl, r.conname);
    v_done := v_done + 1;
  end loop;
  raise notice 'phase0 validation : % contraintes validées', v_done;
end
$phase0$;
