-- Chantier "Personnages" (app mobile) -- contenu D&D, lot 1.
-- Complète public.races / public.subraces à partir de races.json / subraces.json
-- (recoupement Aidedd / 5e-bits (dnd5eapi.co, SRD 5.1) / Open5e). public.classes
-- a été comparé champ par champ à classes.json : aucune différence trouvée (les
-- formats diffèrent -- ex. armor_proficiencies libellés vs abrégés -- mais le
-- contenu est identique), donc aucune migration n'est nécessaire pour les classes.
-- subclasses.json n'est PAS importé : ses 46 entrées correspondent toutes à des
-- sous-classes déjà présentes en base depuis la Phase 5 (103 au total), sous des
-- noms parfois différents (ex. "Voie du guerrier totem" du fichier = "Guerrier
-- totem" en base) ; le fichier ne contient qu'un texte générique non reformulé
-- pour les sous-classes hors SRD, l'importer dégraderait le contenu déjà rédigé.
--
-- 1) Corrections ciblées de contenu déjà en base (un seul champ qui diffère
--    réellement, le reste laissé tel quel) :
--    - Nain (race id existante) : trait "Connaissance de la pierre" (Stonecunning,
--      SRD) manquant entièrement -- ajouté.
--    - Gnome des rochers (subrace id existante) : orthographe VF officielle
--      "Gnome des roches" (fichier) préférée à "Gnome des rochers" (base) ; et
--      description du trait "Bricoleur" complétée avec le texte SRD intégral
--      (règles de fabrication des 3 petits automates), la base n'ayant qu'un
--      résumé d'une phrase.
--
-- 2) Nouvelles races (contenu déjà "prêt", pas de reformulation nécessaire) :
--    Aarakocra, Génasi, Goliath, Orc (2024) -- license_status
--    official_needs_verification pour les 3 premières (Elemental Evil Player's
--    Companion, hors SRD 5.1) mais dont race_lineages.json /
--    racial_innate_spells.json (lot 3) et le présent fichier fournissent déjà
--    des résumés mécaniques originaux (pas de texte copié), donc pas de besoin
--    de relecture différée contrairement au lot 4 (aptitudes de sous-classe).
--    Orc (2024) est srd_cc_by (SRD 5.2).
--    Aasimar (2024) n'est PAS inséré ici : ses 6 traits ne sont que des stubs
--    ("Description intégrale non reproduite...") dans le fichier source, sans
--    aucun résumé mécanique rédigé -- contrairement aux 4 autres, il nécessite
--    une rédaction originale à faire relire, donc traité avec le lot 4 (voir
--    scripts/class_features_non_srd_draft.json et le rapport de tâche).
--
-- 3) Nouvelles sous-races : Génasi de l'air/terre/feu/eau (race_id = nouvelle
--    race Génasi) + Gnome des profondeurs (race_id = Gnome existant).
--    Convention de bonus à choix : le fichier encode le bonus à choix de la
--    Demi-elfe via une clé ad hoc `choice_2_others`, alors que la base utilise
--    déjà `choice_others: {amount, count}` (voir race Demi-elfe existante) --
--    aucune race de ce lot n'a de bonus à choix, donc pas de changement de
--    convention nécessaire ici, notée pour un futur lot qui en ajouterait.

do $$
declare
  v_race_id int;
  v_genasi_id int;
