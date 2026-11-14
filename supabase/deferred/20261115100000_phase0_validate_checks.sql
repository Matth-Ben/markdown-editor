-- Phase 0 (étape 3b, DIFFÉRÉE) : validation des contraintes CHECK ajoutées en NOT VALID par
-- 20261115092000_phase0_add_not_valid_checks.sql.
--
-- CE FICHIER N'EST VOLONTAIREMENT PAS DANS supabase/migrations/ : `db push` appliquerait toutes les
-- migrations en attente d'un coup. Matthias le déplace (git mv) dans supabase/migrations/ seulement
-- après avoir lancé la requête de contrôle « violations » (description de la PR) et obtenu 0 ligne
-- partout, puis l'applique seul, avec --dry-run d'abord.
--
-- EFFET : `validate constraint` parcourt la table et vérifie les lignes existantes. Verrou
-- SHARE UPDATE EXCLUSIVE : les lectures ET les écritures continuent pendant la validation. Si une
-- ligne viole la règle, la commande échoue et rien n'est modifié (la contrainte reste NOT VALID).
-- Idempotent : une contrainte déjà validée est ignorée.
-- RETOUR ARRIÈRE : une contrainte validée ne se « dé-valide » pas ; pour la retirer, `drop constraint`
-- (voir la migration 20261115092000).

set local lock_timeout = '10s';

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
         'character_feature_uses_remaining_nonnegative', 'character_spells_innate_uses_nonnegative',
         'combats_round_positive'
       )
  loop
    execute format('alter table %s validate constraint %I', r.tbl, r.conname);
    v_done := v_done + 1;
  end loop;
  raise notice 'phase0 validation : % contraintes validées', v_done;
end
$phase0$;
