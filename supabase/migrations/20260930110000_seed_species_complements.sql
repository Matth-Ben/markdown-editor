-- Lot 4 de l'import du contenu de référence : espèces manquantes (texte français reformulé).
--
-- * Aasimar : version Manuel des Joueurs (2024) — pas de bonus de caractéristique porté par
--   l'espèce (géré par l'historique), comme l'Orc 2024 déjà en base.
-- * Espèces de Monstres du Multivers (2022), d'Eberron (Forgelier, Kalashtar) et de Strixhaven
--   (Owlin) : leurs bonus de caractéristique sont libres (+2/+1 ou trois +1), ce que
--   `ability_bonuses` ne sait pas exprimer ; ils restent vides et la règle est décrite en trait.
-- * Sous-races Eladrin, Elfe marin, Shadar-kai (Elfe) et Duergar (Nain), d'après Mordenkainen.
-- * Complète la race « Conil » (id 26, Harengon), restée à l'état d'ébauche.
--
-- Idempotente : insertion seulement si le nom FR n'existe pas déjà.

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
  c_asi constant jsonb := $t${"name":"Augmentation de caractéristiques","description":"Augmentez une caractéristique de 2 et une autre de 1, ou trois caractéristiques différentes de 1 chacune, au choix."}$t$::jsonb;
