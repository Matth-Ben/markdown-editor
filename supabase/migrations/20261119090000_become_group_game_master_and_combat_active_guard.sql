-- Groupes : « Devenir MJ du groupe » (A) et refus du départ du propriétaire / de la dissolution pendant un combat actif (B).
--
-- Origine : étape 3 de FEUILLE-DE-ROUTE.md (Grimoire, branche dev/nexus-desktop), décision n° 22 du 16/11/2026
-- (nexus-jdr-app-mobile/docs/api-refonte/00-decisions-et-vision.md) ; règle B : ticket « Combat : règle serveur, le
-- propriétaire ne quitte ni ne dissout le groupe pendant un combat actif » (dettes D222 et D224 du dépôt mobile).
-- Une seule PR pour les deux (décision de Matthias du 19/11/2026) : elles partagent le même contrôle « combat actif ».
--
-- POURQUOI
--   A. Un groupe créé dans Nexus par un propriétaire qui y joue un personnage n'a pas de MJ (`group_has_gm`,
--      20261114090000_create_group_combats.sql) : aucun combat ne peut y être lancé (`no_game_master`), et rien ne permet de
--      redevenir MJ sans personnage (l'edge function set-group-character refuse explicitement ce cas).
--   B. Seul Nexus empêchait, côté client, le propriétaire de quitter le groupe pendant un combat actif ; rien n'empêchait la
--      dissolution (DELETE direct sur `groups`, par Nexus comme par Grimoire) : le combat disparaissait en cascade sous les
--      joueurs, ou restait sans MJ (« MJ parti »). Le serveur devient l'autorité.
--
-- EFFET
--   1. `group_assert_no_active_combat(p_group_id)` : SEUL contrôle « combat actif », partagé par A et B. Lève `combat_active`
--      (SQLSTATE P0001) si un combat `status = 'active'` existe pour le groupe. Interne (service_role seulement).
--   2. Trigger BEFORE DELETE sur `groups` (`groups_before_delete_combat_guard`) : dissolution refusée pendant un combat actif,
--      quel que soit le rôle (authenticated, service_role, postgres).
--   3. Trigger BEFORE DELETE sur `group_members` (`group_members_before_delete_combat_guard`) : la suppression de la ligne du
--      PROPRIÉTAIRE est refusée pendant un combat actif (départ volontaire, auto-exclusion via « Owner can remove a member »,
--      service_role). Les autres membres quittent / sont exclus comme avant (le trigger de départ de la PR #47 retire leur
--      ligne PJ du combat).
--   4. RPC `become_group_game_master(p_group_id uuid) returns group_members` (authenticated) : voir son en-tête plus bas.
--
-- NE BLOQUE JAMAIS (testé dans supabase/tests/group_game_master_combat_guard_test.sql)
--   - La suppression d'un compte (droit RGPD) : `delete-account` -> auth.admin.deleteUser -> DELETE sur auth.users -> cascades
--     vers `groups` (owner_id) et `group_members` (user_id). Ces cascades s'exécutent APRÈS la suppression de la ligne
--     auth.users (commande précédente de la même transaction) : les deux triggers laissent passer dès que le compte concerné
--     n'existe plus dans auth.users. Aucun client ne peut produire cet état autrement (les politiques DELETE exigent que
--     l'appelant soit le propriétaire, donc un compte existant).
--   - La dissolution d'un groupe sans combat actif et ses cascades (group_members, group_treasure, group_notes,
--     group_journal_entries, combats terminés, combat_participants) : quand `group_members` est vidé en cascade depuis
--     `groups`, la ligne `groups` a déjà disparu, le trigger de `group_members` laisse passer (le contrôle a eu lieu sur
--     `groups`). Le rollback de create-group (DELETE d'un groupe tout juste créé) n'a jamais de combat.
--   - Un groupe dont tous les combats sont terminés (`ended`), y compris un propriétaire seul.
--   - Le départ ou l'exclusion d'un membre non propriétaire, pendant un combat ou non.
--
-- CONCURRENCE (lectures en READ COMMITTED, niveau par défaut de PostgREST)
--   start_combat verrouille la ligne `groups` (FOR NO KEY UPDATE) avant de vérifier le MJ et d'insérer le combat. Les trois
--   chemins de cette migration prennent un verrou EN CONFLIT avec celui-là sur la MÊME ligne avant de regarder les combats :
--   - become_group_game_master : FOR SHARE explicite ;
--   - trigger de `group_members` (ligne du propriétaire seulement) : FOR SHARE explicite ;
--   - trigger de `groups` : la ligne est déjà verrouillée (FOR UPDATE) par le DELETE lui-même avant le trigger.
--   Le contrôle est ensuite fait par une instruction distincte (fonction VOLATILE, nouvel instantané) : soit start_combat a
--   validé avant et son combat est vu (`combat_active`), soit il attend le verrou puis relit l'état validé (`no_game_master`
--   si le propriétaire est parti, `group_not_found` si le groupe est dissous).
--   Pourquoi FOR SHARE et pas FOR NO KEY UPDATE : la RPC verrouille `groups` PUIS la ligne de membre, alors que le départ du
--   propriétaire verrouille la ligne de membre (DELETE) PUIS `groups` (trigger) ; l'ordre ne peut pas être inversé côté
--   départ (un trigger BEFORE DELETE s'exécute après le verrou de la ligne supprimée). Deux FOR SHARE étant compatibles, ces
--   deux chemins ne s'attendent plus sur `groups` et se départagent sur la seule ligne de membre : pas de deadlock (un
--   « Devenir MJ » et un « Quitter » simultanés du même propriétaire produisaient un 40P01 avec FOR NO KEY UPDATE, reproduit
--   sur Postgres 17 avant correction). FOR SHARE reste en conflit avec start_combat (FOR NO KEY UPDATE) et la dissolution
--   (FOR UPDATE), seuls cas à sérialiser.
--   Deadlock résiduel (40P01, détecté par PostgreSQL en ~1 s, transaction annulée sans effet, rejouable) : départ du
--   propriétaire et dissolution simultanés du même groupe (group_members -> groups contre groups -> group_members, ordre
--   imposé par le DELETE et la cascade), même classe que ceux déjà documentés par la PR #47. Contrat client : sur 40P01 ou
--   40001, afficher « Réessayez ».
--   Non couvert : une transaction cliente en REPEATABLE READ / SERIALIZABLE (aucun client ne le fait aujourd'hui).
--
-- CE QUE « DEVENIR MJ » FAIT AU PERSONNAGE (relecture de toutes les tables qui lient un groupe et un personnage)
--   - characters et ses tables enfants : rien. Le personnage reste dans la liste de son propriétaire.
--   - group_members.character_id : passe à NULL, is_game_master à true (même ligne : id, role, joined_at inchangés). Realtime
--     publie l'UPDATE (20261108090000) : les écrans « Groupe » ouverts se mettent à jour.
--   - Lecture de la fiche par les coéquipiers (`group_member_can_read_character`, get_group_member_character, vue
--     group_character_status_overview) : le personnage n'est plus dans le groupe, les autres membres ne le lisent plus.
--     Voulu : le personnage a quitté le groupe ; le propriétaire garde évidemment son accès.
--   - combat_participants des combats TERMINÉS : inchangés (historique : character_id et nom conservés). Combats actifs :
--     aucun, la demande est refusée (`combat_active`).
--   - group_notes : clé (group_id, user_id), character_id purement informatif (20261106090000) : la note est conservée telle
--     quelle (character_id n'est pas réécrit).
--   - group_journal_entries : aucune colonne personnage, inchangé.
--   - group_treasure : aucun lien vers un personnage ; ce qui a déjà été réclamé a été crédité au personnage et y reste.
--   - character_campaigns (lien histoire du web) : indépendant des groupes, inchangé.
--   Rien n'est supprimé. Redevenir joueur avec un personnage n'est pas prévu (set-group-character refuse un MJ) : hors périmètre.
--
-- AUTRE MJ QUE LE PROPRIÉTAIRE
--   join-group permet à un membre NON propriétaire de rejoindre sans personnage (is_game_master = true, role 'membre') ; l'index
--   unique partiel `group_members_one_game_master_per_group` n'admet qu'un MJ sans personnage par groupe. Conséquences : ce
--   membre ne débloque pas le combat (`group_has_gm` ne regarde que la ligne du propriétaire) et il empêche le propriétaire de
--   devenir MJ : refus `mj_already_assigned` (même code que join-group). Il faut d'abord l'exclure ; aucune rétrogradation
--   automatique (ce serait retirer un rôle à un autre joueur sans son accord).
--
-- RETOUR ARRIÈRE (aucune donnée en jeu ; les lignes déjà passées en MJ restent MJ) :
--   drop function if exists public.become_group_game_master(uuid);
--   drop trigger if exists group_members_before_delete_combat_guard on public.group_members;
--   drop trigger if exists groups_before_delete_combat_guard on public.groups;
--   drop function if exists public.on_group_member_delete_combat_guard();
--   drop function if exists public.on_group_delete_combat_guard();
--   drop function if exists public.group_assert_no_active_combat(uuid);
--
-- VERROUS : CREATE TRIGGER prend SHARE ROW EXCLUSIVE sur `groups` et `group_members` jusqu'au commit (écritures en attente,
-- lectures libres) : quelques millisecondes. `lock_timeout` = 10 s : échec propre, rien d'appliqué, plutôt qu'une file.

set local lock_timeout = '10s';

do $lt$
begin
  raise notice 'lock_timeout=%', current_setting('lock_timeout');
  if current_setting('lock_timeout') <> '10s' then
    raise exception 'lock_timeout=% (attendu 10s) : cette migration doit s''exécuter dans UNE transaction (connexion directe ou pooler en mode session ; jamais l''éditeur du tableau de bord sans avoir vu ce NOTICE, ni le pooler en mode transaction)', current_setting('lock_timeout');
  end if;
end
$lt$;

-- 1. Contrôle partagé ---------------------------------------------------------------------------------------------------
-- VOLATILE (défaut) à dessein : la requête prend son propre instantané, APRÈS le verrou posé par l'appelant (voir
-- CONCURRENCE). Security definer : lit `combats` sans dépendre de la RLS de l'appelant.
create or replace function public.group_assert_no_active_combat(p_group_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.combats c
     where c.group_id = p_group_id
       and c.status = 'active'
  ) then
    raise exception 'combat_active' using errcode = 'P0001';
  end if;
