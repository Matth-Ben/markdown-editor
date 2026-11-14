-- Phase 0 « hygiène invisible » (étape 5/6) : droits EXECUTE explicites et `pg_temp` en dernier
-- dans le `search_path` des fonctions `security definer`.
--
-- POURQUOI
--   (S07) Par défaut Supabase accorde EXECUTE à `anon`, `authenticated` et `service_role` sur toute fonction du schéma public ;
--   `revoke ... from public` seul ne retire pas `anon` (précédent : 20260908093000_lock_down_share_token_function_grants.sql). Des helpers
--   de RLS, des fonctions internes de triggers et des RPC réservées aux connectés sont donc appelables par n'importe quel visiteur anonyme
--   via /rest/v1/rpc/<nom>.
--   (S08) 24 fonctions `security definer` fixent `search_path = public` sans `pg_temp` : le privilège TEMP est donné à PUBLIC, un attaquant
--   pourrait masquer une table par une table temporaire du même nom. `pg_temp` placé EN DERNIER supprime ce vecteur.
--
-- VÉRIFICATION DES USAGES (aucun droit utilisé n'est retiré)
--   - App mobile (lib/) : seules `claim_push_token`, `release_push_token` (gardées côté client par `currentUser != null`),
--     `claim_group_treasure_currency`, `get_group_member_character`, `regenerate_character_share_token` et les RPC du combat sont appelées,
--     en session connectée. `get_shared_character` (partage public par jeton) est la seule RPC anonyme : NON TOUCHÉE.
--   - Edge functions : `service_role`, dont EXECUTE est conservé. App web (apps/, packages/) : aucun appel rpc().
--
-- GARDE-FOU (la migration échoue proprement, SANS RIEN RÉVOQUER, si la production contient un appelant que le dépôt ne montre pas)
--   Avant tout REVOKE, exception (avec la liste des objets) si l'une des 16 fonctions concernées est référencée par :
--     - une politique RLS de N'IMPORTE QUEL schéma (storage inclus) dont les rôles incluent `public` ou `anon` (ou sans clause TO) ;
--     - une vue ou vue matérialisée (hors catalogues) ; un défaut de colonne / colonne générée ; une contrainte CHECK ;
--     - une fonction NON `security definer` exécutable par `anon` (hors les 16 fonctions elles-mêmes, qui perdent anon).
--   La même vérification existe en lecture seule dans scripts/phase0/controles_lecture_seule.sql (requête C11) : à lancer AVANT.
--   Les écarts de décompte (production avec objets hors dépôt) ne font PAS échouer : ils sont signalés par NOTICE/WARNING.
--
-- EFFET
--   A. `revoke all ... from public, anon` puis `grant execute ... to authenticated, service_role` sur 10 fonctions : owns_character,
--      is_group_member, is_admin, group_member_can_read_character, story_owner_can_read_character, character_owner_can_read_joined_story
--      (helpers de RLS : les politiques `to authenticated` continuent de les évaluer), claim_push_token, release_push_token,
--      claim_group_treasure_currency, get_group_member_character.
--   B. 6 fonctions internes, jamais appelées par un client : refresh_proposal_counts et les fonctions de triggers
--      (notify_character_campaign_access_revoked, notify_new_app_version, on_group_created, trg_content_proposals_review,
--      trg_refresh_proposal_counts) : `revoke all ... from public, anon, authenticated`, `grant execute ... to service_role`. Un trigger
--      n'exige pas EXECUTE quand il se déclenche (seuls la création du trigger et l'appel direct le vérifient).
--   C. `alter function ... set search_path = public, pg_temp` sur les fonctions `security definer` dont le réglage actuel est exactement
--      `search_path=public` (liste de noms ci-dessous ; aucune fonction inconnue n'est touchée ; les autres sont listées en NOTICE).
--   Non touchées : les fonctions de colonne calculée (group_members_display_name, *_author_name, stories_gm_display_name : S09, contrat) ;
--   `claim_group_treasure_currency` n'est pas réécrite (S03) : seuls ses droits changent.
--
-- RISQUE : metadata de catalogue, sans verrou long ; `lock_timeout` 10 s. Test : supabase/tests/phase0_function_grants_test.sql.
--
-- RETOUR ARRIÈRE (aucune donnée en jeu) :
--   grant execute on function <signature> to anon, authenticated;  -- A et B (+ `to public` pour retrouver l'ACL d'origine)
--   alter function <signature> set search_path = public;           -- C

set local lock_timeout = '10s';

do $phase0$
declare
  v_sig text;
  v_a constant text[] := array[
    'public.owns_character(uuid)',
    'public.is_group_member(uuid)',
    'public.is_admin()',
    'public.group_member_can_read_character(uuid)',
    'public.story_owner_can_read_character(uuid)',
    'public.character_owner_can_read_joined_story(uuid)',
    'public.claim_push_token(text, text)',
    'public.release_push_token(text)',
    'public.claim_group_treasure_currency(uuid, uuid, text, integer)',
    'public.get_group_member_character(uuid, uuid)'
  ];
  v_b constant text[] := array[
    'public.refresh_proposal_counts(uuid)',
    'public.notify_character_campaign_access_revoked()',
    'public.notify_new_app_version()',
    'public.on_group_created()',
    'public.trg_content_proposals_review()',
    'public.trg_refresh_proposal_counts()'
  ];
  v_c constant text[] := array[
    'apply_level_up', 'apply_rest', 'build_character_sheet_json', 'character_owner_can_read_joined_story',
    'claim_push_token', 'content_proposals_author_name', 'create_character', 'get_group_member_character',
    'get_shared_character', 'get_translation', 'group_member_can_read_character', 'group_members_display_name',
    'is_admin', 'is_group_member', 'notify_character_campaign_access_revoked', 'notify_new_app_version',
    'on_group_created', 'owns_character', 'proposal_comments_author_name', 'refresh_proposal_counts',
    'release_push_token', 'stories_gm_display_name', 'story_owner_can_read_character',
    'trg_refresh_proposal_counts'
  ];
  v_names text[];
  v_re text;
  v_found text := '';
  r record;
  v_a_n int := 0;
  v_b_n int := 0;
  v_c_n int := 0;
  v_c_skipped text := '';
begin
  -- ---------- Garde-fou : appelants anonymes/publics des 16 fonctions ----------
  v_names := array(select split_part(split_part(s, '(', 1), '.', 2) from unnest(v_a || v_b) s);
  v_re := '\m(' || array_to_string(v_names, '|') || ')\M';

  for r in
    select schemaname || '.' || tablename || ' : politique « ' || policyname || ' » (rôles ' || roles::text || ')' as obj
      from pg_policies
     where (roles && array['public', 'anon']::name[])
       and (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~ v_re
  loop v_found := v_found || E'\n  - ' || r.obj; end loop;

  for r in
    select 'vue ' || schemaname || '.' || viewname as obj from pg_views
     where schemaname not in ('pg_catalog', 'information_schema') and definition ~ v_re
    union all
    select 'vue matérialisée ' || schemaname || '.' || matviewname from pg_matviews
     where schemaname not in ('pg_catalog', 'information_schema') and definition ~ v_re
  loop v_found := v_found || E'\n  - ' || r.obj; end loop;

  for r in
    select 'défaut/colonne générée ' || c.oid::regclass::text || '.' || a.attname as obj
      from pg_attrdef d
      join pg_class c on c.oid = d.adrelid
      join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
     where c.relnamespace not in ('pg_catalog'::regnamespace, 'information_schema'::regnamespace)
       and pg_get_expr(d.adbin, d.adrelid) ~ v_re
  loop v_found := v_found || E'\n  - ' || r.obj; end loop;

  for r in
    select 'contrainte CHECK ' || conrelid::regclass::text || '.' || conname as obj from pg_constraint
     where contype = 'c' and pg_get_constraintdef(oid) ~ v_re
  loop v_found := v_found || E'\n  - ' || r.obj; end loop;

  for r in
    select 'fonction non security definer exécutable par anon : ' || p.oid::regprocedure::text as obj
      from pg_proc p
     where p.prokind = 'f' and not p.prosecdef
       and p.pronamespace not in ('pg_catalog'::regnamespace, 'information_schema'::regnamespace)
       and p.prosrc ~ v_re
       and p.oid::regprocedure::text <> all (select to_regprocedure(s)::text from unnest(v_a || v_b) s where to_regprocedure(s) is not null)
       and has_function_privilege('anon', p.oid, 'execute')
  loop v_found := v_found || E'\n  - ' || r.obj; end loop;

  if v_found <> '' then
    raise exception 'phase0 droits : des appelants anonymes/publics référencent les fonctions dont EXECUTE serait retiré, AUCUN droit modifié. Objets :%', v_found;
  end if;

  -- ---------- A. Appelables par les connectés (et service_role), plus par anon/public ----------
  foreach v_sig in array v_a loop
    if to_regprocedure(v_sig) is null then
      raise notice 'phase0 droits : % absente, ignorée', v_sig;
      continue;
    end if;
    execute format('revoke all on function %s from public, anon', v_sig);
    execute format('grant execute on function %s to authenticated, service_role', v_sig);
    v_a_n := v_a_n + 1;
  end loop;

  -- ---------- B. Internes : service_role seulement ----------
  foreach v_sig in array v_b loop
    if to_regprocedure(v_sig) is null then
      raise notice 'phase0 droits : % absente, ignorée', v_sig;
      continue;
    end if;
    execute format('revoke all on function %s from public, anon, authenticated', v_sig);
    execute format('grant execute on function %s to service_role', v_sig);
    v_b_n := v_b_n + 1;
  end loop;

  -- ---------- C. pg_temp en dernier (definer dont le réglage est exactement search_path=public) ----------
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.prosecdef
       and p.proname = any (v_c) and p.proconfig = array['search_path=public']
  loop
    execute format('alter function %s set search_path = public, pg_temp', r.sig);
    v_c_n := v_c_n + 1;
  end loop;

  -- Fonctions listées mais ignorées (absentes, non definer, ou réglage différent) : signalées, jamais bloquantes.
  for r in
    select n as proname, (select string_agg(coalesce(p.proconfig::text, 'sans réglage') || case when p.prosecdef then '' else ' [invoker]' end, ' ; ')
                            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = n) as cfg
      from unnest(v_c) n
     where not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = n
                          and p.prosecdef and p.proconfig = array['search_path=public, pg_temp'])
  loop
    v_c_skipped := v_c_skipped || format(E'\n  - %s : %s', r.proname, coalesce(r.cfg, 'absente'));
  end loop;
  if v_c_skipped <> '' then
    raise notice 'phase0 droits : fonctions de search_path ignorées (réglage différent de search_path=public, ou absentes) :%', v_c_skipped;
  end if;

  raise notice 'phase0 droits : A=% (10 attendues), B=% (6 attendues), search_path modifiées=% (24 attendues au premier passage)', v_a_n, v_b_n, v_c_n;
  if v_a_n <> 10 or v_b_n <> 6 then
    raise warning 'phase0 droits : décompte A/B différent des attendus (10/6) : la production contient des objets différents du dépôt, à examiner';
  end if;
end
$phase0$;
