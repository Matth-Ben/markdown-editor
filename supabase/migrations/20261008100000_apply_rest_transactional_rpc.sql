-- Chantier "Personnages" (app mobile) -- D05 du registre de dette technique
-- mobile (docs/dette-technique.md, depot nexus-jdr-app-mobile) : suite de
-- 20261007110000_create_character_transactional_rpc.sql (`create_character`),
-- qui laissait volontairement `apply_level_up` et `apply_rest` pour une PR
-- separee -- celle-ci porte `apply_rest` (lien "Prendre un repos", onglet
-- "Personnage" cote mobile, `CharacterRepository.applyRest`,
-- lib/features/characters/data/character_repository.dart ~L2679).
--
-- `apply_level_up` reste hors de cette migration -- voir la discussion
-- complete dans le rapport de tache, resumee ici pour qui relit cette
-- migration seule : contrairement a `apply_rest` (qui ne depend que d'UNE
-- seule table de regle de jeu, la progression des emplacements de sorts),
-- `apply_level_up` combine PLUSIEURS sous-systemes de regles actuellement
-- codes en Dart uniquement (`MulticlassPrerequisites` -- clauses OU/ET par
-- classe --, `HitPointBonusRules` -- formules de PV retroactifs qui
-- comparent des noms de dons/sous-classes resolus a la volee --,
-- `SpellcastingRules.statusFor`, en plus de la meme table de progression de
-- sorts que ci-dessous) ET plusieurs branches de choix mutuellement
-- exclusives (ASI vs demi-don vs style de combat/ennemi jure/pacte,
-- multiclassage vs continuation) ecrivant dans jusqu'a 9 tables differentes.
-- Porter fidelement cet ensemble demanderait de re-verifier chaque formule
-- et chaque table contre le Dart une a une dans la meme migration, avec un
-- risque de divergence subtile bien plus eleve qu'ici (ex. une erreur sur
-- `constitutionRetroactiveBonus` ou sur une clause de prerequis ne casse
-- rien de visible immediatement, contrairement a une erreur sur les des de
-- vie qui saute aux yeux) -- mieux vaut une fonction solide plutot que deux
-- bâclees. `apply_level_up` merite donc sa propre PR et sa propre revue.
--
-- Table de regle de jeu portee ici (et SEULEMENT celle-ci) :
-- `SpellSlotProgression` (lib/features/characters/domain/
-- spell_slot_progression.dart, dépôt mobile) -- tables `_fullCasterSlots`/
-- `_halfCasterSlots`/`_pactMagicSlots`, transcrites ligne a ligne ci-dessous
-- (donnees RAW 5e autoritaires, fournies par le chef de projet, non
-- re-verifiees ici -- meme convention que leur source Dart). Encodees en
-- CTE `values(...)` plutot qu'en fonctions SQL separees : toute nouvelle
-- fonction sur ce projet Supabase recoit EXECUTE par defaut pour
-- anon/authenticated (piege deja documente deux fois, 20260908094500 et
-- 20261007090000/20261007110000) -- une CTE locale a cette seule fonction
-- n'a pas ce probleme, pas de surface de privilege supplementaire a gerer.
--
-- Meme convention de nom de classe que le Dart (nom FRANCAIS resolu via
-- `translations`, locale 'fr' en dur -- `_locale` cote
-- `character_repository.dart`, toujours 'fr' a ce jour, Phase 1 socle
-- mono-langue) : AUCUNE regle de jeu ci-dessous ne cle sur `classes.id`, ces
-- id ne sont pas des constantes stables documentees (voir le commentaire de
-- classe de `SpellcastingRules` cote mobile).
--
-- Deux resolutions de nom DIFFERENTES, fidelement reproduites depuis
-- `applyRest` cote client (a ne jamais fusionner par souci de simplicite) :
-- 1. Pour le total d'emplacements de sorts (`character_spell_slots`) : la
--    classe PRIMAIRE est nommee par `p_primary_class_name` (parametre,
--    deja resolu par l'appelant -- `character_detail_screen.dart`,
--    `detail.primaryClass?.className ?? ''`), les autres classes du
--    personnage sont nommees via `translations`.
-- 2. Pour la detection de l'Occultiste (magie de pacte) : TOUJOURS via
--    `translations`, meme pour la classe primaire -- `p_primary_class_name`
--    n'intervient jamais dans cette detection (voir `restClassNames` cote
--    Dart, une map independante de `className`).
--
-- Isolation : SECURITY DEFINER (ecrit dans characters et plusieurs tables
-- enfant pour le compte de l'appelant, sans passer par les policies RLS),
-- mais la toute premiere chose faite est de verifier que `p_character_id`
-- appartient bien a `auth.uid()` -- jamais un parametre `owner_id` fourni
-- par l'appelant, exactement comme `create_character`.
--
-- Atomicite : aucun `begin`/`commit`/`exception when others` ici, meme
-- raisonnement que `create_character` (voir son commentaire de tete) -- une
-- exception non interceptee annule tout l'appel RPC.
--
-- PIEGE CONNU, VOLONTAIREMENT NON RESOLU ICI (deja documente dans le
-- registre de dette mobile, rappele explicitement a la demande de la tache
-- qui introduit cette migration) : cette fonction n'est PAS idempotente.
-- Un appel RPC PostgREST committe cote serveur dont la reponse HTTP est
-- perdue (coupure reseau, timeout) puis REJOUE par un retry client
-- produirait un second repos complet -- pour un repos COURT ou un repos
-- LONG sans consequence grave en pratique (les PV/emplacements sont
-- recalcules ou plafonnes, pas accumules). Le cas dangereux est la
-- recuperation des des de vie au repos LONG
-- (`hit_dice_spent = max(0, hit_dice_spent - max(1, level / 2))`) : un
-- calcul RELATIF a l'etat courant, donc un REJOUE recupererait une SECONDE
-- fois des des de vie deja recuperes par l'appel precedent, exactement le
-- meme bug qu'aujourd'hui cote client, par un chemin different -- rendre
-- l'ECRITURE atomique protege contre un ECHEC partiel, pas contre un
-- succes suivi d'une re-tentative. Une vraie correction demande un
-- mecanisme d'idempotence (cle fournie par le client, verifiee avant
-- d'appliquer la transaction) -- hors perimetre de cette tache.
--
-- Entrees : toutes deja resolues cote client, meme contrat que
-- `CharacterRepository.applyRest` aujourd'hui (voir sa documentation) --
-- cette fonction ne recalcule ni [p_dice_spent] ni [p_applied_gain]
-- (`HitDiceSpendCalculator`, reste cote Dart), seulement les emplacements
-- de sorts/magie de pacte/aptitudes rechargeables et les PV qui en
-- decoulent directement.
--
-- Hors perimetre, a l'identique du comportement actuel (pas une
-- regression introduite ici) : aucune verification que [p_rest_type] =
-- 'court' ne tente de restaurer des PV via un mecanisme autre que
-- [p_dice_spent]/[p_applied_gain] (deja entierement calcules cote appelant,
-- `RestSheetResult`) -- voir `RestType.short`.
--
-- Hors perimetre de cette migration : le branchement du client Flutter sur
-- cette fonction (chantier dev-flutter separe).

