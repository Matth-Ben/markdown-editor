-- Chantier "Personnages" (app mobile) — Phase 4 — préalable côté web.
-- Expose le nom d'affichage du MJ d'une histoire (04-fonctionnalites-app-mobile.md
-- section 7.2, 12-partage-et-groupes.md section 5), à deux endroits :
--   1. preview-story-invite / join-story (edge functions, client
--      service_role) — étape de confirmation du parcours "Rejoindre une
--      histoire".
--   2. Lecture directe PostgREST par le mobile sur
--      character_campaigns -> stories (carte "Aventures" persistante de la
--      fiche personnage), sans changer la forme des requêtes déjà en place
--      côté mobile (character_campaigns(id, story_id, stories(title,
--      cover_image_path))).
--
-- Contexte : jusqu'ici, le nom du MJ était volontairement omis des deux
-- (décision produit du 30/08/2026 documentée dans
-- preview-story-invite/index.ts et
-- nexus-jdr-app-mobile/lib/features/characters/domain/character_adventure.dart :
-- "aucune notion de profil utilisateur/nom d'affichage n'existe dans le
-- schéma web"). Ce n'est plus tout à fait vrai : depuis un chantier récent
-- du dépôt mobile, un utilisateur PEUT avoir renseigné un nom d'affichage
-- via `auth.updateUser({data: {full_name: ...}})` (`user_metadata.full_name`,
-- Supabase Auth standard, partagé entre les deux apps). Aucune UI web ne
-- permet encore de le renseigner, donc la plupart des MJ (qui n'utilisent
-- que l'app web) n'en auront pas — le repli "pas de nom" (null) reste donc
-- le cas courant à court terme, mais peupler le champ quand il existe ne
-- coûte rien à construire dès maintenant.
--
-- `stories` n'a pas de RLS qui autorise une jointure directe vers
-- `auth.users` (schéma système, jamais exposé à PostgREST) : la fonction
-- ci-dessous est `security definer` pour lire `auth.users` en SQL brut, en
-- ne retournant QUE le nom d'affichage dérivé (jamais l'email ni aucun
-- autre champ de `auth.users`) — surface d'exposition minimale,
-- volontairement réduite à ce seul scalaire sûr. Même style que les
-- helpers security-definer déjà présents dans ce dépôt
-- (public.is_admin(), public.owns_character(), public.story_owner_can_read_character(),
-- public.character_owner_can_read_joined_story()) : `set search_path = public`
-- suffit ici (pas besoin d'ajouter "auth" au search_path : `auth.users` est
-- référencé en toutes lettres ci-dessous, donc sa résolution ne dépend pas
-- du search_path — seul un nom non qualifié le pourrait).
--
-- Patron PostgREST "colonne calculée" (computed column) : une fonction qui
-- prend la ligne `stories` en paramètre unique et retourne un scalaire
-- devient sélectionnable comme si c'était une colonne de `stories` dans
-- n'importe quel `.select()` existant, SANS parenthèses (aliasable comme
-- une colonne normale) :
--   stories?select=title,gm_display_name:stories_gm_display_name
-- Vérifié fonctionner contre ce projet (PostgREST v14.15 en local, cf.
-- `docker ps`), à la fois avec le client service_role et avec un client
-- authenticated soumis à RLS. La forme avec parenthèses
-- (`stories_gm_display_name()`, celle du "computed relationship" utilisé
-- pour des fonctions retournant `setof`) échoue ici avec PGRST200
-- ("Could not find a relationship between 'stories' and
-- 'stories_gm_display_name'") : ne pas l'utiliser côté mobile/edge
-- functions, c'est la forme sans parenthèses qui est le contrat.
create or replace function public.stories_gm_display_name(story public.stories)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select nullif(trim(u.raw_user_meta_data->>'full_name'), '')
  from auth.users u
  where u.id = story.user_id;
$$;

-- authenticated : pour la lecture directe PostgREST côté mobile (relation
-- calculée sur un .select() authentifié, ex. carte "Aventures").
-- service_role : pour l'appel depuis les edge functions preview-story-invite
-- et join-story (client admin, même motif que les GRANTs de
-- 20260830100200_grant_service_role_join_story.sql — un rôle qui contourne
-- déjà RLS par construction n'a pas pour autant de privilège EXECUTE
-- implicite sur les fonctions, il faut l'accorder explicitement).
grant execute on function public.stories_gm_display_name(public.stories) to authenticated;
grant execute on function public.stories_gm_display_name(public.stories) to service_role;

comment on function public.stories_gm_display_name(public.stories) is
  'Nom d''affichage du MJ d''une histoire (auth.users.raw_user_meta_data->>''full_name'', via auth.updateUser côté app mobile), ou null si absent/vide. Ne retourne JAMAIS l''email ni aucun autre champ de auth.users. Security definer : seule voie légitime de lecture dérivée de auth.users depuis public/PostgREST (auth.users lui-même n''est jamais exposé). Exposée comme relation calculée PostgREST sur stories (04-fonctionnalites-app-mobile.md section 7.2, 12-partage-et-groupes.md section 5).';
