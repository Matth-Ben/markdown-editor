-- Combat du groupe (app mobile "Personnages") -- PR0 du chantier, spec
-- consolidée dans nexus-jdr-app-mobile/docs/combat-groupe.md (décisions de
-- Matthias du 12/11/2026). Cette migration pose le SCHÉMA, la RLS, les helpers,
-- le trigger de départ de membre et la publication Realtime. Les RPC
-- d'écriture sont dans 20261114091000_group_combat_rpcs.sql.
--
-- Décisions de modèle (figées) :
--   * Le combat est porté par le GROUPE (`groups` / `group_members` /
--     `is_group_member()`), pas par une histoire du web. Le MJ est
--     `groups.owner_id`. Un groupe ne peut lancer un combat que si son
--     propriétaire est aussi MJ DANS L'APP, c'est-à-dire que sa ligne
--     `group_members` porte `is_game_master = true`
--     (20261016090000_group_members_orphan_character.sql) -- voir le helper
--     `group_has_gm`. Un groupe dont le propriétaire joue avec un personnage
--     (aucun MJ déclaré) n'a donc pas de mode combat.
--   * Monstres/PNJ = nom + initiative, JAMAIS de PV : aucune colonne de ce type
--     n'existe sur ces tables (vérifié par supabase/tests/group_combats_rls_test.sql).
--   * Un seul combat actif par groupe (index unique partiel).
--   * Écriture : AUCUNE écriture directe depuis le client (ni joueur, ni MJ) --
--     privilège de table limité à SELECT pour `authenticated`, aucune policy
--     INSERT/UPDATE/DELETE. Toute écriture passe par les RPC security definer
--     de la migration suivante, qui revérifient auth.uid(), le rôle et l'état
--     du combat. Écart assumé avec la convention "GRANT large + RLS réelle" de
--     20260825091100_grant_authenticated_privileges.sql : la RLS ne sait pas
--     limiter les COLONNES, donc un GRANT UPDATE large laisserait un joueur
--     réécrire l'initiative d'un autre ou le tour courant ; seuls des RPC
--     peuvent exprimer "ta propre ligne, ce champ, ce combat actif".
--   * Lecture : membres du groupe, plus le propriétaire du groupe même s'il n'a
--     plus de ligne `group_members` ("MJ parti = état lisible, seul le MJ peut
--     terminer").
--
-- Rétention : aucun cron. Les combats terminés sont conservés (historique léger,
-- quelques lignes par combat) et supprimés par CASCADE avec le groupe
-- (`groups` -> `combats` -> `combat_participants`). Une purge périodique pourra
-- être ajoutée plus tard si le volume le justifie.
--
-- Retour arrière (dans cet ordre) :
--   alter publication supabase_realtime drop table public.combat_participants;
--   alter publication supabase_realtime drop table public.combats;
--   drop trigger if exists group_members_leave_combat_delete on public.group_members;
--   drop trigger if exists group_members_leave_combat_update on public.group_members;
--   drop function if exists public.on_group_member_left_combat();
--   drop trigger if exists combat_participants_before_delete on public.combat_participants;
--   drop function if exists public.on_combat_participant_deleted();
--   (puis le retour arrière de 20261114091000, puis :)
--   drop table if exists public.combat_participants cascade;
--   drop table if exists public.combats cascade;
--   ATTENTION : ce retour arrière supprime définitivement tous les combats et
--   participants (actifs et terminés) avec les tables.
--   drop function if exists public.is_group_owner(uuid);
--   drop function if exists public.group_has_gm(uuid);

-- Tables ---------------------------------------------------------------------

create table if not exists public.combats (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'ended')),
  -- Compteur de round, >= 1. Modifié uniquement par RPC (V2 : advance_turn).
  round integer not null default 1 check (round >= 1),
  -- Tour en cours, porté par l'état serveur (jamais calculé côté client).
  -- NULL tant qu'aucun tour n'a démarré (V1 : toujours NULL). FK ajoutée plus
  -- bas (dépendance circulaire avec combat_participants).
  current_participant_id uuid,
  started_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  ended_at timestamptz,
  constraint combats_ended_at_matches_status check (
    (status = 'active' and ended_at is null)
    or (status = 'ended' and ended_at is not null)
  ),
  -- Cible de la FK composite de combat_participants (group_id dénormalisé
  -- toujours cohérent avec celui du combat).
  constraint combats_id_group_id_key unique (id, group_id)
);

