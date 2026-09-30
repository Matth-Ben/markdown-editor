-- Lot 7 de l'import du contenu de référence : historiques officiels manquants (format 2014 de la
-- table : compétences, outils/langues, équipement, aptitude d'historique). Texte français reformulé ;
-- la source est rappelée en fin de description (la table n'a pas de colonne source).
-- Complète aussi l'historique « Grand voyageur » (id 16), resté à l'état d'ébauche.
-- Idempotente : insertion seulement si le nom FR n'existe pas déjà.

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
  -- Côte des Épées (SCAG)
  ($t$Garde urbain$t$, $t$City Watch$t$, $t$["Athlétisme","Perspicacité"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Uniforme de votre unité","Cor pour appeler à l'aide","Menottes","Bourse (10 po)"]$t$::jsonb,
   $t$Œil du guetteur$t$, $t$Vous repérez rapidement les postes de garde et quartiers généraux de la milice dans une communauté, ainsi que les repaires des criminels.$t$,
   $t$Vous avez servi la communauté où vous avez grandi comme première ligne de défense contre le crime. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Artisan de clan$t$, $t$Clan Crafter$t$, $t$["Histoire","Perspicacité"]$t$::jsonb, $t${"tools":["un type d'outils d'artisan au choix"],"languages":1,"language_choices":["Nain"]}$t$::jsonb, $t$["Outils d'artisan maîtrisés","Burin de marque du clan","Habits de voyage","Bourse (5 po et une gemme de 10 po)"]$t$::jsonb,
   $t$Respect du peuple robuste$t$, $t$Les nains et artisans nains vous accueillent : vous obtenez gîte et couvert gratuits dans leurs communautés, et ils vous renseignent volontiers.$t$,
   $t$Formé dans l'ancienne tradition artisanale des nains, vous connaissez la valeur d'un travail bien fait. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Érudit cloîtré$t$, $t$Cloistered Scholar$t$, $t$["Histoire","une compétence parmi Arcanes, Nature et Religion"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Robe d'érudit de votre cloître","Nécessaire d'écriture (plume, encre, parchemin, canif)","Livre emprunté sur un sujet de votre choix","Bourse (10 po)"]$t$::jsonb,
   $t$Accès aux bibliothèques$t$, $t$Vous avez libre accès aux bibliothèques et archives de votre institution, et pouvez obtenir l'accès à celles d'autres institutions savantes.$t$,
   $t$Élevé dans l'une des grandes bibliothèques ou académies de Faerûn, vous avez consacré votre vie au savoir. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Courtisan$t$, $t$Courtier$t$, $t$["Perspicacité","Persuasion"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Habits fins","Bourse (5 po)"]$t$::jsonb,
   $t$Fonctionnaire de cour$t$, $t$Vous connaissez le fonctionnement des bureaucraties et des cours : vous savez à qui vous adresser et pouvez consulter les archives administratives.$t$,
   $t$Vous avez occupé une position notable dans une cour noble ou une administration. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Agent de faction$t$, $t$Faction Agent$t$, $t$["Perspicacité","une compétence d'Intelligence, de Sagesse ou de Charisme liée à votre faction"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Insigne de votre faction","Texte fondateur de la faction (ou livre de codes)","Habits communs","Bourse (15 po)"]$t$::jsonb,
   $t$Refuge sûr$t$, $t$Vous connaissez les signes secrets de votre faction et pouvez trouver abri, soins et informations auprès de ses membres dans la plupart des grandes villes.$t$,
   $t$Vous œuvrez pour l'une des grandes organisations de la Côte des Épées (Ménestrels, Ordre du Gantelet, Enclave d'émeraude, Alliance des seigneurs, Zhentarim...). Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Héritier$t$, $t$Inheritor$t$, $t$["Survie","une compétence parmi Arcanes, Histoire et Religion"]$t$::jsonb, $t${"tools":["un jeu ou un instrument de musique au choix"],"languages":1}$t$::jsonb, $t$["Votre héritage","Habits de voyage","Outil maîtrisé","Bourse (15 po)"]$t$::jsonb,
   $t$Héritage$t$, $t$Vous détenez un objet de grande valeur (document, artefact, bijou, carte...) qui vous a été confié ; avec le MD, déterminez sa nature et son importance.$t$,
   $t$Vous êtes l'héritier d'un bien précieux, qui vous a été confié à vous seul. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Chevalier d'un ordre$t$, $t$Knight of the Order$t$, $t$["Persuasion","une compétence parmi Arcanes, Histoire, Nature et Religion selon l'ordre"]$t$::jsonb, $t${"tools":["un jeu ou un instrument de musique au choix"],"languages":1}$t$::jsonb, $t$["Habits de voyage","Chevalière, bannière ou sceau de votre ordre","Bourse (10 po)"]$t$::jsonb,
   $t$Considération chevaleresque$t$, $t$Les membres et sympathisants de votre ordre vous offrent gîte et soutien, et les gens du commun vous témoignent du respect.$t$,
   $t$Vous appartenez à un ordre de chevaliers lié par un serment envers un but commun. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Vétéran mercenaire$t$, $t$Mercenary Veteran$t$, $t$["Athlétisme","Persuasion"]$t$::jsonb, $t${"tools":["un jeu au choix"],"vehicles":["véhicules terrestres"]}$t$::jsonb, $t$["Uniforme de votre compagnie","Insigne de grade","Jeu au choix","Bourse (10 po)"]$t$::jsonb,
   $t$Vie de mercenaire$t$, $t$Vous connaissez les compagnies de mercenaires et leurs coutumes, et pouvez trouver du travail de mercenaire entre deux aventures pour vivre modestement.$t$,
   $t$Vous avez loué votre épée pour de l'or et connaissez les risques du métier. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Chasseur de primes urbain$t$, $t$Urban Bounty Hunter$t$, $t$["deux compétences parmi Tromperie, Perspicacité, Persuasion et Discrétion"]$t$::jsonb, $t${"tools":["deux parmi : un jeu, un instrument de musique, outils de voleur"]}$t$::jsonb, $t$["Vêtements adaptés à vos activités","Bourse (20 po)"]$t$::jsonb,
   $t$À l'écoute de la rue$t$, $t$Vous avez des contacts dans chaque ville où vous passez du temps, qui vous renseignent sur les personnes et les lieux.$t$,
   $t$Vous gagniez votre vie en traquant des gens contre rémunération, dans les bas-fonds comme dans la haute société. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Membre d'une tribu uthgardt$t$, $t$Uthgardt Tribe Member$t$, $t$["Athlétisme","Survie"]$t$::jsonb, $t${"tools":["un instrument de musique ou un type d'outils d'artisan"],"languages":1}$t$::jsonb, $t$["Piège de chasse","Tatouage ou symbole totémique","Habits de voyage","Bourse (10 po)"]$t$::jsonb,
   $t$Héritage uthgardt$t$, $t$Vous connaissez parfaitement le territoire de votre tribu et les terres sauvages du Nord : vous trouvez deux fois plus de nourriture et d'eau en chassant et cueillant, et les tribus uthgardt vous accueillent.$t$,
   $t$Vous appartenez à l'une des tribus barbares du Nord, fidèles à Uthgar et à leur animal totem. Source : Guide des aventuriers de la Côte des Épées.$t$),
  ($t$Noble de Waterdeep$t$, $t$Waterdhavian Noble$t$, $t$["Histoire","Persuasion"]$t$::jsonb, $t${"tools":["un jeu ou un instrument de musique au choix"],"languages":1}$t$::jsonb, $t$["Habits fins","Chevalière ou broche","Parchemin de lignée","Outre de vin fin","Bourse (20 po)"]$t$::jsonb,
   $t$Train de vie assuré$t$, $t$Lorsque vous êtes à Waterdeep ou ailleurs dans le Nord, votre maison paie pour vous les dépenses courantes d'un train de vie confortable (hébergement, repas...).$t$,
   $t$Vous êtes issu d'une des grandes familles nobles de Waterdeep, jalouse de ses privilèges. Source : Guide des aventuriers de la Côte des Épées.$t$),
  -- Tombe de l'annihilation, Theros, Baldur's Gate, Witchlight
  ($t$Anthropologue$t$, $t$Anthropologist$t$, $t$["Perspicacité","Religion"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Journal relié de cuir","Bouteille d'encre","Plume","Habits de voyage","Babiole d'importance particulière","Bourse (10 po)"]$t$::jsonb,
   $t$Linguiste adepte$t$, $t$Après avoir observé des humanoïdes parler une langue pendant au moins un jour, vous pouvez communiquer avec eux de manière rudimentaire.$t$,
   $t$Fasciné par les autres cultures, vous avez étudié les peuples et leurs coutumes, jusqu'à pouvoir vous fondre parmi eux. Source : Tombe de l'annihilation.$t$),
  ($t$Archéologue$t$, $t$Archaeologist$t$, $t$["Histoire","Survie"]$t$::jsonb, $t${"tools":["Outils de cartographe ou outils de navigateur"],"languages":1}$t$::jsonb, $t$["Étui en bois avec la carte d'une ruine","Lanterne à capote","Pioche de mineur","Habits de voyage","Pelle","Tente pour deux","Babiole trouvée lors d'une fouille","Bourse (25 po)"]$t$::jsonb,
   $t$Connaissances historiques$t$, $t$Dans une ruine ou un donjon, vous pouvez déterminer son usage d'origine et ses bâtisseurs ; vous estimez aussi la valeur des objets d'art et antiquités.$t$,
   $t$Vous étudiez les cultures disparues à travers leurs vestiges, ruines et artefacts. Source : Tombe de l'annihilation.$t$),
  ($t$Athlète$t$, $t$Athlete$t$, $t$["Acrobaties","Athlétisme"]$t$::jsonb, $t${"vehicles":["véhicules terrestres"],"languages":1}$t$::jsonb, $t$["Disque de bronze ou balle de cuir","Porte-bonheur ou trophée","Habits de voyage","Bourse (10 po)"]$t$::jsonb,
   $t$Échos de victoire$t$, $t$Vous attirez l'attention des amateurs de sport : dans une ville de 10 000 habitants ou plus, vous trouvez un admirateur prêt à vous aider (hébergement, contacts), et vous pouvez gagner votre vie en concourant.$t$,
   $t$Vous excellez dans une épreuve athlétique et avez connu la gloire des compétitions. Source : Odyssées mythiques de Theros.$t$),
  ($t$Sans-visage$t$, $t$Faceless$t$, $t$["Tromperie","Intimidation"]$t$::jsonb, $t${"tools":["Kit de déguisement"],"languages":1}$t$::jsonb, $t$["Kit de déguisement","Costume","Bourse (10 po)"]$t$::jsonb,
   $t$Double personnalité$t$, $t$Vous menez votre vie de héros sous un masque (persona) : ceux qui vous connaissent sous votre véritable identité ignorent votre persona, et inversement, sauf si vous vous trahissez.$t$,
   $t$Parce que vous ne pouviez être un héros tel que vous êtes, vous avez adopté un personnage masqué. Source : Baldur's Gate : Descente en Averne.$t$),
  ($t$Égaré féerique$t$, $t$Feylost$t$, $t$["Tromperie","Survie"]$t$::jsonb, $t${"tools":["un instrument de musique au choix"],"languages":1,"language_choices":["Elfique","Gnome","Gobelin","Sylvestre"]}$t$::jsonb, $t$["Instrument de musique","Habits de voyage","Trois babioles de la Féerie","Bourse (8 po)"]$t$::jsonb,
   $t$Lien avec la Féerie$t$, $t$Les bêtes et fées de la Féerie vous reconnaissent comme l'un des leurs et vous accueillent ; vous pouvez souvent obtenir leur aide ou leur hospitalité.$t$,
   $t$Vous avez grandi dans la Féerie après avoir disparu de votre plan natal durant l'enfance. Source : Au-delà du Carnaval de Sorcelume.$t$),
  ($t$Main du Carnaval$t$, $t$Witchlight Hand$t$, $t$["Représentation","Escamotage"]$t$::jsonb, $t${"tools":["Kit de déguisement ou un instrument de musique"],"languages":1}$t$::jsonb, $t$["Kit de déguisement ou instrument de musique","Jeu de cartes","Costume de carnaval","Babiole de la Féerie","Bourse (8 po)"]$t$::jsonb,
   $t$Pilier du carnaval$t$, $t$Vous connaissez les rouages du carnaval et ses employés ; vous pouvez y circuler librement et obtenir gîte et couvert auprès des gens du spectacle.$t$,
   $t$Vous vous êtes glissé dans le Carnaval de Sorcelume enfant et n'en êtes jamais reparti, y gagnant votre place. Source : Au-delà du Carnaval de Sorcelume.$t$),
  -- Fantômes de Saltmarsh
  ($t$Pêcheur$t$, $t$Fisher$t$, $t$["Histoire","Survie"]$t$::jsonb, $t${"languages":1}$t$::jsonb, $t$["Matériel de pêche","Filet","Leurre favori ou bottes huilées","Habits de voyage","Bourse (10 po)"]$t$::jsonb,
   $t$Récolter les eaux$t$, $t$Vous avez l'avantage aux tests utilisant du matériel de pêche ; avec un accès à un plan d'eau poissonneux, vous nourrissez jusqu'à dix personnes par jour.$t$,
   $t$Vous avez travaillé sur les docks et les bateaux de pêche, à la merci des marées. Source : Fantômes de Saltmarsh.$t$),
  ($t$Soldat de marine$t$, $t$Marine$t$, $t$["Athlétisme","Survie"]$t$::jsonb, $t${"vehicles":["véhicules terrestres","véhicules d'eau"]}$t$::jsonb, $t$["Dague d'un camarade tombé","Chiffon aux couleurs de votre navire","Habits de voyage","Bourse (10 po)"]$t$::jsonb,
   $t$Stoïque$t$, $t$Vous pouvez vous déplacer à pleine vitesse tout en conservant la discrétion d'un déplacement lent en terrain difficile, et vous connaissez les techniques de débarquement et de raid.$t$,
   $t$Entraîné à combattre sur les plages et les rivages, vous avez mené des raids nocturnes depuis la mer. Source : Fantômes de Saltmarsh.$t$),
  ($t$Charpentier de marine$t$, $t$Shipwright$t$, $t$["Histoire","Perception"]$t$::jsonb, $t${"tools":["Outils de charpentier"],"vehicles":["véhicules d'eau"]}$t$::jsonb, $t$["Outils de charpentier","Livre vierge","Encre","Plume","Habits de voyage","Bourse (10 po)"]$t$::jsonb,
   $t$Je vais le colmater !$t$, $t$Avec des outils de charpentier et du bois, vous réparez la coque d'un navire de 5 × votre bonus de maîtrise points de vie ; impossible à refaire avant une remise en état complète à terre.$t$,
   $t$Vous avez construit et réparé des navires, et connaissez chaque planche d'une coque. Source : Fantômes de Saltmarsh.$t$),
  ($t$Contrebandier$t$, $t$Smuggler$t$, $t$["Athlétisme","Tromperie"]$t$::jsonb, $t${"vehicles":["véhicules d'eau"]}$t$::jsonb, $t$["Gilet de cuir élégant ou bottes de cuir","Habits communs","Bourse (15 po)"]$t$::jsonb,
   $t$Profil bas$t$, $t$Vous connaissez un réseau de contrebandiers : dans une communauté donnée, vous et vos compagnons pouvez loger gratuitement dans leurs planques (train de vie pauvre).$t$,
   $t$Vous avez transporté des marchandises illicites sous le nez des autorités. Source : Fantômes de Saltmarsh.$t$),
  -- Bigby, Curse of Strahd, Eberron, Van Richten, Book of Many Things
  ($t$Enfant trouvé des géants$t$, $t$Giant Foundling$t$, $t$["Intimidation","Survie"]$t$::jsonb, $t${"languages":2,"language_choices":["Géant","une langue au choix"]}$t$::jsonb, $t$["Sac à dos","Habits de voyage","Petite pierre ou brindille rappelant votre foyer","Bourse (10 po)"]$t$::jsonb,
   $t$Frappe des géants$t$, $t$Vous obtenez le don Frappe des géants : une fois par tour, en touchant avec une arme, vous infligez 1d10 dégâts supplémentaires (feu, froid, foudre, tonnerre ou force/repoussement selon le géant choisi), un nombre de fois égal à votre bonus de maîtrise par repos long.$t$,
   $t$Sans être un géant, vous avez grandi parmi eux, recueilli ou élevé par une famille de géants. Source : Bigby présente : La gloire des géants.$t$),
  ($t$Graveur de runes$t$, $t$Rune Carver$t$, $t$["Histoire","Perception"]$t$::jsonb, $t${"tools":["un type d'outils d'artisan au choix"],"languages":1,"language_choices":["Géant"]}$t$::jsonb, $t$["Outils d'artisan au choix","Petit couteau","Pierre à aiguiser","Habits communs","Bourse (10 po)"]$t$::jsonb,
   $t$Façonneur de runes$t$, $t$Vous obtenez le don Façonneur de runes : vous connaissez des runes que vous pouvez graver sur des objets pour lancer certains sorts (Comprendre les langues au départ, puis d'autres), sans emplacement, un nombre de fois égal à votre bonus de maîtrise par repos long.$t$,
   $t$Vous avez consacré votre vie à l'étude de l'art runique des géants. Source : Bigby présente : La gloire des géants.$t$),
  ($t$Hanté$t$, $t$Haunted One$t$, $t$["deux compétences parmi Arcanes, Investigation, Religion et Survie"]$t$::jsonb, $t${"languages":2,"language_choices":["dont une langue exotique (abyssal, céleste, profond, draconique, infernal, primordial, sylvestre ou commun des profondeurs)"]}$t$::jsonb, $t$["Paquetage de chasseur de monstres (coffre, pied-de-biche, marteau, pieux, symbole sacré, eau bénite, menottes, miroir, huile, amadou, 3 torches)","Babiole à caractère macabre","Habits communs","1 pa"]$t$::jsonb,
   $t$Cœur de ténèbres$t$, $t$Ceux qui regardent dans vos yeux devinent que vous avez affronté l'indicible ; les gens du commun vous craignent mais vous aideront à combattre les ténèbres, et peuvent vous héberger voire se battre à vos côtés.$t$,
   $t$Vous êtes hanté par un événement si terrible que vous n'osez en parler. Source : La malédiction de Strahd.$t$),
  ($t$Agent d'une maison$t$, $t$House Agent$t$, $t$["Investigation","Persuasion"]$t$::jsonb, $t${"tools":["deux maîtrises selon votre maison marquée du dragon"]}$t$::jsonb, $t$["Habits fins","Chevalière de votre maison","Papiers d'identité","Bourse (20 po)"]$t$::jsonb,
   $t$Relations de la maison$t$, $t$Votre maison marquée du dragon vous fournit gîte, couvert et assistance dans ses enclaves, et peut vous confier des missions ou des ressources.$t$,
   $t$Vous avez juré fidélité à l'une des maisons marquées du dragon d'Eberron. Source : Eberron : l'ascension après la Dernière Guerre.$t$),
  ($t$Enquêteur$t$, $t$Investigator$t$, $t$["deux compétences parmi Perspicacité, Investigation et Perception"]$t$::jsonb, $t${"tools":["Kit de déguisement","Outils de voleur"]}$t$::jsonb, $t$["Loupe","Preuve d'une ancienne affaire","Habits communs","Bourse (10 po)"]$t$::jsonb,
   $t$Enquête officielle$t$, $t$Vous savez obtenir l'accès aux personnes et aux lieux liés à une enquête : en vous présentant comme enquêteur, vous pouvez interroger témoins et suspects et accéder aux scènes de crime.$t$,
   $t$Vous cherchez inlassablement la vérité, que ce soit au nom de la loi ou contre elle. Source : Guide de Van Richten sur Ravenloft.$t$),
  ($t$Récompensé$t$, $t$Rewarded$t$, $t$["Perspicacité","Persuasion"]$t$::jsonb, $t${"tools":["un jeu au choix"],"languages":1}$t$::jsonb, $t$["Bouteille d'encre noire","Plume","Cinq feuilles de papier","Jeu maîtrisé","Chevalière","Habits fins","Bourse (15 po)"]$t$::jsonb,
   $t$Faveur du destin$t$, $t$Vous obtenez le don Faveur du destin : une fois par repos long, après un jet de d20 raté, vous pouvez lancer un d6 et l'ajouter (ou obtenir un point de chance, selon la variante choisie).$t$,
   $t$Une faveur inattendue du destin (peut-être une carte du Jeu merveilleux) a changé votre vie. Source : Le livre des choses innombrables.$t$),
  ($t$Déchu$t$, $t$Ruined$t$, $t$["Discrétion","Survie"]$t$::jsonb, $t${"tools":["un jeu au choix"],"languages":1}$t$::jsonb, $t$["Sablier fêlé","Menottes rouillées","Bouteille à moitié vide","Piège de chasse","Jeu maîtrisé","Habits de voyage","Bourse (13 po)"]$t$::jsonb,
   $t$Toujours debout$t$, $t$Vous obtenez le don Toujours debout : quand vous tombez à 0 point de vie, vous pouvez vous relever avec quelques points de vie une fois par repos long, et vous avez l'avantage aux jets de sauvegarde contre la mort.$t$,
   $t$Vous avez tout perdu — fortune, rang ou proches — et vous vous relevez des ruines de votre ancienne vie. Source : Le livre des choses innombrables.$t$),
  -- Acquisitions Incorporated
  ($t$Rejeton d'aventuriers célèbres$t$, $t$Celebrity Adventurer's Scion$t$, $t$["Perception","Représentation"]$t$::jsonb, $t${"tools":["Kit de déguisement"],"languages":2}$t$::jsonb, $t$["Kit de déguisement","Habits fins","Bourse (30 po)"]$t$::jsonb,
   $t$Faire jouer ses relations$t$, $t$Vous avez rencontré de nombreuses personnalités puissantes, dont certaines se souviennent de vous ; les gens du commun vous traitent avec déférence.$t$,
   $t$Enfant d'aventuriers célèbres, vous avez grandi dans l'ombre (et la lumière) de leur renommée. Source : Acquisitions Incorporated.$t$),
  ($t$Marchand ruiné$t$, $t$Failed Merchant$t$, $t$["Investigation","Persuasion"]$t$::jsonb, $t${"tools":["un type d'outils d'artisan au choix"],"languages":1}$t$::jsonb, $t$["Outils d'artisan","Balance de marchand","Habits fins","Bourse (10 po)"]$t$::jsonb,
   $t$Chaîne d'approvisionnement$t$, $t$Vous gardez des contacts parmi grossistes, fournisseurs et marchands, que vous pouvez solliciter pour trouver objets ou informations.$t$,
   $t$Votre commerce a fait faillite, mais vous en avez gardé le sens des affaires. Source : Acquisitions Incorporated.$t$),
  ($t$Joueur$t$, $t$Gambler$t$, $t$["Tromperie","Perspicacité"]$t$::jsonb, $t${"tools":["un jeu au choix"],"languages":1}$t$::jsonb, $t$["Jeu","Porte-bonheur","Habits fins","Bourse (15 po)"]$t$::jsonb,
   $t$Ne me parlez pas des probabilités$t$, $t$Lors d'activités de jeux de hasard ou d'évaluation de plans, vous sentez quel choix est le plus sûr et quelles occasions sont trop belles pour être vraies.$t$,
   $t$Vous vivez des jeux de hasard et savez calculer les risques. Source : Acquisitions Incorporated.$t$),
  ($t$Plaignant$t$, $t$Plaintiff$t$, $t$["Médecine","Persuasion"]$t$::jsonb, $t${"tools":["un type d'outils d'artisan au choix"],"languages":1}$t$::jsonb, $t$["Outils d'artisan","Habits fins","20 po"]$t$::jsonb,
   $t$Jargon juridique$t$, $t$Vous connaissez les rouages du système juridique local et savez impressionner par un jargon savant ; les gens du commun croient volontiers que vous maîtrisez la loi.$t$,
   $t$Vous avez poursuivi (ou été poursuivi par) une puissante entreprise, et connaissez les tribunaux. Source : Acquisitions Incorporated.$t$),
  ($t$Stagiaire rival$t$, $t$Rival Intern$t$, $t$["Histoire","Investigation"]$t$::jsonb, $t${"tools":["un type d'outils d'artisan au choix"],"languages":1}$t$::jsonb, $t$["Outils d'artisan","Registre de votre ancien employeur","Habits fins","Bourse (10 po)"]$t$::jsonb,
   $t$Informateur interne$t$, $t$Vous gardez des contacts chez votre ancien employeur et ses partenaires, qui vous fournissent des informations à la discrétion du MD.$t$,
   $t$Ancien stagiaire d'une organisation rivale, vous en connaissez les secrets. Source : Acquisitions Incorporated.$t$),
  -- Dragonlance, Planescape
  ($t$Chevalier de Solamnie$t$, $t$Knight of Solamnia$t$, $t$["Athlétisme","Survie"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Insigne de grade","Jeu de cartes","Habits communs","Bourse (10 po)"]$t$::jsonb,
   $t$Écuyer de Solamnie$t$, $t$Vous obtenez le don Écuyer de Solamnie : avantage à une attaque armée par une action bonus (dégâts supplémentaires en cas de touche), un nombre de fois égal à votre bonus de maîtrise par repos long.$t$,
   $t$Vous vous êtes entraîné à devenir un valeureux Chevalier de Solamnie. Source : Dragonlance : L'ombre de la reine des dragons.$t$),
  ($t$Mage de la haute sorcellerie$t$, $t$Mage of High Sorcery$t$, $t$["Arcanes","Histoire"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Bouteille d'encre colorée","Plume","Habits communs","Bourse (10 po)"]$t$::jsonb,
   $t$Initié de la haute sorcellerie$t$, $t$Vous obtenez le don Initié de la haute sorcellerie : un sort mineur et un sort de niveau 1 liés à l'ordre de votre robe (blanche, rouge ou noire), le second lançable une fois par repos long sans emplacement.$t$,
   $t$Votre talent magique a attiré l'attention des Mages de la haute sorcellerie. Source : Dragonlance : L'ombre de la reine des dragons.$t$),
  ($t$Gardien de portail$t$, $t$Gate Warden$t$, $t$["Persuasion","Survie"]$t$::jsonb, $t${"languages":2,"language_choices":["abyssal, céleste ou infernal recommandés"]}$t$::jsonb, $t$["Trousseau de clés","Livre vierge","Plume","Encre noire","Habits de voyage","Bourse (10 po)"]$t$::jsonb,
   $t$Infusion planaire$t$, $t$Vous obtenez le don Infusion planaire : résistance à un type de dégâts lié à un plan, et un sort de ce plan que vous pouvez lancer une fois par repos long.$t$,
   $t$Vous avez longtemps vécu dans une ville-portail baignée de forces planaires. Source : Planescape : aventures dans le Multivers.$t$),
  ($t$Philosophe planaire$t$, $t$Planar Philosopher$t$, $t$["Arcanes","la compétence liée à votre faction de Sigil (ou une au choix)"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Clé de portail","Manifeste de votre philosophie","Habits communs aux couleurs de la faction","Bourse (10 po)"]$t$::jsonb,
   $t$Conviction$t$, $t$Vous obtenez le don Conviction : +1 à l'Intelligence, la Sagesse ou le Charisme, maîtrise ou expertise d'une compétence, et un sort lié à votre faction lançable une fois par repos long.$t$,
   $t$Vous adhérez à l'une des factions philosophiques de Sigil, la Cité des Portes. Source : Planescape : aventures dans le Multivers.$t$),
  -- Ravnica
  ($t$Fonctionnaire azorius$t$, $t$Azorius Functionary$t$, $t$["Perspicacité","Intimidation"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Insigne azorius","Parchemin d'une loi importante","Encre bleue","Plume","Habits fins","Bourse (10 po)"]$t$::jsonb,
   $t$Autorité légale$t$, $t$Vous êtes habilité à faire appliquer la loi à Ravnica : vous pouvez exiger des explications, arrêter un contrevenant et faire appel à la force publique ; les sorts de guilde azorius s'ajoutent à votre liste si vous lancez des sorts.$t$,
   $t$Membre du Sénat azorius, vous veillez à l'ordre et à la loi. Source : Guide des guildes de Ravnica.$t$),
  ($t$Légionnaire boros$t$, $t$Boros Legionnaire$t$, $t$["Athlétisme","Intimidation"]$t$::jsonb, $t${"tools":["un jeu au choix"],"languages":1,"language_choices":["Céleste","Draconique","Gobelin","Minotaure"]}$t$::jsonb, $t$["Insigne boros","Plume d'aile d'ange","Morceau de bannière boros","Habits communs","Bourse (2 po)"]$t$::jsonb,
   $t$Poste de la Légion$t$, $t$Vous avez un grade dans la Légion Boros : vous pouvez réquisitionner un équipement simple et obtenir l'aide de légionnaires dans les postes de la Légion ; sorts de guilde boros ajoutés à votre liste.$t$,
   $t$Membre de la Légion Boros, votre vie est vouée à la justice et au combat contre le mal. Source : Guide des guildes de Ravnica.$t$),
  ($t$Agent dimir$t$, $t$Dimir Operative$t$, $t$["Tromperie","Discrétion"]$t$::jsonb, $t${"tools":["Kit de déguisement"],"languages":1}$t$::jsonb, $t$["Insigne dimir","Trois petits couteaux","Habits communs sombres","Équipement de l'historique de votre guilde de couverture"]$t$::jsonb,
   $t$Fausse identité$t$, $t$Vous avez une seconde identité au sein d'une autre guilde, avec papiers et contacts ; sorts de guilde dimir ajoutés à votre liste.$t$,
   $t$Vous êtes un espion ; secrets et désinformation sont votre fonds de commerce. Source : Guide des guildes de Ravnica.$t$),
  ($t$Agent golgari$t$, $t$Golgari Agent$t$, $t$["Nature","Survie"]$t$::jsonb, $t${"tools":["Kit d'empoisonneur"],"languages":1,"language_choices":["Elfique","Géant","Kraul"]}$t$::jsonb, $t$["Insigne golgari","Kit d'empoisonneur","Coléoptère ou araignée de compagnie","Habits communs","Bourse (10 po)"]$t$::jsonb,
   $t$Chemins de la sous-cité$t$, $t$Vous connaissez les tunnels et passages souterrains de Ravnica et pouvez trouver un itinéraire caché vers la plupart des lieux de la ville ; sorts de guilde golgari ajoutés à votre liste.$t$,
   $t$Membre de l'essaim Golgari, vous célébrez le cycle de la vie, de la mort et de la décomposition. Source : Guide des guildes de Ravnica.$t$),
  ($t$Anarchiste gruul$t$, $t$Gruul Anarch$t$, $t$["Dressage","Athlétisme"]$t$::jsonb, $t${"tools":["Kit d'herboriste"],"languages":1,"language_choices":["Draconique","Géant","Gobelin","Sylvestre"]}$t$::jsonb, $t$["Insigne gruul","Piège de chasse","Kit d'herboriste","Crâne de sanglier","Cape en peau de bête","Habits de voyage","Bourse (10 po)"]$t$::jsonb,
   $t$Refuge des Friches$t$, $t$Vous connaissez les Friches de Ravnica et y trouvez toujours abri et nourriture pour vous et vos compagnons ; sorts de guilde gruul ajoutés à votre liste.$t$,
   $t$Membre des clans Gruul, vous rejetez la civilisation et vénérez la nature sauvage. Source : Guide des guildes de Ravnica.$t$),
  ($t$Ingénieur izzet$t$, $t$Izzet Engineer$t$, $t$["Arcanes","Investigation"]$t$::jsonb, $t${"tools":["un type d'outils d'artisan au choix"],"languages":1,"language_choices":["Draconique","Gobelin","Vedalken"]}$t$::jsonb, $t$["Insigne izzet","Outils d'artisan","Restes d'une expérience ratée","Marteau","Palan","Habits communs","Bourse (5 po)"]$t$::jsonb,
   $t$Infrastructures urbaines$t$, $t$Vous connaissez les réseaux souterrains et techniques de la ville (conduits, égouts, machineries) et savez vous y orienter ; sorts de guilde izzet ajoutés à votre liste.$t$,
   $t$Inventeur passionné de la Ligue Izzet, vous aimez les expériences audacieuses. Source : Guide des guildes de Ravnica.$t$),
  ($t$Représentant orzhov$t$, $t$Orzhov Representative$t$, $t$["Intimidation","Religion"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Insigne orzhov","Chaîne de dix pièces d'or","Vêtements sacerdotaux","Habits fins","Bourse (1 pp)"]$t$::jsonb,
   $t$Influence$t$, $t$Vous pouvez exercer une pression sur des débiteurs du Syndicat Orzhov pour obtenir faveurs, informations ou services ; sorts de guilde orzhov ajoutés à votre liste.$t$,
   $t$Membre du Syndicat Orzhov, vous servez une église où la richesse est synonyme de pouvoir. Source : Guide des guildes de Ravnica.$t$),
  ($t$Cultiste rakdos$t$, $t$Rakdos Cultist$t$, $t$["Acrobaties","Représentation"]$t$::jsonb, $t${"tools":["un instrument de musique au choix"],"languages":1,"language_choices":["Abyssal","Géant"]}$t$::jsonb, $t$["Insigne rakdos","Instrument de musique","Costume","Lanterne en fer forgé","Chaîne à pointes de 3 m","Boîte à amadou","Bourse (10 po)"]$t$::jsonb,
   $t$Réputation effrayante$t$, $t$Les gens craignent votre culte : on vous laisse passer, on évite de vous contrarier, et vous obtenez aisément ce qui peut vous calmer ; sorts de guilde rakdos ajoutés à votre liste.$t$,
   $t$Artiste du Culte de Rakdos, vous vivez pour le spectacle, les excès et le chaos. Source : Guide des guildes de Ravnica.$t$),
  ($t$Initié selesnya$t$, $t$Selesnya Initiate$t$, $t$["Nature","Persuasion"]$t$::jsonb, $t${"tools":["un type d'outils d'artisan ou un instrument de musique"],"languages":1,"language_choices":["Elfique","Loxodon","Sylvestre"]}$t$::jsonb, $t$["Insigne selesnya","Kit de soins","Robe","Habits communs","Bourse (5 po)"]$t$::jsonb,
   $t$Abri du Conclave$t$, $t$Vous et vos compagnons pouvez obtenir abri, soins et nourriture dans tout lieu du Conclave Selesnya ; sorts de guilde selesnya ajoutés à votre liste.$t$,
   $t$Membre du Conclave Selesnya, vous croyez en l'harmonie de la communauté et de la nature. Source : Guide des guildes de Ravnica.$t$),
  ($t$Scientifique simic$t$, $t$Simic Scientist$t$, $t$["Arcanes","Médecine"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Insigne simic","Habits communs","Livre de notes de recherche","Plume","Encre de seiche","Flasque d'huile","Flasque d'acide","Fiole d'eau de mer","Tube de verre","Bourse (10 po)"]$t$::jsonb,
   $t$Chercheur$t$, $t$Si vous ignorez une information, vous savez souvent où la trouver, notamment dans les laboratoires et archives du Combinat Simic ; sorts de guilde simic ajoutés à votre liste.$t$,
   $t$Chercheur du Combinat Simic, vous voulez améliorer la vie par l'hybridation et la science. Source : Guide des guildes de Ravnica.$t$),
  -- Strixhaven
  ($t$Étudiant de Lorehold$t$, $t$Lorehold Student$t$, $t$["Histoire","Religion"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Encre noire","Plume","Marteau","Lanterne à capote","Boîte à amadou","Ouvrage d'histoire","Uniforme scolaire","Bourse (8 po)"]$t$::jsonb,
   $t$Initié de Lorehold$t$, $t$Vous obtenez le don Initié de Strixhaven (Lorehold) : deux sorts mineurs et un sort de niveau 1 de la liste du collège, ce dernier lançable une fois par repos long sans emplacement.$t$,
   $t$Vous vous êtes préparé à étudier au collège Lorehold, qui explore l'histoire et les esprits du passé. Source : Strixhaven : un programme de chaos.$t$),
  ($t$Étudiant de Prismari$t$, $t$Prismari Student$t$, $t$["Acrobaties","Représentation"]$t$::jsonb, $t${"tools":["un instrument de musique ou un type d'outils d'artisan"],"languages":1}$t$::jsonb, $t$["Encre noire","Plume","Outils d'artisan ou instrument de musique","Uniforme scolaire","Bourse (10 po)"]$t$::jsonb,
   $t$Initié de Prismari$t$, $t$Vous obtenez le don Initié de Strixhaven (Prismari) : deux sorts mineurs et un sort de niveau 1 de la liste du collège, ce dernier lançable une fois par repos long sans emplacement.$t$,
   $t$Artiste dans l'âme, vous vous préparez à exprimer votre art par la magie élémentaire au collège Prismari. Source : Strixhaven : un programme de chaos.$t$),
  ($t$Étudiant de Quandrix$t$, $t$Quandrix Student$t$, $t$["Arcanes","Nature"]$t$::jsonb, $t${"tools":["un type d'outils d'artisan au choix"],"languages":1}$t$::jsonb, $t$["Encre noire","Plume","Boulier","Ouvrage de théorie arcanique","Uniforme scolaire","Bourse (15 po)"]$t$::jsonb,
   $t$Initié de Quandrix$t$, $t$Vous obtenez le don Initié de Strixhaven (Quandrix) : deux sorts mineurs et un sort de niveau 1 de la liste du collège, ce dernier lançable une fois par repos long sans emplacement.$t$,
   $t$Passionné par les mathématiques des motifs naturels, vous vous préparez à étudier au collège Quandrix. Source : Strixhaven : un programme de chaos.$t$),
  ($t$Étudiant de Silverquill$t$, $t$Silverquill Student$t$, $t$["Intimidation","Persuasion"]$t$::jsonb, $t${"languages":2}$t$::jsonb, $t$["Encre noire","Plume","Recueil de poésie","Uniforme scolaire","Bourse (15 po)"]$t$::jsonb,
   $t$Initié de Silverquill$t$, $t$Vous obtenez le don Initié de Strixhaven (Silverquill) : deux sorts mineurs et un sort de niveau 1 de la liste du collège, ce dernier lançable une fois par repos long sans emplacement.$t$,
   $t$Vous avez travaillé l'écriture et l'éloquence pour étudier la magie des mots au collège Silverquill. Source : Strixhaven : un programme de chaos.$t$),
  ($t$Étudiant de Witherbloom$t$, $t$Witherbloom Student$t$, $t$["Nature","Survie"]$t$::jsonb, $t${"tools":["Kit d'herboriste"],"languages":1}$t$::jsonb, $t$["Encre noire","Plume","Livre d'identification des plantes","Marmite en fer","Kit d'herboriste","Uniforme scolaire","Bourse (9 po)"]$t$::jsonb,
   $t$Initié de Witherbloom$t$, $t$Vous obtenez le don Initié de Strixhaven (Witherbloom) : deux sorts mineurs et un sort de niveau 1 de la liste du collège, ce dernier lançable une fois par repos long sans emplacement.$t$,
   $t$Passionné d'alchimie et des cycles de vie et de mort, vous vous préparez à étudier au collège Witherbloom. Source : Strixhaven : un programme de chaos.$t$),
  -- Wildemount, Spelljammer
  ($t$Rieur$t$, $t$Grinner$t$, $t$["Tromperie","Représentation"]$t$::jsonb, $t${"tools":["un instrument de musique au choix","Outils de voleur"]}$t$::jsonb, $t$["Habits fins","Kit de déguisement","Instrument de musique","Anneau doré à visage souriant","Bourse (15 po)"]$t$::jsonb,
   $t$Ballade du bouffon souriant$t$, $t$Dans chaque ville, vous savez trouver un contact du Rictus doré ; en jouant la ballade, vous obtenez gîte et couvert auprès des sympathisants du réseau.$t$,
   $t$Membre du Rictus doré, vous combattez la tyrannie en transmettant des messages codés par la musique. Source : Guide de l'explorateur de Wildemount.$t$),
  ($t$Agent volstrucker$t$, $t$Volstrucker Agent$t$, $t$["Tromperie","Discrétion"]$t$::jsonb, $t${"tools":["Kit d'empoisonneur"],"languages":1}$t$::jsonb, $t$["Habits communs","Cape noire à capuche","Kit d'empoisonneur","Bourse (10 po)"]$t$::jsonb,
   $t$Réseau de l'ombre$t$, $t$Vous avez accès à un réseau secret de sympathisants et d'informateurs du Cerberus Assembly, qui vous transmettent messages et renseignements.$t$,
   $t$Ancien assassin arcanique au service de la Cerberus Assembly de l'Empire de Dwendal. Source : Guide de l'explorateur de Wildemount.$t$),
  ($t$Vagabond astral$t$, $t$Astral Drifter$t$, $t$["Perspicacité","Religion"]$t$::jsonb, $t${"languages":2,"language_choices":["céleste ou gith recommandés"]}$t$::jsonb, $t$["Habits de voyage","Journal","Plume","Encre","Bourse (10 po)"]$t$::jsonb,
   $t$Contact divin$t$, $t$Vous obtenez le don Initié à la magie (clerc) et avez aperçu une divinité morte ou endormie dans la mer Astrale, ce qui vous vaut des connaissances singulières.$t$,
   $t$Vous avez longtemps dérivé dans la mer Astrale, où vous avez cessé de vieillir. Source : Spelljammer : Aventures dans l'espace.$t$),
  ($t$Spatien$t$, $t$Wildspacer$t$, $t$["Athlétisme","Survie"]$t$::jsonb, $t${"tools":["Outils de navigateur"],"vehicles":["véhicules spatiaux"]}$t$::jsonb, $t$["Cabillot (gourdin)","Habits de voyage","Grappin","Corde de chanvre (15 m)","Bourse (10 po)"]$t$::jsonb,
   $t$Adaptation à l'espace sauvage$t$, $t$Vous obtenez le don Robuste, et vous vous adaptez à l'apesanteur (pas de désavantage au combat en gravité nulle, déplacement sans pénalité).$t$,
   $t$Vous avez grandi dans le vide de l'espace sauvage, sur un astéroïde minier, une lune agricole ou un vaisseau. Source : Spelljammer : Aventures dans l'espace.$t$)
    ) as t(name_fr, name_en, skills, choices, equipment, feature_name, feature_description, description)
  loop
    if not exists (
      select 1 from public.translations tr
       where tr.entity_type = 'background' and tr.field_name = 'name' and tr.locale = 'fr'
         and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.backgrounds (skill_proficiencies, tool_or_language_choices, equipment, is_incomplete)
        values (rec.skills, rec.choices, rec.equipment, false)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('background', v_id::text, 'name', 'fr', rec.name_fr),
        ('background', v_id::text, 'name', 'en', rec.name_en),
        ('background', v_id::text, 'feature_name', 'fr', rec.feature_name),
        ('background', v_id::text, 'feature_description', 'fr', rec.feature_description),
        ('background', v_id::text, 'description', 'fr', rec.description);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'historiques insérés : %', v_inserted;
end $$;

-- Grand voyageur (Far Traveler, SCAG) : la ligne existe (id 16) mais n'était qu'une ébauche.
update public.backgrounds
   set skill_proficiencies = '["Perspicacité","Perception"]'::jsonb,
       tool_or_language_choices = $t${"tools":["un instrument de musique ou un jeu au choix"],"languages":1}$t$::jsonb,
       equipment = $t$["Habits de voyage","Instrument de musique ou jeu maîtrisé","Cartes grossières de votre terre natale","Petit bijou de votre pays (10 po)","Bourse (5 po)"]$t$::jsonb,
       is_incomplete = false
 where id = 16 and is_incomplete;

insert into public.translations (entity_type, entity_id, field_name, locale, value)
select 'background', '16', v.field_name, v.locale, v.value
  from (values
    ('name', 'en', $t$Far Traveler$t$),
    ('feature_name', 'fr', $t$Tous les regards sur vous$t$),
    ('feature_description', 'fr', $t$Votre accent, vos manières et vos vêtements trahissent vos origines lointaines : on vous dévisage, mais cette curiosité attire aussi des gens influents, intrigués par votre pays.$t$),
    ('description', 'fr', $t$Vous venez d'une terre lointaine, presque inconnue des gens de la région où vous voyagez. Source : Guide des aventuriers de la Côte des Épées.$t$)
  ) as v(field_name, locale, value)
 where exists (select 1 from public.backgrounds where id = 16)
   and not exists (select 1 from public.translations t
                    where t.entity_type = 'background' and t.entity_id = '16'
                      and t.field_name = v.field_name and t.locale = v.locale);

-- Contrôle final
do $$
declare
  v_n int;
begin
  select count(*) into v_n from public.backgrounds where not is_incomplete;
  if v_n < 72 then
    raise exception 'Contrôle lot 7 : % historiques complets, 72 attendus au minimum', v_n;
  end if;
  if exists (select 1 from public.backgrounds where is_incomplete) then
    raise exception 'Contrôle lot 7 : un historique reste marqué incomplet';
  end if;
end $$;
