-- Chantier "Personnages" (app mobile) — recettage direction-artistique du
-- 13/09/2026, section "Lancement, états vides et erreurs transversales"
-- (`docs/cahier-des-charges/09-maquettes-captures.md`, écrans "Erreur —
-- Mise à jour obligatoire" et "Bannière — Mise à jour suggérée" du dépôt
-- mobile). Ces deux écrans supposaient une source de vérité distante pour
-- la version minimale supportée et la dernière version disponible de
-- l'app mobile — absente jusqu'ici. Cette migration l'ajoute.
--
-- Portée : app mobile uniquement (aucune table/consommateur côté app web
-- "Histoires" n'est concerné) — pas de coordination avec l'équipe web
-- nécessaire pour cette migration, contrairement aux chantiers touchant à
-- `stories`/`codex_entries`/`character_campaigns`.
--
-- Choix de modélisation : une ligne par plateforme plutôt qu'une seule
-- valeur pour les deux (demandé "si simple" par le cahier des charges) —
-- le coût est nul (une PK composite au lieu d'une PK simple) et ça évite
-- une migration de schéma le jour où Android et iOS publient à des
-- rythmes différents (cas déjà avéré ici : Android en test, iOS/Google
-- Play pas encore disponibles, voir 13-depot-versioning-publication.md).
--
-- Les deux colonnes de version sont des chaînes "major.minor.patch" (pas
-- de build number — non pertinent pour une comparaison de version côté
-- utilisateur), volontairement contraintes par un check plutôt que
-- stockées en 3 colonnes entières séparées, pour rester simple côté
-- client (un seul champ à parser/comparer).
--
-- Neutralité au lancement : les valeurs seedées ci-dessous correspondent
-- toutes deux à la version publiée dans pubspec.yaml au moment de cette
-- migration (1.0.0) — l'app n'étant pas encore publiée sur les stores,
-- minimum_supported_version = latest_version pour ne jamais déclencher de
-- blocage ni de bannière tant que ces valeurs n'auront pas été mises à
-- jour à la main après une vraie publication.
create table public.app_versions (
  platform text primary key check (platform in ('android', 'ios')),
  minimum_supported_version text not null check (minimum_supported_version ~ '^\d+\.\d+\.\d+$'),
  latest_version text not null check (latest_version ~ '^\d+\.\d+\.\d+$'),
  updated_at timestamptz not null default now()
);

alter table public.app_versions enable row level security;

-- Lecture publique authentifiée, même principe que les tables de
-- référence D&D (races/classes/sorts...) — voir
-- 20260825090100_create_reference_core_tables.sql. Aucun accès anonyme :
-- l'app "Personnages" exige déjà une session authentifiée avant tout
-- appel réseau applicatif (voir 01-architecture-technique.md).
create policy "Authenticated users can read app_versions"
  on public.app_versions for select
  to authenticated
  using (true);

-- Écriture réservée au rôle contenu/admin (public.is_admin(), voir
-- 20260825090000_create_admin_role.sql) — jamais côté client standard.
-- Pas d'edge function/UI d'admin dédiée pour l'instant : mise à jour au
-- fil de l'eau via la console Supabase (service_role) ou en tant
-- qu'admin, au même titre que le contenu de référence.
create policy "Admins can insert app_versions"
  on public.app_versions for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update app_versions"
  on public.app_versions for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete app_versions"
  on public.app_versions for delete
  to authenticated
  using (public.is_admin());

comment on table public.app_versions is
  'Source de vérité distante pour les écrans "Mise à jour obligatoire"/"Mise à jour suggérée" de l''app mobile Personnages. Une ligne par plateforme (android/ios). Lecture authentifiée, écriture admin uniquement.';

insert into public.app_versions (platform, minimum_supported_version, latest_version)
values
  ('android', '1.0.0', '1.0.0'),
  ('ios', '1.0.0', '1.0.0');
