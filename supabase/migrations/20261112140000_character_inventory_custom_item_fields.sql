-- Chantier P7 "objet personnalisé enrichi" (app mobile "Personnages") : un
-- objet personnalisé (character_inventory.item_id is null, custom_name
-- renseigné) peut désormais porter un type (arme/armure/bouclier/autre), un
-- bonus magique, une CA de base, une catégorie d'armure, un poids, une
-- exigence d'harmonisation et, pour une arme, sa catégorie et sa portée.
-- Spec : docs/p7-objet-personnalise.md du dépôt mobile.
--
-- Colonnes ajoutées à public.character_inventory (toutes NULL, sauf
-- custom_requires_attunement false par défaut -> aucune ligne existante ne
-- change de sens, aucun backfill) :
--   custom_kind                 'arme' | 'armure' | 'bouclier' | 'autre'
--   custom_magic_bonus          0..3 (NULL = 0)
--   custom_ac_base              0..30 (CA de l'armure ; bonus de CA du bouclier)
--   custom_armor_category       'legere' | 'intermediaire' | 'lourde'
--   custom_weight               kg par unité, >= 0
--   custom_requires_attunement  boolean not null default false
--   custom_weapon_category      'courante' | 'guerre'
--   custom_weapon_range         'melee' | 'distance'
--
-- custom_damage_type : AUCUN CHECK n'existe (vérifié dans
-- 20261025090000, volontairement, pour rester aligné sur
-- weapon_properties.damage_type). Rien à élargir : les 13 types (tranchant,
-- perforant, contondant, acide, feu, foudre, froid, force, nécrotique,
-- poison, psychique, radiant, tonnerre, en minuscules singulier) sont
-- acceptés tels quels. Aucun CHECK n'est ajouté (rigueur que le schéma de
-- référence n'a pas non plus).
--
-- Contraintes de cohérence (nommées, ajoutées seulement si absentes, donc
-- rejouable). Les 8 colonnes étant NULL/false sur toutes les lignes
-- existantes, chaque contrainte est satisfaite par construction : ajout
-- direct, sans NOT VALID.
--
-- RLS : aucune modification. Les policies de character_inventory sont par
-- ligne (propriétaire select/insert/update/delete ; MJ d'une histoire liée
-- et coéquipiers de groupe en SELECT seul) et couvrent les nouvelles
-- colonnes ; aucun GRANT/REVOKE par colonne n'existe sur cette table.
--
-- Fiche partagée : build_character_sheet_json redéfinie (reprise à
-- l'identique de 20261110090000_add_characters_conditions.sql, dernière
-- définition) avec les 8 nouvelles clés ajoutées dans 'inventory', juste
-- après 'custom_properties'. get_shared_character et
-- get_group_member_character héritent de l'ajout (changement purement
-- additif). create_character (20261007110000) insère par liste de colonnes
-- explicite : non affectée.
--
-- À APPLIQUER EN PRODUCTION AVANT toute sortie de l'app mobile qui lit ou
-- écrit ces colonnes (le rejeu de la file hors ligne échoue sur colonnes
-- inconnues).
--
-- Retour arrière : rejouer le bloc `create or replace function
-- public.build_character_sheet_json` de 20261110090000, puis supprimer les
-- contraintes character_inventory_custom_* et les 8 colonnes
-- (`alter table public.character_inventory drop column ...`).

alter table public.character_inventory
  add column if not exists custom_kind text
    check (custom_kind in ('arme', 'armure', 'bouclier', 'autre')),
  add column if not exists custom_magic_bonus smallint
    check (custom_magic_bonus between 0 and 3),
  add column if not exists custom_ac_base smallint
    check (custom_ac_base between 0 and 30),
  add column if not exists custom_armor_category text
    check (custom_armor_category in ('legere', 'intermediaire', 'lourde')),
  add column if not exists custom_weight numeric(7, 2)
    check (custom_weight >= 0),
  add column if not exists custom_requires_attunement boolean not null default false,
  add column if not exists custom_weapon_category text
    check (custom_weapon_category in ('courante', 'guerre')),
  add column if not exists custom_weapon_range text
    check (custom_weapon_range in ('melee', 'distance'));

