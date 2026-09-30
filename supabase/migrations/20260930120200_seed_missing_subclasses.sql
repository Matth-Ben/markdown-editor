-- Lot 5c de l'import du contenu de référence : sous-classes officielles manquantes, avec toutes
-- leurs aptitudes (texte français reformulé) :
-- Voie du berserker ancestral nain (SCAG), Voie de la longue mort (SCAG), Immortel (SCAG),
-- Chevalier dragon pourpre (SCAG), Serment de la couronne (SCAG), Parjure (Guide du maître),
-- Sorcellerie lunaire (Dragonlance), Chronurgie et Graviturgie (Wildemount), Chevalier de l'écho
-- (Wildemount).
-- Idempotente : sous-classe insérée si son nom FR n'existe pas pour la classe ; aptitude insérée
-- si la sous-classe n'en a pas déjà une du même nom FR.

do $$
declare
  rec record;
  v_id int;
  v_sub int;
  v_subs int := 0;
  v_feats int := 0;
begin
  for rec in
    select * from (values
  (1, 3, $t$Berserker ancestral$t$, $t$Path of the Battlerager$t$, $t$Voie réservée aux nains : un guerrier en armure hérissée de pointes qui se jette dans la mêlée et blesse tout ce qui l'approche.$t$),
  (6, 3, $t$Voie de la longue mort$t$, $t$Way of the Long Death$t$, $t$Moines obsédés par la mort, qui puisent leur force dans l'extinction de la vie et terrifient leurs ennemis.$t$),
  (10, 1, $t$Immortel$t$, $t$The Undying$t$, $t$Pacte avec une entité ayant vaincu la mort (liche, dieu défunt...), qui éloigne l'occultiste de la fin et du vieillissement.$t$),
  (5, 3, $t$Chevalier dragon pourpre$t$, $t$Purple Dragon Knight (Banneret)$t$, $t$Chef de guerre inspirant qui galvanise ses alliés en combat et représente son ordre avec diplomatie.$t$),
  (7, 3, $t$Serment de la couronne$t$, $t$Oath of the Crown$t$, $t$Paladins voués à la loi et à la civilisation, protecteurs de leur souverain et de leurs compagnons.$t$),
  (7, 3, $t$Parjure$t$, $t$Oathbreaker$t$, $t$Paladin qui a rompu ses vœux sacrés pour servir des ambitions sombres ou une puissance maléfique.$t$),
  (12, 1, $t$Sorcellerie lunaire$t$, $t$Lunar Sorcery$t$, $t$Ensorceleur dont la magie suit les phases de la lune (pleine, nouvelle, croissant).$t$),
  (11, 2, $t$Chronurgie$t$, $t$Chronurgy Magic$t$, $t$Magiciens qui manipulent le temps pour altérer le déroulement des événements.$t$),
  (11, 2, $t$Graviturgie$t$, $t$Graviturgy Magic$t$, $t$Magiciens qui manipulent la gravité, la densité et l'attraction des corps.$t$),
  (5, 3, $t$Chevalier de l'écho$t$, $t$Echo Knight$t$, $t$Guerrier capable d'invoquer un écho de lui-même issu d'une ligne temporelle alternative.$t$)
    ) as t(class_id, from_level, name_fr, name_en, description)
  loop
    if exists (select 1 from public.classes c where c.id = rec.class_id)
       and not exists (
         select 1 from public.subclasses s
           join public.translations tr
             on tr.entity_type = 'subclass' and tr.entity_id = s.id::text
            and tr.field_name = 'name' and tr.locale = 'fr'
          where s.class_id = rec.class_id and lower(tr.value) = lower(rec.name_fr)
       ) then
      insert into public.subclasses (class_id, available_from_level)
        values (rec.class_id, rec.from_level)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('subclass', v_id::text, 'name', 'fr', rec.name_fr),
        ('subclass', v_id::text, 'name', 'en', rec.name_en),
        ('subclass', v_id::text, 'description', 'fr', rec.description);
      v_subs := v_subs + 1;
    end if;
  end loop;

  for rec in
    select * from (values
  -- Berserker ancestral (Barbare)
  (1, $t$Berserker ancestral$t$, 3, null::text, $t$Restriction : nains uniquement$t$, $t$Restriction: Dwarves Only$t$, $t$Seuls les nains peuvent suivre cette voie ; le rôle du berserker ancestral est intimement lié à la culture naine.$t$),
  (1, $t$Berserker ancestral$t$, 3, null, $t$Armure hérissée$t$, $t$Battlerager Armor$t$, $t$Vous maîtrisez l'armure à pointes. En rage et en la portant, par une action bonus, vous portez une attaque avec les pointes contre une créature à 1,50 m (1d4 + modificateur de Force dégâts perforants), et une créature que vous empoignez subit 3 dégâts perforants.$t$),
  (1, $t$Berserker ancestral$t$, 6, null, $t$Abandon téméraire$t$, $t$Reckless Abandon$t$, $t$Lorsque vous utilisez Attaque téméraire pendant votre rage, vous gagnez des points de vie temporaires égaux à votre modificateur de Constitution (minimum 1).$t$),
  (1, $t$Berserker ancestral$t$, 10, null, $t$Charge du berserker ancestral$t$, $t$Battlerager Charge$t$, $t$En rage, vous pouvez effectuer l'action Foncer par une action bonus.$t$),
  (1, $t$Berserker ancestral$t$, 14, null, $t$Représailles hérissées$t$, $t$Spiked Retribution$t$, $t$En rage et en armure à pointes, une créature à 1,50 m ou moins qui vous touche au corps à corps subit 3 dégâts perforants, si vous n'êtes pas neutralisé.$t$),
  -- Voie de la longue mort (Moine)
  (6, $t$Voie de la longue mort$t$, 3, null, $t$Toucher de la mort$t$, $t$Touch of Death$t$, $t$Lorsque vous faites tomber à 0 point de vie une créature à 1,50 m ou moins, vous gagnez des points de vie temporaires égaux à votre modificateur de Sagesse + votre niveau de moine (minimum 1).$t$),
  (6, $t$Voie de la longue mort$t$, 6, null, $t$Heure de la moisson$t$, $t$Hour of Reaping$t$, $t$Par une action, chaque créature à 9 m ou moins qui peut vous voir doit réussir un jet de sauvegarde de Sagesse ou être effrayée par vous jusqu'à la fin de votre prochain tour.$t$),
  (6, $t$Voie de la longue mort$t$, 11, null, $t$Maîtrise de la mort$t$, $t$Mastery of Death$t$, $t$Lorsque vous tombez à 0 point de vie, vous pouvez dépenser 1 point de ki pour tomber à 1 point de vie à la place.$t$),
  (6, $t$Voie de la longue mort$t$, 17, null, $t$Toucher de la longue mort$t$, $t$Touch of the Long Death$t$, $t$Par une action, vous touchez une créature à 1,50 m et dépensez de 1 à 10 points de ki : elle doit réussir un jet de sauvegarde de Constitution ou subir 2d10 dégâts nécrotiques par point de ki dépensé (moitié en cas de réussite).$t$),
  -- Immortel (Occultiste)
  (10, $t$Immortel$t$, 1, $t$sort_domaine$t$, $t$Liste de sorts étendue$t$, $t$Expanded Spell List$t$, $t$Sorts ajoutés à votre liste d'occultiste : niveau 1 — Simulacre de vie, Rayon empoisonné ; niveau 2 — Cécité/Surdité, Silence ; niveau 3 — Mort simulée, Communication avec les morts ; niveau 4 — Aura de vie, Protection contre la mort ; niveau 5 — Contagion, Mythes et légendes.$t$),
  (10, $t$Immortel$t$, 1, null, $t$Parmi les morts$t$, $t$Among the Dead$t$, $t$Vous apprenez le sort mineur Épargner les mourants. Vous avez l'avantage aux jets de sauvegarde contre les maladies. Un mort-vivant qui vous cible directement d'une attaque ou d'un sort nuisible doit réussir un jet de sauvegarde de Sagesse ou choisir une autre cible (s'il réussit, il est immunisé 24 heures).$t$),
  (10, $t$Immortel$t$, 6, null, $t$Défier la mort$t$, $t$Defy Death$t$, $t$Lorsque vous réussissez un jet de sauvegarde contre la mort ou stabilisez une créature avec Épargner les mourants, vous récupérez 1d8 + votre modificateur de Constitution points de vie (minimum 1). Une fois par repos long.$t$),
  (10, $t$Immortel$t$, 10, null, $t$Nature immortelle$t$, $t$Undying Nature$t$, $t$Vous pouvez retenir votre souffle indéfiniment et n'avez besoin ni de manger, ni de boire, ni de dormir (le repos reste nécessaire). Vous vieillissez dix fois plus lentement et êtes immunisé contre le vieillissement magique.$t$),
  (10, $t$Immortel$t$, 14, null, $t$Vie indestructible$t$, $t$Indestructible Life$t$, $t$Par une action bonus, vous récupérez 1d8 + votre niveau d'occultiste points de vie, et pouvez rattacher un membre tranché que vous tenez contre son moignon. Une fois par repos court ou long.$t$),
  -- Chevalier dragon pourpre (Guerrier)
  (5, $t$Chevalier dragon pourpre$t$, 3, null, $t$Cri de ralliement$t$, $t$Rallying Cry$t$, $t$Lorsque vous utilisez Second souffle, jusqu'à trois alliés à 18 m ou moins qui peuvent vous voir ou vous entendre récupèrent des points de vie égaux à votre niveau de guerrier.$t$),
  (5, $t$Chevalier dragon pourpre$t$, 7, null, $t$Envoyé royal$t$, $t$Royal Envoy$t$, $t$Vous maîtrisez la Persuasion (ou, à défaut, une compétence parmi Dressage, Intuition, Intimidation et Représentation), et doublez votre bonus de maîtrise pour les tests de Charisme (Persuasion).$t$),
  (5, $t$Chevalier dragon pourpre$t$, 10, null, $t$Élan inspirant$t$, $t$Inspiring Surge$t$, $t$Lorsque vous utilisez Fougue, un allié à 18 m ou moins qui vous voit ou vous entend peut utiliser sa réaction pour porter une attaque armée ou au corps à corps (deux alliés au niveau 18).$t$),
  (5, $t$Chevalier dragon pourpre$t$, 15, null, $t$Rempart$t$, $t$Bulwark$t$, $t$Lorsque vous utilisez Indomptable pour relancer un jet de sauvegarde d'Intelligence, de Sagesse ou de Charisme, un allié à 18 m ou moins qui a raté le même jet contre le même effet peut aussi le relancer.$t$),
  -- Serment de la couronne (Paladin)
  (7, $t$Serment de la couronne$t$, 3, $t$sort_domaine$t$, $t$Sorts de serment de la couronne$t$, $t$Oath Spells$t$, $t$Toujours préparés : niveau 3 — Injonction, Duel forcé ; niveau 5 — Lien de protection, Zone de vérité ; niveau 9 — Aura de vitalité, Esprits gardiens ; niveau 13 — Bannissement, Gardien de la foi ; niveau 17 — Cercle de pouvoir, Quête.$t$),
  (7, $t$Serment de la couronne$t$, 3, null, $t$Défi du champion$t$, $t$Champion Challenge$t$, $t$Conduit divin : par une action bonus, chaque créature de votre choix à 9 m ou moins doit réussir un jet de sauvegarde de Sagesse ou ne plus pouvoir s'éloigner volontairement à plus de 9 m de vous, tant que vous n'êtes pas neutralisé ou mort.$t$),
  (7, $t$Serment de la couronne$t$, 3, null, $t$Renverser le cours$t$, $t$Turn the Tide$t$, $t$Conduit divin : par une action bonus, chaque créature à 9 m ou moins qui vous entend et qui a au plus la moitié de ses points de vie récupère 1d6 + votre modificateur de Charisme points de vie (minimum 1).$t$),
  (7, $t$Serment de la couronne$t$, 7, null, $t$Allégeance divine$t$, $t$Divine Allegiance$t$, $t$Par une réaction lorsqu'une créature à 1,50 m ou moins subit des dégâts, vous pouvez les subir à sa place ; ils ne peuvent pas être réduits.$t$),
  (7, $t$Serment de la couronne$t$, 15, null, $t$Saint inébranlable$t$, $t$Unyielding Saint$t$, $t$Vous avez l'avantage aux jets de sauvegarde pour éviter d'être paralysé ou étourdi.$t$),
  (7, $t$Serment de la couronne$t$, 20, null, $t$Champion exalté$t$, $t$Exalted Champion$t$, $t$Par une action, pendant 1 heure : résistance aux dégâts contondants, perforants et tranchants des armes non magiques ; vos alliés à 9 m ou moins ont l'avantage aux jets de sauvegarde contre la mort ; vous et vos alliés dans cette zone avez l'avantage aux jets de sauvegarde de Sagesse. Une fois par repos long.$t$),
  -- Parjure (Paladin)
  (7, $t$Parjure$t$, 3, $t$sort_domaine$t$, $t$Sorts du parjure$t$, $t$Oathbreaker Spells$t$, $t$Toujours préparés : niveau 3 — Représailles infernales, Blessure ; niveau 5 — Couronne de démence, Ténèbres ; niveau 9 — Animation des morts, Malédiction ; niveau 13 — Flétrissement, Confusion ; niveau 17 — Contagion, Domination de personne.$t$),
  (7, $t$Parjure$t$, 3, null, $t$Contrôle des morts-vivants$t$, $t$Control Undead$t$, $t$Conduit divin : par une action, un mort-vivant à 9 m ou moins dont le FP ne dépasse pas votre niveau de paladin doit réussir un jet de sauvegarde de Sagesse ou vous obéir pendant 24 heures.$t$),
  (7, $t$Parjure$t$, 3, null, $t$Aspect terrifiant$t$, $t$Dreadful Aspect$t$, $t$Conduit divin : par une action, chaque créature de votre choix à 9 m ou moins qui vous voit doit réussir un jet de sauvegarde de Sagesse ou être effrayée pendant 1 minute ; elle refait le jet si elle termine son tour à plus de 9 m de vous.$t$),
  (7, $t$Parjure$t$, 7, null, $t$Aura de haine$t$, $t$Aura of Hate$t$, $t$Vous, ainsi que les fiélons et morts-vivants à 3 m ou moins de vous (9 m au niveau 18), ajoutez votre modificateur de Charisme (minimum +1) aux dégâts des attaques armées au corps à corps.$t$),
  (7, $t$Parjure$t$, 15, null, $t$Résistance surnaturelle$t$, $t$Supernatural Resistance$t$, $t$Vous avez la résistance aux dégâts contondants, perforants et tranchants des armes non magiques.$t$),
  (7, $t$Parjure$t$, 20, null, $t$Seigneur de l'effroi$t$, $t$Dread Lord$t$, $t$Par une action, pendant 1 minute, une aura de ténèbres de 9 m réduit la lumière vive en lumière faible. Les ennemis effrayés par vous qui y commencent leur tour subissent 4d10 dégâts psychiques ; les créatures qui dépendent de la vue ont le désavantage aux attaques contre vous et vos alliés dans l'aura ; par une action bonus, vous lancez des ombres sur une créature de l'aura (attaque de sort au corps à corps, 3d10 dégâts nécrotiques). Une fois par repos long.$t$),
  -- Sorcellerie lunaire (Ensorceleur)
  (12, $t$Sorcellerie lunaire$t$, 1, $t$sort_domaine$t$, $t$Incarnation lunaire$t$, $t$Lunar Embodiment$t$, $t$Sorts connus en plus : niveau 1 — Bouclier, Rayon empoisonné, Couleurs dansantes ; niveau 3 — Restauration partielle, Cécité/Surdité, Modification d'apparence ; niveau 5 — Dissipation de la magie, Caresse du vampire, Coursier fantôme ; niveau 7 — Protection contre la mort, Confusion, Terrain hallucinatoire ; niveau 9 — Lien télépathique de Rary, Immobilisation de monstre, Double illusoire. Après un repos long, choisissez une phase (pleine lune, nouvelle lune, croissant) : vous pouvez lancer une fois sans emplacement le sort de niveau 1 de cette phase.$t$),
  (12, $t$Sorcellerie lunaire$t$, 1, null, $t$Feu lunaire$t$, $t$Moon Fire$t$, $t$Vous apprenez le sort mineur Flamme sacrée, qui peut viser une créature ou deux créatures situées à 1,50 m l'une de l'autre.$t$),
  (12, $t$Sorcellerie lunaire$t$, 6, null, $t$Bienfaits lunaires$t$, $t$Lunar Boons$t$, $t$Lorsque vous appliquez une Métamagie à un sort d'une école associée à votre phase (pleine lune : abjuration et divination ; nouvelle lune : enchantement et nécromancie ; croissant : illusion et transmutation), son coût diminue de 1 point de sorcellerie. Utilisations égales à votre bonus de maîtrise, récupérées après un repos long.$t$),
  (12, $t$Sorcellerie lunaire$t$, 6, null, $t$Croissance et déclin$t$, $t$Waxing and Waning$t$, $t$Par une action bonus et 1 point de sorcellerie, vous changez de phase lunaire. Vous pouvez désormais lancer sans emplacement le sort de niveau 1 de chaque phase une fois par repos long, à condition d'être dans cette phase.$t$),
  (12, $t$Sorcellerie lunaire$t$, 14, null, $t$Puissance lunaire$t$, $t$Lunar Empowerment$t$, $t$Selon votre phase : pleine lune (par une action bonus, lumière vive sur 3 m ; vous et vos alliés dans cette lumière avez l'avantage aux tests d'Investigation et de Perception) ; nouvelle lune (avantage aux tests de Discrétion, et les attaques contre vous ont le désavantage quand vous êtes entièrement dans l'obscurité) ; croissant (résistance aux dégâts nécrotiques et radiants).$t$),
  (12, $t$Sorcellerie lunaire$t$, 18, null, $t$Phénomène lunaire$t$, $t$Lunar Phenomenon$t$, $t$Par une action bonus (ou en changeant de phase), vous déclenchez le pouvoir de votre phase. Pleine lune : les créatures de votre choix à 9 m doivent réussir un jet de sauvegarde de Constitution ou être aveuglées jusqu'à la fin de leur prochain tour, et une créature récupère 3d8 points de vie. Nouvelle lune : les créatures de votre choix à 9 m doivent réussir un jet de sauvegarde de Dextérité ou subir 3d10 dégâts nécrotiques et voir leur vitesse tomber à 0, et vous devenez invisible jusqu'à la fin de votre prochain tour. Croissant : vous vous téléportez jusqu'à 18 m avec une créature consentante, et vous avez tous deux la résistance à tous les dégâts jusqu'au début de votre prochain tour. Une fois par repos long, ou pour 5 points de sorcellerie.$t$),
  -- Chronurgie (Magicien)
  (11, $t$Chronurgie$t$, 2, null, $t$Glissement temporel$t$, $t$Chronal Shift$t$, $t$Par une réaction, après qu'une créature que vous voyez à 9 m ou moins a fait un jet d'attaque, un test ou un jet de sauvegarde, vous l'obligez à le relancer et à garder le nouveau résultat. Deux fois par repos long.$t$),
  (11, $t$Chronurgie$t$, 2, null, $t$Conscience temporelle$t$, $t$Temporal Awareness$t$, $t$Vous ajoutez votre modificateur d'Intelligence à vos jets d'initiative.$t$),
  (11, $t$Chronurgie$t$, 6, null, $t$Stase momentanée$t$, $t$Momentary Stasis$t$, $t$Par une action, une créature de taille G ou inférieure que vous voyez à 18 m ou moins doit réussir un jet de sauvegarde de Constitution ou être neutralisée, avec une vitesse de 0, jusqu'à la fin de votre prochain tour ou jusqu'à subir des dégâts. Utilisations égales à votre modificateur d'Intelligence, récupérées après un repos long.$t$),
  (11, $t$Chronurgie$t$, 10, null, $t$Suspension arcanique$t$, $t$Arcane Abeyance$t$, $t$Lorsque vous lancez un sort de niveau 4 ou inférieur, vous pouvez le condenser en une perle pendant 1 heure. Une créature qui la tient peut la briser par une action pour libérer le sort (avec votre DD et votre bonus d'attaque). Une fois par repos court ou long.$t$),
  (11, $t$Chronurgie$t$, 14, null, $t$Avenir convergent$t$, $t$Convergent Future$t$, $t$Par une réaction, lorsqu'une créature que vous voyez à 18 m ou moins fait un jet d'attaque, un test ou un jet de sauvegarde, vous décidez qu'il réussit ou échoue. Vous gagnez alors un niveau d'épuisement, qui ne disparaît qu'avec un repos long.$t$),
  -- Graviturgie (Magicien)
  (11, $t$Graviturgie$t$, 2, null, $t$Ajustement de densité$t$, $t$Adjust Density$t$, $t$Par une action, pendant 1 minute (concentration), vous divisez par deux ou doublez le poids d'une créature ou d'un objet de taille G ou inférieure à 9 m ou moins. Allégée : vitesse +3 m, saut doublé, désavantage aux tests et sauvegardes de Force. Alourdie : vitesse −3 m, avantage aux tests et sauvegardes de Force.$t$),
  (11, $t$Graviturgie$t$, 6, null, $t$Puits gravitationnel$t$, $t$Gravity Well$t$, $t$Lorsque vous lancez un sort sur une créature et que vous la touchez, qu'elle rate son jet de sauvegarde ou qu'elle est consentante, vous pouvez la déplacer de 1,50 m dans un espace inoccupé.$t$),
  (11, $t$Graviturgie$t$, 10, null, $t$Attraction violente$t$, $t$Violent Attraction$t$, $t$Par une réaction, lorsqu'une créature que vous voyez à 18 m ou moins touche avec une attaque armée, la cible subit 1d10 dégâts supplémentaires ; ou lorsqu'une créature subit des dégâts de chute, elle subit 2d10 dégâts contondants supplémentaires. Utilisations égales à votre modificateur d'Intelligence, récupérées après un repos long.$t$),
  (11, $t$Graviturgie$t$, 14, null, $t$Horizon des événements$t$, $t$Event Horizon$t$, $t$Par une action, pendant 1 minute (concentration), chaque créature hostile qui commence son tour à 9 m ou moins de vous doit réussir un jet de sauvegarde de Force ou subir 2d10 dégâts de force et voir sa vitesse tomber à 0 ; en cas de réussite, moitié des dégâts et chaque mètre parcouru pour s'éloigner en coûte trois. Une fois par repos long, ou en dépensant un emplacement de niveau 3 ou supérieur.$t$),
  -- Chevalier de l'écho (Guerrier)
  (5, $t$Chevalier de l'écho$t$, 3, null, $t$Écho manifesté$t$, $t$Manifest Echo$t$, $t$Par une action bonus, vous faites apparaître un écho de vous-même à 4,50 m ou moins (CA 14 + bonus de maîtrise, 1 point de vie, immunisé contre les états). Par une action bonus, vous le déplacez de 9 m ou échangez votre place avec lui (1,50 m de déplacement). Vos attaques peuvent partir de son espace, et il peut porter vos attaques d'opportunité.$t$),
  (5, $t$Chevalier de l'écho$t$, 3, null, $t$Incarnation déchaînée$t$, $t$Unleash Incarnation$t$, $t$Lors de l'action Attaque, vous pouvez porter une attaque au corps à corps supplémentaire depuis la position de votre écho. Utilisations égales à votre modificateur de Constitution, récupérées après un repos long.$t$),
  (5, $t$Chevalier de l'écho$t$, 7, null, $t$Avatar de l'écho$t$, $t$Echo Avatar$t$, $t$Par une action, pendant 10 minutes, vous voyez et entendez par votre écho (vous êtes alors aveuglé et assourdi) ; il peut s'éloigner jusqu'à 300 m de vous.$t$),
  (5, $t$Chevalier de l'écho$t$, 10, null, $t$Martyr d'ombre$t$, $t$Shadow Martyr$t$, $t$Par une réaction, avant qu'une créature ne soit attaquée, vous téléportez votre écho à 1,50 m d'elle : l'attaque vise l'écho à la place. Une fois par repos court ou long.$t$),
  (5, $t$Chevalier de l'écho$t$, 15, null, $t$Récupération du potentiel$t$, $t$Reclaim Potential$t$, $t$Lorsque votre écho est détruit par des dégâts, vous gagnez 2d6 + votre modificateur de Constitution points de vie temporaires (s'ils vous en reste moins). Utilisations égales à votre modificateur de Constitution, récupérées après un repos long.$t$),
  (5, $t$Chevalier de l'écho$t$, 18, null, $t$Légion à moi seul$t$, $t$Legion of One$t$, $t$Vous pouvez créer deux échos avec une même action bonus, qui coexistent. Si vous n'avez plus d'utilisation d'Incarnation déchaînée lorsque vous lancez l'initiative, vous en récupérez une.$t$)
    ) as t(class_id, subclass_fr, level, choice_type, name_fr, name_en, description)
  loop
    select s.id into v_sub
      from public.subclasses s
      join public.translations tr
        on tr.entity_type = 'subclass' and tr.entity_id = s.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where s.class_id = rec.class_id and lower(tr.value) = lower(rec.subclass_fr)
     limit 1;
    if v_sub is null then
      raise exception 'Sous-classe introuvable : %', rec.subclass_fr;
    end if;
    if not exists (
      select 1 from public.class_features f
        join public.translations tr
          on tr.entity_type = 'class_feature' and tr.entity_id = f.id::text
         and tr.field_name = 'name' and tr.locale = 'fr'
       where f.subclass_id = v_sub and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.class_features (class_id, subclass_id, level, choice_type)
        values (null, v_sub, rec.level, rec.choice_type)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('class_feature', v_id::text, 'name', 'fr', rec.name_fr),
        ('class_feature', v_id::text, 'name', 'en', rec.name_en),
        ('class_feature', v_id::text, 'description', 'fr', rec.description);
      v_feats := v_feats + 1;
    end if;
  end loop;
  raise notice 'sous-classes insérées : %, aptitudes insérées : %', v_subs, v_feats;
end $$;

-- Contrôle final : les 10 sous-classes existent et ont chacune au moins 4 aptitudes.
do $$
declare
  v_ok int;
begin
  select count(*) into v_ok
    from public.subclasses s
    join public.translations tr
      on tr.entity_type = 'subclass' and tr.entity_id = s.id::text
     and tr.field_name = 'name' and tr.locale = 'fr'
   where tr.value in ('Berserker ancestral','Voie de la longue mort','Immortel','Chevalier dragon pourpre',
                      'Serment de la couronne','Parjure','Sorcellerie lunaire','Chronurgie','Graviturgie',
                      'Chevalier de l''écho')
     and (select count(*) from public.class_features f where f.subclass_id = s.id) >= 4;
  if v_ok <> 10 then
    raise exception 'Contrôle lot 5c : % sous-classes complètes sur 10', v_ok;
  end if;
end $$;