begin
  -- 1a) Nain : ajoute le trait Connaissance de la pierre (Stonecunning, SRD)
  update public.races
  set traits = traits || jsonb_build_array(jsonb_build_object(
    'name', 'Connaissance de la pierre',
    'description', 'Chaque fois que vous effectuez un jet d''Intelligence (Histoire) en relation avec l''origine d''un travail lié à la pierre, vous êtes considéré comme maîtrisant la compétence Histoire et ajoutez le double de votre bonus de maîtrise au jet, au lieu de votre bonus de maîtrise normal.'
  ))
  where id = (
    select r.id from public.races r
    join public.translations t on t.entity_type = 'race' and t.entity_id = r.id::text and t.field_name = 'name' and t.locale = 'fr'
    where t.value = 'Nain'
  )
  and not exists (
    select 1 from public.races r2
    join public.translations t2 on t2.entity_type = 'race' and t2.entity_id = r2.id::text and t2.field_name = 'name' and t2.locale = 'fr'
    where t2.value = 'Nain' and r2.traits @> jsonb_build_array(jsonb_build_object('name', 'Connaissance de la pierre'))
  );

  -- 1b) Gnome des rochers -> Gnome des roches (orthographe VF officielle) + texte complet du trait Bricoleur
  update public.translations
  set value = 'Gnome des roches'
  where entity_type = 'subrace' and field_name = 'name' and locale = 'fr'
    and value = 'Gnome des rochers';

  update public.subraces
  set traits = (
    select jsonb_agg(
      case when elem->>'name' = 'Bricoleur ingénieux' then jsonb_set(
        elem,
        '{description}',
        to_jsonb($j$Vous maîtrisez les outils de bricoleur. En utilisant ces outils, vous pouvez passer 1 heure et dépenser pour 10 po de matériaux pour construire un mécanisme de taille TP, de CA 5 et 1 pv. Le dispositif cesse de fonctionner après 24 heures (sauf si vous passez 1 heure à le réparer) ou si vous utilisez une action pour le démonter ; à ce moment, vous pouvez récupérer les matériaux que vous avez utilisés pour le créer. Vous pouvez avoir jusqu'à trois de ces dispositifs actifs à la fois. Lorsque vous créez un mécanisme, choisissez l'une des options suivantes :
- Allume feu. Le mécanisme produit une toute petite flamme qui peut être utilisée pour allumer une bougie ou une torche au prix d'une action.
- Boîte à musique. Lorsqu'on l'ouvre, la boîte reproduit une chanson (toujours la même) à un volume modéré jusqu'à la fin du morceau ou avant si la boîte est refermée.
- Jouet mécanique. Le jouet représente un animal ou une personne, comme une grenouille, une souris, un oiseau ou un soldat, sur des roulettes. Lorsqu'il est placé sur le sol, il se déplace de 1,50 mètre chaque tour dans une direction aléatoire et fait des bruits en fonction de la créature qu'il représente.$j$::text)
      ) else elem end
    )
    from jsonb_array_elements(traits) elem
  )
  where id = (
    select s.id from public.subraces s
    join public.translations t on t.entity_type = 'subrace' and t.entity_id = s.id::text and t.field_name = 'name' and t.locale = 'fr'
    where t.value = 'Gnome des roches'
  );

  -- 2) Nouvelles races
  if not exists (select 1 from public.translations where entity_type = 'race' and field_name = 'name' and locale = 'fr' and value = 'Aarakocra') then
    insert into public.races (source, size, speed, ability_bonuses, traits, languages)
    values (
      'Elemental Evil Player''s Companion', 'Moyenne', 25,
      '{"dex": 2, "wis": 1}'::jsonb,
      $j$[
        {"name": "Vol", "description": "Vitesse de vol de 15 mètres, inutilisable si vous portez une armure intermédiaire ou lourde."},
        {"name": "Serre", "description": "Vos serres sont une arme naturelle de corps à corps ; en cas de touche, elles infligent 1d4 dégâts tranchants."}
      ]$j$::jsonb,
      '["Commun", "Aarakocra", "Aérien"]'::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('race', v_race_id::text, 'name', 'fr', 'Aarakocra'),
      ('race', v_race_id::text, 'description', 'fr', 'Humanoïde aviaire originaire du plan élémentaire de l''Air.');
  end if;

  if not exists (select 1 from public.translations where entity_type = 'race' and field_name = 'name' and locale = 'fr' and value = 'Génasi') then
    insert into public.races (source, size, speed, ability_bonuses, traits, languages)
    values (
      'Elemental Evil Player''s Companion', 'Moyenne', 30,
      '{"con": 2}'::jsonb,
      '[]'::jsonb,
      '["Commun", "Primordial"]'::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('race', v_race_id::text, 'name', 'fr', 'Génasi'),
      ('race', v_race_id::text, 'description', 'fr', 'Humanoïde portant une influence élémentaire, décliné en quatre sous-races (air, terre, feu, eau) qui portent chacune l''intégralité de la mécanique raciale hors ASI/taille/vitesse/langues.');
  end if;

  if not exists (select 1 from public.translations where entity_type = 'race' and field_name = 'name' and locale = 'fr' and value = 'Goliath') then
    insert into public.races (source, size, speed, ability_bonuses, traits, languages)
    values (
      'Elemental Evil Player''s Companion', 'Moyenne', 30,
      '{"str": 2, "con": 1}'::jsonb,
      $j$[
        {"name": "Athlète naturel", "description": "Vous maîtrisez la compétence Athlétisme."},
        {"name": "Endurance de la pierre", "description": "En réaction, lorsque vous subissez des dégâts, vous pouvez réduire ces dégâts de 1d12 + votre modificateur de Constitution. Cette capacité se recharge après un repos court ou long."},
        {"name": "Puissamment bâti", "description": "Vous comptez comme une catégorie de taille supérieure pour déterminer votre capacité de charge et le poids que vous pouvez pousser, tirer ou soulever."},
        {"name": "Montagnard", "description": "Vous êtes résistant aux dégâts de froid et acclimaté aux hautes altitudes."}
      ]$j$::jsonb,
      '["Commun", "Géant"]'::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('race', v_race_id::text, 'name', 'fr', 'Goliath'),
      ('race', v_race_id::text, 'description', 'fr', 'Humanoïde robuste apparenté aux géants et adapté aux régions montagneuses.');
  end if;

  if not exists (select 1 from public.translations where entity_type = 'race' and field_name = 'name' and locale = 'fr' and value = 'Orc') then
    insert into public.races (source, size, speed, ability_bonuses, traits, languages)
    values (
      'Manuel des Joueurs (2024) / SRD 5.2', 'Moyenne', 30,
      '{}'::jsonb,
      $j$[
        {"name": "Type de créature", "description": "Vous êtes un Humanoïde."},
        {"name": "Poussée d'adrénaline", "description": "Vous pouvez effectuer l'action Foncer comme action bonus, et vous gagnez alors des points de vie temporaires égaux à votre bonus de maîtrise. Utilisations égales à votre bonus de maîtrise, récupérées après un repos court ou long."},
        {"name": "Vision dans le noir", "description": "Vous disposez d'une vision dans le noir d'une portée de 36 mètres."},
        {"name": "Acharnement", "description": "Lorsque vos points de vie tombent à 0 sans que vous soyez tué sur le coup, vous pouvez passer à 1 point de vie à la place. Une utilisation par repos long."}
      ]$j$::jsonb,
      '[]'::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('race', v_race_id::text, 'name', 'fr', 'Orc'),
      ('race', v_race_id::text, 'description', 'fr', 'Espèce jouable Orc selon les règles 2024, distincte du Demi-orc (2014) déjà en base. Aucun bonus de caractéristique ni langue n''est porté par l''espèce elle-même en 2024 (gérés par l''historique).');
  end if;

  -- 3) Nouvelles sous-races
  select r.id into v_genasi_id
  from public.races r
  join public.translations t on t.entity_type = 'race' and t.entity_id = r.id::text and t.field_name = 'name' and t.locale = 'fr'
  where t.value = 'Génasi';

  if v_genasi_id is null then
    raise exception 'Race Génasi introuvable après insertion';
  end if;

  if not exists (select 1 from public.translations where entity_type = 'subrace' and field_name = 'name' and locale = 'fr' and value = 'Génasi de l''air') then
    insert into public.subraces (race_id, ability_bonuses, traits)
    values (
      v_genasi_id, '{"dex": 1}'::jsonb,
      $j$[
        {"name": "Souffle sans fin", "description": "Vous pouvez retenir votre respiration indéfiniment tant que vous n'êtes pas neutralisé."},
        {"name": "Se mêler au vent", "description": "Vous pouvez lancer le sort lévitation une fois par repos long, sans composante matérielle. Le Constitution est votre caractéristique d'incantation pour ce sort."}
      ]$j$::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('subrace', v_race_id::text, 'name', 'fr', 'Génasi de l''air');
  end if;

  if not exists (select 1 from public.translations where entity_type = 'subrace' and field_name = 'name' and locale = 'fr' and value = 'Génasi de la terre') then
    insert into public.subraces (race_id, ability_bonuses, traits)
    values (
      v_genasi_id, '{"str": 1}'::jsonb,
      $j$[
        {"name": "Marche de la terre", "description": "Vous ignorez le coût de déplacement supplémentaire des terrains difficiles faits de terre ou de pierre."},
        {"name": "Fusionner avec la pierre", "description": "Vous pouvez lancer le sort passage sans trace une fois par repos long, sans composante matérielle. Le Constitution est votre caractéristique d'incantation pour ce sort."}
      ]$j$::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('subrace', v_race_id::text, 'name', 'fr', 'Génasi de la terre');
  end if;

  if not exists (select 1 from public.translations where entity_type = 'subrace' and field_name = 'name' and locale = 'fr' and value = 'Génasi du feu') then
    insert into public.subraces (race_id, ability_bonuses, traits)
    values (
      v_genasi_id, '{"int": 1}'::jsonb,
      $j$[
        {"name": "Vision dans le noir", "description": "Vous voyez dans l'obscurité jusqu'à 18 mètres, perçue en nuances de rouge."},
        {"name": "Résistance au feu", "description": "Vous êtes résistant aux dégâts de feu."},
        {"name": "Atteindre le brasier", "description": "Vous connaissez le sort mineur flammes. Au niveau 3, vous pouvez lancer une fois par repos long le sort mains brûlantes, sans emplacement de sort. Le Constitution est votre caractéristique d'incantation pour ces sorts."}
      ]$j$::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('subrace', v_race_id::text, 'name', 'fr', 'Génasi du feu');
  end if;

  if not exists (select 1 from public.translations where entity_type = 'subrace' and field_name = 'name' and locale = 'fr' and value = 'Génasi de l''eau') then
    insert into public.subraces (race_id, ability_bonuses, traits)
    values (
      v_genasi_id, '{"wis": 1}'::jsonb,
      $j$[
        {"name": "Résistance à l'acide", "description": "Vous êtes résistant aux dégâts d'acide."},
        {"name": "Amphibien", "description": "Vous pouvez respirer dans l'air et sous l'eau."},
        {"name": "Nage", "description": "Vous avez une vitesse de nage de 9 mètres."},
        {"name": "Appeler la vague", "description": "Vous connaissez le sort mineur façonnage de l'eau. Au niveau 3, vous pouvez lancer une fois par repos long le sort création ou destruction d'eau, sans emplacement de sort. Le Constitution est votre caractéristique d'incantation pour ces sorts."}
      ]$j$::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('subrace', v_race_id::text, 'name', 'fr', 'Génasi de l''eau');
  end if;

  if not exists (select 1 from public.translations where entity_type = 'subrace' and field_name = 'name' and locale = 'fr' and value = 'Gnome des profondeurs (Svirfnebelin)') then
    insert into public.subraces (race_id, ability_bonuses, traits)
    values (
      (select r.id from public.races r join public.translations t on t.entity_type = 'race' and t.entity_id = r.id::text and t.field_name = 'name' and t.locale = 'fr' where t.value = 'Gnome'),
      '{"dex": 1}'::jsonb,
      $j$[
        {"name": "Vision dans le noir supérieure", "description": "Votre vision dans le noir a une portée de 36 mètres (remplace la vision dans le noir de 18 mètres de la race Gnome, non cumulative)."},
        {"name": "Teint pierreux", "description": "Vous avez l'avantage aux tests de Discrétion effectués pour vous cacher en terrain rocheux."},
        {"name": "Langue supplémentaire", "description": "Vous connaissez le commun des profondeurs en plus des langues de la race Gnome."}
      ]$j$::jsonb
    ) returning id into v_race_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('subrace', v_race_id::text, 'name', 'fr', 'Gnome des profondeurs (Svirfnebelin)');
  end if;
end $$;