end;
$$;

comment on function public.group_assert_no_active_combat(uuid) is
  'Interne. Lève combat_active (P0001) si le groupe a un combat actif. Seul contrôle « combat actif » partagé par become_group_game_master et les triggers groups_before_delete_combat_guard / group_members_before_delete_combat_guard (20261119090000).';

-- 2. Dissolution ------------------------------------------------------------------------------------------------------------
create or replace function public.on_group_delete_combat_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Suppression de compte (RGPD) : DELETE en cascade depuis auth.users, la ligne du propriétaire a déjà disparu. Jamais
  -- bloquée par un combat.
  if not exists (select 1 from auth.users u where u.id = old.owner_id) then
    return old;
  end if;

  -- La ligne `groups` est déjà verrouillée par ce DELETE : pas de course avec start_combat.
  perform public.group_assert_no_active_combat(old.id);
  return old;
end;
$$;

drop trigger if exists groups_before_delete_combat_guard on public.groups;
create trigger groups_before_delete_combat_guard
  before delete on public.groups
  for each row execute function public.on_group_delete_combat_guard();

-- 3. Départ du propriétaire ------------------------------------------------------------------------------------------------
create or replace function public.on_group_member_delete_combat_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_owner uuid;
begin
  select g.owner_id into v_owner from public.groups g where g.id = old.group_id;

  -- Groupe introuvable : suppression en cascade depuis `groups` (dissolution déjà contrôlée sur `groups`).
  -- Ligne d'un autre membre que le propriétaire : jamais bloquée ici.
  if not found or v_owner is distinct from old.user_id then
    return old;
  end if;

  -- Suppression du compte du propriétaire (cascade depuis auth.users) : jamais bloquée.
  if not exists (select 1 from auth.users u where u.id = old.user_id) then
    return old;
  end if;

  -- FOR SHARE sur le groupe : en conflit avec start_combat (FOR NO KEY UPDATE) et la dissolution, compatible avec
  -- become_group_game_master (pas de deadlock, voir CONCURRENCE) ; puis contrôle par une instruction distincte.
  perform 1 from public.groups g where g.id = old.group_id for share;
  perform public.group_assert_no_active_combat(old.group_id);
  return old;
