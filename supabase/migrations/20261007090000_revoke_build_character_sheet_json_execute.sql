-- Corrige 20260927100000_group_member_character_sheet.sql : le
-- `revoke execute ... from public` posé sur build_character_sheet_json
-- était insuffisant. Constat vérifié sur le projet distant le 2026-10-07
-- (lecture de pg_proc et has_function_privilege) : la fonction, pourtant
-- décrite comme "usage interne uniquement (aucun GRANT)", était exécutable
-- par `anon` ET par `authenticated`.
--
-- Cause : exactement celle déjà documentée pour get_translation dans
-- 20260908094500_fix_share_token_function_grants_anon_revoke.sql. Ce projet
-- Supabase applique (comme tout projet provisionné standard) des `alter
-- default privileges in schema public grant ... to anon, authenticated,
-- service_role`, qui accordent EXECUTE directement à ces rôles (pas
-- seulement à PUBLIC) sur toute fonction nouvellement créée dans le schéma
-- public. `revoke ... from public` ne retire que le droit implicite "tout le
-- monde", pas ces droits explicites. Il faut révoquer de CHAQUE rôle.
--
-- Conséquence avant ce correctif : build_character_sheet_json étant
-- SECURITY DEFINER et sans aucun contrôle d'accès propre (ce contrôle est
-- porté par ses deux appelantes), un appel direct à
-- /rest/v1/rpc/build_character_sheet_json avec l'UUID d'un personnage
-- renvoyait sa fiche complète (journal et photos compris) à n'importe quel
-- client, même anonyme, sans token de partage ni appartenance à un groupe.
--
-- Sans effet sur les appelantes légitimes : get_shared_character(text) et
-- get_group_member_character(uuid, uuid) sont SECURITY DEFINER et
-- appartiennent au même rôle que build_character_sheet_json (créées par la
-- même migration) ; elles l'appellent donc avec les droits de ce
-- propriétaire, qui conserve toujours EXECUTE sur sa propre fonction --
-- même mécanisme que get_translation, appelée de la même façon depuis
-- 20260908094500. Leurs propres privilèges ne sont pas modifiés ici :
-- get_shared_character reste appelable par anon (lien public par token).
--
-- Migration autonome et rejouable : ne dépend d'aucune autre migration
-- postérieure à 20260927100000, ne modifie ni table, ni corps de fonction.
-- service_role conserve EXECUTE (il contourne déjà RLS, aucun gain à le
-- retirer).
--
-- Retour arrière (rouvre la faille -- à n'utiliser que pour un diagnostic) :
--   grant execute on function public.build_character_sheet_json(uuid) to anon, authenticated;

revoke execute on function public.build_character_sheet_json(uuid) from anon, authenticated, public;

comment on function public.build_character_sheet_json(uuid) is
  'Construit le JSON complet d''une fiche de personnage en lecture seule. Usage interne : corps commun de get_shared_character (partage par token, 12-partage-et-groupes.md section 1) et de get_group_member_character (fiche d''un membre du même groupe, section 2), qui portent seules le contrôle d''accès. SECURITY DEFINER : lit directement les tables character_* et de référence sans passer par leurs policies RLS. N''inclut jamais owner_id, is_archived, ni character_campaigns/stories. Extraite de get_shared_character par 20260927100000. EXECUTE explicitement retiré à anon/authenticated/PUBLIC (20261007090000 -- le retrait initial, limité à PUBLIC, était insuffisant face aux "alter default privileges" de ce projet, même cause que get_translation en 20260908094500) : non appelable directement via /rest/v1/rpc/build_character_sheet_json.';
