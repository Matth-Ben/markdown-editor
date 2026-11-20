-- Classe d'armure (CA) d'un personnage calculée par DeepCore : fonction interne `private.character_armor_class(uuid)`.
--
-- Origine : étape 5 de FEUILLE-DE-ROUTE.md (Grimoire, branche dev/nexus-desktop), lancée par Matthias le 20/11/2026 ; décision
-- D4 = C2 de nexus-jdr-app-mobile/docs/api-refonte/09-base-outil-local.md §2.4 (fonction SQL, parité testée avec Nexus) ;
-- décision n° 37 du 20/11/2026 (00-decisions-et-vision.md) ; spécification de `regles-dnd` du 20/11/2026 ; écarts RAW
-- volontairement reproduits : dette D234 du dépôt mobile.
--
-- POURQUOI
--   La CA n'est stockée nulle part : Nexus la calcule en Dart (lib/features/characters/domain/armor_class_calculator.dart) à
--   partir de l'inventaire équipé, des caractéristiques, des classes, sous-classes et styles de combat. Grimoire doit afficher
--   la MÊME valeur sans recopier une troisième fois la règle : `api_v1.group_snapshot` (migration suivante, 20261120091000)
--   l'obtient de cette fonction.
--
-- RÈGLE (la fiche mobile fait foi : reproduction EXACTE du calcul Dart, écarts RAW de D234 compris)
--   Entrées
--     - Caractéristiques : character_ability_scores (dex, con, wis). Score absent = 10. Modificateur = floor((score - 10) / 2.0)
--       (division réelle puis plancher, comme le Dart ; la division entière de Postgres tronquerait vers zéro : Dex 9 -> -1).
--     - Classes et sous-classes par leur NOM FRANÇAIS (translations, field_name 'name', locale 'fr'), comparés exactement,
--       casse comprise : « Barbare », « Moine » (classes), « Lignage draconique » (sous-classe). Le niveau n'est jamais lu.
--     - Style « Défense » : `chosen_value = 'Défense'` d'une option de classe dont l'aptitude s'appelle exactement « Style de
--       combat » (pas « Style de combat supplémentaire », comme Nexus).
--     - Inventaire : lignes `equipped = true` seulement. Objet du catalogue : items.category, armor_properties (ac_base,
--       ac_dex_bonus, slot ; ac_dex_bonus absent = 'aucun'), items.requires_attunement, items.ac_bonus, items.ac_bonus_kind ;
--       bonus magique = 0. Objet personnalisé (item_id NULL) : propriétés d'armure seulement si custom_ac_base est renseigné ET
--       (custom_kind = 'bouclier' -> emplacement bouclier) OU (custom_kind = 'armure' et custom_armor_category légère,
--       intermédiaire ou lourde -> ac_dex_bonus 'illimite', 'max_2' ou 'aucun') ; sinon l'objet n'entre pas dans la CA ; bonus
--       magique = coalesce(custom_magic_bonus, 0) ; harmonisation requise = custom_requires_attunement.
--   Calcul
--     1. Emplacement = slot, à défaut items.category.
--     2. Armure = objet équipé avec propriétés d'armure et emplacement 'armure' ; bouclier = idem avec 'bouclier'.
--        Plusieurs armures ou plusieurs boucliers équipés (décision n° 37 ; 0 fiche en production au 20/11/2026) : toutes les
--        combinaisons (une armure x un bouclier) sont évaluées et la MEILLEURE CA est retenue (résultat unique, donc
--        déterministe). L'objet NON retenu ne donne rien : ni base, ni bonus magique, ni ac_bonus d'aucun type, y compris
--        'toujours' (lecture RAW confirmée par regles-dnd le 20/11/2026 : un bonus d'armure ne vaut que tant qu'on la porte,
--        et on n'en porte qu'une). Une seule armure (ou un seul bouclier) équipée : elle est toujours retenue, même si s'en
--        passer donnerait plus (ex. Moine avec bouclier, comme Nexus) ; le résultat est alors identique au Dart.
--     3. Un objet « compte » s'il est équipé ET (sans harmonisation requise OU harmonisé).
--     4. Bonus d'objets = bonus magique de l'armure et du bouclier retenus s'ils comptent, + ac_bonus de chaque objet équipé
--        qui compte, selon ac_bonus_kind : 'toujours' ; 'avec_armure' si une armure est retenue ; 'sans_armure_ni_bouclier'
--        sans armure ni bouclier ; 'base_sans_armure' devient une base candidate (bonus + Dex) sans armure ; autre ou absent :
--        ignoré. L'ac_bonus d'un objet qui occupe l'emplacement d'armure ou de bouclier n'est compté que dans la combinaison
--        qui le retient, et la meilleure combinaison est choisie bonus compris (écailles de dragon harmonisées + armure
--        complète, Dex 16 : 18, pas 19). À reproduire tel quel par Nexus pour la décision n° 37.
--     5. Avec armure : ac_base + Dex selon ac_dex_bonus ('aucun' 0, 'max_2' min(Dex, 2), 'illimite' Dex, autre 0)
--        + 1 si Défense + bouclier + bonus d'objets.
--     6. Sans armure : max(10 + Dex ; Barbare 10 + Dex + Con ; Moine SANS bouclier 10 + Dex + Sag ; Lignage draconique
--        13 + Dex ; bases 'base_sans_armure') + bouclier + bonus d'objets.
--   Ne sont PAS lus : quantité, race, niveaux, états, Force, édition, harmonisation d'une armure pour sa CA de base.
--
-- CONTRAT
--   private.character_armor_class(p_character_id uuid)
--     -> table (armor_class integer, armor_class_bonus integer, armor_class_total integer), une ligne, ou AUCUNE si le
--        personnage n'existe pas.
--     armor_class        CA calculée ci-dessus, SANS l'ajustement manuel = CharacterDetail.armorClass de Nexus (la fiche, qui
--                        affiche l'ajustement à part). Piège de nommage : ce n'est PAS la CA à afficher seule.
--     armor_class_bonus  characters.armor_class_bonus (0 si NULL), ajustement manuel du joueur, positif ou négatif.
--     armor_class_total  armor_class + armor_class_bonus = GroupMember.armorClass de Nexus (tuile du groupe) : la CA que
--                        Grimoire affiche.
--   Cas de parité : supabase/tests/api_v1_character_armor_class_test.sql (C1 à C27 de regles-dnd, en sous-cas).
--
-- DROITS
--   Interne : schéma `private` (aucun USAGE pour anon ni authenticated, jamais exposé à l'API) ; EXECUTE retiré à PUBLIC, anon,
--   authenticated. Appelée uniquement par les fonctions security definer de `api_v1` (propriétaire postgres). SECURITY INVOKER
--   à dessein : appelée par un autre rôle, elle subirait la RLS de ce rôle au lieu de l'élever.
--
-- SANS EFFET SUR : Nexus, Grimoire, l'app web, les edge functions (nouvelle fonction, rien d'existant modifié).
--
-- RETOUR ARRIÈRE (aucune donnée en jeu ; APRÈS celui de 20261120091000, qui l'appelle) :
--   drop function if exists private.character_armor_class(uuid);
--   npx supabase migration repair --status reverted 20261120090000
--
-- VERROUS : création d'une fonction seulement, aucun verrou de table. `lock_timeout` posé par homogénéité avec les autres
-- migrations et pour vérifier que le fichier s'exécute dans UNE transaction.

set local lock_timeout = '5s';

do $lt$
begin
  raise notice 'lock_timeout=%', current_setting('lock_timeout');
  if current_setting('lock_timeout') <> '5s' then
    raise exception 'lock_timeout=% (attendu 5s) : cette migration doit s''exécuter dans UNE transaction (connexion directe ou pooler en mode session ; jamais l''éditeur du tableau de bord sans avoir vu ce NOTICE, ni le pooler en mode transaction)', current_setting('lock_timeout');
  end if;
end
$lt$;

create schema if not exists private;

create or replace function private.character_armor_class(p_character_id uuid)
returns table (armor_class integer, armor_class_bonus integer, armor_class_total integer)
language sql
stable
set search_path = public, pg_temp
as $$
  with ch as (
    select c.id, coalesce(c.armor_class_bonus, 0) as bonus
      from public.characters c
     where c.id = p_character_id
  ),
  -- Une ligne même sans aucun score (agrégat sans GROUP BY) : score absent = 10.
  mods as (
    select
      floor((coalesce(max(s.score) filter (where s.ability_id = 'dex'), 10) - 10) / 2.0)::integer as dex,
      floor((coalesce(max(s.score) filter (where s.ability_id = 'con'), 10) - 10) / 2.0)::integer as con,
      floor((coalesce(max(s.score) filter (where s.ability_id = 'wis'), 10) - 10) / 2.0)::integer as wis
      from public.character_ability_scores s
     where s.character_id = p_character_id
  ),
  flags as (
    select
      exists (
        select 1 from public.character_classes cc
          join public.translations t
            on t.entity_type = 'class' and t.entity_id = cc.class_id::text and t.field_name = 'name' and t.locale = 'fr'
         where cc.character_id = p_character_id and t.value = 'Barbare'
      ) as barbarian,
      exists (
        select 1 from public.character_classes cc
          join public.translations t
            on t.entity_type = 'class' and t.entity_id = cc.class_id::text and t.field_name = 'name' and t.locale = 'fr'
         where cc.character_id = p_character_id and t.value = 'Moine'
      ) as monk,
      exists (
        select 1 from public.character_classes cc
          join public.translations t
            on t.entity_type = 'subclass' and t.entity_id = cc.subclass_id::text and t.field_name = 'name' and t.locale = 'fr'
         where cc.character_id = p_character_id and t.value = 'Lignage draconique'
      ) as draconic,
      exists (
        select 1 from public.character_class_options o
          join public.translations t
            on t.entity_type = 'class_feature' and t.entity_id = o.class_feature_id::text and t.field_name = 'name'
           and t.locale = 'fr'
         where o.character_id = p_character_id and t.value = 'Style de combat' and o.chosen_value = 'Défense'
      ) as defense
  ),
  inv as (
    select
      ci.id,
      case
        when ci.item_id is not null then ap.item_id is not null
        else coalesce(
          ci.custom_ac_base is not null
          and (ci.custom_kind = 'bouclier'
               or (ci.custom_kind = 'armure' and ci.custom_armor_category in ('legere', 'intermediaire', 'lourde'))),
          false)
      end as has_armor_properties,
      case when ci.item_id is not null then ap.ac_base else ci.custom_ac_base::integer end as ac_base,
      case
        when ci.item_id is not null then coalesce(ap.ac_dex_bonus, 'aucun')
        when ci.custom_kind = 'bouclier' then 'aucun'
        when ci.custom_armor_category = 'legere' then 'illimite'
        when ci.custom_armor_category = 'intermediaire' then 'max_2'
        else 'aucun'
      end as ac_dex_bonus,
      case
        when ci.item_id is not null then coalesce(ap.slot, i.category)
        when ci.custom_kind = 'bouclier' then 'bouclier'
        when ci.custom_kind = 'armure' then 'armure'
      end as slot,
      -- « Compte » : équipé (filtre ci-dessous) ET (sans harmonisation requise OU harmonisé).
      (not (case when ci.item_id is not null then coalesce(i.requires_attunement, false)
                 else coalesce(ci.custom_requires_attunement, false) end)
       or coalesce(ci.is_attuned, false)) as counts,
      case when ci.item_id is null then coalesce(ci.custom_magic_bonus, 0)::integer else 0 end as magic_bonus,
      i.ac_bonus,
      i.ac_bonus_kind
      from public.character_inventory ci
      left join public.items i on i.id = ci.item_id
      left join public.armor_properties ap on ap.item_id = ci.item_id
     where ci.character_id = p_character_id
       and ci.equipped
  ),
  -- Objets qui occupent un emplacement : chacun n'apporte sa base, son bonus magique et son ac_bonus (own_bonus, NULL s'il
  -- ne « compte » pas) que dans SA combinaison, c'est-à-dire s'il est l'armure ou le bouclier retenu.
  armor_choices as (
    select v.id, v.ac_base, v.ac_dex_bonus, case when v.counts then v.magic_bonus else 0 end as magic,
           case when v.counts then v.ac_bonus end as own_bonus, v.ac_bonus_kind as own_kind
      from inv v
     where v.has_armor_properties and v.slot = 'armure'
    union all
    select null::uuid, null::integer, null::text, 0, null::integer, null::text
     where not exists (select 1 from inv v where v.has_armor_properties and v.slot = 'armure')
  ),
  shield_choices as (
    select v.id, v.ac_base, case when v.counts then v.magic_bonus else 0 end as magic,
           case when v.counts then v.ac_bonus end as own_bonus, v.ac_bonus_kind as own_kind
      from inv v
     where v.has_armor_properties and v.slot = 'bouclier'
    union all
    select null::uuid, 0, 0, null::integer, null::text
     where not exists (select 1 from inv v where v.has_armor_properties and v.slot = 'bouclier')
  ),
  -- Autres objets équipés qui comptent (anneau, cape, bracelets, robe, « Armure +N »…) : bonus communs à toutes les
  -- combinaisons. Les objets d'emplacement en sont exclus (comptés ci-dessus, dans leur combinaison seulement).
  bonuses as (
    select
      coalesce(sum(v.ac_bonus) filter (where v.ac_bonus_kind = 'toujours'), 0)::integer as always,
      coalesce(sum(v.ac_bonus) filter (where v.ac_bonus_kind = 'avec_armure'), 0)::integer as with_armor,
      coalesce(sum(v.ac_bonus) filter (where v.ac_bonus_kind = 'sans_armure_ni_bouclier'), 0)::integer as bare,
      max(v.ac_bonus) filter (where v.ac_bonus_kind = 'base_sans_armure') as unarmored_base
      from inv v
     where v.counts
       and v.ac_bonus is not null
       and not (v.has_armor_properties and v.slot in ('armure', 'bouclier'))
  ),
  combos as (
    select
      case
        when a.id is not null then
          a.ac_base
          + case a.ac_dex_bonus when 'illimite' then m.dex when 'max_2' then least(m.dex, 2) else 0 end
          + case when n.defense then 1 else 0 end
        else
          greatest(
            10 + m.dex,
            case when n.barbarian then 10 + m.dex + m.con end,
            case when n.monk and s.id is null then 10 + m.dex + m.wis end,
            case when n.draconic then 13 + m.dex end,
            b.unarmored_base + m.dex,
            -- ac_bonus 'base_sans_armure' du bouclier retenu (aucun objet du catalogue aujourd'hui, même règle que Nexus).
            case when s.own_kind = 'base_sans_armure' then s.own_bonus + m.dex end
          )
      end
      + s.ac_base
      + a.magic + s.magic
      + b.always
      + case when a.id is not null then b.with_armor else 0 end
      + case when a.id is null and s.id is null then b.bare else 0 end
      -- ac_bonus de l'armure et du bouclier retenus, selon leur type, évalué pour CETTE combinaison
      -- ('sans_armure_ni_bouclier' ne peut jamais s'appliquer à un objet retenu, puisqu'il occupe un emplacement).
      + coalesce(case when a.own_kind = 'toujours' or (a.own_kind = 'avec_armure' and a.id is not null) then a.own_bonus end, 0)
      + coalesce(case when s.own_kind = 'toujours' or (s.own_kind = 'avec_armure' and a.id is not null) then s.own_bonus end, 0)
      as ac
      from armor_choices a
     cross join shield_choices s
     cross join mods m
     cross join flags n
     cross join bonuses b
  )
  select max(co.ac)::integer, ch.bonus::integer, (max(co.ac) + ch.bonus)::integer
    from ch
   cross join combos co
   group by ch.bonus;
$$;

comment on function private.character_armor_class(uuid) is
  'Interne. CA d''un personnage, reproduction exacte du calcul de Nexus (armor_class_calculator.dart, écarts RAW de D234 compris), plusieurs armures ou boucliers équipés : meilleure combinaison (décision n° 37). Renvoie armor_class (sans ajustement), armor_class_bonus (characters.armor_class_bonus, 0 si NULL) et armor_class_total ; aucune ligne si le personnage n''existe pas. Appelée par api_v1.group_snapshot. Voir 20261120090000.';

-- Droits ----------------------------------------------------------------------------------------------------------------------
-- Les privilèges par défaut de Postgres donnent EXECUTE à PUBLIC sur toute nouvelle fonction : retrait explicite. Aucun rôle
-- client n'a USAGE sur `private` (défense en profondeur).
revoke all on function private.character_armor_class(uuid) from public, anon, authenticated;
