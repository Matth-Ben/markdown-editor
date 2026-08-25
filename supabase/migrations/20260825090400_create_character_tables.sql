-- Chantier "Personnages" (app mobile) — Phase 1 — Socle de données.
-- Tables "personnage" (données joueur) : voir 02-modele-donnees.md section 3
-- du cahier des charges de l'app mobile. RLS stricte par propriétaire
-- (auth.uid() = owner_id), voir 01-architecture-technique.md section
-- Sécurité.
--
-- Hors périmètre de cette migration (volontairement) : `character_campaigns`
-- et les colonnes invite_code/invite_code_enabled de `stories` — ce sont des
-- livrables de la Phase 4 (synchronisation avec "Histoires", cf.
-- 06-roadmap.md), à coordonner avec l'équipe web le moment venu. La Phase 1
-- ne touche donc à rien côté `stories`/`codex_entries`.
--
-- Note de modélisation : le cahier des charges (04-fonctionnalites-app-mobile.md,
-- section 3) précise que l'assistant de création doit permettre de reprendre
-- un personnage en brouillon. En conséquence, toutes les colonnes qui ne
-- sont pas strictement indispensables dès la première sauvegarde (race,
-- sous-race, historique, alignement...) sont nullables ici, même quand
-- 02-modele-donnees.md ne précise pas explicitement "(nullable)" pour
-- `alignment_id` — jugé nécessaire pour ne pas bloquer l'enregistrement
-- d'un brouillon incomplet.

