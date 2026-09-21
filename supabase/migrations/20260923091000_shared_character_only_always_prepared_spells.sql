-- Suite de 20260922100000 / 20260923090000 : subclass_spells porte désormais aussi les listes
-- de sorts ÉTENDUES des patrons d'Occultiste (grant_kind = 'extends_list'), qui ne sont jamais
-- des sorts préparés d'office. Le bloc 'subclass_spells' de get_shared_character ne doit
-- renvoyer que les sorts 'always_prepared'. Seule cette condition change.
CREATE OR REPLACE FUNCTION public.get_shared_character(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_character_id uuid;
  v_result jsonb;
begin
  if p_token is null or btrim(p_token) = '' then
    return null;
  end if;

  select id into v_character_id
  from public.characters
  where share_token = p_token;

  if v_character_id is null then
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
      where c.id = v_character_id
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
      where cc.character_id = v_character_id
    ), '[]'::jsonb),
    'ability_scores', coalesce((
      select jsonb_agg(jsonb_build_object(
        'ability_id', cas.ability_id,
        'score', cas.score
      ))
      from public.character_ability_scores cas
      where cas.character_id = v_character_id
    ), '[]'::jsonb),
    'skill_proficiencies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'skill_id', csp.skill_id,
        'skill_name', public.get_translation('skill', csp.skill_id::text, 'name'),
        'proficiency', csp.proficiency
      ))
      from public.character_skill_proficiencies csp
      where csp.character_id = v_character_id
    ), '[]'::jsonb),
    'tool_proficiencies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'tool_id', ctp.tool_id,
        'tool_name', public.get_translation('tool', ctp.tool_id::text, 'name'),
        'custom_text', ctp.custom_text
      ))
      from public.character_tool_proficiencies ctp
      where ctp.character_id = v_character_id
    ), '[]'::jsonb),
    'languages', coalesce((
      select jsonb_agg(jsonb_build_object(
        'language_id', clg.language_id,
        'language_name', public.get_translation('language', clg.language_id::text, 'name')
      ))
      from public.character_languages clg
      where clg.character_id = v_character_id
    ), '[]'::jsonb),
    'spells', coalesce((
      select jsonb_agg(jsonb_build_object(
        'spell_id', csl.spell_id,
        'spell_name', public.get_translation('spell', csl.spell_id::text, 'name'),
        'status', csl.status,
        'is_favorite', csl.is_favorite,
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
      where csl.character_id = v_character_id
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
      where cc.character_id = v_character_id
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
      where css.character_id = v_character_id
    ), '[]'::jsonb),
    'pact_slots', coalesce((
      select jsonb_agg(jsonb_build_object(
        'slot_level', cps.slot_level,
        'slots_total', cps.slots_total,
        'slots_used', cps.slots_used
      ))
      from public.character_pact_slots cps
      where cps.character_id = v_character_id
    ), '[]'::jsonb),
    'feature_uses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'class_feature_id', cfu.class_feature_id,
        'class_feature_name', public.get_translation('class_feature', cfu.class_feature_id::text, 'name'),
        'uses_remaining', cfu.uses_remaining
      ))
      from public.character_feature_uses cfu
      where cfu.character_id = v_character_id
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
            where cfu.character_id = v_character_id
              and cfu.class_feature_id = cf.id
          )
        end
      ))
      from public.character_classes cc
      join public.class_features cf
        on cf.class_id = cc.class_id
        and cf.level <= cc.level
      where cc.character_id = v_character_id
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
      where ci.character_id = v_character_id
    ), '[]'::jsonb),
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', cp.id,
        'url', cp.url,
        'created_at', cp.created_at
      ))
      from public.character_photos cp
      where cp.character_id = v_character_id
    ), '[]'::jsonb),
    'journal_entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', cje.id,
        'body', cje.body,
        'created_at', cje.created_at
      ))
      from public.character_journal_entries cje
      where cje.character_id = v_character_id
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$function$;

grant execute on function public.get_shared_character(text) to anon, authenticated;
