-- Chantier "Personnages" (app mobile) — Phase 1 — Socle de données.
-- Rôle "contenu/admin" habilité à écrire sur les tables de référence D&D
-- (races, classes, sorts, objets...) — voir 01-architecture-technique.md
-- section Sécurité du cahier des charges de l'app mobile.
--
-- Choix technique : une table d'allow-list plutôt qu'un claim JWT
-- (app_metadata), pour rester auditable/gérable en SQL direct. Cette table
-- n'est exposée à aucun rôle client (ni anon, ni authenticated) : la gestion
-- des admins se fait via la console Supabase / service_role uniquement.
create table public.app_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;

-- Aucun accès direct via l'API cliente, y compris en lecture : seule la
-- fonction is_admin() ci-dessous (security definer) peut consulter cette
-- table pour le compte des policies RLS des autres tables.
create policy "No client access to app_admins"
  on public.app_admins for all
  to authenticated
  using (false)
  with check (false);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.app_admins where user_id = auth.uid()
  );
$$;

grant execute on function public.is_admin() to authenticated;

comment on function public.is_admin() is
  'Retourne vrai si auth.uid() fait partie du rôle "contenu/admin" (chantier Personnages). Utilisé dans les policies RLS d''écriture des tables de référence.';
