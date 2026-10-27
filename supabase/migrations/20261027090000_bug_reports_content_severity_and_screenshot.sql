-- Chantier "Personnages" (app mobile) — fonctionnalité « Remonter un bug » :
--   1. nouvelle sévérité 'contenu' (contenu D&D incorrect ou manquant), qui
--      S'AJOUTE à mineur/majeur/bloquant (décision produit : pas de
--      remplacement, aucune conversion des lignes existantes) ;
--   2. capture d'écran facultative (une seule image max) jointe au
--      signalement, stockée dans un bucket Storage PRIVÉ.
--
-- Table concernée : public.bug_reports (20260903100000_create_bug_reports.sql),
-- écrite par l'edge function `report-bug`. Ne touche ni à `codex_entries`, ni
-- à `stories`, ni aux buckets existants (story-covers, story-content-images,
-- character-portraits, character-gallery-photos) : nouveau bucket dédié.
--
-- Aucune fonction (ni SECURITY DEFINER ni autre) n'est créée ici : pas de
-- question de privilèges EXECUTE par défaut à révoquer.
--
-- Retour arrière (manuel, dans cet ordre) :
--   1. drop policy "Users can upload their own bug report screenshots"
--        on storage.objects;
--   2. Vider le bucket via l'API Storage (dashboard, ou
--      storage.from('bug-report-screenshots').remove(...) avec service_role)
--      -- Storage refuse la suppression directe en SQL dans storage.objects --
--      puis : delete from storage.buckets where id = 'bug-report-screenshots';
--      (échoue tant qu'il reste des objets, FK storage.objects.bucket_id).
--   3. alter table public.bug_reports
--        drop constraint bug_reports_screenshot_path_owner_check,
--        drop column screenshot_path;
--      (les chemins enregistrés sont perdus).
--   4. alter table public.bug_reports drop constraint bug_reports_severity_check;
--      alter table public.bug_reports add constraint bug_reports_severity_check
--        check (severity in ('mineur', 'majeur', 'bloquant'));
--      ATTENTION : cette étape échoue s'il existe des lignes
--      severity = 'contenu' -- il faut d'abord décider de leur sort
--      (suppression ou reclassement manuel), ce que ce retour arrière ne
--      tranche pas.
--   5. Redéployer la version précédente de report-bug (qui n'accepte ni
--      'contenu' ni screenshotPath) et de delete-account.

-- ---------------------------------------------------------------------------
-- 1. Sévérité 'contenu'
-- ---------------------------------------------------------------------------
-- La contrainte d'origine est une contrainte de colonne inline, nommée
-- automatiquement par Postgres `bug_reports_severity_check`. Élargissement
-- strict (les trois valeurs existantes restent valides) : aucune ligne
-- existante ne peut violer la nouvelle contrainte.
alter table public.bug_reports
  drop constraint bug_reports_severity_check;

alter table public.bug_reports
  add constraint bug_reports_severity_check
  check (severity in ('mineur', 'majeur', 'bloquant', 'contenu'));

-- ---------------------------------------------------------------------------
-- 2. Chemin de la capture d'écran
-- ---------------------------------------------------------------------------
-- Chemin de l'objet dans le bucket `bug-report-screenshots` (clé
-- storage.objects.name, SANS le nom du bucket), ex.
-- '<reporter_id>/<fichier>.png'. Nullable : la capture est facultative.
-- On stocke un chemin, jamais une URL (le bucket est privé ; une URL signée
-- serait périssable et ne doit de toute façon jamais sortir vers l'issue
-- GitHub, dépôt public).
alter table public.bug_reports
  add column screenshot_path text;

-- Garde-fou au niveau base, en plus de la validation de l'edge function :
-- la policy RLS INSERT de bug_reports autorise un utilisateur authentifié à
-- insérer DIRECTEMENT via PostgREST (sans passer par report-bug). Sans cette
-- contrainte, un client pourrait y référencer le fichier d'un autre
-- utilisateur. Format imposé : exactement un niveau de dossier égal au
-- reporter_id, puis un nom de fichier simple (pas de '/', pas de '..'
-- possible puisque le premier segment est l'uuid exact et le second ne
-- contient ni '/' ni ne commence par '.').
alter table public.bug_reports
  add constraint bug_reports_screenshot_path_owner_check
  check (
    screenshot_path is null
    or (
      split_part(screenshot_path, '/', 1) = reporter_id::text
      and screenshot_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9_-][A-Za-z0-9._-]{0,127}$'
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Bucket privé `bug-report-screenshots`
-- ---------------------------------------------------------------------------
-- public = false : aucune URL publique (/object/public/...) ne fonctionne ;
-- seules la clé service_role (edge function, dashboard Supabase) ou une
-- policy SELECT explicite (volontairement absente, voir plus bas) peuvent
-- lire. Limite 5 Mo (largement suffisant pour une capture d'écran de
-- téléphone/tablette en JPEG/PNG/WebP) et types MIME restreints aux images,
-- appliqués par l'API Storage elle-même au téléversement.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bug-report-screenshots',
  'bug-report-screenshots',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- INSERT : un utilisateur authentifié ne peut téléverser que sous son propre
-- dossier '<auth.uid()>/<fichier>' (même convention {user_id}/... que
-- character-portraits/character-gallery-photos), et exactement un niveau de
-- dossier (pas de sous-dossiers), cohérent avec la contrainte
-- bug_reports_screenshot_path_owner_check ci-dessus.
create policy "Users can upload their own bug report screenshots"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'bug-report-screenshots'
    and (storage.foldername(name))[1] = auth.uid()::text
    and array_length(storage.foldername(name), 1) = 1
  );

-- SELECT / UPDATE / DELETE : volontairement AUCUNE policy (deny-all côté
-- client, RLS de storage.objects déjà activée par Supabase).
--   - Lecture : l'app n'a aucun besoin de relire une capture après l'envoi
--     (pas d'écran "historique de mes signalements", cf. le commentaire
--     SELECT de 20260903100000_create_bug_reports.sql). L'existence de
--     l'objet est vérifiée par report-bug avec la clé service_role ; Matthias
--     consulte les captures depuis le dashboard Supabase. Conséquence côté
--     app : téléverser SANS upsert (l'upsert exige SELECT + UPDATE), avec un
--     nom de fichier unique (uuid).
--   - Mise à jour : une capture n'est jamais remplacée une fois envoyée.
--   - Suppression : pas de fonction "supprimer mon signalement". Un fichier
--     orphelin (téléversé mais dont l'appel report-bug a échoué) reste en
--     place ; acceptable (privé, borné à 5 Mo) et nettoyable via le
--     dashboard.
