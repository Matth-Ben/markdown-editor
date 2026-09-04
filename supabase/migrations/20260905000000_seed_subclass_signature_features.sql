-- Chantier "Personnages" (app mobile) — Phase 5, lot 3 — Aptitudes signature
-- des 91 sous-classes étendues.
--
-- Complète les 91 sous-classes ajoutées par
-- 20260902020000_seed_subclasses_extended.sql (nom + description de flaveur
-- uniquement) avec, pour chacune, une seule ligne dans public.class_features
-- au niveau public.subclasses.available_from_level — exactement le même
-- niveau de détail que les 12 sous-classes "iconiques" du socle Phase 1
-- (20260825090700_seed_classes_subclasses_features.sql), qui n'ont elles
-- aussi qu'une seule aptitude automatique chacune (pas de progression
-- multi-niveaux RAW).
--
-- Contrainte légale : ces 91 sous-classes viennent du Guide de Xanathar et du
-- Chaudron de Tasha (contenu hors SRD/CC-BY, contrairement au Manuel des
-- Joueurs). Chaque description ci-dessous est une reformulation entièrement
-- originale de l'effet de jeu le plus emblématique de la sous-classe — les
-- règles/mécaniques elles-mêmes ne sont pas protégeables, seule l'expression
-- littéraire du livre l'est, qui n'est jamais reprise ni paraphrasée de près
-- ici. Même registre que les 12 exemples existants : une ou deux phrases,
-- présent, adressé au joueur ("vous"), sans chiffre/dé/DD précis.
--
-- name/description vivent dans public.translations (migration 20260825090050).
-- choice_type/uses_per_rest restent NULL (aptitudes automatiques, pas un
-- choix ni un usage limité par repos, comme les 12 existantes). class_id
-- reste NULL (feature de sous-classe).
--
-- Idempotence : garde par ligne sur subclass_id (pas de garde globale, les 12
-- iconiques ont déjà subclass_id non nul).

do $$
declare
  rec record;
  v_id int;
  v_subclass_id int;
  v_level int;
