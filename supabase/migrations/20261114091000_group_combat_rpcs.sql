-- Combat du groupe : RPC d'écriture (PR0, V1). Voir 20261114090000_create_group_combats.sql
-- pour le modèle, la RLS et les décisions. Toutes les fonctions sont security
-- definer, fixent leur search_path, vérifient auth.uid(), le rôle et l'état du
-- combat, et sont appelables par `authenticated` uniquement (jamais `anon`).
--
-- Conventions d'erreur : `message` = code stable lisible par l'app,
-- `errcode` = classe SQLSTATE (PostgREST renvoie les deux) :
--   not_authenticated        28000  pas de session
--   group_not_found          P0002  groupe inconnu OU appelant ni membre ni MJ
--   combat_not_found         P0002  combat inconnu OU appelant ni membre ni MJ
--   participant_not_found    P0002  participant inexistant (un appelant non membre reçoit combat_not_found)
--   not_group_owner          42501  membre mais pas MJ (action réservée au MJ)
--   no_game_master           P0001  le groupe n'a pas de MJ dans l'app
--   combat_already_active    P0001  un combat actif existe déjà pour ce groupe
--   combat_not_active        P0001  le combat est terminé
--   participant_removed      P0001  participant retiré (non modifiable)
--   no_character             P0001  l'appelant n'a pas de personnage dans le groupe
--   invalid_initiative       22023  initiative hors -20..60 (ou NULL pour set_my_initiative)
--   invalid_name             22023  nom vide ou trop long
--   invalid_count            22023  count < 1
--   npc_limit_per_call       P0001  count > 20
--   npc_limit_per_combat     P0001  plus de 60 PNJ dans le combat (retirés inclus)
--   invalid_sort_order       22023  position hors 1..nombre de participants
--
-- Choix "participant PJ" : une ligne 'pc' est créée (a) au lancement pour chaque
-- membre ayant un personnage (hors MJ), initiative NULL ; (b) paresseusement à
-- la première set_my_initiative d'un membre qui n'en a pas (arrivé après le
-- lancement ou personnage changé). Un PJ retiré (par le MJ ou par son départ)
-- n'est pas réintégrable par le joueur (participant_removed).
--
-- Ordre : sort_order dense par combat ; un nouveau PJ est inséré juste avant le
-- premier PNJ (donc "PJ avant PNJ" à égalité), un nouveau PNJ à la fin
-- ("ordre d'arrivée"). Le client trie par (initiative desc NULLS LAST,
-- sort_order asc) et n'a aucune autre règle à implémenter.
--
-- V2 (non fait ici) : advance_turn modifiera combats.current_participant_id et
-- combats.round (aucune contrainte ni droit ne l'empêche : les RPC V2 seront
-- security definer comme celles-ci).
--
-- Retour arrière :
--   drop function if exists public.start_combat(uuid);
--   drop function if exists public.end_combat(uuid);
--   drop function if exists public.set_my_initiative(uuid, integer);
--   drop function if exists public.set_participant_initiative(uuid, integer);
--   drop function if exists public.add_npc_participants(uuid, text, integer, integer);
--   drop function if exists public.remove_participant(uuid);
--   drop function if exists public.reorder_participant(uuid, integer);
--   drop function if exists public.combat_lock_for_gm(uuid, boolean);

-- Helper interne : verrouille le combat (FOR UPDATE, sérialise les RPC
-- concurrentes sur un même combat : numérotation, limites, sort_order) et
-- vérifie que l'appelant est le MJ (propriétaire du groupe). Non exposé.
create or replace function public.combat_lock_for_gm(p_combat_id uuid, p_require_active boolean default true)
returns public.combats
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_combat public.combats;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_combat from public.combats where id = p_combat_id for update;
  if not found then
    raise exception 'combat_not_found' using errcode = 'P0002';
  end if;

  if not (public.is_group_member(v_combat.group_id) or public.is_group_owner(v_combat.group_id)) then
    raise exception 'combat_not_found' using errcode = 'P0002';
  end if;
  if not public.is_group_owner(v_combat.group_id) then
    raise exception 'not_group_owner' using errcode = '42501';
  end if;
  if p_require_active and v_combat.status <> 'active' then
    raise exception 'combat_not_active' using errcode = 'P0001';
  end if;
  return v_combat;
