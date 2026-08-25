-- Chantier "Personnages" (app mobile) — Phase 1 — Socle de données.
-- Sorts, invocations occultes, objets/équipement, packs d'équipement.
-- Voir 02-modele-donnees.md section 2 du cahier des charges de l'app mobile.
--
-- Choix technique (02-modele-donnees.md laisse le choix ouvert) : les sorts
-- pouvant être appris par une classe sont modélisés par une table de
-- liaison `spell_classes` plutôt qu'un champ jsonb, pour permettre le
-- filtrage direct ("sorts disponibles pour ma classe") sans scanner du
-- jsonb — cas d'usage fréquent identifié dès la conception (voir note de
-- conception "jsonb vs tables normalisées" du document).
--
-- Le texte destiné à l'affichage joueur (name, description) ne figure pas
-- dans ces tables : il vit dans public.translations (migration
-- 20260825090050). `school`/`casting_time`/`range`/`duration` restent des
-- colonnes texte ici : ce sont des valeurs mécaniques/catégorielles des
-- règles (pas du texte narratif d'affichage), même si une éventuelle
-- localisation EN de ces valeurs reste une question ouverte à trancher au
-- moment de la Phase 5 (voir rapport de fin de tâche).

create table public.spells (
  id int generated always as identity primary key,
  level int not null check (level between 0 and 9),
  school text,
  casting_time text,
  range text,
  components jsonb not null default '{}'::jsonb,
  duration text,
  concentration boolean not null default false,
  ritual boolean not null default false,
  source text
);

alter table public.spells enable row level security;

create policy "Authenticated users can read spells"
  on public.spells for select
  to authenticated
  using (true);

create policy "Admins can insert spells"
  on public.spells for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update spells"
  on public.spells for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete spells"
  on public.spells for delete
  to authenticated
  using (public.is_admin());

create table public.spell_classes (
  spell_id int not null references public.spells (id) on delete cascade,
  class_id int not null references public.classes (id) on delete cascade,
  primary key (spell_id, class_id)
);

alter table public.spell_classes enable row level security;

create policy "Authenticated users can read spell_classes"
  on public.spell_classes for select
  to authenticated
  using (true);

create policy "Admins can insert spell_classes"
  on public.spell_classes for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update spell_classes"
  on public.spell_classes for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete spell_classes"
  on public.spell_classes for delete
  to authenticated
  using (public.is_admin());

create table public.invocations (
  id int generated always as identity primary key,
  prerequisites jsonb not null default '{}'::jsonb
);

alter table public.invocations enable row level security;

create policy "Authenticated users can read invocations"
  on public.invocations for select
  to authenticated
  using (true);

create policy "Admins can insert invocations"
  on public.invocations for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update invocations"
  on public.invocations for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete invocations"
  on public.invocations for delete
  to authenticated
  using (public.is_admin());

create table public.items (
  id int generated always as identity primary key,
  category text not null check (
    category in (
      'arme', 'armure', 'bouclier', 'outil', 'equipement_general',
      'objet_magique', 'monture_vehicule'
    )
  ),
  weight numeric,
  cost jsonb,
  source text,
  rarity text,
  requires_attunement boolean not null default false,
  consumable boolean not null default false
);

alter table public.items enable row level security;

create policy "Authenticated users can read items"
  on public.items for select
  to authenticated
  using (true);

create policy "Admins can insert items"
  on public.items for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update items"
  on public.items for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete items"
  on public.items for delete
  to authenticated
  using (public.is_admin());

create table public.weapon_properties (
  item_id int primary key references public.items (id) on delete cascade,
  damage_dice text,
  damage_type text,
  properties jsonb not null default '[]'::jsonb,
  range jsonb
);

alter table public.weapon_properties enable row level security;

create policy "Authenticated users can read weapon_properties"
  on public.weapon_properties for select
  to authenticated
  using (true);

create policy "Admins can insert weapon_properties"
  on public.weapon_properties for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update weapon_properties"
  on public.weapon_properties for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete weapon_properties"
  on public.weapon_properties for delete
  to authenticated
  using (public.is_admin());

create table public.armor_properties (
  item_id int primary key references public.items (id) on delete cascade,
  ac_base int not null,
  ac_dex_bonus text not null check (ac_dex_bonus in ('aucun', 'max_2', 'illimite')),
  strength_requirement int,
  stealth_disadvantage boolean not null default false
);

alter table public.armor_properties enable row level security;

create policy "Authenticated users can read armor_properties"
  on public.armor_properties for select
  to authenticated
  using (true);

create policy "Admins can insert armor_properties"
  on public.armor_properties for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update armor_properties"
  on public.armor_properties for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete armor_properties"
  on public.armor_properties for delete
  to authenticated
  using (public.is_admin());

create table public.equipment_packs (
  id int generated always as identity primary key,
  contents jsonb not null default '[]'::jsonb
);

alter table public.equipment_packs enable row level security;

create policy "Authenticated users can read equipment_packs"
  on public.equipment_packs for select
  to authenticated
  using (true);

create policy "Admins can insert equipment_packs"
  on public.equipment_packs for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update equipment_packs"
  on public.equipment_packs for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete equipment_packs"
  on public.equipment_packs for delete
  to authenticated
  using (public.is_admin());
