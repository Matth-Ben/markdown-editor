-- Onglet "Notes" de l'écran "Groupe" (dépôt nexus-jdr-app-mobile) : carnet de
-- notes personnel pendant la partie, un par membre de groupe (décision
-- utilisateur du 16/09/2026 : personnel, pas partagé entre coéquipiers,
-- contrairement à group_treasure). Distinct de character_journal_entries
-- (20260909170000) : celui-ci vit dans l'onglet "Histoire" d'un personnage,
-- indépendant de tout groupe, et est une LISTE d'entrées horodatées ; ici un
-- unique texte libre par (groupe, personnage), réécrit en place.
create table public.group_notes (
  group_id uuid not null references public.groups (id) on delete cascade,
  character_id uuid not null references public.characters (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  body text not null default '',
  updated_at timestamptz not null default now(),
  primary key (group_id, character_id)
);

alter table public.group_notes enable row level security;

create policy "Member can select their own group_notes"
  on public.group_notes for select
  to authenticated
  using (auth.uid() = user_id);

-- `public.is_group_member` : fonction security definer déjà créée par
-- 20260906182601_create_groups.sql.
create policy "Member can insert their own group_notes"
  on public.group_notes for insert
  to authenticated
  with check (auth.uid() = user_id and public.is_group_member(group_id));

create policy "Member can update their own group_notes"
  on public.group_notes for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Member can delete their own group_notes"
  on public.group_notes for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on table public.group_notes to authenticated;
