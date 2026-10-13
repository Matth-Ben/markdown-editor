-- Système de groupe (12-partage-et-groupes.md section 2, dépôt
-- nexus-jdr-app-mobile) : décision explicite de Matthias (12/10/2026) -- un
-- joueur peut créer OU rejoindre un groupe SANS sélectionner de personnage,
-- avec le rôle de MJ : il voit alors les fiches complètes des autres
-- membres (déjà permis par `is_group_member`/`group_member_can_read_character`/
-- `get_group_member_character`, voir plus bas) sans avoir lui-même de
-- personnage dans le groupe. Au plus UN membre MJ sans personnage par
-- groupe (pas plusieurs).
--
-- Vérification faite avant d'écrire cette migration (relecture des trois
-- fichiers cités) : aucune des fonctions ci-dessous ne déréférence
-- `character_id` pour le VIEWER (l'appelant) -- elles s'appuient uniquement
-- sur l'existence d'une ligne `group_members` pour `(group_id, auth.uid())`.
-- Un membre avec `character_id is null` continue donc de satisfaire
-- `is_group_member`/`group_member_can_read_character` (en tant que viewer)
-- sans aucun changement de policy :
--   - `public.is_group_member(p_group_id)` (20260906182601_create_groups.sql) :
--     `exists (... where m.group_id = p_group_id and m.user_id = auth.uid())`
--     -- ne lit jamais `character_id`.
--   - `public.group_member_can_read_character(p_character_id)`
--     (20260906190500_group_member_can_read_characters.sql) : filtre le
--     personnage CIBLE par `gm_target.character_id = p_character_id` (donc
--     un membre sans personnage n'est jamais lui-même une cible lisible --
--     cohérent, il n'a pas de fiche), mais le VIEWER n'est identifié que par
--     `gm_viewer.user_id = auth.uid()` via la jointure sur `group_id`.
--   - `public.get_group_member_character(p_group_id, p_character_id)`
--     (20260927100000_group_member_character_sheet.sql) : la première
--     vérification ("l'appelant doit être membre du groupe") ne porte que
--     sur `user_id`, la seconde ("le personnage demandé doit participer à
--     ce groupe") porte sur le personnage CIBLE, jamais sur celui du viewer.
-- Donc : une fois qu'un membre MJ sans personnage a sa ligne `group_members`
-- (`character_id = null`), il peut déjà lire les fiches complètes des
-- autres membres sans aucune modification RLS. Seul le SCHÉMA doit changer
-- (rendre `character_id` nullable + imposer "au plus un MJ sans personnage
-- par groupe"), pas les policies/fonctions de lecture.
--
-- `role` ('owner'/'membre') n'est PAS étendu avec une troisième valeur :
-- ce champ reste la permission de gestion du groupe (indépendante du fait
-- d'avoir un personnage ou non -- `groups.owner_id` fait déjà foi pour les
-- droits de gestion réels, `group_members.role` n'est qu'un affichage/une
-- commodité). "MJ sans personnage" se dérive uniquement de
-- `character_id is null`, visible côté client mobile.

-- `character_id` était jusqu'ici NOT NULL et colonne de la clé primaire
-- composite (group_id, character_id) -- Postgres interdit NULL dans une
-- colonne de clé primaire, donc il faut d'abord remplacer la PK composite
-- par une clé de substitution avant de pouvoir relâcher la contrainte NOT
-- NULL.
alter table public.group_members drop constraint group_members_pkey;

alter table public.group_members
  add column id uuid not null default gen_random_uuid();

alter table public.group_members
  add constraint group_members_pkey primary key (id);

alter table public.group_members
  alter column character_id drop not null;

-- Remplace l'unicité implicitement garantie par l'ancienne PK composite
-- (group_id, character_id) : un même personnage ne peut toujours pas
-- rejoindre deux fois le même groupe. Index partiel (pas une contrainte
-- unique classique) car `character_id` peut désormais être NULL, et
-- Postgres ne considère jamais deux NULL comme égaux dans une contrainte
-- unique classique -- ce qui aurait de toute façon autorisé plusieurs
-- membres sans personnage sans le `where` explicite ci-dessous.
create unique index group_members_group_id_character_id_key
  on public.group_members (group_id, character_id)
  where character_id is not null;

-- Nouvelle contrainte (coeur de cette migration) : au plus UNE ligne par
-- groupe où `character_id is null` -- impose "un seul MJ sans personnage
-- par groupe" au niveau base, pas seulement côté edge function (filet de
-- sécurité contre une course entre deux requêtes concurrentes, même
-- principe que les filets déjà en place dans create-group/join-group pour
-- `already_in_group`).
create unique index group_members_one_null_character_per_group
  on public.group_members (group_id)
  where character_id is null;

-- `unique (group_id, user_id)` (déclarée à la création de la table) n'est
-- pas touchée par cette migration : elle ne dépendait pas de la PK
-- composite remplacée ci-dessus, et continue de garantir qu'un utilisateur
-- ne participe à un groupe qu'avec une seule ligne group_members (avec ou
-- sans personnage).
