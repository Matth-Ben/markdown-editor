-- Trace la SOURCE "race" d'une competence/outil choisi par un trait racial a
-- choix structure (cf. 20261005140000_races_skill_and_tool_choice.sql :
-- races.skill_choice / races.tool_choice). Les tables generiques
-- character_skill_proficiencies / character_tool_proficiencies restent la
-- source de verite du personnage (classe, historique ou race confondues) et
-- ne sont pas modifiees ici ; cette table ne fait qu'indiquer, pour une
-- competence ou un outil deja present dans ces tables generiques, qu'il a
-- ete accorde par un trait racial a choix plutot que par la classe ou
-- l'historique -- necessaire pour la carte "CHOIX DE RACE" de la fiche
-- personnage (app mobile), sur le meme principe que la carte "CHOIX DE
-- CLASSE" qui lit deja character_class_options.
--
-- Meme convention que public.character_class_options (dans
-- 20260825090400_create_character_tables.sql) : id uuid, character_id uuid
-- references characters(id) on delete cascade, RLS via owns_character().
--
-- Ne modifie aucune autre table. Ne touche pas a codex_entries.

create table public.character_race_choices (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  kind text not null check (kind in ('competence', 'outil')),
  skill_id int references public.skills (id),
  tool_id int references public.tools (id)
);

comment on table public.character_race_choices is
  'Une ligne = une competence OU un outil accorde par un trait racial a choix (races.skill_choice / races.tool_choice), pour distinguer cette source de la classe/l''historique. skill_id/tool_id mutuellement exclusifs selon kind.';

alter table public.character_race_choices enable row level security;

create policy "Owner can select their character_race_choices"
  on public.character_race_choices for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_race_choices"
  on public.character_race_choices for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_race_choices"
  on public.character_race_choices for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_race_choices"
  on public.character_race_choices for delete
  to authenticated
  using (public.owns_character(character_id));
