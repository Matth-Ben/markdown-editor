-- Chantier "Personnages" (app mobile) — peuplement de public.invocations
-- (0 ligne jusqu'ici, table vide depuis sa création dans
-- 20260825090500_create_character_options_tables.sql ou équivalent).
--
-- Contexte légal, différent des sous-classes (20260905000000) : les 32
-- invocations mystiques du cœur de règles (aucune extension type
-- Xanathar's/Tasha's) sont couvertes par la révision CC-BY 4.0 de janvier
-- 2023 du System Reference Document 5.1 (confirmé via l'API Open5e,
-- document `srd-2014`, licence CC-BY 4.0 + OGL 1.0a — le texte source
-- anglais provient de la description de classe Occultiste exposée par
-- cette API). Contrairement aux 91 sous-classes Phase 5, ce texte est donc
-- une TRADUCTION FIDÈLE du texte source ouvert, pas une reformulation
-- distanciée — la licence CC-BY autorise la reproduction/traduction
-- proche, à condition de créditer la source (voir
-- `07-source-donnees-i18n.md` : mention à ajouter aux mentions légales de
-- l'app, pas encore rédigées).
--
-- Noms de sorts référencés dans les prérequis/descriptions alignés sur les
-- traductions déjà en base (`public.spells`/`public.translations`) plutôt
-- que retraduits indépendamment : Décharge occulte (eldritch blast),
-- Armure de mage (mage armor), Lévitation (levitate), Parole avec les
-- animaux (speak with animals), Compulsion, Immobilisation de monstre
-- (hold monster), Détection de la magie (detect magic), Simulacre de vie
-- (false life), Déguisement (disguise self), Modification d'apparence
-- (alter self), Convocation d'élémentaire (conjure elemental), Lenteur
-- (slow), Image silencieuse (silent image), Bond (jump), Métamorphose
-- (polymorph), Malédiction (bestow curse), Maléfice (bane), Oeil magique
-- (arcane eye), Communication avec les morts (speak with dead).
--
-- `prerequisites` reste un simple texte français libre dans le jsonb
-- (`{"text": "..."}`, `{}` si aucun) : aucune fonctionnalité mobile ne
-- consomme encore cette table (vérifié, aucune référence à `invocations`
-- dans le dépôt mobile) — une structure plus fine sera définie quand
-- l'écran "choisir une invocation" sera réellement construit, plutôt que
-- de deviner un contrat aujourd'hui.

do $$
declare
  rec record;
  v_id int;
begin
  for rec in
    select * from (values
      ('Décharge agonisante', '{"text": "Sort mineur Décharge occulte"}'::jsonb,
        $j$Lorsque vous lancez Décharge occulte, ajoutez votre modificateur de Charisme aux dégâts infligés en cas de touche.$j$),
      ('Armure des ombres', '{}'::jsonb,
        $j$Vous pouvez lancer Armure de mage sur vous-même à volonté, sans dépenser d'emplacement de sort ni de composante matérielle.$j$),
      ('Pas ascendant', '{"text": "Niveau 9"}'::jsonb,
        $j$Vous pouvez lancer Lévitation sur vous-même à volonté, sans dépenser d'emplacement de sort ni de composante matérielle.$j$),
      ('Langage des bêtes', '{}'::jsonb,
        $j$Vous pouvez lancer Parole avec les animaux à volonté, sans dépenser d'emplacement de sort.$j$),
      ('Influence trompeuse', '{}'::jsonb,
        $j$Vous gagnez la maîtrise des compétences Tromperie et Persuasion.$j$),
      ('Murmures ensorcelants', '{"text": "Niveau 7"}'::jsonb,
        $j$Vous pouvez lancer Compulsion une fois en utilisant un emplacement de sort d'occultiste. Vous ne pouvez pas recommencer avant d'avoir terminé un repos long.$j$),
      ('Livre des secrets anciens', '{"text": "Aptitude Pacte du grimoire"}'::jsonb,
        $j$Vous pouvez désormais inscrire des rituels magiques dans votre Livre des Ombres. Choisissez deux sorts de niveau 1 possédant la mention rituel, tirés de la liste de n'importe quelle classe (pas nécessairement la même) ; ils ne comptent pas dans le nombre de sorts que vous connaissez et peuvent être lancés en rituel tant que vous tenez votre Livre des Ombres en main. Vous pouvez aussi lancer en rituel tout sort d'occultiste que vous connaissez possédant cette mention, et ajouter d'autres sorts rituels trouvés en aventure si leur niveau n'excède pas la moitié de votre niveau d'occultiste (arrondi supérieur), moyennant du temps et des matériaux pour les transcrire.$j$),
      ('Chaînes de Carceri', '{"text": "Niveau 15, aptitude Pacte de la chaîne"}'::jsonb,
        $j$Vous pouvez lancer Immobilisation de monstre à volonté sur un céleste, un démon ou un élémentaire, sans dépenser d'emplacement de sort ni de composante matérielle. Vous devez terminer un repos long avant de pouvoir cibler à nouveau la même créature avec cette invocation.$j$),
      ('Vision du diable', '{}'::jsonb,
        $j$Vous voyez normalement dans le noir, magique ou non, jusqu'à 36 mètres.$j$),
      ('Parole funeste', '{"text": "Niveau 7"}'::jsonb,
        $j$Vous pouvez lancer Confusion une fois en utilisant un emplacement de sort d'occultiste. Vous ne pouvez pas recommencer avant d'avoir terminé un repos long.$j$),
      ('Vue occulte', '{}'::jsonb,
        $j$Vous pouvez lancer Détection de la magie à volonté, sans dépenser d'emplacement de sort.$j$),
      ('Lance occulte', '{"text": "Sort mineur Décharge occulte"}'::jsonb,
        $j$Lorsque vous lancez Décharge occulte, sa portée passe à 90 mètres.$j$),
      ('Yeux du gardien des runes', '{}'::jsonb,
        $j$Vous pouvez lire n'importe quelle écriture.$j$),
      ('Vigueur fiélonne', '{}'::jsonb,
        $j$Vous pouvez lancer Simulacre de vie sur vous-même à volonté, comme un sort de niveau 1, sans dépenser d'emplacement de sort ni de composante matérielle.$j$),
      ('Regard des deux esprits', '{}'::jsonb,
        $j$Vous pouvez utiliser votre action pour toucher un humanoïde consentant et percevoir par ses sens jusqu'à la fin de votre prochain tour ; tant qu'il reste sur le même plan d'existence que vous, vous pouvez prolonger ce lien tour après tour. Pendant ce temps, vous bénéficiez de ses sens particuliers, mais vous êtes aveuglé et assourdi quant à votre propre environnement.$j$),
      ('Buveur de vie', '{"text": "Niveau 12, aptitude Pacte de la lame"}'::jsonb,
        $j$Lorsque vous touchez une créature avec votre arme de pacte, elle subit des dégâts nécrotiques supplémentaires égaux à votre modificateur de Charisme (au moins 1).$j$),
      ('Masque aux mille visages', '{}'::jsonb,
        $j$Vous pouvez lancer Déguisement à volonté, sans dépenser d'emplacement de sort.$j$),
      ('Maître des mille formes', '{"text": "Niveau 15"}'::jsonb,
        $j$Vous pouvez lancer Modification d'apparence à volonté, sans dépenser d'emplacement de sort.$j$),
      ('Serviteurs du chaos', '{"text": "Niveau 9"}'::jsonb,
        $j$Vous pouvez lancer Convocation d'élémentaire une fois en utilisant un emplacement de sort d'occultiste. Vous ne pouvez pas recommencer avant d'avoir terminé un repos long.$j$),
      ('Engluer l''esprit', '{"text": "Niveau 5"}'::jsonb,
        $j$Vous pouvez lancer Lenteur une fois en utilisant un emplacement de sort d'occultiste. Vous ne pouvez pas recommencer avant d'avoir terminé un repos long.$j$),
      ('Visions brumeuses', '{}'::jsonb,
        $j$Vous pouvez lancer Image silencieuse à volonté, sans dépenser d'emplacement de sort ni de composante matérielle.$j$),
      ('Un avec les ombres', '{"text": "Niveau 5"}'::jsonb,
        $j$Lorsque vous vous trouvez dans une zone de pénombre ou d'obscurité, vous pouvez utiliser votre action pour devenir invisible jusqu'à ce que vous bougiez ou effectuiez une action ou une réaction.$j$),
      ('Bond d''un autre monde', '{"text": "Niveau 9"}'::jsonb,
        $j$Vous pouvez lancer Bond sur vous-même à volonté, sans dépenser d'emplacement de sort ni de composante matérielle.$j$),
      ('Décharge repoussante', '{"text": "Sort mineur Décharge occulte"}'::jsonb,
        $j$Lorsque vous touchez une créature avec Décharge occulte, vous pouvez la repousser en ligne droite jusqu'à 3 mètres.$j$),
      ('Sculpteur de chair', '{"text": "Niveau 7"}'::jsonb,
        $j$Vous pouvez lancer Métamorphose une fois en utilisant un emplacement de sort d'occultiste. Vous ne pouvez pas recommencer avant d'avoir terminé un repos long.$j$),
      ('Signe de mauvais augure', '{"text": "Niveau 5"}'::jsonb,
        $j$Vous pouvez lancer Malédiction une fois en utilisant un emplacement de sort d'occultiste. Vous ne pouvez pas recommencer avant d'avoir terminé un repos long.$j$),
      ('Voleur des cinq destins', '{}'::jsonb,
        $j$Vous pouvez lancer Maléfice une fois en utilisant un emplacement de sort d'occultiste. Vous ne pouvez pas recommencer avant d'avoir terminé un repos long.$j$),
      ('Lame assoiffée', '{"text": "Niveau 5, aptitude Pacte de la lame"}'::jsonb,
        $j$Vous pouvez attaquer deux fois avec votre arme de pacte, au lieu d'une, chaque fois que vous effectuez l'action Attaque à votre tour.$j$),
      ('Visions des royaumes lointains', '{"text": "Niveau 15"}'::jsonb,
        $j$Vous pouvez lancer Oeil magique à volonté, sans dépenser d'emplacement de sort.$j$),
      ('Voix du maître de la chaîne', '{"text": "Aptitude Pacte de la chaîne"}'::jsonb,
        $j$Vous pouvez communiquer par télépathie avec votre familier et percevoir par ses sens tant que vous êtes sur le même plan d'existence que lui. Vous pouvez également parler à travers lui de votre propre voix, même s'il en est normalement incapable.$j$),
      ('Murmures de la tombe', '{"text": "Niveau 9"}'::jsonb,
        $j$Vous pouvez lancer Communication avec les morts à volonté, sans dépenser d'emplacement de sort.$j$),
      ('Vision de sorcière', '{"text": "Niveau 15"}'::jsonb,
        $j$Vous pouvez percevoir la véritable forme de tout métamorphe ou de toute créature dissimulée par une magie d'illusion ou de transmutation, tant qu'elle se trouve à moins de 9 mètres de vous et dans votre ligne de vue.$j$)
    ) as t(name, prerequisites, description)
  loop
    if not exists (
      select 1 from public.translations
      where entity_type = 'invocation' and field_name = 'name' and locale = 'fr' and value = rec.name
    ) then
      insert into public.invocations (prerequisites) values (rec.prerequisites)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('invocation', v_id::text, 'name', 'fr', rec.name),
        ('invocation', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;
