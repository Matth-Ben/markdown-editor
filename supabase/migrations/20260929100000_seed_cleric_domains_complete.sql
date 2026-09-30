-- Contenu D&D — Domaines divins du Clerc : ajout des domaines manquants et
-- complétion des domaines incomplets.
--
-- État avant cette migration (vérifié en base le 2026-09-29) : 10 domaines,
-- dont 8 complets (Vie, Duperie, Guerre, Lumière, Nature, Savoir, Tempête,
-- Forge) et 2 réduits à leur seule aptitude « signature » posée par
-- 20260905000000_seed_subclass_signature_features.sql :
--   - Crépuscule (Tasha) : seulement « Vision de la nuit » (niv. 1) ;
--   - Tombe (Xanathar)   : seulement « Cercle de mortalité » (niv. 1).
--
-- Cette migration :
--   1. ajoute les 4 domaines officiels absents : Arcanes (Sword Coast
--      Adventurer's Guide), Mort (Guide du maître), Ordre et Paix (Tasha) ;
--   2. leur pose leurs sorts de domaine (public.subclass_spells) ;
--   3. ajoute la progression complète d'aptitudes des 6 domaines concernés
--      (4 nouveaux + Crépuscule + Tombe), y compris les lignes « Sorts de
--      domaine (Niveau de clerc n) » (choice_type sort_domaine) comme pour les
--      autres domaines.
--
-- Textes : reformulés en texte original, jamais copiés du livre — même règle
-- que 20260910130000_seed_class_features_non_srd_progression.sql.
--
-- Sort « Héroïsme » (niv. 1, domaines de l'Ordre et de la Paix) : absent de
-- public.spells à la date de cette migration. Il est cité dans la description
-- de l'aptitude « Sorts de domaine (Niveau de clerc 1) » mais n'a pas de ligne
-- subclass_spells — à rattacher quand le sort sera ajouté au catalogue.
--
-- Idempotente : garde `if not exists` par (classe, nom) pour les domaines, par
-- (sous-classe, niveau, nom) pour les aptitudes, `on conflict` pour les sorts.

-- ---------------------------------------------------------------------------
-- 1. Domaines manquants
-- ---------------------------------------------------------------------------

do $$
declare
  rec record;
  v_id int;
begin
  for rec in
    select * from (values
      ('Arcanes', $j$Domaine de la magie savante : le clerc étudie les arcanes à la manière d'un magicien, repousse les créatures venues d'autres plans et finit par maîtriser de puissants sorts de magicien.$j$),
      ('Mort', $j$Domaine sombre voué aux forces qui mettent fin à la vie : magie nécromantique renforcée et dégâts nécrotiques capables de percer les résistances.$j$),
      ('Ordre', $j$Domaine de la loi et de la discipline : le clerc galvanise ses alliés lorsqu'il les cible de ses sorts et impose sa volonté à ses ennemis par la magie d'enchantement.$j$),
      ('Paix', $j$Domaine de l'harmonie et de la concorde : le clerc tisse entre ses compagnons des liens magiques qui leur permettent de s'épauler et de se protéger mutuellement.$j$)
    ) as t(name, description)
  loop
    if not exists (
      select 1
      from public.subclasses sc
      join public.translations st
        on st.entity_id = sc.id::text
        and st.entity_type = 'subclass' and st.field_name = 'name' and st.locale = 'fr'
      where sc.class_id = 3 and st.value = rec.name
    ) then
      insert into public.subclasses (class_id, available_from_level)
        values (3, 1)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('subclass', v_id::text, 'name', 'fr', rec.name),
        ('subclass', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Sorts de domaine des nouveaux domaines
-- ---------------------------------------------------------------------------

do $$
declare
  rec record;
  v_subclass integer;
  v_spell integer;
  v_inserted integer := 0;
begin
  for rec in
    select * from (values
      ($sp$Arcanes$sp$, 1, $sp$Détection de la magie$sp$, 1),
      ($sp$Arcanes$sp$, 1, $sp$Projectile magique$sp$, 1),
      ($sp$Arcanes$sp$, 3, $sp$Arme magique$sp$, 2),
      ($sp$Arcanes$sp$, 3, $sp$Aura magique de Nystul$sp$, 2),
      ($sp$Arcanes$sp$, 5, $sp$Dissipation de la magie$sp$, 3),
      ($sp$Arcanes$sp$, 5, $sp$Cercle magique$sp$, 3),
      ($sp$Arcanes$sp$, 7, $sp$Oeil magique$sp$, 4),
      ($sp$Arcanes$sp$, 7, $sp$Coffre secret de Léomund$sp$, 4),
      ($sp$Arcanes$sp$, 9, $sp$Contrat$sp$, 5),
      ($sp$Arcanes$sp$, 9, $sp$Cercle de téléportation$sp$, 5),
      ($sp$Mort$sp$, 1, $sp$Simulacre de vie$sp$, 1),
      ($sp$Mort$sp$, 1, $sp$Rayon empoisonné$sp$, 1),
      ($sp$Mort$sp$, 3, $sp$Cécité/Surdité$sp$, 2),
      ($sp$Mort$sp$, 3, $sp$Rayon affaiblissant$sp$, 2),
      ($sp$Mort$sp$, 5, $sp$Animation des morts$sp$, 3),
      ($sp$Mort$sp$, 5, $sp$Toucher du vampire$sp$, 3),
      ($sp$Mort$sp$, 7, $sp$Flétrissement$sp$, 4),
      ($sp$Mort$sp$, 7, $sp$Protection contre la mort$sp$, 4),
      ($sp$Mort$sp$, 9, $sp$Coquille antivie$sp$, 5),
      ($sp$Mort$sp$, 9, $sp$Brume mortelle$sp$, 5),
      ($sp$Ordre$sp$, 1, $sp$Injonction$sp$, 1),
      ($sp$Ordre$sp$, 3, $sp$Immobilisation de personne$sp$, 2),
      ($sp$Ordre$sp$, 3, $sp$Zone de vérité$sp$, 2),
      ($sp$Ordre$sp$, 5, $sp$Mot de guérison de groupe$sp$, 3),
      ($sp$Ordre$sp$, 5, $sp$Lenteur$sp$, 3),
      ($sp$Ordre$sp$, 7, $sp$Compulsion$sp$, 4),
      ($sp$Ordre$sp$, 7, $sp$Localisation de créature$sp$, 4),
      ($sp$Ordre$sp$, 9, $sp$Communion$sp$, 5),
      ($sp$Ordre$sp$, 9, $sp$Domination de personne$sp$, 5),
      ($sp$Paix$sp$, 1, $sp$Sanctuaire$sp$, 1),
      ($sp$Paix$sp$, 3, $sp$Aide$sp$, 2),
      ($sp$Paix$sp$, 3, $sp$Lien de protection$sp$, 2),
      ($sp$Paix$sp$, 5, $sp$Lueur d'espoir$sp$, 3),
      ($sp$Paix$sp$, 5, $sp$Communication à distance$sp$, 3),
      ($sp$Paix$sp$, 7, $sp$Aura de pureté$sp$, 4),
      ($sp$Paix$sp$, 7, $sp$Sphère résiliente d'Otiluke$sp$, 4),
      ($sp$Paix$sp$, 9, $sp$Restauration supérieure$sp$, 5),
      ($sp$Paix$sp$, 9, $sp$Lien télépathique de Rary$sp$, 5)
    ) as t(subclass_name, class_level, spell_name, spell_level)
  loop
    select sc.id into strict v_subclass
      from public.subclasses sc
      join public.translations tr
        on tr.entity_type = 'subclass' and tr.entity_id = sc.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where tr.value = rec.subclass_name and sc.class_id = 3;

    select sp.id into strict v_spell
      from public.spells sp
      join public.translations tr
        on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where tr.value = rec.spell_name and sp.level = rec.spell_level and not sp.is_incomplete;

    insert into public.subclass_spells (subclass_id, spell_id, class_level, grant_kind)
      values (v_subclass, v_spell, rec.class_level, 'always_prepared')
      on conflict (subclass_id, spell_id) do update set class_level = excluded.class_level;
    v_inserted := v_inserted + 1;
  end loop;
  if v_inserted <> 38 then
    raise exception 'subclass_spells (domaines) : % lignes traitées, 38 attendues', v_inserted;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Aptitudes des domaines (nouveaux + Crépuscule + Tombe)
-- ---------------------------------------------------------------------------

do $$
declare
  rec record;
  v_subclass int;
  v_id int;
begin
  for rec in
    select * from (values
      -- Arcanes
      ('Arcanes', 1, $q$Sorts de domaine (Niveau de clerc 1)$q$, $q$Sorts de domaine toujours préparés : Détection de la magie, Projectile magique.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Arcanes', 3, $q$Sorts de domaine (Niveau de clerc 3)$q$, $q$Sorts de domaine toujours préparés : Arme magique, Aura magique de Nystul.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Arcanes', 5, $q$Sorts de domaine (Niveau de clerc 5)$q$, $q$Sorts de domaine toujours préparés : Cercle magique, Dissipation de la magie.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Arcanes', 7, $q$Sorts de domaine (Niveau de clerc 7)$q$, $q$Sorts de domaine toujours préparés : Coffre secret de Léomund, Oeil magique.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Arcanes', 9, $q$Sorts de domaine (Niveau de clerc 9)$q$, $q$Sorts de domaine toujours préparés : Cercle de téléportation, Contrat.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Arcanes', 1, $q$Initié des arcanes$q$, $q$Vous maîtrisez la compétence Arcanes. Vous apprenez aussi deux sorts mineurs de votre choix dans la liste du magicien ; ils sont pour vous des sorts mineurs de clerc.$q$, null, null::jsonb),
      ('Arcanes', 2, $q$Conduit divin : abjuration arcanique$q$, $q$Par une action, vous brandissez votre symbole sacré face à un céleste, un élémentaire, une fée ou un fiélon situé à 9 m ou moins. S'il rate un jet de sauvegarde de Sagesse, il est repoussé pendant 1 minute ou jusqu'à ce qu'il subisse des dégâts. À partir du niveau 5, une créature de facteur de puissance assez faible (même seuil que Destruction des morts-vivants) est bannie pendant 1 minute au lieu d'être repoussée.$q$, null, null::jsonb),
      ('Arcanes', 6, $q$Briseur de sorts$q$, $q$Quand vous rendez des points de vie à un allié grâce à un sort de niveau 1 ou plus, vous pouvez en même temps mettre fin à un sort de votre choix qui l'affecte, à condition que son niveau ne dépasse pas celui de l'emplacement utilisé.$q$, null, null::jsonb),
      ('Arcanes', 8, $q$Incantation puissante$q$, $q$Vous ajoutez votre modificateur de Sagesse aux dégâts infligés par vos sorts mineurs de clerc.$q$, null, null::jsonb),
      ('Arcanes', 17, $q$Maîtrise des arcanes$q$, $q$Vous choisissez quatre sorts dans la liste du magicien : un de niveau 6, un de niveau 7, un de niveau 8 et un de niveau 9. Ils deviennent des sorts de domaine pour vous, toujours préparés.$q$, null, null::jsonb),

      -- Mort
      ('Mort', 1, $q$Sorts de domaine (Niveau de clerc 1)$q$, $q$Sorts de domaine toujours préparés : Rayon empoisonné, Simulacre de vie.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Mort', 3, $q$Sorts de domaine (Niveau de clerc 3)$q$, $q$Sorts de domaine toujours préparés : Cécité/Surdité, Rayon affaiblissant.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Mort', 5, $q$Sorts de domaine (Niveau de clerc 5)$q$, $q$Sorts de domaine toujours préparés : Animation des morts, Toucher du vampire.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Mort', 7, $q$Sorts de domaine (Niveau de clerc 7)$q$, $q$Sorts de domaine toujours préparés : Flétrissement, Protection contre la mort.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Mort', 9, $q$Sorts de domaine (Niveau de clerc 9)$q$, $q$Sorts de domaine toujours préparés : Brume mortelle, Coquille antivie.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Mort', 1, $q$Maîtrises supplémentaires$q$, $q$Vous gagnez la maîtrise des armes de guerre.$q$, null, null::jsonb),
      ('Mort', 1, $q$Faucheur$q$, $q$Vous apprenez un sort mineur de nécromancie de votre choix, quelle que soit sa liste. Quand vous lancez un sort mineur de nécromancie qui ne vise normalement qu'une créature, vous pouvez en viser deux, à condition qu'elles soient à 1,50 m ou moins l'une de l'autre.$q$, null, null::jsonb),
      ('Mort', 2, $q$Conduit divin : toucher de la mort$q$, $q$Quand vous touchez une créature avec une attaque au corps à corps, vous pouvez utiliser votre Conduit divin pour lui infliger en plus des dégâts nécrotiques égaux à 5 + deux fois votre niveau de clerc.$q$, null, null::jsonb),
      ('Mort', 6, $q$Destruction inéluctable$q$, $q$Les dégâts nécrotiques infligés par vos sorts de clerc et par votre Conduit divin ignorent la résistance aux dégâts nécrotiques.$q$, null, null::jsonb),
      ('Mort', 8, $q$Frappe divine$q$, $q$Une fois par tour, vous pouvez ajouter 1d8 dégâts nécrotiques (2d8 au niveau 14) sur une attaque d'arme réussie.$q$, null, null::jsonb),
      ('Mort', 17, $q$Faucheur amélioré$q$, $q$Quand vous lancez un sort de nécromancie de niveau 1 à 5 qui ne vise qu'une créature, vous pouvez en viser deux, situées à 1,50 m ou moins l'une de l'autre. Si le sort consomme des composantes matérielles, vous devez les fournir pour chaque cible.$q$, null, null::jsonb),

      -- Ordre
      ('Ordre', 1, $q$Sorts de domaine (Niveau de clerc 1)$q$, $q$Sorts de domaine toujours préparés : Héroïsme, Injonction.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Ordre', 3, $q$Sorts de domaine (Niveau de clerc 3)$q$, $q$Sorts de domaine toujours préparés : Immobilisation de personne, Zone de vérité.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Ordre', 5, $q$Sorts de domaine (Niveau de clerc 5)$q$, $q$Sorts de domaine toujours préparés : Lenteur, Mot de guérison de groupe.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Ordre', 7, $q$Sorts de domaine (Niveau de clerc 7)$q$, $q$Sorts de domaine toujours préparés : Compulsion, Localisation de créature.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Ordre', 9, $q$Sorts de domaine (Niveau de clerc 9)$q$, $q$Sorts de domaine toujours préparés : Communion, Domination de personne.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Ordre', 1, $q$Maîtrises supplémentaires$q$, $q$Vous gagnez la maîtrise des armures lourdes, ainsi que celle d'une compétence au choix : Intimidation ou Persuasion.$q$, null, null::jsonb),
      ('Ordre', 1, $q$Voix de l'autorité$q$, $q$Quand vous lancez un sort de niveau 1 ou plus qui cible un allié, celui-ci peut, juste après le sort, utiliser sa réaction pour faire une attaque avec une arme contre une créature de votre choix que vous voyez.$q$, null, null::jsonb),
      ('Ordre', 2, $q$Conduit divin : exigence de l'ordre$q$, $q$Par une action, vous utilisez votre Conduit divin : chaque créature de votre choix à 9 m ou moins qui peut vous voir ou vous entendre doit réussir un jet de sauvegarde de Sagesse, sans quoi elle est charmée par vous jusqu'à la fin de votre prochain tour ou jusqu'à ce qu'elle subisse des dégâts. Vous pouvez aussi forcer les créatures charmées à lâcher ce qu'elles tiennent.$q$, null, null::jsonb),
      ('Ordre', 6, $q$Incarnation de la loi$q$, $q$Quand vous lancez un sort d'enchantement de niveau 1 ou plus dont le temps d'incantation est d'une action, vous pouvez le lancer par une action bonus à la place. Utilisable un nombre de fois égal à votre modificateur de Sagesse (minimum 1) par repos long.$q$, null, '{"amount": null, "rest_type": "repos_long"}'::jsonb),
      ('Ordre', 8, $q$Frappe divine$q$, $q$Une fois par tour, vous pouvez ajouter 1d8 dégâts psychiques (2d8 au niveau 14) sur une attaque d'arme réussie.$q$, null, null::jsonb),
      ('Ordre', 17, $q$Courroux de l'ordre$q$, $q$Quand votre Frappe divine touche une créature pendant votre tour, vous pouvez la maudire jusqu'au début de votre prochain tour. La prochaine fois qu'un de vos alliés la touche avec une attaque, elle subit 2d8 dégâts psychiques supplémentaires et la malédiction prend fin. Une fois par tour.$q$, null, null::jsonb),

      -- Paix
      ('Paix', 1, $q$Sorts de domaine (Niveau de clerc 1)$q$, $q$Sorts de domaine toujours préparés : Héroïsme, Sanctuaire.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Paix', 3, $q$Sorts de domaine (Niveau de clerc 3)$q$, $q$Sorts de domaine toujours préparés : Aide, Lien de protection.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Paix', 5, $q$Sorts de domaine (Niveau de clerc 5)$q$, $q$Sorts de domaine toujours préparés : Communication à distance, Lueur d'espoir.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Paix', 7, $q$Sorts de domaine (Niveau de clerc 7)$q$, $q$Sorts de domaine toujours préparés : Aura de pureté, Sphère résiliente d'Otiluke.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Paix', 9, $q$Sorts de domaine (Niveau de clerc 9)$q$, $q$Sorts de domaine toujours préparés : Lien télépathique de Rary, Restauration supérieure.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Paix', 1, $q$Instrument de paix$q$, $q$Vous gagnez la maîtrise d'une compétence au choix : Intuition, Représentation ou Persuasion.$q$, null, null::jsonb),
      ('Paix', 1, $q$Lien d'encouragement$q$, $q$Par une action, vous liez un nombre de créatures consentantes égal à votre bonus de maîtrise, à 9 m ou moins (vous pouvez vous inclure), pendant 10 minutes. Une fois par tour, une créature liée qui se trouve à 9 m ou moins d'une autre créature liée peut ajouter 1d4 à un jet d'attaque, un test de caractéristique ou un jet de sauvegarde. Utilisable un nombre de fois égal à votre bonus de maîtrise par repos long.$q$, null, '{"amount": null, "rest_type": "repos_long"}'::jsonb),
      ('Paix', 2, $q$Conduit divin : baume de paix$q$, $q$Par une action, vous utilisez votre Conduit divin pour vous déplacer jusqu'à votre vitesse sans provoquer d'attaque d'opportunité. Chaque créature de votre choix dont vous passez à 1,50 m ou moins pendant ce déplacement récupère 2d6 + votre modificateur de Sagesse points de vie (une seule fois par créature).$q$, null, null::jsonb),
      ('Paix', 6, $q$Lien protecteur$q$, $q$Quand une créature liée par votre Lien d'encouragement va subir des dégâts, une autre créature liée à 9 m ou moins peut utiliser sa réaction pour se téléporter à 1,50 m d'elle et subir tous ces dégâts à sa place.$q$, null, null::jsonb),
      ('Paix', 8, $q$Incantation puissante$q$, $q$Vous ajoutez votre modificateur de Sagesse aux dégâts infligés par vos sorts mineurs de clerc.$q$, null, null::jsonb),
      ('Paix', 17, $q$Lien étendu$q$, $q$La portée de votre Lien d'encouragement et de votre Lien protecteur passe à 18 m. Une créature qui encaisse des dégâts à la place d'une autre grâce au Lien protecteur a la résistance à ces dégâts.$q$, null, null::jsonb),

      -- Crépuscule (« Vision de la nuit », niv. 1, déjà en base)
      ('Crépuscule', 1, $q$Sorts de domaine (Niveau de clerc 1)$q$, $q$Sorts de domaine toujours préparés : Feu follet, Sommeil.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Crépuscule', 3, $q$Sorts de domaine (Niveau de clerc 3)$q$, $q$Sorts de domaine toujours préparés : Rayon de lune, Voir l'invisible.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Crépuscule', 5, $q$Sorts de domaine (Niveau de clerc 5)$q$, $q$Sorts de domaine toujours préparés : Aura de vitalité, Petite hutte de Léomund.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Crépuscule', 7, $q$Sorts de domaine (Niveau de clerc 7)$q$, $q$Sorts de domaine toujours préparés : Aura de vie, Invisibilité supérieure.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Crépuscule', 9, $q$Sorts de domaine (Niveau de clerc 9)$q$, $q$Sorts de domaine toujours préparés : Cercle de pouvoir, Double illusoire.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Crépuscule', 1, $q$Maîtrises supplémentaires$q$, $q$Vous gagnez la maîtrise des armes de guerre et des armures lourdes.$q$, null, null::jsonb),
      ('Crépuscule', 1, $q$Bénédiction vigilante$q$, $q$Par une action, vous accordez à une créature (vous compris) l'avantage à son prochain jet d'initiative. L'effet prend fin après ce jet ou si vous l'utilisez de nouveau.$q$, null, null::jsonb),
      ('Crépuscule', 2, $q$Conduit divin : sanctuaire crépusculaire$q$, $q$Par une action, vous utilisez votre Conduit divin pour faire naître autour de vous, pendant 1 minute, une sphère de 9 m de rayon baignée de lumière faible qui se déplace avec vous. Quand une créature de votre choix termine son tour dans la sphère, vous pouvez soit lui donner 1d6 + votre niveau de clerc points de vie temporaires, soit mettre fin à un effet qui la charme ou l'effraie.$q$, null, null::jsonb),
      ('Crépuscule', 6, $q$Pas de la nuit$q$, $q$Par une action bonus, lorsque vous êtes dans une zone de lumière faible ou d'obscurité, vous gagnez une vitesse de vol égale à votre vitesse de marche pendant 1 minute. Utilisable un nombre de fois égal à votre bonus de maîtrise par repos long.$q$, null, '{"amount": null, "rest_type": "repos_long"}'::jsonb),
      ('Crépuscule', 8, $q$Frappe divine$q$, $q$Une fois par tour, vous pouvez ajouter 1d8 dégâts radiants (2d8 au niveau 14) sur une attaque d'arme réussie.$q$, null, null::jsonb),
      ('Crépuscule', 17, $q$Linceul crépusculaire$q$, $q$Vous et vos alliés bénéficiez d'un abri partiel tant que vous vous trouvez dans la sphère de votre Sanctuaire crépusculaire.$q$, null, null::jsonb),

      -- Tombe (« Cercle de mortalité », niv. 1, déjà en base)
      ('Tombe', 1, $q$Sorts de domaine (Niveau de clerc 1)$q$, $q$Sorts de domaine toujours préparés : Flétrissure, Simulacre de vie.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Tombe', 3, $q$Sorts de domaine (Niveau de clerc 3)$q$, $q$Sorts de domaine toujours préparés : Préservation des morts, Rayon affaiblissant.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Tombe', 5, $q$Sorts de domaine (Niveau de clerc 5)$q$, $q$Sorts de domaine toujours préparés : Retour à la vie, Toucher du vampire.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Tombe', 7, $q$Sorts de domaine (Niveau de clerc 7)$q$, $q$Sorts de domaine toujours préparés : Flétrissement, Protection contre la mort.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Tombe', 9, $q$Sorts de domaine (Niveau de clerc 9)$q$, $q$Sorts de domaine toujours préparés : Coquille antivie, Rappel à la vie.$q$, $q$sort_domaine$q$, null::jsonb),
      ('Tombe', 1, $q$Yeux de la tombe$q$, $q$Par une action, vous percevez jusqu'à la fin de votre prochain tour l'emplacement de tout mort-vivant situé à 18 m ou moins qui n'est ni derrière un abri total ni protégé contre la divination. Utilisable un nombre de fois égal à votre modificateur de Sagesse (minimum 1) par repos long.$q$, null, '{"amount": null, "rest_type": "repos_long"}'::jsonb),
      ('Tombe', 2, $q$Conduit divin : chemin vers la tombe$q$, $q$Par une action, vous utilisez votre Conduit divin pour maudire une créature que vous voyez à 9 m ou moins, jusqu'à la fin de votre prochain tour. La prochaine fois que vous ou un allié la touchez avec une attaque, elle est vulnérable à tous les dégâts de cette attaque, puis la malédiction prend fin.$q$, null, null::jsonb),
      ('Tombe', 6, $q$Sentinelle au seuil de la mort$q$, $q$Par une réaction, lorsque vous ou une créature que vous voyez à 9 m ou moins subissez un coup critique, vous le transformez en coup normal. Utilisable un nombre de fois égal à votre modificateur de Sagesse (minimum 1) par repos long.$q$, null, '{"amount": null, "rest_type": "repos_long"}'::jsonb),
      ('Tombe', 8, $q$Incantation puissante$q$, $q$Vous ajoutez votre modificateur de Sagesse aux dégâts infligés par vos sorts mineurs de clerc.$q$, null, null::jsonb),
      ('Tombe', 17, $q$Gardien des âmes$q$, $q$Une fois par round, quand un ennemi que vous voyez meurt à 18 m ou moins, vous ou une créature de votre choix à 18 m ou moins récupérez un nombre de points de vie égal au nombre de dés de vie de cet ennemi. Sans effet si l'ennemi était un artificiel ou un mort-vivant.$q$, null, null::jsonb)
    ) as t(subclass_name, level, name, description, choice_type, uses_per_rest)
  loop
    select sc.id into strict v_subclass
      from public.subclasses sc
      join public.translations tr
        on tr.entity_type = 'subclass' and tr.entity_id = sc.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where tr.value = rec.subclass_name and sc.class_id = 3;

    if not exists (
      select 1 from public.class_features cf
      join public.translations n on n.entity_type = 'class_feature' and n.entity_id = cf.id::text and n.field_name = 'name' and n.locale = 'fr'
      where cf.subclass_id = v_subclass and cf.level = rec.level and n.value = rec.name
    ) then
      insert into public.class_features (class_id, subclass_id, level, choice_type, uses_per_rest)
        values (null, v_subclass, rec.level, rec.choice_type, rec.uses_per_rest)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('class_feature', v_id::text, 'name', 'fr', rec.name),
        ('class_feature', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;
