-- Complète 20260908090000_add_character_share_token.sql (et ses correctifs
-- 20260908093000/20260908094500) : ajoute la clé `class_features` au jsonb
-- retourné par public.get_shared_character, manquante à l'origine.
--
-- Contexte : l'écran mobile "Vue en lecture seule" (chantier "Personnages",
-- en cours de construction côté app mobile, hors périmètre de ce dépôt) a
-- besoin des données descriptives des aptitudes de classe pour afficher sa
-- carte "APTITUDES DE CLASSE" de l'onglet Compétences, comme le fait déjà la
-- fiche personnage authentifiée normale. `get_shared_character` exposait déjà
-- `feature_uses` (les compteurs d'usage restants, `character_feature_uses`)
-- mais pas les aptitudes elles-mêmes (`class_features` : niveau d'obtention,
-- nom, description, forme d'usage) -- sans elles, `feature_uses` seul ne
-- permet d'afficher ni le nom, ni la description, ni le niveau d'obtention
-- d'une aptitude, seulement un compteur orphelin.
--
-- Reproduit exactement la logique déjà utilisée côté mobile authentifié pour
-- construire cette même carte -- voir
-- lib/features/characters/data/class_feature_row_mapper.dart (mapping pur)
-- et l'appel dans lib/features/characters/data/character_repository.dart
-- autour de "APTITUDES DE CLASSE" (~L.2629-2672, chantier mobile) :
-- - Table source `public.class_features` (id, class_id, level,
--   uses_per_rest jsonb `{amount, rest_type}`), filtrée sur les `class_id`
--   des classes du personnage (déjà résolues dans la CTE `classes` de cette
--   fonction, via `character_classes`).
-- - Filtre "atteinte par le niveau actuel" : par CLASSE, pas par niveau total
--   du personnage -- un multiclassé a un niveau différent par classe
--   (`character_classes.level`), c'est ce niveau-là qui compte, pas la somme.
--   Reproduit ici en joignant `class_features cf` à `character_classes cc`
--   sur `cc.class_id = cf.class_id` (au lieu du filtre client `classLevels`
--   de `ClassFeatureRowMapper.filterAttained`, qui recevait déjà les niveaux
--   par classe pré-résolus) et en ne gardant que `cf.level <= cc.level`.
-- - Aucune aptitude de sous-classe : `class_features.subclass_id` n'est
--   jamais lu ici, seul `class_id` sert au filtre -- même remarque que
--   documentée dans `class_feature_row_mapper.dart`/`character_class_feature
--   .dart` côté mobile (`class_features_class_or_subclass`, la contrainte
--   check de 20260825090200, garantit que les lignes de sous-classe ont
--   `class_id` NULL, donc mécaniquement exclues par le join ci-dessus, sans
--   filtre `subclass_id is null` explicite nécessaire -- même choix que le
--   code mobile).
-- - `class_features` n'a pas de colonne `description` directe (vit dans
--   `public.translations`, même mécanisme que `class_name`/`spell_name`
--   etc. déjà résolus via `get_translation` dans cette fonction) : `name` et
--   `description` sont donc résolus via `get_translation('class_feature',
--   id::text, 'name'|'description')`, comme `feature_uses.class_feature_name`
--   le fait déjà plus bas pour le nom seul.
-- - `uses_max`/`rest_type` : NULL pour une aptitude passive (`uses_per_rest`
--   NULL en base), sinon extraits de `uses_per_rest->>'amount'` (cast
--   entier) / `uses_per_rest->>'rest_type'` -- mêmes règles que
--   `ClassFeatureRowMapper.toCharacterClassFeature` côté mobile.
-- - `uses_remaining` : croisé avec `character_feature_uses` pour ce
--   `class_feature_id`, NULL si l'aptitude est passive (pas de ligne
--   `character_feature_uses` possible pour une aptitude sans usage limité)
--   OU si aucune ligne `character_feature_uses` n'existe encore pour cette
--   aptitude précise -- même règle que `usesMax != null ?
--   usesRemaining[id.toString()] : null` côté mobile. Dupliqué ici plutôt que
--   factorisé avec la sous-requête `feature_uses` existante (déjà utilisée
--   telle quelle par cette fonction, mieux vaut ne pas la faire dépendre
--   d'un ordre d'évaluation avec ce nouveau bloc) : reste une sous-requête
--   corrélée simple et lisible isolément, cohérent avec le style déjà
--   utilisé pour `weapon_properties`/`armor_properties` dans `inventory`
--   ci-dessous (sous-requêtes scalaires corrélées plutôt que CTE partagée).
--
-- SECURITY DEFINER (fonction inchangée par ailleurs, voir 20260908090000) :
-- `class_features` n'a qu'une policy RLS `to authenticated` (20260825090200,
-- "Authenticated users can read class_features") -- le rôle anon n'y a
-- normalement aucun accès, la lecture ici passe par les privilèges du
-- propriétaire de la fonction comme pour toutes les autres tables déjà
-- lues par get_shared_character (classes, items, translations...), avec le
-- token en paramètre comme unique mécanisme d'autorisation -- voir le
-- rationale complet (RPC vs policies RLS anon) dans le commentaire d'en-tête
-- de 20260908090000.
--
-- Aucun autre comportement de la fonction n'est modifié : les autres clés du
-- jsonb sont copiées telles quelles depuis 20260908090000, `owner_id` et
-- character_campaigns/stories restent exclus (voir leur commentaire
-- original, inchangé), signature (`p_token text`), `security definer` et les
-- GRANT déjà corrects (20260908093000/094500) restent identiques -- ce
-- `create or replace function` est un remplacement complet uniquement parce
-- que PostgreSQL ne permet pas de patcher partiellement le corps d'une
-- fonction existante, pas parce que d'autre chose change.
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
  -- Défense en profondeur : un token vide/blanc ne doit jamais matcher.
  -- share_token = '' ne devrait jamais exister en base (générée uniquement
  -- par gen_random_uuid()), mais cette garantie ne doit pas reposer
  -- uniquement sur "aucune ligne ne contient jamais ''" -- un futur script
  -- de peuplement/correctif buggé qui écrirait '' par erreur sur une ligne
  -- ne doit jamais devenir un partage universel accessible à
  -- p_token = ''. NULL est de toute façon déjà exclu naturellement (NULL =
  -- NULL vaut NULL, jamais true, en SQL) mais un garde explicite documente
  -- l'intention plutôt que de compter sur cette subtilité SQL implicite.
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
        'race_id', c.race_id,
        'race_name', public.get_translation('race', c.race_id::text, 'name'),
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
        'status', csl.status
      ))
      from public.character_spells csl
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
    -- Aptitudes de classe atteintes, carte "APTITUDES DE CLASSE" (voir
    -- commentaire d'en-tête de cette migration pour le détail de la
    -- correspondance avec class_feature_row_mapper.dart/
    -- character_repository.dart côté mobile). Jointure sur
    -- character_classes (pas seulement filtre class_id in (...)) pour
    -- disposer de cc.level -- le niveau DE CETTE CLASSE précise, pas le
    -- niveau total du personnage, indispensable pour filtrer correctement
    -- un personnage multiclassé.
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

