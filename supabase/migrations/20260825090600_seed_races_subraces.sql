-- Chantier "Personnages" (app mobile) — Phase 1 — Peuplement du socle.
-- Les 9 races de base du Manuel des Joueurs (SRD 5.1/5.2, CC-BY 4.0, voir
-- 07-source-donnees-i18n.md) et leurs sous-races, en français (noms de
-- races alignés sur la terminologie officielle VF : Humain, Elfe, Nain,
-- Halfelin, Drakéide, Gnome, Demi-elfe, Demi-orque, Tieffelin). Descriptions
-- de traits reformulées (pas une copie verbatim d'un texte sous droits),
-- basées sur les règles ouvertes du SRD.
--
-- Convention d'unité : `speed` est stocké en pieds (unité native des
-- règles 5e/SRD), la conversion en mètres pour l'affichage FR est un choix
-- de couche de présentation, pas de stockage.
--
-- name/description vivent dans public.translations (migration
-- 20260825090050), pas en colonnes sur races/subraces. `races.id` étant
-- généré à l'insertion, chaque race est insérée individuellement dans une
-- boucle PL/pgSQL pour capturer son id via `returning ... into` avant
-- d'insérer ses traductions et ses sous-races. Les sous-races résolvent
-- `race_id` en relisant public.translations (jointure par nom devenue
-- impossible : `races.name` n'existe plus). Le contenu narratif imbriqué
-- dans les colonnes jsonb `traits` (name/description par trait) reste tel
-- quel : il n'est pas dans le périmètre de ce changement de modélisation
-- (voir rapport de fin de tâche).

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.races) then
    return;
  end if;

  for rec in
    select * from (values
      (
        'Humain', 'Manuel des Joueurs', 'Moyenne', 30,
        '{"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}'::jsonb,
        $j$[
          {"name": "Polyvalence", "description": "Les humains n'ont pas de trait racial marquant au-delà de leur adaptabilité : un bonus de +1 à chacune de leurs six caractéristiques et une langue supplémentaire au choix."}
        ]$j$::jsonb,
        '["Commun", "une langue de son choix"]'::jsonb,
        $j$Peuple le plus répandu et le plus varié de la plupart des mondes, ambitieux et adaptable.$j$
      ),
      (
        'Elfe', 'Manuel des Joueurs', 'Moyenne', 30,
        '{"dex": 2}'::jsonb,
        $j$[
          {"name": "Vision dans le noir", "description": "Habitué à la pénombre des forêts et au ciel nocturne, vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de pénombre, et dans la pénombre comme s'il faisait grand jour."},
          {"name": "Sens aiguisés", "description": "Vous êtes compétent dans la compétence Perception."},
          {"name": "Ascendance féerique", "description": "Vous bénéficiez de l'avantage aux jets de sauvegarde contre le charme, et la magie ne peut pas vous endormir."},
          {"name": "Transe", "description": "Vous n'avez pas besoin de dormir. Une méditation profonde de 4 heures par jour procure les mêmes bienfaits qu'un repos long de 8 heures."}
        ]$j$::jsonb,
        '["Commun", "Elfique"]'::jsonb,
        $j$Peuple gracile et magique, à l'ouïe et à la vue perçantes, doté d'une longue mémoire et d'un amour pour la nature et les arts.$j$
      ),
      (
        'Nain', 'Manuel des Joueurs', 'Moyenne', 25,
        '{"con": 2}'::jsonb,
        $j$[
          {"name": "Vision dans le noir", "description": "Habitué à la vie sous terre, vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de pénombre, et dans la pénombre comme s'il faisait grand jour."},
          {"name": "Résistance naine", "description": "Vous bénéficiez de l'avantage aux jets de sauvegarde contre le poison, et vous êtes résistant aux dégâts de poison."},
          {"name": "Entraînement au combat nain", "description": "Vous êtes compétent avec la hache de bataille, la hache d'armes, le marteau léger et le marteau de guerre."},
          {"name": "Maîtrise des outils", "description": "Vous êtes compétent avec un type d'outils d'artisan de votre choix parmi ceux liés à la culture naine."}
        ]$j$::jsonb,
        '["Commun", "Nain"]'::jsonb,
        $j$Peuple robuste et résistant, attaché à la tradition, à l'artisanat et à la vie souterraine.$j$
      ),
      (
        'Halfelin', 'Manuel des Joueurs', 'Petite', 25,
        '{"dex": 2}'::jsonb,
        $j$[
          {"name": "Chanceux", "description": "Lorsque vous obtenez un 1 naturel sur un jet d'attaque, de caractéristique ou de sauvegarde, vous pouvez relancer le dé et devez utiliser le nouveau résultat."},
          {"name": "Brave", "description": "Vous bénéficiez de l'avantage aux jets de sauvegarde contre la peur."},
          {"name": "Agilité halfeline", "description": "Vous pouvez traverser l'espace occupé par une créature d'une catégorie de taille supérieure à la vôtre."}
        ]$j$::jsonb,
        '["Commun", "Halfelin"]'::jsonb,
        $j$Petit peuple discret et chanceux, attaché au confort du foyer autant qu'à la vie sur les routes.$j$
      ),
      (
        'Drakéide', 'Manuel des Joueurs', 'Moyenne', 30,
        '{"str": 2, "cha": 1}'::jsonb,
        $j$[
          {"name": "Ascendance draconique", "description": "Vous descendez d'un type de dragon qui détermine le type de dégâts de votre souffle et votre résistance aux dégâts associée (au choix à la création du personnage)."},
          {"name": "Souffle destructeur", "description": "Vous pouvez utiliser votre action pour exhaler une énergie destructrice, dont la taille, la forme et le type de dégâts dépendent de votre ascendance draconique."},
          {"name": "Résistance aux dégâts", "description": "Vous êtes résistant au type de dégâts associé à votre ascendance draconique."}
        ]$j$::jsonb,
        '["Commun", "Draconique"]'::jsonb,
        $j$Descendants de dragons portant fièrement leur héritage, honneur et loyauté au clan avant tout.$j$
      ),
      (
        'Gnome', 'Manuel des Joueurs', 'Petite', 25,
        '{"int": 2}'::jsonb,
        $j$[
          {"name": "Vision dans le noir", "description": "Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de pénombre, et dans la pénombre comme s'il faisait grand jour."},
          {"name": "Ruse gnome", "description": "Vous bénéficiez de l'avantage à tous les jets de sauvegarde d'Intelligence, de Sagesse et de Charisme contre la magie."}
        ]$j$::jsonb,
        '["Commun", "Gnome"]'::jsonb,
        $j$Petit peuple curieux et inventif, passionné par la mécanique, l'illusion et le savoir.$j$
      ),
      (
        'Demi-elfe', 'Manuel des Joueurs', 'Moyenne', 30,
        '{"cha": 2, "choice_others": {"amount": 1, "count": 2}}'::jsonb,
        $j$[
          {"name": "Vision dans le noir", "description": "Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de pénombre, et dans la pénombre comme s'il faisait grand jour."},
          {"name": "Ascendance féerique", "description": "Vous bénéficiez de l'avantage aux jets de sauvegarde contre le charme, et la magie ne peut pas vous endormir."},
          {"name": "Polyvalence en compétences", "description": "Vous êtes compétent dans deux compétences de votre choix."}
        ]$j$::jsonb,
        '["Commun", "Elfique", "une langue de son choix"]'::jsonb,
        $j$Nés de deux mondes sans appartenir pleinement à aucun, curieux et adaptables.$j$
      ),
      (
        'Demi-orque', 'Manuel des Joueurs', 'Moyenne', 30,
        '{"str": 2, "con": 1}'::jsonb,
        $j$[
          {"name": "Vision dans le noir", "description": "Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de pénombre, et dans la pénombre comme s'il faisait grand jour."},
          {"name": "Intimidant", "description": "Vous êtes compétent dans la compétence Intimidation."},
          {"name": "Robustesse implacable", "description": "Lorsque vous tombez à 0 point de vie sans être tué net, vous pouvez à la place tomber à 1 point de vie. Ce trait ne peut être utilisé qu'une fois par repos long."},
          {"name": "Attaques sauvages", "description": "Lors d'un coup critique avec une arme de corps à corps, vous relancez un des dés de dégâts et ajoutez le résultat."}
        ]$j$::jsonb,
        '["Commun", "Orc"]'::jsonb,
        $j$Peuple robuste et déterminé, souvent jugé sur les préjugés attachés à son héritage plutôt que sur ses actes.$j$
      ),
      (
        'Tieffelin', 'Manuel des Joueurs', 'Moyenne', 30,
        '{"int": 1, "cha": 2}'::jsonb,
        $j$[
          {"name": "Vision dans le noir", "description": "Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de pénombre, et dans la pénombre comme s'il faisait grand jour."},
          {"name": "Résistance infernale", "description": "Vous êtes résistant aux dégâts de feu."},
          {"name": "Legs infernal", "description": "Vous connaissez le sort mineur Thaumaturgie. À partir du niveau 3, vous pouvez lancer une fois par repos long le sort Repli sinistre, puis à partir du niveau 5, le sort Ténèbres, sans dépenser d'emplacement de sort."}
        ]$j$::jsonb,
        '["Commun", "Infernal"]'::jsonb,
        $j$Marqués par un héritage infernal lointain, souvent en butte à la méfiance malgré eux.$j$
      )
    ) as t(name, source, size, speed, ability_bonuses, traits, languages, description)
  loop
    insert into public.races (source, size, speed, ability_bonuses, traits, languages)
      values (rec.source, rec.size, rec.speed, rec.ability_bonuses, rec.traits, rec.languages)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('race', v_id::text, 'name', 'fr', rec.name),
      ('race', v_id::text, 'description', 'fr', rec.description);
  end loop;
