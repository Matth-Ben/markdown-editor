-- Phase 0 « hygiène invisible » (étape 5/9, fichier 1/3) : index manquants sur clés étrangères — tables dun personnage.
--
-- Les 27 index de la phase 0 sont répartis en 3 fichiers (A : tables d'un personnage ; B : groupes, combat, signalements, liens
-- histoire ; C : tables de référence) : dans une même transaction, chaque `create index` garde son verrou SHARE jusqu'au commit ;
-- trois transactions plus courtes limitent la durée cumulée pendant laquelle les écritures des tables concernées sont bloquées.
--
-- POURQUOI : filtre `character_id` (64 usages dans lib/) et `owner_id` (35 usages) : chargement d'une fiche (26 requetes), liste des personnages, politiques RLS, cascades de suppression de personnage.
-- Les index « partiels » (character_spells_unique_*) et les uniques composites commençant par une autre colonne
-- (group_members(group_id, user_id)) ne servent pas un filtre sur la seule colonne visée.
--
-- EFFET : 11 index btree `<table>_<colonnes>_idx` en `create index if not exists` ; aucun contrat modifié, seuls les plans changent,
-- jamais les résultats. Garde contre les objets ajoutés hors migrations (D58/D72) : un index valide, non partiel, de mêmes premières
-- colonnes déjà présent SOUS UN AUTRE NOM est détecté et la création est sautée (NOTICE). Pas de CONCURRENTLY (interdit dans la
-- transaction du CLI) : verrou SHARE par table jusqu'au commit (lectures libres, écritures de la table en attente).
--
-- PRÉREQUIS D'EXÉCUTION : se connecter en connexion directe ou via le pooler en mode « session » (pas le pooler en mode
-- « transaction ») et vérifier `show statement_timeout;` : il doit laisser le temps de construire les index (volumétrie réelle
-- inconnue, requête C1). `lock_timeout` = 10 s : si un verrou n'est pas obtenu, la migration échoue sans rien appliquer.
--
-- RETOUR ARRIÈRE (aucune donnée en jeu) : drop index if exists public.<nom>; pour chacun de : characters_owner_id_idx, character_ability_increases_character_id_idx, character_class_options_character_id_idx, character_classes_character_id_idx, character_inventory_character_id_idx, character_journal_entries_character_id_idx, character_level_hp_character_id_idx, character_photos_character_id_idx, character_race_choices_character_id_idx, character_spells_character_id_idx, character_tool_proficiencies_character_id_idx

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
  -- (table, colonnes, nom). Nommage : <table>_<colonnes jointes par _>_idx.
  v_indexes constant text[][] := array[
    array['characters', 'owner_id', 'characters_owner_id_idx'],
    array['character_ability_increases', 'character_id', 'character_ability_increases_character_id_idx'],
    array['character_class_options', 'character_id', 'character_class_options_character_id_idx'],
    array['character_classes', 'character_id', 'character_classes_character_id_idx'],
    array['character_inventory', 'character_id', 'character_inventory_character_id_idx'],
    array['character_journal_entries', 'character_id', 'character_journal_entries_character_id_idx'],
    array['character_level_hp', 'character_id', 'character_level_hp_character_id_idx'],
    array['character_photos', 'character_id', 'character_photos_character_id_idx'],
    array['character_race_choices', 'character_id', 'character_race_choices_character_id_idx'],
    array['character_spells', 'character_id', 'character_spells_character_id_idx'],
    array['character_tool_proficiencies', 'character_id', 'character_tool_proficiencies_character_id_idx']
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
