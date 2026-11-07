-- Fractionne le carnet de notes de l'onglet "Notes" (écran "Groupe", dépôt
-- nexus-jdr-app-mobile) : `group_notes` (20260916090000) est aujourd'hui UNE
-- seule ligne par (group_id, user_id) dont `body` grossit indéfiniment --
-- Matthias veut plusieurs entrées distinctes par étape/chapitre, comme
-- `character_journal_entries` (20260909170000) l'a déjà fait pour l'onglet
-- "Histoire" d'un personnage. Même précédent, adapté : table enfant
-- `group_journal_entries`, une ligne par entrée horodatée, plutôt qu'un
-- unique champ réécrit en place.
--
-- Colonnes : `group_id`/`user_id` identiques à `group_notes` (même FK vers
-- `public.groups`/`auth.users`, même sémantique "personnel, pas partagé" --
-- voir le commentaire de 20260916090000_create_group_notes.sql et la
-- décision utilisateur du 16/09/2026). `title` est nouveau ici : `body`
-- seul ne permettait pas d'identifier une entrée en liste -- nullable,
-- l'étape/chapitre reste optionnelle. Pas de `character_id` : contrairement
-- à l'ancien `group_notes`, cette colonne n'a jamais servi qu'à
-- l'affichage (voir 20261106090000, qui l'a déjà rendue purement
-- informative et hors RLS) ; elle n'est pas reprise dans ce nouveau modèle,
-- qui n'en a pas besoin.
--
-- Pas de colonne `updated_at` : vérifié sur `character_journal_entries`
-- (20260909170000), qui n'en a pas non plus, et qui pourtant permet déjà
-- d'éditer une entrée existante (policy UPDATE dédiée, consommée par
-- `CharacterRepository.updateJournalEntry`, dépôt mobile
-- `lib/features/characters/data/character_repository.dart`) : l'édition
-- d'une entrée est portée par la policy RLS `update`, pas par un champ de
-- suivi de date de modification. Ajouter `updated_at` ici aurait été une
-- divergence non justifiée par rapport à ce précédent direct -- la policy
-- `update` ci-dessous suffit à permettre l'édition demandée.
create table public.group_journal_entries (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.group_journal_entries enable row level security;

-- Même sémantique que `group_notes` : personnel, jamais partagé entre
-- coéquipiers (décision utilisateur du 16/09/2026) -- aucune policy
-- n'autorise un autre membre du groupe à lire les entrées de quelqu'un
-- d'autre, contrairement à `group_treasure`.
create policy "Member can select their own group_journal_entries"
  on public.group_journal_entries for select
  to authenticated
  using (auth.uid() = user_id);

-- `public.is_group_member` : fonction security definer déjà créée par
-- 20260906182601_create_groups.sql (même garde que l'INSERT de
-- `group_notes`).
create policy "Member can insert their own group_journal_entries"
  on public.group_journal_entries for insert
  to authenticated
  with check (auth.uid() = user_id and public.is_group_member(group_id));

create policy "Member can update their own group_journal_entries"
  on public.group_journal_entries for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Member can delete their own group_journal_entries"
  on public.group_journal_entries for delete
  to authenticated
  using (auth.uid() = user_id);

-- GRANT explicite comme sur `group_notes` (20260916090000) et toutes les
-- tables créées depuis 20260825091100_grant_authenticated_privileges.sql :
-- la restriction réelle vient des policies RLS ci-dessus, pas de ce
-- privilège de table.
grant select, insert, update, delete on table public.group_journal_entries to authenticated;

comment on table public.group_journal_entries is
  'Entrées horodatées de l''onglet "Notes" (écran "Groupe", dépôt nexus-jdr-app-mobile) : remplace le modèle "une ligne = tout le texte" de group_notes (20260916090000) par plusieurs entrées par (group_id, user_id), même principe que character_journal_entries (20260909170000). Personnel, jamais partagé entre coéquipiers.';

-- Migration de données : chaque ligne `group_notes` non vide devient une
-- première entrée ici. `title` laissé NULL (aucune information de
-- titre/chapitre n'existait dans l'ancien modèle à reprendre). `created_at`
-- = `group_notes.updated_at` de la ligne d'origine : `group_notes` n'a
-- jamais eu de colonne `created_at` séparée (une seule date, réécrite à
-- chaque sauvegarde), `updated_at` est donc la meilleure date disponible
-- pour cette première entrée -- jamais NULL ici (colonne `not null default
-- now()` depuis la création de `group_notes`), donc pas besoin de repli sur
-- `now()` en pratique, mais `coalesce` conservé par défense.
insert into public.group_journal_entries (group_id, user_id, title, body, created_at)
select
  gn.group_id,
  gn.user_id,
  null,
  gn.body,
  coalesce(gn.updated_at, now())
from public.group_notes gn
where gn.body <> '';

-- `group_notes` n'est PAS supprimée par cette migration (choix assumé, voir
-- le rapport de cette tâche) : contrairement au reste de ce projet où une
-- divergence de schéma est éliminée dans la même migration que son
-- remplacement (pas de shim de compatibilité), le code mobile qui écrit
-- dans `group_notes` (dépôt nexus-jdr-app-mobile,
-- `GroupRepository`/`group_notes_tab_body.dart`) est déjà en production
-- sur des appareils dont la mise à jour est contrainte par le délai de
-- revue des stores (voir docs/cahier-des-charges/13-depot-versioning-
-- publication.md, dépôt mobile) -- un DROP immédiat casserait l'onglet
-- "Notes" pour tous les utilisateurs déjà installés jusqu'à ce que la
-- nouvelle version de l'app soit disponible et adoptée. `group_notes` reste
-- donc en lecture/écriture pour ces anciennes versions ; une migration de
-- suppression séparée devra suivre une fois le code mobile basculé sur
-- `group_journal_entries` et le déploiement confirmé (aucune vue/fonction
-- SQL ne dépend de `group_notes` à ce jour -- vérifié par recherche sur
-- tout `supabase/`, seules des mentions en commentaire dans
-- 20261106100000 et 20261107090000, pas de dépendance réelle).
