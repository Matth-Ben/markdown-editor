-- Contrat de lecture pour Grimoire : schéma `api_v1`, `api_v1.my_gm_groups()` et `api_v1.group_snapshot(uuid, text)`.
--
-- Origine : étape 5 de FEUILLE-DE-ROUTE.md (Grimoire, branche dev/nexus-desktop), lancée par Matthias le 20/11/2026 ; phase 1a
-- de nexus-jdr-app-mobile/docs/api-refonte/09-base-outil-local.md (§2.4, §2.7, §5 étape 2) ; décisions D3 (contrat de lecture
-- d'abord), D4 (CA en SQL, 20261120090000), D9 (groupes dont le compte est propriétaire), D14 (schéma `api_v1`) ; décisions
-- n° 10, 11, 21 et 37 de 00-decisions-et-vision.md. Contrat complet : docs/api-v1/contrat-lecture-grimoire.md.
--
-- POURQUOI
--   Grimoire doit afficher, pour une histoire associée à un groupe, les joueurs et l'état de leurs personnages, y compris hors
--   ligne. Aujourd'hui il faudrait 6 requêtes et ~70 Ko par groupe (ce que fait Nexus, group_repository.dart), recopier le
--   calcul de la CA, et un propriétaire SANS ligne group_members (3 groupes sur 4 en production au 20/11/2026) ne lit ni les
--   membres ni les fiches (RLS : is_group_member, group_member_can_read_character).
--
-- EFFET
--   1. Schéma `api_v1` (premier schéma d'API versionné) : USAGE à `authenticated` seulement, jamais à `anon` ni PUBLIC.
--      Il doit être ajouté aux « Exposed schemas » (tableau de bord > Settings > API) APRÈS cette migration : réglage manuel
--      de Matthias (supabase/config.toml le fait pour la pile locale).
--   2. `api_v1.my_gm_groups()` : les groupes dont l'appelant est PROPRIÉTAIRE (avec ou sans ligne de membre), avec compteurs
--      et indicateurs « MJ » (liste « Associer un groupe existant » et proposition « Devenir MJ » de Grimoire).
--   3. `api_v1.group_snapshot(p_group_id, p_known_fingerprint)` : instantané d'un groupe en un appel (groupe, membres, résumé
--      de chaque personnage avec CA calculée), avec empreinte ; réservé au PROPRIÉTAIRE, avec ou sans ligne de membre.
--
-- DROITS (matrice testée dans supabase/tests/api_v1_read_contract_test.sql)
--                                         my_gm_groups()                    group_snapshot(g)
--   anonyme                               refusé (pas d'USAGE sur api_v1)   refusé (pas d'USAGE sur api_v1)
--   connecté, sans session utilisateur    not_authenticated (28000)         not_authenticated (28000)
--   propriétaire avec ligne (MJ ou PJ)    ses groupes                       servi
--   propriétaire SANS ligne (parti)       ses groupes                       servi (ÉLARGISSEMENT, voir ci-dessous)
--   membre non propriétaire               (pas dans sa liste)               not_group_owner (42501)
--   tiers / groupe inconnu / NULL         (rien)                            group_not_found (P0002), existence non révélée
--   ÉLARGISSEMENT ASSUMÉ ET DOCUMENTÉ (demande du chef de projet du 20/11/2026, décision D9 « propriétaire, avec ou sans ligne
--   MJ ») : la RLS actuelle ne donne au propriétaire SANS ligne ni les lignes group_members ni les fiches de ses membres.
--   group_snapshot les lui sert (security definer), réduites au résumé du contrat. Aucune politique RLS ni aucun privilège de
--   table n'est modifié : les lectures directes restent exactement celles d'avant. Il garde par ailleurs tous les droits de
--   gestion (renommer, exclure, dissoudre : « Owner can … », create_groups.sql) et lit déjà les combats du groupe
--   (is_group_owner). Un membre non propriétaire est refusé : D9, Grimoire n'affiche que les groupes du propriétaire ;
--   l'ouvrir aux membres (réutilisation par Nexus, 09 §2.7) serait additif, à décider plus tard.
--
-- MINIMISATION (le contrat est fermé : toute clé hors liste est un changement de contrat)
--   Jamais : code d'invitation, histoire personnelle, traits, notes, inventaire, monnaie, trésor, carnet ou journal du groupe,
--   e-mail, date d'adhésion, updated_at. Le code d'invitation n'est PAS servi alors que 09 §2.4 le proposait : Grimoire le lit
--   déjà par un select direct permis au propriétaire (server/nexus/groups.ts), l'instantané est mis en cache sur la machine
--   du MJ et pourra être réutilisé par Nexus pour des membres, et la rotation du code ne doit pas invalider l'empreinte.
--   Ajout additif possible plus tard (nouvelle clé), jamais de retrait sans `api_v2`.
--
-- EMPREINTE
--   'v1:' || sha256 hexadécimal du texte jsonb du contenu ({group, members}). jsonb trie les clés ; chaque tableau est trié
--   explicitement (membres : propriétaire d'abord, puis date d'adhésion, puis id ; classes : principale d'abord, puis niveau
--   décroissant, puis class_id, puis id ; états : ordre alphabétique, sans doublon) : même contenu, même empreinte, quel que
--   soit l'ordre physique des lignes. Seul le contenu du contrat compte (un changement d'histoire personnelle, de code
--   d'invitation ou d'updated_at ne la change pas ; un changement de PV, d'équipement qui modifie la CA, de pseudo, oui).
--   p_known_fingerprint égal à l'empreinte courante -> {"v":1,"unchanged":true,"fingerprint":…} sans le contenu.
--
-- TEMPS RÉEL (rien d'ajouté) : le propriétaire SANS ligne ne reçoit AUCUN événement postgres_changes sur characters ni
-- group_members (la RLS filtre chaque événement) : Grimoire relit l'instantané périodiquement pour ces groupes (l'empreinte rend
-- la relecture presque gratuite). Avec une ligne, les événements arrivent comme pour Nexus ; les tables filles
-- (character_inventory, character_classes…) ne sont pas publiées (09 §2.6).
--
-- SANS EFFET SUR (vérifié dans le code) : Nexus publié (n'appelle pas api_v1), Grimoire (lectures directes inchangées),
-- l'app web, les edge functions ; aucune table, politique, vue, publication ni privilège existant modifié.
--
-- RETOUR ARRIÈRE (aucune donnée en jeu)
--   1. D'ABORD retirer `api_v1` des « Exposed schemas » (tableau de bord > Settings > API), sinon PostgREST référence un schéma
--      absent.
--   2. Puis, dans UNE transaction :
--        begin;
--        drop function if exists api_v1.group_snapshot(uuid, text);
--        drop function if exists api_v1.my_gm_groups();
--        drop schema if exists api_v1;   -- sans CASCADE : échoue si un autre objet y a été ajouté depuis
--        commit;
--   3. npx supabase migration repair --status reverted 20261120091000
--   (puis, si voulu, le retour arrière de 20261120090000.)
--   Après la sortie d'une version de Grimoire qui appelle ces fonctions : ne pas les supprimer (son écran Groupe tomberait en
--   erreur) ; corriger par une nouvelle migration.
--
-- VERROUS : création d'un schéma et de fonctions, aucun verrou de table.

set local lock_timeout = '5s';

do $lt$
begin
  raise notice 'lock_timeout=%', current_setting('lock_timeout');
  if current_setting('lock_timeout') <> '5s' then
    raise exception 'lock_timeout=% (attendu 5s) : cette migration doit s''exécuter dans UNE transaction (connexion directe ou pooler en mode session ; jamais l''éditeur du tableau de bord sans avoir vu ce NOTICE, ni le pooler en mode transaction)', current_setting('lock_timeout');
  end if;
end
$lt$;

-- Prérequis : la fonction de CA (20261120090000) doit exister.
do $pre$
begin
  if to_regprocedure('private.character_armor_class(uuid)') is null then
    raise exception 'private.character_armor_class(uuid) absente : appliquer 20261120090000 d''abord';
  end if;
end
$pre$;

-- 1. Schéma ---------------------------------------------------------------------------------------------------------------------
create schema if not exists api_v1;

-- Garde-fou de dérive : un schéma api_v1 préexistant (créé hors migrations) doit appartenir au rôle qui applique la migration.
do $drift$
begin
  if (select n.nspowner from pg_namespace n where n.nspname = 'api_v1') is distinct from (select oid from pg_roles where rolname = current_user) then
    raise exception 'api_v1 existe déjà avec un autre propriétaire : rien n''est appliqué, vérifier l''état de la base';
  end if;
end
$drift$;

comment on schema api_v1 is
  'API versionnée de DeepCore (v1), commune à Nexus et Grimoire. Fonctions security definer seulement, USAGE à authenticated seulement (jamais anon). Contrat : docs/api-v1/ du dépôt DeepCore. À ajouter aux « Exposed schemas » de l''API. Voir 20261120091000.';

revoke all on schema api_v1 from public;
revoke all on schema api_v1 from anon;
grant usage on schema api_v1 to authenticated;
-- Pas d'`alter default privileges ... in schema api_v1 revoke execute on functions from public` : un REVOKE par schéma ne
-- retire pas un privilège accordé globalement, et l'EXECUTE de PUBLIC sur les fonctions est le défaut intégré de Postgres
-- (vérifié sur la pile locale : aucune entrée pg_default_acl créée, une nouvelle fonction reste exécutable par anon et
-- PUBLIC). La version globale (sans IN SCHEMA) toucherait toutes les fonctions futures de tous les schémas : hors périmètre.
-- Protections réelles : aucun USAGE pour anon ni PUBLIC sur le schéma, REVOKE explicite à chaque fonction, et un test pgTAP
-- (api_v1_read_contract_test.sql) qui échoue si UNE fonction de api_v1 est exécutable par PUBLIC ou anon.

-- 2. my_gm_groups ---------------------------------------------------------------------------------------------------------------
-- Une ligne par groupe dont auth.uid() est groups.owner_id, triée par nom puis id.
--   member_count           toutes les lignes group_members (MJ, joueurs, orphelins), comme preview-group-invite
--   dead_count             personnages is_dead
--   low_hp_count           personnages vivants, max_hp > 0 et 0 < current_hp <= 25 % de max_hp (même seuil que la vue
--                          group_character_status_overview, 20261106100000)
--   has_game_master        public.group_has_gm : la ligne du propriétaire est MJ (condition du combat dans l'app)
--   owner_has_member_row   le propriétaire a une ligne group_members (sinon « Devenir MJ » répond not_member)
--   owner_plays_character  la ligne du propriétaire porte un personnage (« Devenir MJ » le retirera du groupe)
-- Erreur : not_authenticated (28000).
create or replace function api_v1.my_gm_groups()
returns table (
  id uuid,
  name text,
  story_title text,
  member_count integer,
  dead_count integer,
  low_hp_count integer,
  has_game_master boolean,
  owner_has_member_row boolean,
  owner_plays_character boolean
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  return query
  select
    g.id,
    g.name,
    g.story_title,
    st.member_count::integer,
    st.dead_count::integer,
    st.low_hp_count::integer,
    public.group_has_gm(g.id),
    om.id is not null,
    om.character_id is not null
    from public.groups g
    left join public.group_members om
      on om.group_id = g.id and om.user_id = g.owner_id
    cross join lateral (
      select
        count(*) as member_count,
        count(*) filter (where c.is_dead) as dead_count,
        count(*) filter (
          where c.id is not null
            and not c.is_dead
            and c.max_hp > 0
            and c.current_hp > 0
            and c.current_hp <= c.max_hp * 0.25
        ) as low_hp_count
        from public.group_members m
        left join public.characters c on c.id = m.character_id
       where m.group_id = g.id
    ) st
   where g.owner_id = v_uid
   order by g.name, g.id;
end;
$$;

comment on function api_v1.my_gm_groups() is
  'Groupes dont l''appelant est propriétaire (avec ou sans ligne de membre) : id, name, story_title, member_count, dead_count, low_hp_count (vivant, max_hp > 0, 0 < PV <= 25 %), has_game_master (group_has_gm), owner_has_member_row, owner_plays_character. Erreur : not_authenticated 28000. Contrat : docs/api-v1/contrat-lecture-grimoire.md. Voir 20261120091000.';

-- 3. group_snapshot -------------------------------------------------------------------------------------------------------------
-- Erreurs (`message` = code stable, SQLSTATE entre parenthèses ; mêmes codes que become_group_game_master) :
--   not_authenticated (28000)  pas de session
--   group_not_found   (P0002)  groupe inconnu, identifiant NULL, ou appelant ni propriétaire ni membre
--   not_group_owner   (42501)  membre du groupe mais pas propriétaire
create or replace function api_v1.group_snapshot(p_group_id uuid, p_known_fingerprint text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_content jsonb;
  v_fingerprint text;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select g.owner_id into v_owner from public.groups g where g.id = p_group_id;
  if not found then
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;
  -- IS DISTINCT FROM, jamais <> : une comparaison avec NULL vaudrait NULL et sauterait le refus.
  if v_owner is distinct from v_uid then
    if public.is_group_member(p_group_id) then
      raise exception 'not_group_owner' using errcode = '42501';
    end if;
    raise exception 'group_not_found' using errcode = 'P0002';
  end if;

  select jsonb_build_object(
    'group', jsonb_build_object(
      'id', g.id,
      'name', g.name,
      'story_title', g.story_title,
      'story_summary_public', g.story_summary_public,
      'has_game_master', public.group_has_gm(g.id)
    ),
    'members', coalesce((
      select jsonb_agg(mb.member order by mb.is_owner desc, mb.joined_at, mb.id)
        from (
          select
            m.id,
            m.joined_at,
            m.user_id is not distinct from g.owner_id as is_owner,
            jsonb_build_object(
              'membership_id', m.id,
              'user_id', m.user_id,
              'display_name', public.group_members_display_name(m),
              'role', m.role,
              'is_owner', m.user_id is not distinct from g.owner_id,
              'is_game_master', m.is_game_master,
              'character', case when c.id is null then null else jsonb_build_object(
                'id', c.id,
                'name', c.name,
                'portrait_url', c.portrait_url,
                'race_name', coalesce(nullif(btrim(c.race_custom_text), ''), rt.value),
                'classes', cls.classes,
                'total_level', cls.total_level,
                'current_hp', c.current_hp,
                'max_hp', c.max_hp,
                'temporary_hp', c.temporary_hp,
                'is_dead', c.is_dead,
                'conditions', cond.conditions,
                'armor_class', ac.armor_class,
                'armor_class_bonus', ac.armor_class_bonus,
                'armor_class_total', ac.armor_class_total
              ) end
            ) as member
            from public.group_members m
            left join public.characters c on c.id = m.character_id
            left join public.translations rt
              on rt.entity_type = 'race' and rt.entity_id = c.race_id::text and rt.field_name = 'name' and rt.locale = 'fr'
            left join lateral (
              select
                coalesce(jsonb_agg(jsonb_build_object(
                  'class_id', cc.class_id,
                  'class_name', ct.value,
                  'subclass_id', cc.subclass_id,
                  'subclass_name', sct.value,
                  'level', cc.level
                ) order by cc.is_primary desc, cc.level desc, cc.class_id, cc.id), '[]'::jsonb) as classes,
                coalesce(sum(cc.level), 0)::integer as total_level
                from public.character_classes cc
                left join public.translations ct
                  on ct.entity_type = 'class' and ct.entity_id = cc.class_id::text and ct.field_name = 'name'
                 and ct.locale = 'fr'
                left join public.translations sct
                  on sct.entity_type = 'subclass' and sct.entity_id = cc.subclass_id::text and sct.field_name = 'name'
                 and sct.locale = 'fr'
               where cc.character_id = c.id
            ) cls on true
            left join lateral (
              select coalesce(jsonb_agg(x.v order by x.v), '[]'::jsonb) as conditions
                from (select distinct e.v from jsonb_array_elements(c.conditions) as e(v)) x
            ) cond on true
            left join lateral private.character_armor_class(c.id) ac on true
           where m.group_id = g.id
        ) mb
    ), '[]'::jsonb)
  )
    into v_content
    from public.groups g
   where g.id = p_group_id;

  v_fingerprint := 'v1:' || encode(sha256(convert_to(v_content::text, 'UTF8')), 'hex');

  if p_known_fingerprint is not null and p_known_fingerprint = v_fingerprint then
    return jsonb_build_object('v', 1, 'unchanged', true, 'fingerprint', v_fingerprint);
  end if;

  return jsonb_build_object('v', 1, 'unchanged', false, 'fingerprint', v_fingerprint) || v_content;
end;
$$;

comment on function api_v1.group_snapshot(uuid, text) is
  'Instantané d''un groupe pour son propriétaire (avec ou sans ligne de membre) : {v, unchanged, fingerprint, group{id, name, story_title, story_summary_public, has_game_master}, members[{membership_id, user_id, display_name, role, is_owner, is_game_master, character|null}]}, personnage résumé avec CA (private.character_armor_class). Jamais le code d''invitation ni les notes. p_known_fingerprint égal -> {v, unchanged:true, fingerprint}. Erreurs : not_authenticated 28000, group_not_found P0002, not_group_owner 42501. Contrat : docs/api-v1/contrat-lecture-grimoire.md. Voir 20261120091000.';

-- Droits ------------------------------------------------------------------------------------------------------------------------
-- Les privilèges par défaut de Postgres donnent EXECUTE à PUBLIC (donc à anon) sur toute nouvelle fonction : retrait explicite,
-- puis authenticated seulement. Sans USAGE sur api_v1, anon serait de toute façon refusé (défense en profondeur).
revoke all on function api_v1.my_gm_groups() from public, anon;
revoke all on function api_v1.group_snapshot(uuid, text) from public, anon;
grant execute on function api_v1.my_gm_groups() to authenticated;
grant execute on function api_v1.group_snapshot(uuid, text) to authenticated;
