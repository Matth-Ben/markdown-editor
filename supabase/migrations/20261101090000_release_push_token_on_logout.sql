-- Registre d'audit RGPD (`.claude/agents/rgpd.md`, point B2) — libère le
-- jeton de notification push d'un appareil à la déconnexion simple.
--
-- Constat de l'audit : `user_push_tokens`
-- (20260906155351_create_notification_infrastructure.sql), réclamé via la
-- RPC `claim_push_token` (`SECURITY DEFINER`,
-- 20260906172849_fix_user_push_tokens_reassignment.sql), n'avait aucun
-- mécanisme de libération -- un jeton restait associé au compte précédent
-- après une déconnexion, jusqu'à ce qu'un AUTRE compte le réclame sur le
-- même appareil via `claim_push_token`. Risque concret : entre les deux, un
-- compte reçoit les notifications push destinées au compte précédent sur cet
-- appareil (ex. rappel de repos long, retrait d'accès à une histoire -- voir
-- 15-profil-parametres.md section 3).
--
-- Suppression de compte : DÉJÀ couverte nativement, sans cette migration --
-- `user_push_tokens.user_id` référence `auth.users(id) on delete cascade`
-- (20260906155351_create_notification_infrastructure.sql, ligne
-- `create table public.user_push_tokens`). L'étape 3 de l'edge function
-- `delete-account` (`auth.admin.deleteUser`) supprime donc déjà la ligne du
-- jeton en cascade -- aucune action supplémentaire requise pour ce cas, une
-- fonction dédiée serait une redondance. Reste donc seulement le cas
-- "déconnexion simple" (signOut sans suppression de compte), qu'aucun
-- mécanisme existant ne couvrait.
--
-- Même précaution que `claim_push_token` : `SECURITY DEFINER` qui force
-- TOUJOURS `user_id = auth.uid()` dans la clause WHERE, quoi que l'appelant
-- transmette -- impossible de libérer (ni, a fortiori, de lire ou modifier)
-- le jeton d'un autre utilisateur. Un appel sans session (`auth.uid()` NULL)
-- ne supprime jamais rien : `user_id` est `not null`, la comparaison à NULL
-- échoue toujours.
--
-- DELETE plutôt que désassociation (`user_id = NULL`) : `user_id` est
-- `not null` dans le schéma actuel (changer cette contrainte serait une
-- migration bien plus lourde pour un bénéfice nul), et un jeton délié n'a
-- aucune utilité propre tant que personne ne l'a réclamé -- `claim_push_token`
-- recrée la ligne au prochain upsert, quel que soit le compte connecté sur
-- cet appareil. Cohérent avec la policy DELETE déjà existante sur la table
-- (`"Owner can delete their user_push_tokens"`), que cette fonction
-- n'ajoute ni ne remplace : elle reste la voie normale pour un client qui
-- connaît encore le propriétaire actuel ; cette RPC est seulement un point
-- d'entrée explicite et nommé pour le flux de déconnexion côté app mobile.
--
-- EXECUTE : accordé uniquement à `authenticated`, PUBLIC explicitement
-- révoqué dès la création -- PostgreSQL accorde EXECUTE à PUBLIC par défaut
-- sur toute fonction nouvellement créée (contrairement aux tables), gap déjà
-- documenté et corrigé pour d'autres fonctions par
-- 20260908093000_lock_down_share_token_function_grants.sql. Un appel par
-- `anon` serait de toute façon sans effet (`auth.uid()` NULL, DELETE ne
-- trouve jamais de ligne), mais autant ne pas laisser l'EXECUTE PUBLIC
-- implicite traîner sur une fonction neuve plutôt que de reproduire le même
-- gap que `claim_push_token` (jamais corrigé, hors périmètre de cette
-- migration).
create or replace function public.release_push_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.user_push_tokens
  where token = p_token
    and user_id = auth.uid();
end;
$$;

revoke execute on function public.release_push_token(text) from public;
grant execute on function public.release_push_token(text) to authenticated;
