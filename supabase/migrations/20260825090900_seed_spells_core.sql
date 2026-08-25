-- Chantier "Personnages" (app mobile) — Phase 1 — Peuplement du socle.
-- Sous-ensemble de sorts du Manuel des Joueurs : tous les cantrips (niveau
-- 0) des 6 classes qui en disposent, et une sélection large de sorts de
-- niveau 1 couvrant les 8 classes de lanceurs de sorts. Il ne s'agit PAS de
-- la liste exhaustive des ~319 sorts du Manuel des Joueurs : c'est un socle
-- suffisant pour jouer un personnage de niveau 1 à 3-4 (voir 06-roadmap.md,
-- Phase 1 = "MVP restreint"). Compléter la liste jusqu'à l'exhaustivité PHB
-- puis les extensions est un chantier de contenu continu (Phase 5).
--
-- Traduction FR maison de premier jet (voir 07-source-donnees-i18n.md) : les
-- noms de sorts sont une proposition de traduction à relire/ajuster, pas
-- une reprise garantie de la terminologie officielle VF au mot près.
--
-- name/description vivent dans public.translations (migration
-- 20260825090050). `spells.id` étant généré à l'insertion, chaque sort est
-- inséré individuellement dans une boucle PL/pgSQL pour capturer son id via
-- `returning ... into`. L'association spell_classes n'a pas besoin de
-- boucle : elle résout spell_id/class_id par une relecture de
-- public.translations (jointure par nom devenue impossible, `spells.name`
-- et `classes.name` n'existant plus).

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.spells) then
    return;
  end if;

  for rec in
    select * from (values
    -- Cantrips (niveau 0)
    ('Acide fusant', 0, 'Évocation', '1 action', '18 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Vous lancez une bulle d'acide. Faites une attaque à distance contre une ou deux créatures à portée, à moins de 1,50 mètre l'une de l'autre. Une cible touchée subit des dégâts d'acide.$j$, 'Manuel des Joueurs'),
    ('Aide', 0, 'Divination', '1 action', '3 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 minute', true, false, $j$Vous touchez une créature consentante et pouvez, une fois avant la fin du sort, lui faire ajouter 1d4 à un jet de caractéristique ou de sauvegarde de son choix.$j$, 'Manuel des Joueurs'),
    ('Aspersion empoisonnée', 0, 'Évocation', '1 action', '3 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Vous crachez du poison sur une créature à portée, qui doit réussir un jet de sauvegarde de Constitution sous peine de subir des dégâts de poison.$j$, 'Manuel des Joueurs'),
    ('Avertissement occulte', 0, 'Divination', '1 action bonus', 'Personnelle', '{"verbal": true, "somatic": false, "material": false}'::jsonb, 'Jusqu'||chr(39)||'à la fin de votre prochain tour', false, false, $j$Vous obtenez une brève prescience magique. Le prochain jet d'attaque que vous effectuez avant la fin de votre prochain tour bénéficie de l'avantage.$j$, 'Manuel des Joueurs'),
    ('Baguette d''illusion', 0, 'Illusion', '1 action', '9 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, '1 minute', false, false, $j$Vous créez un son ou une image illusoire discrète dans un espace de 1,50 mètre, qui persiste pendant la durée du sort.$j$, 'Manuel des Joueurs'),
    ('Contact glacial', 0, 'Nécromancie', '1 action', '9 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, '1 round', false, false, $j$Une main spectrale glaciale touche une créature, lui infligeant des dégâts nécrotiques et l'empêchant de récupérer des points de vie jusqu'au round suivant.$j$, 'Manuel des Joueurs'),
    ('Création de flamme', 0, 'Évocation', '1 action', '9 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée ou 1 minute', false, false, $j$Une flamme dansante apparaît dans votre main ou attaque une créature à portée, selon l'usage que vous en faites.$j$, 'Manuel des Joueurs'),
    ('Décharge occulte', 0, 'Évocation', '1 action', '36 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Un rai d'énergie crépitante fuse vers une créature à portée. Faites une attaque à distance qui inflige des dégâts de force en cas de réussite.$j$, 'Manuel des Joueurs'),
    ('Défense féerique', 0, 'Abjuration', '1 action bonus', 'Personnelle', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Jusqu'||chr(39)||'à la fin de votre prochain tour', false, false, $j$Une énergie protectrice réduit de moitié les prochains dégâts contondants, perforants ou tranchants que vous subissez.$j$, 'Manuel des Joueurs'),
    ('Druidisme', 0, 'Transmutation', '1 action', 'Personnelle', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Vous produisez un effet naturel mineur et sans danger : faire pousser une petite pousse, purifier de l'eau, créer un bruit naturel, etc.$j$, 'Manuel des Joueurs'),
    ('Épargner les mourants', 0, 'Nécromancie', '1 action', '1,50 mètre', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Vous touchez une créature mourante qui n'a plus de points de vie et la stabilisez immédiatement.$j$, 'Manuel des Joueurs'),
    ('Flamme sacrée', 0, 'Évocation', '1 action', '18 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Une flamme divine s'abat sur une créature à portée, qui doit réussir un jet de sauvegarde de Dextérité sous peine de subir des dégâts radiants.$j$, 'Manuel des Joueurs'),
    ('Fouet d''épines', 0, 'Transmutation', '1 action', '9 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Instantanée', false, false, $j$Une longue liane épineuse jaillit de votre main pour frapper une créature et tenter de la tirer vers vous de 3 mètres.$j$, 'Manuel des Joueurs'),
    ('Lame acérée', 0, 'Évocation', '1 action', 'Contact', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Un éclair de foudre bondit dans votre main pour frapper une créature au contact, lui infligeant des dégâts électriques et l'empêchant de bénéficier de réactions jusqu'au round suivant.$j$, 'Manuel des Joueurs'),
    ('Lueurs dansantes', 0, 'Illusion', '1 action', '36 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 minute', true, false, $j$Vous créez jusqu'à quatre lumières scintillantes de la taille d'une torche que vous déplacez à votre guise dans la zone d'effet.$j$, 'Manuel des Joueurs'),
    ('Lumière', 0, 'Évocation', '1 action', 'Contact', '{"verbal": true, "somatic": false, "material": true}'::jsonb, '1 heure', false, false, $j$Vous touchez un objet qui ne dépasse pas 3 mètres dans aucune dimension : il émet une lumière vive dans un rayon de 6 mètres.$j$, 'Manuel des Joueurs'),
    ('Main du mage', 0, 'Conjuration', '1 action', '9 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, '1 minute', false, false, $j$Une main spectrale apparaît à un point que vous choisissez à portée et peut manipuler des objets, ouvrir des portes ou porter de petits objets.$j$, 'Manuel des Joueurs'),
    ('Message', 0, 'Transmutation', '1 action', '36 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '1 round', false, false, $j$Vous chuchotez un message qu'une créature ciblée entend seule et peut vous répondre à voix basse, audible de vous seul.$j$, 'Manuel des Joueurs'),
    ('Mot moqueur', 0, 'Enchantement', '1 action', '18 mètres', '{"verbal": true, "somatic": false, "material": false}'::jsonb, 'Instantanée', false, false, $j$Vous adressez une insulte magique blessante à une créature qui vous entend, lui infligeant des dégâts psychiques et un désavantage à sa prochaine attaque.$j$, 'Manuel des Joueurs'),
    ('Prestidigitation', 0, 'Transmutation', '1 action', '3 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Jusqu'||chr(39)||'à 1 heure', false, false, $j$Vous produisez un tour de magie mineur : une étincelle, une odeur, un nettoyage ou salissement d'un petit objet, un petit effet sensoriel sans danger.$j$, 'Manuel des Joueurs'),
    ('Rayon de givre', 0, 'Évocation', '1 action', '18 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Un rayon de lumière bleu-blanc fuse vers une créature à portée, infligeant des dégâts de froid et réduisant sa vitesse de 3 mètres jusqu'au round suivant en cas de réussite.$j$, 'Manuel des Joueurs'),
    ('Réparation', 0, 'Transmutation', '1 minute', 'Contact', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Instantanée', false, false, $j$Vous réparez une seule cassure ou déchirure dans un objet que vous touchez, sans laisser de trace de l'ancien dommage.$j$, 'Manuel des Joueurs'),
    ('Résistance', 0, 'Abjuration', '1 action', 'Contact', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 minute', true, false, $j$Vous touchez une créature consentante qui peut ajouter 1d4 à un seul jet de sauvegarde de son choix avant la fin du sort.$j$, 'Manuel des Joueurs'),
    ('Thaumaturgie', 0, 'Divination', '1 action', '9 mètres', '{"verbal": true, "somatic": false, "material": false}'::jsonb, 'Jusqu'||chr(39)||'à 1 minute', false, false, $j$Vous manifestez un signe mineur de pouvoir surnaturel : voix tonitruante, tremblement du sol, flammes vacillantes, etc.$j$, 'Manuel des Joueurs'),
    ('Trait de feu', 0, 'Évocation', '1 action', '36 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Vous lancez une flèche de feu sur une créature à portée. En cas de réussite, elle subit des dégâts de feu, et les objets inflammables non portés qu'elle transporte s'enflamment.$j$, 'Manuel des Joueurs'),
    ('Trique noueuse', 0, 'Transmutation', '1 action bonus', 'Personnelle', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Instantanée', false, false, $j$Le bois d'un gourdin ou d'un bâton que vous portez s'anime de puissance naturelle, utilisant votre Sagesse au lieu de votre Force pour les jets d'attaque et de dégâts, avec des dégâts augmentés.$j$, 'Manuel des Joueurs'),
    -- Niveau 1
    ('Alarme', 1, 'Abjuration', '1 minute', '9 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '8 heures', false, true, $j$Vous établissez une alarme magique sur une zone contre les intrusions, qui vous alerte mentalement ou audiblement selon votre choix.$j$, 'Manuel des Joueurs'),
    ('Armure de mage', 1, 'Abjuration', '1 action', 'Contact', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '8 heures', false, false, $j$Vous touchez une créature non protégée par une armure : sa Classe d'Armure de base devient 13 + son modificateur de Dextérité pour la durée du sort.$j$, 'Manuel des Joueurs'),
    ('Bénédiction', 1, 'Enchantement', '1 action', '9 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 minute', true, false, $j$Vous bénissez jusqu'à trois créatures à portée, qui ajoutent 1d4 à leurs prochains jets d'attaque et de sauvegarde.$j$, 'Manuel des Joueurs'),
    ('Bouclier', 1, 'Abjuration', '1 réaction', 'Personnelle', '{"verbal": true, "somatic": true, "material": false}'::jsonb, '1 round', false, false, $j$Une barrière de force invisible vous protège, augmentant votre Classe d'Armure de 5 jusqu'au début de votre prochain tour, y compris contre l'attaque qui a déclenché le sort.$j$, 'Manuel des Joueurs'),
    ('Bouclier de la foi', 1, 'Abjuration', '1 action bonus', '18 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 10 minutes', true, false, $j$Un champ de force scintillant entoure une créature à portée, lui accordant un bonus de +2 à la Classe d'Armure pendant la durée du sort.$j$, 'Manuel des Joueurs'),
    ('Charme-personne', 1, 'Enchantement', '1 action', '9 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, '1 heure', false, false, $j$Vous tentez de charmer un humanoïde que vous pouvez voir à portée, qui doit réussir un jet de sauvegarde de Sagesse sous peine d'être charmé.$j$, 'Manuel des Joueurs'),
    ('Compréhension des langues', 1, 'Divination', '1 action', 'Personnelle', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '1 heure', false, true, $j$Pendant la durée du sort, vous comprenez le sens littéral de tout langage parlé que vous entendez, et tout texte écrit que vous voyez.$j$, 'Manuel des Joueurs'),
    ('Déguisement', 1, 'Illusion', '1 action', 'Personnelle', '{"verbal": true, "somatic": true, "material": false}'::jsonb, '1 heure', false, false, $j$Vous modifiez votre apparence, y compris vos vêtements et votre équipement, jusqu'à la fin du sort ou jusqu'à ce que vous l'interrompiez.$j$, 'Manuel des Joueurs'),
    ('Détection de la magie', 1, 'Divination', '1 action', 'Personnelle', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 10 minutes', true, true, $j$Pendant la durée du sort, vous percevez la présence de magie dans un rayon de 9 mètres autour de vous.$j$, 'Manuel des Joueurs'),
    ('Détection du mal et du bien', 1, 'Divination', '1 action', 'Personnelle', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 10 minutes', true, false, $j$Vous percevez la présence et la localisation de célestes, d'êtres-fées, de fiélons, d'élémentaires, de morts-vivants, ou de tout lieu, objet ou créature consacré ou souillé, dans un rayon de 9 mètres.$j$, 'Manuel des Joueurs'),
    ('Feu follet', 1, 'Évocation', '1 action', '18 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 minute', true, false, $j$Un contour scintillant révèle une créature qui échoue à un jet de sauvegarde de Dextérité, accordant l'avantage à tous les jets d'attaque contre elle.$j$, 'Manuel des Joueurs'),
    ('Flétrissure', 1, 'Enchantement', '1 action', '9 mètres', '{"verbal": true, "somatic": false, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 minute', true, false, $j$Vous maudissez jusqu'à trois créatures à portée, qui doivent soustraire 1d4 de leurs prochains jets d'attaque et de sauvegarde.$j$, 'Manuel des Joueurs'),
    ('Identification', 1, 'Divination', '1 minute', 'Contact', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Instantanée', false, true, $j$Vous découvrez les propriétés magiques d'un objet touché, y compris son mode d'activation et le nombre de charges restantes.$j$, 'Manuel des Joueurs'),
    ('Chute plume', 1, 'Transmutation', '1 réaction', '18 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, '1 minute', false, false, $j$Vous choisissez jusqu'à cinq créatures en chute libre à portée : leur vitesse de chute ralentit à 18 mètres par round jusqu'à la fin du sort.$j$, 'Manuel des Joueurs'),
    ('Marque du chasseur', 1, 'Divination', '1 action bonus', '27 mètres', '{"verbal": true, "somatic": false, "material": false}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 heure', true, false, $j$Vous marquez magiquement une créature comme votre proie, infligeant des dégâts supplémentaires à chacune de vos attaques contre elle.$j$, 'Manuel des Joueurs'),
    ('Mot de guérison', 1, 'Évocation', '1 action bonus', '18 mètres', '{"verbal": true, "somatic": false, "material": false}'::jsonb, 'Instantanée', false, false, $j$Une créature de votre choix à portée que vous pouvez voir recouvre 1d4 points de vie, plus votre modificateur de caractéristique d'incantation.$j$, 'Manuel des Joueurs'),
    ('Murmures dissonants', 1, 'Enchantement', '1 action', '18 mètres', '{"verbal": true, "somatic": false, "material": false}'::jsonb, 'Instantanée', false, false, $j$Vous chuchotez une mélodie discordante qu'une seule créature entend, lui infligeant des dégâts psychiques et l'obligeant à fuir si elle échoue à son jet de sauvegarde.$j$, 'Manuel des Joueurs'),
    ('Parole avec les animaux', 1, 'Divination', '1 action', 'Personnelle', '{"verbal": true, "somatic": true, "material": false}'::jsonb, '10 minutes', false, true, $j$Vous gagnez la capacité de comprendre les bêtes et de communiquer avec elles verbalement pendant la durée du sort.$j$, 'Manuel des Joueurs'),
    ('Projectile magique', 1, 'Évocation', '1 action', '36 mètres', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Vous créez trois fléchettes d'énergie magique scintillante. Chacune touche automatiquement une créature de votre choix à portée et inflige des dégâts de force.$j$, 'Manuel des Joueurs'),
    ('Protection contre le mal et le bien', 1, 'Abjuration', '1 action', 'Contact', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 10 minutes', true, false, $j$Vous protégez une créature consentante contre certains types de créatures : célestes, élémentaires, fiélons, êtres-fées ou morts-vivants.$j$, 'Manuel des Joueurs'),
    ('Rire hideux de Tasha', 1, 'Enchantement', '1 action', '9 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 minute', true, false, $j$Une créature de votre choix est submergée par une hilarité incontrôlable, échouant à un jet de sauvegarde de Sagesse sous peine de tomber à terre en état d'incapacité.$j$, 'Manuel des Joueurs'),
    ('Sanctuaire', 1, 'Abjuration', '1 action bonus', '9 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '1 minute', false, false, $j$Vous protégez magiquement une créature : tout adversaire qui vise cette créature avec une attaque ou un sort néfaste doit d'abord réussir un jet de sauvegarde de Sagesse.$j$, 'Manuel des Joueurs'),
    ('Serviteur invisible', 1, 'Conjuration', '1 action', 'Personnelle', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '1 heure', false, false, $j$Vous créez une force invisible et sans intelligence qui effectue de simples tâches sur votre ordre pendant la durée du sort.$j$, 'Manuel des Joueurs'),
    ('Soins', 1, 'Évocation', '1 action', 'Contact', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Une créature que vous touchez recouvre un nombre de points de vie égal à 1d8 plus votre modificateur de caractéristique d'incantation.$j$, 'Manuel des Joueurs'),
    ('Sommeil', 1, 'Enchantement', '1 action', '27 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '1 minute', false, false, $j$Ce sort plonge des créatures dans un sommeil magique, en commençant par celles ayant le moins de points de vie actuels, dans un rayon de 6 mètres autour d'un point que vous choisissez.$j$, 'Manuel des Joueurs'),
    ('Vague tonnerre', 1, 'Évocation', '1 action', 'Personnelle (cube de 4,50 mètres)', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Instantanée', false, false, $j$Une onde d'énergie tonitruante balaie une zone devant vous, infligeant des dégâts de fracas et repoussant les créatures qui échouent à leur jet de sauvegarde.$j$, 'Manuel des Joueurs'),
    ('Vaillance', 1, 'Enchantement', '1 action', 'Contact', '{"verbal": true, "somatic": true, "material": false}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 1 minute', true, false, $j$Une créature consentante que vous touchez est emplie de bravoure, gagnant des points de vie temporaires au début du sort et à chacun de vos tours suivants.$j$, 'Manuel des Joueurs'),
    ('Vitesse supérieure', 1, 'Transmutation', '1 action', 'Contact', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '1 heure', false, false, $j$La vitesse d'une créature que vous touchez augmente de 3 mètres pour la durée du sort.$j$, 'Manuel des Joueurs'),
    ('Écriture illusoire', 1, 'Illusion', '1 minute', 'Contact', '{"verbal": false, "somatic": true, "material": true}'::jsonb, '10 jours', false, false, $j$Vous écrivez sur un parchemin ou un support similaire un texte qui apparaît différent à quiconque ne dispose pas de la clé de lecture que vous définissez.$j$, 'Manuel des Joueurs'),
    ('Image silencieuse', 1, 'Illusion', '1 action', '18 mètres', '{"verbal": true, "somatic": true, "material": true}'::jsonb, 'Concentration, jusqu'||chr(39)||'à 10 minutes', true, false, $j$Vous créez l'image d'un objet, d'une créature ou d'un autre phénomène visible dans un cube de 4,50 mètres, sans effet sonore.$j$, 'Manuel des Joueurs'),
    ('Bond', 1, 'Transmutation', '1 action', 'Contact', '{"verbal": true, "somatic": true, "material": true}'::jsonb, '1 minute', false, false, $j$Vous touchez une créature dont la distance de saut est triplée pour la durée du sort.$j$, 'Manuel des Joueurs')
    ) as t(name, level, school, casting_time, range, components, duration, concentration, ritual, description, source)
  loop
    insert into public.spells (level, school, casting_time, range, components, duration, concentration, ritual, source)
      values (rec.level, rec.school, rec.casting_time, rec.range, rec.components, rec.duration, rec.concentration, rec.ritual, rec.source)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('spell', v_id::text, 'name', 'fr', rec.name),
      ('spell', v_id::text, 'description', 'fr', rec.description);
  end loop;
end $$;

-- Association sorts <-> classes pouvant les apprendre/préparer.
insert into public.spell_classes (spell_id, class_id)
select sp.id, c.id
from (values
  ('Acide fusant', 'Magicien'), ('Acide fusant', 'Ensorceleur'),
  ('Aide', 'Clerc'), ('Aide', 'Druide'),
  ('Aspersion empoisonnée', 'Druide'), ('Aspersion empoisonnée', 'Ensorceleur'), ('Aspersion empoisonnée', 'Occultiste'), ('Aspersion empoisonnée', 'Magicien'),
  ('Avertissement occulte', 'Barde'), ('Avertissement occulte', 'Ensorceleur'), ('Avertissement occulte', 'Occultiste'), ('Avertissement occulte', 'Magicien'),
  ('Baguette d''illusion', 'Barde'), ('Baguette d''illusion', 'Ensorceleur'), ('Baguette d''illusion', 'Occultiste'), ('Baguette d''illusion', 'Magicien'),
  ('Contact glacial', 'Ensorceleur'), ('Contact glacial', 'Occultiste'), ('Contact glacial', 'Magicien'),
  ('Création de flamme', 'Druide'),
  ('Décharge occulte', 'Occultiste'),
  ('Défense féerique', 'Barde'), ('Défense féerique', 'Ensorceleur'), ('Défense féerique', 'Occultiste'), ('Défense féerique', 'Magicien'),
  ('Druidisme', 'Druide'),
  ('Épargner les mourants', 'Clerc'),
  ('Flamme sacrée', 'Clerc'),
  ('Fouet d''épines', 'Druide'),
  ('Lame acérée', 'Ensorceleur'), ('Lame acérée', 'Magicien'),
  ('Lueurs dansantes', 'Barde'), ('Lueurs dansantes', 'Ensorceleur'), ('Lueurs dansantes', 'Occultiste'), ('Lueurs dansantes', 'Magicien'),
  ('Lumière', 'Barde'), ('Lumière', 'Clerc'), ('Lumière', 'Ensorceleur'), ('Lumière', 'Occultiste'), ('Lumière', 'Magicien'),
  ('Main du mage', 'Barde'), ('Main du mage', 'Ensorceleur'), ('Main du mage', 'Occultiste'), ('Main du mage', 'Magicien'),
  ('Message', 'Barde'), ('Message', 'Ensorceleur'), ('Message', 'Occultiste'), ('Message', 'Magicien'),
  ('Mot moqueur', 'Barde'),
  ('Prestidigitation', 'Barde'), ('Prestidigitation', 'Ensorceleur'), ('Prestidigitation', 'Occultiste'), ('Prestidigitation', 'Magicien'),
  ('Rayon de givre', 'Ensorceleur'), ('Rayon de givre', 'Magicien'),
  ('Réparation', 'Barde'), ('Réparation', 'Clerc'), ('Réparation', 'Druide'), ('Réparation', 'Ensorceleur'), ('Réparation', 'Occultiste'), ('Réparation', 'Magicien'),
  ('Résistance', 'Clerc'), ('Résistance', 'Druide'),
  ('Thaumaturgie', 'Clerc'),
  ('Trait de feu', 'Ensorceleur'), ('Trait de feu', 'Magicien'),
  ('Trique noueuse', 'Druide'),

  ('Alarme', 'Rôdeur'), ('Alarme', 'Magicien'),
  ('Armure de mage', 'Ensorceleur'), ('Armure de mage', 'Occultiste'), ('Armure de mage', 'Magicien'),
  ('Bénédiction', 'Clerc'), ('Bénédiction', 'Paladin'),
  ('Bouclier', 'Ensorceleur'), ('Bouclier', 'Magicien'),
  ('Bouclier de la foi', 'Clerc'), ('Bouclier de la foi', 'Paladin'),
  ('Charme-personne', 'Barde'), ('Charme-personne', 'Druide'), ('Charme-personne', 'Occultiste'), ('Charme-personne', 'Magicien'), ('Charme-personne', 'Ensorceleur'),
  ('Compréhension des langues', 'Barde'), ('Compréhension des langues', 'Clerc'), ('Compréhension des langues', 'Occultiste'), ('Compréhension des langues', 'Magicien'),
  ('Déguisement', 'Barde'), ('Déguisement', 'Occultiste'), ('Déguisement', 'Magicien'), ('Déguisement', 'Ensorceleur'),
  ('Détection de la magie', 'Barde'), ('Détection de la magie', 'Clerc'), ('Détection de la magie', 'Druide'), ('Détection de la magie', 'Paladin'), ('Détection de la magie', 'Rôdeur'), ('Détection de la magie', 'Occultiste'), ('Détection de la magie', 'Magicien'), ('Détection de la magie', 'Ensorceleur'),
  ('Détection du mal et du bien', 'Clerc'), ('Détection du mal et du bien', 'Paladin'),
  ('Feu follet', 'Druide'),
  ('Flétrissure', 'Barde'), ('Flétrissure', 'Clerc'),
  ('Identification', 'Barde'), ('Identification', 'Occultiste'), ('Identification', 'Magicien'),
  ('Chute plume', 'Barde'), ('Chute plume', 'Occultiste'), ('Chute plume', 'Magicien'), ('Chute plume', 'Ensorceleur'),
  ('Marque du chasseur', 'Rôdeur'),
  ('Mot de guérison', 'Barde'), ('Mot de guérison', 'Clerc'), ('Mot de guérison', 'Druide'),
  ('Murmures dissonants', 'Barde'),
  ('Parole avec les animaux', 'Barde'), ('Parole avec les animaux', 'Druide'), ('Parole avec les animaux', 'Rôdeur'),
  ('Projectile magique', 'Ensorceleur'), ('Projectile magique', 'Magicien'),
  ('Protection contre le mal et le bien', 'Clerc'), ('Protection contre le mal et le bien', 'Paladin'), ('Protection contre le mal et le bien', 'Occultiste'), ('Protection contre le mal et le bien', 'Magicien'),
  ('Rire hideux de Tasha', 'Barde'), ('Rire hideux de Tasha', 'Magicien'), ('Rire hideux de Tasha', 'Ensorceleur'),
  ('Sanctuaire', 'Clerc'),
  ('Serviteur invisible', 'Occultiste'), ('Serviteur invisible', 'Magicien'),
  ('Soins', 'Barde'), ('Soins', 'Clerc'), ('Soins', 'Druide'), ('Soins', 'Paladin'), ('Soins', 'Rôdeur'),
  ('Sommeil', 'Barde'), ('Sommeil', 'Occultiste'), ('Sommeil', 'Magicien'), ('Sommeil', 'Ensorceleur'),
  ('Vague tonnerre', 'Druide'), ('Vague tonnerre', 'Occultiste'), ('Vague tonnerre', 'Magicien'), ('Vague tonnerre', 'Ensorceleur'),
  ('Vaillance', 'Barde'), ('Vaillance', 'Paladin'),
  ('Vitesse supérieure', 'Barde'), ('Vitesse supérieure', 'Druide'), ('Vitesse supérieure', 'Rôdeur'), ('Vitesse supérieure', 'Occultiste'), ('Vitesse supérieure', 'Magicien'),
  ('Écriture illusoire', 'Barde'), ('Écriture illusoire', 'Occultiste'), ('Écriture illusoire', 'Magicien'),
  ('Image silencieuse', 'Barde'), ('Image silencieuse', 'Occultiste'), ('Image silencieuse', 'Magicien'), ('Image silencieuse', 'Ensorceleur'),
  ('Bond', 'Druide'), ('Bond', 'Rôdeur'), ('Bond', 'Occultiste'), ('Bond', 'Magicien'), ('Bond', 'Ensorceleur')
) as link(spell_name, class_name)
join public.translations spt
  on spt.entity_type = 'spell' and spt.field_name = 'name' and spt.locale = 'fr'
  and spt.value = link.spell_name
join public.spells sp on sp.id::text = spt.entity_id
join public.translations ct
  on ct.entity_type = 'class' and ct.field_name = 'name' and ct.locale = 'fr'
  and ct.value = link.class_name
join public.classes c on c.id::text = ct.entity_id
where not exists (select 1 from public.spell_classes);
