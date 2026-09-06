-- Chantier "limites du multiclassage", item 3/3 — magie de pacte de
-- l'Occultiste (app mobile "Personnages"), jamais écrite en base jusqu'ici.
--
-- Table dédiée plutôt qu'une réutilisation de `character_spell_slots` : la
-- magie de pacte est RAW 5e délibérément exclue du calcul combiné
-- multiclasse des emplacements de sorts (voir
-- `SpellSlotProgression.combinedCasterLevel`, dépôt mobile) — un Occultiste
-- multiclassé avec un lanceur "non-pacte" pourrait avoir un emplacement
-- combiné et un emplacement de pacte au MÊME niveau (`slot_level`)
-- simultanément, ce qui collisionnerait avec la clé primaire composite
-- `(character_id, slot_level)` de `character_spell_slots`. Un personnage n'a
-- jamais qu'une seule classe Occultiste (RAW : impossible de cumuler deux
-- fois la même classe) et la magie de pacte n'a jamais qu'un seul niveau de
-- charge actif à la fois (contrairement aux emplacements normaux, répartis
-- sur plusieurs niveaux) — d'où une clé primaire simple sur `character_id`.
--
-- Même patron RLS/GRANT que `character_spell_slots`
-- (20260825090400_create_character_tables.sql,
-- 20260825091100_grant_authenticated_privileges.sql,
-- 20260830100100_create_character_campaigns.sql).

create table public.character_pact_slots (
  character_id uuid primary key references public.characters (id) on delete cascade,
  slot_level int not null check (slot_level between 1 and 5),
  slots_total int not null default 0,
  slots_used int not null default 0
);

alter table public.character_pact_slots enable row level security;

create policy "Owner can select their character_pact_slots"
  on public.character_pact_slots for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_pact_slots"
  on public.character_pact_slots for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_pact_slots"
  on public.character_pact_slots for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_pact_slots"
  on public.character_pact_slots for delete
  to authenticated
  using (public.owns_character(character_id));

create policy "Story owner can select linked character_pact_slots"
  on public.character_pact_slots for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

grant select, insert, update, delete on table
  public.character_pact_slots
to authenticated;
