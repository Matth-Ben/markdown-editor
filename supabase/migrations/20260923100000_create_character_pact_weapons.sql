-- Chantier "Personnages" (app mobile) — Arme du Pacte de la lame (Occultiste).
--
-- Mémorise, pour un personnage ayant choisi le Pacte de la lame, la FORME courante de son
-- arme de pacte (une arme de corps à corps du catalogue `items`). RAW 5e : l'Occultiste choisit
-- la forme à chaque invocation ; cette table ne retient que le dernier choix, affiché sur la
-- fiche. Une seule arme de pacte à la fois par personnage (clé primaire = character_id).
--
-- Même patron RLS/GRANT que character_pact_slots (20260906103610).

create table public.character_pact_weapons (
  character_id uuid primary key references public.characters (id) on delete cascade,
  item_id int not null references public.items (id) on delete restrict
);

alter table public.character_pact_weapons enable row level security;

create policy "Owner can select their character_pact_weapons"
  on public.character_pact_weapons for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_pact_weapons"
  on public.character_pact_weapons for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_pact_weapons"
  on public.character_pact_weapons for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_pact_weapons"
  on public.character_pact_weapons for delete
  to authenticated
  using (public.owns_character(character_id));

create policy "Story owner can select linked character_pact_weapons"
  on public.character_pact_weapons for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

grant select, insert, update, delete on table public.character_pact_weapons to authenticated;