-- Un seul combat actif par groupe.
create unique index if not exists combats_one_active_per_group
  on public.combats (group_id)
  where status = 'active';

create index if not exists combats_group_id_created_at_idx
  on public.combats (group_id, created_at desc);

create table if not exists public.combat_participants (
  id uuid primary key default gen_random_uuid(),
  combat_id uuid not null,
  -- Dénormalisé depuis le combat pour permettre le filtre Realtime
  -- (postgres_changes ne filtre que sur les colonnes de la ligne) et une RLS
  -- sans jointure ; la FK composite garantit qu'il égale combats.group_id.
  group_id uuid not null references public.groups (id) on delete cascade,
  -- Personnage lié (PJ) ; NULL pour un PNJ, ou si le personnage a été supprimé.
  character_id uuid references public.characters (id) on delete set null,
  -- Joueur propriétaire de la ligne (PJ) ; NULL pour un PNJ du MJ.
  user_id uuid references auth.users (id) on delete cascade,
  -- Nom copié à l'insertion (un renommage ultérieur du personnage ne change pas
  -- la ligne du combat en cours).
  name text not null check (char_length(name) between 1 and 80),
  kind text not null check (kind in ('pc', 'npc')),
  -- NULL = "initiative à saisir".
  initiative integer check (initiative between -20 and 60),
  -- Rang de départage, dense par combat. Ordre d'affichage = initiative
  -- décroissante (NULL en dernier), puis sort_order croissant. Le serveur
  -- applique la règle par défaut (PJ avant PNJ, puis ordre d'arrivée) en
  -- attribuant sort_order à l'insertion ; le MJ peut le modifier (RPC
  -- reorder_participant) pour trancher une égalité.
  sort_order integer not null check (sort_order >= 1),
  -- 'removed' = retrait logique (le DELETE n'est pas filtrable en Realtime) ;
  -- 'waiting' = mise en attente (V2, aucun RPC V1 ne l'écrit).
  status text not null default 'active' check (status in ('active', 'removed', 'waiting')),
  created_at timestamptz not null default now(),
  constraint combat_participants_combat_fk
    foreign key (combat_id, group_id)
    references public.combats (id, group_id) on delete cascade,
  constraint combat_participants_kind_shape check (
    (kind = 'pc' and user_id is not null)
    or (kind = 'npc' and user_id is null and character_id is null)
  ),
  constraint combat_participants_combat_character_key unique (combat_id, character_id),
  -- Cible de la FK composite de combats.current_participant_id.
  constraint combat_participants_id_combat_id_key unique (id, combat_id)
);

-- Un joueur n'a qu'une ligne PJ non retirée par combat (filet contre un
-- changement de personnage en cours de combat).
create unique index if not exists combat_participants_one_live_pc_per_user
  on public.combat_participants (combat_id, user_id)
  where kind = 'pc' and status <> 'removed';

create index if not exists combat_participants_combat_id_sort_order_idx
  on public.combat_participants (combat_id, sort_order);

create index if not exists combat_participants_group_id_idx
  on public.combat_participants (group_id);

-- FK du tour courant : doit désigner un participant DU MÊME combat (FK
-- composite, NO ACTION). Pas de `on delete set null (colonne)` (PostgreSQL >=
-- 15 uniquement) : un trigger BEFORE DELETE sur combat_participants (plus bas)
-- remet current_participant_id à NULL avant la suppression du participant, ce
-- qui rend les suppressions en cascade (groupe, utilisateur, combat) sûres sur
-- PostgreSQL 14 comme sur les versions récentes.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'combats_current_participant_fk'
      and conrelid = 'public.combats'::regclass
  ) then
    alter table public.combats
      add constraint combats_current_participant_fk
      foreign key (current_participant_id, id)
      references public.combat_participants (id, combat_id);
  end if;
