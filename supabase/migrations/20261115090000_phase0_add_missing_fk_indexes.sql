-- Phase 0 « hygiène invisible » de la refonte de la base (étape 1/5) : index manquants
-- sur les clés étrangères et filtres réellement utilisés par l'app mobile (lib/) et par
-- les politiques RLS.
--
-- POURQUOI
--   Sur 98 clés étrangères du schéma public, 67 n'ont aucun index dont la première
--   colonne soit la clé. Les index « partiels » (character_spells_unique_*) et les
--   uniques composites commençant par une autre colonne (group_members(group_id, user_id))
--   ne servent pas un filtre sur character_id / user_id seul. Conséquence : chaque
--   `where character_id = ...` (64 usages dans lib/), `where owner_id = ...` (35) ou
--   `where user_id = ...` fait un parcours séquentiel, et chaque ligne évaluée par la RLS
--   (fonctions owns_character / group_member_can_read_character) en subit un second.
--   Les suppressions en cascade (suppression de personnage ou de compte) parcourent
--   aussi ces tables entières.
--
-- EFFET
--   27 index btree `<table>_<colonne>_idx`, créés avec `create index if not exists`.
--   Aucune colonne, politique, fonction ni contrat modifié ; les plans de requête
--   changent, pas les résultats. Aucun index redondant avec une clé primaire ni un
--   index unique existant (vérifié sur le rejeu des 157 migrations).
--   Garde contre les objets ajoutés hors migrations (D58/D72) : avant de créer un
--   index, le bloc ci-dessous vérifie qu'il n'existe pas déjà, SOUS UN AUTRE NOM, un
--   index valide non partiel dont les premières colonnes sont identiques ; le cas
--   échéant il saute la création et le signale (NOTICE).
--
-- RISQUE
--   `create index` (sans CONCURRENTLY, car le CLI exécute chaque migration dans une
--   transaction, où CONCURRENTLY est interdit) pose un verrou SHARE sur la table : les
--   lectures continuent, les écritures (insert/update/delete) de CETTE table attendent
--   la fin de la construction. Sur des tables de quelques milliers à quelques dizaines de
--   milliers de lignes, la construction dure de quelques millisecondes à une seconde.
--   Volumétrie réelle de production : INCONNUE (requête de contrôle fournie dans la PR).
--   `lock_timeout` à 10 s : si un verrou ne peut pas être obtenu, la migration échoue
--   proprement (rien n'est appliqué) au lieu de bloquer les écritures en file d'attente.
--   Coût en écriture : un petit surcoût d'insertion par index ; négligeable ici.
--
-- RETOUR ARRIÈRE (aucune donnée en jeu) : `drop index if exists public.<nom>;` pour chaque
-- index listé dans le tableau `v_indexes` ci-dessous (migration inverse triviale).

set local lock_timeout = '10s';

do $phase0$
declare
  -- (table, colonnes, nom). Nommage : <table>_<colonnes jointes par _>_idx.
  v_indexes constant text[][] := array[
    -- Tables enfants d'un personnage : filtre `character_id` (64 usages dans lib/) + cascade.
    array['characters',                    'owner_id',             'characters_owner_id_idx'],
    array['character_ability_increases',   'character_id',         'character_ability_increases_character_id_idx'],
    array['character_class_options',       'character_id',         'character_class_options_character_id_idx'],
    array['character_classes',             'character_id',         'character_classes_character_id_idx'],
    array['character_inventory',           'character_id',         'character_inventory_character_id_idx'],
    array['character_journal_entries',     'character_id',         'character_journal_entries_character_id_idx'],
    array['character_level_hp',            'character_id',         'character_level_hp_character_id_idx'],
    array['character_photos',              'character_id',         'character_photos_character_id_idx'],
    array['character_race_choices',        'character_id',         'character_race_choices_character_id_idx'],
    array['character_spells',              'character_id',         'character_spells_character_id_idx'],
    array['character_tool_proficiencies',  'character_id',         'character_tool_proficiencies_character_id_idx'],
    -- Groupes : fonctions RLS is_group_member / group_member_can_read_character,
    -- liste « mes groupes » (user_id), cascade de suppression de personnage.
    array['group_members',                 'user_id',              'group_members_user_id_idx'],
    array['group_members',                 'character_id',         'group_members_character_id_idx'],
    array['groups',                        'owner_id',             'groups_owner_id_idx'],
    array['group_journal_entries',         'group_id, user_id',    'group_journal_entries_group_id_user_id_idx'],
    array['group_journal_entries',         'user_id',              'group_journal_entries_user_id_idx'],
    array['group_notes',                   'user_id',              'group_notes_user_id_idx'],
    array['group_notes',                   'character_id',         'group_notes_character_id_idx'],
    -- Combat du groupe (PR #47) : filtres de lecture et cascades.
    array['combat_participants',           'character_id',         'combat_participants_character_id_idx'],
    array['combat_participants',           'user_id',              'combat_participants_user_id_idx'],
    array['combats',                       'started_by',           'combats_started_by_idx'],
    -- Signalements de bug : RLS `auth.uid() = reporter_id` + cascade.
    array['bug_reports',                   'reporter_id',          'bug_reports_reporter_id_idx'],
    array['bug_reports',                   'character_id',         'bug_reports_character_id_idx'],
    -- Liaison personnage <-> histoire (lecture MJ, fonction story_owner_can_read_character).
    array['character_campaigns',           'story_id',             'character_campaigns_story_id_idx'],
    -- Référence très lue par l'app (28 requêtes class_features, 3 spell_classes). Petites
    -- tables : gain modeste, mais clés étrangères sans index.
    array['class_features',                'class_id',             'class_features_class_id_idx'],
    array['class_features',                'subclass_id',          'class_features_subclass_id_idx'],
    array['spell_classes',                 'class_id',             'spell_classes_class_id_idx']
  ];
  v_i int;
  v_table text;
  v_cols text;
  v_name text;
  v_existing text;
  v_created int := 0;
  v_skipped int := 0;
begin
  for v_i in 1 .. array_length(v_indexes, 1) loop
    v_table := v_indexes[v_i][1];
    v_cols := v_indexes[v_i][2];
    v_name := v_indexes[v_i][3];

    if to_regclass(format('public.%I', v_table)) is null then
      raise notice 'phase0 index : table public.% absente, ignorée', v_table;
      v_skipped := v_skipped + 1;
      continue;
    end if;

    -- Index équivalent déjà présent (même table, valide, non partiel, mêmes premières
    -- colonnes dans le même ordre), quel que soit son nom ?
    select i.indexrelid::regclass::text into v_existing
      from pg_index i
     where i.indrelid = format('public.%I', v_table)::regclass
       and i.indisvalid
       and i.indpred is null
       and i.indexprs is null
       and (
         select array_agg(a.attname::text order by k.ord)
           from unnest(i.indkey::int2[]) with ordinality k(attnum, ord)
           join pg_attribute a on a.attrelid = i.indrelid and a.attnum = k.attnum
          where k.ord <= cardinality(string_to_array(replace(v_cols, ' ', ''), ','))
       ) = string_to_array(replace(v_cols, ' ', ''), ',')
     limit 1;

    if v_existing is not null then
      if v_existing <> v_name and v_existing <> format('public.%I', v_name) then
        raise notice 'phase0 index : % ignoré (index équivalent déjà présent : %)', v_name, v_existing;
      end if;
      v_skipped := v_skipped + 1;
      continue;
    end if;

    execute format('create index if not exists %I on public.%I (%s)', v_name, v_table, v_cols);
    v_created := v_created + 1;
  end loop;

  raise notice 'phase0 index : % index créés, % déjà présents ou ignorés', v_created, v_skipped;
end
$phase0$;