-- GRANT identiques à ceux déjà en place depuis 20260908090000/093000/094500
-- (anon, authenticated ; PUBLIC déjà révoqué par les migrations
-- précédentes -- create or replace ne réinitialise pas les GRANT existants
-- sur le nom de fonction, ce ré-affirmation est donc redondante mais gardée
-- pour que cette migration reste lisible seule, même convention que
-- 20260908093000/094500).
grant execute on function public.get_shared_character(text) to anon, authenticated;

comment on function public.get_shared_character(text) is
  'Point d''entrée public (anon, aucun JWT requis) du partage en lecture seule d''un personnage (12-partage-et-groupes.md section 1). Retourne NULL si p_token ne correspond à aucun characters.share_token actif. SECURITY DEFINER : lit directement toutes les tables character_* et de référence (classes, class_features, items, translations...) sans passer par leurs policies RLS `to authenticated`, le token en paramètre étant l''unique mécanisme d''autorisation -- voir le commentaire d''en-tête de la migration 20260908090000 pour le rationale complet (RPC vs policies RLS anon). N''inclut jamais owner_id ni character_campaigns/stories (voir même commentaire). class_features (aptitudes de classe atteintes, filtrées par cc.level -- niveau par classe, pas niveau total du personnage) ajoutée par 20260908100000, voir son commentaire pour la correspondance avec class_feature_row_mapper.dart côté mobile.';
