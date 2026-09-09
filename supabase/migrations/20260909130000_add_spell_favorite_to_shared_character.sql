-- Complète 20260908090000 (et 093000/094500/100000/103000/20260909110000) :
-- ajoute `is_favorite` à chaque entrée `spells` du jsonb retourné par
-- public.get_shared_character -- nécessaire pour que la vue en lecture seule
-- affiche la même section "FAVORIS" que la fiche authentifiée (chantier
-- "Favoris de sorts, distinction connu/préparé",
-- docs/cahier-des-charges/11-fonctionnalites-a-ajouter.md, section "Onglet
-- Sorts"). `status` ('connu'/'préparé'/'inné') était déjà exposé depuis
-- 20260908090000 (jamais affiché côté mobile jusqu'à ce chantier, voir
-- CharacterSpellEntry.status) ; aucune colonne supplémentaire n'est donc
-- nécessaire pour la distinction connu/préparé elle-même.
--
-- Copie exacte du corps de la fonction tel que laissé par 20260909110000
-- (relu depuis ce fichier avant d'écrire cette migration) : seule la ligne
-- `'is_favorite', csl.is_favorite,` est nouvelle.
create or replace function public.get_shared_character(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

-- GRANT identiques à ceux déjà en place (anon, authenticated) -- ré-affirmé
-- pour que cette migration reste lisible seule, même convention que les
-- migrations précédentes de ce chantier.
grant execute on function public.get_shared_character(text) to anon, authenticated;

comment on function public.get_shared_character(text) is
  'Point d''entrée public (anon, aucun JWT requis) du partage en lecture seule d''un personnage (12-partage-et-groupes.md section 1). Retourne NULL si p_token ne correspond à aucun characters.share_token actif. SECURITY DEFINER : lit directement toutes les tables character_* et de référence (classes, class_features, spells, items, races, translations...) sans passer par leurs policies RLS `to authenticated`, le token en paramètre étant l''unique mécanisme d''autorisation -- voir le commentaire d''en-tête de la migration 20260908090000 pour le rationale complet (RPC vs policies RLS anon). N''inclut jamais owner_id, is_archived, ni character_campaigns/stories. class_features ajoutée par 20260908100000. Détails complets des sorts et description des objets d''inventaire ajoutés par 20260908103000. inspiration/race_speed ajoutés par 20260909110000. is_favorite (sorts) ajoutée par 20260909130000.';
