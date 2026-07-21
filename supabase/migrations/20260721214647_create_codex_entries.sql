create table public.codex_entries (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null check (category in ('pnj', 'bestiaire', 'joueur', 'lieu', 'autre')),
  name text not null,
  summary text not null default '',
  content text not null default '',
  attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (story_id, name)
);

alter table public.codex_entries enable row level security;

create policy "Users can view their own codex entries"
  on public.codex_entries for select
  using (auth.uid() = user_id);

create policy "Users can insert their own codex entries"
  on public.codex_entries for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own codex entries"
  on public.codex_entries for update
  using (auth.uid() = user_id);

create policy "Users can delete their own codex entries"
  on public.codex_entries for delete
  using (auth.uid() = user_id);
