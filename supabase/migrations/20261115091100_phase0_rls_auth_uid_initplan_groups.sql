-- Phase 0 « hygiène invisible » (étape 3/9, fichier 2/3 des politiques RLS) : `auth.uid()` -> `(select auth.uid())` sur les 4 tables de groupe.
--
-- POURQUOI
--   Une politique écrite `auth.uid() = owner_id` rappelle auth.uid() (lecture de la configuration de session + analyse JSON des claims)
--   pour CHAQUE ligne examinée. Écrite `(select auth.uid()) = owner_id`, la sous-requête est un « initplan » évalué UNE fois par requête
--   (recommandation Supabase « RLS performance »). auth.uid() est stable pendant toute une requête : même résultat, ligne pour ligne.
--
-- EFFET
--   Réécriture par `alter policy ... using (...) with check (...)` des politiques de : les 4 tables de groupe, dans CET ordre (ordre de verrouillage groups -> group_members -> group_notes -> group_journal_entries, le même que celui des transactions applicatives (la création d'un groupe écrit groups puis group_members) pour éviter un deadlock).
--   Transformation mécanique : chaque `auth.uid()` qui n'est pas déjà dans un `select` devient `(select auth.uid())`. Noms, commande,
--   rôles (to authenticated) et sémantique INCHANGÉS ; les expressions sont relues dans pg_policies (pas de recopie à la main : une politique
--   ajoutée hors migrations est transformée de la même façon). Idempotent. 26 politiques au total sur les 3 fichiers (30 sur ces 8 tables).
--
-- NON RÉÉCRIT, DÉLIBÉRÉMENT (mesures dans la PR)
--   - les ~77 politiques `owns_character(character_id)` : aucun gain mesuré (story_owner_can_read_character, évaluée en premier, domine) ;
--   - les politiques is_admin() (écriture des tables de référence), stories, codex_entries, character_campaigns (sous-requête sur stories),
--     content_proposals/proposal_* : legacy gelé ou sans client.
--
-- VERROUS ET DEADLOCK (MESURÉ sur Postgres 17 via pg_locks)
--   `alter policy` pose un verrou ACCESS EXCLUSIVE, conservé jusqu'au commit : lectures ET écritures de la table attendent. D'où 3 fichiers
--   (3 transactions courtes) et un ordre de verrouillage cohérent avec les transactions applicatives. APPLIQUER SANS CRÉATION DE GROUPE NI
--   SUPPRESSION DE PERSONNAGE EN COURS, hors pic, après avoir vérifié l'absence de transaction longue (pg_stat_activity, xact_start > 1 min).
--   `lock_timeout` = 10 s : échec propre, rien d'appliqué, plutôt qu'une file de verrous.
--   PRÉREQUIS : connexion directe ou pooler en mode « session » ; NE PAS coller ce SQL dans l'éditeur du tableau de bord sans vérifier le
--   NOTICE `lock_timeout=10s` (la migration lève une exception si `set local` n'est pas dans une transaction).
--
-- Contrôle de non-régression : supabase/tests/phase0_rls_initplan_test.sql et la matrice scripts/phase0/rls_matrix.sql
-- (mêmes lignes visibles/modifiables pour propriétaire, équipier, MJ, tiers, anonyme, y compris les UPDATE de transfert de propriété).
--
-- RETOUR ARRIÈRE de CE fichier : exécuter le bloc inverse (remet `auth.uid()` nu ; aucune donnée en jeu ; testé sur le schéma rejoué ; l'`order by` reproduit l'ordre de verrouillage de la migration) :
--   do $$ declare r record; begin
--     for r in select tablename, policyname, qual, with_check from pg_policies
--              where schemaname = 'public' and tablename in ('groups', 'group_members', 'group_notes', 'group_journal_entries')
--              order by array_position(array['groups','group_members','group_notes','group_journal_entries'], tablename::text), policyname
--     loop
--       execute format('alter policy %I on public.%I%s%s', r.policyname, r.tablename,
--         case when r.qual is null then '' else ' using (' ||
--           regexp_replace(r.qual, '\( SELECT auth\.uid\(\) AS uid\)', 'auth.uid()', 'g') || ')' end,
--         case when r.with_check is null then '' else ' with check (' ||
--           regexp_replace(r.with_check, '\( SELECT auth\.uid\(\) AS uid\)', 'auth.uid()', 'g') || ')' end);
--     end loop;
--   end $$;

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
  v_tables constant text[] := array['groups', 'group_members', 'group_notes', 'group_journal_entries'];
  v_table text;
  r record;
  v_new_using text;
  v_new_check text;
  v_sql text;
  v_done int := 0;
  v_unchanged int := 0;
begin
  foreach v_table in array v_tables loop
    for r in
      select schemaname, tablename, policyname, qual, with_check
        from pg_policies
       where schemaname = 'public' and tablename = v_table
       order by policyname
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
  end loop;

  raise notice 'phase0 RLS (%): % politiques réécrites, % déjà conformes ou sans auth.uid()', array_to_string(v_tables, ', '), v_done, v_unchanged;
end
$phase0$;
