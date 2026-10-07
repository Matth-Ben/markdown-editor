-- Chantier "Personnages" (app mobile) -- deux besoins, une seule migration :
--
-- 1. Compteur d'usage des sorts innés raciaux (demande utilisateur,
--    2026-10-07). En 5e, un sort inné racial de niveau 1 ou plus se lance
--    SANS emplacement, une fois par repos long. character_spells n'avait
--    aucun compteur : on ajoute character_spells.innate_uses_spent.
--
--    On stocke le nombre d'usages DÉPENSÉS (pas "restants") : la valeur par
--    défaut 0 est correcte pour toute ligne existante ou future, sans
--    initialisation à la création ni à la montée de niveau, et la base n'a
--    pas à connaître le maximum. La fréquence ("une fois par repos long")
--    reste une règle de l'app, comme pour slots_used / hit_dice_spent :
--    volontairement AUCUNE borne haute en base (seulement >= 0), pour ne pas
--    figer la règle de jeu ici (fréquence par race, don ou objet plus tard).
--    Volontairement AUCUNE contrainte croisée avec status = 'inné' non plus :
--    une valeur non nulle sur une ligne non innée est ignorée par l'app, alors
--    qu'un CHECK croisé ferait échouer tout changement de status d'une ligne
--    déjà entamée. Remise à 0 par l'app au repos long (aucun déclencheur).
--
--    Pas de nouvelle policy RLS ni de GRANT : les policies de
--    character_spells (20260825090400_create_character_tables.sql) portent
--    sur la ligne entière via owns_character(character_id), et le GRANT
--    select/insert/update/delete à authenticated (20260825091100) est au
--    niveau table, sans liste de colonnes -- même précédent que is_favorite
--    (20260909120000). Le MJ d'une histoire liée la voit en LECTURE SEULE
--    via "Story owner can select linked character_spells" (20260830100100),
--    jamais en écriture.
--
-- 2. Classe d'origine des sorts dans la fiche partagée. Le bloc 'spells' de
--    build_character_sheet_json (corps commun de get_shared_character et de
--    get_group_member_character depuis 20260927100000) ne renvoyait pas
--    character_spells.source_class_id : un personnage multiclassé mixte
--    partagé (Barde + Clerc) affichait tous ses sorts "à préparer". On
--    ajoute 'source_class_id', et 'innate_uses_spent' (1) pour qu'un tiers
--    voie l'usage restant d'un sort inné, au même titre que slots_used,
--    hit_dice_spent et uses_remaining déjà exposés.
--
--    Seule build_character_sheet_json est redéfinie : reprise à l'identique
--    de 20260927100000_group_member_character_sheet.sql (seule migration qui
--    la définit), avec ces deux clés pour seule différence. Signature,
--    SECURITY DEFINER et search_path inchangés ; EXECUTE reste retiré à
--    anon/authenticated/PUBLIC (20261007090000). get_shared_character
--    et get_group_member_character ne sont PAS redéfinies : elles délèguent
--    à cette fonction et héritent de l'ajout.
--
-- Changement purement additif : aucune colonne ni clé JSON retirée ou
-- renommée. Ne touche pas à codex_entries.
--
-- Retour arrière (dans cet ordre -- la fonction doit cesser de lire la
-- colonne avant sa suppression) :
--   1. rejouer le bloc `create or replace function
--      public.build_character_sheet_json` de
--      20260927100000_group_member_character_sheet.sql ;
--   2. alter table public.character_spells drop column if exists innate_uses_spent;
-- (2) n'est à faire qu'une fois plus aucune version de l'app mobile ne
-- nomme cette colonne dans un select/update.

alter table public.character_spells
  add column if not exists innate_uses_spent integer not null default 0
  check (innate_uses_spent >= 0);

comment on column public.character_spells.innate_uses_spent is
  'Nombre d''usages DÉPENSÉS depuis le dernier repos long pour un sort lancé sans emplacement (sort inné racial, status = ''inné''). 0 = aucun usage consommé. Remis à 0 par l''app au repos long. Le maximum (1 par repos long pour un sort inné racial en 5e) est une règle de l''app, volontairement non bornée en base. Sans signification pour une ligne non innée (reste à 0).';

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
  'Construit le JSON complet d''une fiche de personnage en lecture seule. Usage interne : corps commun de get_shared_character (partage par token, 12-partage-et-groupes.md section 1) et de get_group_member_character (fiche d''un membre du même groupe, section 2), qui portent seules le contrôle d''accès. SECURITY DEFINER : lit directement les tables character_* et de référence sans passer par leurs policies RLS. N''inclut jamais owner_id, is_archived, ni character_campaigns/stories. Extraite de get_shared_character par 20260927100000. EXECUTE explicitement retiré à anon/authenticated/PUBLIC (20261007090000) : non appelable directement via /rest/v1/rpc/build_character_sheet_json. source_class_id et innate_uses_spent (sorts) ajoutés par 20261007100000.';
