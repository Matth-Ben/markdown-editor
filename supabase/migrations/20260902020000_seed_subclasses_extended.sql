-- Chantier "Personnages" (app mobile) — Phase 5, lot 2 — Sous-classes étendues.
-- Étoffe public.subclasses au-delà des 12 sous-classes "iconiques" du socle
-- Phase 1 (une par classe, voir 20260825090700_seed_classes_subclasses_features.sql,
-- qui n'est pas modifiée ici) avec les sous-classes du Manuel des Joueurs, du
-- Guide de Xanathar, du Chaudron de Tasha et de suppléments ultérieurs, pour
-- un total de 103 sous-classes sur les 12 classes — voir 06-roadmap.md Phase 5
-- du cahier des charges de l'app mobile.
--
-- Source : fichier local CodexArcanum_V2.html (bloc SUBCLASSES_BY_CLASS), qui
-- ne fournit qu'un nom et une description d'ambiance courte par sous-classe,
-- pas d'aptitudes mécaniques niveau par niveau. Décision de périmètre actée
-- avec l'utilisateur : ces 91 nouvelles sous-classes sont ajoutées sans
-- public.class_features associées (contrairement aux 12 "iconiques" du socle,
-- qui elles ont des aptitudes détaillées) — pas d'aptitudes fabriquées pour
-- combler ce manque, ce sera un chantier de contenu ultérieur.
--
-- Dédoublonnage contre les 12 "iconiques" déjà en base : le fichier source
-- contient bien une entrée par sous-classe iconique, mais sous un nom/une
-- casse différents de celui retenu par le socle Phase 1 (vérifié un à un par
-- classe + description, chaque sous-classe canonique D&D ne correspondant
-- qu'à une seule paire) :
--   Barbare    : "Voie du Berserker" (base)     = "Berserker" (fichier)
--   Barde      : "Collège du Savoir" (base)     = "Collège du savoir" (fichier, casse)
--   Clerc      : "Domaine de la Vie" (base)     = "Vie" (fichier)
--   Druide     : "Cercle de la Terre" (base)    = "Cercle de la terre" (fichier, casse)
--   Ensorceleur: "Lignage draconique" (base)    = "Lignée draconique" (fichier)
--   Guerrier   : "Champion" (base)              = "Champion" (fichier, identique)
--   Magicien   : "École de l'évocation" (base)  = "Évocation" (fichier)
--   Moine      : "Voie de la Main Ouverte" (base) = "Voie de la paume" (fichier)
--   Occultiste : "Protecteur Fiélon" (base)     = "Fiélon" (fichier)
--   Paladin    : "Serment des Anciens" (base)   = "Serment des anciens" (fichier, casse)
--   Rôdeur     : "Chasseur" (base)              = "Chasseur" (fichier, identique)
--   Roublard   : "Voleur" (base)                = "Voleur" (fichier, identique)
-- Comparer les noms tels quels aurait donc dupliqué 9 de ces 12 sous-classes
-- sous un second libellé (seules Champion/Chasseur/Voleur sont des chaînes
-- strictement identiques). Le nom du fichier correspondant à chacune des 12
-- iconiques est donc explicitement omis des listes de valeurs ci-dessous
-- (dédoublonnage primaire, à la génération, même logique que
-- 20260902012940_seed_spells_extended.sql pour les sorts), avec en
-- complément une garde SQL `if not exists` par (class_id, nom fr) comme filet
-- de sécurité pour une ré-application de cette migration.
--
-- name/description vivent dans public.translations (migration
-- 20260825090050).

do $$
declare
  rec record;
  v_id int;
  v_class_id int;
begin
  for rec in
    select * from (values
      -- Barbare (available_from_level 3 ; iconique déjà en base : "Voie du Berserker" = "Berserker")
      ('Barbare', 3, 'Guerrier totem', $j$Puise sa rage dans un esprit animal protecteur (Ours, Aigle, Loup...) qui octroie résistance, mobilité ou soutien aux alliés selon le totem choisi.$j$),
      ('Barbare', 3, 'Bête', $j$Transforme des parties de son corps en armes naturelles pendant la rage : griffes, crocs ou carapace, pour un combat brutal et instinctif.$j$),
      ('Barbare', 3, 'Gardien ancestral', $j$Invoque les esprits protecteurs de ses ancêtres pour entraver ses ennemis et protéger ses compagnons des dégâts.$j$),
      ('Barbare', 3, 'Géant', $j$Canalise la force des géants primordiaux : grandit en taille, projette des ennemis et frappe avec une puissance colossale.$j$),
      ('Barbare', 3, 'Héraut des tempêtes', $j$Devient un vecteur de la fureur des éléments, frappant la zone autour de lui de foudre, de froid ou de tonnerre selon la tempête choisie.$j$),
      ('Barbare', 3, 'Magie sauvage', $j$Sa rage est liée à une magie chaotique imprévisible qui peut déclencher des effets surprenants, bénéfiques comme désastreux.$j$),
      ('Barbare', 3, 'Zélote', $j$Sert un dieu de guerre : ses attaques en rage sont empreintes de puissance divine et il revient parfois d'entre les morts.$j$),

      -- Barde (available_from_level 3 ; iconique déjà en base : "Collège du Savoir" = "Collège du savoir")
      ('Barde', 3, 'Collège de la vaillance', $j$Un barde guerrier qui inspire ses compagnons au combat, portant une armure intermédiaire et frappant aux côtés du groupe.$j$),
      ('Barde', 3, 'Collège de l''éloquence', $j$Spécialiste de la persuasion et du débat, capable de garantir un minimum sur les jets liés à l'inspiration bardique et de contrer les effets mentaux.$j$),
      ('Barde', 3, 'Collège de la création', $j$Manipule le Son Originel pour matérialiser temporairement des objets et illusions à partir de sa musique.$j$),
      ('Barde', 3, 'Collège de la séduction', $j$Utilise le charme et la fascination pour manipuler et enchanter son public, sur scène comme au combat.$j$),
      ('Barde', 3, 'Collège des épées', $j$Combine performance musicale et maniement d'arme, exécutant des figures de combat spectaculaires et acrobatiques.$j$),
      ('Barde', 3, 'Collège des esprits', $j$Puise son inspiration dans les histoires des défunts, invoquant des effets aléatoires liés à des contes et légendes.$j$),
      ('Barde', 3, 'Collège des murmures', $j$Un barde plus sinistre, expert en intimidation psychique et en manipulation des peurs les plus profondes de ses cibles.$j$),

      -- Clerc (available_from_level 1 ; iconique déjà en base : "Domaine de la Vie" = "Vie")
      ('Clerc', 1, 'Duperie', $j$Domaine de la tromperie et de l'illusion, favorisant la ruse, le mensonge bienveillant et les capacités de duplication.$j$),
      ('Clerc', 1, 'Guerre', $j$Domaine martial : bénédictions de combat, bonus aux attaques et capacité à devenir un redoutable combattant sacré.$j$),
      ('Clerc', 1, 'Lumière', $j$Domaine radieux maîtrisant le feu et la lumière, avec des sorts offensifs et la capacité d'éblouir ses ennemis.$j$),
      ('Clerc', 1, 'Nature', $j$Domaine lié aux forces naturelles, offrant sorts de Druide, affinité avec les animaux et résistance aux éléments.$j$),
      ('Clerc', 1, 'Savoir', $j$Domaine de la connaissance : accès élargi aux sorts de toutes les écoles et expertise dans de nombreuses compétences.$j$),
      ('Clerc', 1, 'Tempête', $j$Domaine des éléments déchaînés, canalisant foudre et tonnerre pour frapper à distance avec violence.$j$),
      ('Clerc', 1, 'Crépuscule', $j$Domaine protecteur veillant sur ceux qui craignent l'obscurité, offrant vision dans le noir partagée et soins réguliers au groupe.$j$),
      ('Clerc', 1, 'Forge', $j$Domaine de la création et du métal, renforçant l'armure du clerc et lui permettant d'infuser des objets magiques mineurs.$j$),
      ('Clerc', 1, 'Tombe', $j$Domaine funéraire luttant contre la mort et les morts-vivants, avec la capacité de repousser la mort d'un allié.$j$),

      -- Druide (available_from_level 2 ; iconique déjà en base : "Cercle de la Terre" = "Cercle de la terre")
      ('Druide', 2, 'Cercle de la lune', $j$Druide combattant capable de prendre des formes bestiales redoutables au combat, y compris des créatures puissantes dès le niveau 2.$j$),
      ('Druide', 2, 'Cercle des astres', $j$Druide céleste dont la forme sauvage se change en constellations d'étoiles offrant soin, combat ou lumière.$j$),
      ('Druide', 2, 'Cercle du berger', $j$Invoque des esprits protecteurs qui soutiennent et renforcent les alliés proches, en véritable meneur de troupe.$j$),
      ('Druide', 2, 'Cercle des fournaises', $j$Lié aux esprits du feu et du fer, ce druide manipule des automates et une magie ardente destructrice.$j$),
      ('Druide', 2, 'Cercle des rêves', $j$Puise dans le Royaume Féerique une magie apaisante, capable de soigner et réconforter le groupe autour d'un feu de camp.$j$),
      ('Druide', 2, 'Cercle des spores', $j$Druide macabre lié à la décomposition, capable d'animer des zombies fongiques et d'infliger des dégâts nécrotiques.$j$),

      -- Ensorceleur (available_from_level 1 ; iconique déjà en base : "Lignage draconique" = "Lignée draconique")
      ('Ensorceleur', 1, 'Magie sauvage', $j$Sa magie est instable et imprévisible, générant occasionnellement des effets surprenants (la Marée sauvage) à chaque sort lancé.$j$),
      ('Ensorceleur', 1, 'Âme divine', $j$Sa magie trouve sa source dans le divin, offrant accès à des sorts de Clerc et un lien de guérison ou de vengeance sacrée.$j$),
      ('Ensorceleur', 1, 'Âme mécanique', $j$Lié à un plan modronique ordonné, manipulant l'ordre et la loi pour stabiliser ses sorts et invoquer un esprit gardien.$j$),
      ('Ensorceleur', 1, 'Aberrance', $j$Son esprit a été touché par une entité aberrante, lui conférant télépathie et pouvoirs psioniques altérant la réalité.$j$),
      ('Ensorceleur', 1, 'Magie des ombres', $j$Sa magie vient du Plan des Ombres, offrant vision dans le noir, résistance nécrotique et capacité de marcher entre les ombres.$j$),
      ('Ensorceleur', 1, 'Sorcellerie des tempêtes', $j$Né au cœur d'une tempête magique, maîtrise le vent et la foudre et peut voler brièvement en lançant des sorts.$j$),

      -- Guerrier (available_from_level 3 ; iconique déjà en base : "Champion" = "Champion")
      ('Guerrier', 3, 'Maître de guerre', $j$Combattant tacticien utilisant des manœuvres martiales variées (dés de supériorité) pour contrôler le champ de bataille.$j$),
      ('Guerrier', 3, 'Chevalier occulte', $j$Guerrier-mage combinant escrime et magie du Magicien, renforçant ses armes d'effets arcaniques.$j$),
      ('Guerrier', 3, 'Archer arcanique', $j$Spécialiste du tir à l'arc soutenu par la magie, capable d'enchanter ses flèches d'effets variés (feu, force, illusion...).$j$),
      ('Guerrier', 3, 'Cavalier', $j$Combattant monté d'exception, lié à sa monture au point de la protéger et de coordonner leurs attaques.$j$),
      ('Guerrier', 3, 'Chevalier runique', $j$Grave des runes géantes sur son équipement pour amplifier sa force, sa taille et infliger la peur à ses adversaires.$j$),
      ('Guerrier', 3, 'Samouraï', $j$Guerrier d'une discipline martiale rigoureuse, capable de puiser dans une détermination intérieure pour enchaîner les attaques.$j$),
      ('Guerrier', 3, 'Soldat psi', $j$Combattant doté de pouvoirs psioniques, manipulant les esprits et projetant une énergie mentale destructrice.$j$),

      -- Magicien (available_from_level 2 ; iconique déjà en base : "École de l'évocation" = "Évocation")
      ('Magicien', 2, 'Abjuration', $j$Spécialiste de la protection magique, capable de créer des boucliers absorbant les dégâts et de bannir la magie adverse.$j$),
      ('Magicien', 2, 'Divination', $j$Maîtrise les sorts de prédiction et d'analyse, manipulant le hasard grâce à des dés de portent pour infléchir le destin.$j$),
      ('Magicien', 2, 'Enchantement', $j$Expert en manipulation mentale, renforçant ses sorts de charme et se protégeant des tentatives de domination adverses.$j$),
      ('Magicien', 2, 'Illusion', $j$Maître du mensonge sensoriel, rendant ses illusions quasi indétectables et capables d'infliger de vrais dégâts psychiques.$j$),
      ('Magicien', 2, 'Invocation', $j$Convoque créatures et objets à travers les plans, avec une invocation compagnon fidèle et une téléportation mineure fréquente.$j$),
      ('Magicien', 2, 'Nécromancie', $j$Manipule les forces de la mort, renforçant ses sorts nécrotiques et pouvant animer davantage de morts-vivants.$j$),
      ('Magicien', 2, 'Transmutation', $j$Altère la matière et les formes, capable de transformer temporairement des objets et de partager cette magie avec ses alliés.$j$),
      ('Magicien', 2, 'Chantelames', $j$Fusionne magie et escrime, incantant tout en maniant une lame liée qui amplifie ses sorts offensifs.$j$),
      ('Magicien', 2, 'Magie de guerre', $j$Magicien de guerre pur, capable de lancer des sorts et de se défendre en combat rapproché sans perdre en efficacité.$j$),
      ('Magicien', 2, 'Scribes', $j$Lie son grimoire vivant à une entité mystique, pouvant modifier le type de dégâts de ses sorts à la volée.$j$),

      -- Moine (available_from_level 3 ; iconique déjà en base : "Voie de la Main Ouverte" = "Voie de la paume")
      ('Moine', 3, 'Voie de l''ombre', $j$Moine furtif maîtrisant des techniques d'infiltration : invisibilité, déplacement entre les ombres et illusions mineures.$j$),
      ('Moine', 3, 'Voie des quatre éléments', $j$Dépense son ki pour déclencher des disciplines élémentaires (souffle de feu, mur de glace, vague déferlante...).$j$),
      ('Moine', 3, 'Voie de l''âme solaire', $j$Manifeste son ki en énergie radiante pure, façonnant des armes de lumière et frappant à distance.$j$),
      ('Moine', 3, 'Voie de l''astre intérieur', $j$Se transforme en une forme astrale céleste, gagnant une aura et des capacités liées à une constellation choisie.$j$),
      ('Moine', 3, 'Voie de la miséricorde', $j$Manie le ki pour soigner ou, à l'inverse, provoquer une souffrance handicapante, en soignant guérisseur de guerre.$j$),
      ('Moine', 3, 'Voie du dragon ascendant', $j$Canalise l'essence draconique dans ses techniques, avec un souffle élémentaire et un vol temporaire.$j$),
      ('Moine', 3, 'Voie du kensei', $j$Maîtrise une sélection d'armes comme extension de son propre corps, avec la précision d'un maître d'armes.$j$),
      ('Moine', 3, 'Voie du maître ivre', $j$Style de combat imprévisible imitant l'ivresse pour déstabiliser les adversaires et esquiver avec une grâce chaotique.$j$),

      -- Occultiste (available_from_level 1 ; iconique déjà en base : "Protecteur Fiélon" = "Fiélon")
      ('Occultiste', 1, 'Archifée', $j$Pacte avec un seigneur ou une dame féerique, octroyant charme, téléportation courte et capacités d'enchantement.$j$),
      ('Occultiste', 1, 'Grand Ancien', $j$Pacte avec une entité cosmique incompréhensible, offrant pouvoirs psioniques et capacité à briser l'esprit des ennemis.$j$),
      ('Occultiste', 1, 'Céleste', $j$Pacte avec une entité du Plan Supérieur, apportant sorts de soin, lumière radiante et protection sacrée.$j$),
      ('Occultiste', 1, 'Génie - Dao', $j$Pacte avec un génie de la Terre, liant l'occultiste à un vase magique et des pouvoirs telluriques.$j$),
      ('Occultiste', 1, 'Génie - Djinn', $j$Pacte avec un génie de l'Air, offrant vol occasionnel et magie du vent au sein d'un vase-palais.$j$),
      ('Occultiste', 1, 'Génie - Éfrit', $j$Pacte avec un génie du Feu, conférant résistance au feu et déplacements ardents depuis une lampe magique.$j$),
      ('Occultiste', 1, 'Génie - Maride', $j$Pacte avec un génie de l'Eau, offrant respiration aquatique et pouvoirs liés aux flots depuis une urne magique.$j$),
      ('Occultiste', 1, 'Insondable', $j$Pacte avec les profondeurs inconnues de l'existence elle-même, aux capacités mystérieuses et changeantes.$j$),
      ('Occultiste', 1, 'Lame maudite', $j$Pacte lié à une arme maudite intelligente, combinant combat rapproché et magie sombre.$j$),
      ('Occultiste', 1, 'Mort-vivant', $j$Pacte avec une entité liée à la non-mort, offrant résistance à la peur, apparence spectrale et pouvoirs nécrotiques.$j$),

      -- Paladin (available_from_level 3 ; iconique déjà en base : "Serment des Anciens" = "Serment des anciens")
      ('Paladin', 3, 'Serment de dévotion', $j$Incarne les vertus classiques du chevalier : honnêteté, courage et protection des innocents, avec des sorts de justice sacrée.$j$),
      ('Paladin', 3, 'Serment de vengeance', $j$Consacré à punir ceux qui commettent de grands maux, avec des capacités de traque implacable et de châtiment.$j$),
      ('Paladin', 3, 'Serment de conquête', $j$Impose l'ordre par la crainte et la domination, semant la terreur chez ses ennemis pour asseoir son autorité.$j$),
      ('Paladin', 3, 'Serment de gloire', $j$Recherche des exploits légendaires, avec une endurance physique hors norme et des capacités athlétiques surhumaines.$j$),
      ('Paladin', 3, 'Serment des guetteurs', $j$Veille aux frontières entre les mondes, contrant les incursions de créatures aberrantes ou planaires.$j$),
      ('Paladin', 3, 'Serment de rédemption', $j$Cherche à convaincre plutôt qu'à détruire, utilisant la persuasion et une défense pacifique pour éviter le conflit.$j$),

      -- Rôdeur (available_from_level 3 ; iconique déjà en base : "Chasseur" = "Chasseur")
      ('Rôdeur', 3, 'Maître des bêtes', $j$Combat aux côtés d'un compagnon animal fidèle qui partage ses actions et évolue avec lui.$j$),
      ('Rôdeur', 3, 'Arpenteur de l''horizon', $j$Voyageur entre les plans, capable de courtes téléportations et de repérer les créatures invisibles ou planaires.$j$),
      ('Rôdeur', 3, 'Gardien de drake', $j$Lié à un familier draconique miniature qui combat et voyage à ses côtés.$j$),
      ('Rôdeur', 3, 'Gardien des nuées', $j$Rôdeur aérien lié aux esprits du ciel, capable de léviter et de frapper depuis les airs.$j$),
      ('Rôdeur', 3, 'Traqueur des ténèbres', $j$Opère dans l'ombre et l'obscurité, maîtrisant furtivité et embuscades contre des cibles isolées.$j$),
      ('Rôdeur', 3, 'Tueur de monstres', $j$Chasseur spécialisé dans les créatures monstrueuses et magiques, avec des capacités de détection et de résistance à leurs pouvoirs.$j$),
      ('Rôdeur', 3, 'Vagabond féerique', $j$Lié au Royaume Féerique, capable de téléportation courte et de ruses illusoires empruntées aux fées.$j$),

      -- Roublard (available_from_level 3 ; iconique déjà en base : "Voleur" = "Voleur")
      ('Roublard', 3, 'Assassin', $j$Spécialiste de l'élimination furtive et des attaques surprises, infligeant des dégâts dévastateurs contre une cible non préparée.$j$),
      ('Roublard', 3, 'Escroc arcanique', $j$Roublard initié à la magie mineure du Magicien, combinant vol, illusions et tours de passe-passe enchantés.$j$),
      ('Roublard', 3, 'Âme acérée', $j$Canalise une énergie psionique intérieure pour renforcer sa précision et manipuler les perceptions de ses adversaires.$j$),
      ('Roublard', 3, 'Bretteur', $j$Duelliste virtuose misant sur l'esquive et la finesse d'escrime plutôt que sur la force brute.$j$),
      ('Roublard', 3, 'Conspirateur', $j$Maître de la manipulation et du renseignement, tissant des réseaux d'informateurs et de fausses pistes.$j$),
      ('Roublard', 3, 'Éclaireur', $j$Expert de la reconnaissance et du terrain, coordonnant ses attaques à distance avec agilité et discrétion.$j$),
      ('Roublard', 3, 'Enquêteur', $j$Fin limier misant sur l'observation et la déduction pour repérer failles et indices que d'autres manqueraient.$j$),
      ('Roublard', 3, 'Phantôme', $j$Marqué par une rencontre avec la mort, ce roublard manipule les esprits des défunts et frappe avec une froideur spectrale.$j$)
    ) as t(class_name, available_from_level, name, description)
  loop
    select c.id into v_class_id
    from public.translations ct
    join public.classes c on c.id::text = ct.entity_id
    where ct.entity_type = 'class' and ct.field_name = 'name' and ct.locale = 'fr'
      and ct.value = rec.class_name;

    if v_class_id is null then
      raise exception 'Classe introuvable pour la sous-classe % : %', rec.name, rec.class_name;
    end if;

    if not exists (
      select 1
      from public.subclasses sc
      join public.translations st
        on st.entity_id = sc.id::text
        and st.entity_type = 'subclass' and st.field_name = 'name' and st.locale = 'fr'
      where sc.class_id = v_class_id and st.value = rec.name
    ) then
      insert into public.subclasses (class_id, available_from_level)
        values (v_class_id, rec.available_from_level)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('subclass', v_id::text, 'name', 'fr', rec.name),
        ('subclass', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;