end;
$$;

drop trigger if exists group_members_before_delete_combat_guard on public.group_members;
create trigger group_members_before_delete_combat_guard
  before delete on public.group_members
  for each row execute function public.on_group_member_delete_combat_guard();

-- 4. Devenir MJ du groupe ----------------------------------------------------------------------------------------------------
-- become_group_game_master(p_group_id) -> group_members (la ligne de l'appelant après l'appel)
-- Propriétaire du groupe uniquement. Sa ligne `group_members` passe en MJ sans personnage (character_id = NULL,
-- is_game_master = true ; id, role et joined_at inchangés). Le personnage quitte le groupe et reste dans la liste du joueur.
-- Idempotent : déjà MJ sans personnage, la ligne est renvoyée telle quelle, sans écriture, y compris pendant un combat (rien
-- ne change, donc aucun personnage ne quitte le combat).
--
-- Choix d'une RPC SQL plutôt qu'une edge function : une seule transaction sérialisée avec start_combat (pas de fenêtre
-- entre la vérification « combat actif » et l'écriture), même contrôle partagé que les triggers, même convention d'erreurs
-- que les RPC de combat (PR #47), testable en pgTAP, rien à déployer à part la migration.
--
-- Erreurs (`message` = code stable, SQLSTATE entre parenthèses) :
--   not_authenticated     (28000) pas de session
--   group_not_found       (P0002) groupe inconnu, ou appelant ni propriétaire ni membre (l'existence n'est pas révélée)
--   not_group_owner       (42501) membre du groupe mais pas propriétaire (même code que les RPC de combat)
--   not_member            (P0002) propriétaire sans ligne group_members (il a quitté son groupe)
--   combat_active         (P0001) un combat est actif dans ce groupe
--   mj_already_assigned   (P0001) un autre membre est déjà MJ sans personnage (même code que join-group)
create or replace function public.become_group_game_master(p_group_id uuid)
returns public.group_members
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_member public.group_members;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  -- Contrôles d'accès SANS verrou (leçon D222 : un tiers qui connaît l'UUID d'un groupe ne doit pas pouvoir retarder les
  -- écritures de ce groupe).
  select g.owner_id into v_owner from public.groups g where g.id = p_group_id;
  if not found or not (v_owner = v_uid or public.is_group_member(p_group_id)) then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;
  if v_owner <> v_uid then
    raise exception 'not_group_owner' using errcode = '42501';
  end if;

  -- FOR SHARE sur la ligne du groupe : en conflit avec start_combat (FOR NO KEY UPDATE) et la dissolution (FOR UPDATE),
  -- compatible avec le trigger de départ du propriétaire (FOR SHARE), qui verrouille sa ligne de membre AVANT le groupe :
  -- la RPC et le départ se départagent sur la ligne de membre ci-dessous, sans deadlock (voir CONCURRENCE). Deux appels
  -- concurrents se sérialisent aussi sur cette ligne (le second voit la ligne déjà MJ : idempotent).
  perform 1 from public.groups g where g.id = p_group_id for share;
  if not found then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;

  select * into v_member
    from public.group_members m
   where m.group_id = p_group_id and m.user_id = v_uid
   for update;
  if not found then
    raise exception 'not_member' using errcode = 'P0002';
  end if;

  if v_member.is_game_master and v_member.character_id is null then
    return v_member;
  end if;

  perform public.group_assert_no_active_combat(p_group_id);

  if exists (
    select 1 from public.group_members m
     where m.group_id = p_group_id
       and m.id <> v_member.id
       and m.is_game_master
       and m.character_id is null
  ) then
    raise exception 'mj_already_assigned' using errcode = 'P0001';
  end if;

  begin
    update public.group_members
       set character_id = null,
           is_game_master = true
     where id = v_member.id
     returning * into v_member;
  exception when unique_violation then
    -- Course avec un join-group « sans personnage » validé entre le contrôle ci-dessus et l'écriture (join-group ne prend
    -- pas le verrou du groupe) : l'index group_members_one_game_master_per_group tranche.
    raise exception 'mj_already_assigned' using errcode = 'P0001';
  end;

  return v_member;
