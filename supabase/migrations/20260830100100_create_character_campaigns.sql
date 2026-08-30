-- Chantier "Personnages" (app mobile) — Phase 4 — préalable côté web.
-- Table de liaison personnage <-> histoire ("Rejoindre une histoire") et
-- accès MJ en lecture seule aux personnages rattachés. Anticipé (et
-- volontairement exclu) par 20260825090400_create_character_tables.sql
-- (voir son commentaire d'en-tête). Voir 12-partage-et-groupes.md section 5
-- et 02-modele-donnees.md section 4 du cahier des charges de l'app mobile.
--
-- `codex_entries` (fiches du MJ, catégorie "joueur" incluse) n'est PAS
-- touchée par cette migration — point tranché du cahier des charges
-- (02-modele-donnees.md section 4, "Résolu (25/08/2026)").

create table public.character_campaigns (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  story_id uuid not null references public.stories (id) on delete cascade,
  role text not null default 'joueur' check (role in ('joueur', 'pnj')),
  joined_at timestamptz not null default now(),
  -- Contrainte sur (character_id, story_id), pas (owner_id, story_id) : un
  -- joueur peut rejoindre la même histoire avec plusieurs personnages
  -- successifs (ex. après la mort d'un personnage).
  unique (character_id, story_id)
);

alter table public.character_campaigns enable row level security;

-- SELECT : propriétaire du personnage OU propriétaire de l'histoire (MJ).
create policy "Owner can select their character_campaigns"
  on public.character_campaigns for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Story owner can select their character_campaigns"
  on public.character_campaigns for select
  to authenticated
  using (
    exists (
      select 1 from public.stories s
      where s.id = story_id
        and s.user_id = auth.uid()
    )
  );

-- INSERT : volontairement AUCUNE policy. RLS activée + aucune policy pour
-- une commande = deny-all pour cette commande (comportement Postgres
-- standard), donc tout insert direct via l'API cliente (anon/authenticated)
-- est refusé. C'est une exigence de sécurité explicite de
-- 12-partage-et-groupes.md section 5.4 : empêcher qu'un client attache
-- arbitrairement un personnage à n'importe quelle histoire sans passer par
-- la validation du code d'invitation. Seule l'edge function `join-story`
-- (clé service_role, qui contourne RLS) peut créer une ligne, après avoir
-- vérifié côté serveur le code d'invitation et la propriété du personnage.

-- UPDATE : pas de policy non plus, aucun besoin identifié dans la spec
-- (role/joined_at ne sont pas modifiés après coup).

-- DELETE : propriétaire du personnage ("Quitter l'histoire") OU
-- propriétaire de l'histoire ("Retirer ce joueur").
create policy "Owner can delete their character_campaigns"
  on public.character_campaigns for delete
  to authenticated
  using (public.owns_character(character_id));

create policy "Story owner can delete their character_campaigns"
  on public.character_campaigns for delete
  to authenticated
  using (
    exists (
      select 1 from public.stories s
      where s.id = story_id
        and s.user_id = auth.uid()
    )
  );

-- GRANT complet (select/insert/update/delete), même pattern que les autres
-- tables "personnage" (20260825091100_grant_authenticated_privileges.sql) :
-- le privilège de table à lui seul n'ouvre rien, la restriction réelle est
-- portée par les policies RLS ci-dessus. C'est délibéré pour insert/update :
-- on veut que le refus constaté par un client vienne de RLS ("new row
-- violates row-level security policy"), pas d'un "permission denied for
-- table" qui surviendrait avant même l'évaluation de RLS si le GRANT était
-- omis.
grant select, insert, update, delete on table public.character_campaigns to authenticated;

-- Helper security-definer, même style que public.owns_character(uuid)
-- (20260825090400_create_character_tables.sql) : permet à une policy sur
-- characters/character_* de vérifier que l'appelant est le propriétaire
-- (MJ) d'une histoire à laquelle p_character_id est rattaché, sans dépendre
-- de la lisibilité de character_campaigns/stories pour l'appelant
-- (security definer contourne RLS pour cette vérification interne).
create or replace function public.story_owner_can_read_character(p_character_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.character_campaigns cc
    join public.stories s on s.id = cc.story_id
    where cc.character_id = p_character_id
      and s.user_id = auth.uid()
  );
$$;

grant execute on function public.story_owner_can_read_character(uuid) to authenticated;

comment on function public.story_owner_can_read_character(uuid) is
  'Retourne vrai si p_character_id est rattaché (via character_campaigns) à une histoire dont auth.uid() est le propriétaire (MJ). Donne un accès lecture seule au MJ sur la fiche complète d''un joueur rattaché (12-partage-et-groupes.md section 5.4).';

-- Accès MJ en lecture seule à la fiche complète d'un personnage rattaché :
-- une policy select supplémentaire par table, sur `characters` et sur les
-- 14 tables enfants de 20260825090400_create_character_tables.sql. En
-- PostgreSQL, plusieurs policies "for select" sur une même table se
-- combinent en OR : ceci s'ajoute donc proprement à la policy
-- "Owner can select..." déjà en place sur chaque table, sans la modifier.
create policy "Story owner can select linked characters"
  on public.characters for select
  to authenticated
  using (public.story_owner_can_read_character(id));

create policy "Story owner can select linked character_classes"
  on public.character_classes for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_level_hp"
  on public.character_level_hp for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_ability_scores"
  on public.character_ability_scores for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_ability_increases"
  on public.character_ability_increases for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_skill_proficiencies"
  on public.character_skill_proficiencies for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_tool_proficiencies"
  on public.character_tool_proficiencies for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_languages"
  on public.character_languages for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_feats"
  on public.character_feats for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_spells"
  on public.character_spells for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_spell_slots"
  on public.character_spell_slots for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_invocations"
  on public.character_invocations for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_feature_uses"
  on public.character_feature_uses for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_inventory"
  on public.character_inventory for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));

create policy "Story owner can select linked character_class_options"
  on public.character_class_options for select
  to authenticated
  using (public.story_owner_can_read_character(character_id));
