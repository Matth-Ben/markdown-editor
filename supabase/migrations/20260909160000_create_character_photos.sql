-- Galerie de photos complémentaires (dépôt nexus-jdr-app-mobile,
-- docs/cahier-des-charges/11-fonctionnalites-a-ajouter.md, section "Onglet
-- Histoire" : "Galerie de photos complémentaires (au-delà du portrait
-- principal)."). Table enfant simple (même forme que character_inventory),
-- RLS via owns_character (helper créé par
-- 20260825090400_create_character_tables.sql, réutilisé tel quel).
create table public.character_photos (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  url text not null,
  created_at timestamptz not null default now()
);

alter table public.character_photos enable row level security;

create policy "Owner can select their character_photos"
  on public.character_photos for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_photos"
  on public.character_photos for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_photos"
  on public.character_photos for delete
  to authenticated
  using (public.owns_character(character_id));

-- Pas de policy update : une photo n'est jamais modifiée une fois ajoutée,
-- seulement ajoutée/retirée (spec de la tâche) -- même principe que
-- character_campaigns (delete only), pas d'action "update" jamais exposée
-- côté app.

-- Stockage (Supabase Storage) : même logique que character-portraits
-- (20260825090400_create_character_tables.sql) -- bucket public en lecture,
-- écriture restreinte au dossier de l'utilisateur propriétaire
-- ({user_id}/...). Bucket dédié plutôt que réutilisation de
-- character-portraits (même rationale que story-content-images vs
-- story-covers côté web) : porte plusieurs fichiers par personnage, jamais
-- un remplacement d'un fichier unique.
insert into storage.buckets (id, name, public)
values ('character-gallery-photos', 'character-gallery-photos', true)
on conflict (id) do nothing;

create policy "Character gallery photos are publicly readable"
  on storage.objects for select
  using (bucket_id = 'character-gallery-photos');

create policy "Users can upload their own character gallery photos"
  on storage.objects for insert
  with check (
    bucket_id = 'character-gallery-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own character gallery photos"
  on storage.objects for delete
  using (
    bucket_id = 'character-gallery-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
