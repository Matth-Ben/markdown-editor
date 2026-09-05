-- Chantier "Personnages" (app mobile) — peuplement de public.feats
-- (0 ligne jusqu'ici, table créée par
-- 20260825090200_create_reference_races_classes_tables.sql : `id integer
-- generated always as identity`, `prerequisites jsonb not null default
-- '{}'`).
--
-- Les 42 dons classiques du Manuel des Joueurs (édition 2014).
--
-- Contexte légal, comme pour 20260905010000 (invocations) : un seul de ces
-- dons est couvert par une licence ouverte, Empoignade (Grappler), présent
-- dans le SRD 5.1 (révision CC-BY 4.0 de janvier 2023) — sa description
-- ci-dessous est une TRADUCTION FIDÈLE du texte source ouvert, à créditer
-- dans les mentions légales de l'app (voir `07-source-donnees-i18n.md`, pas
-- encore rédigées). Les 41 autres dons (contenu Manuel des Joueurs
-- propriétaire Wizards of the Coast, hors SRD) sont chacun une
-- REFORMULATION ENTIÈREMENT ORIGINALE de l'effet de jeu — jamais une
-- traduction/paraphrase proche du texte du livre. Contrairement aux 91
-- sous-classes Phase 5 (20260905000000, volontairement sans chiffre), un
-- don doit rester utilisable tel quel en séance : les chiffres et
-- mécaniques concrets (bonus, portées, dés...) sont des règles de jeu non
-- protégeables et sont donc assumés ici ; seule l'expression littéraire du
-- livre l'est, et n'est reprise nulle part.
--
-- Choix à l'apprentissage (Initié à la magie, Robuste, Adepte élémentaire,
-- Tireur d'élite occulte, Rituels magiques) : décrits dans le texte même de
-- la description, la table n'ayant pas de colonne dédiée à ce choix.
--
-- `prerequisites` reste un simple texte français libre dans le jsonb
-- (`{"text": "..."}`, `{}` si aucun), même format que les invocations :
-- aucune fonctionnalité mobile ne consomme encore cette table (vérifié,
-- aucune référence à `feats` dans le dépôt mobile) — une structure plus
-- fine sera définie quand l'écran correspondant sera réellement construit.
--
-- Idempotence : garde par nom sur public.translations
-- (entity_type='feat', field_name='name', locale='fr').

do $$
declare
  rec record;
  v_id int;