end;
$$;

comment on function public.become_group_game_master(uuid) is
  'Devenir MJ du groupe (propriétaire seulement) : sa ligne group_members passe en MJ sans personnage (character_id NULL, is_game_master true), le personnage reste dans sa liste. Idempotent. Erreurs (message, SQLSTATE) : not_authenticated 28000, group_not_found P0002, not_group_owner 42501, not_member P0002, combat_active P0001, mj_already_assigned P0001. Voir 20261119090000.';

-- Droits ------------------------------------------------------------------------------------------------------------------
-- RPC : authenticated seulement (jamais public/anon), comme les RPC de combat. Internes (contrôle partagé, fonctions de
-- trigger) : ni anon ni authenticated, service_role seulement (convention de la phase 0, 20261115093000). Un trigger
-- n'exige pas EXECUTE pour se déclencher.
revoke all on function public.become_group_game_master(uuid) from public, anon;
grant execute on function public.become_group_game_master(uuid) to authenticated;

revoke all on function public.group_assert_no_active_combat(uuid) from public, anon, authenticated;
revoke all on function public.on_group_delete_combat_guard() from public, anon, authenticated;
revoke all on function public.on_group_member_delete_combat_guard() from public, anon, authenticated;
grant execute on function public.group_assert_no_active_combat(uuid) to service_role;
grant execute on function public.on_group_delete_combat_guard() to service_role;
grant execute on function public.on_group_member_delete_combat_guard() to service_role;
