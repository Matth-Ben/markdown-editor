-- Lot 3 de l'import du contenu de référence : dons et manifestations occultes manquants.
--
-- * Faveurs épiques (dons de niveau 19+) : les 7 du SRD 5.2 (CC-BY-4.0, « System Reference
--   Document 5.2 » de Wizards of the Coast LLC, https://creativecommons.org/licenses/by/4.0/),
--   traduites ; les 5 autres du Manuel des Joueurs (2024) en texte reformulé.
-- * Dons du Guide de Xanathar (dons raciaux) et du Chaudron de Tasha : texte reformulé.
-- * Manifestations occultes du Guide de Xanathar et du Chaudron de Tasha : texte reformulé.
--
-- Idempotente : chaque entrée n'est insérée que si son nom FR n'existe pas déjà.
-- Les dons existants (PHB 2014) ne sont pas modifiés.

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
  -- Faveurs épiques — SRD 5.2
  ($t$Faveur de prouesse martiale$t$, $t$Boon of Combat Prowess$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Lorsque vous ratez un jet d'attaque, vous pouvez décider de toucher à la place. Une fois ce bénéfice utilisé, vous ne pouvez plus l'utiliser avant le début de votre prochain tour.$t$),
  ($t$Faveur de voyage dimensionnel$t$, $t$Boon of Dimensional Travel$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Immédiatement après avoir effectué l'action Attaque ou l'action Magie, vous pouvez vous téléporter jusqu'à 9 m dans un espace inoccupé que vous voyez.$t$),
  ($t$Faveur du destin$t$, $t$Boon of Fate$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Lorsque vous ou une autre créature située à 18 m ou moins de vous réussissez ou ratez un test de d20, vous pouvez lancer 2d4 et appliquer le total en bonus ou en malus au résultat du d20. Une fois ce bénéfice utilisé, vous ne pouvez plus l'utiliser avant de lancer l'initiative ou de terminer un repos court ou long.$t$),
  ($t$Faveur d'offensive irrésistible$t$, $t$Boon of Irresistible Offense$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Les dégâts contondants, perforants et tranchants que vous infligez ignorent toujours la résistance. Lorsque vous obtenez 20 au d20 d'un jet d'attaque, vous pouvez infliger à la cible des dégâts supplémentaires égaux à la valeur de la caractéristique augmentée par ce don, du même type que ceux de l'attaque.$t$),
  ($t$Faveur de rappel des sorts$t$, $t$Boon of Spell Recall$t$, $t${"text":"Niveau 19, aptitude Incantation (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Chaque fois que vous lancez un sort avec un emplacement de niveau 1 à 4, lancez 1d4 : si le résultat est égal au niveau de l'emplacement, celui-ci n'est pas dépensé.$t$),
  ($t$Faveur de l'esprit nocturne$t$, $t$Boon of the Night Spirit$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Tant que vous êtes dans une zone de lumière faible ou d'obscurité, vous pouvez, par une action bonus, vous rendre invisible ; cet état prend fin immédiatement après que vous avez effectué une action, une action bonus ou une réaction. Dans ces mêmes conditions, vous avez la résistance à tous les dégâts, sauf psychiques et radiants.$t$),
  ($t$Faveur de vision véritable$t$, $t$Boon of Truesight$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Vous bénéficiez de la vision véritable dans un rayon de 18 m.$t$),
  -- Faveurs épiques — Manuel des Joueurs (2024), texte reformulé
  ($t$Faveur de résistance énergétique$t$, $t$Boon of Energy Resistance$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Choisissez deux types de dégâts parmi acide, feu, froid, force, foudre, nécrotique, poison, psychique, radiant et tonnerre : vous obtenez la résistance à ces types (vous pouvez changer ce choix à la fin d'un repos long). Lorsque vous subissez des dégâts de l'un de ces types, vous pouvez utiliser votre réaction pour obliger une créature que vous voyez à 18 m ou moins à réussir un jet de sauvegarde de Dextérité (DD 8 + modificateur de la caractéristique augmentée + bonus de maîtrise) ou subir 2d12 dégâts de ce type.$t$),
  ($t$Faveur de robustesse$t$, $t$Boon of Fortitude$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Votre maximum de points de vie augmente de 40. Lorsque vous récupérez des points de vie, vous pouvez en récupérer un nombre supplémentaire égal à votre modificateur de Constitution ; une fois ce bénéfice utilisé, il faut attendre le début de votre prochain tour pour le réutiliser.$t$),
  ($t$Faveur de récupération$t$, $t$Boon of Recovery$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Lorsque vous tombez à 0 point de vie sans être tué sur le coup, vous pouvez tomber à 1 point de vie et récupérer immédiatement la moitié de votre maximum de points de vie (une fois par repos long). Vous disposez en outre d'une réserve de dix d10 : par une action bonus, vous pouvez en dépenser autant que vous le souhaitez et récupérer le total obtenu en points de vie ; les dés dépensés reviennent à la fin d'un repos long.$t$),
  ($t$Faveur de compétence$t$, $t$Boon of Skill$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Vous obtenez la maîtrise de toutes les compétences, ainsi que l'expertise dans une compétence de votre choix (votre bonus de maîtrise est doublé pour les tests qui l'utilisent).$t$),
  ($t$Faveur de célérité$t$, $t$Boon of Speed$t$, $t${"text":"Niveau 19 (Faveur épique)","level":19}$t$::jsonb,
   $t$Faveur épique. Augmentez une valeur de caractéristique de votre choix de 1, jusqu'à un maximum de 30. Votre vitesse augmente de 9 m. Par une action bonus, vous pouvez effectuer l'action Désengagement, qui met aussi fin à l'état empoigné qui vous affecte ; une fois ce bénéfice utilisé, il faut attendre le début de votre prochain tour pour le réutiliser.$t$),
  -- Guide de Xanathar — dons raciaux, texte reformulé
  ($t$Chance généreuse$t$, $t$Bountiful Luck$t$, $t${"text":"Halfelin"}$t$::jsonb,
   $t$Lorsqu'un allié que vous voyez à 9 m ou moins obtient 1 au d20 d'un jet d'attaque, d'un test de caractéristique ou d'un jet de sauvegarde, vous pouvez utiliser votre réaction pour lui permettre de relancer le dé ; il doit garder le nouveau résultat. Vous ne pouvez pas utiliser votre trait Chanceux avant la fin de votre prochain tour lorsque vous faites ainsi.$t$),
  ($t$Terreur draconique$t$, $t$Dragon Fear$t$, $t${"text":"Drakéide"}$t$::jsonb,
   $t$Force, Constitution ou Charisme +1 (max. 20). Au lieu d'exhaler votre souffle, vous pouvez dépenser cette utilisation pour pousser un rugissement : chaque créature de votre choix à 9 m ou moins doit réussir un jet de sauvegarde de Sagesse (DD 8 + modificateur de Charisme + bonus de maîtrise) ou être effrayée par vous pendant 1 minute. Elle peut refaire le jet de sauvegarde chaque fois qu'elle subit des dégâts.$t$),
  ($t$Peau de dragon$t$, $t$Dragon Hide$t$, $t${"text":"Drakéide"}$t$::jsonb,
   $t$Force, Constitution ou Charisme +1 (max. 20). Vos écailles se durcissent : sans armure, votre CA est égale à 13 + votre modificateur de Dextérité (un bouclier reste utilisable). Vous poussez aussi des griffes rétractiles, qui sont des armes naturelles infligeant 1d4 + modificateur de Force dégâts tranchants lors de vos attaques à mains nues.$t$),
  ($t$Haute magie drow$t$, $t$Drow High Magic$t$, $t${"text":"Elfe (drow)"}$t$::jsonb,
   $t$Vous apprenez des sorts drows supplémentaires. Vous pouvez lancer Détection de la magie à volonté, sans dépenser d'emplacement. Vous pouvez aussi lancer Lévitation et Dissipation de la magie une fois chacun sans emplacement, et récupérez ces utilisations à la fin d'un repos long. Le Charisme est votre caractéristique d'incantation pour ces sorts.$t$),
  ($t$Robustesse naine$t$, $t$Dwarven Fortitude$t$, $t${"text":"Nain"}$t$::jsonb,
   $t$Constitution +1 (max. 20). Lorsque vous effectuez l'action Esquiver pendant votre tour, vous pouvez dépenser un dé de vie pour récupérer des points de vie : lancez-le et ajoutez votre modificateur de Constitution (minimum 1).$t$),
  ($t$Précision elfique$t$, $t$Elven Accuracy$t$, $t${"text":"Elfe ou demi-elfe"}$t$::jsonb,
   $t$Dextérité, Intelligence, Sagesse ou Charisme +1 (max. 20). Lorsque vous avez l'avantage à un jet d'attaque basé sur la Dextérité, l'Intelligence, la Sagesse ou le Charisme, vous pouvez relancer l'un des dés une fois.$t$),
  ($t$Évanescence$t$, $t$Fade Away$t$, $t${"text":"Gnome"}$t$::jsonb,
   $t$Dextérité ou Intelligence +1 (max. 20). Immédiatement après avoir subi des dégâts, vous pouvez utiliser votre réaction pour devenir invisible par magie jusqu'à la fin de votre prochain tour, ou jusqu'à ce que vous attaquiez, infligiez des dégâts ou forciez quelqu'un à faire un jet de sauvegarde. Vous récupérez cette capacité à la fin d'un repos court ou long.$t$),
  ($t$Téléportation féerique$t$, $t$Fey Teleportation$t$, $t${"text":"Elfe (haut-elfe)"}$t$::jsonb,
   $t$Intelligence ou Charisme +1 (max. 20). Vous apprenez à parler, lire et écrire le sylvestre. Vous pouvez lancer Pas brumeux une fois sans dépenser d'emplacement et récupérez cette utilisation à la fin d'un repos court ou long ; l'Intelligence est votre caractéristique d'incantation pour ce sort.$t$),
  ($t$Flammes de Phlégéthos$t$, $t$Flames of Phlegethos$t$, $t${"text":"Tieffelin"}$t$::jsonb,
   $t$Intelligence ou Charisme +1 (max. 20). Lorsque vous lancez les dégâts de feu d'un sort que vous lancez, vous pouvez relancer les 1, mais devez garder le nouveau résultat. Lorsque vous lancez un sort qui inflige des dégâts de feu, vous pouvez vous envelopper de flammes jusqu'à la fin de votre prochain tour : elles émettent une lumière vive sur 9 m et une créature qui vous touche avec une attaque au corps à corps à 1,50 m ou moins subit 1d4 dégâts de feu.$t$),
  ($t$Constitution infernale$t$, $t$Infernal Constitution$t$, $t${"text":"Tieffelin"}$t$::jsonb,
   $t$Constitution +1 (max. 20). Vous obtenez la résistance aux dégâts de froid et de poison, et vous avez l'avantage aux jets de sauvegarde contre l'état empoisonné.$t$),
  ($t$Fureur orque$t$, $t$Orcish Fury$t$, $t${"text":"Demi-orc"}$t$::jsonb,
   $t$Force ou Constitution +1 (max. 20). Lorsque vous touchez avec une arme simple ou de guerre, vous pouvez lancer un dé de dégâts supplémentaire de l'arme et l'ajouter aux dégâts ; vous récupérez cette capacité à la fin d'un repos court ou long. De plus, immédiatement après avoir utilisé votre trait Endurance implacable, vous pouvez utiliser votre réaction pour porter une attaque avec une arme.$t$),
  ($t$Prodige$t$, $t$Prodigy$t$, $t${"text":"Demi-elfe, demi-orc ou humain"}$t$::jsonb,
   $t$Vous obtenez la maîtrise d'une compétence, d'un outil et d'une langue de votre choix. Choisissez aussi une compétence que vous maîtrisez : vous obtenez l'expertise dans celle-ci (votre bonus de maîtrise est doublé pour les tests qui l'utilisent).$t$),
  ($t$Seconde chance$t$, $t$Second Chance$t$, $t${"text":"Halfelin"}$t$::jsonb,
   $t$Dextérité, Constitution ou Charisme +1 (max. 20). Lorsqu'une créature que vous voyez vous touche avec un jet d'attaque, vous pouvez utiliser votre réaction pour l'obliger à relancer ce jet. Vous récupérez cette capacité lorsque vous lancez l'initiative ou à la fin d'un repos court ou long.$t$),
  ($t$Agilité trapue$t$, $t$Squat Nimbleness$t$, $t${"text":"Nain ou créature de taille P"}$t$::jsonb,
   $t$Force ou Dextérité +1 (max. 20). Votre vitesse augmente de 1,50 m. Vous obtenez la maîtrise de l'Acrobatie ou de l'Athlétisme, et vous avez l'avantage aux tests de Force (Athlétisme) ou de Dextérité (Acrobaties) effectués pour échapper à une empoignade.$t$),
  ($t$Magie des elfes sylvains$t$, $t$Wood Elf Magic$t$, $t${"text":"Elfe (elfe sylvain)"}$t$::jsonb,
   $t$Vous apprenez un sort mineur de druide de votre choix. Vous apprenez aussi Grande foulée et Passage sans trace, que vous pouvez lancer chacun une fois sans dépenser d'emplacement ; ces utilisations reviennent à la fin d'un repos long. La Sagesse est votre caractéristique d'incantation pour ces sorts.$t$),
  -- Chaudron de Tasha — texte reformulé
  ($t$Initié artificier$t$, $t$Artificer Initiate$t$, $t${}$t$::jsonb,
   $t$Vous apprenez un sort mineur de la liste de l'artificier et un sort de niveau 1 de cette liste, que vous pouvez lancer une fois sans emplacement (utilisation récupérée après un repos long) ou avec vos emplacements. L'Intelligence est votre caractéristique d'incantation pour ces sorts. Vous obtenez aussi la maîtrise d'un type d'outils d'artisan de votre choix, que vous pouvez utiliser comme focaliseur pour ces sorts.$t$),
  ($t$Chef$t$, $t$Chef$t$, $t${}$t$::jsonb,
   $t$Constitution ou Sagesse +1 (max. 20). Vous obtenez la maîtrise des ustensiles de cuisinier. Pendant un repos court, vous pouvez préparer un plat pour jusqu'à 4 + bonus de maîtrise créatures : chacune regagne 1d8 points de vie supplémentaires si elle dépense des dés de vie. En 1 heure (ou pendant un repos long), vous pouvez aussi préparer autant de friandises que votre bonus de maîtrise ; manger une friandise par une action bonus confère un nombre de points de vie temporaires égal à votre bonus de maîtrise.$t$),
  ($t$Écraseur$t$, $t$Crusher$t$, $t${}$t$::jsonb,
   $t$Force ou Constitution +1 (max. 20). Une fois par tour, lorsque vous touchez une créature avec une attaque infligeant des dégâts contondants, vous pouvez la déplacer de 1,50 m dans un espace inoccupé, si elle n'est pas plus d'une catégorie de taille au-dessus de la vôtre. Lorsque vous réussissez un coup critique infligeant des dégâts contondants, les jets d'attaque contre cette créature ont l'avantage jusqu'au début de votre prochain tour.$t$),
  ($t$Adepte occulte$t$, $t$Eldritch Adept$t$, $t${"text":"Aptitude Incantation ou Magie de pacte"}$t$::jsonb,
   $t$Vous apprenez une manifestation occulte d'occultiste de votre choix. Si elle a un prérequis, vous ne pouvez la choisir que si vous êtes occultiste et remplissez ce prérequis. Chaque fois que vous gagnez un niveau, vous pouvez la remplacer par une autre.$t$),
  ($t$Touché par les fées$t$, $t$Fey Touched$t$, $t${}$t$::jsonb,
   $t$Intelligence, Sagesse ou Charisme +1 (max. 20). Vous apprenez Pas brumeux et un sort de niveau 1 de divination ou d'enchantement de votre choix. Vous pouvez lancer chacun d'eux une fois sans emplacement (utilisation récupérée après un repos long) ou avec vos emplacements. La caractéristique augmentée par ce don est votre caractéristique d'incantation pour ces sorts.$t$),
  ($t$Initié au combat$t$, $t$Fighting Initiate$t$, $t${"text":"Maîtrise d'une arme de guerre"}$t$::jsonb,
   $t$Vous apprenez un style de combat de votre choix parmi ceux du guerrier. Si vous avez déjà un style, celui-ci doit être différent. Chaque fois que vous gagnez un niveau vous donnant une aptitude Amélioration de caractéristique, vous pouvez remplacer ce style par un autre.$t$),
  ($t$Artilleur$t$, $t$Gunner$t$, $t${}$t$::jsonb,
   $t$Dextérité +1 (max. 20). Vous obtenez la maîtrise des armes à feu. Vous ignorez la propriété de chargement des armes à feu, et attaquer à distance alors qu'un ennemi se trouve à 1,50 m ou moins ne vous impose pas le désavantage.$t$),
  ($t$Adepte de la métamagie$t$, $t$Metamagic Adept$t$, $t${"text":"Aptitude Incantation ou Magie de pacte"}$t$::jsonb,
   $t$Vous apprenez deux options de Métamagie de votre choix parmi celles de l'ensorceleur ; vous ne pouvez en utiliser qu'une par sort, sauf indication contraire. Vous obtenez 2 points de sorcellerie à dépenser pour la Métamagie (ils s'ajoutent à ceux que vous pourriez avoir par ailleurs) et les récupérez à la fin d'un repos long. Chaque fois que vous gagnez un niveau vous donnant une aptitude Amélioration de caractéristique, vous pouvez remplacer une de ces options.$t$),
  ($t$Perforateur$t$, $t$Piercer$t$, $t${}$t$::jsonb,
   $t$Force ou Dextérité +1 (max. 20). Une fois par tour, lorsque vous touchez une créature avec une attaque infligeant des dégâts perforants, vous pouvez relancer un des dés de dégâts et garder le nouveau résultat. Lorsque vous réussissez un coup critique infligeant des dégâts perforants, vous pouvez lancer un dé de dégâts supplémentaire.$t$),
  ($t$Empoisonneur$t$, $t$Poisoner$t$, $t${}$t$::jsonb,
   $t$Vos jets de dégâts ignorent la résistance aux dégâts de poison. Vous pouvez enduire une arme ou une munition de poison par une action bonus au lieu d'une action. Vous obtenez la maîtrise du kit d'empoisonneur et, en 1 heure de travail avec 50 po de matériel, pouvez fabriquer autant de doses de poison que votre bonus de maîtrise : une créature touchée par l'arme empoisonnée doit réussir un jet de sauvegarde de Constitution DD 14 ou subir 2d8 dégâts de poison et être empoisonnée jusqu'à la fin de votre prochain tour.$t$),
  ($t$Touché par l'ombre$t$, $t$Shadow Touched$t$, $t${}$t$::jsonb,
   $t$Intelligence, Sagesse ou Charisme +1 (max. 20). Vous apprenez Invisibilité et un sort de niveau 1 d'illusion ou de nécromancie de votre choix. Vous pouvez lancer chacun d'eux une fois sans emplacement (utilisation récupérée après un repos long) ou avec vos emplacements. La caractéristique augmentée par ce don est votre caractéristique d'incantation pour ces sorts.$t$),
  ($t$Expert en compétences$t$, $t$Skill Expert$t$, $t${}$t$::jsonb,
   $t$Augmentez une valeur de caractéristique de votre choix de 1 (max. 20). Vous obtenez la maîtrise d'une compétence de votre choix, ainsi que l'expertise dans une compétence que vous maîtrisez (votre bonus de maîtrise est doublé pour les tests qui l'utilisent).$t$),
  ($t$Trancheur$t$, $t$Slasher$t$, $t${}$t$::jsonb,
   $t$Force ou Dextérité +1 (max. 20). Une fois par tour, lorsque vous touchez une créature avec une attaque infligeant des dégâts tranchants, vous pouvez réduire sa vitesse de 3 m jusqu'au début de votre prochain tour. Lorsque vous réussissez un coup critique infligeant des dégâts tranchants, la créature subit le désavantage à ses jets d'attaque jusqu'au début de votre prochain tour.$t$),
  ($t$Télékinésiste$t$, $t$Telekinetic$t$, $t${}$t$::jsonb,
   $t$Intelligence, Sagesse ou Charisme +1 (max. 20). Vous apprenez Main de mage, que vous pouvez lancer sans composantes et dont la main peut être invisible ; sa portée augmente de 9 m si vous connaissiez déjà ce sort. Par une action bonus, vous pouvez pousser par télékinésie une créature que vous voyez à 9 m ou moins : elle doit réussir un jet de sauvegarde de Force (DD 8 + bonus de maîtrise + modificateur de la caractéristique augmentée) ou être déplacée de 1,50 m vers vous ou à l'opposé.$t$),
  ($t$Télépathe$t$, $t$Telepathic$t$, $t${}$t$::jsonb,
   $t$Intelligence, Sagesse ou Charisme +1 (max. 20). Vous pouvez parler par télépathie à toute créature que vous voyez à 18 m ou moins, dans une langue que vous connaissez ; elle comprend si elle connaît cette langue mais ne peut pas vous répondre ainsi. Vous pouvez aussi lancer Détection des pensées une fois sans emplacement (utilisation récupérée après un repos long) ou avec vos emplacements ; la caractéristique augmentée par ce don est votre caractéristique d'incantation pour ce sort.$t$)
    ) as t(name_fr, name_en, prerequisites, description)
  loop
    if not exists (
      select 1 from public.translations tr
       where tr.entity_type = 'feat' and tr.field_name = 'name' and tr.locale = 'fr'
         and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.feats (prerequisites) values (rec.prerequisites) returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('feat', v_id::text, 'name', 'fr', rec.name_fr),
        ('feat', v_id::text, 'name', 'en', rec.name_en),
        ('feat', v_id::text, 'description', 'fr', rec.description);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'dons insérés : %', v_inserted;
end $$;

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
  -- Guide de Xanathar — texte reformulé
  ($t$Aspect de la lune$t$, $t$Aspect of the Moon$t$, $t${"text":"Aptitude Pacte du grimoire","pact":"grimoire"}$t$::jsonb,
   $t$Vous n'avez plus besoin de dormir et ne pouvez pas être forcé à dormir par quelque moyen que ce soit. Pour bénéficier d'un repos long, il vous suffit de passer les 8 heures à des activités légères, comme lire votre grimoire ou monter la garde.$t$),
  ($t$Manteau de mouches$t$, $t$Cloak of Flies$t$, $t${"text":"Niveau 5","level":5}$t$::jsonb,
   $t$Par une action bonus, vous vous entourez d'une nuée magique de mouches bourdonnantes dans un rayon de 1,50 m autour de vous. Elle s'étend autour des angles et n'affecte pas votre vision. Vous avez l'avantage aux tests de Charisme (Intimidation) mais le désavantage aux autres tests de Charisme, et toute autre créature qui commence son tour dans la nuée subit des dégâts de poison égaux à votre modificateur de Charisme (minimum 0). La nuée se dissipe si vous êtes neutralisé ou si vous la congédiez par une action bonus. Vous récupérez cette capacité à la fin d'un repos court ou long.$t$),
  ($t$Châtiment occulte$t$, $t$Eldritch Smite$t$, $t${"text":"Niveau 5, aptitude Pacte de la lame","level":5,"pact":"lame"}$t$::jsonb,
   $t$Une fois par tour, lorsque vous touchez une créature avec votre arme de pacte, vous pouvez dépenser un emplacement de sort d'occultiste pour lui infliger 1d8 dégâts de force supplémentaires, plus 1d8 par niveau de l'emplacement, et la faire tomber à terre si elle est de taille TG ou inférieure.$t$),
  ($t$Regard spectral$t$, $t$Ghostly Gaze$t$, $t${"text":"Niveau 7","level":7}$t$::jsonb,
   $t$Par une action, vous pouvez voir à travers les objets solides jusqu'à 9 m, pendant 1 minute tant que vous vous concentrez (comme pour un sort). Dans ce rayon, vous bénéficiez de la vision dans le noir si vous ne l'avez pas déjà. Les objets vous apparaissent comme des formes fantomatiques. Vous récupérez cette capacité à la fin d'un repos court ou long.$t$),
  ($t$Don des profondeurs$t$, $t$Gift of the Depths$t$, $t${"text":"Niveau 5","level":5}$t$::jsonb,
   $t$Vous pouvez respirer sous l'eau et obtenez une vitesse de nage égale à votre vitesse au sol. Vous pouvez aussi lancer Respiration aquatique une fois sans dépenser d'emplacement de sort ; vous récupérez cette utilisation à la fin d'un repos long.$t$),
  ($t$Don des Éternels$t$, $t$Gift of the Ever-Living Ones$t$, $t${"text":"Aptitude Pacte de la chaîne","pact":"chaine"}$t$::jsonb,
   $t$Chaque fois que vous récupérez des points de vie alors que votre familier se trouve à 30 m ou moins de vous, considérez chaque dé lancé pour déterminer les points de vie récupérés comme ayant obtenu son résultat maximal.$t$),
  ($t$Étreinte d'Hadar$t$, $t$Grasp of Hadar$t$, $t${"text":"Sort mineur Décharge occulte","cantrip_spell_id":8}$t$::jsonb,
   $t$Une fois par tour, lorsque vous touchez une créature avec votre Décharge occulte, vous pouvez la déplacer en ligne droite de 3 m vers vous.$t$),
  ($t$Arme de pacte améliorée$t$, $t$Improved Pact Weapon$t$, $t${"text":"Aptitude Pacte de la lame","pact":"lame"}$t$::jsonb,
   $t$Vous pouvez utiliser toute arme que vous invoquez avec votre Pacte de la lame comme focaliseur d'incantation pour vos sorts d'occultiste. Cette arme obtient un bonus de +1 aux jets d'attaque et de dégâts, sauf s'il s'agit d'une arme magique qui possède déjà un bonus à ces jets. Vous pouvez enfin invoquer un arc court, un arc long ou une arbalète légère ou lourde comme arme de pacte.$t$),
  ($t$Lance de léthargie$t$, $t$Lance of Lethargy$t$, $t${"text":"Sort mineur Décharge occulte","cantrip_spell_id":8}$t$::jsonb,
   $t$Une fois par tour, lorsque vous touchez une créature avec votre Décharge occulte, vous pouvez réduire sa vitesse de 3 m jusqu'à la fin de votre prochain tour.$t$),
  ($t$Maléfice affolant$t$, $t$Maddening Hex$t$, $t${"text":"Niveau 5, sort Maléfice ou aptitude d'occultiste qui maudit","level":5}$t$::jsonb,
   $t$Par une action bonus, vous provoquez une perturbation psychique autour de la cible maudite par votre sort Maléfice ou par une aptitude d'occultiste (comme Rétribution du maléfice ou Marque sinistre). La cible et chaque créature de votre choix que vous voyez à 1,50 m ou moins d'elle subissent des dégâts psychiques égaux à votre modificateur de Charisme (minimum 1). Vous devez voir la cible, qui doit se trouver à 9 m ou moins de vous.$t$),
  ($t$Maléfice implacable$t$, $t$Relentless Hex$t$, $t${"text":"Niveau 7, sort Maléfice ou aptitude d'occultiste qui maudit","level":7}$t$::jsonb,
   $t$Votre malédiction crée un lien temporaire entre vous et votre cible. Par une action bonus, vous pouvez vous téléporter par magie jusqu'à 9 m dans un espace inoccupé que vous voyez, situé à 1,50 m ou moins de la cible maudite par votre sort Maléfice ou par une aptitude d'occultiste. Vous devez voir la cible pour cela.$t$),
  ($t$Voile d'ombre$t$, $t$Shroud of Shadow$t$, $t${"text":"Niveau 15","level":15}$t$::jsonb,
   $t$Vous pouvez lancer Invisibilité à volonté, sans dépenser d'emplacement de sort.$t$),
  ($t$Tombe de Levistus$t$, $t$Tomb of Levistus$t$, $t${"text":"Niveau 5","level":5}$t$::jsonb,
   $t$Par une réaction lorsque vous subissez des dégâts, vous pouvez vous enfermer dans la glace, qui fond à la fin de votre prochain tour. Vous obtenez 10 points de vie temporaires par niveau d'occultiste, qui absorbent autant que possible les dégâts déclencheurs. Juste après, vous obtenez la vulnérabilité aux dégâts de feu, votre vitesse tombe à 0 et vous êtes neutralisé ; ces effets, et les points de vie temporaires restants, disparaissent quand la glace fond. Vous récupérez cette capacité à la fin d'un repos court ou long.$t$),
  ($t$Évasion du mystificateur$t$, $t$Trickster's Escape$t$, $t${"text":"Niveau 7","level":7}$t$::jsonb,
   $t$Vous pouvez lancer Liberté de mouvement une fois sur vous-même sans dépenser d'emplacement de sort. Vous récupérez cette capacité à la fin d'un repos long.$t$),
  -- Chaudron de Tasha — texte reformulé
  ($t$Lien du talisman$t$, $t$Bond of the Talisman$t$, $t${"text":"Niveau 12, aptitude Pacte du talisman","level":12,"pact":"talisman"}$t$::jsonb,
   $t$Tant qu'une autre créature porte votre talisman, vous pouvez, par une action, vous téléporter dans l'espace inoccupé le plus proche d'elle, à condition d'être sur le même plan d'existence. Le porteur du talisman peut faire de même pour vous rejoindre. Cette capacité peut être utilisée un nombre de fois égal à votre bonus de maîtrise, et toutes les utilisations reviennent à la fin d'un repos long.$t$),
  ($t$Esprit occulte$t$, $t$Eldritch Mind$t$, $t${}$t$::jsonb,
   $t$Vous avez l'avantage aux jets de sauvegarde de Constitution effectués pour maintenir votre concentration sur un sort.$t$),
  ($t$Scribe lointain$t$, $t$Far Scribe$t$, $t${"text":"Niveau 5, aptitude Pacte du grimoire","level":5,"pact":"grimoire"}$t$::jsonb,
   $t$Une nouvelle page apparaît dans votre Livre des Ombres. Avec votre permission, une créature peut y écrire son nom par une action ; la page peut contenir un nombre de noms égal à votre bonus de maîtrise. Vous pouvez lancer Envoi sans dépenser d'emplacement ni de composante matérielle, en ciblant uniquement une créature dont le nom figure sur la page ; la cible entend le message dans son esprit et peut répondre de la même manière. Vous pouvez effacer un nom par une action magique.$t$),
  ($t$Don des protecteurs$t$, $t$Gift of the Protectors$t$, $t${"text":"Niveau 9, aptitude Pacte du grimoire","level":9,"pact":"grimoire"}$t$::jsonb,
   $t$Une nouvelle page apparaît dans votre Livre des Ombres. Avec votre permission, une créature peut y écrire son nom par une action ; la page peut contenir un nombre de noms égal à votre bonus de maîtrise. Lorsqu'une créature dont le nom figure sur la page tombe à 0 point de vie sans être tuée sur le coup, elle tombe à 1 point de vie à la place. Une fois cette protection déclenchée, aucune créature ne peut en bénéficier avant la fin de votre prochain repos long. Vous pouvez effacer un nom par une action magique.$t$),
  ($t$Investiture du maître de la chaîne$t$, $t$Investment of the Chain Master$t$, $t${"text":"Aptitude Pacte de la chaîne","pact":"chaine"}$t$::jsonb,
   $t$Lorsque vous lancez Appel de familier, le familier obtient : une vitesse de vol ou de nage de 12 m ; la possibilité de lui ordonner d'effectuer l'action Attaque par une action bonus ; des attaques infligeant, à votre choix, des dégâts nécrotiques ou radiants qui comptent comme magiques ; votre DD de sauvegarde des sorts pour tout jet de sauvegarde qu'il impose. Lorsqu'il subit des dégâts, vous pouvez utiliser votre réaction pour lui accorder la résistance à ces dégâts.$t$),
  ($t$Protection du talisman$t$, $t$Protection of the Talisman$t$, $t${"text":"Niveau 7, aptitude Pacte du talisman","level":7,"pact":"talisman"}$t$::jsonb,
   $t$Lorsque le porteur de votre talisman rate un jet de sauvegarde, il peut ajouter 1d4 au résultat, ce qui peut transformer l'échec en réussite. Cette capacité peut être utilisée un nombre de fois égal à votre bonus de maîtrise, et toutes les utilisations reviennent à la fin d'un repos long.$t$),
  ($t$Réprimande du talisman$t$, $t$Rebuke of the Talisman$t$, $t${"text":"Aptitude Pacte du talisman","pact":"talisman"}$t$::jsonb,
   $t$Lorsque le porteur de votre talisman est touché par un attaquant que vous voyez à 9 m ou moins de vous, vous pouvez utiliser votre réaction pour infliger à l'attaquant des dégâts psychiques égaux à votre bonus de maîtrise et le repousser de 3 m loin du porteur.$t$),
  ($t$Servitude éternelle$t$, $t$Undying Servitude$t$, $t${"text":"Niveau 5","level":5}$t$::jsonb,
   $t$Vous pouvez lancer Animation des morts sans dépenser d'emplacement de sort. Vous récupérez cette capacité à la fin d'un repos long.$t$)
    ) as t(name_fr, name_en, prerequisites, description)
  loop
    if not exists (
      select 1 from public.translations tr
       where tr.entity_type = 'invocation' and tr.field_name = 'name' and tr.locale = 'fr'
         and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.invocations (prerequisites) values (rec.prerequisites) returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('invocation', v_id::text, 'name', 'fr', rec.name_fr),
        ('invocation', v_id::text, 'name', 'en', rec.name_en),
        ('invocation', v_id::text, 'description', 'fr', rec.description);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'manifestations insérées : %', v_inserted;
end $$;

-- Contrôle final : toute anomalie annule la migration entière.
do $$
declare
  v_feats int;
  v_invocations int;
begin
  select count(*) into v_feats from public.feats;
  select count(*) into v_invocations from public.invocations;
  if v_feats < 84 then
    raise exception 'Contrôle lot 3 : % dons présents, 84 attendus au minimum', v_feats;
  end if;
  if v_invocations < 54 then
    raise exception 'Contrôle lot 3 : % manifestations présentes, 54 attendues au minimum', v_invocations;
  end if;
  if exists (
    select 1 from public.feats f
     where not exists (select 1 from public.translations t
                        where t.entity_type = 'feat' and t.entity_id = f.id::text
                          and t.field_name = 'name' and t.locale = 'fr')
  ) or exists (
    select 1 from public.invocations i
     where not exists (select 1 from public.translations t
                        where t.entity_type = 'invocation' and t.entity_id = i.id::text
                          and t.field_name = 'name' and t.locale = 'fr')
  ) then
    raise exception 'Contrôle lot 3 : don ou manifestation sans nom FR';
  end if;
end $$;
