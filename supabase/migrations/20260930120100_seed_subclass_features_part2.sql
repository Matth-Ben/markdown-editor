-- Lot 5b de l'import du contenu de référence : aptitudes manquantes des sous-classes qui n'en
-- comptaient qu'une (Moine, Occultiste, Paladin, Rôdeur, Roublard).
-- Texte français reformulé d'après les livres d'origine (Xanathar, Tasha, SCAG, Fizban, Van Richten).
-- Idempotente : une aptitude n'est insérée que si la sous-classe n'a pas déjà une aptitude du même nom FR.

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
  -- Moine — Voie de l'âme solaire (67)
  (67, 6, null::text, $t$Frappe en arc ardente$t$, $t$Searing Arc Strike$t$, $t$Immédiatement après l'action Attaque, vous pouvez dépenser 2 points de ki pour lancer Mains brûlantes par une action bonus, et 1 point de ki supplémentaire par niveau d'emplacement au-delà du premier (maximum égal à la moitié de votre niveau de moine).$t$),
  (67, 11, null, $t$Explosion solaire ardente$t$, $t$Searing Sunburst$t$, $t$Par une action, vous créez un orbe de lumière qui explose en une sphère de 6 m de rayon en un point à 45 m ou moins : chaque créature dans la zone doit réussir un jet de sauvegarde de Constitution ou subir 2d6 dégâts radiants. Vous pouvez dépenser jusqu'à 3 points de ki pour ajouter 2d6 dégâts par point.$t$),
  (67, 17, null, $t$Bouclier solaire$t$, $t$Sun Shield$t$, $t$Vous émettez une lumière vive sur 9 m (désactivable par une action bonus). Lorsqu'une créature vous touche avec une attaque au corps à corps pendant que cette lumière brille, vous pouvez utiliser votre réaction pour lui infliger 5 + votre modificateur de Sagesse dégâts radiants.$t$),
  -- Moine — Voie du moi astral (68)
  (68, 6, null, $t$Visage du moi astral$t$, $t$Visage of the Astral Self$t$, $t$Par une action bonus et 1 point de ki, vous invoquez le visage de votre moi astral pendant 10 minutes : vision dans le noir de 36 m (même magique), avantage aux tests de Sagesse (Intuition) et de Charisme (Intimidation), et voix portant jusqu'à 180 m ou audible d'une seule créature.$t$),
  (68, 11, null, $t$Corps du moi astral$t$, $t$Body of the Astral Self$t$, $t$Lorsque bras et visage astraux sont invoqués : par une réaction, vous réduisez de 1d10 + votre modificateur de Sagesse les dégâts d'acide, de feu, de force, de foudre, de froid ou de tonnerre que vous subissez ; et une fois par tour, une attaque réussie avec vos bras astraux inflige un dé d'arts martiaux de dégâts de force supplémentaires.$t$),
  (68, 17, null, $t$Moi astral éveillé$t$, $t$Awakened Astral Self$t$, $t$Par une action bonus et 5 points de ki, vous invoquez bras, visage et corps astraux pendant 10 minutes : +2 à la CA, et l'action Attaque vous permet de porter trois attaques avec vos bras astraux.$t$),
  -- Moine — Voie de la miséricorde (69)
  (69, 3, null, $t$Instruments de miséricorde$t$, $t$Implements of Mercy$t$, $t$Vous maîtrisez l'Intuition, la Médecine et le kit d'herboriste, et possédez un masque rituel que vous portez souvent pendant vos soins ou vos frappes.$t$),
  (69, 6, null, $t$Toucher du médecin$t$, $t$Physician's Touch$t$, $t$Vos Mains de guérison mettent aussi fin à une maladie ou à l'un des états suivants : aveuglé, assourdi, paralysé, empoisonné ou étourdi. Vos Mains de souffrance peuvent rendre la cible empoisonnée jusqu'à la fin de votre prochain tour.$t$),
  (69, 11, null, $t$Déluge de soins et de souffrances$t$, $t$Flurry of Healing and Harm$t$, $t$Lors d'une Déluge de coups, vous pouvez remplacer chaque attaque à mains nues par une utilisation de Mains de guérison sans dépenser de ki. Vous pouvez aussi utiliser Mains de souffrance sans ki sur une des frappes de la Déluge (une fois par tour). Utilisations gratuites égales à votre modificateur de Sagesse par repos long.$t$),
  (69, 17, null, $t$Main de miséricorde ultime$t$, $t$Hand of Ultimate Mercy$t$, $t$Par une action et 5 points de ki, vous touchez le cadavre d'une créature morte depuis moins de 24 heures : elle revient à la vie avec 4d10 + votre modificateur de Sagesse points de vie, libérée des états aveuglé, assourdi, paralysé, empoisonné et étourdi. Une fois par repos long.$t$),
  -- Moine — Voie du dragon ascendant (70)
  (70, 3, null, $t$Disciple draconique$t$, $t$Draconic Disciple$t$, $t$Vos attaques à mains nues peuvent infliger des dégâts d'acide, de feu, de foudre, de froid ou de poison. Vous apprenez le draconique et, une fois par repos long, pouvez transformer un échec à un test de Charisme (Intimidation ou Persuasion) en réussite.$t$),
  (70, 6, null, $t$Ailes déployées$t$, $t$Wings Unfurled$t$, $t$Lorsque vous utilisez Pas du vent, vous pouvez déployer des ailes spectrales et gagner une vitesse de vol égale à votre vitesse jusqu'à la fin du tour. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (70, 11, null, $t$Aspect du wyrm$t$, $t$Aspect of the Wyrm$t$, $t$Par une action bonus, pendant 1 minute, vous créez une aura de 3 m : soit Présence effrayante (à la création puis par une action bonus, une créature de l'aura doit réussir un jet de sauvegarde de Sagesse contre votre DD de ki ou être effrayée 1 minute), soit Résistance (vous et vos alliés dans l'aura résistez à l'acide, au feu, à la foudre, au froid ou au poison, au choix). Une fois par repos long, ou pour 3 points de ki.$t$),
  (70, 17, null, $t$Aspect ascendant$t$, $t$Ascendant Aspect$t$, $t$Souffle amplifié : en dépensant 1 point de ki, votre Souffle du dragon devient un cône de 18 m ou une ligne de 27 m et inflige quatre dés d'arts martiaux de dégâts (moitié en cas de réussite). Vision aveugle : vous obtenez une vision aveugle de 3 m. Fureur explosive : lorsque vous activez votre Aspect du wyrm, les créatures de votre choix dans l'aura doivent réussir un jet de sauvegarde de Dextérité contre votre DD de ki ou subir 3d10 dégâts d'acide, de feu, de foudre, de froid ou de poison.$t$),
  -- Moine — Voie du kensei (71)
  (71, 6, null, $t$Un avec la lame$t$, $t$One with the Blade$t$, $t$Vos attaques avec une arme de kensei comptent comme magiques. Frappe habile : lorsque vous touchez avec une arme de kensei, vous pouvez dépenser 1 point de ki pour ajouter un dé d'arts martiaux aux dégâts (une fois par tour).$t$),
  (71, 11, null, $t$Aiguiser la lame$t$, $t$Sharpen the Blade$t$, $t$Par une action bonus, vous dépensez jusqu'à 3 points de ki pour accorder à une arme de kensei un bonus égal aux points dépensés aux jets d'attaque et de dégâts pendant 1 minute (sans effet sur une arme magique ayant déjà un bonus).$t$),
  (71, 17, null, $t$Précision infaillible$t$, $t$Unerring Accuracy$t$, $t$Une fois à chacun de vos tours, si vous ratez un jet d'attaque avec une arme de moine, vous pouvez le relancer.$t$),
  -- Moine — Voie du maître ivre (72)
  (72, 3, null, $t$Maîtrises supplémentaires$t$, $t$Bonus Proficiencies$t$, $t$Vous maîtrisez la Représentation et les outils de brasseur.$t$),
  (72, 6, null, $t$Démarche vacillante$t$, $t$Tipsy Sway$t$, $t$Se relever ne vous coûte que 1,50 m de déplacement. Lorsqu'une créature vous rate au corps à corps, vous pouvez dépenser 1 point de ki et utiliser votre réaction pour rediriger l'attaque vers une autre créature de votre choix à 1,50 m de vous (autre que l'attaquant).$t$),
  (72, 11, null, $t$Chance de l'ivrogne$t$, $t$Drunkard's Luck$t$, $t$Lorsque vous avez le désavantage à un test, un jet d'attaque ou un jet de sauvegarde, vous pouvez dépenser 2 points de ki pour l'annuler.$t$),
  (72, 17, null, $t$Frénésie éthylique$t$, $t$Intoxicated Frenzy$t$, $t$Lors d'une Déluge de coups, vous pouvez porter jusqu'à trois attaques supplémentaires (cinq au total), chacune devant viser une créature différente.$t$),
  -- Occultiste — Céleste (75)
  (75, 1, $t$sort_domaine$t$, $t$Liste de sorts étendue$t$, $t$Expanded Spell List$t$, $t$Sorts ajoutés à votre liste d'occultiste : niveau 1 — Soins, Rayon traçant ; niveau 2 — Sphère de feu, Restauration partielle ; niveau 3 — Lumière du jour, Retour à la vie ; niveau 4 — Gardien de la foi, Mur de feu ; niveau 5 — Colonne de flamme, Restauration supérieure.$t$),
  (75, 1, null, $t$Sorts mineurs supplémentaires$t$, $t$Bonus Cantrips$t$, $t$Vous apprenez les sorts mineurs Lumière et Flamme sacrée, qui comptent comme des sorts d'occultiste sans être décomptés.$t$),
  (75, 6, null, $t$Âme radieuse$t$, $t$Radiant Soul$t$, $t$Vous avez la résistance aux dégâts radiants. Lorsque vous lancez un sort qui inflige des dégâts radiants ou de feu, vous ajoutez votre modificateur de Charisme à un jet de dégâts de ce sort contre une cible.$t$),
  (75, 10, null, $t$Résistance céleste$t$, $t$Celestial Resilience$t$, $t$À la fin d'un repos court ou long, vous gagnez des points de vie temporaires égaux à votre niveau d'occultiste + votre modificateur de Charisme, et jusqu'à cinq créatures de votre choix en gagnent la moitié de votre niveau + votre modificateur de Charisme.$t$),
  (75, 14, null, $t$Vengeance ardente$t$, $t$Searing Vengeance$t$, $t$Lorsque vous devez faire un jet de sauvegarde contre la mort, vous pouvez vous relever avec la moitié de vos points de vie maximum ; chaque créature de votre choix à 9 m ou moins subit 2d8 + votre modificateur de Charisme dégâts radiants et est aveuglée jusqu'à la fin du tour. Une fois par repos long.$t$),
  -- Occultiste — Insondable (80)
  (80, 1, $t$sort_domaine$t$, $t$Liste de sorts étendue$t$, $t$Expanded Spell List$t$, $t$Sorts ajoutés à votre liste d'occultiste : niveau 1 — Création ou destruction d'eau, Vague tonnante ; niveau 2 — Bourrasque, Silence ; niveau 3 — Éclair, Tempête de neige ; niveau 4 — Contrôle de l'eau, Invocation d'élémentaire (eau uniquement) ; niveau 5 — Main de Bigby (sous forme de tentacule), Cône de froid.$t$),
  (80, 1, null, $t$Don de la mer$t$, $t$Gift of the Sea$t$, $t$Vous obtenez une vitesse de nage de 12 m et pouvez respirer sous l'eau.$t$),
  (80, 6, null, $t$Âme océanique$t$, $t$Oceanic Soul$t$, $t$Vous avez la résistance aux dégâts de froid. Lorsque vous êtes entièrement immergé, toute créature elle aussi immergée peut comprendre vos paroles, et vous comprenez les siennes.$t$),
  (80, 6, null, $t$Anneau protecteur$t$, $t$Guardian Coil$t$, $t$Lorsque vous ou une créature que vous voyez subissez des dégâts à 3 m ou moins de votre tentacule, vous pouvez utiliser votre réaction pour réduire ces dégâts de 1d8 (2d8 au niveau 10).$t$),
  (80, 10, null, $t$Tentacules agrippants$t$, $t$Grasping Tentacles$t$, $t$Vous apprenez Tentacules noirs d'Evard, toujours préparé, et pouvez le lancer une fois sans emplacement par repos long. Lorsque vous le lancez, vous gagnez des points de vie temporaires égaux à votre niveau d'occultiste, et les dégâts ne peuvent pas briser votre concentration sur ce sort.$t$),
  (80, 14, null, $t$Plongeon insondable$t$, $t$Fathomless Plunge$t$, $t$Par une action, vous et jusqu'à cinq créatures consentantes à 9 m ou moins vous téléportez vers un plan d'eau que vous avez déjà vu, à 1,5 km ou moins, en arrivant à 9 m ou moins les uns des autres. Une fois par repos court ou long.$t$),
  -- Occultiste — Lame maudite (81)
  (81, 1, $t$sort_domaine$t$, $t$Liste de sorts étendue$t$, $t$Expanded Spell List$t$, $t$Sorts ajoutés à votre liste d'occultiste : niveau 1 — Bouclier, Châtiment courroucé ; niveau 2 — Flou, Châtiment révélateur ; niveau 3 — Clignotement, Arme élémentaire ; niveau 4 — Assassin imaginaire, Châtiment stupéfiant ; niveau 5 — Châtiment du bannissement, Cône de froid.$t$),
  (81, 1, null, $t$Guerrier maléfique$t$, $t$Hex Warrior$t$, $t$Vous maîtrisez les armures intermédiaires, les boucliers et les armes de guerre. Après un repos long, vous pouvez lier une arme que vous maîtrisez (sans la propriété deux mains) : vous utilisez votre Charisme au lieu de la Force ou de la Dextérité pour ses jets d'attaque et de dégâts. Cela s'applique aussi à votre arme de pacte.$t$),
  (81, 6, null, $t$Spectre maudit$t$, $t$Accursed Specter$t$, $t$Lorsque vous tuez un humanoïde, vous pouvez relever son esprit en spectre sous votre contrôle jusqu'à votre prochain repos long, avec des points de vie temporaires égaux à la moitié de votre niveau et un bonus à l'attaque égal à votre modificateur de Charisme. Une fois par repos long.$t$),
  (81, 10, null, $t$Armure de maléfices$t$, $t$Armor of Hexes$t$, $t$Si la cible de votre Malédiction de la lame maudite vous touche, vous pouvez utiliser votre réaction et lancer un d6 : sur 4 ou plus, l'attaque vous rate automatiquement.$t$),
  (81, 14, null, $t$Maître des maléfices$t$, $t$Master of Hexes$t$, $t$Lorsque la créature maudite par votre Malédiction de la lame maudite meurt, vous pouvez transférer la malédiction à une autre créature que vous voyez à 9 m ou moins, sans regagner de points de vie.$t$),
  -- Occultiste — Mort-vivant (82)
  (82, 1, $t$sort_domaine$t$, $t$Liste de sorts étendue$t$, $t$Expanded Spell List$t$, $t$Sorts ajoutés à votre liste d'occultiste : niveau 1 — Fléau, Simulacre de vie ; niveau 2 — Cécité/Surdité, Force fantasmagorique ; niveau 3 — Coursier fantôme, Communication avec les morts ; niveau 4 — Protection contre la mort, Invisibilité supérieure ; niveau 5 — Barrière anti-vie, Brume mortelle.$t$),
  (82, 1, null, $t$Forme d'effroi$t$, $t$Form of Dread$t$, $t$Par une action bonus, vous prenez une forme terrifiante pendant 1 minute : points de vie temporaires égaux à 1d10 + votre niveau d'occultiste, immunité à l'état effrayé, et une fois par tour, une créature que vous touchez d'une attaque doit réussir un jet de sauvegarde de Sagesse ou être effrayée jusqu'à la fin de votre prochain tour. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (82, 6, null, $t$Touché par la tombe$t$, $t$Grave Touched$t$, $t$Vous n'avez plus besoin de manger, boire ni respirer. Une fois par tour, lorsque vous touchez une créature et lui infligez des dégâts, vous pouvez les convertir en dégâts nécrotiques ; en Forme d'effroi, vous lancez un dé de dégâts supplémentaire.$t$),
  (82, 10, null, $t$Carcasse nécrotique$t$, $t$Necrotic Husk$t$, $t$Vous avez la résistance aux dégâts nécrotiques (l'immunité en Forme d'effroi). Lorsque vous tombez à 0 point de vie, vous pouvez tomber à 1 point de vie à la place : chaque créature à 9 m ou moins subit 2d10 + votre niveau d'occultiste dégâts nécrotiques, et vous gagnez un niveau d'épuisement. Réutilisable seulement après 1d4 repos longs.$t$),
  (82, 14, null, $t$Projection spirituelle$t$, $t$Spirit Projection$t$, $t$Par une action, vous projetez votre esprit hors de votre corps pendant 1 heure (concentration) : il a vos statistiques, la résistance aux dégâts contondants, perforants et tranchants, vole à votre vitesse, traverse les objets, et vos sorts d'invocation ou de nécromancie ne nécessitent ni composantes verbales ni somatiques. Une fois par repos long.$t$),
  -- Paladin — Serment de conquête (85)
  (85, 3, $t$sort_domaine$t$, $t$Sorts de serment de conquête$t$, $t$Oath Spells$t$, $t$Toujours préparés : niveau 3 — Armure d'Agathys, Injonction ; niveau 5 — Immobilisation de personne, Arme spirituelle ; niveau 9 — Malédiction, Terreur ; niveau 13 — Domination de bête, Peau de pierre ; niveau 17 — Brume mortelle, Domination de personne.$t$),
  (85, 3, null, $t$Frappe guidée$t$, $t$Guided Strike$t$, $t$Conduit divin : lorsque vous effectuez un jet d'attaque, vous pouvez utiliser votre Conduit divin pour obtenir un bonus de +10 à ce jet, après avoir vu le dé mais avant de connaître le résultat.$t$),
  (85, 7, null, $t$Aura de conquête$t$, $t$Aura of Conquest$t$, $t$Une créature effrayée par vous qui se trouve à 3 m ou moins de vous (9 m au niveau 18) a une vitesse de 0 et subit des dégâts psychiques égaux à la moitié de votre niveau de paladin au début de son tour.$t$),
  (85, 15, null, $t$Réprimande méprisante$t$, $t$Scornful Rebuke$t$, $t$Une créature qui vous touche avec une attaque subit des dégâts psychiques égaux à votre modificateur de Charisme (minimum 1), si vous n'êtes pas neutralisé.$t$),
  (85, 20, null, $t$Conquérant invincible$t$, $t$Invincible Conqueror$t$, $t$Par une action, pendant 1 minute : résistance à tous les dégâts, une attaque supplémentaire avec l'action Attaque, et vos attaques au corps à corps sont des coups critiques sur 19 ou 20. Une fois par repos long.$t$),
  -- Paladin — Serment de gloire (86)
  (86, 3, $t$sort_domaine$t$, $t$Sorts de serment de gloire$t$, $t$Oath Spells$t$, $t$Toujours préparés : niveau 3 — Rayon traçant, Héroïsme ; niveau 5 — Amélioration de caractéristique, Arme magique ; niveau 9 — Hâte, Protection contre l'énergie ; niveau 13 — Coercition mystique, Liberté de mouvement ; niveau 17 — Communion, Colonne de flamme.$t$),
  (86, 3, null, $t$Châtiment inspirant$t$, $t$Inspiring Smite$t$, $t$Conduit divin : immédiatement après un Châtiment divin, par une action bonus, vous répartissez 2d8 + votre niveau de paladin points de vie temporaires entre les créatures de votre choix à 9 m ou moins (vous compris).$t$),
  (86, 7, null, $t$Aura d'alacrité$t$, $t$Aura of Alacrity$t$, $t$Votre vitesse augmente de 3 m. Un allié qui commence son tour à 1,50 m ou moins de vous (3 m au niveau 18) gagne 3 m de vitesse jusqu'à la fin de ce tour.$t$),
  (86, 15, null, $t$Défense glorieuse$t$, $t$Glorious Defense$t$, $t$Par une réaction, lorsque vous ou une créature à 3 m ou moins êtes touchés, vous ajoutez votre modificateur de Charisme à la CA de la cible ; si l'attaque rate alors, vous pouvez porter une attaque armée contre l'attaquant s'il est à portée. Utilisations égales à votre modificateur de Charisme, récupérées après un repos long.$t$),
  (86, 20, null, $t$Légende vivante$t$, $t$Living Legend$t$, $t$Par une action bonus, pendant 1 minute : avantage aux tests de Charisme ; une fois par tour, une attaque armée ratée peut devenir une touche ; et par une réaction, vous pouvez relancer un jet de sauvegarde raté. Une fois par repos long, ou en dépensant un emplacement de niveau 5.$t$),
  -- Paladin — Serment des guetteurs (87)
  (87, 3, $t$sort_domaine$t$, $t$Sorts de serment des guetteurs$t$, $t$Oath Spells$t$, $t$Toujours préparés : niveau 3 — Alarme, Détection de la magie ; niveau 5 — Rayon de lune, Détection de l'invisibilité ; niveau 9 — Contresort, Antidétection ; niveau 13 — Aura de pureté, Bannissement ; niveau 17 — Immobilisation de monstre, Scrutation.$t$),
  (87, 3, null, $t$Abjuration des extraplanaires$t$, $t$Abjure the Extraplanar$t$, $t$Conduit divin : par une action, chaque aberration, céleste, élémentaire, fée ou fiélon à 9 m ou moins qui vous entend doit réussir un jet de sauvegarde de Sagesse ou être repoussé pendant 1 minute (ou jusqu'à subir des dégâts).$t$),
  (87, 7, null, $t$Aura de la sentinelle$t$, $t$Aura of the Sentinel$t$, $t$Vous et les créatures de votre choix à 3 m ou moins de vous (9 m au niveau 18) ajoutez votre bonus de maîtrise à vos jets d'initiative.$t$),
  (87, 15, null, $t$Réprimande vigilante$t$, $t$Vigilant Rebuke$t$, $t$Par une réaction, lorsque vous ou une créature que vous voyez à 9 m ou moins réussissez un jet de sauvegarde d'Intelligence, de Sagesse ou de Charisme, la créature à l'origine de l'effet subit 2d8 + votre modificateur de Charisme dégâts de force.$t$),
  (87, 20, null, $t$Rempart des mortels$t$, $t$Mortal Bulwark$t$, $t$Par une action bonus, pendant 1 minute : vision véritable sur 36 m, avantage aux attaques contre les aberrations, célestes, élémentaires, fées et fiélons, et une telle créature que vous touchez doit réussir un jet de sauvegarde de Charisme ou être renvoyée sur son plan d'origine. Une fois par repos long, ou en dépensant un emplacement de niveau 5.$t$),
  -- Paladin — Serment de rédemption (88)
  (88, 3, $t$sort_domaine$t$, $t$Sorts de serment de rédemption$t$, $t$Oath Spells$t$, $t$Toujours préparés : niveau 3 — Sanctuaire, Sommeil ; niveau 5 — Apaisement des émotions, Immobilisation de personne ; niveau 9 — Contresort, Motif hypnotique ; niveau 13 — Sphère résiliente d'Otiluke, Peau de pierre ; niveau 17 — Immobilisation de monstre, Mur de force.$t$),
  (88, 3, null, $t$Réprimande des violents$t$, $t$Rebuke the Violent$t$, $t$Conduit divin : par une réaction, lorsqu'une créature à 9 m ou moins inflige des dégâts à une autre créature que vous, elle doit réussir un jet de sauvegarde de Sagesse ou subir des dégâts radiants égaux à ceux qu'elle vient d'infliger (moitié en cas de réussite).$t$),
  (88, 7, null, $t$Aura du gardien$t$, $t$Aura of the Guardian$t$, $t$Par une réaction, lorsqu'une créature à 3 m ou moins de vous (9 m au niveau 18) subit des dégâts, vous les subissez à sa place ; ces dégâts ne peuvent pas être réduits.$t$),
  (88, 15, null, $t$Esprit protecteur$t$, $t$Protective Spirit$t$, $t$À la fin de chacun de vos tours, si vous avez moins de la moitié de vos points de vie et n'êtes pas neutralisé, vous récupérez 1d6 + la moitié de votre niveau de paladin points de vie.$t$),
  (88, 20, null, $t$Émissaire de la rédemption$t$, $t$Emissary of Redemption$t$, $t$Vous avez la résistance à tous les dégâts infligés par d'autres créatures, et une créature qui vous blesse subit des dégâts radiants égaux à la moitié de ceux infligés. Vous perdez ces bénéfices face à une créature que vous attaquez ou ciblez d'un sort, jusqu'à votre prochain repos long.$t$),
  -- Rôdeur — Arpenteur de l'horizon (90)
  (90, 3, $t$sort_domaine$t$, $t$Magie de l'arpenteur de l'horizon$t$, $t$Horizon Walker Magic$t$, $t$Sorts toujours connus : niveau 3 — Protection contre le mal et le bien ; niveau 5 — Pas brumeux ; niveau 9 — Hâte ; niveau 13 — Bannissement ; niveau 17 — Cercle de téléportation.$t$),
  (90, 7, null, $t$Pas éthéré$t$, $t$Ethereal Step$t$, $t$Par une action bonus, vous passez dans le plan éthéré jusqu'à la fin de votre tour. Une fois par repos court ou long.$t$),
  (90, 11, null, $t$Frappe lointaine$t$, $t$Distant Strike$t$, $t$Lors de l'action Attaque, vous pouvez vous téléporter jusqu'à 3 m avant chaque attaque dans un espace que vous voyez. Si vous attaquez au moins deux créatures différentes pendant l'action, vous pouvez porter une attaque supplémentaire contre une troisième.$t$),
  (90, 15, null, $t$Défense spectrale$t$, $t$Spectral Defense$t$, $t$Par une réaction lorsqu'une attaque vous touche, vous obtenez la résistance à tous ses dégâts pour ce tour.$t$),
  -- Rôdeur — Gardien des nuées (92)
  (92, 3, $t$sort_domaine$t$, $t$Magie du gardien des nuées$t$, $t$Swarmkeeper Magic$t$, $t$Vous connaissez le sort mineur Main de mage. Sorts toujours connus : niveau 3 — Lueurs féeriques ; niveau 5 — Toile d'araignée ; niveau 9 — Forme gazeuse ; niveau 13 — Œil magique ; niveau 17 — Fléau d'insectes.$t$),
  (92, 7, null, $t$Marée grouillante$t$, $t$Writhing Tide$t$, $t$Par une action bonus, votre nuée vous soulève pendant 1 minute : vitesse de vol de 3 m avec vol stationnaire. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (92, 11, null, $t$Nuée puissante$t$, $t$Mighty Swarm$t$, $t$Les dégâts de votre Nuée rassemblée passent à 1d8 ; une créature qui rate son jet de sauvegarde contre le déplacement tombe aussi à terre ; lorsque la nuée vous déplace, vous bénéficiez d'un abri partiel jusqu'au début de votre prochain tour.$t$),
  (92, 15, null, $t$Dispersion de la nuée$t$, $t$Swarming Dispersal$t$, $t$Par une réaction lorsque vous subissez des dégâts, vous obtenez la résistance à ces dégâts et vous téléportez jusqu'à 9 m dans un espace inoccupé que vous voyez. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  -- Rôdeur — Traqueur des ténèbres (93)
  (93, 3, $t$sort_domaine$t$, $t$Magie du traqueur des ténèbres$t$, $t$Gloom Stalker Magic$t$, $t$Sorts toujours connus : niveau 3 — Déguisement ; niveau 5 — Corde enchantée ; niveau 9 — Terreur ; niveau 13 — Invisibilité supérieure ; niveau 17 — Apparence trompeuse.$t$),
  (93, 3, null, $t$Vision des ombres$t$, $t$Umbral Sight$t$, $t$Vous avez une vision dans le noir de 18 m (ou +9 m si vous l'aviez déjà), et vous êtes invisible pour les créatures qui dépendent de la vision dans le noir pour vous voir dans l'obscurité.$t$),
  (93, 7, null, $t$Esprit d'acier$t$, $t$Iron Mind$t$, $t$Vous obtenez la maîtrise des jets de sauvegarde de Sagesse (ou, à défaut, d'Intelligence ou de Charisme).$t$),
  (93, 11, null, $t$Déluge du traqueur$t$, $t$Stalker's Flurry$t$, $t$Une fois à chacun de vos tours, lorsque vous ratez une attaque armée, vous pouvez porter une autre attaque armée dans le cadre de la même action.$t$),
  (93, 15, null, $t$Esquive ténébreuse$t$, $t$Shadowy Dodge$t$, $t$Par une réaction lorsqu'une créature vous attaque sans avoir l'avantage, vous lui imposez le désavantage à ce jet.$t$),
  -- Rôdeur — Tueur de monstres (94)
  (94, 3, $t$sort_domaine$t$, $t$Magie du tueur de monstres$t$, $t$Monster Slayer Magic$t$, $t$Sorts toujours connus : niveau 3 — Protection contre le mal et le bien ; niveau 5 — Zone de vérité ; niveau 9 — Cercle magique ; niveau 13 — Bannissement ; niveau 17 — Immobilisation de monstre.$t$),
  (94, 3, null, $t$Proie du tueur$t$, $t$Slayer's Prey$t$, $t$Par une action bonus, vous désignez une créature que vous voyez à 18 m ou moins : la première fois à chacun de vos tours que vous la touchez avec une arme, elle subit 1d6 dégâts supplémentaires. L'effet dure jusqu'à votre prochain repos ou jusqu'à ce que vous désigniez une autre cible.$t$),
  (94, 7, null, $t$Défense surnaturelle$t$, $t$Supernatural Defense$t$, $t$Lorsque la cible de votre Proie du tueur vous impose un jet de sauvegarde ou un test pour échapper à son empoignade, vous ajoutez 1d6 au résultat.$t$),
  (94, 11, null, $t$Némésis des lanceurs de sorts$t$, $t$Magic-User's Nemesis$t$, $t$Par une réaction, lorsqu'une créature que vous voyez lance un sort ou se téléporte, vous pouvez l'obliger à réussir un jet de sauvegarde de Sagesse ; en cas d'échec, le sort ou la téléportation échoue et est perdu. Une fois par repos court ou long.$t$),
  (94, 15, null, $t$Riposte du tueur$t$, $t$Slayer's Counter$t$, $t$Lorsque la cible de votre Proie du tueur vous impose un jet de sauvegarde, vous pouvez utiliser votre réaction pour l'attaquer ; si vous touchez, vous réussissez automatiquement le jet de sauvegarde en plus des effets normaux de l'attaque.$t$),
  -- Rôdeur — Vagabond féerique (95)
  (95, 3, $t$sort_domaine$t$, $t$Magie du vagabond féerique$t$, $t$Fey Wanderer Magic$t$, $t$Sorts toujours préparés : niveau 3 — Charme-personne ; niveau 5 — Pas brumeux ; niveau 9 — Dissipation de la magie ; niveau 13 — Porte dimensionnelle ; niveau 17 — Double illusoire.$t$),
  (95, 3, null, $t$Glamour de l'autre monde$t$, $t$Otherworldly Glamour$t$, $t$Vous ajoutez votre modificateur de Sagesse (minimum +1) à vos tests de Charisme, et obtenez la maîtrise d'une compétence parmi Représentation, Persuasion et Tromperie.$t$),
  (95, 7, null, $t$Retournement ensorcelant$t$, $t$Beguiling Twist$t$, $t$Vous avez l'avantage aux jets de sauvegarde contre les états charmé et effrayé. Lorsqu'une créature que vous voyez à 36 m ou moins réussit un tel jet, vous pouvez utiliser votre réaction pour qu'une autre créature réussisse un jet de sauvegarde de Sagesse ou soit charmée ou effrayée par vous pendant 1 minute.$t$),
  (95, 11, null, $t$Renforts féeriques$t$, $t$Fey Reinforcements$t$, $t$Vous connaissez Invocation de fée, toujours préparé, et pouvez le lancer une fois sans emplacement ni composante matérielle par repos long ; vous pouvez choisir de ne pas vous concentrer, le sort durant alors 1 minute.$t$),
  (95, 15, null, $t$Vagabond des brumes$t$, $t$Misty Wanderer$t$, $t$Vous pouvez lancer Pas brumeux sans emplacement un nombre de fois égal à votre modificateur de Sagesse par repos long, et emmener avec vous une créature consentante à 1,50 m ou moins, qui arrive à 1,50 m de vous.$t$),
  -- Roublard — Âme acérée (98)
  (98, 3, null, $t$Énergie psionique$t$, $t$Psionic Power$t$, $t$Vous disposez de dés d'énergie psionique (d6, puis d8, d10 et d12 aux niveaux 5, 11 et 17 ; nombre égal au double de votre bonus de maîtrise). Talent psi-renforcé : sur un test de compétence ou d'outil raté, ajoutez un dé (perdu seulement si le test réussit). Murmures psychiques : par une action, vous établissez une télépathie avec un nombre de créatures égal à votre bonus de maîtrise pour un nombre d'heures égal au résultat d'un dé.$t$),
  (98, 9, null, $t$Lames de l'âme$t$, $t$Soul Blades$t$, $t$Frappes guidées : si vous ratez avec vos Lames psychiques, vous pouvez ajouter un dé d'énergie psionique au jet. Téléportation psychique : par une action bonus, vous lancez une lame et dépensez un dé pour vous téléporter d'une distance égale à 3 m × le résultat.$t$),
  (98, 13, null, $t$Voile psychique$t$, $t$Psychic Veil$t$, $t$Par une action, vous devenez invisible pendant 1 heure, jusqu'à ce que vous infligiez des dégâts ou forciez un jet de sauvegarde. Une fois par repos long, ou en dépensant un dé d'énergie psionique.$t$),
  (98, 17, null, $t$Déchirer l'esprit$t$, $t$Rend Mind$t$, $t$Lorsque vos Lames psychiques infligent une Attaque sournoise, la cible doit réussir un jet de sauvegarde de Sagesse (DD 8 + bonus de maîtrise + modificateur de Dextérité) ou être étourdie pendant 1 minute (nouveau jet à la fin de chacun de ses tours). Une fois par repos long, ou en dépensant trois dés d'énergie psionique.$t$),
  -- Roublard — Bretteur (99)
  (99, 9, null, $t$Panache$t$, $t$Panache$t$, $t$Par une action, un test de Charisme (Persuasion) opposé à un test de Sagesse (Intuition) : une créature hostile est provoquée (désavantage aux attaques contre d'autres que vous) pendant 1 minute ; une créature non hostile est charmée pendant 1 minute.$t$),
  (99, 13, null, $t$Manœuvre élégante$t$, $t$Elegant Maneuver$t$, $t$Par une action bonus, vous obtenez l'avantage à votre prochain test de Dextérité (Acrobaties) ou de Force (Athlétisme) ce tour-ci.$t$),
  (99, 17, null, $t$Maître duelliste$t$, $t$Master Duelist$t$, $t$Lorsque vous ratez un jet d'attaque, vous pouvez le relancer avec l'avantage. Une fois par repos court ou long.$t$),
  -- Roublard — Éclaireur (101)
  (101, 3, null, $t$Survivaliste$t$, $t$Survivalist$t$, $t$Vous maîtrisez la Nature et la Survie, et doublez votre bonus de maîtrise pour les tests qui les utilisent.$t$),
  (101, 9, null, $t$Mobilité supérieure$t$, $t$Superior Mobility$t$, $t$Votre vitesse au sol augmente de 3 m, ainsi que vos vitesses d'escalade et de nage si vous en avez.$t$),
  (101, 13, null, $t$Maître de l'embuscade$t$, $t$Ambush Master$t$, $t$Vous avez l'avantage aux jets d'initiative. La première créature que vous touchez au premier round d'un combat devient plus facile à atteindre : les attaques contre elle ont l'avantage jusqu'au début de votre prochain tour.$t$),
  (101, 17, null, $t$Frappe soudaine$t$, $t$Sudden Strike$t$, $t$Lorsque vous effectuez l'action Attaque, vous pouvez porter une attaque supplémentaire par une action bonus ; elle peut bénéficier de l'Attaque sournoise même si vous l'avez déjà utilisée ce tour, mais pas contre la même cible.$t$),
  -- Roublard — Enquêteur (102)
  (102, 3, null, $t$Oreille pour le mensonge$t$, $t$Ear for Deceit$t$, $t$Lorsque vous faites un test de Sagesse (Intuition) pour déceler un mensonge, tout résultat de 7 ou moins au d20 compte comme un 8.$t$),
  (102, 3, null, $t$Combat perspicace$t$, $t$Insightful Fighting$t$, $t$Par une action bonus, un test de Sagesse (Intuition) opposé au test de Charisme (Tromperie) d'une créature : en cas de réussite, vous pouvez lui infliger votre Attaque sournoise sans avantage (si aucune autre créature n'est avantagée contre vous) pendant 1 minute.$t$),
  (102, 9, null, $t$Regard assuré$t$, $t$Steady Eye$t$, $t$Si vous ne vous déplacez pas de plus de la moitié de votre vitesse pendant votre tour, vous avez l'avantage aux tests de Sagesse (Perception) et d'Intelligence (Investigation).$t$),
  (102, 13, null, $t$Œil infaillible$t$, $t$Unerring Eye$t$, $t$Par une action, vous détectez les illusions, métamorphes et effets de tromperie magique à 9 m ou moins (sans connaître leur nature). Utilisations égales à votre modificateur de Sagesse, récupérées après un repos long.$t$),
  (102, 17, null, $t$Œil pour la faiblesse$t$, $t$Eye for Weakness$t$, $t$Tant que votre Combat perspicace s'applique à une créature, votre Attaque sournoise contre elle inflige 3d6 dégâts supplémentaires.$t$),
  -- Roublard — Fantôme (103)
  (103, 3, null, $t$Lamentations d'outre-tombe$t$, $t$Wails from the Grave$t$, $t$Immédiatement après une Attaque sournoise, vous pouvez viser une autre créature à 9 m ou moins de la première : elle subit des dégâts nécrotiques égaux à la moitié de vos dés d'Attaque sournoise. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (103, 9, null, $t$Souvenirs des défunts$t$, $t$Tokens of the Departed$t$, $t$Par une réaction lorsqu'une créature meurt à 9 m ou moins, vous créez un souvenir d'âme (maximum égal à votre bonus de maîtrise). Tant que vous en portez un : avantage aux jets de sauvegarde de Constitution et contre la mort ; utiliser Lamentations d'outre-tombe en en détruisant un ne dépense pas d'utilisation ; et vous pouvez en détruire un pour poser une question à l'esprit du défunt.$t$),
  (103, 13, null, $t$Marche fantomatique$t$, $t$Ghost Walk$t$, $t$Par une action bonus, pendant 10 minutes, vous prenez une forme spectrale : vol de 3 m avec vol stationnaire, désavantage aux attaques contre vous, et vous traversez créatures et objets comme un terrain difficile. Une fois par repos long, ou en détruisant un souvenir d'âme.$t$),
  (103, 17, null, $t$Ami de la mort$t$, $t$Death's Friend$t$, $t$Lamentations d'outre-tombe inflige ses dégâts nécrotiques à la fois à la première et à la seconde créature. Si vous n'avez aucun souvenir d'âme à la fin d'un repos long, vous en obtenez un.$t$)
    ) as t(subclass_id, level, choice_type, name_fr, name_en, description)
  loop
    if exists (select 1 from public.subclasses s where s.id = rec.subclass_id)
       and not exists (
         select 1 from public.class_features f
           join public.translations tr
             on tr.entity_type = 'class_feature' and tr.entity_id = f.id::text
            and tr.field_name = 'name' and tr.locale = 'fr'
          where f.subclass_id = rec.subclass_id and lower(tr.value) = lower(rec.name_fr)
       ) then
      insert into public.class_features (class_id, subclass_id, level, choice_type)
        values (null, rec.subclass_id, rec.level, rec.choice_type)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('class_feature', v_id::text, 'name', 'fr', rec.name_fr),
        ('class_feature', v_id::text, 'name', 'en', rec.name_en),
        ('class_feature', v_id::text, 'description', 'fr', rec.description);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'aptitudes insérées : %', v_inserted;
end $$;

-- Contrôle final : plus aucune sous-classe ne doit compter une seule aptitude.
do $$
declare
  v_left int;
begin
  select count(*) into v_left
    from public.subclasses s
   where (select count(*) from public.class_features f where f.subclass_id = s.id) <= 1;
  if v_left > 0 then
    raise exception 'Contrôle lot 5b : % sous-classes ont encore une seule aptitude au plus', v_left;
  end if;
end $$;
