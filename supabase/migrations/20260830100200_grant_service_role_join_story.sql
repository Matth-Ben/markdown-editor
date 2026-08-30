-- Chantier "Personnages" (app mobile) — Phase 4 — préalable côté web.
-- GRANTs explicites pour `service_role` sur les tables lues/écrites par
-- l'edge function `join-story` (supabase/functions/join-story/).
--
-- Constat fait en testant l'edge function contre le stack Supabase local
-- (`supabase functions serve join-story`, cf. démarche de vérification de
-- 20260830100100_create_character_campaigns.sql) : `service_role` n'a, sur
-- ce projet, AUCUN privilège explicite de table (select/insert/update/
-- delete) sur `public.stories`/`public.characters`/`public.character_campaigns`
-- — uniquement TRIGGER/TRUNCATE/REFERENCES, hérités par défaut. Un premier
-- appel avec le client service_role échoue donc avec "permission denied for
-- table stories" (Postgres error 42501), avant même l'insertion dans
-- character_campaigns. Ce constat est cohérent avec celui déjà documenté
-- dans 20260825091100_grant_authenticated_privileges.sql pour le rôle
-- `authenticated` (le comportement "not auto-exposed" mentionné dans
-- supabase/config.toml, section [api], semble s'appliquer à tous les rôles
-- Data API, pas seulement `authenticated`) — et c'est la première edge
-- function de ce dépôt à s'appuyer sur `service_role` pour contourner RLS,
-- donc rien ne l'avait révélé jusqu'ici.
--
-- Cette migration accorde explicitement à `service_role` les privilèges
-- nécessaires au flux `join-story` (12-partage-et-groupes.md section 5.4) :
-- lire `stories` par invite_code, lire `characters` pour vérifier la
-- propriété, lire/insérer dans `character_campaigns`. `service_role`
-- contourne déjà RLS par construction (clé serveur uniquement, jamais
-- exposée à un client) : ces GRANTs ne changent donc pas le modèle de
-- sécurité côté client, ils corrigent uniquement l'accès du rôle de
-- confiance côté serveur. GRANT est idempotent : sans effet si le projet
-- distant `nexus-jdr` accordait déjà ces privilèges par défaut.

grant select on table public.stories to service_role;
grant select on table public.characters to service_role;
grant select, insert on table public.character_campaigns to service_role;
