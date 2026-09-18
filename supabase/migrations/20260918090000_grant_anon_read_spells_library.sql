-- Chantier "Bibliothèque" (dépôt nexus-jdr-library) — Phase 1 — sorts en
-- lecture seule, accessible sans compte.
--
-- Contexte : `01-architecture-technique.md`/`03-fonctionnalites.md` du dépôt
-- nexus-jdr-library posent que la bibliothèque de contenu D&D doit être
-- consultable sans connexion, contrairement au chantier "Personnages" (app
-- mobile) où toute lecture, même du référentiel, exige une session
-- authentifiée (voir 20260825090300_create_reference_spells_items_tables.sql
-- et 20260825091100_grant_authenticated_privileges.sql : ni GRANT ni policy
-- RLS n'existent pour `anon` sur `spells`/`translations`).
--
-- Portée volontairement limitée aux sorts (seul type de contenu actuellement
-- consommé par la Bibliothèque) plutôt qu'un accès anonyme large sur tout le
-- référentiel — le même pattern (GRANT + policy anon dédiée) sera répliqué
-- table par table à mesure que d'autres types de contenu (races, classes,
-- dons, objets...) rejoignent la Bibliothèque.
--
-- Deux couches à ouvrir, confirmées en testant en conditions réelles
-- (requête anonyme : HTTP 200, 0 ligne, sans erreur) :
-- 1. Le GRANT de table lui-même — sans lui, PostgREST refuse la requête
--    avant même que RLS n'intervienne (même constat déjà documenté dans
--    20260825091100_grant_authenticated_privileges.sql pour `authenticated`).
-- 2. Une policy RLS explicite pour le rôle `anon` (les policies existantes
--    ne ciblent que `to authenticated`).

grant usage on schema public to anon;

grant select on table public.spells, public.translations to anon;

create policy "Anonymous users can read spells"
  on public.spells for select
  to anon
  using (true);

-- Scoped à entity_type = 'spell' (least privilege) : les autres entity_type
-- de `translations` (race, class, item, class_feature, invocation...) ne
-- sont pas encore exposés par la Bibliothèque et n'ont pas besoin d'être
-- lisibles par un visiteur anonyme aujourd'hui.
create policy "Anonymous users can read spell translations"
  on public.translations for select
  to anon
  using (entity_type = 'spell');