end;
$$;

-- start_combat(p_group_id) -> combats
-- MJ uniquement ; le groupe doit avoir un MJ dans l'app ; refus si un combat
-- est déjà actif. Crée le combat (round 1, aucun tour) et une ligne PJ par
-- membre ayant un personnage (initiative NULL).
create or replace function public.start_combat(p_group_id uuid)
returns public.combats
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_combat public.combats;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  -- Verrou léger sur le groupe : sérialise deux lancements simultanés (l'index
  -- unique partiel reste le filet final).
  select owner_id into v_owner from public.groups where id = p_group_id for no key update;
  if not found then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;
  if not (v_owner = v_uid or public.is_group_member(p_group_id)) then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;
  if v_owner <> v_uid then
    raise exception 'not_group_owner' using errcode = '42501';
  end if;
  if not public.group_has_gm(p_group_id) then
    raise exception 'no_game_master' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.combats where group_id = p_group_id and status = 'active') then
    raise exception 'combat_already_active' using errcode = 'P0001';
  end if;

  begin
    insert into public.combats (group_id, started_by)
    values (p_group_id, v_uid)
    returning * into v_combat;
  exception when unique_violation then
    raise exception 'combat_already_active' using errcode = 'P0001';
  end;

  insert into public.combat_participants
    (combat_id, group_id, character_id, user_id, name, kind, sort_order)
  select
    v_combat.id,
    p_group_id,
    m.character_id,
    m.user_id,
    left(coalesce(nullif(btrim(c.name), ''), 'Personnage'), 80),
    'pc',
    (row_number() over (order by m.joined_at, m.id))::integer
  from public.group_members m
  join public.characters c on c.id = m.character_id
  where m.group_id = p_group_id
    and m.character_id is not null
    and not m.is_game_master;

  return v_combat;
end;
$$;

-- end_combat(p_combat_id) -> combats
-- MJ uniquement. Idempotent : un combat déjà terminé est renvoyé tel quel.
-- Fonctionne même si le MJ n'a plus de ligne group_members (seul le MJ peut
-- terminer).
create or replace function public.end_combat(p_combat_id uuid)
returns public.combats
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_combat public.combats;
begin
  v_combat := public.combat_lock_for_gm(p_combat_id, false);
  if v_combat.status = 'ended' then
    return v_combat;
  end if;
  update public.combats
     set status = 'ended', ended_at = now()
   where id = p_combat_id
   returning * into v_combat;
  return v_combat;
end;
$$;

