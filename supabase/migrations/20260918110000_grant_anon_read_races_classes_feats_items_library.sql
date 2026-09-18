-- Chantier "Bibliothèque" (dépôt nexus-jdr-library) — Phase 1, suite.
-- Ouvre au rôle anon les 4 nouveaux types de contenu affichés par la
-- Bibliothèque : races (+ sous-races), classes (+ sous-classes + aptitudes
-- de classe), dons (feats), objets (+ propriétés d'armes/armures).
--
-- Même constat et même pattern que
-- 20260918090000_grant_anon_read_spells_library.sql (sorts) : ces tables
-- n'accordaient jusqu'ici select qu'au rôle authenticated (voir
-- 20260825090200_create_reference_races_classes_tables.sql et
-- 20260825090300_create_reference_spells_items_tables.sql), cohérent avec
-- l'app mobile mais pas avec la Bibliothèque ("accessible sans compte").
--
-- Portée : uniquement les tables réellement consommées par cette tranche de
-- la Bibliothèque. `backgrounds`/`skills`/`alignments`/`tools`/`languages`/
-- `invocations`/`equipment_packs` restent hors périmètre pour l'instant.

grant select on table
  public.races,
  public.subraces,
  public.classes,
  public.subclasses,
  public.class_features,
  public.feats,
  public.items,
  public.weapon_properties,
  public.armor_properties
to anon;

create policy "Anonymous users can read races"
  on public.races for select
  to anon
  using (true);

create policy "Anonymous users can read subraces"
  on public.subraces for select
  to anon
  using (true);

create policy "Anonymous users can read classes"
  on public.classes for select
  to anon
  using (true);

create policy "Anonymous users can read subclasses"
  on public.subclasses for select
  to anon
  using (true);

create policy "Anonymous users can read class_features"
  on public.class_features for select
  to anon
  using (true);

create policy "Anonymous users can read feats"
  on public.feats for select
  to anon
  using (true);

create policy "Anonymous users can read items"
  on public.items for select
  to anon
  using (true);

create policy "Anonymous users can read weapon_properties"
  on public.weapon_properties for select
  to anon
  using (true);

create policy "Anonymous users can read armor_properties"
  on public.armor_properties for select
  to anon
  using (true);

-- translations : élargit la policy anon existante (créée par la migration
-- spells, scopée à entity_type = 'spell') aux entity_type utilisés par ces
-- 4 nouveaux types de contenu plutôt que de dupliquer une policy par type.
drop policy "Anonymous users can read spell translations" on public.translations;

create policy "Anonymous users can read library translations"
  on public.translations for select
  to anon
  using (
    entity_type in ('spell', 'race', 'subrace', 'class', 'subclass', 'class_feature', 'feat', 'item')
  );
