-- Chantier "Bibliothèque" (dépôt nexus-jdr-library) — propositions de
-- contenu de la communauté, avec avis (pouce haut/bas) et commentaires.
--
-- Règles produit (docs/cahier-des-charges/03 et 04 du dépôt library) :
--   * consultation ouverte à tous (anon compris) ;
--   * proposer, commenter, voter : utilisateurs connectés uniquement ;
--   * un seul vote par personne et par proposition, jamais sur sa propre
--     proposition, et seulement tant qu'elle est en attente ;
--   * seul l'admin (public.is_admin()) approuve/refuse : le vote est un
--     signal affiché, il ne change jamais le statut automatiquement ;
--   * l'approbation ne fait QUE changer le statut : l'intégration du contenu
--     approuvé dans les tables de référence (spells, feats, items) est une
--     étape distincte, pas traitée ici.
--
-- Trois tables : content_proposals, proposal_comments, proposal_votes.
-- Les compteurs (votes_up, votes_down, comments_count) sont dénormalisés sur
-- content_proposals et maintenus par triggers security definer, pour lister
-- les propositions avec leur score sans agréger à chaque lecture.

create table public.content_proposals (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users (id) on delete cascade,
  content_type text not null check (content_type in ('spell', 'feat', 'item')),
  title text not null check (char_length(btrim(title)) between 1 and 120),
  -- Contenu proposé (champs du type ciblé) ; validé côté application, borné
  -- ici en taille pour qu'un client ne puisse pas y stocker n'importe quoi.
  payload jsonb not null check (
    jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 20000
  ),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  rejection_reason text check (rejection_reason is null or char_length(rejection_reason) <= 500),
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  votes_up integer not null default 0,
  votes_down integer not null default 0,
  comments_count integer not null default 0,
  created_at timestamptz not null default now(),
  constraint content_proposals_reason_only_if_rejected check (
    status = 'rejected' or rejection_reason is null
  )
);

create index content_proposals_status_created_idx
  on public.content_proposals (status, created_at desc);