-- set_my_initiative(p_combat_id, p_initiative) -> combat_participants
-- Membre du groupe ayant un personnage, combat actif, SA propre ligne
-- uniquement (la ligne est créée si elle n'existe pas encore). Valeur -20..60,
-- non NULL. Le MJ sans personnage reçoit no_character (il utilise
-- set_participant_initiative pour les PNJ).
create or replace function public.set_my_initiative(p_combat_id uuid, p_initiative integer)
returns public.combat_participants
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_combat public.combats;
  v_char uuid;
  v_row public.combat_participants;
  v_pos integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into v_combat from public.combats where id = p_combat_id for update;
  if not found then
    raise exception 'combat_not_found' using errcode = 'P0002';
  end if;

  select m.character_id into v_char
    from public.group_members m
   where m.group_id = v_combat.group_id and m.user_id = v_uid;
  if not found then
    -- Non-membre (y compris un MJ qui a quitté) : on ne révèle pas le combat.
    raise exception 'combat_not_found' using errcode = 'P0002';
  end if;

  if v_combat.status <> 'active' then
    raise exception 'combat_not_active' using errcode = 'P0001';
  end if;
  if p_initiative is null or p_initiative < -20 or p_initiative > 60 then
    raise exception 'invalid_initiative' using errcode = '22023';
  end if;
  if v_char is null then
    raise exception 'no_character' using errcode = 'P0001';
  end if;

  select * into v_row
    from public.combat_participants
   where combat_id = p_combat_id and character_id = v_char;

  if found then
    if v_row.status = 'removed' or v_row.user_id is distinct from v_uid then
      raise exception 'participant_removed' using errcode = 'P0001';
    end if;
    update public.combat_participants
       set initiative = p_initiative
     where id = v_row.id
     returning * into v_row;
    return v_row;
  end if;

  -- Première saisie : création de la ligne PJ juste avant le premier PNJ.
  select coalesce(
           min(sort_order) filter (where kind = 'npc'),
           coalesce(max(sort_order), 0) + 1)
    into v_pos
    from public.combat_participants
   where combat_id = p_combat_id;

  update public.combat_participants
     set sort_order = sort_order + 1
   where combat_id = p_combat_id and sort_order >= v_pos;

  insert into public.combat_participants
    (combat_id, group_id, character_id, user_id, name, kind, initiative, sort_order)
  select p_combat_id, v_combat.group_id, v_char, v_uid,
         left(coalesce(nullif(btrim(c.name), ''), 'Personnage'), 80),
         'pc', p_initiative, v_pos
    from public.characters c
   where c.id = v_char
  returning * into v_row;

  return v_row;
end;
$$;

-- set_participant_initiative(p_participant_id, p_initiative) -> combat_participants
-- MJ uniquement, n'importe quel participant non retiré, combat actif.
-- p_initiative NULL = remettre à "initiative à saisir".
create or replace function public.set_participant_initiative(p_participant_id uuid, p_initiative integer)
returns public.combat_participants
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_combat_id uuid;
  v_row public.combat_participants;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select combat_id into v_combat_id from public.combat_participants where id = p_participant_id;
  if not found then
    raise exception 'participant_not_found' using errcode = 'P0002';
  end if;
  perform public.combat_lock_for_gm(v_combat_id, true);

  if p_initiative is not null and (p_initiative < -20 or p_initiative > 60) then
    raise exception 'invalid_initiative' using errcode = '22023';
  end if;

  select * into v_row from public.combat_participants where id = p_participant_id for update;
  if not found then
    raise exception 'participant_not_found' using errcode = 'P0002';
  end if;
  if v_row.status = 'removed' then
    raise exception 'participant_removed' using errcode = 'P0001';
  end if;

  update public.combat_participants
     set initiative = p_initiative
   where id = p_participant_id
   returning * into v_row;
  return v_row;
end;
$$;

-- add_npc_participants(p_combat_id, p_base_name, p_initiative, p_count) -> setof combat_participants
-- MJ uniquement, combat actif. Ajoute p_count PNJ (nom + initiative, jamais de
-- PV). p_count = 1 : nom tel quel. p_count > 1 : "Gobelin 1", "Gobelin 2"...
-- en CONTINUANT la numérotation des PNJ déjà présents du même nom de base
-- (un "Gobelin" seul compte comme n°1). Limites : 20 par appel, 60 PNJ par
-- combat (retirés inclus). p_initiative NULL autorisé (à saisir plus tard).
create or replace function public.add_npc_participants(
  p_combat_id uuid,
  p_base_name text,
  p_initiative integer default null,
  p_count integer default 1
)
returns setof public.combat_participants
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_combat public.combats;
  v_base text := btrim(coalesce(p_base_name, ''));
  v_offset integer := 0;
  v_total integer;
  v_start integer;
begin
  v_combat := public.combat_lock_for_gm(p_combat_id, true);

  if char_length(v_base) < 1 or char_length(v_base) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_count is null or p_count < 1 then
    raise exception 'invalid_count' using errcode = '22023';
  end if;
  if p_count > 20 then
    raise exception 'npc_limit_per_call' using errcode = 'P0001';
  end if;
  if p_count > 1 and char_length(v_base) > 74 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_initiative is not null and (p_initiative < -20 or p_initiative > 60) then
    raise exception 'invalid_initiative' using errcode = '22023';
  end if;

  select count(*) into v_total
    from public.combat_participants
   where combat_id = p_combat_id and kind = 'npc';
  if v_total + p_count > 60 then
    raise exception 'npc_limit_per_combat' using errcode = 'P0001';
  end if;

  if p_count > 1 then
    select greatest(
             coalesce(max(substr(name, char_length(v_base) + 2)::integer)
                      filter (where left(name, char_length(v_base) + 1) = v_base || ' '
                                and substr(name, char_length(v_base) + 2) ~ '^[0-9]{1,4}$'), 0),
             case when bool_or(name = v_base) then 1 else 0 end)
      into v_offset
      from public.combat_participants
     where combat_id = p_combat_id and kind = 'npc';
    v_offset := coalesce(v_offset, 0);
  end if;

  select coalesce(max(sort_order), 0) into v_start
    from public.combat_participants where combat_id = p_combat_id;

  return query
  with ins as (
    insert into public.combat_participants
      (combat_id, group_id, name, kind, initiative, sort_order)
    select p_combat_id,
           v_combat.group_id,
           case when p_count = 1 then v_base else v_base || ' ' || (v_offset + g)::text end,
           'npc',
           p_initiative,
           v_start + g
      from generate_series(1, p_count) as g
    returning *
  )
  select * from ins order by sort_order;
end;
$$;

-- remove_participant(p_participant_id) -> combat_participants
-- MJ uniquement, combat actif. Retrait logique (status = 'removed'),
-- idempotent. Ne touche pas au tour courant (la V2 saute les retirés).
create or replace function public.remove_participant(p_participant_id uuid)
returns public.combat_participants
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_combat_id uuid;
  v_row public.combat_participants;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select combat_id into v_combat_id from public.combat_participants where id = p_participant_id;
  if not found then
    raise exception 'participant_not_found' using errcode = 'P0002';
  end if;
  perform public.combat_lock_for_gm(v_combat_id, true);

  update public.combat_participants
     set status = 'removed'
   where id = p_participant_id
   returning * into v_row;
  if not found then
    raise exception 'participant_not_found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

-- reorder_participant(p_participant_id, p_new_sort_order) -> setof combat_participants
-- MJ uniquement, combat actif. Déplace le participant à la position
-- p_new_sort_order (1..nombre de lignes du combat, retirés inclus) et décale
-- les autres : sert à trancher une égalité d'initiative (l'ordre d'affichage
-- est initiative puis sort_order, donc le déplacement n'a d'effet visible qu'à
-- égalité). Renvoie toutes les lignes du combat triées par sort_order.
create or replace function public.reorder_participant(p_participant_id uuid, p_new_sort_order integer)
returns setof public.combat_participants
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_combat_id uuid;
  v_old integer;
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select combat_id into v_combat_id from public.combat_participants where id = p_participant_id;
  if not found then
    raise exception 'participant_not_found' using errcode = 'P0002';
  end if;
  perform public.combat_lock_for_gm(v_combat_id, true);

  select sort_order into v_old from public.combat_participants where id = p_participant_id;
  select count(*) into v_count from public.combat_participants where combat_id = v_combat_id;
  if p_new_sort_order is null or p_new_sort_order < 1 or p_new_sort_order > v_count then
    raise exception 'invalid_sort_order' using errcode = '22023';
  end if;

  if p_new_sort_order <> v_old then
    update public.combat_participants
       set sort_order = case
             when id = p_participant_id then p_new_sort_order
             when p_new_sort_order < v_old and sort_order >= p_new_sort_order and sort_order < v_old then sort_order + 1
             when p_new_sort_order > v_old and sort_order > v_old and sort_order <= p_new_sort_order then sort_order - 1
             else sort_order
           end
     where combat_id = v_combat_id;
  end if;

  return query
    select * from public.combat_participants
     where combat_id = v_combat_id
     order by sort_order;
end;
$$;

-- Privilèges d'exécution : authenticated uniquement (jamais public/anon).
revoke all on function public.combat_lock_for_gm(uuid, boolean) from public, anon, authenticated;
revoke all on function public.start_combat(uuid) from public, anon;
revoke all on function public.end_combat(uuid) from public, anon;
revoke all on function public.set_my_initiative(uuid, integer) from public, anon;
revoke all on function public.set_participant_initiative(uuid, integer) from public, anon;
revoke all on function public.add_npc_participants(uuid, text, integer, integer) from public, anon;
revoke all on function public.remove_participant(uuid) from public, anon;
revoke all on function public.reorder_participant(uuid, integer) from public, anon;

grant execute on function public.start_combat(uuid) to authenticated;
grant execute on function public.end_combat(uuid) to authenticated;
grant execute on function public.set_my_initiative(uuid, integer) to authenticated;
grant execute on function public.set_participant_initiative(uuid, integer) to authenticated;
grant execute on function public.add_npc_participants(uuid, text, integer, integer) to authenticated;
grant execute on function public.remove_participant(uuid) to authenticated;
grant execute on function public.reorder_participant(uuid, integer) to authenticated;
