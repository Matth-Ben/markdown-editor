-- Lot 9 de l'import du contenu de référence : table des créatures (bestiaire).
-- Données issues du SRD 5.2 (CC-BY-4.0, « System Reference Document 5.2 » de Wizards of the
-- Coast LLC, https://creativecommons.org/licenses/by/4.0/), traduites en français.
--
-- Champs structurés (caractéristiques, CA, PV, vitesses en pieds comme races.speed) ; traits et
-- actions en jsonb [{name, description}] déjà en français (comme races.traits). Le nom est dans
-- translations (entity_type 'creature', fr + en).

create table if not exists public.creatures (
  id integer generated always as identity primary key,
  size text not null,
  creature_type text not null,
  alignment text,
  armor_class integer,
  armor_detail text,
  hit_points integer,
  hit_dice text,
  speed jsonb not null default '{}'::jsonb,
  ability_scores jsonb not null default '{}'::jsonb,
  saving_throws jsonb not null default '{}'::jsonb,
  skills jsonb not null default '{}'::jsonb,
  damage_vulnerabilities text,
  damage_resistances text,
  damage_immunities text,
  condition_immunities text,
  senses text,
  languages text,
  challenge_rating numeric,
  experience_points integer,
  proficiency_bonus integer,
  initiative_bonus integer,
  traits jsonb not null default '[]'::jsonb,
  actions jsonb not null default '[]'::jsonb,
  bonus_actions jsonb not null default '[]'::jsonb,
  reactions jsonb not null default '[]'::jsonb,
  legendary_actions jsonb not null default '[]'::jsonb,
  source text
);

comment on table public.creatures is
  'Bestiaire (SRD 5.2 traduit). Nom dans translations (entity_type creature). Traits/actions en jsonb [{name, description}] en français. Vitesses en pieds.';

create index if not exists creatures_cr_idx on public.creatures (challenge_rating);
create index if not exists creatures_type_idx on public.creatures (creature_type);

alter table public.creatures enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'creatures' and policyname = 'Anonymous users can read creatures') then
    create policy "Anonymous users can read creatures" on public.creatures for select to anon using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'creatures' and policyname = 'Authenticated users can read creatures') then
    create policy "Authenticated users can read creatures" on public.creatures for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'creatures' and policyname = 'Admins can insert creatures') then
    create policy "Admins can insert creatures" on public.creatures for insert to authenticated with check (is_admin());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'creatures' and policyname = 'Admins can update creatures') then
    create policy "Admins can update creatures" on public.creatures for update to authenticated using (is_admin()) with check (is_admin());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'creatures' and policyname = 'Admins can delete creatures') then
    create policy "Admins can delete creatures" on public.creatures for delete to authenticated using (is_admin());
  end if;
end $$;
