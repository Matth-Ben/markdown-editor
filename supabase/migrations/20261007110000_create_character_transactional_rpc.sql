-- Chantier "Personnages" (app mobile) -- D05 du registre de dette technique
-- mobile (docs/dette-technique.md, depot nexus-jdr-app-mobile) : les
-- ecritures multi-etapes de la creation/montee de niveau/repos cote client
-- Flutter ne sont pas atomiques. `CharacterCreationRepository.createCharacter`
-- enchaine aujourd'hui 13 appels HTTP sequentiels (characters, puis jusqu'a 9
-- tables enfant) avec un nettoyage "best effort" du personnage si une etape
-- echoue en cours de route -- une coupure reseau au milieu laisse parfois un
-- personnage a moitie cree (ex. sans sa classe, sans ses sorts) que le
-- nettoyage lui-meme peut ne jamais atteindre si LUI echoue aussi.
--
-- Portee de cette migration : SEULEMENT `create_character`. Les deux autres
-- fonctions demandees par D05 (`apply_level_up`, `apply_rest`) sont
-- volontairement laissees pour une PR separee -- voir la discussion complete
-- dans le rapport de tache, resumee ici pour qui relit cette migration seule :
-- - `create_character` ne fait QUE sequencer des ecritures dont la valeur est
--   deja entierement resolue cote client (scores de caracteristiques finaux,
--   equipement resolu, sorts/competences/outils resolus, PV max calcules) --
--   exactement ce que fait deja `CharacterCreationRepository.createCharacter`
--   avant chacun de ses appels reseau. Porter cette fonction en SQL ne duplique
--   donc aucune regle de jeu : elle est un pur sequenceur, sur UNE SEULE
--   nouvelle ligne `characters` et ses tables enfant.
-- - `apply_level_up` et `apply_rest` dependent en revanche de
--   `SpellSlotProgression.totalsForClasses`/`pactMagicFor` (tables de
--   progression d'emplacements de sorts par classe/niveau, y compris le
--   niveau de lanceur combine multiclasse) et, pour `apply_level_up`, de
--   `MulticlassPrerequisites`/`SpellcastingRules.statusFor` : des regles de
--   jeu actuellement codees cote Dart uniquement. Les porter fidelement en
--   SQL est un chantier a part entiere (et un risque de divergence avec le
--   Dart existant -- le registre de dette documente deja cette meme classe de
--   duplication ailleurs, voir D04), qui merite sa propre PR et sa propre
--   revue plutot que d'etre improvise dans celle-ci.
-- - `apply_rest` a de plus un piege specifique au-dela de la seule atomicite,
--   deja identifie dans le registre : la recuperation des des de vie au repos
--   long est un calcul RELATIF
--   (`hit_dice_spent = max(0, hit_dice_spent - max(1, level / 2))`). Rendre
--   l'ecriture atomique (tout ou rien) protege contre un ECHEC partiel, mais
--   PAS contre un succes serveur suivi d'une re-tentative client (ex. reponse
--   perdue apres un timeout reseau) : un appel REJOUE d'une transaction deja
--   committee recupererait les des de vie une seconde fois, exactement le
--   meme bug qu'aujourd'hui, par un chemin different. Une vraie correction
--   demande un mecanisme d'idempotence (cle d'idempotence fournie par le
--   client, verifiee avant d'appliquer la transaction) -- une decision de
--   conception a part entiere, hors de portee d'une simple transaction SQL.
--
-- Isolation : SECURITY DEFINER (la fonction ecrit dans `characters` et ses
-- tables enfant pour le compte de l'appelant, sans passer par les policies
-- RLS -- comme `owns_character`/`build_character_sheet_json`), mais la ligne
-- `characters` est TOUJOURS creee avec `owner_id = auth.uid()` (jamais un
-- parametre fourni par l'appelant) : aucune elevation de privilege possible,
-- un appelant ne peut creer un personnage que pour lui-meme, exactement
-- comme le `with check (auth.uid() = owner_id)` des policies qu'elle
-- contourne.
--
-- Privileges EXECUTE : piege deja documente deux fois dans ce depot
-- (20260908094500, 20261007090000) -- ce projet Supabase applique des
-- `alter default privileges ... grant ... to anon, authenticated,
-- service_role` qui accordent EXECUTE directement a `anon`/`authenticated`
-- sur toute fonction nouvellement creee, pas seulement a PUBLIC. Un simple
-- `revoke ... from public` ne suffit donc jamais : il faut revoquer
-- explicitement de CHAQUE role, puis regrant uniquement `authenticated` (une
-- creation de personnage n'a aucun sens pour `anon`, `auth.uid()` y vaut
-- toujours NULL).
--
-- Atomicite : un appel RPC PostgREST (`supabase_flutter`, `.rpc(...)`)
-- s'execute dans sa propre transaction, une par requete HTTP. Une exception
-- non interceptee a l'interieur du corps PL/pgSQL annule TOUTE la transaction
-- en cours, donc TOUTES les ecritures deja faites par cet appel -- aucun
-- `begin`/`commit` explicite n'est necessaire (impossible, d'ailleurs, dans
-- une simple fonction) et surtout AUCUN bloc `exception when others` n'est
-- ajoute ici : avaler une exception romprait precisement la garantie
-- recherchee (une erreur masquee laisserait croire a l'appelant que la
-- creation a reussi, ou pire, laisserait une transaction partiellement
-- validee via une sous-transaction/savepoint si on en ajoutait une sans
-- precaution). Les contraintes `not null`/`check`/FK des tables existantes
-- restent le dernier filet de securite, comme avant.
--
-- Entrees : toutes deja resolues cote client, meme contrat que
-- `CharacterCreationRepository.createCharacter` aujourd'hui (voir sa
-- documentation, lib/features/character_creation/data/
-- character_creation_repository.dart) -- cette fonction ne recalcule RIEN
-- (pas de score de caracteristique final, pas de PV max, pas de resolution
-- d'equipement). Les listes (scores de caracteristiques, competences,
-- outils, choix de race, sorts, inventaire) voyagent en `jsonb` (tableau
-- d'objets) plutot qu'en une dizaine de parametres positionnels distincts,
-- pour rester lisible et pour que l'appelant puisse omettre un champ
-- optionnel par objet (ex. `tool_id` ou `custom_text`) sans avoir a aligner
-- plusieurs tableaux paralleles par position.
--
-- Non couvert par cette fonction, a l'identique du comportement actuel de
-- `createCharacter` (pas une regression introduite ici) :
-- `characters.background_custom_text` n'est ecrit par aucun des deux chemins
-- -- gap pre-existant, pas corrige au passage pour rester strictement dans le
-- perimetre de cette tache (atomicite, pas correction de regle produit).
--
-- Hors perimetre de cette migration : le branchement du client Flutter sur
-- cette fonction (chantier dev-flutter separe, une fois cette migration
-- appliquee et validee).

create or replace function public.create_character(
  p_name text,
  p_class_id int,
  p_hp_rolled int,
  p_max_hp int,
  p_hp_method text default 'moyenne',
  p_race_id int default null,
  p_subrace_id int default null,
  p_lineage_id int default null,
  p_race_custom_text text default null,
  p_background_id int default null,
  p_alignment_id int default null,
  p_subclass_id int default null,
  p_sexe text default null,
  p_age text default null,
  p_height text default null,
  p_weight text default null,
  p_eyes text default null,
  p_skin text default null,
  p_hair text default null,
  p_appearance_text text default null,
  p_traits_text text default null,
  p_ideals_text text default null,
  p_bonds_text text default null,
  p_flaws_text text default null,
  p_backstory_text text default null,
  p_allies_text text default null,
  p_features_text text default null,
  p_treasure_text text default null,
  p_currency_gp int default 0,
  p_ability_scores jsonb default '[]'::jsonb,
  p_skill_proficiencies jsonb default '[]'::jsonb,
  p_tool_proficiencies jsonb default '[]'::jsonb,
  p_race_choices jsonb default '[]'::jsonb,
  p_language_ids int[] default '{}'::int[],
  p_spells jsonb default '[]'::jsonb,
  p_inventory jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_owner_id uuid := auth.uid();
  v_character_id uuid;
begin
  if v_owner_id is null then
    raise exception 'Authentification requise pour creer un personnage.';
  end if;

  if p_name is null or btrim(p_name) = '' then
    raise exception 'Le nom du personnage est obligatoire.';
  end if;

  if p_class_id is null then
    raise exception 'La classe est obligatoire pour creer un personnage.';
  end if;

  -- 1. `characters` -- toujours en premier : chaque table enfant ci-dessous
  -- reference `v_character_id`, rien d'autre ne peut etre ecrit avant elle.
  -- `owner_id` vient exclusivement de `auth.uid()`, jamais d'un parametre.
  insert into public.characters (
    owner_id, name, race_id, subrace_id, lineage_id, race_custom_text,
    background_id, alignment_id, xp, max_hp, current_hp, temporary_hp,
    sexe, age, height, weight, eyes, skin, hair, portrait_url,
    appearance_text, traits_text, ideals_text, bonds_text, flaws_text,
    backstory_text, allies_text, features_text, treasure_text,
    currency_gp, currency_pp, currency_ep, currency_sp, currency_cp
  ) values (
    v_owner_id, p_name, p_race_id, p_subrace_id, p_lineage_id, p_race_custom_text,
    p_background_id, p_alignment_id, 0, p_max_hp, p_max_hp, 0,
    p_sexe, p_age, p_height, p_weight, p_eyes, p_skin, p_hair, null,
    -- `characters.*_text` sont `not null default ''` en base (voir
    -- `CharacterCreationRepository.createCharacter`, meme coalescence) :
    -- jamais un `null` litteral ecrit sur ces 9 colonnes.
    coalesce(p_appearance_text, ''), coalesce(p_traits_text, ''),
    coalesce(p_ideals_text, ''), coalesce(p_bonds_text, ''),
    coalesce(p_flaws_text, ''), coalesce(p_backstory_text, ''),
    coalesce(p_allies_text, ''), coalesce(p_features_text, ''),
    coalesce(p_treasure_text, ''),
    coalesce(p_currency_gp, 0), 0, 0, 0, 0
  )
  returning id into v_character_id;

  -- 2. Classe de depart, niveau 1, toujours primaire (une creation ne peut
  -- jamais commencer multiclassee).
  insert into public.character_classes (
    character_id, class_id, subclass_id, level, is_primary
  ) values (
    v_character_id, p_class_id, p_subclass_id, 1, true
  );

  -- 3. Historique PV niveau 1 (voir `createCharacter` : methode toujours
  -- 'moyenne' au niveau 1, calcul deterministe cote Dart, jamais un lance de
  -- de).
  insert into public.character_level_hp (character_id, level, hp_rolled, method)
  values (v_character_id, 1, p_hp_rolled, p_hp_method);

  -- 4. Scores de caracteristiques finaux (deja resolus par
  -- `FinalAbilityScoresResolver` cote client).
  if jsonb_array_length(p_ability_scores) > 0 then
    insert into public.character_ability_scores (character_id, ability_id, score)
    select v_character_id, x.ability_id, x.score
    from jsonb_to_recordset(p_ability_scores) as x(ability_id text, score int)
    on conflict (character_id, ability_id) do nothing;
  end if;

  -- 5. Competences (classe + historique + race, deja fusionnees/dedupliquees
  -- par `SkillProficiencyResolver.resolve` cote client).
  if jsonb_array_length(p_skill_proficiencies) > 0 then
    insert into public.character_skill_proficiencies (character_id, skill_id, proficiency)
    select v_character_id, x.skill_id, coalesce(x.proficiency, 'aucune')
    from jsonb_to_recordset(p_skill_proficiencies) as x(skill_id int, proficiency text)
    on conflict (character_id, skill_id) do nothing;
  end if;

  -- 6. Outils (resolus par `ToolProficiencyResolver.resolve` cote client ;
  -- `tool_id`/`custom_text` mutuellement non-exclusifs ici, la contrainte
  -- `character_tool_proficiencies_tool_or_custom` de la table exige au moins
  -- l'un des deux par ligne).
  if jsonb_array_length(p_tool_proficiencies) > 0 then
    insert into public.character_tool_proficiencies (character_id, tool_id, custom_text)
    select v_character_id, x.tool_id, x.custom_text
    from jsonb_to_recordset(p_tool_proficiencies) as x(tool_id int, custom_text text);
  end if;

  -- 7. Tracage de la source "race" pour une competence/outil a choix (carte
  -- "CHOIX DE RACE" de la fiche) -- n'ecrit jamais dans les deux tables
  -- generiques ci-dessus (deja fait aux etapes 5/6), voir
  -- `20261005150000_create_character_race_choices.sql`.
  if jsonb_array_length(p_race_choices) > 0 then
    insert into public.character_race_choices (character_id, kind, skill_id, tool_id)
    select v_character_id, x.kind, x.skill_id, x.tool_id
    from jsonb_to_recordset(p_race_choices) as x(kind text, skill_id int, tool_id int);
  end if;

  -- 8. Langues (historique + commun systematique, deja dedupliquees par un
  -- `Set` cote client -- `on conflict do nothing` garde cette garantie cote
  -- serveur par prudence plutot que de faire echouer toute la creation pour
  -- un doublon sans consequence).
  if p_language_ids is not null and array_length(p_language_ids, 1) > 0 then
    insert into public.character_languages (character_id, language_id)
    select v_character_id, lang_id
    from unnest(p_language_ids) as lang_id
    on conflict (character_id, language_id) do nothing;
  end if;

  -- 9. Sorts -- classe ET innes raciaux dans le MEME tableau (meme table,
  -- memes colonnes ; seuls `status`/`source_class_id` different, deja
  -- resolus par l'appelant : 'inne'/`source_class_id null` pour un sort
  -- racial, 'connu'/'prepare' + l'id de classe sinon -- voir
  -- `SpellSelectionResolver`/`RacialInnateSpellRepository` cote client).
  if jsonb_array_length(p_spells) > 0 then
    insert into public.character_spells (character_id, spell_id, status, source_class_id)
    select v_character_id, x.spell_id, x.status, x.source_class_id
    from jsonb_to_recordset(p_spells) as x(spell_id int, status text, source_class_id int);
  end if;

  -- 10. Equipement de depart (deja resolu par
  -- `CharacterCreationEquipmentResolver.resolve` cote client -- historique ou
  -- achat, arme naturelle de race incluse).
  if jsonb_array_length(p_inventory) > 0 then
    insert into public.character_inventory (character_id, item_id, custom_name, quantity, equipped, notes)
    select v_character_id, x.item_id, x.custom_name, coalesce(x.quantity, 1), coalesce(x.equipped, false), null
    from jsonb_to_recordset(p_inventory) as x(item_id int, custom_name text, quantity int, equipped boolean);
  end if;

  return v_character_id;
end;
$function$;

-- Voir le commentaire de tete : le revoke/grant ci-dessous doit cibler
-- explicitement `anon` ET `authenticated`, pas seulement PUBLIC (defaut de
-- privileges de ce projet, meme cause que 20260908094500/20261007090000).
revoke execute on function public.create_character(
  text, int, int, int, text, int, int, int, text, int, int, int,
  text, text, text, text, text, text, text,
  text, text, text, text, text, text, text, text, text,
  int, jsonb, jsonb, jsonb, jsonb, int[], jsonb, jsonb
) from anon, authenticated, public;

grant execute on function public.create_character(
  text, int, int, int, text, int, int, int, text, int, int, int,
  text, text, text, text, text, text, text,
  text, text, text, text, text, text, text, text, text,
  int, jsonb, jsonb, jsonb, jsonb, int[], jsonb, jsonb
) to authenticated;

comment on function public.create_character(
  text, int, int, int, text, int, int, int, text, int, int, int,
  text, text, text, text, text, text, text,
  text, text, text, text, text, text, text, text, text,
  int, jsonb, jsonb, jsonb, jsonb, int[], jsonb, jsonb
) is
  'Cree un personnage complet (characters + character_classes + character_level_hp + tables enfant optionnelles) en une seule transaction -- D05 du registre de dette technique mobile (ecritures multi-etapes non atomiques). SECURITY DEFINER, owner_id toujours fixe a auth.uid() (jamais un parametre), EXECUTE restreint a authenticated (revoke explicite de anon/authenticated/public puis grant a authenticated seul, meme precaution que 20261007090000 face aux privileges par defaut de ce projet). Ne recalcule aucune regle de jeu : toutes les valeurs (scores de caracteristiques finaux, PV max, equipement/sorts/competences/outils resolus) sont deja calculees par CharacterCreationRepository cote client, cette fonction ne fait que les ecrire atomiquement. N''initialise jamais character_spell_slots/character_pact_slots/character_feature_uses (gap preexistant, deja documente cote mobile pour applyLevelUp/applyRest, inchange ici). Ne touche pas a background_custom_text (non ecrit non plus par le chemin Dart actuel). Pas encore appele par le client Flutter : branchement hors perimetre de la migration qui introduit cette fonction.';
