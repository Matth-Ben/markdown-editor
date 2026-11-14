-- Phase 0 « hygiène invisible » (étape 2/6) : politiques RLS, `auth.uid()` -> `(select auth.uid())`.
--
-- POURQUOI
--   Une politique écrite `auth.uid() = owner_id` rappelle auth.uid() (lecture de la
--   configuration de session + analyse JSON des claims) pour CHAQUE ligne examinée.
--   Écrite `(select auth.uid()) = owner_id`, la sous-requête est un « initplan » : évaluée
--   UNE fois par requête, puis réutilisée (recommandation Supabase « RLS performance »).
--   auth.uid() est stable pendant toute une requête : les deux écritures donnent exactement
--   le même résultat, ligne pour ligne.
--
-- EFFET
--   Réécriture, par `alter policy ... using (...) with check (...)`, des 26 politiques
--   (au 14/11/2026) des 8 tables ci-dessous dont l'expression contient un `auth.uid()` nu :
--     bug_reports (2), characters (4), group_journal_entries (4), group_members (2),
--     group_notes (4), groups (3), notification_preferences (3), user_push_tokens (4).
--   La transformation est mécanique et partout la même : chaque `auth.uid()` qui n'est pas
--   déjà dans un `select` devient `(select auth.uid())`. Noms, commande (select/insert/
--   update/delete), rôles (to authenticated) et sémantique INCHANGÉS ; les expressions
--   n'étant pas recopiées à la main mais relues dans pg_policies, une politique ajoutée
--   hors migrations (D58/D72) est transformée de la même façon, sans risque d'écrasement.
--   Idempotent : une politique déjà réécrite n'est plus touchée.
--
-- NON RÉÉCRIT, DÉLIBÉRÉMENT (voir la description de la PR, mesures à l'appui)
--   - Les ~77 politiques `owns_character(character_id)` des tables character_* : le remplacer
--     par `character_id in (select id from characters where owner_id = (select auth.uid()))`
--     n'apporte aucun gain mesuré (la fonction story_owner_can_read_character, évaluée en
--     premier par PostgreSQL, domine le coût) et ajouterait une dépendance à la RLS de
--     `characters`.
--   - Les politiques à base d'is_admin() (tables de référence, écriture seulement) : aucun
--     client, aucun gain.
--   - stories, codex_entries, character_campaigns (sous-requête sur stories),
--     content_proposals/proposal_* : legacy gelé ou sans client (S01, M02).
--
-- RISQUE
--   `alter policy` pose un verrou ACCESS EXCLUSIVE (MESURÉ sur Postgres 17 via pg_locks : lectures ET écritures de la table
--   attendent), conservé jusqu'au commit pour les 8 tables : la migration dure ~150 ms sur le jeu de test, mais elle attend
--   la fin des requêtes en cours sur ces tables. `lock_timeout` à 10 s : échec propre (rien d'appliqué) plutôt qu'une file
--   d'attente qui bloquerait tout derrière elle. Appliquer hors pic. Aucune réécriture de données.
--   Contrôle de non-régression : supabase/tests/phase0_rls_initplan_test.sql et la matrice scripts/phase0/rls_matrix.sql
--   (mêmes lignes visibles/modifiables pour propriétaire, membre de groupe, tiers, anonyme).
--
-- RETOUR ARRIÈRE : exécuter le bloc inverse (remet `auth.uid()` nu ; aucune donnée en jeu) :
--   do $$ declare r record; begin
--     for r in select tablename, policyname, qual, with_check from pg_policies
--              where schemaname = 'public' and tablename in ('bug_reports','characters',
--                'group_journal_entries','group_members','group_notes','groups',
--                'notification_preferences','user_push_tokens')
--     loop
--       execute format('alter policy %I on public.%I%s%s', r.policyname, r.tablename,
--         case when r.qual is null then '' else ' using (' ||
--           regexp_replace(r.qual, '\( SELECT auth\.uid\(\) AS uid\)', 'auth.uid()', 'g') || ')' end,
--         case when r.with_check is null then '' else ' with check (' ||
--           regexp_replace(r.with_check, '\( SELECT auth\.uid\(\) AS uid\)', 'auth.uid()', 'g') || ')' end);
--     end loop;
--   end $$;

set local lock_timeout = '10s';

do $phase0$
declare
  r record;
  v_new_using text;
  v_new_check text;
  v_sql text;
  v_done int := 0;
  v_unchanged int := 0;
begin
  for r in
    select schemaname, tablename, policyname, qual, with_check
      from pg_policies
     where schemaname = 'public'
       and tablename in (
         'bug_reports', 'characters', 'group_journal_entries', 'group_members',
         'group_notes', 'groups', 'notification_preferences', 'user_push_tokens'
       )
     order by tablename, policyname
  loop
    -- (?<!SELECT ) : ne retouche pas un auth.uid() déjà enveloppé (« ( SELECT auth.uid() AS uid) »).
    v_new_using := case when r.qual is null then null
      else regexp_replace(r.qual, '(?<!SELECT )auth\.uid\(\)', '(select auth.uid())', 'g') end;
    v_new_check := case when r.with_check is null then null
      else regexp_replace(r.with_check, '(?<!SELECT )auth\.uid\(\)', '(select auth.uid())', 'g') end;

    if v_new_using is not distinct from r.qual and v_new_check is not distinct from r.with_check then
      v_unchanged := v_unchanged + 1;
      continue;
    end if;

    v_sql := format('alter policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
    if v_new_using is not null then
      v_sql := v_sql || ' using (' || v_new_using || ')';
    end if;
    if v_new_check is not null then
      v_sql := v_sql || ' with check (' || v_new_check || ')';
    end if;
    execute v_sql;
    v_done := v_done + 1;
  end loop;

  raise notice 'phase0 RLS : % politiques réécrites, % déjà conformes ou sans auth.uid()', v_done, v_unchanged;
end
$phase0$;
