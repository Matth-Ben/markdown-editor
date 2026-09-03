-- Chantier "Personnages" (app mobile) — Signalement de bug depuis l'app
-- mobile, synchronisé vers une issue GitHub sur
-- Matth-Ben/nexus-jdr-app-mobile (décision produit : GitHub Issues plutôt
-- qu'un canal email/autre outil, gratuit et déjà utilisé pour ce projet,
-- tri/priorité natifs via labels).
--
-- Cette table est écrite en deux temps par l'edge function `report-bug` :
--   1. INSERT initial (client scoped-utilisateur, respecte la RLS INSERT
--      ci-dessous), status='pending' -- AVANT tout appel à l'API GitHub,
--      pour ne jamais perdre un signalement même si GitHub est indisponible.
--   2. UPDATE du statut (client service_role, hors RLS) une fois l'appel
--      GitHub tenté : status='synced' + github_issue_number/url en cas de
--      succès, status='failed' + error_message sinon.
--
-- Ne touche pas à `codex_entries` ni aux tables de référence/personnage
-- existantes -- table autonome, sans lien fonctionnel avec le reste du
-- schéma en dehors de reporter_id (auth.users) et character_id (characters,
-- contexte optionnel et purement informatif : sur quel personnage
-- l'utilisateur se trouvait, pas une donnée protégée modifiée par ce
-- chantier).

create table public.bug_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  description text not null,
  severity text not null check (severity in ('mineur', 'majeur', 'bloquant')),
  app_version text,
  platform text,
  -- Contexte optionnel : personnage affiché au moment du signalement, si
  -- l'app était sur un écran de personnage. on delete set null (comme les
  -- autres FK "contexte" de ce schéma, ex. characters.race_id) : la
  -- suppression du personnage ne doit jamais faire disparaître le
  -- signalement associé.
  character_id uuid references public.characters (id) on delete set null,
  github_issue_number int,
  github_issue_url text,
  status text not null default 'pending' check (status in ('pending', 'synced', 'failed')),
  -- Diagnostic manuel a posteriori si l'appel GitHub échoue (rate limit,
  -- token expiré/mal scopé, dépôt renommé...).
  error_message text,
  created_at timestamptz not null default now()
);

alter table public.bug_reports enable row level security;

-- SELECT : un utilisateur ne voit que ses propres signalements. Pas
-- d'exigence produit actuelle côté mobile (pas d'écran "historique de mes
-- signalements" prévu dans cette itération), mais peu coûteux à activer
-- maintenant et cohérent avec le principe "RLS stricte par propriétaire"
-- des tables personnage (01-architecture-technique.md).
create policy "Reporter can select their bug_reports"
  on public.bug_reports for select
  to authenticated
  using (auth.uid() = reporter_id);

-- INSERT : un utilisateur authentifié peut créer un signalement, jamais au
-- nom d'un autre reporter_id. C'est la voie utilisée par l'edge function
-- report-bug elle-même (client scoped-utilisateur, JWT transmis) -- pas de
-- passage par service_role pour cette étape, afin que l'INSERT reste
-- garanti par RLS et pas seulement par la logique applicative.
create policy "Reporter can insert their bug_reports"
  on public.bug_reports for insert
  to authenticated
  with check (auth.uid() = reporter_id);

-- UPDATE : volontairement AUCUNE policy. RLS activée + aucune policy pour
-- cette commande = deny-all côté client (authenticated), même pattern que
-- l'INSERT de character_campaigns
-- (20260830100100_create_character_campaigns.sql). Seule l'edge function
-- report-bug (clé service_role, qui contourne RLS) peut faire évoluer
-- status/github_issue_number/github_issue_url/error_message après l'appel
-- GitHub -- un client ne doit jamais pouvoir se prétendre "synced" ou
-- falsifier un numéro d'issue.

-- DELETE : pas de policy non plus, aucun besoin identifié (pas de fonction
-- "supprimer mon signalement" dans cette itération).

-- GRANT complet (select/insert/update/delete), même pattern documenté par
-- 20260825091100_grant_authenticated_privileges.sql et
-- 20260830100100_create_character_campaigns.sql : le privilège de table à
-- lui seul n'ouvre rien, la restriction réelle est portée par les policies
-- RLS ci-dessus. Délibéré pour update/delete : on veut que le refus
-- constaté par un client vienne de RLS ("new row violates row-level
-- security policy" / update filtré à 0 ligne), pas d'un "permission denied
-- for table" qui surviendrait avant même l'évaluation de RLS si le GRANT
-- était omis.
grant select, insert, update, delete on table public.bug_reports to authenticated;
