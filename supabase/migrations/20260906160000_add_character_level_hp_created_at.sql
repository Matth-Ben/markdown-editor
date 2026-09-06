-- Chantier "Notifications push/email" (app mobile "Personnages") —
-- 15-profil-parametres.md section 3.
--
-- `send-weekly-digest` (edge function, chantier suivant) a besoin de savoir
-- quelles montées de niveau ont eu lieu depuis le dernier résumé envoyé
-- (`notification_preferences.last_email_digest_sent_at`) pour les lister.
-- `character_level_hp` (20260825090400_create_character_tables.sql) n'a
-- jamais eu de colonne d'horodatage jusqu'ici, faute de besoin identifié —
-- ce n'est plus vrai avec ce chantier.
--
-- Backfill : les lignes déjà existantes reçoivent l'horodatage
-- d'application de cette migration (valeur par défaut de la colonne, pas la
-- date réelle de la montée de niveau historique — non tracée jusqu'ici). Sans
-- conséquence pratique : le premier résumé envoyé à un utilisateur compare de
-- toute façon `created_at > last_email_digest_sent_at` où
-- `last_email_digest_sent_at` vaut `null` (traité comme epoch, voir
-- send-weekly-digest/index.ts) — ces lignes backfillées seront donc
-- correctement incluses au moins une fois, peu importe la valeur exacte
-- assignée ici.
alter table public.character_level_hp
  add column created_at timestamptz not null default now();

comment on column public.character_level_hp.created_at is
  'Horodatage de la montée de niveau. Ajouté pour send-weekly-digest (résumé hebdomadaire par email) — voir son commentaire d''en-tête. Les lignes antérieures à cette migration portent l''horodatage de la migration elle-même, pas la date réelle de la montée de niveau (non trackée avant ce chantier).';
