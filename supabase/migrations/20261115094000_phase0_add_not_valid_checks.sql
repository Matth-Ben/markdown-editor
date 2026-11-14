-- Phase 0 « hygiène invisible » (étape 9/9) : contraintes CHECK manquantes, ajoutées `NOT VALID`.
--
-- POURQUOI
--   Aucune contrainte de valeur n'existe sur les compteurs : PV, PV temporaires, XP et monnaies de `characters`, trésor du groupe,
--   quantités, niveaux, emplacements de sorts... peuvent être négatifs (S02/I02/I03 du diagnostic). `group_treasure` est même
--   modifiable colonne par colonne par tout membre du groupe (policy UPDATE). Les clients valident déjà ces bornes
--   (lib/features/characters/domain/currency_kind.dart : « total absolu >= 0 » ; hp_adjustment.dart : `clamp(0, maxHp)`) : la base ne
--   fait que garantir ce que les deux apps supposent.
--
-- EFFET
--   10 contraintes CHECK, ajoutées en `NOT VALID` : PostgreSQL ne parcourt PAS la table à l'ajout et applique la règle aux INSERT et
--   UPDATE à venir. La validation des lignes existantes est une étape séparée (supabase/deferred/20261115100000_phase0_validate_checks.sql).
--   Déjà présentes dans le dépôt, donc NON recréées ici : character_spells.innate_uses_spent >= 0 et combats.round >= 1 (CHECK inline validés).
--
-- GARDE-FOUS (la migration échoue proprement, SANS RIEN AJOUTER, plutôt que de casser la production)
--   1. Violations : avant tout ajout, la migration compte les lignes qui violent chaque règle (c'est la requête C6 exécutée ici) ; si UNE
--      SEULE ligne viole UNE règle, exception qui liste table, contrainte et nombre de lignes. Raison : une contrainte NOT VALID fait échouer
--      tout UPDATE d'une ligne déjà fautive (SQLSTATE 23514), même sur une autre colonne.
--   2. Doublons : une contrainte du même nom OU de définition équivalente (comparée via pg_get_constraintdef, indépendamment du nom, des
--      espaces et des parenthèses) déjà présente sur la table n'est pas recréée (NOTICE).
--   Aucun NOT NULL à ajouter : les colonnes nullables des tables utilisateur le sont par conception.
--   Non ajouté (règles à trancher par regles-dnd ou recalculs transitoires) : current_hp <= max_hp, max_hp >= 0, slots_used <= slots_total,
--   plafond de niveau.
--
-- RISQUE : `ADD CONSTRAINT ... CHECK ... NOT VALID` prend un verrou ACCESS EXCLUSIVE sur la table : bref (aucun parcours des lignes), mais tenu
--   jusqu'au commit de la migration ; `lock_timeout` 10 s ; appliquer hors pic et sans transaction longue en cours (pg_stat_activity). Le comptage
--   des violations lit chaque table une fois (lecture seule) SANS verrou qui bloque les écritures : une ligne fautive écrite entre le comptage et
--   l'ajout n'est pas exclue (documenté ; un verrou SHARE ROW EXCLUSIVE préalable ne serait à ajouter que si les tables restent petites).
--   Non inspectés par la détection d'équivalence : expressions d'index, clauses WHEN de triggers, règles. Si un client écrit plus tard une valeur hors borne, l'écriture est refusée (23514) au lieu
--   d'être acceptée en silence : comportement voulu, à connaître côté mobile (file hors ligne).
--
-- RETOUR ARRIÈRE : alter table <t> drop constraint if exists <nom>; pour chaque nom listé dans `v_checks` ci-dessous.

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
          'uses_remaining >= 0']
  ];
  v_i int;
  v_need boolean[] := array_fill(false, array[array_length(v_checks, 1)]);
  v_norm text;
  v_found text;
  v_count bigint;
  v_viol text := '';
  v_added int := 0;
  v_present int := 0;
begin
  -- Passe 1 : quelles contraintes manquent réellement ?
  for v_i in 1 .. array_length(v_checks, 1) loop
    if to_regclass(format('public.%I', v_checks[v_i][1])) is null then
      raise notice 'phase0 checks : table public.% absente, ignorée', v_checks[v_i][1];
      continue;
    end if;

    -- Normalisation : minuscules, sans « NOT VALID » final, sans conversions de type (::text, ::integer...), sans espaces ni parenthèses.
    v_norm := 'check' || regexp_replace(regexp_replace(lower(v_checks[v_i][3]), '::[a-z_]+', '', 'g'), '[\s()]', '', 'g');
    select c.conname into v_found
      from pg_constraint c
     where c.conrelid = format('public.%I', v_checks[v_i][1])::regclass
       and c.contype = 'c'
       and (c.conname = v_checks[v_i][2]
            or regexp_replace(regexp_replace(regexp_replace(lower(pg_get_constraintdef(c.oid)), '\s+not\s+valid\s*$', ''), '::[a-z_]+', '', 'g'), '[\s()]', '', 'g') = v_norm)
     limit 1;

    if v_found is not null then
      if v_found <> v_checks[v_i][2] then
        raise notice 'phase0 checks : % ignorée (contrainte équivalente déjà présente : %)', v_checks[v_i][2], v_found;
      end if;
      v_present := v_present + 1;
    else
      v_need[v_i] := true;
    end if;
  end loop;

  -- Passe 2 (garde-fou) : aucune ligne existante ne doit violer une règle à ajouter.
  for v_i in 1 .. array_length(v_checks, 1) loop
    continue when not v_need[v_i];
    execute format('select count(*) from public.%I where not (%s)', v_checks[v_i][1], v_checks[v_i][3]) into v_count;
    if v_count > 0 then
      v_viol := v_viol || format(E'\n  - %s : %s (%s ligne(s) en violation)', v_checks[v_i][1], v_checks[v_i][2], v_count);
    end if;
  end loop;
  if v_viol <> '' then
    raise exception 'phase0 checks : des lignes existantes violent des règles, AUCUNE contrainte ajoutée. Corriger les données (requête C6) puis relancer :%', v_viol;
  end if;

  -- Passe 3 : ajout en NOT VALID.
  for v_i in 1 .. array_length(v_checks, 1) loop
    continue when not v_need[v_i];
    execute format('alter table public.%I add constraint %I check (%s) not valid',
                   v_checks[v_i][1], v_checks[v_i][2], v_checks[v_i][3]);
    v_added := v_added + 1;
  end loop;

  raise notice 'phase0 checks : % contraintes ajoutées (NOT VALID), % déjà présentes ou équivalentes (10 attendues au total)', v_added, v_present;
end
$phase0$;
