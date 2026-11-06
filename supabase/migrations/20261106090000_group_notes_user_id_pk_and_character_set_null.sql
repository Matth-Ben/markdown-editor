-- F02(a) + D170 : carnet de notes de groupe (group_notes) accessible à un
-- MJ sans personnage, et FK characters non destructive.
--
-- Contexte (docs/retours-utilisateurs.md, dépôt nexus-jdr-app-mobile,
-- proposition F02 validée par Matthias) : 20260916090000_create_group_notes.sql
-- donne à group_notes une PK (group_id, character_id) ET character_id NOT
-- NULL. Un MJ qui a rejoint/créé un groupe sans personnage
-- (group_members.character_id null, is_game_master = true, depuis
-- 20261013100000_group_member_without_character.sql) ne peut donc JAMAIS
-- écrire de note : l'INSERT échoue sur la contrainte NOT NULL avant même
-- d'atteindre RLS. Avis de faisabilité dev-backend-supabase (même document) :
-- cette PK est de toute façon redondante avec (group_id, user_id), garanti
-- unique par group_members depuis sa création (20260906182601_create_groups.sql,
-- `unique (group_id, user_id)`) -- un même utilisateur ne peut avoir qu'UN
-- SEUL personnage par groupe à la fois. On bascule donc la PK sur
-- (group_id, user_id) ; character_id devient nullable et purement
-- informatif. Aucune policy RLS de group_notes n'est réécrite ici :
-- toutes reposaient déjà exclusivement sur `auth.uid() = user_id` (voir
-- 20260916090000_create_group_notes.sql), jamais sur character_id, pour
-- l'autorisation.
--
-- D170 (docs/dette-technique.md, dépôt mobile) trouvé incidemment par
-- dev-backend-supabase en instruisant F02 : la FK character_id est `on
-- delete cascade` -- supprimer son personnage fait perdre silencieusement
-- la note de groupe associée, sans avertissement. Remplacée ici par `on
-- delete set null`, même pattern que group_members.character_id
-- (20261016090000_group_members_orphan_character.sql) : character_id
-- devenant purement informatif depuis cette migration, il n'y a plus
-- aucune raison de perdre la note elle-même quand le personnage disparaît
-- -- c'est même le cas d'usage central de F02(a) (un MJ sans personnage,
-- y compris un MJ qui vient DE PERDRE son personnage, doit pouvoir garder
-- ses notes).
--
-- Cas limite signalé par qa-testeur (docs/retours-utilisateurs.md, avis F02) :
-- un membre orphelin RÉASSIGNÉ (personnage supprimé puis remplacé via
-- l'edge function set-group-character) garde le même user_id mais change
-- de character_id. Avec l'ANCIENNE PK (group_id, character_id), si ce
-- membre avait déjà écrit une note avec son premier personnage, puis une
-- seconde note après réassignation (sous le nouveau character_id), les
-- deux lignes coexisteraient aujourd'hui sans jamais se télescoper (PK
-- différente) -- la NOUVELLE PK (group_id, user_id) entrerait, elle, en
-- conflit avec ces deux lignes. Règle de fusion retenue : garder la ligne
-- la plus RÉCENTE par `updated_at` (la note la plus à jour l'emporte --
-- cohérent avec le comportement d'un upsert normal, qui écrase l'ancienne
-- note d'un même auteur plutôt que de les concaténer) et supprimer les
-- autres lignes du même (group_id, user_id) ; `ctid` sert de tie-break
-- déterministe en cas d'égalité exacte d'horodatage.
--
-- Vérification faite avant d'écrire ce backfill : avec l'ancienne PK
-- (group_id, character_id), produire deux lignes pour le même (group_id,
-- user_id) nécessite deux character_id DIFFÉRENTS pour le même user_id
-- dans le même groupe -- donc, en pratique, au plus une seule note par
-- (group_id, user_id) a dû être écrite à ce jour pour la quasi-totalité
-- des membres (aucun flux applicatif actuel n'encourage un joueur à
-- re-écrire une note après réassignation avant cette migration). Le
-- dédoublonnage ci-dessous est donc un garde-fou défensif qui rend
-- l'opération sûre dans tous les cas, pas la correction d'un état déjà
-- observé en base.
with ranked as (
  select
    ctid,
    row_number() over (
      partition by group_id, user_id
      order by updated_at desc, ctid desc
    ) as rn
  from public.group_notes
)
delete from public.group_notes gn
using ranked
where gn.ctid = ranked.ctid
  and ranked.rn > 1;

-- 1. PK (group_id, character_id) -> (group_id, user_id).
alter table public.group_notes drop constraint if exists group_notes_pkey;
alter table public.group_notes add primary key (group_id, user_id);

-- 2. character_id devient nullable (plus de contrainte NOT NULL
--    empêchant un MJ sans personnage d'écrire une note).
alter table public.group_notes alter column character_id drop not null;

-- 3. D170 : on delete set null plutôt que cascade.
alter table public.group_notes drop constraint if exists group_notes_character_id_fkey;
alter table public.group_notes
  add constraint group_notes_character_id_fkey
  foreign key (character_id) references public.characters (id) on delete set null;

comment on column public.group_notes.character_id is
  'Informatif uniquement depuis cette migration (F02(a)/D170) : le personnage du membre au moment de la dernière écriture de la note, pour affichage éventuel côté client. Ne sert plus de clé ni d''autorisation -- la PK et les policies RLS reposent exclusivement sur (group_id, user_id) / auth.uid() = user_id. Mis à NULL (on delete set null, jamais cascade) si le personnage est supprimé : la note elle-même doit survivre, y compris pour un MJ qui n''a jamais eu de personnage ou qui vient de perdre le sien.';

comment on table public.group_notes is
  'Carnet de notes personnel par membre de groupe (décision du 16/09/2026 : personnel, pas partagé). Depuis F02(a)/D170 (20261106090000) : clé (group_id, user_id), accessible à un MJ sans personnage, survit à la suppression du personnage du membre.';
