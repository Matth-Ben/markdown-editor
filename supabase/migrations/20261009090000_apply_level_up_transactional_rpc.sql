-- Chantier "Personnages" (app mobile) -- D05 du registre de dette technique
-- mobile (docs/dette-technique.md, depot nexus-jdr-app-mobile) : dernier
-- morceau de D05 -- suite de `create_character` (20261007110000) et
-- `apply_rest` (20261008100000), qui laissaient volontairement
-- `apply_level_up` pour une PR separee (voir le commentaire de tete de
-- 20261007110000 et celui, plus detaille, de 20261008100000). Porte
-- `CharacterRepository.applyLevelUp` (lib/features/characters/data/
-- character_repository.dart, depot mobile, ~L2360-2700) en une seule
-- transaction.
--
-- CETTE FONCTION EST PLUS COMPLEXE QUE `create_character`/`apply_rest` --
-- lue en entier (elle, ses 6 fichiers `domain/` appeles, et le schema des 9
-- tables qu'elle ecrit) avant d'ecrire cette migration, par prudence plutot
-- que de la reporter une seconde fois. Resume de l'analyse qui justifie de
-- la porter INTEGRALEMENT plutot que de la scinder (contrairement a ce que
-- le commentaire de 20261008100000 laissait entendre comme risque) :
-- - `MulticlassPrerequisites` (domain/multiclass_prerequisites.dart) est une
--   simple table de donnees (clauses OU/ET par nom de classe francais, deja
--   utilisee ailleurs pour le filtrage UI) -- transcrite ci-dessous en CTE
--   `values(...)`, meme precaution que les tables de progression de sorts.
-- - `HitPointBonusRules.perLevelBonus` (Nain des collines, don deja pris,
--   Lignage draconique) n'a PAS besoin d'etre porte ici : il est deja
--   applique cote CLIENT dans le calcul de [p_hp_gain] (voir
--   `domain/level_up_hit_points_calculator.dart`, appelant de
--   `applyLevelUp`) -- cette fonction ne fait qu'ecrire [p_hp_gain] deja
--   calcule, exactement comme `create_character` n'a jamais recalcule
--   [p_max_hp]. Seules `HitPointBonusRules.constitutionRetroactiveBonus`
--   (arithmetique pure, aucune comparaison de nom) et
--   `HitPointBonusRules.featTakenBonus` (compare un nom de don RESOLU VIA
--   `translations` a DEUX constantes connues -- 'Robuste physiquement' et
--   'Faveur de robustesse' -- exactement la meme classe de risque que la
--   comparaison "Occultiste" deja acceptee dans `apply_rest`) sont portees
--   ici, et SEULEMENT elles -- aucune comparaison de nom de SOUS-CLASSE
--   n'est necessaire cote serveur (le bonus de Lignage draconique est deja
--   dans [p_hp_gain], voir ci-dessus).
-- - `MulticlassProficiencies` (domain/multiclass_proficiencies.dart) n'est
--   PAS porte : lu en entier, confirme PUREMENT textuel/affichage ponctuel
--   (etape "Aptitudes" de la montee de niveau), jamais persiste nulle part
--   -- aucune ecriture serveur n'en depend.
-- - `SpellSlotProgression` (emplacements de sorts ET magie de pacte) est
--   EXACTEMENT la meme table de donnees que celle deja portee par
--   `apply_rest` (meme fichier source, memes constantes RAW 5e) -- seule la
--   semantique d'upsert differe (voir plus bas : ici `slots_used` est
--   PRESERVE/PLAFONNE, jamais remis a 0, contrairement a un repos).
-- - `SpellcastingRules.statusFor` est un simple mapping a 2 branches (4 noms
--   de classe "preparee" connus, 'connu' par defaut) -- transcrit en `case`.
--
-- Resolution de nom DIFFERENTE d'`apply_rest`, A NE JAMAIS CONFONDRE AVEC LA
-- SIENNE (qui en a DEUX distinctes, voir son commentaire de tete) : ici, une
-- SEULE convention, utilisee de façon UNIFORME pour a) le calcul des
-- emplacements de sorts classiques ET b) la detection de l'Occultiste pour
-- la magie de pacte -- la classe CIBLE de cette montee de niveau (celle
-- identifiee par [p_class_id]) est TOUJOURS nommee par [p_class_name]
-- (parametre, deja resolu par l'appelant), TOUTES LES AUTRES classes du
-- personnage sont nommees via `translations` (repli '' si la traduction
-- manque, jamais une erreur -- meme philosophie que `apply_rest`). C'est la
-- transcription fidele de `afterClasses` cote Dart (`applyLevelUp`), qui
-- nomme sa ligne cible par le parametre `className` dans les DEUX listes
-- `beforeClasses`/`afterClasses`, reutilisees ENSUITE identiquement par
-- [_upsertSpellSlots] ET [_upsertPactSlot] -- contrairement a `apply_rest`,
-- qui a deux fonctions Dart distinctes (`_resetSpellSlots`/`_resetPactSlot`)
-- avec chacune sa propre resolution.
--
-- Semantique d'upsert des emplacements de sorts/magie de pacte, ENCORE
-- distincte d'`apply_rest` : une montee de niveau ne "repose" jamais le
-- personnage -- `slots_used`/charges deja consommees restent CONSOMMEES,
-- seul `slots_total`/charges disponibles change, plafonne le `slots_used`
-- existant au nouveau total s'il le depasserait (`least(existing, total)`)
-- -- jamais remis a 0 (voir [_upsertSpellSlots]/[_upsertPactSlot] cote
-- Dart, qui PRESERVENT plutot que RESETENT, contrairement a
-- [_resetSpellSlots]/[_resetPactSlot] utilisees par `apply_rest`).
--
-- Isolation : SECURITY DEFINER, verifie EN PREMIER que [p_character_id]
-- appartient a `auth.uid()` (jamais un parametre `owner_id`), meme
-- discipline que `create_character`/`apply_rest`.
--
-- Privileges EXECUTE : meme piege deja documente trois fois sur ce projet
-- (20260908094500, 20261007090000/20261007110000, 20261008100000) -- revoke
-- explicite de anon ET authenticated ET public, puis grant a authenticated
-- seul.
--
-- Atomicite : aucun `begin`/`commit`/`exception when others` -- une
-- exception non interceptee annule TOUTE la transaction de cet appel RPC,
-- meme raisonnement que `create_character`/`apply_rest` (voir leurs
-- commentaires de tete).
--
-- PIEGE CONNU, VOLONTAIREMENT NON RESOLU ICI (meme famille que celui deja
-- documente sur `apply_rest`, en PIRE sur cette fonction) : un appel RPC
-- committe cote serveur dont la reponse HTTP est perdue puis REJOUE par un
-- retry client ne serait PAS idempotent -- et contrairement a `apply_rest`
-- (un seul point sensible, la recuperation RELATIVE des des de vie), cette
-- fonction cumule PLUSIEURS surfaces non idempotentes sur un seul appel :
-- un REJOUE additionnerait une SECONDE fois `p_hp_gain` (et le bonus
-- retroactif de Constitution/don) a `characters.max_hp`/`current_hp`,
-- inserait une SECONDE ligne `character_level_hp` (pas de contrainte
-- unique, doublon d'historique silencieux), inserait une SECONDE fois les
-- sorts initiaux/invocations choisis (`character_invocations` a une cle
-- primaire composite -- un REJOUE y leverait une erreur explicite de
-- doublon, donc PAS un risque silencieux la, mais `character_spells` n'a
-- aucune contrainte unique -- doublon silencieux), et re-executerait le
-- choix (un second don identique leverait une erreur de doublon sur
-- `character_feats`, PK composite -- pas silencieux ; mais une seconde
-- repartition de caracteristiques ASI re-ajouterait les points une seconde
-- fois, silencieusement, jusqu'au plafond de 20). Seuls les emplacements de
-- sorts/magie de pacte sont naturellement idempotents ici (upsert sur un
-- total RECALCULE, pas un delta). Corriger ceci demande un mecanisme
-- d'idempotence (cle fournie par le client, verifiee avant d'appliquer la
-- transaction) -- hors perimetre de cette tache, comme pour `apply_rest`.
--
-- Entrees : toutes deja resolues cote client, meme contrat que
-- `CharacterRepository.applyLevelUp` aujourd'hui (voir sa documentation) --
-- cette fonction ne recalcule ni [p_hp_rolled] ni [p_hp_gain]
-- (`LevelUpHitPointsCalculator`, reste cote Dart), ni les quotas de sorts/
-- invocations (deja appliques cote ecran avant d'arriver jusqu'ici).
--
-- Convention de wire de [p_choice] (jsonb, NOUVELLE -- ce RPC n'est pas
-- encore appele par le client Flutter, voir plus bas) :
--   {"kind": "ability_score_improvement" | "subclass" | "fighting_style" |
--            "favored_enemy" | "pact",
--    "ability_allocations": {"str": 1, "cha": 1} | null,  -- ASI uniquement
--    "feat_id": <int> | null,            -- ASI, sous-mode "don" uniquement
--    "feat_ability": "con" | null,       -- ASI, sous-mode "don" uniquement
--    "subclass_id": <int> | null,        -- kind = "subclass" uniquement
--    "class_feature_id": <int> | null,   -- fighting_style/favored_enemy/pact
--    "chosen_value": "<texte>" | null}   -- fighting_style/favored_enemy/pact
-- `kind` mappe directement les 5 valeurs de `LevelUpChoiceKind` (dart,
-- `domain/level_up_choice_kind.dart`) en snake_case -- a mapper
-- explicitement lors du futur branchement Flutter, jamais serialiser
-- l'enum Dart brut. `null` (pas d'objet du tout) si la montee de niveau ne
-- comporte aucun choix a cette etape (`choice == null` cote Dart).
--
-- Hors perimetre de cette migration : le branchement du client Flutter sur
-- cette fonction (chantier dev-flutter separe, comme pour
-- `create_character`/`apply_rest`).

create or replace function public.apply_level_up(
  p_character_id uuid,
  p_class_id int,
  p_class_name text,
  p_is_multiclassing boolean,
  p_hp_rolled int,
  p_hp_method text,
  p_hp_gain int,
  p_choice jsonb default null,
  p_initial_spell_ids int[] default '{}'::int[],
  p_invocation_ids int[] default '{}'::int[],
  p_racial_innate_spell_ids int[] default '{}'::int[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_classes_count int;
  v_existing_target_id uuid;
  v_existing_target_level int;
  v_new_class_level int;
  v_max_hp int;
  v_current_hp int;
  v_new_max_hp int;
  v_new_current_hp int;
  v_final_max_hp int;
  v_final_current_hp int;
  v_retroactive_hp int;
  v_ability_hp int;
  v_feat_name text;
  v_feat_ability_increase jsonb;
  v_feat_amount int;
  v_feat_max int;
  v_current_score int;
  v_new_score int;
  v_ability_id text;
  v_increase_text text;
  v_increase int;
  v_check_row record;
  v_totals int[];
  v_occultiste_level int;
  v_new_total_level int;
  v_spell_level int;
  v_pact_charges int;
  v_pact_slot_level int;
  v_kind text;
begin
  if v_owner_id is null then
    raise exception 'Authentification requise pour monter de niveau.';
  end if;

  if not exists (
    select 1 from public.characters
    where id = p_character_id and owner_id = v_owner_id
  ) then
    raise exception 'Personnage introuvable.';
  end if;

  -- 1. Classes actuelles du personnage (lecture, avant toute ecriture) --
  -- necessaire pour determiner si [p_class_id] est deja possedee et pour
  -- revalider les prerequis de multiclassage de TOUTES les classes (voir
  -- plus bas).
  select count(*) into v_classes_count
  from public.character_classes
  where character_id = p_character_id;

  if v_classes_count = 0 then
    raise exception 'Aucune classe trouvee pour ce personnage : impossible de monter de niveau.';
  end if;

  select cc.id, cc.level into v_existing_target_id, v_existing_target_level
  from public.character_classes cc
  where cc.character_id = p_character_id and cc.class_id = p_class_id
  limit 1;

  if p_is_multiclassing then
    if v_existing_target_id is not null then
      raise exception 'Ce personnage possede deja cette classe : impossible de la multiclasser a nouveau.';
    end if;

    -- Defense en profondeur, meme discipline que cote Dart
    -- (`MulticlassPrerequisites.meetsRequirement`, appelee la aussi en
    -- re-verification malgre le filtrage deja fait par l'UI) : revalide le
    -- prerequis de [p_class_name] ET de CHAQUE classe deja possedee (RAW :
    -- multiclasser exige de remplir le prerequis de la nouvelle classe ET
    -- de rester eligible a toutes les classes actuelles).
    for v_check_row in
      with existing_classes as (
        select cc.class_id, t.value as class_name
        from public.character_classes cc
        left join public.translations t
          on t.entity_type = 'class'
         and t.entity_id = cc.class_id::text
         and t.field_name = 'name'
         and t.locale = 'fr'
        where cc.character_id = p_character_id
      ),
      names_to_check as (
        select p_class_name as class_name, true as is_target
        union all
        select class_name, false from existing_classes
      ),
      scores as (
        select jsonb_object_agg(ability_id, score) as s
        from public.character_ability_scores
        where character_id = p_character_id
      ),
      requirements (class_name, clause_no, ability_id, min_score) as (
        values
          ('Barbare', 1, 'str', 13),
          ('Barde', 1, 'cha', 13),
          ('Clerc', 1, 'wis', 13),
          ('Druide', 1, 'wis', 13),
          ('Guerrier', 1, 'str', 13),
          ('Guerrier', 2, 'dex', 13),
          ('Moine', 1, 'dex', 13),
          ('Moine', 1, 'wis', 13),
          ('Paladin', 1, 'str', 13),
          ('Paladin', 1, 'cha', 13),
          ('Rôdeur', 1, 'dex', 13),
          ('Rôdeur', 1, 'wis', 13),
          ('Roublard', 1, 'dex', 13),
          ('Ensorceleur', 1, 'cha', 13),
          ('Occultiste', 1, 'cha', 13),
          ('Magicien', 1, 'int', 13)
      ),
      clauses_met as (
        select r.class_name, r.clause_no,
               bool_and(coalesce((s.s ->> r.ability_id)::int, 0) >= r.min_score) as clause_ok
        from requirements r, scores s
        group by r.class_name, r.clause_no
      ),
      class_meets as (
        select class_name, bool_or(clause_ok) as meets
        from clauses_met
        group by class_name
      )
      select n.class_name, n.is_target, cm.meets
      from names_to_check n
      left join class_meets cm on cm.class_name = n.class_name
      order by n.is_target desc
    loop
      if v_check_row.class_name is null then
        raise exception 'Impossible de verifier les prerequis d''une classe deja possedee : multiclassage refuse par prudence.';
      end if;
      if not coalesce(v_check_row.meets, false) then
        if v_check_row.is_target then
          raise exception 'Prerequis de caracteristique non rempli pour ''%'' : multiclassage refuse.', p_class_name;
        else
          raise exception 'Prerequis de caracteristique non rempli pour la classe deja possedee ''%'' : multiclassage refuse.', v_check_row.class_name;
        end if;
      end if;
    end loop;
  else
    if v_existing_target_id is null then
      raise exception 'Classe introuvable pour ce personnage : impossible de monter de niveau.';
    end if;
  end if;

  v_new_class_level := coalesce(v_existing_target_level, 0) + 1;

  -- 2. `characters` : PV max/courants incrementes de [p_hp_gain] (deja
  -- calcule cote client, voir le commentaire de tete).
  select max_hp, current_hp into v_max_hp, v_current_hp
  from public.characters where id = p_character_id;

  v_new_max_hp := v_max_hp + p_hp_gain;
  v_new_current_hp := v_current_hp + p_hp_gain;

  update public.characters
     set max_hp = v_new_max_hp, current_hp = v_new_current_hp
   where id = p_character_id and owner_id = v_owner_id;

  -- 3. `character_classes` : nouvelle ligne (multiclassage, niveau 1,
  -- jamais primaire) ou mise a jour du niveau de la classe existante. Le
  -- choix "sous-classe" (s'il y en a un a ce niveau) est combine dans la
  -- MEME ecriture plutot qu'un appel separe, meme choix que cote Dart.
  if p_is_multiclassing then
    insert into public.character_classes (
      character_id, class_id, level, is_primary, hit_dice_spent, subclass_id
    ) values (
      p_character_id, p_class_id, 1, false, 0,
      case when p_choice is not null and p_choice ->> 'kind' = 'subclass'
           then (p_choice ->> 'subclass_id')::int else null end
    );
  else
    update public.character_classes
       set level = v_new_class_level,
           subclass_id = case when p_choice is not null and p_choice ->> 'kind' = 'subclass'
                              then (p_choice ->> 'subclass_id')::int else subclass_id end
     where id = v_existing_target_id;
  end if;

  -- 4. Emplacements de sorts classiques ET magie de pacte de l'Occultiste,
  -- recalcules depuis les classes du personnage APRES l'ecriture ci-dessus
  -- (la table `character_classes` reflete deja le nouvel etat -- requetee
  -- directement plutot que reconstruite en memoire, contrairement a
  -- `afterClasses` cote Dart). Resolution de nom : voir le commentaire de
  -- tete (classe CIBLE = [p_class_name], toutes les autres via
  -- `translations`). `slots_used`/charges existantes PRESERVEES et
  -- PLAFONNEES au nouveau total (jamais remises a 0 -- voir le commentaire
  -- de tete pour la difference avec `apply_rest`).
  with full_caster_table (lvl, slots) as (
    values
      (1, array[2,0,0,0,0,0,0,0,0]),
      (2, array[3,0,0,0,0,0,0,0,0]),
      (3, array[4,2,0,0,0,0,0,0,0]),
      (4, array[4,3,0,0,0,0,0,0,0]),
      (5, array[4,3,2,0,0,0,0,0,0]),
      (6, array[4,3,3,0,0,0,0,0,0]),
      (7, array[4,3,3,1,0,0,0,0,0]),
      (8, array[4,3,3,2,0,0,0,0,0]),
      (9, array[4,3,3,3,1,0,0,0,0]),
      (10, array[4,3,3,3,2,0,0,0,0]),
      (11, array[4,3,3,3,2,1,0,0,0]),
      (12, array[4,3,3,3,2,1,0,0,0]),
      (13, array[4,3,3,3,2,1,1,0,0]),
      (14, array[4,3,3,3,2,1,1,0,0]),
      (15, array[4,3,3,3,2,1,1,1,0]),
      (16, array[4,3,3,3,2,1,1,1,0]),
      (17, array[4,3,3,3,2,1,1,1,1]),
      (18, array[4,3,3,3,3,1,1,1,1]),
      (19, array[4,3,3,3,3,2,1,1,1]),
      (20, array[4,3,3,3,3,2,2,1,1])
  ),
  half_caster_table (lvl, slots) as (
    values
      (1, array[0,0,0,0,0,0,0,0,0]),
      (2, array[2,0,0,0,0,0,0,0,0]),
      (3, array[3,0,0,0,0,0,0,0,0]),
      (4, array[3,0,0,0,0,0,0,0,0]),
      (5, array[4,2,0,0,0,0,0,0,0]),
      (6, array[4,2,0,0,0,0,0,0,0]),
      (7, array[4,3,0,0,0,0,0,0,0]),
      (8, array[4,3,0,0,0,0,0,0,0]),
      (9, array[4,3,2,0,0,0,0,0,0]),
      (10, array[4,3,2,0,0,0,0,0,0]),
      (11, array[4,3,3,0,0,0,0,0,0]),
      (12, array[4,3,3,0,0,0,0,0,0]),
      (13, array[4,3,3,1,0,0,0,0,0]),
      (14, array[4,3,3,1,0,0,0,0,0]),
      (15, array[4,3,3,2,0,0,0,0,0]),
      (16, array[4,3,3,2,0,0,0,0,0]),
      (17, array[4,3,3,3,1,0,0,0,0]),
      (18, array[4,3,3,3,1,0,0,0,0]),
      (19, array[4,3,3,3,2,0,0,0,0]),
      (20, array[4,3,3,3,2,0,0,0,0])
  ),
  after_classes as (
    select
      case when cc.class_id = p_class_id then p_class_name
           else coalesce(t.value, '') end as class_name,
      cc.level as lvl
    from public.character_classes cc
    left join public.translations t
      on t.entity_type = 'class'
     and t.entity_id = cc.class_id::text
     and t.field_name = 'name'
     and t.locale = 'fr'
    where cc.character_id = p_character_id
  ),
  caster_classes as (
    select lvl,
      case
        when class_name in ('Barde', 'Clerc', 'Druide', 'Magicien', 'Ensorceleur') then 'full'
        when class_name in ('Paladin', 'Rôdeur') then 'half'
      end as caster_type
    from after_classes
    where class_name in ('Barde', 'Clerc', 'Druide', 'Magicien', 'Ensorceleur', 'Paladin', 'Rôdeur')
  ),
  agg as (
    select
      count(*) as caster_count,
      coalesce(sum(lvl) filter (where caster_type = 'full'), 0) as full_sum,
      coalesce(sum(lvl) filter (where caster_type = 'half'), 0) as half_sum,
      (array_agg(lvl))[1] as single_level,
      (array_agg(caster_type))[1] as single_type
    from caster_classes
  )
  select
    case
      when agg.caster_count = 0 then array_fill(0, array[9])
      when agg.caster_count = 1 and agg.single_type = 'full' then
        (select slots from full_caster_table where lvl = agg.single_level)
      when agg.caster_count = 1 and agg.single_type = 'half' then
        (select slots from half_caster_table where lvl = agg.single_level)
      else
        coalesce(
          (select slots from full_caster_table
           where lvl = least(20, agg.full_sum + (agg.half_sum / 2))),
          array_fill(0, array[9])
        )
    end,
    (select lvl from after_classes where class_name = 'Occultiste' limit 1),
    (select coalesce(sum(lvl), 0) from after_classes)
    into v_totals, v_occultiste_level, v_new_total_level
  from agg;

  for v_spell_level in 1..9 loop
    if v_totals[v_spell_level] > 0 then
      insert into public.character_spell_slots (character_id, slot_level, slots_total, slots_used)
      values (p_character_id, v_spell_level, v_totals[v_spell_level], 0)
      on conflict (character_id, slot_level) do update
        set slots_total = excluded.slots_total,
            slots_used = least(public.character_spell_slots.slots_used, excluded.slots_total);
    end if;
  end loop;

  if v_occultiste_level is not null then
    select charges, slot_level into v_pact_charges, v_pact_slot_level
    from (
      values
        (1, 1, 1), (2, 2, 1), (3, 2, 2), (4, 2, 2), (5, 2, 3),
        (6, 2, 3), (7, 2, 4), (8, 2, 4), (9, 2, 5), (10, 2, 5),
        (11, 3, 5), (12, 3, 5), (13, 3, 5), (14, 3, 5), (15, 3, 5),
        (16, 3, 5), (17, 4, 5), (18, 4, 5), (19, 4, 5), (20, 4, 5)
    ) as pact_magic_table(lvl, charges, slot_level)
    where lvl = v_occultiste_level;

    if v_pact_charges is not null then
      insert into public.character_pact_slots (character_id, slot_level, slots_total, slots_used)
      values (p_character_id, v_pact_slot_level, v_pact_charges, 0)
      on conflict (character_id) do update
        set slot_level = excluded.slot_level,
            slots_total = excluded.slots_total,
            slots_used = least(public.character_pact_slots.slots_used, excluded.slots_total);
    end if;
  end if;

  -- 5. Le choix de cette etape (ASI/don, style de combat/ennemi jure/pacte,
  -- ou rien pour une sous-classe -- deja ecrite a l'etape 3) -- branches
  -- mutuellement exclusives, voir [LevelUpChoiceSelection] cote Dart.
  v_retroactive_hp := 0;
  if p_choice is not null then
    v_kind := p_choice ->> 'kind';
    case v_kind
      when 'subclass' then
        v_retroactive_hp := 0;

      when 'ability_score_improvement' then
        if (p_choice ->> 'feat_id') is not null then
          -- Don choisi en alternative a l'ASI.
          insert into public.character_feats (character_id, feat_id, level_taken)
          values (p_character_id, (p_choice ->> 'feat_id')::int, v_new_class_level);

          select t.value into v_feat_name
          from public.translations t
          where t.entity_type = 'feat'
            and t.entity_id = (p_choice ->> 'feat_id')
            and t.field_name = 'name'
            and t.locale = 'fr'
          limit 1;

          v_ability_hp := 0;
          if (p_choice ->> 'feat_ability') is not null then
            select ability_increase into v_feat_ability_increase
            from public.feats where id = (p_choice ->> 'feat_id')::int;

            if v_feat_ability_increase is not null
               and v_feat_ability_increase -> 'abilities' ? (p_choice ->> 'feat_ability') then
              v_feat_amount := coalesce((v_feat_ability_increase ->> 'amount')::int, 1);
              v_feat_max := coalesce((v_feat_ability_increase ->> 'max')::int, 20);

              select score into v_current_score
              from public.character_ability_scores
              where character_id = p_character_id and ability_id = (p_choice ->> 'feat_ability');

              if v_current_score is not null then
                v_new_score := greatest(v_current_score, least(v_current_score + v_feat_amount, v_feat_max));
                if v_new_score <> v_current_score then
                  update public.character_ability_scores
                     set score = v_new_score
                   where character_id = p_character_id and ability_id = (p_choice ->> 'feat_ability');

                  insert into public.character_ability_increases (character_id, level, ability_id, increase, source)
                  values (p_character_id, v_new_class_level, (p_choice ->> 'feat_ability'), v_new_score - v_current_score, 'feat');

                  if (p_choice ->> 'feat_ability') = 'con' then
                    v_ability_hp := (floor((v_new_score - 10) / 2.0)::int - floor((v_current_score - 10) / 2.0)::int) * v_new_total_level;
                  end if;
                end if;
              end if;
            end if;
          end if;

          v_retroactive_hp := v_ability_hp + case v_feat_name
            when 'Robuste physiquement' then 2 * v_new_total_level
            when 'Faveur de robustesse' then 40
            else 0
          end;
        else
          if (p_choice -> 'ability_allocations') is null
             or (select count(*) from jsonb_each_text(p_choice -> 'ability_allocations')) = 0 then
            raise exception 'Choix de montee de niveau invalide : ni don ni repartition de caracteristiques fournie pour une amelioration de caracteristique.';
          end if;

          for v_ability_id, v_increase_text in
            select key, value from jsonb_each_text(p_choice -> 'ability_allocations')
          loop
            v_increase := v_increase_text::int;

            select score into v_current_score
            from public.character_ability_scores
            where character_id = p_character_id and ability_id = v_ability_id;

            if v_current_score is null then
              raise exception 'Score actuel introuvable pour la caracteristique ''%'' : impossible d''appliquer l''augmentation de caracteristique.', v_ability_id;
            end if;

            v_new_score := v_current_score + v_increase;
            if v_new_score > 20 then
              raise exception 'Caracteristique ''%'' deja a % : impossible de depasser le plafond de 20.', v_ability_id, v_current_score;
            end if;

            update public.character_ability_scores
               set score = v_new_score
             where character_id = p_character_id and ability_id = v_ability_id;

            insert into public.character_ability_increases (character_id, level, ability_id, increase, source)
            values (p_character_id, v_new_class_level, v_ability_id, v_increase, 'asi');

            if v_ability_id = 'con' then
              v_retroactive_hp := v_retroactive_hp +
                (floor((v_new_score - 10) / 2.0)::int - floor((v_current_score - 10) / 2.0)::int) * v_new_total_level;
            end if;
          end loop;
        end if;

      when 'fighting_style', 'favored_enemy', 'pact' then
        insert into public.character_class_options (character_id, class_feature_id, level, chosen_value)
        values (p_character_id, (p_choice ->> 'class_feature_id')::int, v_new_class_level, p_choice ->> 'chosen_value');
        v_retroactive_hp := 0;

      else
        raise exception 'Choix de montee de niveau invalide : type ''%'' inconnu.', v_kind;
    end case;
  end if;

  if v_retroactive_hp <> 0 then
    v_final_max_hp := v_new_max_hp + v_retroactive_hp;
    v_final_current_hp := v_new_current_hp + v_retroactive_hp;
    update public.characters
       set max_hp = v_final_max_hp, current_hp = v_final_current_hp
     where id = p_character_id and owner_id = v_owner_id;
  else
    v_final_max_hp := v_new_max_hp;
    v_final_current_hp := v_new_current_hp;
  end if;

  -- 6. Sorts de depart d'une nouvelle classe "a sorts connus" (statut via
  -- `SpellcastingRules.statusFor` -- 'prepare' pour Clerc/Druide/Magicien/
  -- Paladin, 'connu' sinon), invocations occultistes nouvellement
  -- choisies, et sorts innes raciaux devenus accessibles (reverifies contre
  -- les sorts deja connus, dedupliques -- jamais un sort deja connu
  -- reecrit).
  if array_length(p_initial_spell_ids, 1) > 0 then
    insert into public.character_spells (character_id, spell_id, status, source_class_id)
    select p_character_id, x.spell_id,
           case when p_class_name in ('Clerc', 'Druide', 'Magicien', 'Paladin') then 'préparé' else 'connu' end,
           p_class_id
    from unnest(p_initial_spell_ids) as x(spell_id);
  end if;

  if array_length(p_invocation_ids, 1) > 0 then
    insert into public.character_invocations (character_id, invocation_id)
    select p_character_id, x.invocation_id
    from unnest(p_invocation_ids) as x(invocation_id);
  end if;

  if array_length(p_racial_innate_spell_ids, 1) > 0 then
    insert into public.character_spells (character_id, spell_id, status, source_class_id)
    select p_character_id, x.spell_id, 'inné', null
    from (select distinct unnest(p_racial_innate_spell_ids) as spell_id) as x
    where not exists (
      select 1 from public.character_spells cs
      where cs.character_id = p_character_id and cs.spell_id = x.spell_id
    );
  end if;

  -- 7. Historique PV du niveau, toujours en dernier (pur historique, voir
  -- le commentaire de tete de `create_character` pour le meme rationale
  -- d'ordonnancement -- ici sans portee, une seule transaction).
  insert into public.character_level_hp (character_id, level, hp_rolled, method)
  values (p_character_id, v_new_total_level, p_hp_rolled, p_hp_method);

  return jsonb_build_object(
    'new_level', v_new_total_level,
    'new_max_hp', v_final_max_hp,
    'new_current_hp', v_final_current_hp
  );
end;
$function$;

-- Voir le commentaire de tete (meme piege de privileges par defaut sur ce
-- projet, deja documente trois fois) : revoke explicite de anon ET
-- authenticated ET public, puis grant a authenticated seul.
revoke execute on function public.apply_level_up(
  uuid, int, text, boolean, int, text, int, jsonb, int[], int[], int[]
) from anon, authenticated, public;

grant execute on function public.apply_level_up(
  uuid, int, text, boolean, int, text, int, jsonb, int[], int[], int[]
) to authenticated;

comment on function public.apply_level_up(
  uuid, int, text, boolean, int, text, int, jsonb, int[], int[], int[]
) is
  'Applique une montee de niveau (continuation ou multiclassage, avec choix associe) en une seule transaction -- D05 du registre de dette technique mobile (ecritures multi-etapes non atomiques), dernier morceau apres create_character (20261007110000) et apply_rest (20261008100000). SECURITY DEFINER, verifie owner_id = auth.uid() sur p_character_id en tout premier (jamais un parametre owner_id). EXECUTE restreint a authenticated (revoke explicite anon/authenticated/public puis grant authenticated). Porte MulticlassPrerequisites (revalidation des prerequis de multiclassage, defense en profondeur), SpellSlotProgression (emplacements de sorts + magie de pacte, PRESERVES/PLAFONNES et non remis a zero -- different d''apply_rest, voir le commentaire de tete), SpellcastingRules.statusFor, et le sous-ensemble de HitPointBonusRules reellement necessaire cote serveur (constitutionRetroactiveBonus, featTakenBonus) -- perLevelBonus (Nain des collines/don deja pris/Lignage draconique) reste cote client, deja inclus dans p_hp_gain ; MulticlassProficiencies n''est jamais porte (purement textuel/affichage, jamais persiste). PIEGE CONNU NON RESOLU, PLUS ETENDU QUE SUR apply_rest : non idempotente sur plusieurs fronts (PV, historique de niveau, sorts/choix ASI) -- un retry client apres succes serveur perdu rejoue ces ecritures (deja documente dans le registre de dette mobile) -- correction hors perimetre. Pas encore appele par le client Flutter : branchement hors perimetre de la migration qui introduit cette fonction. Voir le commentaire de tete pour la convention de wire complete de p_choice (jsonb).';