end $$;

create or replace function public.on_combat_participant_deleted()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.combats
     set current_participant_id = null
   where current_participant_id = old.id;
  return old;
end;
$$;

revoke all on function public.on_combat_participant_deleted() from public, anon, authenticated;

drop trigger if exists combat_participants_before_delete on public.combat_participants;
create trigger combat_participants_before_delete
  before delete on public.combat_participants
  for each row execute function public.on_combat_participant_deleted();

-- Helpers security definer ------------------------------------------------------
-- Security definer pour éviter toute récursion RLS (même patron que
-- is_group_member, 20260906182601_create_groups.sql).

-- Vrai si l'utilisateur connecté est le propriétaire (MJ) du groupe.
create or replace function public.is_group_owner(p_group_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.groups g
    where g.id = p_group_id
      and g.owner_id = auth.uid()
  );
$$;

-- Vrai si le groupe a un MJ "au sens de l'app" : son propriétaire a une ligne
-- group_members avec is_game_master = true. Usage interne (start_combat) : non
-- exposé aux clients.
create or replace function public.group_has_gm(p_group_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.groups g
    join public.group_members m
      on m.group_id = g.id and m.user_id = g.owner_id
    where g.id = p_group_id
      and m.is_game_master
  );
$$;

revoke all on function public.is_group_owner(uuid) from public, anon;
revoke all on function public.group_has_gm(uuid) from public, anon, authenticated;
grant execute on function public.is_group_owner(uuid) to authenticated;
grant execute on function public.group_has_gm(uuid) to service_role;

-- RLS / privilèges ---------------------------------------------------------------

alter table public.combats enable row level security;
alter table public.combat_participants enable row level security;

-- Privilèges explicites (on ne dépend pas des privilèges par défaut de
-- Supabase) : lecture seule pour les clients, aucune écriture directe.
revoke all on table public.combats from public, anon, authenticated;
revoke all on table public.combat_participants from public, anon, authenticated;
grant select on table public.combats to authenticated;
grant select on table public.combat_participants to authenticated;
grant select, insert, update, delete on table public.combats to service_role;
grant select, insert, update, delete on table public.combat_participants to service_role;

drop policy if exists "Member or owner can select combats" on public.combats;
create policy "Member or owner can select combats"
  on public.combats for select
  to authenticated
  using (public.is_group_member(group_id) or public.is_group_owner(group_id));

drop policy if exists "Member or owner can select combat_participants" on public.combat_participants;
create policy "Member or owner can select combat_participants"
  on public.combat_participants for select
  to authenticated
  using (public.is_group_member(group_id) or public.is_group_owner(group_id));

-- Pas de policy INSERT/UPDATE/DELETE pour authenticated (deny-all) : voir
-- l'en-tête, tout passe par les RPC de 20261114091000.