create or replace function public.apply_rest(
  p_character_id uuid,
  p_rest_type text,
  p_primary_class_name text default '',
  p_dice_spent int default 0,
  p_applied_gain int default 0
)
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_primary_row_id uuid;
  v_primary_class_id int;
  v_primary_level int;
  v_primary_hit_dice_spent int;
  v_new_hit_dice_spent int;
  v_max_hp int;
  v_current_hp int;
  v_new_current_hp int;
  v_occultiste_level int;
  v_pact_charges int;
  v_pact_slot_level int;
  v_totals int[];
  v_spell_level int;
begin
  if v_owner_id is null then
    raise exception 'Authentification requise pour appliquer un repos.';
  end if;

  if not exists (
    select 1 from public.characters
    where id = p_character_id and owner_id = v_owner_id
  ) then
    raise exception 'Personnage introuvable.';
  end if;

  if p_rest_type not in ('court', 'long') then
    raise exception 'Type de repos invalide : % (attendu ''court'' ou ''long'').', p_rest_type;
  end if;

  -- Classe primaire (une seule par personnage, character_classes.is_primary)
  -- -- sert uniquement au suivi des des de vie (comme cote Dart, decision
  -- produit en attente pour un personnage multiclasse) et, pour le repos
  -- long, a nommer la ligne primaire dans le calcul des emplacements de
  -- sorts ci-dessous. Toutes les variables restent NULL si aucune classe
  -- n'est marquee primaire -- chaque site d'utilisation garde deja `is not
  -- null`, meme convention que `primaryClassRow.isNotEmpty` cote Dart.
  select cc.id, cc.class_id, cc.level, cc.hit_dice_spent
    into v_primary_row_id, v_primary_class_id, v_primary_level, v_primary_hit_dice_spent
  from public.character_classes cc
  where cc.character_id = p_character_id and cc.is_primary
  limit 1;

  -- Occultiste parmi TOUTES les classes du personnage (primaire ou non,
  -- l'Occultiste peut etre une classe secondaire) -- resolu EXCLUSIVEMENT
  -- via `translations`, jamais via p_primary_class_name meme si l'Occultiste
  -- est la classe primaire (voir le commentaire de tete : deux resolutions
  -- de nom distinctes, fidelement reproduites depuis `restClassNames` cote
  -- Dart).
  select cc.level
    into v_occultiste_level
  from public.character_classes cc
  join public.translations t
    on t.entity_type = 'class'
   and t.entity_id = cc.class_id::text
   and t.field_name = 'name'
   and t.locale = 'fr'
  where cc.character_id = p_character_id
    and t.value = 'Occultiste'
  limit 1;

  if p_rest_type = 'long' then
    -- 1. Emplacements de sorts classiques (character_spell_slots),
    -- TOUTES les classes lanceuses "non-pacte" du personnage, niveau de
    -- lanceur combine si deux ou plus -- voir
    -- SpellSlotProgression.totalsForClasses cote Dart, transcrit ici via
    -- les CTE full_caster_table/half_caster_table (donnees RAW, voir le
    -- commentaire de tete). Classe primaire nommee par
    -- p_primary_class_name, les autres via translations (fallback '' si la
    -- traduction manque, meme convention que `restClassNames[...] ?? ''`
    -- cote Dart -- traitee comme non lanceuse, jamais une erreur).
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
    char_classes as (
      select
        case when cc.is_primary then p_primary_class_name
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
      select
        lvl,
        case
          when class_name in ('Barde', 'Clerc', 'Druide', 'Magicien', 'Ensorceleur') then 'full'
          when class_name in ('Paladin', 'Rôdeur') then 'half'
        end as caster_type
      from char_classes
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
      end
      into v_totals
    from agg;

    -- Upsert des niveaux de sort dont le total calcule est > 0
    -- (slots_total recalcule, slots_used TOUJOURS remis a 0 -- c'est tout
    -- le sens d'un repos long, voir `_resetSpellSlots` cote Dart).
    for v_spell_level in 1..9 loop
      if v_totals[v_spell_level] > 0 then
        insert into public.character_spell_slots (character_id, slot_level, slots_total, slots_used)
        values (p_character_id, v_spell_level, v_totals[v_spell_level], 0)
        on conflict (character_id, slot_level) do update
          set slots_total = excluded.slots_total,
              slots_used = 0;
      end if;
    end loop;

    -- Lignes existantes HORS calcul (total calcule a 0, ex. donnee heritee)
    -- : slots_total jamais touche, seul slots_used est remis a 0 s'il ne
    -- l'est pas deja -- meme filet de securite que `_resetSpellSlots`.
    update public.character_spell_slots
       set slots_used = 0
     where character_id = p_character_id
       and slots_used <> 0
       and slot_level = any(array(select g from generate_series(1, 9) g where v_totals[g] = 0));

    -- 2. Sorts innes raciaux lances sans emplacement (domain/
    -- innate_spell_usage.dart) : compteur remis a 0 au repos LONG
    -- uniquement -- avant la recuperation des des de vie (etape 3,
    -- RELATIVE et donc seule etape non rejouable, voir le piege documente
    -- en tete de cette migration).
    update public.character_spells
       set innate_uses_spent = 0
     where character_id = p_character_id
       and innate_uses_spent > 0;

    -- 3. Recuperation RAW 5e des des de vie, classe primaire uniquement.
    if v_primary_row_id is not null then
      v_new_hit_dice_spent := greatest(0, v_primary_hit_dice_spent - greatest(1, v_primary_level / 2));
      if v_new_hit_dice_spent <> v_primary_hit_dice_spent then
        update public.character_classes
           set hit_dice_spent = v_new_hit_dice_spent
         where id = v_primary_row_id;
      end if;
    end if;

    -- 4. PV courants au maximum, PV temporaires a 0, horodatage du dernier
    -- repos long (chantier "Notifications", alimente le rappel de repos
    -- long cote backend).
    select max_hp into v_max_hp from public.characters where id = p_character_id;
    update public.characters
       set current_hp = v_max_hp,
           temporary_hp = 0,
           last_long_rest_at = now()
     where id = p_character_id;

  elsif p_dice_spent > 0 then
    -- Repos court avec depense de des de vie (regle RAW 5e) : les des sont
    -- depenses que le jet restaure ou non des PV -- ces deux ecritures
    -- restent independantes l'une de l'autre, meme ordre que cote Dart.
    if v_primary_row_id is not null then
      v_new_hit_dice_spent := least(v_primary_level, v_primary_hit_dice_spent + p_dice_spent);
      update public.character_classes
         set hit_dice_spent = v_new_hit_dice_spent
       where id = v_primary_row_id;
    end if;

    if p_applied_gain > 0 then
      select current_hp, max_hp into v_current_hp, v_max_hp
      from public.characters where id = p_character_id;
      v_new_current_hp := least(v_current_hp + p_applied_gain, v_max_hp);
      update public.characters
         set current_hp = v_new_current_hp
       where id = p_character_id;
    end if;
  end if;

  -- 5. Magie de pacte de l'Occultiste (RAW 5e) : recharge au repos COURT
  -- ET long, contrairement aux emplacements classiques ci-dessus --
  -- toujours un reset complet (slots_used = 0), jamais une preservation
  -- clampee (contrairement a `_upsertPactSlot`, utilisee par
  -- `apply_level_up`, hors perimetre ici) -- voir `_resetPactSlot` cote
  -- Dart.
  if v_occultiste_level is not null then
    with pact_magic_table (lvl, charges, slot_level) as (
      values
        (1, 1, 1), (2, 2, 1), (3, 2, 2), (4, 2, 2), (5, 2, 3),
        (6, 2, 3), (7, 2, 4), (8, 2, 4), (9, 2, 5), (10, 2, 5),
        (11, 3, 5), (12, 3, 5), (13, 3, 5), (14, 3, 5), (15, 3, 5),
        (16, 3, 5), (17, 4, 5), (18, 4, 5), (19, 4, 5), (20, 4, 5)
    )
    select charges, slot_level into v_pact_charges, v_pact_slot_level
    from pact_magic_table where lvl = v_occultiste_level;

    if v_pact_charges is not null then
      insert into public.character_pact_slots (character_id, slot_level, slots_total, slots_used)
      values (p_character_id, v_pact_slot_level, v_pact_charges, 0)
      on conflict (character_id) do update
        set slot_level = excluded.slot_level,
            slots_total = excluded.slots_total,
            slots_used = 0;
    end if;
  end if;

  -- 6. Aptitudes a usage limite (character_feature_uses), TOUTES les
  -- classes du personnage (multiclassage inclus) atteintes par leur niveau
  -- respectif -- voir ClassFeatureRowMapper.filterAttained/_resetFeatureUses
  -- cote Dart. Repos long : toutes, quel que soit leur rest_type. Repos
  -- court : seulement celles dont uses_per_rest->>'rest_type' vaut
  -- 'repos_court'. Jamais de ligne ecrite pour une aptitude sans
  -- uses_per_rest (passive) ou sans 'amount' exploitable -- meme principe
  -- que `_rechargedAmount` cote Dart.
  insert into public.character_feature_uses (character_id, class_feature_id, uses_remaining)
  select p_character_id, cf.id, (cf.uses_per_rest ->> 'amount')::int
  from public.class_features cf
  join public.character_classes cc
    on cc.character_id = p_character_id
   and cc.class_id = cf.class_id
  where cf.level <= cc.level
    and cf.uses_per_rest is not null
    and (cf.uses_per_rest ->> 'amount') is not null
    and (
      p_rest_type = 'long'
      or (cf.uses_per_rest ->> 'rest_type') = 'repos_court'
    )
  on conflict (character_id, class_feature_id) do update
    set uses_remaining = excluded.uses_remaining;
end;
$function$;

-- Voir le commentaire de tete de 20261007110000_create_character_transactional_rpc.sql
-- (meme piege de privileges par defaut sur ce projet) : revoke explicite de
-- anon ET authenticated ET public, puis grant a authenticated seul.
revoke execute on function public.apply_rest(uuid, text, text, int, int)
  from anon, authenticated, public;

grant execute on function public.apply_rest(uuid, text, text, int, int)
  to authenticated;

comment on function public.apply_rest(uuid, text, text, int, int) is
  'Applique un repos (court ou long) en une seule transaction -- D05 du registre de dette technique mobile (ecritures multi-etapes non atomiques), suite de create_character (20261007110000). SECURITY DEFINER, verifie owner_id = auth.uid() sur p_character_id en tout premier (jamais un parametre owner_id). EXECUTE restreint a authenticated (revoke explicite anon/authenticated/public puis grant authenticated, meme precaution que 20261007110000/20261007090000). Porte la table de progression des emplacements de sorts (SpellSlotProgression, dépôt mobile) en CTE locales -- seule regle de jeu portee par cette migration, voir son commentaire de tete pour le detail et pour la raison du report d''apply_level_up a une PR separee. PIEGE CONNU NON RESOLU : non idempotente, un retry client apres succes serveur perdu rejoue la recuperation des des de vie au repos long (deja documente dans le registre de dette mobile) -- correction hors perimetre (mecanisme d''idempotence a concevoir separement). Pas encore appele par le client Flutter : branchement hors perimetre de la migration qui introduit cette fonction.';