do $$
begin
  -- Un objet du catalogue ne porte aucun champ d'objet personnalisé.
  if not exists (select 1 from pg_constraint where conname = 'character_inventory_custom_fields_only_if_custom'
                   and conrelid = 'public.character_inventory'::regclass) then
    alter table public.character_inventory
      add constraint character_inventory_custom_fields_only_if_custom check (
        item_id is null
        or (
          custom_kind is null
          and custom_magic_bonus is null
          and custom_ac_base is null
          and custom_armor_category is null
          and custom_weight is null
          and custom_requires_attunement = false
          and custom_weapon_category is null
          and custom_weapon_range is null
        )
      );
  end if;

  -- Armure : CA de base et catégorie obligatoires.
  if not exists (select 1 from pg_constraint where conname = 'character_inventory_custom_armor_requires_ac_and_category'
                   and conrelid = 'public.character_inventory'::regclass) then
    alter table public.character_inventory
      add constraint character_inventory_custom_armor_requires_ac_and_category check (
        custom_kind is distinct from 'armure'
        or (custom_ac_base is not null and custom_armor_category is not null)
      );
  end if;

  -- Bouclier : bonus de CA obligatoire.
  if not exists (select 1 from pg_constraint where conname = 'character_inventory_custom_shield_requires_ac'
                   and conrelid = 'public.character_inventory'::regclass) then
    alter table public.character_inventory
      add constraint character_inventory_custom_shield_requires_ac check (
        custom_kind is distinct from 'bouclier'
        or custom_ac_base is not null
      );
  end if;

  -- Bonus magique réservé à arme/armure/bouclier (coalesce : un type NULL
  -- ne doit pas faire passer la contrainte par la valeur NULL).
  if not exists (select 1 from pg_constraint where conname = 'character_inventory_custom_magic_bonus_kind'
                   and conrelid = 'public.character_inventory'::regclass) then
    alter table public.character_inventory
      add constraint character_inventory_custom_magic_bonus_kind check (
        custom_magic_bonus is null
        or coalesce(custom_kind in ('arme', 'armure', 'bouclier'), false)
      );
  end if;

  -- Catégorie et portée d'arme réservées au type arme.
  if not exists (select 1 from pg_constraint where conname = 'character_inventory_custom_weapon_fields_kind'
                   and conrelid = 'public.character_inventory'::regclass) then
    alter table public.character_inventory
      add constraint character_inventory_custom_weapon_fields_kind check (
        (custom_weapon_category is null and custom_weapon_range is null)
        or coalesce(custom_kind = 'arme', false)
      );
  end if;
end
$$;

comment on column public.character_inventory.custom_kind is
  'Type d''un objet personnalisé (item_id is null) : ''arme'', ''armure'', ''bouclier'' ou ''autre''. NULL pour un objet du catalogue et pour un ancien objet personnalisé non typé (le client déduit alors ''arme'' si custom_damage_dice est renseigné).';

comment on column public.character_inventory.custom_magic_bonus is
  'Bonus magique (0 à 3) d''une arme, armure ou bouclier personnalisé. NULL = 0. Réservé à ces trois types ; inactif côté app tant que l''objet requiert l''harmonisation sans être harmonisé.';

comment on column public.character_inventory.custom_ac_base is
  'Classe d''armure de base (0 à 30) d''une armure personnalisée ; bonus de CA d''un bouclier personnalisé. Obligatoire pour ces deux types, NULL sinon.';

comment on column public.character_inventory.custom_armor_category is
  'Catégorie d''une armure personnalisée : ''legere'', ''intermediaire'' ou ''lourde'' (détermine le bonus de Dextérité et la maîtrise). Obligatoire pour une armure, NULL sinon.';

comment on column public.character_inventory.custom_weight is
  'Poids unitaire en kilogrammes (>= 0, deux décimales) d''un objet personnalisé. NULL = non renseigné.';

