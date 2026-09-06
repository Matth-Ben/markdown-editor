-- Chantier "Notifications push/email" (app mobile "Personnages") —
-- `docs/cahier-des-charges/15-profil-parametres.md` section 3.
--
-- Périmètre de cette migration : le socle de données (préférences,
-- tokens d'appareil, horodatage du dernier repos long pour le rappel).
-- L'edge function d'envoi et les déclencheurs (trigger DB / cron) sont un
-- chantier séparé côté fonctions, pas dans cette migration.
--
-- Déclencheur "invitation à rejoindre une histoire reçue" (spec section
-- 3.1) volontairement absent des préférences ci-dessous : le modèle
-- actuel d'invitation est un code partagé hors bande (pas une invitation
-- nominative par joueur, voir 12-partage-et-groupes.md section 5.7) — il
-- n'existe aucun événement serveur "invitation reçue par cet utilisateur"
-- à notifier tant que les invitations nominatives ne sont pas construites.
-- Seuls les 2 déclencheurs réellement observables sont couverts : le MJ
-- retire l'accès à une histoire, et le rappel de repos long.

-- Préférences de notification, une ligne par utilisateur — absence de
-- ligne == valeurs par défaut ci-dessous (même convention que
-- character_spell_slots/character_feature_uses : pas d'initialisation à
-- la création de compte, calculée par défaut côté lecture).
create table public.notification_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  push_enabled boolean not null default true,
  push_rest_reminder boolean not null default true,
  push_access_revoked boolean not null default true,
  email_digest_enabled boolean not null default false,
  -- Horodatage du dernier résumé email envoyé, pour que la fonction cron
  -- d'envoi sache si un nouveau résumé est dû (période hebdomadaire) sans
  -- dépendre d'une table de file d'attente séparée.
  last_email_digest_sent_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

create policy "Owner can select their notification_preferences"
  on public.notification_preferences for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Owner can insert their notification_preferences"
  on public.notification_preferences for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Owner can update their notification_preferences"
  on public.notification_preferences for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Pas de policy DELETE : aucun besoin produit identifié (les préférences
-- disparaissent de toute façon en cascade si le compte est supprimé).

grant select, insert, update on table public.notification_preferences to authenticated;

-- Tokens d'appareil FCM/APNs, un par installation (un utilisateur peut
-- avoir plusieurs appareils). PK sur le token lui-même (identifie une
-- installation unique) plutôt que composite (user_id, token) : un même
-- token ne peut physiquement appartenir qu'à un seul utilisateur connecté
-- à la fois côté client, et ça simplifie l'upsert de rafraîchissement
-- (`onConflict: 'token'`) si Firebase fait tourner le token sous le même
-- utilisateur.
create table public.user_push_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

create index user_push_tokens_user_id_idx on public.user_push_tokens (user_id);

alter table public.user_push_tokens enable row level security;

create policy "Owner can select their user_push_tokens"
  on public.user_push_tokens for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Owner can insert their user_push_tokens"
  on public.user_push_tokens for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Owner can update their user_push_tokens"
  on public.user_push_tokens for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Owner can delete their user_push_tokens"
  on public.user_push_tokens for delete
  to authenticated
  using (auth.uid() = user_id);

-- Pas de policy SELECT pour un autre rôle : seule l'edge function d'envoi
-- (clé service_role, hors RLS) lit les tokens d'un destinataire pour lui
-- envoyer une notification.

grant select, insert, update, delete on table public.user_push_tokens to authenticated;

-- Horodatage du dernier repos long, pour le rappel "repos long non pris
-- depuis longtemps" (spec section 3.1) — n'existait nulle part avant
-- cette migration. Mis à jour par l'app mobile (CharacterRepository.
-- applyRest) à chaque repos long, jamais au repos court.
alter table public.characters
  add column last_long_rest_at timestamptz;