begin
  for rec in
    select * from (values
  ($t$Aasimar$t$, $t$Aasimar$t$, $t$Manuel des Joueurs (2024)$t$, $t$Moyenne ou Petite$t$, 30, $t${}$t$::jsonb, false,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Résistance céleste","description":"Vous avez la résistance aux dégâts nécrotiques et radiants."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Mains guérisseuses","description":"Par une action Magie, vous touchez une créature et lancez un nombre de d4 égal à votre bonus de maîtrise : elle récupère autant de points de vie. Utilisable une fois par repos long."},
      {"name":"Porteur de lumière","description":"Vous connaissez le sort mineur Lumière ; le Charisme est votre caractéristique d'incantation pour ce sort."},
      {"name":"Révélation céleste","description":"À partir du niveau 3, par une action bonus, vous vous transformez pendant 1 minute (une fois par repos long). Une fois par tour, vous infligez des dégâts supplémentaires égaux à votre bonus de maîtrise (nécrotiques ou radiants). Choisissez la forme à chaque transformation : Ailes célestes (vitesse de vol égale à votre vitesse), Âme radieuse (lumière vive sur 3 m ; les dégâts supplémentaires sont radiants) ou Linceul nécrotique (chaque créature de votre choix à 3 m ou moins doit réussir un jet de sauvegarde de Charisme DD 8 + modificateur de Charisme + bonus de maîtrise ou être effrayée jusqu'à la fin de votre prochain tour)."}]$t$::jsonb,
   $t$[]$t$::jsonb,
   $t$Mortels portant en eux une étincelle des Plans supérieurs, les aasimars peuvent révéler leur ascendance céleste pour guérir ou frapper. Version 2024 : les bonus de caractéristiques et les langues viennent de l'historique.$t$),
  ($t$Gobelours$t$, $t$Bugbear$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Ascendance féerique","description":"Vous avez l'avantage aux jets de sauvegarde pour éviter ou terminer l'état charmé."},
      {"name":"Long bras","description":"Lorsque vous effectuez une attaque au corps à corps pendant votre tour, votre allonge augmente de 1,50 mètre."},
      {"name":"Puissamment bâti","description":"Vous comptez comme une catégorie de taille supérieure pour déterminer votre capacité de charge et le poids que vous pouvez pousser, tirer ou soulever."},
      {"name":"Furtif","description":"Vous maîtrisez la compétence Discrétion."},
      {"name":"Attaque surprise","description":"Si vous touchez une créature avec un jet d'attaque, elle subit 2d6 dégâts supplémentaires si elle n'a pas encore joué de tour pendant ce combat."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes massifs et furtifs d'ascendance féerique, étonnamment discrets pour leur carrure.$t$),
  ($t$Centaure$t$, $t$Centaur$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 40, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes une Fée."},
      {"name":"Charge","description":"Si vous vous déplacez d'au moins 9 mètres en ligne droite vers une cible puis la touchez avec une attaque d'arme au corps à corps pendant le même tour, vous pouvez immédiatement utiliser une action bonus pour l'attaquer avec vos sabots."},
      {"name":"Sabots","description":"Vos sabots sont des armes naturelles : une touche inflige 1d6 + modificateur de Force dégâts contondants."},
      {"name":"Constitution équine","description":"Vous comptez comme une catégorie de taille supérieure pour votre capacité de charge. Chaque mètre d'escalade vous coûte 4 mètres de déplacement supplémentaires."},
      {"name":"Affinité naturelle","description":"Vous maîtrisez une compétence au choix parmi Dressage, Médecine, Nature et Survie."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Êtres mi-humains, mi-chevaux venus des terres sauvages de la Féerie, liés à la nature.$t$),
  ($t$Changelin$t$, $t$Changeling$t$, $t$Monstres du Multivers$t$, $t$Moyenne ou Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes une Fée."},
      {"name":"Instincts de changelin","description":"Vous maîtrisez deux compétences au choix parmi Intimidation, Intuition, Persuasion, Représentation et Tromperie."},
      {"name":"Métamorphe","description":"Par une action, vous pouvez modifier votre apparence et votre voix : taille, poids, traits, couleur des cheveux et de la peau, et même passer de la taille Moyenne à Petite ou inversement. Vous ne pouvez pas imiter une créature que vous n'avez jamais vue, et votre corps doit garder la même disposition de membres. Vos vêtements ne changent pas. Vous reprenez votre forme véritable à votre mort. Vous avez l'avantage aux tests de Charisme (Tromperie) pour vous faire passer pour quelqu'un d'autre sous une autre forme."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Métamorphes d'origine féerique capables de changer d'apparence à volonté.$t$),
  ($t$Fée$t$, $t$Fairy$t$, $t$Monstres du Multivers$t$, $t$Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes une Fée."},
      {"name":"Magie féerique","description":"Vous connaissez le sort mineur Druidisme. Au niveau 3, vous pouvez lancer Lueurs féeriques, puis au niveau 5 Agrandissement/Rapetissement, chacun une fois par repos long sans emplacement (ou avec vos emplacements). Caractéristique d'incantation au choix : Intelligence, Sagesse ou Charisme."},
      {"name":"Vol","description":"Vous avez une vitesse de vol égale à votre vitesse au sol, inutilisable si vous portez une armure intermédiaire ou lourde."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Petites créatures ailées imprégnées de la magie de la Féerie.$t$),
  ($t$Firbolg$t$, $t$Firbolg$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Magie firbolg","description":"Vous pouvez lancer Détection de la magie et Déguisement, chacun une fois par repos long sans emplacement (ou avec vos emplacements). Avec Déguisement, vous pouvez paraître jusqu'à 90 cm plus petit ou plus grand. Caractéristique d'incantation au choix : Intelligence, Sagesse ou Charisme."},
      {"name":"Pas caché","description":"Par une action bonus, vous devenez invisible par magie jusqu'au début de votre prochain tour, ou jusqu'à ce que vous attaquiez, infligiez des dégâts ou forciez une créature à faire un jet de sauvegarde. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long."},
      {"name":"Puissamment bâti","description":"Vous comptez comme une catégorie de taille supérieure pour votre capacité de charge et le poids que vous pouvez pousser, tirer ou soulever."},
      {"name":"Langage des bêtes et du feuillage","description":"Vous pouvez communiquer de façon limitée avec les bêtes, les plantes et la végétation, qui comprennent le sens de vos paroles sans que vous compreniez forcément leur réponse. Vous avez l'avantage aux tests de Charisme pour les influencer."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Gardiens des forêts à l'ascendance géante, discrets et pacifiques.$t$),
  ($t$Githyanki$t$, $t$Githyanki$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Savoir astral","description":"À la fin de chaque repos long, vous obtenez la maîtrise d'une compétence ainsi que d'une arme ou d'un outil de votre choix, jusqu'à la fin de votre prochain repos long."},
      {"name":"Psionique githyanki","description":"Vous connaissez le sort mineur Main de mage, dont la main est invisible. Au niveau 3, vous pouvez lancer Saut, puis au niveau 5 Pas brumeux, chacun une fois par repos long sans emplacement (ou avec vos emplacements), sans composantes. Caractéristique d'incantation au choix : Intelligence, Sagesse ou Charisme."},
      {"name":"Résilience psychique","description":"Vous avez la résistance aux dégâts psychiques."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Guerriers du plan Astral, farouches ennemis des flagelleurs mentaux.$t$),
  ($t$Githzerai$t$, $t$Githzerai$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Discipline mentale","description":"Vous avez l'avantage aux jets de sauvegarde contre les états charmé et effrayé."},
      {"name":"Psionique githzerai","description":"Vous connaissez le sort mineur Main de mage, dont la main est invisible. Au niveau 3, vous pouvez lancer Bouclier, puis au niveau 5 Détection des pensées, chacun une fois par repos long sans emplacement (ou avec vos emplacements), sans composantes. Caractéristique d'incantation au choix : Intelligence, Sagesse ou Charisme."},
      {"name":"Résilience psychique","description":"Vous avez la résistance aux dégâts psychiques."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Moines ascètes installés dans les Limbes, maîtres de l'ordre intérieur.$t$),
  ($t$Gobelin$t$, $t$Goblin$t$, $t$Monstres du Multivers$t$, $t$Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Ascendance féerique","description":"Vous avez l'avantage aux jets de sauvegarde pour éviter ou terminer l'état charmé."},
      {"name":"Colère des petits","description":"Lorsque vous infligez des dégâts à une créature plus grande que vous, vous pouvez ajouter des dégâts supplémentaires égaux à votre bonus de maîtrise. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long ; une seule fois par tour."},
      {"name":"Fuite agile","description":"Vous pouvez effectuer l'action Désengagement ou Se cacher par une action bonus à chacun de vos tours."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Petits humanoïdes rusés et vifs, d'ascendance féerique.$t$),
  ($t$Hobgobelin$t$, $t$Hobgoblin$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Ascendance féerique","description":"Vous avez l'avantage aux jets de sauvegarde pour éviter ou terminer l'état charmé."},
      {"name":"Don féerique","description":"Vous pouvez effectuer l'action Aider par une action bonus. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long. À partir du niveau 3, choisissez un effet supplémentaire : Hospitalité (vous et la créature aidée obtenez 1d6 + bonus de maîtrise points de vie temporaires), Passage (vitesse +3 m pour vous deux jusqu'au début de votre prochain tour) ou Malveillance (jusqu'au début de votre prochain tour, la première attaque d'une créature de votre choix à 1,50 m se fait avec désavantage)."},
      {"name":"Fortune du nombre","description":"Si vous ratez un jet d'attaque, un test de caractéristique ou un jet de sauvegarde, vous pouvez ajouter un bonus égal au nombre d'alliés que vous voyez à 9 mètres ou moins (maximum +3). Utilisations égales à votre bonus de maîtrise, récupérées après un repos long."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes disciplinés d'ascendance féerique, réputés pour leur sens du collectif.$t$),
  ($t$Kenku$t$, $t$Kenku$t$, $t$Monstres du Multivers$t$, $t$Moyenne ou Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Copie experte","description":"Lorsque vous copiez une écriture ou un ouvrage d'art, y compris le vôtre, vous avez l'avantage à tout test de caractéristique pour produire une copie exacte."},
      {"name":"Mémoire kenku","description":"Vous maîtrisez deux compétences de votre choix. Lorsque vous effectuez un test utilisant une compétence que vous maîtrisez, vous pouvez vous donner l'avantage avant de lancer le dé. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long."},
      {"name":"Mimétisme","description":"Vous pouvez imiter les sons et les voix que vous avez entendus. Une créature qui les entend peut deviner qu'il s'agit d'une imitation en réussissant un test de Sagesse (Intuition) contre un DD de 8 + votre bonus de maîtrise + votre modificateur de Charisme."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes à plumes au don remarquable pour la copie et l'imitation.$t$),
  ($t$Kobold$t$, $t$Kobold$t$, $t$Monstres du Multivers$t$, $t$Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Cri draconique","description":"Par une action bonus, vous poussez un cri : jusqu'au début de votre prochain tour, vous et vos alliés avez l'avantage aux jets d'attaque contre les ennemis à 3 mètres ou moins de vous qui peuvent vous entendre. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long."},
      {"name":"Héritage kobold","description":"Choisissez une option : Ruse (maîtrise d'une compétence parmi Arcanes, Investigation, Médecine, Escamotage et Survie), Défi (avantage aux jets de sauvegarde pour éviter ou terminer l'état effrayé) ou Sorcellerie draconique (un sort mineur de la liste de l'ensorceleur, avec l'Intelligence, la Sagesse ou le Charisme comme caractéristique d'incantation)."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Petits humanoïdes reptiliens qui revendiquent un lien avec les dragons.$t$),
  ($t$Homme-lézard$t$, $t$Lizardfolk$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Nage","description":"Vous avez une vitesse de nage égale à votre vitesse au sol."},
      {"name":"Morsure","description":"Votre gueule est une arme naturelle : une touche inflige 1d6 + modificateur de Force dégâts perforants."},
      {"name":"Mâchoires affamées","description":"Par une action bonus, vous pouvez porter une attaque de morsure spéciale ; si elle touche, elle inflige ses dégâts normaux et vous obtenez des points de vie temporaires égaux à votre bonus de maîtrise. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long."},
      {"name":"Retenir son souffle","description":"Vous pouvez retenir votre respiration pendant 15 minutes."},
      {"name":"Armure naturelle","description":"Sans armure, votre CA est égale à 13 + votre modificateur de Dextérité. Un bouclier reste utilisable."},
      {"name":"Instincts du chasseur","description":"Vous maîtrisez deux compétences au choix parmi Dressage, Médecine, Nature, Perception, Discrétion et Survie."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes reptiliens pragmatiques, chasseurs et survivants des marais.$t$),
  ($t$Minotaure$t$, $t$Minotaur$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Cornes","description":"Vos cornes sont des armes naturelles : une touche inflige 1d6 + modificateur de Force dégâts perforants."},
      {"name":"Charge encornée","description":"Si vous effectuez l'action Foncer et parcourez au moins 6 mètres, vous pouvez effectuer une attaque avec vos cornes par une action bonus."},
      {"name":"Cornes martelantes","description":"Immédiatement après avoir touché avec une attaque au corps à corps dans le cadre de l'action Attaque, vous pouvez utiliser une action bonus pour tenter de repousser la cible de 3 mètres, si elle n'est pas plus grande que vous d'une catégorie ; elle doit réussir un jet de sauvegarde de Force DD 8 + bonus de maîtrise + modificateur de Force."},
      {"name":"Mémoire du labyrinthe","description":"Vous savez toujours où se trouve le nord et vous avez l'avantage aux tests de Sagesse (Survie) pour vous orienter ou suivre une piste."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes à tête de taureau, puissants et au sens de l'orientation infaillible.$t$),
  ($t$Satyre$t$, $t$Satyr$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 35, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes une Fée."},
      {"name":"Bélier","description":"Vous pouvez donner des coups de tête : une touche inflige 1d6 + modificateur de Force dégâts contondants."},
      {"name":"Résistance à la magie","description":"Vous avez l'avantage aux jets de sauvegarde contre les sorts."},
      {"name":"Bonds joyeux","description":"Lorsque vous effectuez un saut en longueur ou en hauteur, vous pouvez lancer 1d8 et ajouter le résultat au nombre de pieds parcourus (environ 30 cm par point)."},
      {"name":"Fêtard","description":"Vous maîtrisez les compétences Persuasion et Représentation, ainsi qu'un instrument de musique de votre choix."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Fées aux jambes de bouc, amatrices de musique et de réjouissances.$t$),
  ($t$Tabaxi$t$, $t$Tabaxi$t$, $t$Monstres du Multivers$t$, $t$Moyenne ou Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Escalade","description":"Vous avez une vitesse d'escalade égale à votre vitesse au sol."},
      {"name":"Griffes félines","description":"Vos griffes sont des armes naturelles : une touche inflige 1d6 + modificateur de Force dégâts tranchants."},
      {"name":"Talent félin","description":"Vous maîtrisez les compétences Perception et Discrétion."},
      {"name":"Agilité féline","description":"Lorsque vous vous déplacez pendant votre tour, vous pouvez doubler votre vitesse jusqu'à la fin du tour. Vous ne pouvez pas réutiliser ce trait avant d'avoir passé un de vos tours sans vous déplacer."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes félins curieux, voyageurs et collectionneurs d'histoires.$t$),
  ($t$Tortue$t$, $t$Tortle$t$, $t$Monstres du Multivers$t$, $t$Moyenne ou Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Griffes","description":"Vos griffes sont des armes naturelles : une touche inflige 1d6 + modificateur de Force dégâts tranchants."},
      {"name":"Retenir son souffle","description":"Vous pouvez retenir votre respiration pendant 1 heure."},
      {"name":"Armure naturelle","description":"Votre carapace vous donne une CA de base de 17 (votre modificateur de Dextérité ne s'applique pas). Vous ne pouvez pas porter d'armure, mais un bouclier reste utilisable."},
      {"name":"Défense de la carapace","description":"Par une action, vous vous retirez dans votre carapace : +4 à la CA, avantage aux jets de sauvegarde de Force et de Constitution, mais vous êtes à terre, votre vitesse est de 0, vous avez le désavantage aux jets de sauvegarde de Dextérité et ne pouvez pas effectuer de réaction. Vous en sortez par une action bonus."},
      {"name":"Instinct de survie","description":"Vous maîtrisez une compétence au choix parmi Dressage, Médecine, Nature, Perception, Discrétion et Survie."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes à carapace, voyageurs paisibles qui portent leur maison sur le dos.$t$),
  ($t$Triton$t$, $t$Triton$t$, $t$Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Amphibie","description":"Vous pouvez respirer dans l'air comme sous l'eau, et avez une vitesse de nage égale à votre vitesse au sol."},
      {"name":"Contrôle de l'air et de l'eau","description":"Vous pouvez lancer Nappe de brouillard, puis au niveau 3 Bourrasque et au niveau 5 Mur d'eau, chacun une fois par repos long sans emplacement (ou avec vos emplacements). Caractéristique d'incantation au choix : Intelligence, Sagesse ou Charisme."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Émissaire de la mer","description":"Vous pouvez communiquer des idées simples à toute bête, élémentaire ou monstruosité capable de respirer sous l'eau."},
      {"name":"Gardien des profondeurs","description":"Adapté aux abysses, vous avez la résistance aux dégâts de froid."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Gardiens des profondeurs marines, venus du plan élémentaire de l'Eau.$t$),
  ($t$Yuan-ti$t$, $t$Yuan-ti$t$, $t$Monstres du Multivers$t$, $t$Moyenne ou Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Résistance à la magie","description":"Vous avez l'avantage aux jets de sauvegarde contre les sorts."},
      {"name":"Résilience au poison","description":"Vous avez l'avantage aux jets de sauvegarde pour éviter ou terminer l'état empoisonné, et la résistance aux dégâts de poison."},
      {"name":"Héritage serpentin","description":"Vous connaissez le sort mineur Bouffée de poison et pouvez lancer Amitié avec les animaux à volonté, uniquement sur des serpents. Au niveau 3, vous pouvez lancer Suggestion une fois par repos long sans emplacement (ou avec vos emplacements). Caractéristique d'incantation au choix : Intelligence, Sagesse ou Charisme."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes au sang de serpent, marqués par une ancienne magie.$t$),
  ($t$Owlin$t$, $t$Owlin$t$, $t$Strixhaven : un programme de chaos$t$, $t$Moyenne ou Petite$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 36 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Vol","description":"Vous avez une vitesse de vol égale à votre vitesse au sol, inutilisable si vous portez une armure intermédiaire ou lourde."},
      {"name":"Silencieux","description":"Vous maîtrisez la compétence Discrétion."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Humanoïdes à l'apparence de chouette, silencieux en vol.$t$),
  ($t$Changeforme$t$, $t$Shifter$t$, $t$Eberron / Monstres du Multivers$t$, $t$Moyenne$t$, 30, $t${}$t$::jsonb, true,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Vision dans le noir","description":"Vous voyez dans l'obscurité jusqu'à 18 mètres comme s'il s'agissait de lumière faible."},
      {"name":"Sens bestiaux","description":"Vous maîtrisez une compétence au choix parmi Acrobaties, Athlétisme, Intimidation et Survie."},
      {"name":"Transformation","description":"Par une action bonus, vous prenez un aspect plus bestial pendant 1 minute et obtenez des points de vie temporaires égaux à 2 × votre bonus de maîtrise. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long. Choisissez une lignée qui ajoute un effet pendant la transformation : Peau de bête (1d6 points de vie temporaires supplémentaires et +1 à la CA), Longues dents (attaque de morsure 1d6 + Force perforants en action bonus), Foulée rapide (vitesse +3 m ; en réaction, vous vous déplacez de 3 m quand un ennemi termine son tour à 1,50 m de vous) ou Traque sauvage (avantage aux tests de Sagesse, et personne n'a l'avantage aux attaques contre vous)."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Descendants de lycanthropes capables de laisser affleurer leur nature bestiale.$t$),
  ($t$Forgelier$t$, $t$Warforged$t$, $t$Eberron : l'ascension après la Dernière Guerre$t$, $t$Moyenne$t$, 30, $t${"con":2,"choice_others":{"count":1,"amount":1}}$t$::jsonb, false,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde (créature artificielle vivante)."},
      {"name":"Résilience d'artifice","description":"Vous avez l'avantage aux jets de sauvegarde contre le poison et la résistance aux dégâts de poison. Vous êtes immunisé contre les maladies, n'avez pas besoin de manger, boire ni respirer, et la magie ne peut pas vous endormir."},
      {"name":"Repos de sentinelle","description":"Pour un repos long, vous passez au moins 6 heures dans un état inactif mais conscient, au lieu de dormir."},
      {"name":"Protection intégrée","description":"Vous obtenez un bonus de +1 à la CA. Vous ne pouvez revêtir ou retirer une armure qu'en l'intégrant à votre corps pendant 1 heure, et on ne peut pas vous l'ôter contre votre gré."},
      {"name":"Conception spécialisée","description":"Vous maîtrisez une compétence et un outil de votre choix."}]$t$::jsonb,
   $t$["Commun","une langue de son choix"]$t$::jsonb,
   $t$Soldats artificiels conçus pour la Dernière Guerre d'Eberron, désormais en quête de sens.$t$),
  ($t$Kalashtar$t$, $t$Kalashtar$t$, $t$Eberron : l'ascension après la Dernière Guerre$t$, $t$Moyenne$t$, 30, $t${"wis":2,"cha":1}$t$::jsonb, false,
   $t$[{"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Esprit double","description":"Vous avez l'avantage à tous les jets de sauvegarde de Sagesse."},
      {"name":"Discipline mentale","description":"Vous avez la résistance aux dégâts psychiques."},
      {"name":"Lien mental","description":"Vous pouvez parler par télépathie à toute créature que vous voyez, à une distance maximale de 3 mètres par niveau. Par une action, vous pouvez permettre à une créature de vous répondre ainsi pendant 1 heure, tant qu'elle reste à portée."},
      {"name":"Coupé des rêves","description":"Vous dormez sans rêver : vous êtes immunisé contre les sorts et effets qui nécessitent de rêver, comme le sort Songe, mais pas contre ceux qui endorment."}]$t$::jsonb,
   $t$["Commun","Quori","une langue de son choix"]$t$::jsonb,
   $t$Humains liés à un esprit quori renégat, dotés de dons psychiques.$t$)
    ) as t(name_fr, name_en, source, size, speed, ability_bonuses, flexible_asi, traits, languages, description)
  loop
    if not exists (
      select 1 from public.translations tr
       where tr.entity_type = 'race' and tr.field_name = 'name' and tr.locale = 'fr'
         and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.races (source, size, speed, ability_bonuses, traits, languages, is_incomplete)
        values (rec.source, rec.size, rec.speed, rec.ability_bonuses,
                case when rec.flexible_asi then jsonb_build_array(c_asi) || rec.traits else rec.traits end,
                rec.languages, false)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('race', v_id::text, 'name', 'fr', rec.name_fr),
        ('race', v_id::text, 'name', 'en', rec.name_en),
        ('race', v_id::text, 'description', 'fr', rec.description);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'espèces insérées : %', v_inserted;
end $$;

-- Conil (Harengon, Monstres du Multivers) : la ligne existe (id 26) mais n'était qu'une ébauche.
update public.races
   set source = 'Monstres du Multivers',
       size = 'Moyenne ou Petite',
       speed = 30,
       ability_bonuses = '{}'::jsonb,
       traits = $t$[{"name":"Augmentation de caractéristiques","description":"Augmentez une caractéristique de 2 et une autre de 1, ou trois caractéristiques différentes de 1 chacune, au choix."},
      {"name":"Type de créature","description":"Vous êtes un Humanoïde."},
      {"name":"Réflexes de lièvre","description":"Vous ajoutez votre bonus de maîtrise à vos jets d'initiative."},
      {"name":"Sens léporins","description":"Vous maîtrisez la compétence Perception."},
      {"name":"Pied chanceux","description":"Lorsque vous ratez un jet de sauvegarde de Dextérité, vous pouvez utiliser votre réaction pour lancer 1d4 et l'ajouter au résultat, ce qui peut transformer l'échec en réussite. Impossible si vous êtes à terre ou si votre vitesse est de 0."},
      {"name":"Bond du lapin","description":"Par une action bonus, vous sautez d'un nombre de mètres égal à 1,50 × votre bonus de maîtrise, sans provoquer d'attaque d'opportunité. Uniquement si votre vitesse n'est pas de 0. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long."}]$t$::jsonb,
       languages = '["Commun","une langue de son choix"]'::jsonb,
       is_incomplete = false
 where id = 26 and is_incomplete;

insert into public.translations (entity_type, entity_id, field_name, locale, value)
select 'race', '26', v.field_name, v.locale, v.value
  from (values
    ('name', 'en', $t$Harengon$t$),
    ('description', 'fr', $t$Humanoïdes lapins originaires de la Féerie, vifs et chanceux.$t$)
  ) as v(field_name, locale, value)
 where exists (select 1 from public.races where id = 26)
   and not exists (select 1 from public.translations t
                    where t.entity_type = 'race' and t.entity_id = '26'
                      and t.field_name = v.field_name and t.locale = v.locale);

-- Sous-races (d'après Mordenkainen présente : Monstres et Multivers).
do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
  (2, $t$Eladrin$t$, $t$Eladrin$t$, $t${"cha":1}$t$::jsonb,
   $t$[{"name":"Pas féerique","description":"Par une action bonus, vous vous téléportez jusqu'à 9 mètres dans un espace inoccupé que vous voyez (une fois par repos court ou long). À partir du niveau 3, le pas produit un effet selon votre saison : Automne (jusqu'à deux créatures à 3 m de vous doivent réussir un jet de sauvegarde de Sagesse ou être charmées 1 minute), Hiver (une créature à 1,50 m de votre point de départ doit réussir un jet de sauvegarde de Sagesse ou être effrayée jusqu'à la fin de votre prochain tour), Printemps (vous pouvez téléporter une créature consentante à 1,50 m de vous à la place) ou Été (chaque créature à 1,50 m de votre arrivée subit des dégâts de feu égaux à votre modificateur de Charisme). Le DD est de 8 + bonus de maîtrise + modificateur de Charisme."},
      {"name":"Saisons changeantes","description":"À la fin d'un repos long, vous pouvez changer de saison, ce qui modifie votre apparence et votre humeur."}]$t$::jsonb,
   $t$Elfes de la Féerie dont l'humeur et l'apparence suivent le cycle des saisons.$t$),
  (2, $t$Elfe marin$t$, $t$Sea Elf$t$, $t${"con":1}$t$::jsonb,
   $t$[{"name":"Entraînement martial des elfes marins","description":"Vous maîtrisez la lance, le trident, l'arbalète légère et le filet."},
      {"name":"Enfant de la mer","description":"Vous avez une vitesse de nage de 9 mètres et pouvez respirer dans l'air comme sous l'eau."},
      {"name":"Ami de la mer","description":"Grâce à des gestes et des sons, vous pouvez communiquer des idées simples à toute bête capable de respirer sous l'eau."},
      {"name":"Langue supplémentaire","description":"Vous parlez, lisez et écrivez l'aquatique."}]$t$::jsonb,
   $t$Elfes adaptés à la vie sous les vagues, amis des créatures marines.$t$),
  (2, $t$Shadar-kai$t$, $t$Shadar-kai$t$, $t${"con":1}$t$::jsonb,
   $t$[{"name":"Résistance nécrotique","description":"Vous avez la résistance aux dégâts nécrotiques."},
      {"name":"Bénédiction de la Reine corbeau","description":"Par une action bonus, vous vous téléportez jusqu'à 9 mètres dans un espace inoccupé que vous voyez (une fois par repos long). À partir du niveau 3, vous avez aussi la résistance à tous les dégâts jusqu'au début de votre prochain tour après cette téléportation."}]$t$::jsonb,
   $t$Elfes au service de la Reine corbeau, liés à la Gisombre.$t$),
  (3, $t$Duergar$t$, $t$Duergar$t$, $t${"str":1}$t$::jsonb,
   $t$[{"name":"Vision dans le noir supérieure","description":"Votre vision dans le noir a une portée de 36 mètres (remplace celle de la race Nain)."},
      {"name":"Résilience duergar","description":"Vous avez l'avantage aux jets de sauvegarde contre les illusions et contre les états charmé et paralysé."},
      {"name":"Magie duergar","description":"À partir du niveau 3, vous pouvez lancer Agrandissement/Rapetissement sur vous-même (agrandissement uniquement) une fois par repos long ; à partir du niveau 5, Invisibilité sur vous-même une fois par repos long. Sans composantes matérielles ; l'Intelligence est votre caractéristique d'incantation."},
      {"name":"Sensibilité au soleil","description":"Vous avez le désavantage aux jets d'attaque et aux tests de Sagesse (Perception) basés sur la vue lorsque vous, votre cible ou ce que vous cherchez êtes en plein soleil."}]$t$::jsonb,
   $t$Nains de l'Outreterre, endurcis par des siècles d'esclavage sous les flagelleurs mentaux.$t$)
    ) as t(race_id, name_fr, name_en, ability_bonuses, traits, description)
  loop
    if exists (select 1 from public.races where id = rec.race_id)
       and not exists (
         select 1 from public.translations tr
          where tr.entity_type = 'subrace' and tr.field_name = 'name' and tr.locale = 'fr'
            and lower(tr.value) = lower(rec.name_fr)
       ) then
      insert into public.subraces (race_id, ability_bonuses, traits)
        values (rec.race_id, rec.ability_bonuses, rec.traits)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('subrace', v_id::text, 'name', 'fr', rec.name_fr),
        ('subrace', v_id::text, 'name', 'en', rec.name_en),
        ('subrace', v_id::text, 'description', 'fr', rec.description);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'sous-races insérées : %', v_inserted;
end $$;

-- Contrôle final : toute anomalie annule la migration entière.
do $$
declare
  v_races int;
  v_subraces int;
begin
  select count(*) into v_races
    from public.translations
   where entity_type = 'race' and field_name = 'name' and locale = 'fr'
     and value in ('Aasimar','Gobelours','Centaure','Changelin','Fée','Firbolg','Githyanki','Githzerai',
                   'Gobelin','Hobgobelin','Kenku','Kobold','Homme-lézard','Minotaure','Satyre','Tabaxi',
                   'Tortue','Triton','Yuan-ti','Owlin','Changeforme','Forgelier','Kalashtar');
  if v_races <> 23 then
    raise exception 'Contrôle lot 4 : % espèces sur 23 attendues', v_races;
  end if;
  select count(*) into v_subraces
    from public.translations
   where entity_type = 'subrace' and field_name = 'name' and locale = 'fr'
     and value in ('Eladrin','Elfe marin','Shadar-kai','Duergar');
  if v_subraces <> 4 then
    raise exception 'Contrôle lot 4 : % sous-races sur 4 attendues', v_subraces;
  end if;
  if exists (select 1 from public.races where is_incomplete) then
    raise exception 'Contrôle lot 4 : une race reste marquée incomplète';
  end if;
end $$;
