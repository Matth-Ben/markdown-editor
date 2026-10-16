-- Bug produit (12-partage-et-groupes.md section 2, dépôt
-- nexus-jdr-app-mobile) : supprimer un personnage engagé dans un groupe fait
-- disparaître le groupe ENTIER de la liste de groupes de son propriétaire.
--
-- Cause exacte (20260906182601_create_groups.sql) :
-- `group_members.character_id uuid references public.characters (id) on
-- delete cascade` -- supprimer un personnage supprimait donc toute la ligne
-- `group_members`, et `fetchMyGroups()` côté mobile filtre par `user_id`
-- (donc dépend de l'EXISTENCE de cette ligne pour que le groupe apparaisse
-- dans la liste). Comportement voulu : le groupe reste dans la liste, et à
-- la réouverture l'app doit proposer de choisir un nouveau personnage pour
-- continuer à le suivre.
--
-- Pourquoi pas un simple `on delete set null` sans rien d'autre : depuis
-- 20261013100000_group_member_without_character.sql, `character_id is null`
-- est le SEUL marqueur de "MJ sans personnage" (décision volontaire du
-- 12/10/2026), y compris dans l'index unique partiel
-- `group_members_one_null_character_per_group` (au plus un membre avec
-- `character_id is null` par groupe) et dans create-group/join-group. Un
-- simple `set null` transformerait donc silencieusement le propriétaire d'un
-- personnage supprimé en "MJ sans personnage" -- faux sémantiquement (il n'a
-- jamais choisi ce rôle), ET capable de violer l'index unique si le groupe a
-- déjà un vrai MJ sans personnage, ce qui ferait ÉCHOUER la suppression du
-- personnage elle-même (inacceptable : la suppression d'un personnage ne
-- doit jamais pouvoir échouer à cause de l'état d'un groupe tiers).
--
-- Solution : un troisième état, "orphelin", distinct du MJ volontaire.
-- `is_game_master boolean` devient la SEULE source de vérité pour "MJ sans
-- personnage" ; `character_id is null` seul ne suffit plus à le déterminer.
--   - MJ volontaire (create-group/join-group sans character_id) :
--     character_id = null, is_game_master = true.
--   - Orphelin (personnage supprimé) : character_id = null,
--     is_game_master = false.
-- Ce n'est PAS un troisième `GroupRole` (qui reste owner/membre, permission
-- de gestion -- voir le commentaire de 20261013100000_group_member_without_
-- character.sql, inchangé) : un orphelin peut être owner ou membre, exactement
-- comme avant la suppression de son personnage.
--
-- L'index unique partiel est réduit en conséquence
-- (`where character_id is null and is_game_master`) : il ne doit contraindre
-- que les MJ volontaires. Un membre orphelin ne doit jamais compter comme
-- "le MJ du groupe" ni entrer en conflit avec lui, et PLUSIEURS membres
-- orphelins doivent pouvoir coexister dans un même groupe (ex. deux joueurs
-- suppriment chacun leur personnage dans le même groupe) sans violer cette
-- contrainte.
--
-- Vérification faite avant d'écrire ce backfill (relecture complète de
-- 20261013100000_group_member_without_character.sql et
-- 20260906190500_group_member_can_read_characters.sql) : à ce jour, la SEULE
-- voie d'écriture de `group_members.character_id = null` est le MJ
-- volontaire via create-group/join-group (aucun code existant ne met déjà
-- `character_id` à null par suppression de personnage -- c'est précisément
-- le bug que cette migration corrige). Tous les `character_id is null`
-- existants en base sont donc, à ce jour, des MJ volontaires -- le backfill
-- ci-dessous est donc correct.

alter table public.group_members
  add column is_game_master boolean not null default false;

update public.group_members
  set is_game_master = true
  where character_id is null;

