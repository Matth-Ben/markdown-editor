-- Phase 0 « hygiène invisible » (étape 7/9, fichier 3/3) : index manquants sur clés étrangères — tables de référence.
--
-- Les 27 index de la phase 0 sont répartis en 3 fichiers (A : tables d'un personnage ; B : groupes, combat, signalements, liens
-- histoire ; C : tables de référence) : dans une même transaction, chaque `create index` garde son verrou SHARE jusqu'au commit ;
-- trois transactions plus courtes limitent la durée cumulée pendant laquelle les écritures des tables concernées sont bloquées.
--
-- POURQUOI : tables de référence très lues par l'app (28 requêtes `class_features`, 3 `spell_classes`) dont les clés étrangères n'ont aucun index ; petites tables (~1 000 lignes), gain modeste mais risque nul.
-- Les index « partiels » (character_spells_unique_*) et les uniques composites commençant par une autre colonne
-- (group_members(group_id, user_id)) ne servent pas un filtre sur la seule colonne visée.
--
-- EFFET : 3 index btree `<table>_<colonnes>_idx` en `create index if not exists` ; aucun contrat modifié, seuls les plans changent,
-- jamais les résultats. Garde contre les objets ajoutés hors migrations (D58/D72) : un index valide, non partiel, de mêmes premières
-- colonnes déjà présent SOUS UN AUTRE NOM est détecté et la création est sautée (NOTICE). Pas de CONCURRENTLY (interdit dans la
-- transaction du CLI) : verrou SHARE par table jusqu'au commit (lectures libres, écritures de la table en attente).
--
-- PRÉREQUIS D'EXÉCUTION : se connecter en connexion directe ou via le pooler en mode « session » (pas le pooler en mode
-- « transaction ») et vérifier `show statement_timeout;` : il doit laisser le temps de construire les index (volumétrie réelle
-- inconnue, requête C1). `lock_timeout` = 10 s : si un verrou n'est pas obtenu, la migration échoue sans rien appliquer.
--
-- RETOUR ARRIÈRE (aucune donnée en jeu) : drop index if exists public.<nom>; pour chacun de : class_features_class_id_idx, class_features_subclass_id_idx, spell_classes_class_id_idx

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
    array['class_features', 'class_id', 'class_features_class_id_idx'],
    array['class_features', 'subclass_id', 'class_features_subclass_id_idx'],
    array['spell_classes', 'class_id', 'spell_classes_class_id_idx']
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
