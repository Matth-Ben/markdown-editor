-- Journal de campagne / notes de séance (dépôt nexus-jdr-app-mobile,
-- docs/cahier-des-charges/11-fonctionnalites-a-ajouter.md, section "Onglet
-- Histoire" : "Journal de campagne / notes de séance (distinct du backstory
-- figé)."). Distinct des 9 colonnes characters.*_text (backstory_text
-- notamment, voir 20260825090400_create_character_tables.sql) : un journal
-- est une liste d'entrées horodatées, pas un champ de texte unique -- table
-- enfant séparée, même principe que character_inventory/character_photos.
create table public.character_journal_entries (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.character_journal_entries enable row level security;

create policy "Owner can select their character_journal_entries"
  on public.character_journal_entries for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_journal_entries"
  on public.character_journal_entries for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_journal_entries"
  on public.character_journal_entries for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_journal_entries"
  on public.character_journal_entries for delete
  to authenticated
  using (public.owns_character(character_id));