create table public.proposal_comments (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.content_proposals (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index proposal_comments_proposal_idx
  on public.proposal_comments (proposal_id, created_at);

create table public.proposal_votes (
  proposal_id uuid not null references public.content_proposals (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  vote text not null check (vote in ('up', 'down')),
  created_at timestamptz not null default now(),
  -- Clé composite : un seul vote par personne et par proposition, garanti au
  -- niveau base (pas seulement par l'application).
  primary key (proposal_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Nom d'affichage de l'auteur (colonne calculée PostgREST, même patron que
-- stories_gm_display_name) : ne retourne QUE user_metadata.full_name, jamais
-- l'e-mail. null si non renseigné — l'interface affiche alors "Membre".
-- ---------------------------------------------------------------------------
create or replace function public.content_proposals_author_name(proposal public.content_proposals)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select nullif(btrim(u.raw_user_meta_data->>'full_name'), '')
  from auth.users u
  where u.id = proposal.author_id;
$$;

create or replace function public.proposal_comments_author_name(proposal_comment public.proposal_comments)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select nullif(btrim(u.raw_user_meta_data->>'full_name'), '')
  from auth.users u
  where u.id = proposal_comment.author_id;
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

-- Recalcule les compteurs d'une proposition depuis les tables sources.
create or replace function public.refresh_proposal_counts(target uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.content_proposals p
  set votes_up = (select count(*) from public.proposal_votes v where v.proposal_id = p.id and v.vote = 'up'),
      votes_down = (select count(*) from public.proposal_votes v where v.proposal_id = p.id and v.vote = 'down'),
      comments_count = (select count(*) from public.proposal_comments c where c.proposal_id = p.id)
  where p.id = target;
$$;

revoke all on function public.refresh_proposal_counts(uuid) from public;

create or replace function public.trg_refresh_proposal_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.refresh_proposal_counts(new.proposal_id);
  end if;
  if tg_op in ('DELETE', 'UPDATE') then
    perform public.refresh_proposal_counts(old.proposal_id);
  end if;
  return null;
end;
$$;

revoke all on function public.trg_refresh_proposal_counts() from public;

create trigger proposal_votes_refresh_counts
  after insert or update or delete on public.proposal_votes
  for each row execute function public.trg_refresh_proposal_counts();

create trigger proposal_comments_refresh_counts
  after insert or delete on public.proposal_comments
  for each row execute function public.trg_refresh_proposal_counts();

-- Traçabilité de la décision : reviewed_by/reviewed_at sont posés par la base
-- (jamais fournis par le client) à chaque changement de statut.
create or replace function public.trg_content_proposals_review()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'pending' then
      new.reviewed_by := null;
      new.reviewed_at := null;
      new.rejection_reason := null;
    else
      new.reviewed_by := auth.uid();
      new.reviewed_at := now();
    end if;
  end if;
  return new;
end;
$$;

create trigger content_proposals_review
  before update on public.content_proposals
  for each row execute function public.trg_content_proposals_review();

-- ---------------------------------------------------------------------------
-- Privilèges (explicites : ce projet n'accorde rien par défaut, voir
-- 20260825091100_grant_authenticated_privileges.sql) et RLS
-- ---------------------------------------------------------------------------
alter table public.content_proposals enable row level security;
alter table public.proposal_comments enable row level security;
alter table public.proposal_votes enable row level security;

grant select on public.content_proposals, public.proposal_comments to anon, authenticated;
grant execute on function public.content_proposals_author_name(public.content_proposals) to anon, authenticated;
grant execute on function public.proposal_comments_author_name(public.proposal_comments) to anon, authenticated;

grant insert, delete on public.content_proposals to authenticated;
-- Seuls les champs de décision sont modifiables (par l'admin, cf. policy) ;
-- le contenu proposé et les compteurs ne le sont jamais par un client.
grant update (status, rejection_reason) on public.content_proposals to authenticated;
grant insert, delete on public.proposal_comments to authenticated;
grant select, insert, delete on public.proposal_votes to authenticated;
grant update (vote) on public.proposal_votes to authenticated;

-- content_proposals
create policy "Anyone can read proposals"
  on public.content_proposals for select
  to anon, authenticated
  using (true);

create policy "Authenticated users can propose"
  on public.content_proposals for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and status = 'pending'
    and rejection_reason is null
    and reviewed_by is null
    and reviewed_at is null
    and votes_up = 0
    and votes_down = 0
    and comments_count = 0
  );

create policy "Admins can review proposals"
  on public.content_proposals for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Authors delete their pending proposals, admins any"
  on public.content_proposals for delete
  to authenticated
  using ((author_id = auth.uid() and status = 'pending') or public.is_admin());

-- proposal_comments
create policy "Anyone can read comments"
  on public.proposal_comments for select
  to anon, authenticated
  using (true);

create policy "Authenticated users can comment"
  on public.proposal_comments for insert
  to authenticated
  with check (author_id = auth.uid());

create policy "Authors delete their comments, admins any"
  on public.proposal_comments for delete
  to authenticated
  using (author_id = auth.uid() or public.is_admin());

-- proposal_votes : chacun ne voit que son propre vote (les totaux sont
-- publics via content_proposals.votes_up/votes_down).
create policy "Users read their own votes"
  on public.proposal_votes for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users vote on pending proposals of others"
  on public.proposal_votes for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.content_proposals p
      where p.id = proposal_id and p.status = 'pending' and p.author_id <> auth.uid()
    )
  );

create policy "Users change their own vote while pending"
  on public.proposal_votes for update
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.content_proposals p
      where p.id = proposal_id and p.status = 'pending' and p.author_id <> auth.uid()
    )
  );

create policy "Users withdraw their own vote"
  on public.proposal_votes for delete
  to authenticated
  using (user_id = auth.uid());