create table public.characters (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null default '',
  race_id int references public.races (id) on delete set null,
  subrace_id int references public.subraces (id) on delete set null,
  race_custom_text text,
  background_id int references public.backgrounds (id) on delete set null,
  background_custom_text text,
  alignment_id int references public.alignments (id) on delete set null,
  xp int not null default 0,
  max_hp int not null default 0,
  current_hp int not null default 0,
  temporary_hp int not null default 0,
  sexe text,
  age text,
  height text,
  weight text,
  eyes text,
  skin text,
  hair text,
  portrait_url text,
  appearance_text text not null default '',
  traits_text text not null default '',
  ideals_text text not null default '',
  bonds_text text not null default '',
  flaws_text text not null default '',
  backstory_text text not null default '',
  allies_text text not null default '',
  features_text text not null default '',
  treasure_text text not null default '',
  currency_gp int not null default 0,
  currency_pp int not null default 0,
  currency_ep int not null default 0,
  currency_sp int not null default 0,
  currency_cp int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.characters enable row level security;

create policy "Owner can select their characters"
  on public.characters for select
  to authenticated
  using (auth.uid() = owner_id);

create policy "Owner can insert their characters"
  on public.characters for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "Owner can update their characters"
  on public.characters for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Owner can delete their characters"
  on public.characters for delete
  to authenticated
  using (auth.uid() = owner_id);

-- Helper security-definer réutilisé par toutes les tables "enfant" de
-- characters ci-dessous, pour éviter de répéter un sous-select sur
-- characters (et pour rester correct même si RLS empêchait autrement une
-- policy de lire characters pour vérifier la propriété).
create or replace function public.owns_character(p_character_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.characters c
    where c.id = p_character_id
      and c.owner_id = auth.uid()
  );
$$;

grant execute on function public.owns_character(uuid) to authenticated;

comment on function public.owns_character(uuid) is
  'Retourne vrai si le personnage p_character_id appartient à auth.uid(). Utilisé dans les policies RLS des tables "character_*".';

-- Supporte le multiclassage (une ou plusieurs lignes par personnage).
create table public.character_classes (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  class_id int not null references public.classes (id),
  subclass_id int references public.subclasses (id),
  level int not null default 1,
  is_primary boolean not null default false
);

alter table public.character_classes enable row level security;

create policy "Owner can select their character_classes"
  on public.character_classes for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_classes"
  on public.character_classes for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_classes"
  on public.character_classes for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_classes"
  on public.character_classes for delete
  to authenticated
  using (public.owns_character(character_id));

-- Historique des PV gagnés par niveau.
create table public.character_level_hp (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  level int not null,
  hp_rolled int not null,
  method text not null check (method in ('lance', 'moyenne'))
);

alter table public.character_level_hp enable row level security;

create policy "Owner can select their character_level_hp"
  on public.character_level_hp for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_level_hp"
  on public.character_level_hp for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_level_hp"
  on public.character_level_hp for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_level_hp"
  on public.character_level_hp for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_ability_scores (
  character_id uuid not null references public.characters (id) on delete cascade,
  ability_id text not null references public.abilities (id),
  score int not null,
  primary key (character_id, ability_id)
);

alter table public.character_ability_scores enable row level security;

create policy "Owner can select their character_ability_scores"
  on public.character_ability_scores for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_ability_scores"
  on public.character_ability_scores for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_ability_scores"
  on public.character_ability_scores for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_ability_scores"
  on public.character_ability_scores for delete
  to authenticated
  using (public.owns_character(character_id));

-- Historique des augmentations de caractéristiques (ASI ou don).
create table public.character_ability_increases (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  level int not null,
  ability_id text not null references public.abilities (id),
  increase int not null,
  source text not null check (source in ('asi', 'feat'))
);

alter table public.character_ability_increases enable row level security;

create policy "Owner can select their character_ability_increases"
  on public.character_ability_increases for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_ability_increases"
  on public.character_ability_increases for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_ability_increases"
  on public.character_ability_increases for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_ability_increases"
  on public.character_ability_increases for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_skill_proficiencies (
  character_id uuid not null references public.characters (id) on delete cascade,
  skill_id int not null references public.skills (id),
  proficiency text not null default 'aucune' check (proficiency in ('aucune', 'competente', 'expertise')),
  primary key (character_id, skill_id)
);

alter table public.character_skill_proficiencies enable row level security;

create policy "Owner can select their character_skill_proficiencies"
  on public.character_skill_proficiencies for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_skill_proficiencies"
  on public.character_skill_proficiencies for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_skill_proficiencies"
  on public.character_skill_proficiencies for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_skill_proficiencies"
  on public.character_skill_proficiencies for delete
  to authenticated
  using (public.owns_character(character_id));

-- tool_id nullable (outil non référencé -> custom_text) : pas de clé
-- composite naturelle, d'où l'id de substitution.
create table public.character_tool_proficiencies (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  tool_id int references public.tools (id),
  custom_text text,
  constraint character_tool_proficiencies_tool_or_custom check (
    tool_id is not null or custom_text is not null
  )
);

alter table public.character_tool_proficiencies enable row level security;

create policy "Owner can select their character_tool_proficiencies"
  on public.character_tool_proficiencies for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_tool_proficiencies"
  on public.character_tool_proficiencies for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_tool_proficiencies"
  on public.character_tool_proficiencies for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_tool_proficiencies"
  on public.character_tool_proficiencies for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_languages (
  character_id uuid not null references public.characters (id) on delete cascade,
  language_id int not null references public.languages (id),
  primary key (character_id, language_id)
);

alter table public.character_languages enable row level security;

create policy "Owner can select their character_languages"
  on public.character_languages for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_languages"
  on public.character_languages for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_languages"
  on public.character_languages for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_languages"
  on public.character_languages for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_feats (
  character_id uuid not null references public.characters (id) on delete cascade,
  feat_id int not null references public.feats (id),
  level_taken int not null,
  primary key (character_id, feat_id)
);

alter table public.character_feats enable row level security;

create policy "Owner can select their character_feats"
  on public.character_feats for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_feats"
  on public.character_feats for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_feats"
  on public.character_feats for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_feats"
  on public.character_feats for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_spells (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  spell_id int not null references public.spells (id),
  status text not null check (status in ('connu', 'préparé', 'inné')),
  source_class_id int references public.classes (id)
);

alter table public.character_spells enable row level security;

create policy "Owner can select their character_spells"
  on public.character_spells for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_spells"
  on public.character_spells for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_spells"
  on public.character_spells for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_spells"
  on public.character_spells for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_spell_slots (
  character_id uuid not null references public.characters (id) on delete cascade,
  slot_level int not null check (slot_level between 1 and 9),
  slots_total int not null default 0,
  slots_used int not null default 0,
  primary key (character_id, slot_level)
);

alter table public.character_spell_slots enable row level security;

create policy "Owner can select their character_spell_slots"
  on public.character_spell_slots for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_spell_slots"
  on public.character_spell_slots for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_spell_slots"
  on public.character_spell_slots for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_spell_slots"
  on public.character_spell_slots for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_invocations (
  character_id uuid not null references public.characters (id) on delete cascade,
  invocation_id int not null references public.invocations (id),
  primary key (character_id, invocation_id)
);

alter table public.character_invocations enable row level security;

create policy "Owner can select their character_invocations"
  on public.character_invocations for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_invocations"
  on public.character_invocations for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_invocations"
  on public.character_invocations for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_invocations"
  on public.character_invocations for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_feature_uses (
  character_id uuid not null references public.characters (id) on delete cascade,
  class_feature_id int not null references public.class_features (id),
  uses_remaining int not null default 0,
  primary key (character_id, class_feature_id)
);

alter table public.character_feature_uses enable row level security;

create policy "Owner can select their character_feature_uses"
  on public.character_feature_uses for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_feature_uses"
  on public.character_feature_uses for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_feature_uses"
  on public.character_feature_uses for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_feature_uses"
  on public.character_feature_uses for delete
  to authenticated
  using (public.owns_character(character_id));

create table public.character_inventory (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  item_id int references public.items (id),
  custom_name text,
  quantity int not null default 1,
  equipped boolean not null default false,
  notes text,
  constraint character_inventory_item_or_custom check (
    item_id is not null or custom_name is not null
  )
);

alter table public.character_inventory enable row level security;

create policy "Owner can select their character_inventory"
  on public.character_inventory for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_inventory"
  on public.character_inventory for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_inventory"
  on public.character_inventory for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_inventory"
  on public.character_inventory for delete
  to authenticated
  using (public.owns_character(character_id));

-- Choix génériques propres à une classe/niveau (styles de combat, ennemis
-- jurés, domaines/écoles choisis...).
create table public.character_class_options (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  class_feature_id int not null references public.class_features (id),
  level int not null,
  chosen_value text not null
);

alter table public.character_class_options enable row level security;

create policy "Owner can select their character_class_options"
  on public.character_class_options for select
  to authenticated
  using (public.owns_character(character_id));

create policy "Owner can insert their character_class_options"
  on public.character_class_options for insert
  to authenticated
  with check (public.owns_character(character_id));

create policy "Owner can update their character_class_options"
  on public.character_class_options for update
  to authenticated
  using (public.owns_character(character_id))
  with check (public.owns_character(character_id));

create policy "Owner can delete their character_class_options"
  on public.character_class_options for delete
  to authenticated
  using (public.owns_character(character_id));

-- Portraits de personnage (Supabase Storage) : même logique que
-- story-covers/story-content-images côté web — bucket public en lecture,
-- écriture restreinte au dossier de l'utilisateur propriétaire
-- ({user_id}/...), voir 01-architecture-technique.md.
insert into storage.buckets (id, name, public)
values ('character-portraits', 'character-portraits', true)
on conflict (id) do nothing;

create policy "Character portraits are publicly readable"
  on storage.objects for select
  using (bucket_id = 'character-portraits');

create policy "Users can upload their own character portraits"
  on storage.objects for insert
  with check (
    bucket_id = 'character-portraits'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update their own character portraits"
  on storage.objects for update
  using (
    bucket_id = 'character-portraits'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete their own character portraits"
  on storage.objects for delete
  using (
    bucket_id = 'character-portraits'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
