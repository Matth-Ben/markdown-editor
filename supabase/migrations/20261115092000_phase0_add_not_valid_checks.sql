-- Phase 0 « hygiène invisible » (étape 3/5) : contraintes CHECK manquantes, ajoutées `NOT VALID`.
--
-- POURQUOI
--   Aucune contrainte de valeur n'existe sur les compteurs : PV, PV temporaires, XP et
--   monnaies de `characters`, trésor du groupe, emplacements de sorts... peuvent être
--   négatifs (S02/I02/I03 du diagnostic). `group_treasure` est même modifiable colonne par
--   colonne par tout membre du groupe (policy UPDATE) : rien n'empêche un solde négatif.
--   Les clients valident déjà ces bornes (ex. lib/features/characters/domain/currency_kind.dart :
--   « total absolu >= 0, sinon payload jamais rejoué » ; hp_adjustment.dart : `clamp(0, maxHp)`) :
--   la base ne fait que garantir ce que les deux apps supposent.
--
-- EFFET
--   12 contraintes CHECK, ajoutées en `NOT VALID` : PostgreSQL ne parcourt PAS la table
--   (verrou très bref, aucune lecture des lignes existantes) et applique la règle aux
--   INSERT et UPDATE à venir. La validation des lignes existantes est une étape séparée
--   (supabase/deferred/20261115100000_phase0_validate_checks.sql), à ne lancer qu'après
--   contrôle des données (requêtes de lecture seule dans la description de la PR).
--   Idempotent : une contrainte du même nom déjà présente est laissée telle quelle.
--
-- RISQUE (à lire avant d'appliquer)
--   Une contrainte NOT VALID n'ignore pas les anciennes lignes fautives en cas de MISE À JOUR :
--   tout UPDATE d'une ligne qui viole la règle (même sur une autre colonne) échoue avec
--   SQLSTATE 23514 jusqu'à correction de la ligne. Il faut donc lancer la requête de contrôle
--   AVANT d'appliquer cette migration (résultat attendu : 0 ligne partout). Si un client écrit
--   un jour une valeur hors borne, l'écriture est refusée (23514) au lieu d'être acceptée
--   silencieusement : comportement voulu, mais à connaître côté mobile (file hors ligne).
--   Bornes volontairement larges : `>= 0` / `>= 1`, aucun plafond (pas de règle D&D tranchée ici).
--   Non ajouté : current_hp <= max_hp (PV max temporaires, règle à trancher : regles-dnd),
--   max_hp >= 0, slots_used <= slots_total (recalculs transitoires possibles).
--   Aucun NOT NULL à ajouter : sur les tables utilisateur, toutes les colonnes nullables
--   (character_id de group_members/group_notes/bug_reports/combat_participants, campaign_id,
--   dates d'envoi...) sont nullables par conception (vérifié sur le schéma rejoué).
--
-- RETOUR ARRIÈRE : `alter table <t> drop constraint if exists <nom>;` pour chaque nom listé
-- dans `v_checks` ci-dessous.

set local lock_timeout = '10s';

do $phase0$
declare
  -- (table, nom de contrainte, expression)
  v_checks constant text[][] := array[
    array['characters', 'characters_hp_nonnegative',
          'current_hp >= 0 and temporary_hp >= 0'],
    array['characters', 'characters_xp_nonnegative',
          'xp >= 0'],
    array['characters', 'characters_currency_nonnegative',
          'currency_gp >= 0 and currency_pp >= 0 and currency_ep >= 0 and currency_sp >= 0 and currency_cp >= 0'],
    array['group_treasure', 'group_treasure_currency_nonnegative',
          'currency_gp >= 0 and currency_pp >= 0 and currency_ep >= 0 and currency_sp >= 0 and currency_cp >= 0'],
    array['group_treasure', 'group_treasure_items_is_array',
          'jsonb_typeof(items) = ''array'''],
    array['character_inventory', 'character_inventory_quantity_nonnegative',
          'quantity >= 0'],
    array['character_classes', 'character_classes_level_positive',
          'level >= 1'],
    array['character_spell_slots', 'character_spell_slots_counts_nonnegative',
          'slots_total >= 0 and slots_used >= 0'],
    array['character_pact_slots', 'character_pact_slots_counts_nonnegative',
          'slots_total >= 0 and slots_used >= 0'],
    array['character_feature_uses', 'character_feature_uses_remaining_nonnegative',
          'uses_remaining >= 0'],
    array['character_spells', 'character_spells_innate_uses_nonnegative',
          'innate_uses_spent >= 0'],
    array['combats', 'combats_round_positive',
          'round >= 1']
  ];
  v_i int;
  v_added int := 0;
  v_present int := 0;
begin
  for v_i in 1 .. array_length(v_checks, 1) loop
    if to_regclass(format('public.%I', v_checks[v_i][1])) is null then
      raise notice 'phase0 checks : table public.% absente, ignorée', v_checks[v_i][1];
      continue;
    end if;

    if exists (
      select 1 from pg_constraint
       where conrelid = format('public.%I', v_checks[v_i][1])::regclass
         and conname = v_checks[v_i][2]
    ) then
      v_present := v_present + 1;
      continue;
    end if;

    execute format('alter table public.%I add constraint %I check (%s) not valid',
                   v_checks[v_i][1], v_checks[v_i][2], v_checks[v_i][3]);
    v_added := v_added + 1;
  end loop;

  raise notice 'phase0 checks : % contraintes ajoutées (NOT VALID), % déjà présentes', v_added, v_present;
end
$phase0$;
