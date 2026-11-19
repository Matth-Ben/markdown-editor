-- Groupes : titre et résumé public de la campagne, visibles par les membres (étiquette « Campagne : … » dans Nexus).
--
-- Origine : étape 4 de FEUILLE-DE-ROUTE.md (Grimoire, branche dev/nexus-desktop), lancée par Matthias le 19/11/2026 ; option
-- « O1 + étiquette » (option C) de nexus-jdr-app-mobile/docs/api-refonte/09-base-outil-local.md §2.2 et §2.3 : le contenu des
-- campagnes reste dans Grimoire, la base ne porte qu'une étiquette copiée sur le groupe. Aucune nouvelle table, aucune RPC.
--
-- POURQUOI
--   Les joueurs ne savent pas à quelle histoire correspond leur groupe : la campagne vit dans Grimoire (local), le groupe dans
--   DeepCore. Grimoire écrit le titre et un résumé public (choisi par le MJ, jamais ses notes) sur le groupe associé ; Nexus
--   l'affiche sur l'écran du groupe.
--
-- EFFET
--   1. Deux colonnes facultatives sur `groups` : `story_title text` et `story_summary_public text`, sans défaut ni NOT NULL :
--      tous les groupes existants, et ceux créés par create-group (qui n'insère que name, owner_id, invite_code), valent NULL.
--      Ajout sans réécriture de la table (colonne nullable sans défaut : modification du catalogue seulement).
--   2. Quatre contraintes CHECK, ajoutées NOT VALID puis validées par une instruction distincte (garde-fou n° 2 du 14/11/2026).
--      La validation parcourt `groups` (petite table) : toutes les valeurs sont NULL, elle ne peut échouer que si ces colonnes
--      existaient déjà en production avec des valeurs hors règle (dérive), et alors RIEN n'est appliqué. Une validation différée
--      dans un fichier séparé (comme 20261115094000) n'apporterait rien ici : aucune ligne existante ne peut violer la règle.
--        groups_story_title_not_blank            story_title ~ '\S'                       (au moins un caractère non blanc)
--        groups_story_title_max_length           char_length(story_title) <= 200
--        groups_story_summary_public_not_blank   story_summary_public ~ '\S'
--        groups_story_summary_public_max_length  char_length(story_summary_public) <= 500
--
-- CONTRAT (Grimoire écrit, Nexus lit)
--   - NULL = pas de campagne associée (ou pas de résumé). Effacer = écrire NULL (les deux colonnes à la dissociation).
--   - Longueur en caractères Unicode (points de code, `char_length`) : ni en octets, ni en unités UTF-16. JavaScript :
--     `[...texte].length` (pas `texte.length`) ; Dart : `texte.runes.length` (pas `texte.length`).
--   - Titre : 1 à 200 caractères, même plafond que le titre d'une campagne de Grimoire (shared/schema.ts, `title()` : rogné,
--     1 à 200) : la colonne en est une copie, un plafond plus bas obligerait Grimoire à tronquer. L'affichage court
--     (« Campagne : … » sur une ou deux lignes, points de suspension) est l'affaire de Nexus.
--   - Résumé public : 1 à 500 caractères (environ 80 mots, 4 à 8 lignes sur un téléphone) : une accroche, distincte de la
--     description de la campagne dans Grimoire (jusqu'à 50 000 caractères) et des notes du MJ ; le plafond empêche d'y copier
--     par erreur la description entière. Retours à la ligne admis.
--   - Chaîne vide ou seulement blanche (espaces, tabulations, retours à la ligne) : REFUSÉE (23514), pas convertie en NULL.
--     Pas de trigger de normalisation : il s'exécuterait à chaque UPDATE de `groups` (renommage, nouveau code de Nexus) et
--     réécrirait en silence une valeur que Grimoire croit avoir écrite (sa relecture « changement appliqué ? » échouerait).
--     Les espaces en début et en fin sont acceptés tels quels : le client rogne avant d'envoyer.
--   - Écriture : `update` sur `groups` (PostgREST : `.from('groups').update({ story_title, story_summary_public }).eq('id', …)`),
--     par le propriétaire seulement. Une écriture refusée par la RLS ne lève AUCUNE erreur (0 ligne modifiée) : relire la ligne
--     pour confirmer (Grimoire le fait déjà, `#expectApplied`). Hors règle : HTTP 400, code `23514`, message
--     « new row for relation "groups" violates check constraint "<nom de la contrainte>" ».
--   - Migration absente : PostgREST répond `PGRST204` à un update qui cite ces colonnes, `42703` à un select qui les cite.
--   - Lecture : `select` explicite (`id, name, owner_id, invite_code, story_title, story_summary_public`).
--   - Temps réel : `groups` n'est PAS dans la publication supabase_realtime (seules characters, combats, combat_participants et
--     group_members y sont) : un changement de titre n'est pas poussé, Nexus le relit à l'ouverture de l'écran du groupe.
--
-- DROITS (aucune politique ni aucun privilège modifiés ; les colonnes héritent des règles de la ligne `groups`)
--   - Lecture : propriétaire (« Owner can select their groups ») et membres (« Member can select their groups »,
--     is_group_member) ; un non-membre et `anon` ne voient aucune ligne.
--   - Écriture : « Owner can update their groups » (owner_id = auth.uid(), USING et WITH CHECK). Un membre, le MJ non
--     propriétaire, un tiers : 0 ligne. Le propriétaire qui a quitté son groupe (sans ligne group_members) peut encore écrire,
--     comme pour `name` et `invite_code` (règle inchangée).
--   - Insertion : aucune politique INSERT pour authenticated (création par create-group, service_role, sans ces colonnes).
--   - `anon` et `authenticated` ont aujourd'hui TOUS les privilèges de table sur `groups` (privilèges par défaut du projet,
--     dette D229 du dépôt mobile) : seule la RLS protège, testé ici. Des privilèges par colonne seraient sans effet tant que
--     l'UPDATE de table est accordé. Si D229 passe un jour `groups` en privilèges par colonne, y inclure ces deux colonnes.
--   - Aucune fonction security definer n'écrit `groups` ; aucun trigger UPDATE sur `groups` ; aucune vue ne dépend de
--     `groups` ; aucune fonction ne renvoie le type ligne `groups` (relevé sur le schéma rejoué).
--
-- SANS EFFET SUR (vérifié dans le code)
--   - Nexus publié : selects explicites (`group_repository.dart` : `groups(id, name, owner_id)`, `id, name, owner_id,
--     invite_code`) et updates partiels (`name`, `invite_code`).
--   - Grimoire : selects explicites (`server/nexus/groups.ts`), updates partiels.
--   - Edge functions : create-group (insert de 3 colonnes, `select("id, name, invite_code")`), join-group et
--     preview-group-invite (`select("id, name, owner_id")` via findJoinableGroup), set-group-character (ne lit que
--     group_members et characters), delete-account (cascade depuis auth.users, inchangée). L'aperçu d'invitation n'expose PAS
--     le titre à un non-membre (question ouverte, voir la PR).
--   - App web (apps/web) : ne lit pas `groups`.
--
-- RETOUR ARRIÈRE
--   Tant qu'aucune version de Nexus ni de Grimoire ne lit ou n'écrit ces colonnes (perte des titres déjà écrits : Grimoire
--   les réécrit à la prochaine association ou modification) :
--     alter table public.groups drop constraint if exists groups_story_summary_public_max_length;
--     alter table public.groups drop constraint if exists groups_story_summary_public_not_blank;
--     alter table public.groups drop constraint if exists groups_story_title_max_length;
--     alter table public.groups drop constraint if exists groups_story_title_not_blank;
--     alter table public.groups drop column if exists story_summary_public;
--     alter table public.groups drop column if exists story_title;
--   Après la sortie d'une version qui les cite : NE PAS supprimer les colonnes (son select échouerait, 42703, et l'écran du
--   groupe avec) ; ne retirer que les contraintes si elles posent problème.
--
-- VERROUS : ALTER TABLE prend ACCESS EXCLUSIVE sur `groups` jusqu'au commit (lectures et écritures du groupe en attente) :
-- quelques millisecondes (catalogue, puis parcours d'une petite table pour la validation). `lock_timeout` = 10 s : échec
-- propre, rien d'appliqué, plutôt qu'une file. Appliquer hors partie en cours, sans transaction longue (pg_stat_activity).
-- Idempotent : rejouable sans effet (colonnes et contraintes déjà présentes conservées, validation sans effet).

set local lock_timeout = '10s';

do $lt$
begin
  raise notice 'lock_timeout=%', current_setting('lock_timeout');
  if current_setting('lock_timeout') <> '10s' then
    raise exception 'lock_timeout=% (attendu 10s) : cette migration doit s''exécuter dans UNE transaction (connexion directe ou pooler en mode session ; jamais l''éditeur du tableau de bord sans avoir vu ce NOTICE, ni le pooler en mode transaction)', current_setting('lock_timeout');
  end if;
end
$lt$;

-- 1. Colonnes ---------------------------------------------------------------------------------------------------------------
alter table public.groups
  add column if not exists story_title text,
  add column if not exists story_summary_public text;

-- Garde-fou de dérive : si ces colonnes existaient déjà (ajout hors migrations), elles doivent être exactement `text`,
-- nullables et sans défaut ; sinon rien n'est appliqué.
do $drift$
declare
  r record;
  v_bad text := '';
begin
  for r in
    select a.attname::text as col, format_type(a.atttypid, a.atttypmod) as typ, a.attnotnull, a.atthasdef
      from pg_attribute a
     where a.attrelid = 'public.groups'::regclass
       and a.attname in ('story_title', 'story_summary_public')
       and a.attnum > 0
       and not a.attisdropped
  loop
    if r.typ <> 'text' or r.attnotnull or r.atthasdef then
      v_bad := v_bad || format(E'\n  - %s : %s%s%s', r.col, r.typ,
                               case when r.attnotnull then ', NOT NULL' else '' end,
                               case when r.atthasdef then ', avec valeur par défaut' else '' end);
    end if;
  end loop;
  if v_bad <> '' then
    raise exception 'groups.story_* : colonne(s) déjà présente(s) avec une autre définition (attendu : text nullable sans défaut), RIEN n''est appliqué :%', v_bad;
  end if;
end
$drift$;

comment on column public.groups.story_title is
  'Titre de la campagne associée (copié par Grimoire), lisible par les membres du groupe, modifiable par le propriétaire seulement (policy « Owner can update their groups »). NULL = aucune campagne. 1 à 200 caractères (char_length), jamais vide ni seulement blanc (23514). Voir 20261119120000.';
comment on column public.groups.story_summary_public is
  'Résumé public de la campagne, choisi par le MJ dans Grimoire (jamais ses notes), lisible par les membres du groupe, modifiable par le propriétaire seulement. NULL = aucun résumé. 1 à 500 caractères (char_length), jamais vide ni seulement blanc (23514). Voir 20261119120000.';

-- 2. Contraintes : NOT VALID, puis validation par des instructions distinctes ----------------------------------------------
do $checks$
declare
  -- (nom de contrainte, expression)
  v_checks constant text[][] := array[
    array['groups_story_title_not_blank', 'story_title ~ ''\S'''],
    array['groups_story_title_max_length', 'char_length(story_title) <= 200'],
    array['groups_story_summary_public_not_blank', 'story_summary_public ~ ''\S'''],
    array['groups_story_summary_public_max_length', 'char_length(story_summary_public) <= 500']
  ];
  v_i int;
  v_def text;
  v_added int := 0;
begin
  for v_i in 1 .. array_length(v_checks, 1) loop
    select pg_get_constraintdef(c.oid) into v_def
      from pg_constraint c
     where c.conrelid = 'public.groups'::regclass
       and c.conname = v_checks[v_i][1];
    if found then
      raise notice 'groups.story_* : % déjà présente (%), conservée', v_checks[v_i][1], v_def;
      continue;
    end if;
    execute format('alter table public.groups add constraint %I check (%s) not valid', v_checks[v_i][1], v_checks[v_i][2]);
    v_added := v_added + 1;
  end loop;
  raise notice 'groups.story_* : % contrainte(s) ajoutée(s) NOT VALID (4 attendues au premier passage, 0 au rejeu)', v_added;
end
$checks$;

alter table public.groups validate constraint groups_story_title_not_blank;
alter table public.groups validate constraint groups_story_title_max_length;
alter table public.groups validate constraint groups_story_summary_public_not_blank;
alter table public.groups validate constraint groups_story_summary_public_max_length;
