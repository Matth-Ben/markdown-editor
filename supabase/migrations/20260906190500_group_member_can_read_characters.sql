-- Système de groupe (12-partage-et-groupes.md section 2.3, dépôt
-- nexus-jdr-app-mobile) : "un membre d'un groupe peut lire un sous-ensemble
-- restreint de champs (current_hp, max_hp, temporary_hp, statut vivant/mort)
-- des personnages des autres membres du même groupe, via une policy basée
-- sur group_members".
--
-- RLS ne restreint jamais des COLONNES, seulement des LIGNES -- et Supabase
-- Realtime (postgres_changes, utilisé ici pour le tableau de bord PV en
-- temps réel de l'écran "Groupe") ne peut diffuser que depuis une vraie
-- table soumise à RLS ligne-par-ligne, jamais depuis une vue qui exposerait
-- seulement un sous-ensemble de champs. La policy ci-dessous accorde donc un
-- accès en lecture à la LIGNE ENTIÈRE d'un coéquipier -- exactement le même
-- compromis déjà accepté pour "Story owner can select linked characters"
-- (20260830100100_create_character_campaigns.sql), qui donne déjà un accès
-- complet en lecture à un MJ pour ses besoins narratifs alors que l'app web
-- n'en affiche qu'un résumé. La restriction au "sous-ensemble de champs"
-- reste appliquée côté client mobile (l'écran Groupe n'affiche jamais que
-- portrait/nom/race/classe/PV/statut), pas au niveau de la base.
create or replace function public.group_member_can_read_character(p_character_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members gm_target
    join public.group_members gm_viewer
      on gm_viewer.group_id = gm_target.group_id
    where gm_target.character_id = p_character_id
      and gm_viewer.user_id = auth.uid()
  );
$$;

create policy "Group member can select teammates' characters"
  on public.characters for select
  to authenticated
  using (public.group_member_can_read_character(id));

create policy "Group member can select teammates' character_classes"
  on public.character_classes for select
  to authenticated
  using (public.group_member_can_read_character(character_id));
