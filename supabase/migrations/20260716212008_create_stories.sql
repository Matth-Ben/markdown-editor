create table public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  cover_image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.stories enable row level security;

create policy "Users can view their own stories"
  on public.stories for select
  using (auth.uid() = user_id);

create policy "Users can insert their own stories"
  on public.stories for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own stories"
  on public.stories for update
  using (auth.uid() = user_id);

create policy "Users can delete their own stories"
  on public.stories for delete
  using (auth.uid() = user_id);

-- Couvertures d'histoires (Supabase Storage) : bucket public en lecture,
-- écriture restreinte au dossier de l'utilisateur propriétaire.
insert into storage.buckets (id, name, public)
values ('story-covers', 'story-covers', true)
on conflict (id) do nothing;

create policy "Story covers are publicly readable"
  on storage.objects for select
  using (bucket_id = 'story-covers');

create policy "Users can upload their own story covers"
  on storage.objects for insert
  with check (
    bucket_id = 'story-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own story covers"
  on storage.objects for update
  using (
    bucket_id = 'story-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own story covers"
  on storage.objects for delete
  using (
    bucket_id = 'story-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