begin
  for rec in
    select * from (values
      ('Acteur', '{}'::jsonb,
        $j$Votre charisme s'affine (+1, jusqu'à 20). Vous obtenez l'avantage aux tests de Tromperie et de Représentation lorsque vous cherchez à vous faire passer pour quelqu'un d'autre, et vous pouvez imiter fidèlement la voix d'une personne ou un bruit précis que vous avez longuement entendu, au point de tromper l'oreille la plus attentive.$j$),
      ('Alerte', '{}'::jsonb,
        $j$Votre vigilance est redoutable : vous gagnez un bonus de +5 à l'initiative, vous ne pouvez plus être pris par surprise tant que vous êtes conscient, et le simple fait qu'un adversaire vous soit invisible ne lui procure plus l'avantage lorsqu'il vous attaque.$j$),
      ('Athlète', '{}'::jsonb,
        $j$Force ou Dextérité augmente de 1 (jusqu'à 20). Vous vous relevez d'une chute en ne dépensant qu'un mètre cinquante de déplacement, grimper ne vous coûte plus de déplacement supplémentaire, et un simple pas d'élan d'un mètre cinquante suffit avant un saut en longueur ou en hauteur.$j$),
      ('Chargeur', '{}'::jsonb,
        $j$Lorsque vous utilisez l'action Foncer et parcourez au moins trois mètres en ligne droite, vous pouvez, en action bonus, porter une attaque de mêlée qui inflige 5 dégâts supplémentaires en cas de touche, ou bousculer un adversaire pour le renverser ou le repousser de trois mètres de plus.$j$),
      ('Expert des armes à distance', '{}'::jsonb,
        $j$Vous ignorez la propriété de rechargement des arbalètes que vous maîtrisez, tirer à l'arbalète ne vous impose plus de désavantage même au contact d'un ennemi, et lorsque vous attaquez avec une arme à une main, vous pouvez tirer un carreau d'arbalète de poing supplémentaire en action bonus.$j$),
      ('Frappeur à deux armes', '{}'::jsonb,
        $j$Tant que vous combattez avec deux armes de corps à corps, vous gagnez +1 à la Classe d'Armure. Vous pouvez combattre à deux armes même si elles ne sont pas légères, et dégainer ou rengainer deux armes en une seule fois là où une seule serait normalement possible.$j$),
      ('Explorateur de donjon', '{}'::jsonb,
        $j$Vous bénéficiez de l'avantage aux tests de Perception et d'Investigation destinés à repérer des passages secrets ou des pièges, ainsi qu'à vos jets de sauvegarde contre les pièges, dont les dégâts sont réduits de moitié en cas d'échec. Explorer à un rythme rapide ne réduit plus votre perception passive face à ces dangers.$j$),
      ('Endurant', '{}'::jsonb,
        $j$Constitution augmente de 1 (jusqu'à 20). Chaque fois que vous relancez un dé de vie pour récupérer des points de vie, vous en regagnez au moins deux fois votre modificateur de Constitution.$j$),
      ('Maître d''armes lourdes', '{}'::jsonb,
        $j$Lorsque vous portez un coup critique ou réduisez une créature à 0 point de vie avec une arme de corps à corps, vous pouvez immédiatement porter une attaque de mêlée supplémentaire en action bonus. Avant d'attaquer avec une arme lourde que vous maîtrisez, vous pouvez accepter un malus de 5 au jet d'attaque pour infliger 10 dégâts supplémentaires en cas de touche.$j$),
      ('Guérisseur', '{}'::jsonb,
        $j$Stabiliser une créature mourante à l'aide d'une trousse de soins lui rend également 1 point de vie. En dépensant une utilisation de votre trousse de soins et votre action, vous pouvez soigner une créature blessée de 1d6+4 points de vie, plus un bonus supplémentaire égal au nombre de dés de vie qu'elle possède, une seule fois par créature entre deux repos courts ou longs.$j$),
      ('Pourfendeur de mages', '{}'::jsonb,
        $j$Lorsqu'une créature à moins d'un mètre cinquante de vous lance un sort, vous pouvez utiliser votre réaction pour l'attaquer en mêlée. Les créatures que vous blessez alors qu'elles se concentrent sur un sort subissent un désavantage à leur jet de sauvegarde de concentration, et vous bénéficiez vous-même de l'avantage aux jets de sauvegarde contre les sorts lancés par une créature à votre contact.$j$),
      ('Initié à la magie', '{}'::jsonb,
        $j$Vous choisissez une classe de lanceur de sorts (Barde, Clerc, Druide, Ensorceleur, Occultiste ou Magicien) à l'apprentissage de ce don : vous apprenez ainsi deux sorts mineurs de sa liste, ainsi qu'un sort de niveau 1, que vous pouvez lancer une fois gratuitement entre deux repos longs sans dépenser d'emplacement (ou normalement si vous disposez d'emplacements adaptés), en utilisant la caractéristique d'incantation propre à la classe choisie.$j$),
      ('Adepte martial', '{}'::jsonb,
        $j$Vous apprenez deux manœuvres martiales du répertoire du Maître de guerre et gagnez un dé de supériorité d6 pour les alimenter, retrouvé après chaque repos court ou long.$j$),
      ('Mobile', '{}'::jsonb,
        $j$Votre vitesse de déplacement augmente de trois mètres. Le terrain difficile ne vous coûte plus de déplacement supplémentaire lorsque vous utilisez l'action Foncer, et une créature que vous attaquez en mêlée ne peut plus vous infliger d'attaque d'opportunité si vous vous éloignez d'elle par la suite, que votre attaque ait touché ou non.$j$),
      ('Cavalier hors pair', '{}'::jsonb,
        $j$Vous bénéficiez de l'avantage aux jets d'attaque en mêlée contre toute créature à pied plus petite que votre monture. Vous pouvez désigner votre monture comme cible à votre place lorsqu'un adversaire l'attaque, et si elle réussit un jet de sauvegarde de Dextérité qui réduirait habituellement les dégâts subis de moitié, elle n'en subit alors aucun.$j$),
      ('Maître de la hallebarde', '{}'::jsonb,
        $j$Lorsque vous utilisez l'action Attaque avec un glaive, une hallebarde, une pique ou un bâton, vous pouvez porter une attaque supplémentaire en action bonus avec l'extrémité opposée de l'arme, infligeant 1d4 dégâts contondants. Tant que vous maniez l'une de ces armes, toute créature qui entre dans votre allonge déclenche une attaque d'opportunité de votre part.$j$),
      ('Robuste', '{}'::jsonb,
        $j$Vous choisissez une caractéristique à l'apprentissage de ce don : elle augmente de 1 (jusqu'à 20) et vous gagnez la maîtrise des jets de sauvegarde qui lui sont associés.$j$),
      ('Frappeur sauvage', '{}'::jsonb,
        $j$Une fois par tour, lorsque vous infligez des dégâts avec une attaque d'arme de corps à corps, vous pouvez relancer les dés de dégâts de l'arme et choisir le meilleur des deux résultats.$j$),
      ('Sentinelle', '{}'::jsonb,
        $j$Lorsque votre attaque d'opportunité touche sa cible, la vitesse de celle-ci tombe immédiatement à zéro jusqu'à la fin du tour. Une créature ne peut plus échapper à vos attaques d'opportunité simplement en se dégageant, et si un adversaire à votre contact attaque une autre cible que vous, vous pouvez utiliser votre réaction pour le frapper en retour.$j$),
      ('Tireur d''élite', '{}'::jsonb,
        $j$Tirer à longue portée ne vous impose plus de désavantage, et vos attaques à distance ignorent les bonus de couvert partiel ou aux trois quarts de votre cible. Avant d'attaquer à distance avec une arme que vous maîtrisez, vous pouvez accepter un malus de 5 au jet d'attaque pour infliger 10 dégâts supplémentaires en cas de touche.$j$),
      ('Maître du bouclier', '{}'::jsonb,
        $j$Lorsque vous utilisez l'action Attaque, vous pouvez bousculer un adversaire à l'aide de votre bouclier en action bonus. Tant que vous n'êtes pas incapable d'agir, vous ajoutez le bonus de Classe d'Armure de votre bouclier à vos jets de sauvegarde de Dextérité contre un effet qui ne cible que vous, et si vous réussissez un tel jet qui aurait normalement réduit les dégâts de moitié, vous n'en subissez alors aucun.$j$),
      ('Qualifié', '{}'::jsonb,
        $j$Vous gagnez la maîtrise de trois compétences ou outils de votre choix.$j$),
      ('Bagarreur de taverne', '{}'::jsonb,
        $j$Force ou Constitution augmente de 1 (jusqu'à 20). Vous êtes formé au maniement des armes improvisées, vos coups à mains nues infligent 1d4 dégâts contondants au lieu d'un seul point, et toucher avec un coup à mains nues ou une arme improvisée vous permet de tenter d'empoigner votre cible en action bonus.$j$),
      ('Robuste physiquement', '{}'::jsonb,
        $j$Votre total maximal de points de vie augmente de deux points par niveau de personnage, aussi bien rétroactivement qu'à chaque niveau gagné par la suite.$j$),
      ('Maître d''armes', '{}'::jsonb,
        $j$Force ou Dextérité augmente de 1 (jusqu'à 20), et vous gagnez la maîtrise de quatre armes de votre choix.$j$),
      ('Armure légère', '{}'::jsonb,
        $j$Force ou Dextérité augmente de 1 (jusqu'à 20), et vous gagnez la maîtrise des armures légères.$j$),
      ('Duelliste défensif', '{"text": "Dextérité 13 ou plus"}'::jsonb,
        $j$Lorsque vous maniez une arme de finesse et qu'un adversaire vous touche par une attaque de mêlée, vous pouvez utiliser votre réaction pour ajouter votre bonus de maîtrise à votre Classe d'Armure contre cette attaque, au point de la faire échouer.$j$),
      ('Sournois', '{"text": "Dextérité 13 ou plus"}'::jsonb,
        $j$Vous pouvez vous dissimuler même en étant simplement dans la pénombre. Rater une attaque à distance ne révèle plus votre position, et la faible luminosité ne vous impose plus de désavantage à vos tests de Perception fondés sur la vue.$j$),
      ('Meneur inspirant', '{"text": "Charisme 13 ou plus"}'::jsonb,
        $j$En consacrant dix minutes à galvaniser jusqu'à six compagnons qui vous entendent et vous comprennent, vous leur octroyez à chacun des points de vie temporaires égaux à votre niveau plus votre modificateur de Charisme, un bienfait qu'une même créature ne peut recevoir à nouveau qu'après un repos court ou long.$j$),
      ('Observateur', '{"text": "Intelligence ou Sagesse 13 ou plus"}'::jsonb,
        $j$Intelligence ou Sagesse augmente de 1 (jusqu'à 20). Vous pouvez lire sur les lèvres toute créature dont vous voyez la bouche s'exprimer dans une langue que vous comprenez, et vos scores de Perception passive et d'Investigation passive augmentent chacun de 5.$j$),
      ('Armure lourde', '{"text": "Maîtrise des armures intermédiaires"}'::jsonb,
        $j$Force augmente de 1 (jusqu'à 20), et vous gagnez la maîtrise des armures lourdes.$j$),
      ('Maître de l''armure intermédiaire', '{"text": "Maîtrise des armures intermédiaires"}'::jsonb,
        $j$Porter une armure intermédiaire ne vous impose plus de désavantage aux tests de Discrétion, et vous pouvez ajouter jusqu'à 3 points de votre modificateur de Dextérité (au lieu de 2) à votre Classe d'Armure lorsque vous en portez une.$j$),
      ('Armure intermédiaire', '{"text": "Maîtrise des armures légères"}'::jsonb,
        $j$Force ou Dextérité augmente de 1 (jusqu'à 20), et vous gagnez la maîtrise des armures intermédiaires ainsi que des boucliers.$j$),
      ('Maître de l''armure lourde', '{"text": "Maîtrise des armures lourdes"}'::jsonb,
        $j$Force augmente de 1 (jusqu'à 20). Tant que vous portez une armure lourde, les dégâts contondants, perforants ou tranchants infligés par une arme non magique sont réduits de 3 points.$j$),
      ('Adepte élémentaire', '{"text": "Capacité de lancer au moins un sort"}'::jsonb,
        $j$Vous choisissez un type de dégâts (acide, froid, feu, foudre ou tonnerre) à l'apprentissage de ce don, que vous pouvez reprendre plusieurs fois pour couvrir d'autres types : vos sorts infligeant ce type de dégâts ignorent la résistance de la cible, et tout 1 obtenu sur un dé de dégâts de ce type est compté comme un 2.$j$),
      ('Tireur d''élite occulte', '{"text": "Capacité de lancer au moins un sort"}'::jsonb,
        $j$Vous choisissez à l'apprentissage un sort que vous connaissez nécessitant un jet d'attaque à distance : sa portée est doublée. Vos attaques de sorts à distance ignorent en outre les bonus de couvert partiel ou aux trois quarts de la cible, et vous apprenez un sort mineur supplémentaire nécessitant un jet d'attaque, choisi dans la liste de n'importe quelle classe de lanceur de sorts.$j$),
      ('Guerrier-sorcier', '{"text": "Capacité de lancer au moins un sort"}'::jsonb,
        $j$Vous bénéficiez de l'avantage aux jets de sauvegarde de Constitution destinés à maintenir votre concentration sur un sort, vous pouvez exécuter les gestes d'incantation même les mains occupées par une arme ou un bouclier, et vous pouvez lancer un sort à la place d'une attaque d'opportunité lorsqu'une créature quitte votre allonge, en la ciblant.$j$),
      ('Rituels magiques', '{"text": "Intelligence ou Sagesse 13 ou plus"}'::jsonb,
        $j$Vous choisissez une classe de lanceur de sorts (Barde, Clerc, Druide, Occultiste ou Magicien) à l'apprentissage de ce don, qui détermine la caractéristique d'incantation utilisée : vous apprenez alors deux sorts de niveau 1 dotés du mot-clé rituel tirés de sa liste, que vous pouvez lancer uniquement en tant que rituels, sans les compter parmi les sorts que vous connaissez par ailleurs, à condition d'avoir en main le grimoire où vous les avez consignés.$j$),
      ('Linguiste', '{}'::jsonb,
        $j$Intelligence augmente de 1 (jusqu'à 20), et vous apprenez trois langues de votre choix. Vous savez également créer des messages écrits chiffrés que seuls vous-même ou ceux à qui vous avez enseigné le code peuvent déchiffrer aisément, quiconque d'autre devant réussir un test d'Intelligence particulièrement ardu.$j$),
      ('Esprit vif', '{}'::jsonb,
        $j$Intelligence augmente de 1 (jusqu'à 20). Vous savez toujours instinctivement où se trouve le nord, combien d'heures vous séparent du prochain lever ou coucher du soleil, et vous vous rappelez avec une précision parfaite tout ce que vous avez vu ou entendu au cours du dernier mois.$j$),
      ('Chanceux', '{}'::jsonb,
        $j$Vous disposez de trois points de chance, retrouvés après chaque repos long. Vous pouvez en dépenser un pour vous octroyer l'avantage sur un jet d'attaque, de sauvegarde ou de caractéristique que vous êtes sur le point d'effectuer, ou pour imposer le désavantage à l'attaque d'un ennemi dirigée contre vous, sans jamais dépenser plus d'un point sur un même jet.$j$),
      ('Empoignade', '{"text": "Force 13 ou plus"}'::jsonb,
        $j$Vous avez développé les compétences nécessaires pour dominer un adversaire au corps à corps. Vous bénéficiez des avantages suivants : vous avez l'avantage aux jets d'attaque contre une créature que vous empoignez. Vous pouvez utiliser votre action pour tenter d'immobiliser une créature que vous empoignez. Elle doit réussir un jet de sauvegarde de Force ou de Dextérité contre votre DD de manœuvre, sous peine d'être entravée, tout comme vous, jusqu'à la fin de l'empoignade.$j$)
    ) as t(name, prerequisites, description)
  loop
    if not exists (
      select 1 from public.translations
      where entity_type = 'feat' and field_name = 'name' and locale = 'fr' and value = rec.name
    ) then
      insert into public.feats (prerequisites) values (rec.prerequisites)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('feat', v_id::text, 'name', 'fr', rec.name),
        ('feat', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;