-- Remplace `on delete cascade` par `on delete set null` : la suppression
-- d'un personnage ne doit plus supprimer le rattachement au groupe, juste
-- libérer le lien -- le membre devient orphelin (is_game_master reste à sa
-- valeur actuelle, `false` par défaut pour une ligne qui avait un
-- personnage, ce qui est exactement l'état "orphelin" recherché).
alter table public.group_members
  drop constraint if exists group_members_character_id_fkey;

alter table public.group_members
  add constraint group_members_character_id_fkey
  foreign key (character_id) references public.characters (id) on delete set null;

-- Remplace l'ancien index (qui comptait TOUT character_id null comme "le MJ
-- du groupe") par un index scopé aux seuls MJ volontaires : un membre
-- orphelin (is_game_master = false) n'entre plus jamais en conflit avec un
-- vrai MJ, et plusieurs orphelins peuvent coexister dans le même groupe.
drop index if exists group_members_one_null_character_per_group;

create unique index group_members_one_game_master_per_group
  on public.group_members (group_id)
  where character_id is null and is_game_master;

comment on column public.group_members.is_game_master is
  'Vrai uniquement pour un MJ ayant volontairement choisi de rejoindre/créer le groupe sans personnage (create-group/join-group, character_id fourni absent -- décision du 12/10/2026). Un membre avec character_id null ET is_game_master = false est un ORPHELIN : son personnage a été supprimé (on delete set null depuis cette migration), il reste dans le groupe en attendant que son joueur choisisse un nouveau personnage via set-group-character. is_game_master, pas character_id is null seul, est la source de vérité pour distinguer les deux cas -- voir le commentaire d''en-tête de cette migration.';

-- set-group-character (edge function, service_role) a besoin de lire/écrire
-- cette colonne -- déjà couvert par les GRANTs existants sur toute la table
-- group_members pour service_role (select, insert --
-- 20260906190000_grant_service_role_group_functions.sql) et authenticated
-- (select -- 20260906182601_create_groups.sql), mais l'UPDATE de
-- character_id par set-group-character passe par le client service_role,
-- qui n'avait jusqu'ici aucun GRANT UPDATE sur cette table (aucune edge
-- function existante n'en avait besoin -- join-group/create-group ne font
-- que des INSERT).
grant update on table public.group_members to service_role;

-- group_members_display_name --------------------------------------------
--
-- Limitation documentée dans lib/features/groups/data/group_member_row_mapper.dart
-- (dépôt mobile) : "aucune colonne/fonction Postgres n'expose aujourd'hui le
-- nom de compte d'un AUTRE utilisateur à ce dépôt [...] une future colonne
-- calculée analogue à stories_gm_display_name permettrait d'exposer le vrai
-- nom de compte à tous les membres." Nécessaire dès maintenant : un MJ
-- volontaire ET un orphelin n'ont ni l'un ni l'autre de fiche personnage à
-- résoudre pour s'afficher dans la liste des membres -- le mobile a besoin
-- d'un nom de repli.
--
-- Même patron EXACT que public.stories_gm_display_name
-- (20260906000000_add_stories_gm_display_name.sql, s'y référer pour le détail
-- du mécanisme PostgREST "colonne calculée" et sa vérification) -- générique
-- ici plutôt que spécifique au MJ : fonctionne pour n'importe quelle ligne
-- group_members (le mobile peut l'utiliser aussi bien pour un MJ volontaire
-- que pour un orphelin, ou même un membre avec personnage si un jour utile).
-- Security definer pour lire auth.users (jamais exposé directement à
-- PostgREST), ne retourne QUE le nom d'affichage dérivé -- jamais l'email ni
-- aucun autre champ de auth.users.
create or replace function public.group_members_display_name(member public.group_members)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select nullif(trim(u.raw_user_meta_data->>'full_name'), '')
  from auth.users u
  where u.id = member.user_id;
$$;

grant execute on function public.group_members_display_name(public.group_members) to authenticated;
grant execute on function public.group_members_display_name(public.group_members) to service_role;

comment on function public.group_members_display_name(public.group_members) is
  'Nom d''affichage du membre (auth.users.raw_user_meta_data->>''full_name'', via auth.updateUser côté app mobile), ou null si absent/vide. Ne retourne JAMAIS l''email ni aucun autre champ de auth.users. Security definer : seule voie légitime de lecture dérivée de auth.users depuis public/PostgREST. Exposée comme relation calculée PostgREST sur group_members (même patron que public.stories_gm_display_name, 20260906000000_add_stories_gm_display_name.sql) -- utile pour un MJ volontaire (is_game_master) comme pour un membre orphelin (character_id null, is_game_master false), qui n''ont ni l''un ni l''autre de fiche personnage à résoudre pour s''afficher.';
