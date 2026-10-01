-- Lot 5a de l'import du contenu de référence : aptitudes manquantes des sous-classes qui n'en
-- comptaient qu'une (Barbare, Barde, Druide, Ensorceleur, Guerrier, Magicien).
-- Texte français reformulé d'après les livres d'origine (Xanathar, Tasha, SCAG, Theros, Bigby,
-- Fizban, Wildemount). Idempotente : une aptitude n'est insérée que si la sous-classe n'a pas
-- déjà une aptitude du même nom FR.

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
  -- Barbare — Voie de la bête (14)
  (14, 6, null::text, $t$Âme bestiale$t$, $t$Bestial Soul$t$, $t$Vos armes naturelles comptent comme magiques. À la fin de chaque repos, choisissez un bénéfice : vitesse de nage égale à votre vitesse et respiration aquatique ; vitesse d'escalade égale à votre vitesse et escalade des surfaces difficiles (y compris au plafond) sans test ; ou, une fois par tour lorsque vous sautez, allongement du saut d'un nombre de pieds égal au total d'un test de Force (Athlétisme).$t$),
  (14, 10, null, $t$Fureur contagieuse$t$, $t$Infectious Fury$t$, $t$En rage, lorsque vous touchez une créature avec vos armes naturelles, vous pouvez lui imposer un jet de sauvegarde de Sagesse (DD 8 + modificateur de Constitution + bonus de maîtrise). En cas d'échec, au choix : elle utilise sa réaction pour attaquer une autre créature de votre choix, ou elle subit 2d12 dégâts psychiques. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (14, 14, null, $t$Appel de la chasse$t$, $t$Call the Hunt$t$, $t$En entrant en rage, choisissez jusqu'à votre modificateur de Constitution créatures consentantes à 9 m ou moins : vous gagnez 5 points de vie temporaires par créature choisie, et chacune peut, une fois par tour, infliger 1d6 dégâts supplémentaires lors d'une attaque réussie, pendant toute votre rage. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  -- Barbare — Gardien ancestral (15)
  (15, 6, null, $t$Bouclier spirituel$t$, $t$Spirit Shield$t$, $t$En rage, lorsqu'une créature que vous voyez à 9 m ou moins subit des dégâts, vous pouvez utiliser votre réaction pour réduire ces dégâts de 2d6 (3d6 au niveau 10, 4d6 au niveau 14).$t$),
  (15, 10, null, $t$Consulter les esprits$t$, $t$Consult the Spirits$t$, $t$Vous pouvez lancer Augure ou Clairvoyance sans emplacement ni composante matérielle, la Sagesse étant votre caractéristique d'incantation. Une fois par repos court ou long.$t$),
  (15, 14, null, $t$Ancêtres vengeurs$t$, $t$Vengeful Ancestors$t$, $t$Lorsque votre Bouclier spirituel réduit des dégâts, l'attaquant subit des dégâts de force égaux aux dégâts évités.$t$),
  -- Barbare — Voie du géant (16)
  (16, 3, null, $t$Puissance du géant$t$, $t$Giant's Power$t$, $t$Vous apprenez le sort mineur Druidisme ou Thaumaturgie (Sagesse comme caractéristique d'incantation) ainsi que la langue des géants.$t$),
  (16, 6, null, $t$Tranchant élémentaire$t$, $t$Elemental Cleaver$t$, $t$En entrant en rage (ou par une action bonus pendant la rage), vous imprégnez une arme d'acide, de feu, de foudre, de froid ou de tonnerre : elle inflige 1d6 dégâts supplémentaires de ce type, gagne la propriété lancer (portée 6/18 m) et revient dans votre main après un lancer.$t$),
  (16, 10, null, $t$Propulsion puissante$t$, $t$Mighty Impel$t$, $t$En rage, par une action bonus, vous soulevez une créature de taille M ou inférieure à votre allonge et la projetez dans un espace inoccupé à 9 m ou moins. Une créature non consentante peut résister par un jet de sauvegarde de Force (DD 8 + bonus de maîtrise + modificateur de Force).$t$),
  (16, 14, null, $t$Colosse démiurgique$t$, $t$Demiurgic Colossus$t$, $t$En rage, votre allonge augmente de 3 m, vous pouvez devenir de taille G ou TG, et les dégâts supplémentaires de Tranchant élémentaire passent à 2d6.$t$),
  -- Barbare — Héraut des tempêtes (17)
  (17, 6, null, $t$Âme de la tempête$t$, $t$Storm Soul$t$, $t$Selon l'environnement de votre aura : Désert (résistance au feu, insensibilité à la chaleur extrême, et vous pouvez enflammer un objet inflammable non porté par une action) ; Mer (résistance à la foudre, respiration aquatique, vitesse de nage de 9 m) ; Toundra (résistance au froid, insensibilité au froid extrême, et vous pouvez geler de l'eau par une action).$t$),
  (17, 10, null, $t$Tempête protectrice$t$, $t$Shielding Storm$t$, $t$Chaque créature de votre choix dans votre aura bénéficie de la résistance accordée par votre Âme de la tempête.$t$),
  (17, 14, null, $t$Tempête déchaînée$t$, $t$Raging Storm$t$, $t$Votre aura gagne un effet supplémentaire (DD 8 + bonus de maîtrise + modificateur de Constitution). Désert : en réaction quand une créature de l'aura vous touche, elle subit des dégâts de feu égaux à la moitié de votre niveau de barbare. Mer : en réaction quand vous touchez une créature de l'aura, elle doit réussir un jet de sauvegarde de Force ou tomber à terre. Toundra : quand l'aura s'active, une créature de l'aura doit réussir un jet de sauvegarde de Force ou voir sa vitesse tomber à 0 jusqu'au début de votre prochain tour.$t$),
  -- Barbare — Zélote (19)
  (19, 3, null, $t$Guerrier des dieux$t$, $t$Warrior of the Gods$t$, $t$Les sorts destinés à vous ramener à la vie (sauf Souhait) ne nécessitent aucune composante matérielle lorsqu'ils vous ciblent.$t$),
  (19, 6, null, $t$Concentration fanatique$t$, $t$Fanatical Focus$t$, $t$Une fois par rage, si vous ratez un jet de sauvegarde, vous pouvez le relancer et devez garder le nouveau résultat.$t$),
  (19, 10, null, $t$Présence zélée$t$, $t$Zealous Presence$t$, $t$Par une action bonus, jusqu'à dix créatures de votre choix à 18 m ou moins ont l'avantage aux jets d'attaque et de sauvegarde jusqu'au début de votre prochain tour. Une fois par repos long.$t$),
  (19, 14, null, $t$Rage au-delà de la mort$t$, $t$Rage Beyond Death$t$, $t$En rage, tomber à 0 point de vie ne vous rend pas inconscient. Vous faites toujours des jets de sauvegarde contre la mort, mais ne mourez qu'à la fin de votre rage si vous êtes encore à 0 point de vie.$t$),
  -- Barde — Collège de l'éloquence (21)
  (21, 3, null, $t$Paroles troublantes$t$, $t$Unsettling Words$t$, $t$Par une action bonus, vous dépensez une utilisation d'Inspiration bardique et lancez le dé : une créature que vous voyez à 18 m ou moins soustrait le résultat de son prochain jet de sauvegarde avant le début de votre prochain tour.$t$),
  (21, 6, null, $t$Inspiration infaillible$t$, $t$Unfailing Inspiration$t$, $t$Lorsqu'une créature ajoute votre dé d'Inspiration bardique à un jet et échoue, elle conserve le dé.$t$),
  (21, 6, null, $t$Discours universel$t$, $t$Universal Speech$t$, $t$Par une action, jusqu'à votre modificateur de Charisme créatures à 18 m ou moins peuvent comprendre vos paroles pendant 1 heure, quelle que soit la langue. Une fois par repos long, ou en dépensant un emplacement de sort.$t$),
  (21, 14, null, $t$Inspiration contagieuse$t$, $t$Infectious Inspiration$t$, $t$Lorsqu'une créature réussit un jet grâce à votre dé d'Inspiration bardique, vous pouvez utiliser votre réaction pour accorder un dé d'Inspiration à une autre créature à 18 m ou moins sans dépenser d'utilisation. Utilisations égales à votre modificateur de Charisme, récupérées après un repos long.$t$),
  -- Barde — Collège de la création (22)
  (22, 3, null, $t$Parcelle de potentiel$t$, $t$Mote of Potential$t$, $t$Quand vous donnez une Inspiration bardique, une parcelle de potentiel l'accompagne. Sur un test de caractéristique, la créature lance le dé deux fois et garde le résultat de son choix ; sur un jet d'attaque, la cible et les créatures à 1,50 m d'elle doivent réussir un jet de sauvegarde de Constitution ou subir des dégâts de tonnerre égaux au résultat du dé ; sur un jet de sauvegarde, la créature gagne des points de vie temporaires égaux au résultat + votre modificateur de Charisme.$t$),
  (22, 6, null, $t$Performance animatrice$t$, $t$Animating Performance$t$, $t$Par une action, vous animez un objet non magique de taille G ou inférieure pendant 1 heure (bloc de statistiques « objet dansant ») ; il agit à votre initiative et obéit à vos ordres donnés par une action bonus. Une fois par repos long, ou en dépensant un emplacement de niveau 3 ou supérieur.$t$),
  (22, 14, null, $t$Crescendo créatif$t$, $t$Creative Crescendo$t$, $t$Avec Performance de la création, vous pouvez créer un nombre d'objets égal à votre modificateur de Charisme (un seul de la taille maximale, les autres de taille P ou inférieure), sans limite de valeur en pièces d'or.$t$),
  -- Barde — Collège de la séduction (23)
  (23, 3, null, $t$Performance envoûtante$t$, $t$Enthralling Performance$t$, $t$Après avoir joué au moins 1 minute, jusqu'à votre modificateur de Charisme humanoïdes qui vous ont écouté à 18 m ou moins doivent réussir un jet de sauvegarde de Sagesse ou être charmés pendant 1 heure : ils vous idolâtrent et vous défendent. Une fois par repos court ou long.$t$),
  (23, 6, null, $t$Manteau de majesté$t$, $t$Mantle of Majesty$t$, $t$Par une action bonus, vous lancez Injonction sans emplacement, puis pouvez le relancer par une action bonus à chacun de vos tours pendant 1 minute (concentration). Les créatures que vous avez charmées échouent automatiquement. Une fois par repos long.$t$),
  (23, 14, null, $t$Majesté inébranlable$t$, $t$Unbreakable Majesty$t$, $t$Par une action bonus, pendant 1 minute, une créature qui vous attaque pour la première fois à son tour doit réussir un jet de sauvegarde de Charisme ou choisir une autre cible (sinon l'attaque est perdue) ; en cas de réussite, elle a le désavantage à ses jets de sauvegarde contre vos sorts à votre prochain tour. Une fois par repos court ou long.$t$),
  -- Barde — Collège des épées (24)
  (24, 3, null, $t$Maîtrises supplémentaires$t$, $t$Bonus Proficiencies$t$, $t$Vous maîtrisez les armures intermédiaires et le cimeterre, et pouvez utiliser une arme de corps à corps que vous maîtrisez comme focaliseur d'incantation.$t$),
  (24, 3, null, $t$Style de combat$t$, $t$Fighting Style$t$, $t$Vous adoptez le style Duel ou Combat à deux armes.$t$),
  (24, 6, null, $t$Attaque supplémentaire$t$, $t$Extra Attack$t$, $t$Vous pouvez attaquer deux fois au lieu d'une lorsque vous effectuez l'action Attaque pendant votre tour.$t$),
  (24, 14, null, $t$Fioriture de maître$t$, $t$Master's Flourish$t$, $t$Lorsque vous utilisez une Fioriture de lame, vous pouvez lancer un d6 et l'utiliser au lieu de dépenser un dé d'Inspiration bardique.$t$),
  -- Barde — Collège des esprits (25)
  (25, 3, null, $t$Murmures guides$t$, $t$Guiding Whispers$t$, $t$Vous apprenez le sort mineur Assistance, dont la portée passe à 18 m.$t$),
  (25, 3, null, $t$Focaliseur spirituel$t$, $t$Spiritual Focus$t$, $t$Vous pouvez utiliser une bougie, une boule de cristal, un crâne, une planche spirite ou un jeu de tarokka comme focaliseur. À partir du niveau 6, lorsque vous lancez un sort de barde qui inflige des dégâts ou rend des points de vie par ce focaliseur, vous ajoutez 1d6 à un des jets.$t$),
  (25, 6, null, $t$Séance spirite$t$, $t$Spirit Session$t$, $t$Par un rituel d'une heure avec jusqu'à votre bonus de maîtrise créatures consentantes, vous apprenez temporairement un sort de divination ou de nécromancie de n'importe quelle liste, d'un niveau au plus égal au nombre de participants (et que vous pouvez lancer), jusqu'à votre prochain repos long. Une fois par repos long.$t$),
  (25, 14, null, $t$Connexion mystique$t$, $t$Mystical Connection$t$, $t$Lorsque vous lancez le dé de Contes d'outre-tombe, vous pouvez le lancer deux fois et choisir le résultat.$t$),
  -- Barde — Collège des murmures (26)
  (26, 3, null, $t$Mots de terreur$t$, $t$Words of Terror$t$, $t$Après avoir parlé seul à seul pendant au moins 1 minute avec un humanoïde, vous pouvez l'obliger à réussir un jet de sauvegarde de Sagesse ou être effrayé par vous ou par une créature de votre choix pendant 1 heure. Une fois par repos court ou long.$t$),
  (26, 6, null, $t$Manteau de murmures$t$, $t$Mantle of Whispers$t$, $t$Par une réaction lorsqu'un humanoïde meurt à 9 m ou moins, vous capturez son ombre. Par une action, vous pouvez ensuite prendre son apparence pendant 1 heure et accéder à des informations générales sur sa vie ; une créature méfiante peut déceler la supercherie par un test de Sagesse (Intuition) contre votre test de Charisme (Tromperie) +5. Une fois par repos court ou long.$t$),
  (26, 14, null, $t$Savoir des ombres$t$, $t$Shadow Lore$t$, $t$Par une action, une créature que vous voyez à 9 m ou moins et qui vous comprend doit réussir un jet de sauvegarde de Sagesse ou être charmée pendant 8 heures : elle croit que vous connaissez son secret le plus sombre et suit vos ordres (sans se mettre en danger). Une fois par repos long.$t$),
  -- Druide — Cercle des astres (37)
  (37, 2, null, $t$Carte stellaire$t$, $t$Star Map$t$, $t$Vous créez une carte des étoiles qui vous sert de focaliseur. Vous connaissez le sort mineur Assistance et avez Rayon traçant toujours préparé ; vous pouvez le lancer sans emplacement un nombre de fois égal à votre bonus de maîtrise par repos long.$t$),
  (37, 6, null, $t$Présage cosmique$t$, $t$Cosmic Omen$t$, $t$Après un repos long, lancez un dé. Pair (Faste) : par une réaction, vous ajoutez 1d6 au jet d'attaque, de sauvegarde ou au test d'une créature que vous voyez à 9 m ou moins. Impair (Néfaste) : vous soustrayez 1d6 à ce jet. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (37, 10, null, $t$Constellations scintillantes$t$, $t$Twinkling Constellations$t$, $t$Les dés de l'Archer et du Calice de votre Forme astrale passent à 2d8 ; le Dragon vous confère une vitesse de vol de 6 m avec vol stationnaire. Au début de chacun de vos tours en Forme astrale, vous pouvez changer de constellation.$t$),
  (37, 14, null, $t$Plein d'étoiles$t$, $t$Full of Stars$t$, $t$En Forme astrale, vous êtes en partie incorporel et avez la résistance aux dégâts contondants, perforants et tranchants.$t$),
  -- Druide — Cercle du berger (38)
  (38, 2, null, $t$Langage des bois$t$, $t$Speech of the Woods$t$, $t$Vous apprenez le sylvestre, et Communication avec les animaux est toujours préparé (sans compter dans vos sorts préparés).$t$),
  (38, 6, null, $t$Invocateur puissant$t$, $t$Mighty Summoner$t$, $t$Les bêtes et fées que vous appelez ou créez par un sort obtiennent 2 points de vie supplémentaires par dé de vie, et leurs armes naturelles comptent comme magiques.$t$),
  (38, 10, null, $t$Esprit gardien$t$, $t$Guardian Spirit$t$, $t$Une bête ou une fée invoquée par vos sorts qui termine son tour dans l'aura de votre Totem spirituel récupère des points de vie égaux à la moitié de votre niveau de druide.$t$),
  (38, 14, null, $t$Invocations fidèles$t$, $t$Faithful Summons$t$, $t$Si vous tombez à 0 point de vie ou êtes neutralisé contre votre gré, vous obtenez l'effet de Invocation d'animaux lancé au niveau 9 : quatre bêtes de FP 2 ou moins apparaissent et vous protègent pendant 1 heure, sans concentration. Une fois par repos long.$t$),
  -- Druide — Cercle des fournaises (39)
  (39, 2, $t$sort_domaine$t$, $t$Sorts du cercle des fournaises$t$, $t$Circle Spells$t$, $t$Toujours préparés : niveau 2 — Mains brûlantes, Soins ; niveau 3 — Sphère de feu, Rayon ardent ; niveau 5 — Croissance végétale, Retour à la vie ; niveau 7 — Aura de vie, Bouclier de feu ; niveau 9 — Colonne de flamme, Soins de groupe.$t$),
  (39, 6, null, $t$Lien renforcé$t$, $t$Enhanced Bond$t$, $t$Tant que votre esprit de la fournaise est invoqué, vos sorts qui infligent des dégâts de feu ou rendent des points de vie ajoutent 1d8 à un des jets, et vous pouvez lancer un sort à portée autre que personnelle comme s'il partait de l'esprit.$t$),
  (39, 10, null, $t$Flammes cautérisantes$t$, $t$Cauterizing Flames$t$, $t$Quand une créature de taille P ou supérieure meurt à 9 m ou moins de vous ou de votre esprit, une flamme spectrale apparaît dans son espace pendant 1 minute. Quand une créature y entre, vous pouvez utiliser votre réaction pour éteindre la flamme et soit lui rendre, soit lui infliger (dégâts de feu) 2d10 + votre modificateur de Sagesse. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (39, 14, null, $t$Renaissance ardente$t$, $t$Blazing Revival$t$, $t$Si vous tombez à 0 point de vie alors que votre esprit se trouve à 36 m ou moins, il tombe à 0 point de vie et vous récupérez la moitié de votre maximum de points de vie en vous relevant. Une fois par repos long.$t$),
  -- Druide — Cercle des rêves (40)
  (40, 6, null, $t$Foyer de lune et d'ombre$t$, $t$Hearth of Moonlight and Shadow$t$, $t$Pendant un repos court ou long, vous créez une sphère de 9 m de rayon : vous et vos alliés à l'intérieur gagnez +5 aux tests de Dextérité (Discrétion) et de Sagesse (Perception), et la lumière des feux y est invisible de l'extérieur.$t$),
  (40, 10, null, $t$Chemins cachés$t$, $t$Hidden Paths$t$, $t$Par une action bonus, vous vous téléportez jusqu'à 18 m dans un espace inoccupé que vous voyez ; ou, par une action, vous téléportez une créature consentante que vous touchez jusqu'à 9 m. Utilisations égales à votre modificateur de Sagesse, récupérées après un repos long.$t$),
  (40, 14, null, $t$Marcheur des rêves$t$, $t$Walker in Dreams$t$, $t$Au terme d'un repos court, vous pouvez lancer Songe (vous étant le messager), Scrutation ou Cercle de téléportation (vers le dernier lieu où vous avez fini un repos long), sans emplacement ni composante matérielle. Une fois par repos long.$t$),
  -- Druide — Cercle des spores (41)
  (41, 2, $t$sort_domaine$t$, $t$Sorts du cercle des spores$t$, $t$Circle Spells$t$, $t$Vous connaissez le sort mineur Contact glacial. Toujours préparés : niveau 3 — Cécité/Surdité, Préservation des morts ; niveau 5 — Animation des morts, Forme gazeuse ; niveau 7 — Flétrissement, Confusion ; niveau 9 — Brume mortelle, Contagion.$t$),
  (41, 2, null, $t$Halo de spores$t$, $t$Halo of Spores$t$, $t$Par une réaction, lorsqu'une créature que vous voyez entre ou commence son tour à 3 m ou moins de vous, elle doit réussir un jet de sauvegarde de Constitution ou subir 1d4 dégâts nécrotiques (1d6 au niveau 6, 1d8 au niveau 10, 1d10 au niveau 14).$t$),
  (41, 6, null, $t$Infestation fongique$t$, $t$Fungal Infestation$t$, $t$Par une réaction lorsqu'une bête ou un humanoïde de taille P ou M meurt à 3 m ou moins, vous l'animez en zombi avec 1 point de vie pendant 1 heure ; il obéit à vos ordres mentaux. Utilisations égales à votre modificateur de Sagesse, récupérées après un repos long.$t$),
  (41, 10, null, $t$Propagation des spores$t$, $t$Spreading Spores$t$, $t$Tant que votre Entité symbiotique est active, par une action bonus, vous projetez vos spores dans un cube de 3 m à 9 m ou moins pendant 1 minute : les dégâts du Halo de spores s'appliquent aux créatures qui y entrent ou y commencent leur tour (et plus autour de vous).$t$),
  (41, 14, null, $t$Corps fongique$t$, $t$Fungal Body$t$, $t$Vous ne pouvez pas être aveuglé, assourdi, effrayé ni empoisonné, et les coups critiques contre vous deviennent des coups normaux, sauf si vous êtes neutralisé.$t$),
  -- Ensorceleur — Âme divine (43)
  (43, 1, null, $t$Magie divine$t$, $t$Divine Magic$t$, $t$Vous pouvez choisir vos sorts d'ensorceleur dans la liste du clerc. Selon votre affinité, vous apprenez en plus : Bien — Soins ; Mal — Blessure ; Loi — Bénédiction ; Chaos — Fléau ; Neutralité — Protection contre le mal et le bien.$t$),
  (43, 6, null, $t$Guérison renforcée$t$, $t$Empowered Healing$t$, $t$Lorsque vous ou un allié à 1,50 m ou moins lancez les dés de soins d'un sort, vous pouvez dépenser 1 point de sorcellerie pour relancer autant de ces dés que vous voulez, une fois.$t$),
  (43, 14, null, $t$Forme angélique$t$, $t$Otherworldly Wings$t$, $t$Par une action bonus, des ailes spectrales apparaissent dans votre dos : vitesse de vol de 9 m, jusqu'à ce que vous les congédiiez par une action bonus.$t$),
  (43, 18, null, $t$Rétablissement surnaturel$t$, $t$Unearthly Recovery$t$, $t$Par une action bonus, lorsque vous avez moins de la moitié de vos points de vie, vous récupérez la moitié de votre maximum de points de vie. Une fois par repos long.$t$),
  -- Ensorceleur — Âme mécanique (44)
  (44, 1, $t$sort_domaine$t$, $t$Magie mécanique$t$, $t$Clockwork Magic$t$, $t$Sorts toujours connus : niveau 1 — Alarme, Protection contre le mal et le bien ; niveau 3 — Aide, Restauration partielle ; niveau 5 — Dissipation de la magie, Protection contre l'énergie ; niveau 7 — Liberté de mouvement, Invocation d'artificiel ; niveau 9 — Restauration supérieure, Mur de force. Chacun peut être remplacé par un sort d'abjuration ou de transmutation de la liste d'ensorceleur, d'occultiste ou de magicien.$t$),
  (44, 6, null, $t$Bastion de la loi$t$, $t$Bastion of Law$t$, $t$Par une action, vous dépensez de 1 à 5 points de sorcellerie pour protéger une créature à 9 m ou moins : elle reçoit autant de d8. Lorsqu'elle subit des dégâts, elle peut dépenser des dés et réduire les dégâts du total obtenu. La protection dure jusqu'à votre prochain repos long.$t$),
  (44, 14, null, $t$Transe de l'ordre$t$, $t$Trance of Order$t$, $t$Par une action bonus, pendant 1 minute, les attaques contre vous n'ont jamais l'avantage, et tout résultat de 9 ou moins au d20 de vos jets d'attaque, tests et jets de sauvegarde compte comme un 10. Une fois par repos long, ou pour 5 points de sorcellerie.$t$),
  (44, 18, null, $t$Cavalcade mécanique$t$, $t$Clockwork Cavalcade$t$, $t$Par une action, dans un cube de 9 m : vous répartissez jusqu'à 100 points de vie entre les créatures de votre choix, réparez les objets endommagés et mettez fin aux sorts de niveau 6 ou inférieur sur les créatures et objets de votre choix. Une fois par repos long, ou pour 7 points de sorcellerie.$t$),
  -- Ensorceleur — Esprit aberrant (45)
  (45, 1, $t$sort_domaine$t$, $t$Sorts psioniques$t$, $t$Psionic Spells$t$, $t$Sorts toujours connus : niveau 1 — Bras d'Hadar, Murmures dissonants, Éclat mental ; niveau 3 — Apaisement des émotions, Détection des pensées ; niveau 5 — Faim d'Hadar, Communication à distance ; niveau 7 — Tentacules noirs d'Evard, Invocation d'aberration ; niveau 9 — Lien télépathique de Rary, Télékinésie. Chacun peut être remplacé par un sort de divination ou d'enchantement de la liste d'ensorceleur, d'occultiste ou de magicien.$t$),
  (45, 6, null, $t$Sorcellerie psionique$t$, $t$Psionic Sorcery$t$, $t$Vous pouvez lancer un de vos Sorts psioniques en dépensant autant de points de sorcellerie que son niveau, sans composantes verbales ni somatiques, ni matérielles non consommées.$t$),
  (45, 6, null, $t$Défenses psychiques$t$, $t$Psychic Defenses$t$, $t$Vous avez la résistance aux dégâts psychiques et l'avantage aux jets de sauvegarde contre les états charmé et effrayé.$t$),
  (45, 14, null, $t$Révélation dans la chair$t$, $t$Revelation in Flesh$t$, $t$Par une action bonus, vous dépensez des points de sorcellerie (1 par bénéfice) pour 10 minutes : voir les créatures invisibles à 18 m ; vitesse de vol égale à votre vitesse avec vol stationnaire ; vitesse de nage doublée et respiration aquatique ; ou passage par un interstice de 2,5 cm et évasion d'une empoignade pour 1,50 m de déplacement.$t$),
  (45, 18, null, $t$Implosion déformante$t$, $t$Warping Implosion$t$, $t$Par une action, vous vous téléportez jusqu'à 36 m ; chaque créature à 9 m ou moins de l'espace quitté doit réussir un jet de sauvegarde de Force ou subir 3d10 dégâts de force et être attirée vers cet espace (moitié des dégâts en cas de réussite). Une fois par repos long, ou pour 5 points de sorcellerie.$t$),
  -- Ensorceleur — Magie des ombres (46)
  (46, 1, null, $t$Force de la tombe$t$, $t$Strength of the Grave$t$, $t$Lorsque des dégâts vous font tomber à 0 point de vie (hors dégâts radiants et coups critiques), vous pouvez faire un jet de sauvegarde de Charisme (DD 5 + dégâts subis) : en cas de réussite, vous tombez à 1 point de vie à la place. Une fois par repos long.$t$),
  (46, 6, null, $t$Molosse de mauvais augure$t$, $t$Hound of Ill Omen$t$, $t$Par une action bonus et pour 3 points de sorcellerie, vous invoquez un molosse d'ombre (loup sanguinaire) qui traque une créature que vous voyez à 36 m ou moins. Tant que le molosse est à 1,50 m d'elle, la cible a le désavantage aux jets de sauvegarde contre vos sorts.$t$),
  (46, 14, null, $t$Marche des ombres$t$, $t$Shadow Walk$t$, $t$Lorsque vous êtes dans une zone de lumière faible ou d'obscurité, par une action bonus, vous vous téléportez jusqu'à 36 m dans un autre espace de lumière faible ou d'obscurité que vous voyez.$t$),
  (46, 18, null, $t$Forme obscure$t$, $t$Umbral Form$t$, $t$Par une action bonus et pour 6 points de sorcellerie, pendant 1 minute, vous avez la résistance à tous les dégâts sauf de force et radiants, et pouvez traverser créatures et objets comme un terrain difficile (1d10 dégâts de force si vous finissez votre tour dans un objet).$t$),
  -- Ensorceleur — Sorcellerie des tempêtes (47)
  (47, 1, null, $t$Voix du vent$t$, $t$Wind Speaker$t$, $t$Vous parlez, lisez et écrivez le primordial (et ses dialectes aérien, aquatique, igné et terreux).$t$),
  (47, 6, null, $t$Cœur de la tempête$t$, $t$Heart of the Storm$t$, $t$Vous avez la résistance aux dégâts de foudre et de tonnerre. Lorsque vous lancez un sort de niveau 1 ou supérieur infligeant de tels dégâts, les créatures de votre choix à 3 m ou moins subissent des dégâts de foudre ou de tonnerre égaux à la moitié de votre niveau d'ensorceleur.$t$),
  (47, 6, null, $t$Guide des tempêtes$t$, $t$Storm Guide$t$, $t$Par une action, vous faites cesser la pluie dans une sphère de 6 m autour de vous ; par une action bonus, vous choisissez la direction du vent dans un rayon de 30 m, jusqu'à la fin de votre prochain tour.$t$),
  (47, 14, null, $t$Furie de la tempête$t$, $t$Storm's Fury$t$, $t$Par une réaction lorsqu'une attaque au corps à corps vous touche, l'attaquant subit des dégâts de foudre égaux à votre niveau d'ensorceleur et doit réussir un jet de sauvegarde de Force ou être repoussé jusqu'à 6 m.$t$),
  (47, 18, null, $t$Âme du vent$t$, $t$Wind Soul$t$, $t$Vous êtes immunisé contre les dégâts de foudre et de tonnerre et avez une vitesse de vol de 18 m. Par une action, vous pouvez réduire ce vol à 9 m pendant 1 heure pour accorder une vitesse de vol de 9 m à jusqu'à 3 + votre modificateur de Charisme créatures à 9 m ou moins. Une fois par repos court ou long.$t$),
  -- Guerrier — Archer arcanique (50)
  (50, 3, null, $t$Savoir de l'archer arcanique$t$, $t$Arcane Archer Lore$t$, $t$Vous obtenez la maîtrise des Arcanes ou de la Nature, et apprenez le sort mineur Prestidigitation ou Druidisme.$t$),
  (50, 7, null, $t$Flèche magique$t$, $t$Magic Arrow$t$, $t$Les flèches non magiques que vous tirez avec un arc court ou long deviennent magiques pour surmonter résistances et immunités.$t$),
  (50, 7, null, $t$Tir incurvé$t$, $t$Curving Shot$t$, $t$Lorsque vous ratez une attaque avec une flèche magique, vous pouvez utiliser une action bonus pour relancer le jet d'attaque contre une autre cible située à 18 m ou moins de la première.$t$),
  (50, 15, null, $t$Tir toujours prêt$t$, $t$Ever-Ready Shot$t$, $t$Si vous n'avez plus d'utilisation de Tir arcanique lorsque vous lancez l'initiative, vous en récupérez une.$t$),
  (50, 18, null, $t$Tirs arcaniques améliorés$t$, $t$Arcane Shot Options$t$, $t$Les dégâts supplémentaires et effets de vos options de Tir arcanique augmentent (les dés de dégâts sont doublés).$t$),
  -- Guerrier — Cavalier (51)
  (51, 3, null, $t$Maîtrise supplémentaire$t$, $t$Bonus Proficiency$t$, $t$Vous obtenez la maîtrise d'une compétence parmi Dressage, Histoire, Intuition, Persuasion et Représentation, ou apprenez une langue.$t$),
  (51, 3, null, $t$Né en selle$t$, $t$Born to the Saddle$t$, $t$Vous avez l'avantage aux jets de sauvegarde pour ne pas tomber de votre monture ; si vous en tombez de 3 m ou moins, vous atterrissez sur vos pieds ; monter ou descendre ne vous coûte que 1,50 m de déplacement.$t$),
  (51, 7, null, $t$Manœuvre protectrice$t$, $t$Warding Maneuver$t$, $t$Par une réaction, lorsqu'une créature à 1,50 m ou moins de vous (vous compris ou votre monture) est touchée, vous ajoutez 1d8 à sa CA ; si l'attaque touche quand même, elle a la résistance à ses dégâts. Utilisations égales à votre modificateur de Constitution, récupérées après un repos long.$t$),
  (51, 10, null, $t$Tenir la ligne$t$, $t$Hold the Line$t$, $t$Une créature provoque une attaque d'opportunité de votre part si elle se déplace de 1,50 m ou plus dans votre allonge ; si l'attaque touche, sa vitesse tombe à 0 jusqu'à la fin du tour.$t$),
  (51, 15, null, $t$Chargeur féroce$t$, $t$Ferocious Charger$t$, $t$Si vous vous déplacez d'au moins 3 m en ligne droite avant de toucher une créature, elle doit réussir un jet de sauvegarde de Force ou tomber à terre. Une fois par tour.$t$),
  (51, 18, null, $t$Défenseur vigilant$t$, $t$Vigilant Defender$t$, $t$Vous disposez d'une réaction spéciale utilisable uniquement pour une attaque d'opportunité, une fois au tour de chaque autre créature.$t$),
  -- Guerrier — Chevalier runique (52)
  (52, 3, null, $t$Maîtrises supplémentaires$t$, $t$Bonus Proficiencies$t$, $t$Vous maîtrisez les outils de forgeron et apprenez la langue des géants.$t$),
  (52, 3, null, $t$Puissance du géant$t$, $t$Giant's Might$t$, $t$Par une action bonus, pendant 1 minute, vous devenez de taille G si l'espace le permet, avez l'avantage aux tests et jets de sauvegarde de Force, et infligez 1d6 dégâts supplémentaires une fois par tour avec une arme. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (52, 7, null, $t$Bouclier runique$t$, $t$Runic Shield$t$, $t$Par une réaction, lorsqu'une créature que vous voyez à 18 m ou moins est touchée par une attaque, vous obligez l'attaquant à relancer son d20 et à garder le nouveau résultat. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (52, 10, null, $t$Grande stature$t$, $t$Great Stature$t$, $t$Vous grandissez de 3d4 pouces (environ 7 à 30 cm), et le dé de dégâts de Puissance du géant passe à 1d8.$t$),
  (52, 15, null, $t$Maître des runes$t$, $t$Master of Runes$t$, $t$Vous pouvez invoquer chacune de vos runes deux fois par repos court ou long.$t$),
  (52, 18, null, $t$Colosse runique$t$, $t$Runic Juggernaut$t$, $t$Le dé de Puissance du géant passe à 1d10, vous pouvez devenir de taille TG, et votre allonge augmente de 1,50 m pendant l'effet.$t$),
  -- Guerrier — Samouraï (53)
  (53, 3, null, $t$Maîtrise supplémentaire$t$, $t$Bonus Proficiency$t$, $t$Vous obtenez la maîtrise d'une compétence parmi Histoire, Intuition, Persuasion et Représentation, ou apprenez une langue.$t$),
  (53, 7, null, $t$Courtisan élégant$t$, $t$Elegant Courtier$t$, $t$Vous ajoutez votre modificateur de Sagesse à vos tests de Charisme (Persuasion), et obtenez la maîtrise des jets de sauvegarde de Sagesse (ou, à défaut, d'Intelligence ou de Charisme).$t$),
  (53, 10, null, $t$Esprit inépuisable$t$, $t$Tireless Spirit$t$, $t$Si vous n'avez plus d'utilisation d'Esprit combatif lorsque vous lancez l'initiative, vous en récupérez une.$t$),
  (53, 15, null, $t$Frappe rapide$t$, $t$Rapid Strike$t$, $t$Une fois par tour, lorsque vous avez l'avantage à un jet d'attaque avec une arme, vous pouvez y renoncer pour effectuer une attaque supplémentaire avec cette arme dans le cadre de la même action.$t$),
  (53, 18, null, $t$Force avant la mort$t$, $t$Strength before Death$t$, $t$Par une réaction lorsque vous tombez à 0 point de vie sans mourir, vous jouez immédiatement un tour supplémentaire ; vous ne tombez inconscient qu'à la fin de ce tour si vous êtes toujours à 0 point de vie. Une fois par repos long.$t$),
  -- Guerrier — Soldat psi (54)
  (54, 7, null, $t$Adepte télékinétique$t$, $t$Telekinetic Adept$t$, $t$Bond psionique : par une action bonus, vous obtenez une vitesse de vol égale au double de votre vitesse jusqu'à la fin du tour (une fois par repos court, ou en dépensant un dé d'énergie psionique). Poussée télékinétique : lorsque vous infligez des dégâts avec Frappe psionique, la cible doit réussir un jet de sauvegarde de Force ou tomber à terre ou être repoussée de 3 m.$t$),
  (54, 10, null, $t$Esprit protégé$t$, $t$Guarded Mind$t$, $t$Vous avez la résistance aux dégâts psychiques. Si vous êtes charmé ou effrayé au début de votre tour, vous pouvez dépenser un dé d'énergie psionique pour mettre fin à tous ces effets.$t$),
  (54, 15, null, $t$Rempart de force$t$, $t$Bulwark of Force$t$, $t$Par une action bonus, jusqu'à votre modificateur d'Intelligence créatures à 9 m ou moins (vous compris) bénéficient d'un abri partiel pendant 1 minute. Une fois par repos long, ou en dépensant un dé d'énergie psionique.$t$),
  (54, 18, null, $t$Maître télékinétique$t$, $t$Telekinetic Master$t$, $t$Vous pouvez lancer Télékinésie sans emplacement ni composantes (Intelligence) ; tant que vous vous concentrez sur ce sort, vous pouvez effectuer une attaque armée par une action bonus à chacun de vos tours. Une fois par repos long, ou en dépensant un dé d'énergie psionique.$t$),
  -- Magicien — Chantelame (62)
  (62, 2, null, $t$Entraînement à la guerre et au chant$t$, $t$Training in War and Song$t$, $t$Vous maîtrisez les armures légères, un type d'arme de corps à corps à une main de votre choix et la compétence Représentation.$t$),
  (62, 6, null, $t$Attaque supplémentaire$t$, $t$Extra Attack$t$, $t$Vous pouvez attaquer deux fois lorsque vous effectuez l'action Attaque ; l'une de ces attaques peut être remplacée par un sort mineur.$t$),
  (62, 10, null, $t$Chant de défense$t$, $t$Song of Defense$t$, $t$Tant que votre Chant des lames est actif, lorsque vous subissez des dégâts, vous pouvez utiliser votre réaction et dépenser un emplacement de sort pour réduire ces dégâts de cinq fois le niveau de l'emplacement.$t$),
  (62, 14, null, $t$Chant de victoire$t$, $t$Song of Victory$t$, $t$Tant que votre Chant des lames est actif, vous ajoutez votre modificateur d'Intelligence (minimum +1) aux dégâts de vos attaques armées au corps à corps.$t$),
  -- Magicien — Magie de guerre (63)
  (63, 2, null, $t$Esprit tactique$t$, $t$Tactical Wit$t$, $t$Vous ajoutez votre modificateur d'Intelligence à vos jets d'initiative.$t$),
  (63, 6, null, $t$Afflux de puissance$t$, $t$Power Surge$t$, $t$Vous stockez des afflux de puissance (maximum égal à votre modificateur d'Intelligence, remis à un après un repos long). Vous en gagnez un en mettant fin à un sort avec Dissipation de la magie ou Contresort, ou en finissant un repos court sans en avoir. Une fois par tour, en infligeant des dégâts avec un sort de magicien, vous pouvez en dépenser un pour infliger des dégâts de force supplémentaires égaux à la moitié de votre niveau de magicien.$t$),
  (63, 10, null, $t$Magie durable$t$, $t$Durable Magic$t$, $t$Tant que vous vous concentrez sur un sort, vous bénéficiez d'un bonus de +2 à la CA et à tous vos jets de sauvegarde.$t$),
  (63, 14, null, $t$Linceul déflecteur$t$, $t$Deflecting Shroud$t$, $t$Lorsque vous utilisez Déviation arcanique, jusqu'à trois créatures de votre choix à 18 m ou moins subissent des dégâts de force égaux à la moitié de votre niveau de magicien.$t$),
  -- Magicien — Ordre des scribes (64)
  (64, 2, null, $t$Plume magique$t$, $t$Wizardly Quill$t$, $t$Par une action bonus, vous créez une plume magique qui écrit sans encre, dans la couleur voulue. Copier un sort dans votre grimoire ne prend que 2 minutes par niveau avec elle, et vous pouvez effacer ce qu'elle a écrit à 1,50 m ou moins par une action bonus.$t$),
  (64, 6, null, $t$Esprit manifesté$t$, $t$Manifest Mind$t$, $t$Par une action bonus, l'esprit de votre grimoire éveillé se manifeste sous forme d'objet spectral de taille TP à 18 m ou moins ; il voit et entend (vision dans le noir 18 m) et partage ses perceptions avec vous. Vous pouvez lancer vos sorts de magicien comme s'ils partaient de lui, un nombre de fois égal à votre bonus de maîtrise par repos long.$t$),
  (64, 10, null, $t$Maître scribe$t$, $t$Master Scrivener$t$, $t$Après un repos long, vous pouvez créer avec votre plume un parchemin d'un sort de niveau 1 ou 2 de votre grimoire (temps d'incantation d'une action), qui compte comme lancé à un niveau de plus ; il disparaît après usage ou au repos long suivant. Vous copiez aussi les parchemins deux fois plus vite.$t$),
  (64, 14, null, $t$Un avec le verbe$t$, $t$One with the Word$t$, $t$Vous avez l'avantage aux tests d'Intelligence (Arcanes) tant que votre grimoire est sur vous. Si vous subissez des dégâts alors que son esprit est manifesté, vous pouvez congédier celui-ci par une réaction pour annuler ces dégâts ; lancez alors 3d6 : votre grimoire perd des sorts dont le total des niveaux atteint au moins ce résultat, jusqu'à ce que vous finissiez 1d6 repos longs. Une fois par repos long.$t$)
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

-- Contrôle final : plus aucune de ces sous-classes ne doit compter une seule aptitude.
do $$
declare
  v_left int;
begin
  select count(*) into v_left
    from (select f.subclass_id
            from public.class_features f
           where f.subclass_id in (14,15,16,17,19,21,22,23,24,25,26,37,38,39,40,41,43,44,45,46,47,50,51,52,53,54,62,63,64)
           group by f.subclass_id
          having count(*) <= 1) x;
  if v_left > 0 then
    raise exception 'Contrôle lot 5a : % sous-classes ont encore une seule aptitude', v_left;
  end if;
end $$;
