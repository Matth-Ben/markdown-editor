-- Images importées dans le contenu (histoire ou fiches Codex) via la barre d'outils Markdown :
-- même politique que les couvertures d'histoire (bucket public en lecture, écriture restreinte
-- au dossier de l'utilisateur propriétaire), avec un niveau de dossier en plus pour ranger par
-- histoire : {user_id}/{story_id}/{fichier}. `storage.foldername(name))[1]` reste le premier
-- segment (l'utilisateur) quel que soit le nombre de segments suivants, donc la policy n'a pas
-- besoin de connaître le story_id pour rester correcte.
insert into storage.buckets (id, name, public)
values ('story-content-images', 'story-content-images', true)
on conflict (id) do nothing;

create policy "Story content images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'story-content-images');

create policy "Users can upload their own story content images"
  on storage.objects for insert
  with check (
    bucket_id = 'story-content-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own story content images"
  on storage.objects for update
  using (
    bucket_id = 'story-content-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own story content images"
  on storage.objects for delete
  using (
    bucket_id = 'story-content-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