comment on column public.character_inventory.custom_requires_attunement is
  'Vrai si l''objet personnalisé nécessite une harmonisation. Toujours faux pour un objet du catalogue (qui utilise items.requires_attunement).';

comment on column public.character_inventory.custom_weapon_category is
  'Catégorie d''une arme personnalisée : ''courante'' ou ''guerre'' (sert à évaluer la maîtrise). NULL = non renseignée (maîtrise non évaluée). Réservé au type ''arme''.';

comment on column public.character_inventory.custom_weapon_range is
  'Portée d''une arme personnalisée : ''melee'' (corps à corps) ou ''distance'' (choix de la caractéristique d''attaque). NULL = non renseignée. Réservé au type ''arme''.';

create or replace function public.build_character_sheet_json(p_character_id uuid)
 returns jsonb
 language plpgsql
 stable security definer
 set search_path to 'public'
as $function$
declare
  v_result jsonb;
begin
  if p_character_id is null then
    return null;
  end if;

  select jsonb_build_object(
    'character', (
      select jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'portrait_url', c.portrait_url,
        'xp', c.xp,
        'current_hp', c.current_hp,
        'max_hp', c.max_hp,
        'temporary_hp', c.temporary_hp,
        'is_dead', c.is_dead,
        'inspiration', c.inspiration,
        'armor_class_bonus', c.armor_class_bonus,
        'conditions', coalesce(c.conditions, '[]'::jsonb),
        'race_id', c.race_id,
        'race_name', public.get_translation('race', c.race_id::text, 'name'),
        'race_speed', (select r.speed from public.races r where r.id = c.race_id),
        'subrace_id', c.subrace_id,
        'subrace_name', public.get_translation('subrace', c.subrace_id::text, 'name'),
        'race_custom_text', c.race_custom_text,
        'background_id', c.background_id,
        'background_name', public.get_translation('background', c.background_id::text, 'name'),
        'alignment_id', c.alignment_id,
        'alignment_name', public.get_translation('alignment', c.alignment_id::text, 'name'),
        'sexe', c.sexe,
        'age', c.age,
        'height', c.height,
        'weight', c.weight,
        'eyes', c.eyes,
        'skin', c.skin,
        'hair', c.hair,
        'currency_gp', c.currency_gp,
        'currency_pp', c.currency_pp,
        'currency_ep', c.currency_ep,
        'currency_sp', c.currency_sp,
        'currency_cp', c.currency_cp,
        'appearance_text', c.appearance_text,
        'traits_text', c.traits_text,
        'ideals_text', c.ideals_text,
        'bonds_text', c.bonds_text,
        'flaws_text', c.flaws_text,
        'backstory_text', c.backstory_text,
        'allies_text', c.allies_text,
        'features_text', c.features_text,
        'treasure_text', c.treasure_text
      )
      from public.characters c
      where c.id = p_character_id
    ),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'class_id', cc.class_id,
        'class_name', public.get_translation('class', cc.class_id::text, 'name'),
        'subclass_id', cc.subclass_id,
        'subclass_name', public.get_translation('subclass', cc.subclass_id::text, 'name'),
        'level', cc.level,
        'is_primary', cc.is_primary,
        'hit_dice_spent', cc.hit_dice_spent,
        'hit_die', cl.hit_die,
        'saving_throw_proficiencies', cl.saving_throw_proficiencies,
        'armor_proficiencies', cl.armor_proficiencies,
        'weapon_proficiencies', cl.weapon_proficiencies
      ))
      from public.character_classes cc
      join public.classes cl on cl.id = cc.class_id
      where cc.character_id = p_character_id
    ), '[]'::jsonb),
    'ability_scores', coalesce((
      select jsonb_agg(jsonb_build_object(
        'ability_id', cas.ability_id,
        'score', cas.score
      ))
      from public.character_ability_scores cas
      where cas.character_id = p_character_id
    ), '[]'::jsonb),
    'skill_proficiencies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'skill_id', csp.skill_id,
        'skill_name', public.get_translation('skill', csp.skill_id::text, 'name'),
        'proficiency', csp.proficiency
      ))
      from public.character_skill_proficiencies csp
      where csp.character_id = p_character_id
    ), '[]'::jsonb),
    'tool_proficiencies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'tool_id', ctp.tool_id,
        'tool_name', public.get_translation('tool', ctp.tool_id::text, 'name'),
        'custom_text', ctp.custom_text
      ))
      from public.character_tool_proficiencies ctp
      where ctp.character_id = p_character_id
    ), '[]'::jsonb),
    'languages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'language_id', clg.language_id,
        'language_name', public.get_translation('language', clg.language_id::text, 'name')
      ))
      from public.character_languages clg
      where clg.character_id = p_character_id
    ), '[]'::jsonb),
    'spells', coalesce((
      select jsonb_agg(jsonb_build_object(
        'spell_id', csl.spell_id,
        'spell_name', public.get_translation('spell', csl.spell_id::text, 'name'),
        'status', csl.status,
        'is_favorite', csl.is_favorite,
        'source_class_id', csl.source_class_id,
        'innate_uses_spent', csl.innate_uses_spent,
        'level', s.level,
        'school', s.school,
        'casting_time', s.casting_time,
        'range', s.range,
        'components', s.components,
        'duration', s.duration,
        'concentration', s.concentration,
        'description', public.get_translation('spell', csl.spell_id::text, 'description')
      ))
      from public.character_spells csl
      join public.spells s on s.id = csl.spell_id
      where csl.character_id = p_character_id
    ), '[]'::jsonb),
    'subclass_spells', coalesce((
      select jsonb_agg(jsonb_build_object(
        'spell_id', ss.spell_id,
        'spell_name', public.get_translation('spell', ss.spell_id::text, 'name'),
        'class_id', cc.class_id,
        'subclass_id', cc.subclass_id,
        'level', s.level,
        'school', s.school,
        'casting_time', s.casting_time,
        'range', s.range,
        'components', s.components,
        'duration', s.duration,
        'concentration', s.concentration,
        'description', public.get_translation('spell', ss.spell_id::text, 'description')
      ))
      from public.character_classes cc
      join public.subclass_spells ss on ss.subclass_id = cc.subclass_id
      join public.spells s on s.id = ss.spell_id
      where cc.character_id = p_character_id
        and cc.subclass_id is not null
        and ss.class_level <= cc.level
        and ss.grant_kind = 'always_prepared'
    ), '[]'::jsonb),
    'spell_slots', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_level', css.slot_level,
        'slots_total', css.slots_total,
        'slots_used', css.slots_used
      ))
      from public.character_spell_slots css
      where css.character_id = p_character_id
    ), '[]'::jsonb),
    'pact_slots', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_level', cps.slot_level,
        'slots_total', cps.slots_total,
        'slots_used', cps.slots_used
      ))
      from public.character_pact_slots cps
      where cps.character_id = p_character_id
    ), '[]'::jsonb),
    'feature_uses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'class_feature_id', cfu.class_feature_id,
        'class_feature_name', public.get_translation('class_feature', cfu.class_feature_id::text, 'name'),
        'uses_remaining', cfu.uses_remaining
      ))
      from public.character_feature_uses cfu
      where cfu.character_id = p_character_id
    ), '[]'::jsonb),
    'class_features', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', cf.id,
        'name', public.get_translation('class_feature', cf.id::text, 'name'),
        'level', cf.level,
        'uses_max', (cf.uses_per_rest->>'amount')::int,
        'rest_type', cf.uses_per_rest->>'rest_type',
        'description', public.get_translation('class_feature', cf.id::text, 'description'),
        'uses_remaining', case
          when (cf.uses_per_rest->>'amount')::int is null then null
          else (
            select cfu.uses_remaining
            from public.character_feature_uses cfu
            where cfu.character_id = p_character_id
              and cfu.class_feature_id = cf.id
          )
        end
      ))
      from public.character_classes cc
      join public.class_features cf
        on cf.class_id = cc.class_id
        and cf.level <= cc.level
      where cc.character_id = p_character_id
    ), '[]'::jsonb),
    'inventory', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', ci.id,
        'item_id', ci.item_id,
        'item_name', public.get_translation('item', ci.item_id::text, 'name'),
        'custom_name', ci.custom_name,
        'quantity', ci.quantity,
        'equipped', ci.equipped,
        'is_attuned', ci.is_attuned,
        'notes', ci.notes,
        'custom_description', ci.custom_description,
        'custom_damage_dice', ci.custom_damage_dice,
        'custom_damage_type', ci.custom_damage_type,
        'custom_properties', ci.custom_properties,
        'custom_kind', ci.custom_kind,
        'custom_magic_bonus', ci.custom_magic_bonus,
        'custom_ac_base', ci.custom_ac_base,
        'custom_armor_category', ci.custom_armor_category,
        'custom_weight', ci.custom_weight,
        'custom_requires_attunement', ci.custom_requires_attunement,
        'custom_weapon_category', ci.custom_weapon_category,
        'custom_weapon_range', ci.custom_weapon_range,
        'category', it.category,
        'weight', it.weight,
        'cost', it.cost,
        'rarity', it.rarity,
        'requires_attunement', it.requires_attunement,
        'consumable', it.consumable,
        'description', case
          when ci.item_id is null then null
          else public.get_translation('item', ci.item_id::text, 'description')
        end,
        'weapon_properties', (
          select jsonb_build_object(
            'damage_dice', wp.damage_dice,
            'damage_type', wp.damage_type,
            'properties', wp.properties,
            'range', wp.range
          )
          from public.weapon_properties wp
          where wp.item_id = ci.item_id
        ),
        'armor_properties', (
          select jsonb_build_object(
            'ac_base', ap.ac_base,
            'ac_dex_bonus', ap.ac_dex_bonus,
            'strength_requirement', ap.strength_requirement,
            'stealth_disadvantage', ap.stealth_disadvantage
          )
          from public.armor_properties ap
          where ap.item_id = ci.item_id
        )
      ))
      from public.character_inventory ci
      left join public.items it on it.id = ci.item_id
      where ci.character_id = p_character_id
    ), '[]'::jsonb),
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', cp.id,
        'url', cp.url,
        'created_at', cp.created_at
      ))
      from public.character_photos cp
      where cp.character_id = p_character_id
    ), '[]'::jsonb),
    'journal_entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', cje.id,
        'body', cje.body,
        'created_at', cje.created_at
      ))
      from public.character_journal_entries cje
      where cje.character_id = p_character_id
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$function$;

