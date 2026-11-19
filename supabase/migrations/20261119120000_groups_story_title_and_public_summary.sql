-- Groupes : titre et résumé public de la campagne, visibles par les membres (étiquette « Campagne : … » dans Nexus).
--
-- Origine : étape 4 de FEUILLE-DE-ROUTE.md (Grimoire, branche dev/nexus-desktop), lancée par Matthias le 19/11/2026 ; option
-- « O1 + étiquette » (option C) de nexus-jdr-app-mobile/docs/api-refonte/09-base-outil-local.md §2.2 et §2.3 : le contenu des
-- campagnes reste dans Grimoire, la base ne porte qu'une étiquette copiée sur le groupe. Aucune nouvelle table, aucune RPC.
-- Décision n° 33 du 19/11/2026 (00-decisions-et-vision.md) : l'aperçu d'invitation (edge function preview-group-invite, même
-- PR) montre le TITRE, jamais le résumé.
--
-- POURQUOI
--   Les joueurs ne savent pas à quelle histoire correspond leur groupe : la campagne vit dans Grimoire (local), le groupe dans
--   DeepCore. Grimoire écrit le titre et un résumé public (choisi par le MJ, jamais ses notes) sur le groupe associé ; Nexus
--   l'affiche sur l'écran du groupe, et le titre dans l'aperçu d'invitation.
--
-- EFFET
--   1. Deux colonnes facultatives sur `groups` : `story_title text` et `story_summary_public text`, sans défaut ni NOT NULL :
--      tous les groupes existants, et ceux créés par create-group (qui n'insère que name, owner_id, invite_code), valent NULL.
--      Ajout sans réécriture de la table (colonne nullable sans défaut : modification du catalogue seulement).
--      `story_title` n'a AUCUN lien avec `groups.campaign_id` (colonne dépréciée, jamais exploitée, clé vers les « histoires »
--      de l'ancienne app web) : celle-ci n'est ni lue ni écrite ici.
--   2. Quatre contraintes CHECK, ajoutées NOT VALID puis validées par des instructions distinctes. Ici, sans gain : les
--      colonnes sont neuves, toutes à NULL, la validation ne peut pas échouer ; ce patron est gardé pour rester identique aux
--      autres migrations (garde-fou n° 2 du 14/11/2026). Il ne pourrait échouer que si ces colonnes existaient déjà en
--      production avec des valeurs hors règle (dérive), et alors RIEN n'est appliqué.
--        groups_story_title_not_blank            story_title ~ '[^<blancs>]'          (au moins un caractère non blanc)
--        groups_story_title_max_length           char_length(story_title) <= 200
--        groups_story_summary_public_not_blank   story_summary_public ~ '[^<blancs>]'
--        groups_story_summary_public_max_length  char_length(story_summary_public) <= 500
--      <blancs> : classe EXPLICITE (v_blank plus bas), indépendante de la locale de la base. `\S` ne l'est pas : sous libc
--      (en_US.utf8, C.utf8), U+00A0, U+2007 et U+202F (espace fine insécable, courante en typographie française) n'y sont pas
--      des blancs, et U+200B n'en est un sous aucune locale (vérifié sous C, C.utf8, en_US.utf8 et ICU).
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
--   - Chaîne vide ou faite seulement de blancs : REFUSÉE (23514), pas convertie en NULL. Blancs : tabulation, saut de ligne,
--     tabulation verticale, saut de page, retour chariot, espace, U+0085, U+00A0 (insécable), U+1680, U+2000 à U+200A
--     (espaces typographiques, dont U+2007), U+200B (sans chasse), U+2028, U+2029, U+202F (fine insécable), U+205F,
--     U+2060, U+3000, U+FEFF. Pour rogner côté client, utiliser la même liste (`String.prototype.trim` ne retire ni U+200B,
--     ni U+2060 ; `String.trim` de Dart non plus).
--     Pas de trigger de normalisation : il s'exécuterait à chaque UPDATE de `groups` (renommage, nouveau code de Nexus) et
--     réécrirait en silence une valeur que Grimoire croit avoir écrite (sa relecture « changement appliqué ? » échouerait).
--     Les blancs en début et en fin sont acceptés tels quels : le client rogne avant d'envoyer.
--   - Écriture : `update` sur `groups` (PostgREST : `.from('groups').update({ story_title, story_summary_public }).eq('id', …)`),
--     par le propriétaire seulement. Une écriture refusée par la RLS ne lève AUCUNE erreur (0 ligne modifiée) : relire la ligne
--     pour confirmer (Grimoire le fait déjà, `#expectApplied`). Hors règle : HTTP 400, code `23514`, message
--     « new row for relation "groups" violates check constraint "<nom de la contrainte>" ».
--   - Migration absente : PostgREST répond `PGRST204` à un update qui cite ces colonnes, `42703` à un select qui les cite.
--   - Lecture : `select` explicite (`id, name, owner_id, invite_code, story_title, story_summary_public`).
--   - Aperçu d'invitation (preview-group-invite, décision n° 33) : `200 { name, member_count, story_title }`, `story_title`
--     à null sans campagne ; jamais `story_summary_public`. À déployer APRÈS cette migration (sinon 500 pour tout le monde).
--   - Temps réel : `groups` n'est PAS dans la publication supabase_realtime (seules characters, combats, combat_participants et
--     group_members y sont) : un changement de titre n'est pas poussé, Nexus le relit à l'ouverture de l'écran du groupe.
--
-- DROITS (aucune politique ni aucun privilège modifiés ; les colonnes héritent des règles de la ligne `groups`)
--   - Lecture : propriétaire (« Owner can select their groups ») et membres (« Member can select their groups »,
--     is_group_member) ; un non-membre et `anon` ne voient aucune ligne. Exception voulue (décision n° 33) : le TITRE est
--     montré par preview-group-invite (service_role) à tout compte connecté qui a le code d'invitation.
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
--     invite_code`) et updates partiels (`name`, `invite_code`) ; l'aperçu n'est lu que par clés (`name`, `member_count`),
--     un champ de plus est ignoré.
--   - Grimoire : selects explicites (`server/nexus/groups.ts`), updates partiels.
--   - Edge functions : create-group (insert de 3 colonnes, `select("id, name, invite_code")`), join-group
--     (`select("id, name, owner_id")` via findJoinableGroup, inchangé : un déploiement de join-group ne dépend pas de cette
--     migration), set-group-character (ne lit que group_members et characters), delete-account (cascade depuis auth.users,
--     inchangée). Seule preview-group-invite lit `story_title` (findGroupPreviewByInviteCode).
--   - App web (apps/web) : ne lit pas `groups`.
--
-- RETOUR ARRIÈRE (supprimer une colonne supprime ses contraintes)
--   Tant qu'aucune version de Nexus ni de Grimoire ne lit ou n'écrit ces colonnes (perte des titres déjà écrits : Grimoire
--   les réécrit à la prochaine association ou modification) :
--   1. D'ABORD, si preview-group-invite a été déployée avec cette PR : redéployer sa version précédente (sinon elle lirait
--      une colonne absente et l'aperçu échouerait pour tout le monde) :
--        git switch --detach <commit de merge de cette PR>^1
--        npx supabase functions deploy preview-group-invite
--        git switch main
--   2. Puis, dans UNE transaction (connexion directe ou pooler en mode session) :
--        begin;
--        set local lock_timeout = '5s';
--        alter table public.groups drop column if exists story_summary_public;
--        alter table public.groups drop column if exists story_title;
--        commit;
--   3. Puis marquer la migration comme annulée dans l'historique distant :
--        npx supabase migration repair --status reverted 20261119120000
--   Après la sortie d'une version de Nexus ou de Grimoire qui les cite : NE PAS supprimer les colonnes (son select échouerait,
--   42703, et l'écran du groupe avec) ; ne retirer que les contraintes si elles posent problème.
--
-- VERROUS : ALTER TABLE prend ACCESS EXCLUSIVE sur `groups` jusqu'au commit : quelques millisecondes une fois obtenu
-- (catalogue, puis parcours d'une petite table pour la validation). Pendant l'ATTENTE de ce verrou (transaction longue en
-- cours sur `groups`), tout nouvel accès à `groups` se met en file derrière lui : lectures et écritures des groupes, mais aussi
-- les SELECT sur `combats` et `combat_participants` qui passent par is_group_owner (politiques « Member or owner can select
-- … »), y compris l'autorisation temps réel des combats, et la policy « Owner can remove a member ». D'où `lock_timeout` =
-- 5 s (et non 10 s comme 20261119090000) : au pire 5 s de file, puis échec propre, RIEN d'appliqué, à relancer plus tard.
-- Appliquer hors partie en cours, sans transaction longue (pg_stat_activity).
-- Idempotent : rejouable sans effet (colonnes et contraintes déjà présentes et identiques conservées, validation sans effet) ;
-- une colonne ou une contrainte du même nom mais d'une autre définition fait échouer la migration sans rien appliquer.

set local lock_timeout = '5s';

do $lt$
begin
  raise notice 'lock_timeout=%', current_setting('lock_timeout');
  if current_setting('lock_timeout') <> '5s' then
    raise exception 'lock_timeout=% (attendu 5s) : cette migration doit s''exécuter dans UNE transaction (connexion directe ou pooler en mode session ; jamais l''éditeur du tableau de bord sans avoir vu ce NOTICE, ni le pooler en mode transaction)', current_setting('lock_timeout');
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
  'Titre de la campagne associée (copié par Grimoire), lisible par les membres du groupe, modifiable par le propriétaire seulement (policy « Owner can update their groups ») ; montré aussi par l''aperçu d''invitation (preview-group-invite, décision n° 33). NULL = aucune campagne. 1 à 200 caractères (char_length), jamais vide ni fait seulement de blancs (23514). Aucun lien avec campaign_id (dépréciée). Voir 20261119120000.';
comment on column public.groups.story_summary_public is
  'Résumé public de la campagne, choisi par le MJ dans Grimoire (jamais ses notes), lisible par les membres du groupe seulement (jamais par l''aperçu d''invitation), modifiable par le propriétaire seulement. NULL = aucun résumé. 1 à 500 caractères (char_length), jamais vide ni fait seulement de blancs (23514). Voir 20261119120000.';

-- 2. Contraintes : NOT VALID, puis validation par des instructions distinctes ----------------------------------------------
-- Définition attendue obtenue en posant les mêmes contraintes sur une table temporaire de même forme : pg_get_constraintdef
-- des deux côtés, donc comparaison exacte quelles que soient la version de PostgreSQL et la mise en forme.
do $checks$
declare
  -- Classe des blancs, écrite en échappements de l'analyseur d'expressions rationnelles (chaîne entre dollars : aucun
  -- traitement des « \ » par l'analyseur SQL, quel que soit standard_conforming_strings). Indépendante de la locale.
  v_blank constant text := $re$[^\t\n\v\f\r \u0085\u00a0\u1680\u2000-\u200b\u2028\u2029\u202f\u205f\u2060\u3000\ufeff]$re$;
  v_checks text[][];
  v_i int;
  v_def text;
  v_expected text;
  v_bad text := '';
  v_added int := 0;
begin
  v_checks := array[
    array['groups_story_title_not_blank', format('story_title ~ %L', v_blank)],
    array['groups_story_title_max_length', 'char_length(story_title) <= 200'],
    array['groups_story_summary_public_not_blank', format('story_summary_public ~ %L', v_blank)],
    array['groups_story_summary_public_max_length', 'char_length(story_summary_public) <= 500']
  ];

  if to_regclass('pg_temp.groups_story_expected') is not null then
    drop table pg_temp.groups_story_expected;
  end if;
  create temp table groups_story_expected (story_title text, story_summary_public text) on commit drop;
  for v_i in 1 .. array_length(v_checks, 1) loop
    execute format('alter table pg_temp.groups_story_expected add constraint %I check (%s)', v_checks[v_i][1], v_checks[v_i][2]);
  end loop;

  -- Passe 1 : contraintes déjà présentes sous le même nom, identiques (conservées) ou différentes (exception).
  for v_i in 1 .. array_length(v_checks, 1) loop
    select regexp_replace(pg_get_constraintdef(c.oid), E'\\s+NOT VALID$', '') into v_def
      from pg_constraint c
     where c.conrelid = 'public.groups'::regclass
       and c.conname = v_checks[v_i][1];
    continue when not found;
    select pg_get_constraintdef(c.oid) into v_expected
      from pg_constraint c
     where c.conrelid = 'pg_temp.groups_story_expected'::regclass
       and c.conname = v_checks[v_i][1];
    if v_def is distinct from v_expected then
      v_bad := v_bad || format(E'\n  - %s : %s (attendu : %s)', v_checks[v_i][1], v_def, v_expected);
    else
      raise notice 'groups.story_* : % déjà présente et identique, conservée', v_checks[v_i][1];
    end if;
  end loop;
  if v_bad <> '' then
    raise exception 'groups.story_* : contrainte(s) déjà présente(s) avec une autre définition, RIEN n''est appliqué :%', v_bad;
  end if;

  -- Passe 2 : ajout en NOT VALID de celles qui manquent.
  for v_i in 1 .. array_length(v_checks, 1) loop
    continue when exists (select 1 from pg_constraint c
                           where c.conrelid = 'public.groups'::regclass and c.conname = v_checks[v_i][1]);
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
