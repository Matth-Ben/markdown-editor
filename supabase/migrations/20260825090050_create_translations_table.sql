-- Chantier "Personnages" (app mobile) — Phase 1 — Socle de données.
-- Table de traduction générique pour tout le texte destiné à l'affichage
-- joueur des tables de référence D&D (races, classes, sorts, objets...).
--
-- Décision actée par le chef de projet (remplace la note laissée ouverte
-- dans une version précédente de la migration 20260825090100 — voir
-- 07-source-donnees-i18n.md) : plutôt que des colonnes `name`/`description`
-- dupliquées par langue directement sur chaque table de référence, tout
-- texte affiché passe par cette table de traduction générique unique.
--
-- Compromis assumé : `entity_id` ne porte pas de contrainte de clé
-- étrangère stricte vers la table correspondante — impossible à exprimer
-- nativement en SQL puisque `entity_type` varie d'une ligne à l'autre (une
-- FK ne peut pointer que vers une seule table cible). L'intégrité
-- référentielle repose donc sur la discipline applicative (scripts de
-- peuplement, futures edge functions d'administration de contenu), et non
-- sur une contrainte au niveau base. En contrepartie, le schéma reste
-- stable quel que soit le nombre de tables de référence ou de langues
-- ajoutées par la suite : ajouter l'anglais (Phase 5+) ne nécessite aucune
-- migration de schéma, seulement des lignes `locale = 'en'`.
--
-- Écart volontaire par rapport à la DDL fournie : `entity_id` est typé
-- `text` et non `int`. Raison : `public.abilities.id` est une clé primaire
-- `text` (ex. 'str', 'dex'...) déjà utilisée telle quelle par de nombreuses
-- tables `character_*` (migration 20260825090400, hors périmètre de cette
-- tâche — on ne renomme pas cette clé). Un `entity_id int` empêcherait donc
-- de stocker les traductions de la table `abilities`. Les identifiants
-- numériques (`int generated always as identity`) des autres tables de
-- référence sont stockés ici sous leur forme texte (`id::text`), ce qui ne
-- change rien à l'usage : les jointures applicatives comparent toujours des
-- chaînes de caractères en pratique (paramètres d'URL, clés de cache...).
create table public.translations (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id text not null,
  field_name text not null,
  locale text not null check (locale in ('fr', 'en')),
  value text not null,
  unique (entity_type, entity_id, field_name, locale)
);

comment on table public.translations is
  'Traductions du texte affiché joueur des tables de référence D&D (name, description...). entity_type identifie la table logique (''race'', ''class'', ''spell''...), entity_id la ligne (stockée en texte, voir commentaire de migration). Pas de FK stricte sur entity_id : compromis assumé du pattern générique.';

alter table public.translations enable row level security;

-- Même politique que les autres tables de référence : lecture publique
-- authentifiée, écriture réservée au rôle contenu/admin (public.is_admin(),
-- voir migration 20260825090000).
create policy "Authenticated users can read translations"
  on public.translations for select
  to authenticated
  using (true);

create policy "Admins can insert translations"
  on public.translations for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update translations"
  on public.translations for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete translations"
  on public.translations for delete
  to authenticated
  using (public.is_admin());

-- Index de lookup : "toutes les traductions d'une entité donnée dans une
-- langue donnée" (le pattern de requête dominant côté app mobile — voir
-- rapport de fin de tâche pour un exemple concret).
create index translations_entity_idx
  on public.translations (entity_type, entity_id, locale);
