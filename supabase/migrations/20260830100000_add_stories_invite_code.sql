-- Chantier "Personnages" (app mobile) — Phase 4 — préalable côté web.
-- Ajoute le mécanisme d'invitation MJ -> joueur sur `stories`, anticipé
-- (et volontairement exclu) par 20260825090400_create_character_tables.sql
-- (voir son commentaire d'en-tête). Voir 12-partage-et-groupes.md section
-- 5.2 et 02-modele-donnees.md section 4 du cahier des charges de l'app
-- mobile (dépôt nexus-jdr-app-mobile, docs/cahier-des-charges/).
--
-- `invite_code` : code court généré par le MJ depuis l'app web ("Inviter
-- des joueurs"), `null` tant qu'aucune invitation n'a été générée.
-- `invite_code_enabled` : permet de désactiver temporairement l'invitation
-- sans perdre le code (plutôt que de le régénérer) — même pattern que
-- `groups.invite_code` (12-partage-et-groupes.md section 2.1), déjà retenu
-- ailleurs dans le projet pour ce genre de code d'invitation.
--
-- Sécurité (12-partage-et-groupes.md section 5.4) : `invite_code` ne doit
-- JAMAIS être lisible via une policy select publique. La validation d'un
-- code passe uniquement par l'edge function `join-story` (clé service_role,
-- contourne RLS) — jamais par une lecture directe côté client. Vérification
-- faite : la policy "Users can view their own stories" existante
-- (20260716212008_create_stories.sql) filtre déjà sur `auth.uid() = user_id`,
-- donc elle ne fuite pas ce champ à un tiers — seul le propriétaire de
-- l'histoire peut lire sa propre ligne (et donc son propre invite_code, ce
-- qui est légitime : c'est lui qui l'a généré). Aucune policy
-- supplémentaire n'est ajoutée ici ; point de vigilance pour ne jamais en
-- ajouter une qui exposerait ce champ à un utilisateur autre que le
-- propriétaire de l'histoire.

alter table public.stories
  add column invite_code text unique,
  add column invite_code_enabled boolean not null default false;

comment on column public.stories.invite_code is
  'Code court d''invitation, généré par le MJ. Null tant qu''aucune invitation n''a été générée. Ne JAMAIS exposer via une policy select publique : la validation passe uniquement par l''edge function join-story (service_role).';

comment on column public.stories.invite_code_enabled is
  'Permet de désactiver temporairement l''invitation sans perdre/régénérer invite_code.';