end $$;

-- Sous-races.
do $$
declare
  rec record;
  v_id int;
  v_race_id int;
begin
  if exists (select 1 from public.subraces) then
    return;
  end if;

  for rec in
    select * from (values
      ('Elfe', 'Haut-elfe',
        '{"int": 1}'::jsonb,
        $j$[
          {"name": "Cantrip elfique", "description": "Vous connaissez un cantrip (sort mineur) de la liste des sorts de magicien, l'Intelligence étant votre caractéristique d'incantation pour ce sort."},
          {"name": "Entraînement martial elfique", "description": "Vous êtes compétent avec l'épée longue, l'épée courte, l'arc court et l'arc long."},
          {"name": "Langue supplémentaire", "description": "Vous connaissez une langue supplémentaire de votre choix."}
        ]$j$::jsonb
      ),
      ('Elfe', 'Elfe des bois',
        '{"wis": 1}'::jsonb,
        $j$[
          {"name": "Entraînement martial elfique", "description": "Vous êtes compétent avec l'épée longue, l'épée courte, l'arc court et l'arc long."},
          {"name": "Foulée légère", "description": "Votre vitesse de base est de 10,5 mètres (35 pieds)."},
          {"name": "Camouflage naturel", "description": "Vous pouvez tenter de vous cacher même en n'étant que légèrement dissimulé par le feuillage, la pluie battante, la neige tombante, le brouillard ou tout autre phénomène naturel."}
        ]$j$::jsonb
      ),
      ('Elfe', 'Elfe noir (Drow)',
        '{"cha": 1}'::jsonb,
        $j$[
          {"name": "Vision dans le noir supérieure", "description": "Votre vision dans le noir a une portée de 36 mètres."},
          {"name": "Sensibilité à la lumière du soleil", "description": "Vous subissez un désavantage aux jets d'attaque et aux jets de Sagesse (Perception) basés sur la vue lorsque vous-même ou la cible se trouvez en pleine lumière du soleil."},
          {"name": "Magie féerique drow", "description": "Vous connaissez le cantrip Lumières féeriques. À partir du niveau 3, vous pouvez lancer une fois par repos long Reflets troublants, puis à partir du niveau 5, Ténèbres."},
          {"name": "Entraînement martial drow", "description": "Vous êtes compétent avec la rapière, l'épée courte et l'arbalète de poing."}
        ]$j$::jsonb
      ),
      ('Nain', 'Nain des collines',
        '{"wis": 1}'::jsonb,
        $j$[
          {"name": "Ténacité naine", "description": "Votre maximum de points de vie augmente de 1, et augmente de 1 supplémentaire à chaque fois que vous gagnez un niveau."}
        ]$j$::jsonb
      ),
      ('Nain', 'Nain des montagnes',
        '{"str": 2}'::jsonb,
        $j$[
          {"name": "Entraînement au combat nain (armures)", "description": "Vous êtes compétent avec les armures légères et intermédiaires."}
        ]$j$::jsonb
      ),
      ('Halfelin', 'Halfelin pied-léger',
        '{"cha": 1}'::jsonb,
        $j$[
          {"name": "Discrétion naturelle", "description": "Vous pouvez tenter de vous cacher même en n'étant dissimulé que par une créature d'au moins une catégorie de taille supérieure à la vôtre."}
        ]$j$::jsonb
      ),
      ('Halfelin', 'Halfelin robuste',
        '{"con": 1}'::jsonb,
        $j$[
          {"name": "Résistance robuste", "description": "Vous bénéficiez de l'avantage aux jets de sauvegarde contre le poison, et vous êtes résistant aux dégâts de poison."}
        ]$j$::jsonb
      ),
      ('Gnome', 'Gnome des forêts',
        '{"dex": 1}'::jsonb,
        $j$[
          {"name": "Illusionniste inné", "description": "Vous connaissez le cantrip Ménagerie illusoire, l'Intelligence étant votre caractéristique d'incantation pour ce sort."},
          {"name": "Communication avec les petites bêtes", "description": "Grâce à des gestes et des sons simples, vous pouvez communiquer des idées rudimentaires avec une bête de taille P ou plus petite."}
        ]$j$::jsonb
      ),
      ('Gnome', 'Gnome des rochers',
        '{"con": 1}'::jsonb,
        $j$[
          {"name": "Connaissances de l'artisan", "description": "Vous ajoutez le double de votre bonus de maîtrise pour tout jet d'Intelligence (Histoire) lié aux objets magiques, mécanismes ou dispositifs alchimiques."},
          {"name": "Bricoleur ingénieux", "description": "Vous savez vous servir d'outils d'artisan (outils de bricoleur) pour construire de petits automates mécaniques."}
        ]$j$::jsonb
      )
    ) as t(race_name, name, ability_bonuses, traits)
  loop
    select r.id into v_race_id
    from public.translations rt
    join public.races r on r.id::text = rt.entity_id
    where rt.entity_type = 'race' and rt.field_name = 'name' and rt.locale = 'fr'
      and rt.value = rec.race_name;

    if v_race_id is null then
      raise exception 'Race introuvable pour la sous-race % : %', rec.name, rec.race_name;
    end if;

    insert into public.subraces (race_id, ability_bonuses, traits)
      values (v_race_id, rec.ability_bonuses, rec.traits)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value)
      values ('subrace', v_id::text, 'name', 'fr', rec.name);
  end loop;
end $$;