-- Re-déclaré pour que ce fichier reste correct seul. Un `create or replace`
-- conserve les privilèges existants, mais un `revoke ... from public` seul
-- NE SUFFIT PAS sur ce projet : les "alter default privileges" accordent
-- EXECUTE directement à anon et authenticated (voir
-- 20261007090000_revoke_build_character_sheet_json_execute.sql, qui corrige
-- le retrait initial de 20260927100000). Toujours révoquer des trois.
revoke execute on function public.build_character_sheet_json(uuid) from anon, authenticated, public;

comment on function public.build_character_sheet_json(uuid) is
  'Construit le JSON complet d''une fiche de personnage en lecture seule. Usage interne : corps commun de get_shared_character (partage par token, 12-partage-et-groupes.md section 1) et de get_group_member_character (fiche d''un membre du même groupe, section 2), qui portent seules le contrôle d''accès. SECURITY DEFINER : lit directement les tables character_* et de référence sans passer par leurs policies RLS. N''inclut jamais owner_id, is_archived, ni character_campaigns/stories. Extraite de get_shared_character par 20260927100000. source_class_id et innate_uses_spent (sorts) ajoutés par 20261007100000. armor_class_bonus ajouté par 20261023110000. custom_description/custom_damage_dice/custom_damage_type/custom_properties (objets personnalisés) ajoutés par 20261025100000. conditions (marqueurs d''états) ajouté par 20261110090000. custom_kind/custom_magic_bonus/custom_ac_base/custom_armor_category/custom_weight/custom_requires_attunement/custom_weapon_category/custom_weapon_range (objets personnalisés enrichis) ajoutés par 20261112140000.';
