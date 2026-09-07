-- Chantier "Personnages" (app mobile) — 12-partage-et-groupes.md section 1,
-- "Partage d'un personnage" : un lien/token de partage en lecture seule sur
-- un personnage, révocable, consultable sans compte. Fonctionnement
-- indépendant du système de groupe (20260906182601_create_groups.sql) et de
-- character_campaigns (20260830100100_create_character_campaigns.sql).
--
-- Migration posée dans ce dépôt (web) bien que le chantier soit "Personnages"
-- (app mobile) : un seul historique de migrations SQL pour le projet
-- Supabase partagé, voir le CLAUDE.md du dépôt mobile
-- (nexus-jdr-app-mobile) qui l'impose explicitement. Aucun fichier de
-- migration n'existe ni ne doit exister dans ce dépôt-là.
--
-- Section 5.4 du même document (accès MJ -> personnages rattachés) précise
-- que ce type d'accès en lecture doit couvrir "la fiche complète... et leurs
-- tables associées — classes, inventaire, sorts, etc.", "sur le même
-- principe que le partage en lecture de la section 1". La fonction
-- get_shared_character ci-dessous couvre donc exactement le même ensemble de
-- tables que CharacterRepository.fetchCharacterDetail côté mobile
-- (lib/features/characters/data/character_repository.dart), à une exclusion
-- volontaire près : character_campaigns/stories (voir son commentaire).
--
-- ## Point de décision : RPC security-definer plutôt que policies RLS anon
--
-- La spec écrite ("policy RLS de lecture publique restreinte aux requêtes
-- présentant ce token") suggérerait naïvement une policy `to anon using
-- (share_token = current_setting(...))` sur `characters`, répliquée sur
-- chacune des ~10 tables "character_*" jointes (character_classes,
-- character_ability_scores, character_skill_proficiencies,
-- character_tool_proficiencies, character_languages, character_spells,
-- character_spell_slots, character_pact_slots, character_feature_uses,
-- character_inventory), plus des policies `to anon` sur les tables de
-- référence encore fermées à `authenticated` uniquement (translations,
-- classes, items, weapon_properties, armor_properties...) pour que le rôle
-- anon puisse résoudre les noms affichés. Écarté pour trois raisons :
--
-- 1. Surface d'attaque : une dizaine de policies RLS anon distinctes (une par
--    table "character_*"), chacune devant reproduire correctement la
--    comparaison de token, est nettement plus difficile à auditer et à
--    maintenir correctement dans le temps qu'un seul point d'entrée. Une
--    seule policy mal écrite (ex. oubliée sur une table ajoutée plus tard)
--    romprait silencieusement l'isolation sans qu'aucun test RLS existant ne
--    le détecte forcément.
-- 2. Il n'existe aujourd'hui aucun moyen RLS-natif de comparer `share_token`
--    à "le token présenté par la requête" sans un mécanisme supplémentaire
--    (ex. `current_setting('request.jwt.claims')` suppose un JWT, or le
--    lecteur est explicitement anonyme/sans compte ; un header custom via
--    `current_setting('request.headers', true)` fonctionnerait mais reste
--    fragile/peu documenté côté PostgREST et ne bénéficierait toujours pas
--    de mise en cache de plan de requête par table). Un paramètre RPC
--    explicite (`p_token text`) est une interface bien plus simple et
--    testable.
-- 3. Il faudrait ouvrir en lecture anonyme la moitié des tables de référence
--    (translations, classes, items, weapon_properties, armor_properties...)
--    juste pour ce seul cas d'usage, ce qui élargit durablement la surface
--    publique du schéma bien au-delà du besoin ("montrer une fiche" ne
--    justifie pas que n'importe qui puisse aussi faire `select * from
--    classes` sans compte).
--
-- Précédent déjà accepté dans ce dépôt pour ce style : les policies RLS
-- inter-utilisateurs de ce projet (character_owner_can_read_joined_story,
-- 20260830100300 ; group_member_can_read_character, 20260906190500)
-- utilisent déjà des fonctions helper `security definer` comme
-- intermédiaires d'autorisation, mais restent posées EN TANT que USING d'une
-- policy RLS classique (le lecteur y est toujours `auth.uid()`, un
-- utilisateur authentifié connu). Ici le lecteur n'a par construction aucune
-- identité (anon, aucun JWT) : il n'y a donc rien à substituer à `auth.uid()`
-- dans une policy RLS "normale", le SEUL secret disponible est le token en
-- paramètre — d'où le choix d'une fonction RPC `security definer` comme
-- point d'entrée unique et unique périmètre à auditer, plutôt qu'une
-- déclinaison de ce pattern policy-par-policy.

-- ## Colonne

alter table public.characters
  add column share_token text;

comment on column public.characters.share_token is
  'Jeton de partage en lecture seule (12-partage-et-groupes.md section 1). NULL = partage désactivé (valeur par défaut, immense majorité des personnages). Ne jamais écrire directement une valeur choisie côté client : la génération passe exclusivement par public.regenerate_character_share_token(), voir son commentaire. Consommé sans authentification (rôle anon, aucun JWT) via public.get_shared_character(p_token).';

-- Empêche toute collision qui ferait pointer deux personnages vers le même
-- token (négligeable en pratique avec ~122 bits d'entropie, gratuit à
-- garantir explicitement plutôt que de compter uniquement sur la probabilité
-- -- une collision non détectée exposerait la fiche d'un personnage A à qui
-- que ce soit possédant le lien du personnage B). `unique` autorise
-- nativement plusieurs lignes à NULL (comportement standard Postgres, aucune
-- valeur NULL n'est jamais égale à une autre) : ne gêne donc en rien
-- l'immense majorité des personnages qui n'activent jamais le partage. Sert
-- aussi d'index pour le lookup par égalité dans get_shared_character
-- ci-dessous (pas de scan séquentiel de characters).
alter table public.characters
  add constraint characters_share_token_key unique (share_token);

-- ## Régénération / désactivation

-- Régénère (et retourne) un nouveau share_token pour p_character_id,
-- invalidant l'ancien de fait (une seule colonne, écrasée). SECURITY INVOKER
-- explicite (pas DEFINER) : cette fonction n'accorde AUCUN privilège
-- supplémentaire par rapport à un UPDATE direct que le propriétaire pourrait
-- déjà faire lui-même depuis le client PostgREST
-- (`characters.update({share_token: ...}).eq('id', p_character_id)`),
-- puisque l'UPDATE interne ci-dessous reste entièrement soumis à la policy
-- "Owner can update their characters" existante (20260825090400, `auth.uid()
-- = owner_id`, sans restriction de colonne — vérifié explicitement pour
-- cette tâche). Son seul rôle est de garantir que la VALEUR écrite est
-- générée côté serveur avec une entropie suffisante (gen_random_uuid(),
-- ~122 bits, suggestion explicite de la spec 12-partage-et-groupes.md
-- section 1), plutôt que de faire confiance au client mobile pour
-- générer/envoyer lui-même "une valeur suffisamment aléatoire et
-- imprévisible" — un token faible ou prévisible choisi côté app romprait la
-- garantie de sécurité même si l'écriture elle-même reste par ailleurs
-- légitime.
--
-- Désactivation : pas de fonction dédiée. `update characters set
-- share_token = null where id = ... and owner_id = auth.uid()` suffit déjà,
-- via cette même policy "Owner can update their characters" — écrire `null`
-- ne nécessite aucune génération d'entropie, donc aucun besoin de passer par
-- une fonction serveur pour ce cas.
create or replace function public.regenerate_character_share_token(p_character_id uuid)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_new_token text;
  v_updated_id uuid;
begin
  v_new_token := gen_random_uuid()::text;

  update public.characters
  set share_token = v_new_token
  where id = p_character_id
    and owner_id = auth.uid() -- redondant avec la policy RLS ci-dessus (même
                               -- convention que le reste de ce dépôt côté
                               -- mobile, voir character_repository.dart :
                               -- "gardé pour la clarté... et pour ne jamais
                               -- dépendre implicitement d'une policy qu'on ne
                               -- voit pas depuis ce dépôt")
  returning id into v_updated_id;

  if v_updated_id is null then
    raise exception using
      message = 'Character not found or not owned by the current user',
      errcode = 'P0002';
  end if;

  return v_new_token;
end;
$$;

grant execute on function public.regenerate_character_share_token(uuid) to authenticated;

comment on function public.regenerate_character_share_token(uuid) is
  'Régénère share_token pour p_character_id (invalide l''ancien) et retourne la nouvelle valeur. SECURITY INVOKER : aucune élévation de privilège, l''UPDATE interne reste entièrement soumis à la policy "Owner can update their characters" existante -- cette fonction garantit seulement que la valeur écrite est générée côté serveur (gen_random_uuid()) plutôt que fournie par l''appelant. Lève une exception (P0002) si p_character_id n''existe pas ou n''appartient pas à auth.uid().';

-- ## Lecture publique agrégée

-- Petit helper de résolution de traduction (locale 'fr' en dur : l'app
-- mobile est mono-langue pour l'instant, voir _locale dans
-- character_repository.dart côté mobile -- "l'app démarre en français
-- uniquement, aucune gestion de locale n'existe encore côté client"). Évite
-- de répéter le même sous-select 5 fois dans get_shared_character
-- ci-dessous. SECURITY DEFINER pour la même raison que get_shared_character
-- (le rôle anon n'a aucune policy sur public.translations, `to authenticated`
-- uniquement -- voir 20260825090050_create_translations_table.sql) ; usage
-- interne uniquement, EXECUTE non accordé à anon/authenticated (appelé
-- seulement depuis l'intérieur de get_shared_character, elle-même security
-- definer).
create or replace function public.get_translation(
  p_entity_type text,
  p_entity_id text,
  p_field_name text
)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select value
  from public.translations
  where entity_type = p_entity_type
    and entity_id = p_entity_id
    and field_name = p_field_name
    and locale = 'fr'
  limit 1;
$$;

comment on function public.get_translation(text, text, text) is
  'Résout une traduction fr (public.translations) par (entity_type, entity_id, field_name). Retourne NULL si p_entity_id est NULL ou si aucune traduction n''existe. Usage interne à get_shared_character, pas exposée en EXECUTE à anon/authenticated.';

-- Point d'entrée public du partage en lecture seule (12-partage-et-groupes.md
-- section 1). Retourne un objet jsonb agrégeant la fiche complète du
-- personnage dont share_token = p_token, structurée pour couvrir exactement
-- les mêmes tables que CharacterRepository.fetchCharacterDetail côté mobile
-- -- voir le commentaire d'en-tête de cette migration pour le détail de la
-- correspondance table-par-table -- ou NULL si p_token ne correspond à aucun
-- personnage (token vide/NULL, révoqué, ou jamais généré). Le cas "aucune
-- correspondance" et le cas "existe mais aucun droit" sont indistinguables
-- pour l'appelant par construction : il n'y a ici qu'un seul et unique droit
-- d'accès possible (connaître le token exact), donc aucune information
-- supplémentaire à cacher entre ces deux cas.
--
-- Exclusion volontaire : character_campaigns/stories (histoires
-- rejointes/rattachées) ne sont PAS incluses dans le résultat, contrairement
-- à ce que lit fetchCharacterDetail côté mobile. Une histoire rattachée
-- n'est pas une donnée de la fiche du personnage au sens de la section 1 --
-- c'est une relation vers une autre table appartenant potentiellement à un
-- tiers (le MJ), et character_campaigns/stories ne sont déjà accessibles en
-- lecture qu'à des utilisateurs authentifiés et identifiés (le joueur
-- propriétaire, ou le MJ de l'histoire -- voir
-- 20260830100300_add_character_owner_stories_select.sql). Les exposer à un
-- détenteur de lien anonyme révélerait en plus à quelle(s) histoire(s)/MJ ce
-- personnage est rattaché, une fuite d'information qui dépasse largement
-- "montrer la fiche" et qui n'est demandée nulle part dans la spec.
--
-- owner_id n'est jamais inclus non plus : le token ne doit permettre de
-- lire QUE la fiche, jamais d'identifier son propriétaire (auth.users.id).
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

grant execute on function public.get_shared_character(text) to anon, authenticated;

comment on function public.get_shared_character(text) is
  'Point d''entrée public (anon, aucun JWT requis) du partage en lecture seule d''un personnage (12-partage-et-groupes.md section 1). Retourne NULL si p_token ne correspond à aucun characters.share_token actif. SECURITY DEFINER : lit directement toutes les tables character_* et de référence (classes, items, translations...) sans passer par leurs policies RLS `to authenticated`, le token en paramètre étant l''unique mécanisme d''autorisation -- voir le commentaire d''en-tête de la migration 20260908090000 pour le rationale complet (RPC vs policies RLS anon). N''inclut jamais owner_id ni character_campaigns/stories (voir même commentaire).';
