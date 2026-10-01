-- Lot 8 de l'import du contenu de référence : les 32 sorts officiels (hors UA) absents de la base,
-- avec leurs listes de classes (spell_classes). Texte français reformulé.
-- Classes : 2 Barde, 3 Clerc, 4 Druide, 8 Rôdeur, 10 Occultiste, 11 Magicien, 12 Ensorceleur, 13 Artificier.
-- Idempotente : un sort n'est inséré que si son nom FR n'existe pas déjà.

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
  ($t$Encoder les pensées$t$, $t$Encode Thoughts$t$, 0, $t$Enchantement$t$, $t$1 action$t$, $t$Personnelle$t$, false, true, false, $t$8 heures$t$, false, $t$Guide des guildes de Ravnica$t$, '{}'::int[],
   $t$Vous extrayez un souvenir, une idée ou un message de votre esprit (ou de celui d'une créature dont vous lisez les pensées) et le matérialisez en un filament de pensée, objet minuscule sans poids qu'on peut tenir. Lancer le sort en tenant un filament en révèle instantanément le contenu.$t$),
  ($t$Altération de valeur$t$, $t$Distort Value$t$, 1, $t$Illusion$t$, $t$1 minute$t$, $t$Contact$t$, true, false, false, $t$8 heures$t$, false, $t$Acquisitions Incorporated$t$, '{2,12,10,11}'::int[],
   $t$Un objet de 30 cm de côté au plus paraît valoir le double (fioritures illusoires) ou la moitié (bosses et rayures illusoires). Qui l'examine doit réussir un test d'Investigation contre votre DD de sort. Niveaux supérieurs : +30 cm de taille par niveau au-delà du 1er.$t$),
  ($t$Doigts de givre$t$, $t$Frost Fingers$t$, 1, $t$Évocation$t$, $t$1 action$t$, $t$Personnelle (cône de 4,50 mètres)$t$, true, true, false, $t$Instantanée$t$, false, $t$Icewind Dale : Rime of the Frostmaiden$t$, '{11}'::int[],
   $t$Un souffle glacé jaillit de vos doigts dans un cône de 4,50 m : chaque créature fait un jet de sauvegarde de Constitution et subit 2d8 dégâts de froid (moitié en cas de réussite). Les liquides non magiques non portés gèlent. Niveaux supérieurs : +1d8 par niveau au-delà du 1er.$t$),
  ($t$Projectile magique de Jim$t$, $t$Jim's Magic Missile$t$, 1, $t$Évocation$t$, $t$1 action$t$, $t$36 mètres$t$, true, true, true, $t$Instantanée$t$, false, $t$Acquisitions Incorporated$t$, '{11}'::int[],
   $t$Vous créez trois fléchettes de force et faites une attaque de sort à distance pour chacune : 2d4 dégâts de force par touche (5d4 sur un critique). Si un des jets donne un 1 naturel, toutes les fléchettes se retournent contre vous (1 dégât de force chacune). Composante : 1 po consommée comme « taxe ». Niveaux supérieurs : une fléchette et 1 po de taxe de plus par niveau au-delà du 1er.$t$),
  ($t$Barbes argentées$t$, $t$Silvery Barbs$t$, 1, $t$Enchantement$t$, $t$1 réaction, quand une créature que vous voyez à 18 mètres ou moins réussit un jet d'attaque, un test ou un jet de sauvegarde$t$, $t$18 mètres$t$, true, false, false, $t$Instantanée$t$, false, $t$Strixhaven : un programme de chaos$t$, '{2,12,11}'::int[],
   $t$La créature déclencheuse doit relancer son d20 et garder le résultat le plus bas. Vous pouvez ensuite choisir une autre créature à portée (vous compris) : elle a l'avantage à son prochain jet d'attaque, test ou jet de sauvegarde dans la minute.$t$),
  ($t$Bulle d'air$t$, $t$Air Bubble$t$, 2, $t$Invocation$t$, $t$1 action$t$, $t$18 mètres$t$, false, true, false, $t$24 heures$t$, false, $t$Spelljammer : Aventures dans l'espace$t$, '{13,4,8,12,11}'::int[],
   $t$Un globe spectral rempli d'air frais entoure la tête d'une créature consentante, qui ne peut pas suffoquer pendant la durée. Niveaux supérieurs : deux globes de plus par niveau au-delà du 2e.$t$),
  ($t$Savoir emprunté$t$, $t$Borrowed Knowledge$t$, 2, $t$Divination$t$, $t$1 action$t$, $t$Personnelle$t$, true, true, true, $t$1 heure$t$, false, $t$Strixhaven : un programme de chaos$t$, '{2,3,10,11}'::int[],
   $t$Vous puisez dans le savoir des esprits du passé : vous obtenez la maîtrise d'une compétence que vous ne maîtrisez pas pour la durée. Composante : un livre d'au moins 25 po.$t$),
  ($t$Nuée de familiers$t$, $t$Flock of Familiars$t$, 2, $t$Invocation$t$, $t$1 minute$t$, $t$Contact$t$, true, true, false, $t$Concentration, jusqu'à 1 heure$t$, true, $t$Le laboratoire perdu de Kwalish$t$, '{10,11}'::int[],
   $t$Vous appelez temporairement trois familiers (célestes, fées ou fiélons, au choix, tous du même type), selon les règles d'Appel de familier (un de moins si vous en avez déjà un). Ils communiquent par télépathie avec vous jusqu'à 1,5 km et peuvent transmettre vos sorts de contact (un par tour). Niveaux supérieurs : un familier de plus par niveau au-delà du 2e.$t$),
  ($t$Don de la parole$t$, $t$Gift of Gab$t$, 2, $t$Enchantement$t$, $t$1 réaction, quand vous parlez à une autre créature$t$, $t$Personnelle$t$, true, true, true, $t$Instantanée$t$, false, $t$Acquisitions Incorporated$t$, '{2,11}'::int[],
   $t$Chaque créature de votre choix à 1,50 m ou moins oublie ce que vous avez dit au cours des 6 dernières secondes et se souvient à la place des paroles prononcées pour lancer ce sort. Composante : 2 po consommées comme « taxe ».$t$),
  ($t$Pièce lumineuse de Jim$t$, $t$Jim's Glowing Coin$t$, 2, $t$Enchantement$t$, $t$1 action$t$, $t$18 mètres$t$, false, true, true, $t$1 minute$t$, false, $t$Acquisitions Incorporated$t$, '{11}'::int[],
   $t$Vous lancez une pièce qui s'illumine comme sous l'effet du sort Lumière ; chaque créature de votre choix à 9 m d'elle doit réussir un jet de sauvegarde de Sagesse ou être distraite pour la durée (désavantage aux tests de Perception et aux jets d'initiative). Composante : 2 po consommées comme « taxe ».$t$),
  ($t$Bond cinétique$t$, $t$Kinetic Jaunt$t$, 2, $t$Transmutation$t$, $t$1 action bonus$t$, $t$Personnelle$t$, false, true, false, $t$Concentration, jusqu'à 1 minute$t$, true, $t$Strixhaven : un programme de chaos$t$, '{13,2,12,11}'::int[],
   $t$Pour la durée : votre vitesse augmente de 3 m, vous ne provoquez pas d'attaques d'opportunité et vous pouvez traverser l'espace d'autres créatures sans terrain difficile. Si vous finissez votre tour dans l'espace d'une créature, vous êtes repoussé dans le dernier espace libre occupé et subissez 1d8 dégâts de force.$t$),
  ($t$Espièglerie de Nathair$t$, $t$Nathair's Mischief$t$, 2, $t$Illusion$t$, $t$1 action$t$, $t$18 mètres$t$, false, true, true, $t$Concentration, jusqu'à 1 minute$t$, true, $t$Le trésor draconique de Fizban$t$, '{2,12,11}'::int[],
   $t$Un cube de 6 m est empli de magie féerique et draconique ; au lancement puis au début de chacun de vos tours (après avoir pu déplacer le cube de 3 m), lancez 1d4 : 1 — odeur de tarte, charme (Sagesse) ; 2 — bouquets qui aveuglent (Dextérité) ; 3 — fou rire, créature neutralisée errant au hasard (Sagesse) ; 4 — mélasse, terrain difficile. Les effets durent jusqu'au début de votre prochain tour.$t$),
  ($t$Glace entravante de Rime$t$, $t$Rime's Binding Ice$t$, 2, $t$Évocation$t$, $t$1 action$t$, $t$Personnelle (cône de 9 mètres)$t$, false, true, true, $t$Instantanée$t$, false, $t$Le trésor draconique de Fizban$t$, '{12,11}'::int[],
   $t$Un cône de froid de 9 m : chaque créature fait un jet de sauvegarde de Constitution ; en cas d'échec, elle subit 3d8 dégâts de froid et sa vitesse tombe à 0 pendant 1 minute (jusqu'à ce qu'elle ou une autre brise la glace par une action) ; en cas de réussite, moitié des dégâts seulement. Niveaux supérieurs : +1d8 par niveau au-delà du 2e.$t$),
  ($t$Jet de cartes$t$, $t$Spray of Cards$t$, 2, $t$Invocation$t$, $t$1 action$t$, $t$Personnelle (cône de 4,50 mètres)$t$, true, true, true, $t$Instantanée$t$, false, $t$Le livre des choses innombrables$t$, '{2,12,10,11}'::int[],
   $t$Un cône de cartes spectrales de 4,50 m : chaque créature fait un jet de sauvegarde de Dextérité ; en cas d'échec, 2d10 dégâts de force et aveuglée jusqu'à la fin de son prochain tour ; en cas de réussite, moitié des dégâts seulement. Niveaux supérieurs : +1d10 par niveau au-delà du 2e.$t$),
  ($t$Distorsion tourbillonnante$t$, $t$Vortex Warp$t$, 2, $t$Invocation$t$, $t$1 action$t$, $t$27 mètres$t$, true, true, false, $t$Instantanée$t$, false, $t$Strixhaven : un programme de chaos$t$, '{13,12,11}'::int[],
   $t$Une créature que vous voyez à portée doit réussir un jet de sauvegarde de Constitution (elle peut choisir d'échouer) ou être téléportée dans un espace inoccupé de votre choix à portée, sur une surface ou un liquide pouvant la supporter. Niveaux supérieurs : +9 m de portée par niveau au-delà du 2e.$t$),
  ($t$Sens des distorsions$t$, $t$Warp Sense$t$, 2, $t$Divination$t$, $t$1 action$t$, $t$Personnelle$t$, true, true, true, $t$Concentration, jusqu'à 1 minute$t$, true, $t$Planescape : aventures dans le Multivers$t$, '{12,10,11}'::int[],
   $t$Vous percevez les portails, même inactifs, à 9 m ou moins. Par une action, vous pouvez en étudier un (test de caractéristique d'incantation DD 15) : en cas de réussite, vous apprenez son plan de destination et la clé requise. Bloqué par 30 cm de pierre, 2,5 cm de métal, une feuille de plomb ou 90 cm de bois ou de terre.$t$),
  ($t$Flétrir et fleurir$t$, $t$Wither and Bloom$t$, 2, $t$Nécromancie$t$, $t$1 action$t$, $t$18 mètres$t$, true, true, true, $t$Instantanée$t$, false, $t$Strixhaven : un programme de chaos$t$, '{4,12,11}'::int[],
   $t$Dans une sphère de 3 m de rayon, chaque créature de votre choix fait un jet de sauvegarde de Constitution et subit 2d6 dégâts nécrotiques (moitié en cas de réussite) ; la végétation non magique se flétrit. Une créature de votre choix dans la zone peut dépenser un dé de vie et récupérer le résultat + votre modificateur d'incantation. Niveaux supérieurs : +1d6 dégâts et un dé de vie de plus par niveau au-delà du 2e.$t$),
  ($t$Provocation$t$, $t$Antagonize$t$, 3, $t$Enchantement$t$, $t$1 action$t$, $t$9 mètres$t$, true, true, true, $t$Instantanée$t$, false, $t$Le livre des choses innombrables$t$, '{2,12,10,11}'::int[],
   $t$Une créature à portée fait un jet de sauvegarde de Sagesse ; en cas d'échec, elle subit 4d4 dégâts psychiques et doit utiliser sa réaction pour attaquer au corps à corps une autre créature de votre choix (sinon, désavantage à sa prochaine attaque) ; en cas de réussite, moitié des dégâts seulement. Niveaux supérieurs : +1d4 par niveau au-delà du 3e.$t$),
  ($t$Foulée d'Ashardalon$t$, $t$Ashardalon's Stride$t$, 3, $t$Transmutation$t$, $t$1 action bonus$t$, $t$Personnelle$t$, true, true, false, $t$Concentration, jusqu'à 1 minute$t$, true, $t$Le trésor draconique de Fizban$t$, '{13,8,12,11}'::int[],
   $t$Votre vitesse augmente de 6 m et vous ne provoquez pas d'attaques d'opportunité ; toute créature ou objet non porté à 1,50 m de votre passage subit 1d6 dégâts de feu (une fois par tour). Niveaux supérieurs : +1,50 m de vitesse et +1d6 dégâts par niveau au-delà du 3e.$t$),
  ($t$Amis rapides$t$, $t$Fast Friends$t$, 3, $t$Enchantement$t$, $t$1 action$t$, $t$9 mètres$t$, true, false, false, $t$Concentration, jusqu'à 1 heure$t$, true, $t$Acquisitions Incorporated$t$, '{2,3,11}'::int[],
   $t$Un humanoïde qui vous voit, vous entend et vous comprend doit réussir un jet de sauvegarde de Sagesse ou être charmé : il accomplit de bon cœur les tâches que vous lui confiez ; il peut refaire le jet si la tâche lui nuit ou le contrarie, et le sort prend fin si elle entraînerait sa mort. Niveaux supérieurs : une cible de plus par niveau au-delà du 3e.$t$),
  ($t$Tour de Galder$t$, $t$Galder's Tower$t$, 3, $t$Invocation$t$, $t$10 minutes$t$, $t$9 mètres$t$, true, true, true, $t$24 heures$t$, false, $t$Le laboratoire perdu de Kwalish$t$, '{11}'::int[],
   $t$Vous faites apparaître une tour de deux étages (3 m de haut, 9 m² par étage), chaque étage aménagé au choix (chambre, bureau, salle à manger, salon, salle d'eau, observatoire ou pièce vide), chaude et sèche. Relancer le sort la maintient 24 heures de plus ; lancé chaque jour pendant un an au même endroit, elle devient permanente. Niveaux supérieurs : un étage de plus par niveau au-delà du 3e.$t$),
  ($t$Susciter la cupidité$t$, $t$Incite Greed$t$, 3, $t$Enchantement$t$, $t$1 action$t$, $t$9 mètres$t$, true, true, true, $t$Concentration, jusqu'à 1 minute$t$, true, $t$Acquisitions Incorporated$t$, '{3,12,10,11}'::int[],
   $t$Vous présentez une gemme (50 po minimum) : les créatures choisies qui la voient doivent réussir un jet de sauvegarde de Sagesse ou être charmées, ne faisant que s'approcher prudemment de vous puis fixer la gemme à 1,50 m. Nouveau jet à la fin de chacun de leurs tours ; l'effet cesse si on leur nuit.$t$),
  ($t$Discours motivant$t$, $t$Motivational Speech$t$, 3, $t$Enchantement$t$, $t$1 minute$t$, $t$18 mètres$t$, true, false, false, $t$1 heure$t$, false, $t$Acquisitions Incorporated$t$, '{2,3}'::int[],
   $t$Jusqu'à cinq créatures qui vous entendent gagnent 5 points de vie temporaires et l'avantage aux jets de sauvegarde de Sagesse ; si l'une est touchée par une attaque, elle a l'avantage à sa prochaine attaque. Le sort cesse pour une créature quand elle perd ces points de vie temporaires. Niveaux supérieurs : +5 points de vie temporaires par niveau au-delà du 3e.$t$),
  ($t$Coursier rapide de Galder$t$, $t$Galder's Speedy Courier$t$, 4, $t$Invocation$t$, $t$1 action$t$, $t$3 mètres$t$, true, true, true, $t$10 minutes$t$, false, $t$Le laboratoire perdu de Kwalish$t$, '{10,11}'::int[],
   $t$Un petit élémentaire de l'air intangible apporte un coffre de 90 cm de côté ; une fois rempli et fermé, il disparaît et réapparaît auprès d'une créature que vous avez déjà vue (ou dont vous possédez un fragment), seule à pouvoir l'ouvrir. Si la cible est sur un autre plan ou protégée, le contenu revient à vos pieds. Composante : 25 po consommées. Niveaux supérieurs : au niveau 8, la cible peut être sur un autre plan.$t$),
  ($t$Scellement de portail$t$, $t$Gate Seal$t$, 4, $t$Abjuration$t$, $t$1 minute$t$, $t$18 mètres$t$, true, true, true, $t$24 heures$t$, false, $t$Planescape : aventures dans le Multivers$t$, '{12,10,11}'::int[],
   $t$Dans un cube fixe de 9 m, les portails se ferment et ne peuvent s'ouvrir, et les effets de voyage planaire (Portail, Changement de plan...) échouent pour entrer ou sortir de la zone. Composante : une clé de portail brisée, consommée. Niveaux supérieurs : au niveau 6 ou plus, dure jusqu'à dissipation.$t$),
  ($t$Lance psychique de Raulothim$t$, $t$Raulothim's Psychic Lance$t$, 4, $t$Enchantement$t$, $t$1 action$t$, $t$36 mètres$t$, true, false, false, $t$Instantanée$t$, false, $t$Le trésor draconique de Fizban$t$, '{2,12,10,11}'::int[],
   $t$Une lance psychique vise une créature que vous voyez (ou que vous nommez, si elle est à portée) : jet de sauvegarde d'Intelligence ; en cas d'échec, 7d6 dégâts psychiques et neutralisée jusqu'au début de votre prochain tour ; en cas de réussite, moitié des dégâts seulement. Niveaux supérieurs : +1d6 par niveau au-delà du 4e.$t$),
  ($t$Esprit de la mort$t$, $t$Spirit of Death$t$, 4, $t$Nécromancie$t$, $t$1 action$t$, $t$18 mètres$t$, true, true, true, $t$Concentration, jusqu'à 1 heure$t$, true, $t$Le livre des choses innombrables$t$, '{12,10,11}'::int[],
   $t$Vous appelez un esprit faucheur (bloc « esprit faucheur ») qui agit juste après vous et obéit à vos ordres verbaux (sinon il Esquive). Composante : une carte dorée représentant un avatar de la mort (400 po). Niveaux supérieurs : utilisez le niveau de l'emplacement dans le bloc de statistiques.$t$),
  ($t$Création de heaume spatial$t$, $t$Create Spelljamming Helm$t$, 5, $t$Transmutation$t$, $t$1 action$t$, $t$Contact$t$, true, true, true, $t$Instantanée$t$, false, $t$Spelljammer : Aventures dans l'espace$t$, '{13,11}'::int[],
   $t$Vous touchez un siège inoccupé de taille G ou inférieure avec une baguette de cristal (5 000 po, consommée) : il devient un heaume spatial permettant de piloter un vaisseau.$t$),
  ($t$Invocation d'esprit draconique$t$, $t$Summon Draconic Spirit$t$, 5, $t$Invocation$t$, $t$1 action$t$, $t$18 mètres$t$, true, true, true, $t$Concentration, jusqu'à 1 heure$t$, true, $t$Le trésor draconique de Fizban$t$, '{4,12,11}'::int[],
   $t$Vous appelez un esprit draconique de taille G (famille chromatique, gemme ou métallique) avec le bloc « esprit draconique » : CA 14 + niveau du sort, 50 points de vie (+10 par niveau au-delà du 5e), vol 18 m, souffle et attaques. Il agit juste après vous. Composante : un objet gravé d'un dragon (500 po).$t$),
  ($t$Bouclier de platine de Fizban$t$, $t$Fizban's Platinum Shield$t$, 6, $t$Abjuration$t$, $t$1 action bonus$t$, $t$18 mètres$t$, true, true, true, $t$Concentration, jusqu'à 1 minute$t$, true, $t$Le trésor draconique de Fizban$t$, '{12,11}'::int[],
   $t$Un champ de lumière argentée entoure une créature (vous compris) : abri partiel, résistance à l'acide, au feu, à la foudre, au froid et au poison, et Dérobade (aucun dégât sur un jet de sauvegarde de Dextérité réussi, moitié en cas d'échec). Par une action bonus, vous pouvez transférer le champ à une autre créature à 18 m.$t$),
  ($t$Création de magen$t$, $t$Create Magen$t$, 7, $t$Transmutation$t$, $t$1 heure$t$, $t$Contact$t$, true, true, true, $t$Instantanée$t$, false, $t$Icewind Dale : Rime of the Frostmaiden$t$, '{11}'::int[],
   $t$Vous transformez une poupée grandeur nature (avec une fiole de vif-argent de 500 po, consommées) en magen du type choisi, qui vous obéit sans condition. Votre maximum de points de vie diminue d'autant que le FP du magen (minimum 1) ; seul un Souhait annule cette réduction. Composante non consommée : une baguette de cristal (1 500 po).$t$),
  ($t$Transformation draconique$t$, $t$Draconic Transformation$t$, 7, $t$Transmutation$t$, $t$1 action bonus$t$, $t$Personnelle$t$, true, true, true, $t$Concentration, jusqu'à 1 minute$t$, true, $t$Le trésor draconique de Fizban$t$, '{4,12,11}'::int[],
   $t$Vous prenez des traits draconiques : vision aveugle de 9 m, ailes incorporelles (vol 18 m), et au lancement puis par une action bonus, un souffle de force dans un cône de 18 m (jet de sauvegarde de Dextérité, 6d8 dégâts de force, moitié en cas de réussite). Composante : une statuette de dragon (500 po).$t$)
    ) as t(name_fr, name_en, level, school, casting_time, range, verbal, somatic, material, duration, concentration, source, classes, description)
  loop
    if not exists (
      select 1 from public.translations tr
       where tr.entity_type = 'spell' and tr.field_name = 'name' and tr.locale = 'fr'
         and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.spells (level, school, casting_time, range, components, duration, concentration, ritual, source, is_incomplete)
        values (rec.level, rec.school, rec.casting_time, rec.range,
                jsonb_build_object('verbal', rec.verbal, 'somatic', rec.somatic, 'material', rec.material),
                rec.duration, rec.concentration, false, rec.source, false)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('spell', v_id::text, 'name', 'fr', rec.name_fr),
        ('spell', v_id::text, 'name', 'en', rec.name_en),
        ('spell', v_id::text, 'description', 'fr', rec.description);
      insert into public.spell_classes (spell_id, class_id)
        select v_id, c from unnest(rec.classes) as c
         where exists (select 1 from public.classes cl where cl.id = c);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'sorts insérés : %', v_inserted;
end $$;

-- Contrôle final
do $$
declare
  v_n int;
begin
  select count(*) into v_n
    from public.translations
   where entity_type = 'spell' and field_name = 'name' and locale = 'en'
     and value in ('Encode Thoughts','Distort Value','Frost Fingers','Jim''s Magic Missile','Silvery Barbs','Air Bubble',
                   'Borrowed Knowledge','Flock of Familiars','Gift of Gab','Jim''s Glowing Coin','Kinetic Jaunt',
                   'Nathair''s Mischief','Rime''s Binding Ice','Spray of Cards','Vortex Warp','Warp Sense','Wither and Bloom',
                   'Antagonize','Ashardalon''s Stride','Fast Friends','Galder''s Tower','Incite Greed','Motivational Speech',
                   'Galder''s Speedy Courier','Gate Seal','Raulothim''s Psychic Lance','Spirit of Death',
                   'Create Spelljamming Helm','Summon Draconic Spirit','Fizban''s Platinum Shield','Create Magen',
                   'Draconic Transformation');
  if v_n <> 32 then
    raise exception 'Contrôle lot 8 : % sorts sur 32', v_n;
  end if;
end $$;
