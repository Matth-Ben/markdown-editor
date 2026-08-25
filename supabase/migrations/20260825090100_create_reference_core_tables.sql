-- Chantier "Personnages" (app mobile) — Phase 1 — Socle de données.
-- Tables de référence "de base" : caractéristiques, compétences,
-- alignements, langues, outils. Lecture publique authentifiée, écriture
-- réservée au rôle contenu/admin (public.is_admin(), voir migration
-- 20260825090000). Voir 02-modele-donnees.md section 2 du cahier des
-- charges de l'app mobile pour le détail du schéma attendu.
--
-- Note d'internationalisation (voir 07-source-donnees-i18n.md) : décision
-- actée — le texte destiné à l'affichage joueur (name...) n'est pas stocké
-- en colonnes directement sur ces tables. Il vit dans la table générique
-- public.translations (migration 20260825090050), qui découple le stockage
-- du contenu de son schéma de règles et n'impose aucune migration de
-- schéma pour ajouter l'anglais (Phase 5+).

-- Les 6 caractéristiques (id texte, fixe).
create table public.abilities (
  id text primary key,
  "order" int not null
);

alter table public.abilities enable row level security;

create policy "Authenticated users can read abilities"
  on public.abilities for select
  to authenticated
  using (true);

create policy "Admins can insert abilities"
  on public.abilities for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update abilities"
  on public.abilities for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete abilities"
  on public.abilities for delete
  to authenticated
  using (public.is_admin());

-- Les 18 compétences, chacune rattachée à une caractéristique.
create table public.skills (
  id int generated always as identity primary key,
  ability_id text not null references public.abilities (id)
);

alter table public.skills enable row level security;

create policy "Authenticated users can read skills"
  on public.skills for select
  to authenticated
  using (true);

create policy "Admins can insert skills"
  on public.skills for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update skills"
  on public.skills for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete skills"
  on public.skills for delete
  to authenticated
  using (public.is_admin());

-- Les 9 alignements. Table réduite à sa clé (le libellé vit dans
-- public.translations) — sert d'ancrage FK pour characters.alignment_id.
create table public.alignments (
  id int generated always as identity primary key
);

alter table public.alignments enable row level security;

create policy "Authenticated users can read alignments"
  on public.alignments for select
  to authenticated
  using (true);

create policy "Admins can insert alignments"
  on public.alignments for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update alignments"
  on public.alignments for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete alignments"
  on public.alignments for delete
  to authenticated
  using (public.is_admin());

-- Langues.
create table public.languages (
  id int generated always as identity primary key,
  type text not null check (type in ('standard', 'exotique'))
);

alter table public.languages enable row level security;

create policy "Authenticated users can read languages"
  on public.languages for select
  to authenticated
  using (true);

create policy "Admins can insert languages"
  on public.languages for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update languages"
  on public.languages for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete languages"
  on public.languages for delete
  to authenticated
  using (public.is_admin());

-- Outils/instruments dont on peut être compétent.
create table public.tools (
  id int generated always as identity primary key,
  category text not null check (category in ('outils_artisan', 'instrument', 'jeu', 'autre'))
);

alter table public.tools enable row level security;

create policy "Authenticated users can read tools"
  on public.tools for select
  to authenticated
  using (true);

create policy "Admins can insert tools"
  on public.tools for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update tools"
  on public.tools for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete tools"
  on public.tools for delete
  to authenticated
  using (public.is_admin());
