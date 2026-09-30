-- Chantier "Bibliothèque" (dépôt nexus-jdr-library) : lecture anonyme des tables de
-- référence encore fermées aux visiteurs.
--
-- Les pages Invocations, Lignées, Historiques, les sorts de sous-classe, les sorts
-- innés raciaux et le filtre par classe des sorts lisent ces tables. Le rôle anon a
-- déjà le privilège select, mais RLS est active sans policy pour lui : un visiteur
-- non connecté obtenait des listes vides.
--
-- Même pattern que 20260918090000_grant_anon_read_spells_library.sql.
-- Idempotente (drop policy if exists).

grant select on table
  public.invocations,
  public.race_lineages,
  public.racial_innate_spells,
  public.subclass_spells,
  public.spell_classes,
  public.backgrounds
to anon;

drop policy if exists "Anonymous users can read invocations" on public.invocations;
create policy "Anonymous users can read invocations"
  on public.invocations for select
  to anon
  using (true);

drop policy if exists "Anonymous users can read race_lineages" on public.race_lineages;
create policy "Anonymous users can read race_lineages"
  on public.race_lineages for select
  to anon
  using (true);

drop policy if exists "Anonymous users can read racial_innate_spells" on public.racial_innate_spells;
create policy "Anonymous users can read racial_innate_spells"
  on public.racial_innate_spells for select
  to anon
  using (true);

drop policy if exists "Anonymous users can read subclass_spells" on public.subclass_spells;
create policy "Anonymous users can read subclass_spells"
  on public.subclass_spells for select
  to anon
  using (true);

drop policy if exists "Anonymous users can read spell_classes" on public.spell_classes;
create policy "Anonymous users can read spell_classes"
  on public.spell_classes for select
  to anon
  using (true);

drop policy if exists "Anonymous users can read backgrounds" on public.backgrounds;
create policy "Anonymous users can read backgrounds"
  on public.backgrounds for select
  to anon
  using (true);