begin
  for rec in
    select * from (values
      -- Barbare (niveau 3)
      ('Barbare', 'Guerrier totem', 'Esprit totémique', $j$Vous choisissez un esprit animal totémique (Ours, Aigle, Loup...) qui vous confère un pouvoir défensif ou offensif particulier tant que vous êtes en rage.$j$),
      ('Barbare', 'Bête', 'Forme de la bête', $j$Tant que vous êtes en rage, une partie de votre corps se transforme en arme naturelle — crocs, griffes ou queue — que vous pouvez utiliser au combat.$j$),
      ('Barbare', 'Gardien ancestral', 'Gardiens ancestraux', $j$Lorsque vous touchez un ennemi en rage, des esprits protecteurs le marquent : s'il n'attaque pas vous en priorité, ses attaques sont désavantagées et les dégâts qu'il inflige à vos alliés s'en trouvent réduits.$j$),
      ('Barbare', 'Géant', 'Ravages du géant', $j$Tant que vous êtes en rage, votre allonge et la portée de vos armes de jet augmentent, et chacun de vos coups portés avec une arme de jet peut repousser violemment votre adversaire.$j$),
      ('Barbare', 'Héraut des tempêtes', 'Aura de tempête', $j$Vous émanez une aura de tempête liée à un environnement choisi (désert, mer ou toundra) que vous pouvez déclencher en action bonus pour affecter les créatures proches de brûlure, de foudre ou de froid.$j$),
      ('Barbare', 'Magie sauvage', 'Sursaut de magie sauvage', $j$Lorsque vous entrez en rage, vous déclenchez un effet magique aléatoire qui affecte les créatures autour de vous, tantôt à votre avantage tantôt à celui de vos ennemis.$j$),
      ('Barbare', 'Zélote', 'Fureur divine', $j$Vos coups portés en rage sont empreints d'une puissance divine infligeant des dégâts supplémentaires, et votre foi vous permet de revenir d'entre les morts avec une facilité surnaturelle.$j$),

      -- Barde (niveau 3)
      ('Barde', 'Collège de la vaillance', 'Inspiration au combat', $j$Vous pouvez offrir un dé d'inspiration bardique à un allié pour qu'il l'ajoute à un jet de dégâts ou à sa Classe d'Armure en pleine bataille.$j$),
      ('Barde', 'Collège de l''éloquence', 'Langue d''argent', $j$Vos jets de Persuasion et de Tromperie ne peuvent jamais être inférieurs à un certain seuil, rendant votre éloquence redoutablement fiable, et vous pouvez perturber la volonté d'une créature qui vous entend parler.$j$),
      ('Barde', 'Collège de la création', 'Performance de la création', $j$Vous pouvez, par votre musique, faire naître temporairement un objet non magique inspiré du Son Originel de la création.$j$),
      ('Barde', 'Collège de la séduction', 'Manteau d''inspiration', $j$Vous pouvez insuffler votre inspiration bardique à plusieurs alliés à la fois, leur offrant protection temporaire et liberté de mouvement immédiate.$j$),
      ('Barde', 'Collège des épées', 'Fioriture de lame', $j$Chacune de vos attaques d'arme peut se conclure par une fioriture spectaculaire, dépensant un dé d'inspiration bardique pour repousser, blesser des adversaires proches ou améliorer votre défense.$j$),
      ('Barde', 'Collège des esprits', 'Contes d''outre-tombe', $j$Vous invoquez des récits d'esprits défunts pour produire un effet magique aléatoire — soin, illumination ou malédiction — en dépensant un dé d'inspiration bardique.$j$),
      ('Barde', 'Collège des murmures', 'Lames psychiques', $j$Une fois par tour, vous pouvez ajouter des dégâts psychiques supplémentaires à une attaque réussie en consommant un dé d'inspiration bardique, et votre seule présence peut instiller une terreur profonde.$j$),

      -- Clerc (niveau 1)
      ('Clerc', 'Duperie', 'Bénédiction du trompeur', $j$Vous pouvez octroyer à un allié un avantage temporaire sur ses jets de discrétion, une faveur digne d'une divinité de la ruse.$j$),
      ('Clerc', 'Guerre', 'Prêtre guerrier', $j$Un certain nombre de fois par jour, vous pouvez porter une attaque supplémentaire en action bonus lorsque vous utilisez l'action Attaque.$j$),
      ('Clerc', 'Lumière', 'Éclat de mise en garde', $j$Lorsqu'une créature que vous voyez vous attaque ou attaque un allié proche, vous pouvez créer un éclat de lumière aveuglant pour désavantager son jet d'attaque.$j$),
      ('Clerc', 'Nature', 'Acolyte de la nature', $j$Votre lien avec la nature vous octroie un sort mineur druidique supplémentaire et une aisance accrue dans les activités liées au monde sauvage.$j$),
      ('Clerc', 'Savoir', 'Bénédictions de la connaissance', $j$Vous gagnez une maîtrise, voire une expertise, dans des domaines de connaissance variés, ainsi que la compréhension de langues supplémentaires.$j$),
      ('Clerc', 'Tempête', 'Courroux de la tempête', $j$Lorsqu'une créature vous touche en mêlée, vous pouvez réagir pour lui infliger des dégâts de foudre ou de tonnerre en retour.$j$),
      ('Clerc', 'Crépuscule', 'Vision de la nuit', $j$Vous pouvez, un certain nombre de fois par repos long, partager votre vision dans le noir avec un groupe de compagnons proches.$j$),
      ('Clerc', 'Forge', 'Bénédiction de la forge', $j$À la fin d'un repos long, vous pouvez enchanter magiquement une arme ou une armure d'un allié, lui conférant temporairement un bonus surnaturel.$j$),
      ('Clerc', 'Tombe', 'Cercle de mortalité', $j$Lorsque vous soignez une créature réduite à 0 point de vie, vos sorts de guérison sont d'une efficacité maximale.$j$),

      -- Druide (niveau 2)
      ('Druide', 'Cercle de la lune', 'Forme sauvage de combat', $j$Vous pouvez prendre forme sauvage en action bonus et vous transformer en bêtes bien plus redoutables que la normale, y compris au combat.$j$),
      ('Druide', 'Cercle des astres', 'Forme astrale', $j$Vous pouvez, à la place de la forme sauvage, adopter une forme astrale scintillante correspondant à une constellation, vous octroyant selon le choix des soins, des attaques lumineuses ou une meilleure vision.$j$),
      ('Druide', 'Cercle du berger', 'Totem spirituel', $j$Vous invoquez un esprit protecteur spectral qui accompagne votre groupe et renforce vos alliés proches selon la nature du totem choisi.$j$),
      ('Druide', 'Cercle des fournaises', 'Esprit de la fournaise', $j$Lié à un esprit forgé de feu et de métal, vous convoquez un servant élémentaire qui vous assiste au combat et attise des flammes destructrices.$j$),
      ('Druide', 'Cercle des rêves', 'Baume de la Cour d''été', $j$Autour d'un feu de camp mystique, vous pouvez soigner et réconforter vos compagnons pendant un repos, dans l'esprit bienveillant du Royaume Féerique.$j$),
      ('Druide', 'Cercle des spores', 'Entité symbiotique', $j$Vous fusionnez temporairement avec vos spores fongiques, ce qui renforce vos coups au corps à corps de dégâts nécrotiques et vous octroie des points de vie temporaires.$j$),

      -- Ensorceleur (niveau 1)
      ('Ensorceleur', 'Magie sauvage', 'Marées du chaos', $j$Vous pouvez vous octroyer un avantage sur un jet en faisant appel au chaos qui sommeille en vous, quitte à déclencher ensuite un effet de magie sauvage imprévisible.$j$),
      ('Ensorceleur', 'Âme divine', 'Favorisé des dieux', $j$Lorsque vous ratez de peu un jet de sauvegarde ou une attaque, vous pouvez invoquer une faveur divine pour en améliorer le résultat.$j$),
      ('Ensorceleur', 'Âme mécanique', 'Rétablir l''équilibre', $j$Vous pouvez réagir pour annuler l'avantage ou le désavantage d'un jet effectué par une créature proche, rétablissant un ordre parfait.$j$),
      ('Ensorceleur', 'Aberrance', 'Parole télépathique', $j$Vous pouvez communiquer par télépathie avec toute créature que vous voyez, et lancer certains de vos sorts psioniques sans geste ni parole.$j$),
      ('Ensorceleur', 'Magie des ombres', 'Regard des ténèbres', $j$Vous voyez dans l'obscurité totale, et pouvez invoquer les ténèbres elles-mêmes en dépensant des points de sorcellerie.$j$),
      ('Ensorceleur', 'Sorcellerie des tempêtes', 'Magie tempétueuse', $j$Chaque fois que vous lancez un sort, vous pouvez brièvement voler dans les airs en action bonus, sans provoquer d'attaque d'opportunité.$j$),

      -- Guerrier (niveau 3)
      ('Guerrier', 'Maître de guerre', 'Supériorité au combat', $j$Vous disposez d'une réserve de dés de supériorité que vous dépensez pour exécuter des manœuvres martiales spéciales, comme déstabiliser, désarmer ou repousser un adversaire.$j$),
      ('Guerrier', 'Chevalier occulte', 'Incantation martiale', $j$Vous apprenez à lancer des sorts de magicien tout en conservant votre maîtrise martiale, et pouvez lier magiquement une arme à vous pour la faire apparaître dans votre main sur commande.$j$),
      ('Guerrier', 'Archer arcanique', 'Tir arcanique', $j$Vous pouvez insuffler à vos flèches une charge d'énergie arcanique, déclenchant un effet magique différent selon la manœuvre choisie.$j$),
      ('Guerrier', 'Cavalier', 'Marque inébranlable', $j$Vous marquez un ennemi engagé au corps à corps, le pénalisant s'il attaque une autre cible que vous, ce qui vous permet de protéger votre monture ou vos alliés.$j$),
      ('Guerrier', 'Chevalier runique', 'Gravure runique', $j$Vous gravez des runes magiques sur votre équipement, chacune vous octroyant un pouvoir particulier, et pouvez temporairement grandir pour frapper avec la force d'un géant.$j$),
      ('Guerrier', 'Samouraï', 'Détermination martiale', $j$Vous pouvez puiser dans votre détermination intérieure pour gagner des points de vie temporaires et frapper avec avantage sur vos attaques d'armes pendant un court instant.$j$),
      ('Guerrier', 'Soldat psi', 'Énergie psionique', $j$Vous disposez d'une réserve d'énergie psionique que vous pouvez employer pour repousser une cible à distance, réduire les dégâts que vous subissez ou renforcer momentanément vos attaques.$j$),

      -- Magicien (niveau 2)
      ('Magicien', 'Abjuration', 'Rempart arcanique', $j$Vous créez un bouclier magique qui absorbe les dégâts à votre place, rechargé chaque fois que vous lancez un sort d'abjuration.$j$),
      ('Magicien', 'Divination', 'Présage', $j$Chaque jour, vous prédisez plusieurs résultats de dés que vous pouvez ensuite substituer à un jet d'attaque, de sauvegarde ou de caractéristique, le vôtre ou celui d'une autre créature.$j$),
      ('Magicien', 'Enchantement', 'Regard hypnotique', $j$Vous pouvez plonger le regard d'une créature dans le vôtre pour la charmer et l'incapaciter momentanément.$j$),
      ('Magicien', 'Illusion', 'Illusion mineure améliorée', $j$Votre sort mineur d'illusion peut désormais créer à la fois un son et une image, rendant vos tromperies sensorielles bien plus convaincantes.$j$),
      ('Magicien', 'Invocation', 'Invocation mineure', $j$Vous pouvez matérialiser à partir de rien un petit objet non magique, qui s'évanouit au bout d'un moment — pratique pour improviser un outil, mais jamais assez durable ou précieux pour servir de monnaie.$j$),
      ('Magicien', 'Nécromancie', 'Moisson funeste', $j$Lorsque vous achevez une créature avec un sort, vous récupérez des points de vie supplémentaires, davantage encore si le sort est nécrotique.$j$),
      ('Magicien', 'Transmutation', 'Pierre du transmutateur', $j$Vous créez une pierre magique qui octroie à son porteur un bienfait durable, que vous pouvez modifier chaque fois que vous lancez un sort de transmutation.$j$),
      ('Magicien', 'Chantelames', 'Chant des lames', $j$Vous pouvez déclencher un chant des lames en action bonus, qui améliore votre Classe d'Armure, votre vitesse et votre concentration tant que vous combattez sans armure lourde.$j$),
      ('Magicien', 'Magie de guerre', 'Déviation arcanique', $j$Lorsque vous êtes attaqué ou visé par un effet, vous pouvez réagir pour renforcer momentanément votre Classe d'Armure ou votre jet de sauvegarde, au prix de votre capacité à lancer un sort ce tour.$j$),
      ('Magicien', 'Scribes', 'Grimoire éveillé', $j$Votre grimoire est un familier magique vivant qui vous permet, au moment de préparer vos sorts quotidiens, de changer le type de dégâts de certains d'entre eux.$j$),

      -- Moine (niveau 3)
      ('Moine', 'Voie de l''ombre', 'Arts de l''ombre', $j$Vous pouvez dépenser du ki pour plonger une zone dans l'obscurité, voir dans le noir, vous déplacer sans un bruit ou créer de petites illusions.$j$),
      ('Moine', 'Voie des quatre éléments', 'Disciplines élémentaires', $j$Vous apprenez à dépenser votre ki pour déclencher des effets élémentaires impressionnants, comme projeter une vague, souffler des flammes ou ériger un mur de glace.$j$),
      ('Moine', 'Voie de l''âme solaire', 'Rayon d''âme solaire', $j$Vous pouvez projeter à distance une décharge d'énergie radiante, considérée comme une attaque à mains nues.$j$),
      ('Moine', 'Voie de l''astre intérieur', 'Bras de l''astral', $j$Vous manifestez des bras spectraux astraux qui prolongent votre portée et vous permettent d'attaquer à mains nues en vous appuyant sur votre Sagesse plutôt que votre force physique.$j$),
      ('Moine', 'Voie de la miséricorde', 'Mains de miséricorde', $j$Vous pouvez canaliser votre ki à travers un simple contact pour soigner une créature ou, à l'inverse, aggraver les blessures d'un ennemi.$j$),
      ('Moine', 'Voie du dragon ascendant', 'Souffle du dragon ascendant', $j$Vous pouvez dépenser du ki pour exhaler un souffle draconique dévastateur, dont le type d'énergie dépend de votre lignée ascendante choisie.$j$),
      ('Moine', 'Voie du kensei', 'Armes du kensei', $j$Vous désignez certaines armes comme extensions de vos arts martiaux, pouvant y insuffler du ki pour améliorer vos attaques à distance ou en mêlée.$j$),
      ('Moine', 'Voie du maître ivre', 'Technique du maître ivre', $j$Votre technique de combat imite la démarche titubante d'un ivrogne : elle vous permet d'esquiver et de vous déplacer librement juste après une rafale de coups.$j$),

      -- Occultiste (niveau 1)
      ('Occultiste', 'Archifée', 'Présence féerique', $j$Vous pouvez déclencher une vague de charme ou de terreur féerique affectant les créatures autour de vous.$j$),
      ('Occultiste', 'Grand Ancien', 'Esprit éveillé', $j$Vous établissez un contact télépathique avec les créatures proches, pouvant communiquer silencieusement par la pensée.$j$),
      ('Occultiste', 'Céleste', 'Lumière curative', $j$Vous disposez d'une réserve de lumière curative que vous pouvez employer pour soigner une créature que vous voyez.$j$),
      ('Occultiste', 'Génie - Dao', 'Vase du génie', $j$Un vase magique lié à votre génie vous sert de refuge, et votre pacte avec ce génie de la terre vous confère une affinité particulière avec le sol et la pierre.$j$),
      ('Occultiste', 'Génie - Djinn', 'Vase du génie', $j$Un vase-palais magique lié à votre génie vous sert de refuge, et votre pacte avec ce génie de l'air vous permet de vous déplacer avec une grâce aérienne accrue.$j$),
      ('Occultiste', 'Génie - Éfrit', 'Vase du génie', $j$Une lampe magique liée à votre génie vous sert de refuge, et votre pacte avec ce génie du feu vous rend plus résistant aux flammes tout en réchauffant votre présence.$j$),
      ('Occultiste', 'Génie - Maride', 'Vase du génie', $j$Une urne magique liée à votre génie vous sert de refuge, et votre pacte avec ce génie de l'eau vous permet de respirer et de vous mouvoir aisément sous les flots.$j$),
      ('Occultiste', 'Insondable', 'Tentacule des profondeurs', $j$Vous pouvez invoquer un tentacule spectral qui frappe et peut agripper vos ennemis à votre place.$j$),
      ('Occultiste', 'Lame maudite', 'Malédiction de la lame maudite', $j$Vous pouvez maudire une créature, infligeant des dégâts supplémentaires à vos attaques contre elle et régénérant des points de vie si vous l'achevez.$j$),
      ('Occultiste', 'Mort-vivant', 'Parmi les morts', $j$Les morts-vivants ordinaires ne vous prennent pas pour cible sans raison, et vous pouvez communiquer plus aisément avec les esprits des défunts.$j$),

      -- Paladin (niveau 3)
      ('Paladin', 'Serment de dévotion', 'Arme sacrée', $j$Vous pouvez consacrer votre arme, la faisant briller d'une lumière sacrée et améliorant la précision de vos coups pendant un court instant.$j$),
      ('Paladin', 'Serment de vengeance', 'Vœu d''inimitié', $j$Vous pouvez désigner une créature comme votre ennemie jurée, obtenant l'avantage sur vos jets d'attaque contre elle.$j$),
      ('Paladin', 'Serment de conquête', 'Présence conquérante', $j$Vous pouvez déclencher une vague de terreur autour de vous, effrayant les créatures qui vous entourent.$j$),
      ('Paladin', 'Serment de gloire', 'Athlète accompli', $j$Vous pouvez invoquer une bénédiction athlétique qui décuple temporairement votre force, votre agilité et votre endurance physique.$j$),
      ('Paladin', 'Serment des guetteurs', 'Volonté du guetteur', $j$Vous pouvez insuffler à vous-même et à vos alliés proches une vigilance surnaturelle qui les protège des effets mentaux et des ruses planaires.$j$),
      ('Paladin', 'Serment de rédemption', 'Émissaire de la paix', $j$Vous pouvez invoquer une aura apaisante qui facilite grandement vos tentatives de persuasion pendant un court instant.$j$),

      -- Rôdeur (niveau 3)
      ('Rôdeur', 'Maître des bêtes', 'Compagnon animal', $j$Vous liez votre destin à celui d'un compagnon animal qui combat à vos côtés et partage certaines de vos actions.$j$),
      ('Rôdeur', 'Arpenteur de l''horizon', 'Guerrier planaire', $j$Une fois par tour, vous pouvez insuffler une énergie planaire dans l'une de vos attaques, et vous savez détecter la présence de portails ou de créatures venues d'autres plans.$j$),
      ('Rôdeur', 'Gardien de drake', 'Compagnon drake', $j$Vous faites éclore un petit compagnon draconique lié à vous par un pacte, qui grandit et combat à vos côtés.$j$),
      ('Rôdeur', 'Gardien des nuées', 'Nuée rassemblée', $j$Une nuée d'esprits spectraux (insectes, chauves-souris, corbeaux) vous accompagne en permanence, repoussant légèrement vos ennemis à chacune de vos attaques réussies.$j$),
      ('Rôdeur', 'Traqueur des ténèbres', 'Embusqueur redoutable', $j$Vous frappez avec une rapidité redoutable dès le premier round de combat, portant une attaque supplémentaire tout en évoluant aisément dans l'obscurité.$j$),
      ('Rôdeur', 'Tueur de monstres', 'Sens du chasseur de monstres', $j$Vous pouvez, en observant un instant un adversaire, discerner ses résistances, vulnérabilités et immunités aux dégâts.$j$),
      ('Rôdeur', 'Vagabond féerique', 'Frappes funestes', $j$Une fois par tour, vous pouvez ajouter des dégâts psychiques supplémentaires à l'une de vos attaques réussies, votre lien avec le Royaume Féerique aiguisant vos coups.$j$),

      -- Roublard (niveau 3)
      ('Roublard', 'Assassin', 'Assassinat', $j$Vous obtenez l'avantage sur vos attaques contre toute créature qui n'a pas encore agi lors du combat, et vos coups portés contre une cible prise par surprise sont automatiquement critiques.$j$),
      ('Roublard', 'Escroc arcanique', 'Ruse de la main magique', $j$Vous apprenez quelques sorts de magicien et pouvez invoquer une main spectrale invisible pour voler, manipuler ou dissimuler des objets à distance.$j$),
      ('Roublard', 'Âme acérée', 'Lames psychiques', $j$Vous manifestez des lames d'énergie psychique que vous pouvez projeter ou manier en combat, infligeant des dégâts mentaux.$j$),
      ('Roublard', 'Bretteur', 'Audace effrontée', $j$Vous pouvez porter votre attaque sournoise même en combat singulier sans avantage tactique, et vous déplacer librement autour d'un adversaire que vous venez d'attaquer sans subir d'attaque d'opportunité.$j$),
      ('Roublard', 'Conspirateur', 'Maître des tactiques', $j$Vous pouvez, en action bonus, guider un allié à distance pour lui procurer un avantage tactique sur sa prochaine attaque.$j$),
      ('Roublard', 'Éclaireur', 'Instinct d''éclaireur', $j$Vous vous éloignez automatiquement et sans risque d'un ennemi qui termine son tour à votre contact, un réflexe d'éclaireur aguerri au terrain.$j$),
      ('Roublard', 'Enquêteur', 'Œil du détail', $j$Vous pouvez, en action bonus, examiner attentivement une situation pour repérer une créature cachée ou déceler un mensonge.$j$),
      ('Roublard', 'Phantôme', 'Murmures des morts', $j$Lorsqu'une créature meurt sous vos coups, vous pouvez prélever un lien spirituel avec elle qui vous octroie temporairement l'une de ses compétences ou maîtrises d'outil.$j$)
    ) as t(class_name, subclass_name, name, description)
  loop
    begin
      select sc.id, sc.available_from_level into strict v_subclass_id, v_level
      from public.subclasses sc
      join public.translations st
        on st.entity_id = sc.id::text and st.entity_type = 'subclass'
        and st.field_name = 'name' and st.locale = 'fr'
      join public.translations ct
        on ct.entity_id = sc.class_id::text and ct.entity_type = 'class'
        and ct.field_name = 'name' and ct.locale = 'fr'
      where st.value = rec.subclass_name and ct.value = rec.class_name;
    exception
      when no_data_found then
        raise exception 'Sous-classe introuvable pour l''aptitude % : % / %', rec.name, rec.class_name, rec.subclass_name;
      when too_many_rows then
        raise exception 'Couple classe/sous-classe ambigu (plusieurs sous-classes correspondent) pour l''aptitude % : % / %', rec.name, rec.class_name, rec.subclass_name;
    end;

    if not exists (select 1 from public.class_features where subclass_id = v_subclass_id) then
      insert into public.class_features (subclass_id, level)
        values (v_subclass_id, v_level)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('class_feature', v_id::text, 'name', 'fr', rec.name),
        ('class_feature', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;