-- Départ d'un membre ---------------------------------------------------------------
-- Quand un membre quitte/est exclu du groupe (DELETE de sa ligne group_members)
-- ou change de personnage / perd son personnage (UPDATE de character_id, y
-- compris le `set null` déclenché par la suppression d'un personnage), ses
-- lignes PJ encore vivantes dans les combats ACTIFS du groupe passent en
-- status = 'removed' : pas de fantôme dans la liste. Retrait logique plutôt que
-- DELETE (non filtrable en Realtime, re-fetch sinon).
-- Notes de comportement :
--   * Le tour courant (current_participant_id) n'est PAS modifié : si le
--     partant était le tour en cours, la V2 (advance_turn) doit sauter les
--     participants 'removed' ; le client ignore un tour pointant sur un
--     participant retiré.
--   * Le MJ (propriétaire) qui perd sa ligne group_members ne déclenche aucune
--     fin de combat : l'état reste lisible (policies "member or owner") et seul
--     le MJ peut terminer (end_combat). Un PJ retiré n'est PAS réintégré
--     automatiquement s'il revient dans le groupe pendant ce même combat.
create or replace function public.on_group_member_left_combat()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Course départ / création de ligne PJ : set_my_initiative tient un verrou
  -- FOR UPDATE sur le combat. Prendre le même verrou ici sérialise les deux :
  -- soit la ligne PJ créée est vue (UPDATE en READ COMMITTED) puis retirée, soit
  -- set_my_initiative revoit l'appartenance après commit et refuse. Deadlock
  -- possible seulement contre une suppression concurrente de l'utilisateur, du
  -- personnage ou du groupe ; PostgreSQL le détecte (40P01) et la transaction
  -- est rejouable.
  perform 1 from public.combats c
   where c.group_id = old.group_id and c.status = 'active'
   for update;

  if tg_op = 'DELETE' then
    update public.combat_participants p
       set status = 'removed'
      from public.combats c
     where c.id = p.combat_id
       and c.status = 'active'
       and p.group_id = old.group_id
       and p.user_id = old.user_id
       and p.kind = 'pc'
       and p.status <> 'removed';
    return old;
  end if;

  -- UPDATE de character_id (autres colonnes ignorées par la clause WHEN du
  -- trigger) : on retire toute ligne PJ vivante du joueur qui ne correspond
  -- pas à son NOUVEAU personnage (ou toutes si plus de personnage).
  update public.combat_participants p
     set status = 'removed'
    from public.combats c
   where c.id = p.combat_id
     and c.status = 'active'
     and p.group_id = new.group_id
     and p.user_id = new.user_id
     and p.kind = 'pc'
     and p.status <> 'removed'
     and (new.character_id is null or p.character_id is distinct from new.character_id);
  return new;
end;
$$;

revoke all on function public.on_group_member_left_combat() from public, anon, authenticated;

drop trigger if exists group_members_leave_combat_delete on public.group_members;
create trigger group_members_leave_combat_delete
  after delete on public.group_members
  for each row execute function public.on_group_member_left_combat();

drop trigger if exists group_members_leave_combat_update on public.group_members;
create trigger group_members_leave_combat_update
  after update of character_id on public.group_members
  for each row
  when (old.character_id is distinct from new.character_id)
  execute function public.on_group_member_left_combat();

-- Realtime -----------------------------------------------------------------------------
-- Patron de 20261107090000/20261108090000, rendu idempotent. REPLICA IDENTITY
-- laissée au défaut (clé primaire) : le client filtre sur `group_id` pour les
-- INSERT/UPDATE (le retrait est logique, donc un UPDATE, pas un DELETE non
-- filtrable). Realtime réévalue la policy SELECT ci-dessus pour chaque abonné :
-- aucun accès élargi par rapport à un select direct. Aucune colonne PV n'existe
-- donc aucun payload ne peut en contenir.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'combats'
  ) then
    alter publication supabase_realtime add table public.combats;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'combat_participants'
  ) then
    alter publication supabase_realtime add table public.combat_participants;
  end if;
end $$;

comment on table public.combats is
  'Combat d''un groupe (app mobile). Un seul combat actif par groupe. MJ = groups.owner_id. Écriture uniquement par RPC (start_combat, end_combat, ...) ; lecture : membres + propriétaire.';
comment on table public.combat_participants is
  'Participants d''un combat : PJ (kind pc) et PNJ du MJ (kind npc, nom + initiative, JAMAIS de PV). Ordre = initiative décroissante (NULL en dernier) puis sort_order croissant. Retrait logique via status = removed.';
