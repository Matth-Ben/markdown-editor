-- Phase 0 « hygiène invisible » (étape 4/5) : droits EXECUTE explicites et `pg_temp` en dernier
-- dans le `search_path` des fonctions `security definer`.
--
-- POURQUOI
--   (S07) Par défaut Supabase accorde EXECUTE à `anon`, `authenticated` et `service_role` sur toute
--   fonction du schéma public ; `revoke ... from public` seul ne retire pas `anon` (précédent :
--   20260908093000_lock_down_share_token_function_grants.sql). Résultat : des helpers de RLS,
--   des fonctions internes de triggers et des RPC réservées aux connectés sont appelables par
--   n'importe quel visiteur anonyme via /rest/v1/rpc/<nom>.
--   (S08) 24 fonctions `security definer` fixent `search_path = public` sans `pg_temp` : le
--   privilège TEMP est donné à PUBLIC, un attaquant pourrait masquer une table par une table
--   temporaire du même nom. `pg_temp` placé EN DERNIER supprime ce vecteur.
--
-- VÉRIFICATION DES USAGES (aucun droit utilisé n'est retiré)
--   - App mobile (lib/) : seules `claim_push_token`, `release_push_token` (gardées côté client par
--     `currentUser != null`), `claim_group_treasure_currency`, `get_group_member_character`,
--     `regenerate_character_share_token` et les RPC du combat sont appelées : toutes en session
--     connectée. `get_shared_character` (partage public par jeton) est la seule RPC anonyme : NON TOUCHÉE.
--   - Aucune politique visant `anon`/`public` n'appelle les helpers listés (vérifié sur pg_policies
--     du schéma rejoué) ; une politique `to authenticated` n'est jamais évaluée pour `anon`.
--   - Edge functions : utilisent `service_role`, dont EXECUTE est conservé partout.
--   - App web (apps/, packages/) : aucun appel rpc().
--
-- EFFET
--   A. `revoke all ... from public, anon` puis `grant execute ... to authenticated, service_role` sur :
--      owns_character, is_group_member, is_admin, group_member_can_read_character,
--      story_owner_can_read_character, character_owner_can_read_joined_story (helpers de RLS : les
--      politiques `to authenticated` continuent de les évaluer), claim_push_token, release_push_token,
--      claim_group_treasure_currency, get_group_member_character.
--   B. Fonctions internes, jamais appelées par un client : `refresh_proposal_counts` et les fonctions
--      de triggers (notify_character_campaign_access_revoked, notify_new_app_version, on_group_created,
--      trg_content_proposals_review, trg_refresh_proposal_counts) : `revoke all ... from public, anon,
--      authenticated`, `grant execute ... to service_role`. Un trigger n'exige pas EXECUTE au moment
--      où il se déclenche : seuls la création du trigger et l'appel direct le vérifient.
--   C. `alter function ... set search_path = public, pg_temp` sur les fonctions `security definer`
--      dont le réglage actuel est exactement `search_path=public` (liste de noms ci-dessous ; aucune
--      fonction inconnue n'est touchée). Aucune sémantique ne change.
--   Les fonctions de colonne calculée (group_members_display_name, *_author_name, stories_gm_display_name)
--   gardent leurs droits : leur restriction est un changement de contrat (S09), hors phase 0.
--   `claim_group_treasure_currency` n'est PAS réécrite (S03, changement de comportement) : seuls ses droits.
--
-- RISQUE
--   Très faible : metadata de catalogue, sans verrou long. Seul risque : un appelant anonyme que
--   la revue n'aurait pas vu (le contrôle « fonctions exécutables par anon » de la PR le détecte
--   avant). Test : supabase/tests/phase0_function_grants_test.sql.
--
-- RETOUR ARRIÈRE (aucune donnée en jeu) :
--   grant execute on function <signature> to anon, authenticated, public;   -- pour A et B
--   alter function <signature> set search_path = public;                    -- pour C

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
  r record;
  v_a_n int := 0;
  v_b_n int := 0;
  v_c_n int := 0;
begin
  -- A. Appelables par les utilisateurs connectés (et service_role), plus par anon/public.
  foreach v_sig in array v_a loop
    if to_regprocedure(v_sig) is null then
      raise notice 'phase0 droits : % absente, ignorée', v_sig;
      continue;
    end if;
    execute format('revoke all on function %s from public, anon', v_sig);
    execute format('grant execute on function %s to authenticated, service_role', v_sig);
    v_a_n := v_a_n + 1;
  end loop;

  -- B. Internes : service_role seulement.
  foreach v_sig in array v_b loop
    if to_regprocedure(v_sig) is null then
      raise notice 'phase0 droits : % absente, ignorée', v_sig;
      continue;
    end if;
    execute format('revoke all on function %s from public, anon, authenticated', v_sig);
    execute format('grant execute on function %s to service_role', v_sig);
    v_b_n := v_b_n + 1;
  end loop;

  -- C. pg_temp en dernier, uniquement pour les definer dont le réglage est exactement search_path=public.
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.prokind = 'f'
       and p.prosecdef
       and p.proname = any (v_c)
       and p.proconfig = array['search_path=public']
  loop
    execute format('alter function %s set search_path = public, pg_temp', r.sig);
    v_c_n := v_c_n + 1;
  end loop;

  raise notice 'phase0 droits : A=% fonctions, B=% fonctions, search_path=% fonctions', v_a_n, v_b_n, v_c_n;
end
$phase0$;
