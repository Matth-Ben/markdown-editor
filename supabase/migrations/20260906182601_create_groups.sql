-- Système de groupe (app mobile "Personnages") — item 3/4 d'une liste de
-- chantiers, cadrage complet dans
-- docs/cahier-des-charges/12-partage-et-groupes.md section 2 (dépôt
-- nexus-jdr-app-mobile). Propre à l'app mobile, indépendant de l'app web
-- "Histoires" pour cette itération (`campaign_id` est un point d'extension
-- future non exploité ici, voir section 4 du même document) : un groupe se
-- crée et se rejoint depuis l'app, sans MJ ni histoire requis.

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references auth.users (id) on delete cascade,
  invite_code text not null unique,
  -- Point d'extension future (section 4 du document) : associer un groupe
  -- à une histoire de l'app web. Non exploité par cette itération, colonne
  -- posée pour ne pas casser le modèle plus tard.
  campaign_id uuid references public.stories (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups (id) on delete cascade,
  character_id uuid not null references public.characters (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'membre' check (role in ('owner', 'membre')),
  joined_at timestamptz not null default now(),
  primary key (group_id, character_id),
  -- Un joueur ne participe à un même groupe qu'avec UN SEUL personnage à la
  -- fois (spec : "un joueur avec plusieurs personnages choisit lequel") —
  -- sans cette contrainte, rien n'empêcherait un même compte de rejoindre
  -- deux fois le même groupe avec deux personnages différents.
  unique (group_id, user_id)
);

-- Une seule ligne par groupe (monnaie/objets communs non encore attribués).
create table public.group_treasure (
  group_id uuid primary key references public.groups (id) on delete cascade,
  currency_gp int not null default 0,
  currency_pp int not null default 0,
  currency_ep int not null default 0,
  currency_sp int not null default 0,
  currency_cp int not null default 0,
  -- Objets en attente d'attribution : jsonb plutôt qu'une table de liaison
  -- dédiée (spec section 2.1, "jsonb ou table de liaison dédiée") — un
  -- tableau d'objets `{item_id?: int, custom_name?: text, quantity: int}`,
  -- même souplesse item-référence/texte-libre que `character_inventory`
  -- (`character_inventory_item_or_custom`), mais sans les champs propres à
  -- un personnage (`equipped`, `notes`) qui n'ont pas de sens pour un butin
  -- commun pas encore attribué.
  items jsonb not null default '[]'::jsonb
);

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_treasure enable row level security;

-- Vrai si l'utilisateur connecté est membre (owner ou membre) de p_group_id
-- via une ligne group_members -- même patron que owns_character/
-- story_owner_can_read_character (security definer, sinon la policy sur
-- group_members qui l'utilise entrerait en boucle avec elle-même via RLS).
create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id
      and m.user_id = auth.uid()
  );
$$;

-- groups --------------------------------------------------------------

create policy "Owner can select their groups"
  on public.groups for select
  to authenticated
  using (auth.uid() = owner_id);

create policy "Member can select their groups"
  on public.groups for select
  to authenticated
  using (public.is_group_member(id));

-- Pas de policy INSERT pour authenticated (deny-all) : créer un groupe
-- passe par l'edge function create-group (à construire séparément), qui
-- insère à la fois la ligne `groups` ET la ligne `group_members` du
-- créateur (role='owner', avec le personnage qu'il choisit pour y
-- participer) via le client service_role, en une seule opération server-
-- side -- même principe que join-group ci-dessous. Un simple INSERT direct
-- laisserait le créateur sans ligne group_members, donc `is_group_member`
-- resterait faux même pour SON PROPRE groupe.

create policy "Owner can update their groups"
  on public.groups for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Owner can dissolve their groups"
  on public.groups for delete
  to authenticated
  using (auth.uid() = owner_id);

-- group_members ---------------------------------------------------------

-- Pas de policy SELECT séparée "owner" : is_group_member couvre déjà le
-- owner, qui a lui-même une ligne group_members (role='owner') dès la
-- création du groupe (voir le trigger plus bas).
create policy "Member can select members of their groups"
  on public.group_members for select
  to authenticated
  using (public.is_group_member(group_id));

-- Rejoindre un groupe passe par une edge function dédiée (join-group, à
-- construire séparément), pas par un INSERT direct : même principe que
-- join-story (20260830100100_create_character_campaigns.sql) — valider le
-- code d'invitation et l'appartenance du personnage côté serveur avant
-- d'écrire, plutôt que d'exposer invite_code via une policy SELECT
-- publique sur `groups`. Volontairement AUCUNE policy INSERT ici pour le
-- rôle authenticated (deny-all) ; l'edge function utilise le client
-- service_role, qui contourne RLS.

create policy "Member can leave a group"
  on public.group_members for delete
  to authenticated
  using (auth.uid() = user_id);

create policy "Owner can remove a member from their group"
  on public.group_members for delete
  to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_members.group_id
        and g.owner_id = auth.uid()
    )
  );

-- group_treasure ---------------------------------------------------------

create policy "Member can select their group_treasure"
  on public.group_treasure for select
  to authenticated
  using (public.is_group_member(group_id));

create policy "Member can update their group_treasure"
  on public.group_treasure for update
  to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

-- Pas de policy INSERT/DELETE pour authenticated : la ligne est créée par
-- le trigger ci-dessous à la création du groupe, et supprimée en cascade
-- avec lui (dissolution) -- jamais un besoin client direct pour ces deux
-- opérations.

-- Crée automatiquement la ligne group_treasure (tous les compteurs à 0) dès
-- qu'un groupe est créé -- la ligne group_members du créateur, elle, est
-- insérée explicitement par l'edge function create-group (pas par ce
-- trigger : elle a besoin du character_id choisi par le créateur, une
-- donnée que le trigger n'a pas).
create or replace function public.on_group_created()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.group_treasure (group_id) values (new.id);
  return new;
end;
$$;

create trigger groups_after_insert
  after insert on public.groups
  for each row execute function public.on_group_created();

grant select, insert, update, delete on table
  public.groups,
  public.group_members,
  public.group_treasure
to authenticated;
