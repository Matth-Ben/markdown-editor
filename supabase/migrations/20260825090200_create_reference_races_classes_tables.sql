-- Chantier "Personnages" (app mobile) — Phase 1 — Socle de données.
-- Races, sous-races, classes, sous-classes, aptitudes de classe,
-- historiques, dons. Voir 02-modele-donnees.md section 2 du cahier des
-- charges de l'app mobile. Même politique RLS que la migration précédente :
-- lecture publique authentifiée, écriture réservée au rôle admin/contenu.
--
-- Le texte destiné à l'affichage joueur (name, description, feature_name,
-- feature_description...) ne figure pas dans ces tables : il vit dans
-- public.translations (migration 20260825090050). Les autres colonnes
-- texte conservées ici (source, size...) sont des valeurs
-- mécaniques/catégorielles utilisées par les tables de règles, pas du texte
-- narratif d'affichage.

create table public.races (
  id int generated always as identity primary key,
  source text,
  size text,
  speed int,
  ability_bonuses jsonb not null default '{}'::jsonb,
  traits jsonb not null default '[]'::jsonb,
  languages jsonb not null default '[]'::jsonb
);

alter table public.races enable row level security;

create policy "Authenticated users can read races"
  on public.races for select
  to authenticated
  using (true);

create policy "Admins can insert races"
  on public.races for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update races"
  on public.races for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete races"
  on public.races for delete
  to authenticated
  using (public.is_admin());

create table public.subraces (
  id int generated always as identity primary key,
  race_id int not null references public.races (id) on delete cascade,
  ability_bonuses jsonb not null default '{}'::jsonb,
  traits jsonb not null default '[]'::jsonb
);

alter table public.subraces enable row level security;

create policy "Authenticated users can read subraces"
  on public.subraces for select
  to authenticated
  using (true);

create policy "Admins can insert subraces"
  on public.subraces for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update subraces"
  on public.subraces for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete subraces"
  on public.subraces for delete
  to authenticated
  using (public.is_admin());

create table public.classes (
  id int generated always as identity primary key,
  source text,
  hit_die int not null,
  primary_abilities jsonb not null default '[]'::jsonb,
  saving_throw_proficiencies jsonb not null default '[]'::jsonb,
  armor_proficiencies jsonb not null default '[]'::jsonb,
  weapon_proficiencies jsonb not null default '[]'::jsonb,
  tool_proficiencies jsonb not null default '[]'::jsonb,
  skill_choices jsonb not null default '{}'::jsonb
);

alter table public.classes enable row level security;

create policy "Authenticated users can read classes"
  on public.classes for select
  to authenticated
  using (true);

create policy "Admins can insert classes"
  on public.classes for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update classes"
  on public.classes for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete classes"
  on public.classes for delete
  to authenticated
  using (public.is_admin());

create table public.subclasses (
  id int generated always as identity primary key,
  class_id int not null references public.classes (id) on delete cascade,
  available_from_level int not null
);

alter table public.subclasses enable row level security;

create policy "Authenticated users can read subclasses"
  on public.subclasses for select
  to authenticated
  using (true);

create policy "Admins can insert subclasses"
  on public.subclasses for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update subclasses"
  on public.subclasses for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete subclasses"
  on public.subclasses for delete
  to authenticated
  using (public.is_admin());

create table public.class_features (
  id int generated always as identity primary key,
  class_id int references public.classes (id) on delete cascade,
  subclass_id int references public.subclasses (id) on delete cascade,
  level int not null,
  choice_type text,
  uses_per_rest jsonb,
  constraint class_features_class_or_subclass check (
    class_id is not null or subclass_id is not null
  )
);

alter table public.class_features enable row level security;

create policy "Authenticated users can read class_features"
  on public.class_features for select
  to authenticated
  using (true);

create policy "Admins can insert class_features"
  on public.class_features for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update class_features"
  on public.class_features for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete class_features"
  on public.class_features for delete
  to authenticated
  using (public.is_admin());

create table public.backgrounds (
  id int generated always as identity primary key,
  skill_proficiencies jsonb not null default '[]'::jsonb,
  tool_or_language_choices jsonb not null default '{}'::jsonb,
  equipment jsonb not null default '[]'::jsonb
);

alter table public.backgrounds enable row level security;

create policy "Authenticated users can read backgrounds"
  on public.backgrounds for select
  to authenticated
  using (true);

create policy "Admins can insert backgrounds"
  on public.backgrounds for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update backgrounds"
  on public.backgrounds for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete backgrounds"
  on public.backgrounds for delete
  to authenticated
  using (public.is_admin());

create table public.feats (
  id int generated always as identity primary key,
  prerequisites jsonb not null default '{}'::jsonb
);

alter table public.feats enable row level security;

create policy "Authenticated users can read feats"
  on public.feats for select
  to authenticated
  using (true);

create policy "Admins can insert feats"
  on public.feats for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update feats"
  on public.feats for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete feats"
  on public.feats for delete
  to authenticated
  using (public.is_admin());
