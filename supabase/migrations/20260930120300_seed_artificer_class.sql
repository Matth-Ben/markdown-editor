-- Lot 5d de l'import du contenu de référence : classe Artificier (Chaudron de Tasha), ses
-- aptitudes de classe, ses 4 sous-classes (Alchimiste, Armurier, Artilleur, Forgeron de guerre)
-- et sa liste de sorts (liens spell_classes vers les sorts déjà en base).
-- Texte français reformulé. Idempotente (classe repérée par son nom FR).

do $$
declare
  v_class int;
  v_id int;
  v_sub int;
  rec record;
begin
  select c.id into v_class
    from public.classes c
    join public.translations tr
      on tr.entity_type = 'class' and tr.entity_id = c.id::text
     and tr.field_name = 'name' and tr.locale = 'fr'
   where lower(tr.value) = 'artificier'
   limit 1;

  if v_class is null then
    insert into public.classes (source, hit_die, primary_abilities, saving_throw_proficiencies,
                                armor_proficiencies, weapon_proficiencies, tool_proficiencies, skill_choices)
      values ($t$Chaudron de Tasha$t$, 8, '["int"]'::jsonb, '["con","int"]'::jsonb,
              $t$["légère","intermédiaire","boucliers"]$t$::jsonb,
              $t$["courantes"]$t$::jsonb,
              $t$["outils de voleur","outils de bricoleur","un type d'outils d'artisan"]$t$::jsonb,
              $t${"count":2,"choices":["Arcanes","Histoire","Investigation","Médecine","Nature","Perception","Escamotage"]}$t$::jsonb)
      returning id into v_class;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('class', v_class::text, 'name', 'fr', $t$Artificier$t$),
      ('class', v_class::text, 'name', 'en', $t$Artificer$t$),
      ('class', v_class::text, 'description', 'fr', $t$Inventeur qui canalise la magie à travers des objets : il infuse l'équipement de pouvoirs, lance des sorts à l'aide d'outils et crée des merveilles mécaniques. Lanceur de sorts à demi basé sur l'Intelligence.$t$);
  end if;

  -- Aptitudes de classe
  for rec in
    select * from (values
  (1, null::text, $t$Bricolage magique$t$, $t$Magical Tinkering$t$, $t$Avec des outils de voleur ou d'artisan en main, par une action, vous imprégnez un objet minuscule non magique d'une propriété mineure : lumière, message enregistré, odeur ou son, ou image/inscription statique. Nombre d'objets simultanés égal à votre modificateur d'Intelligence.$t$),
  (1, null, $t$Incantation$t$, $t$Spellcasting$t$, $t$Vous lancez des sorts d'artificier avec l'Intelligence comme caractéristique d'incantation, en utilisant des outils (de voleur ou d'artisan) comme focaliseur. Vous préparez un nombre de sorts égal à votre modificateur d'Intelligence + la moitié de votre niveau d'artificier (arrondie au supérieur). Vous pouvez lancer vos sorts préparés comme rituels s'ils ont cette étiquette.$t$),
  (2, null, $t$Infusion d'objets$t$, $t$Infuse Item$t$, $t$Vous apprenez des infusions (4 au niveau 2, puis davantage) que vous pouvez placer dans des objets non magiques à la fin d'un repos long, les transformant en objets magiques. Le nombre d'objets infusés simultanément est limité (2 au niveau 2), et une infusion prend fin si vous en placez une de trop.$t$),
  (3, $t$sous_classe$t$, $t$Spécialisation d'artificier$t$, $t$Artificer Specialist$t$, $t$Vous choisissez une spécialisation : Alchimiste, Armurier, Artilleur ou Forgeron de guerre, qui vous accorde des aptitudes aux niveaux 3, 5, 9 et 15.$t$),
  (3, null, $t$Le bon outil pour la tâche$t$, $t$The Right Tool for the Job$t$, $t$Avec des outils de voleur ou d'artisan en main, vous pouvez créer par magie un jeu d'outils d'artisan en 1 heure (pendant un repos court ou long) ; il disparaît si vous en créez un autre.$t$),
  (4, $t$amelioration_caracteristiques$t$, $t$Amélioration de caractéristiques$t$, $t$Ability Score Improvement$t$, $t$Augmentez une caractéristique de 2, ou deux caractéristiques de 1 (maximum 20), ou choisissez un don.$t$),
  (6, null, $t$Expertise des outils$t$, $t$Tool Expertise$t$, $t$Votre bonus de maîtrise est doublé pour tout test utilisant un outil que vous maîtrisez.$t$),
  (7, null, $t$Éclair de génie$t$, $t$Flash of Genius$t$, $t$Par une réaction, lorsque vous ou une créature que vous voyez à 9 m ou moins faites un test ou un jet de sauvegarde, vous ajoutez votre modificateur d'Intelligence au résultat. Utilisations égales à votre modificateur d'Intelligence, récupérées après un repos long.$t$),
  (8, $t$amelioration_caracteristiques$t$, $t$Amélioration de caractéristiques$t$, $t$Ability Score Improvement$t$, $t$Augmentez une caractéristique de 2, ou deux caractéristiques de 1 (maximum 20), ou choisissez un don.$t$),
  (10, null, $t$Adepte des objets magiques$t$, $t$Magic Item Adept$t$, $t$Vous pouvez être lié à quatre objets magiques simultanément, et fabriquer un objet magique commun ou peu commun vous coûte quatre fois moins de temps et deux fois moins d'or.$t$),
  (11, null, $t$Objet de stockage de sort$t$, $t$Spell-Storing Item$t$, $t$Après un repos long, vous pouvez stocker dans une arme simple ou de guerre, ou dans un focaliseur, un sort d'artificier de niveau 1 ou 2 au temps d'incantation d'une action. Une créature qui tient l'objet peut, par une action, en produire l'effet (avec votre caractéristique d'incantation), un nombre de fois égal au double de votre modificateur d'Intelligence.$t$),
  (12, $t$amelioration_caracteristiques$t$, $t$Amélioration de caractéristiques$t$, $t$Ability Score Improvement$t$, $t$Augmentez une caractéristique de 2, ou deux caractéristiques de 1 (maximum 20), ou choisissez un don.$t$),
  (14, null, $t$Savant des objets magiques$t$, $t$Magic Item Savant$t$, $t$Vous pouvez être lié à cinq objets magiques simultanément, et vous ignorez toutes les restrictions de classe, d'espèce, de sort et de niveau pour vous lier à un objet ou l'utiliser.$t$),
  (16, $t$amelioration_caracteristiques$t$, $t$Amélioration de caractéristiques$t$, $t$Ability Score Improvement$t$, $t$Augmentez une caractéristique de 2, ou deux caractéristiques de 1 (maximum 20), ou choisissez un don.$t$),
  (18, null, $t$Maître des objets magiques$t$, $t$Magic Item Master$t$, $t$Vous pouvez être lié à six objets magiques simultanément.$t$),
  (19, $t$amelioration_caracteristiques$t$, $t$Amélioration de caractéristiques$t$, $t$Ability Score Improvement$t$, $t$Augmentez une caractéristique de 2, ou deux caractéristiques de 1 (maximum 20), ou choisissez un don.$t$),
  (20, null, $t$Âme de l'artifice$t$, $t$Soul of Artifice$t$, $t$Vous obtenez +1 à tous vos jets de sauvegarde par objet magique auquel vous êtes lié. Si vous tombez à 0 point de vie sans être tué, vous pouvez utiliser votre réaction pour mettre fin à une de vos infusions et tomber à 1 point de vie à la place.$t$)
    ) as t(level, choice_type, name_fr, name_en, description)
  loop
    if not exists (
      select 1 from public.class_features f
        join public.translations tr
          on tr.entity_type = 'class_feature' and tr.entity_id = f.id::text
         and tr.field_name = 'name' and tr.locale = 'fr'
       where f.class_id = v_class and f.level = rec.level and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.class_features (class_id, subclass_id, level, choice_type)
        values (v_class, null, rec.level, rec.choice_type)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('class_feature', v_id::text, 'name', 'fr', rec.name_fr),
        ('class_feature', v_id::text, 'name', 'en', rec.name_en),
        ('class_feature', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;

  -- Sous-classes
  for rec in
    select * from (values
  ($t$Alchimiste$t$, $t$Alchemist$t$, $t$Expert des élixirs et des réactifs, qui soigne et ravage par la chimie magique.$t$),
  ($t$Armurier$t$, $t$Armorer$t$, $t$Artificier qui transforme son armure en conduit magique, en version gardien ou infiltrateur.$t$),
  ($t$Artilleur$t$, $t$Artillerist$t$, $t$Spécialiste des sorts destructeurs, qui crée un canon occulte et une arme à feu arcanique.$t$),
  ($t$Forgeron de guerre$t$, $t$Battle Smith$t$, $t$Combattant protecteur accompagné d'un défenseur d'acier, qui soigne et frappe par la magie.$t$)
    ) as t(name_fr, name_en, description)
  loop
    if not exists (
      select 1 from public.subclasses s
        join public.translations tr
          on tr.entity_type = 'subclass' and tr.entity_id = s.id::text
         and tr.field_name = 'name' and tr.locale = 'fr'
       where s.class_id = v_class and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.subclasses (class_id, available_from_level) values (v_class, 3) returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('subclass', v_id::text, 'name', 'fr', rec.name_fr),
        ('subclass', v_id::text, 'name', 'en', rec.name_en),
        ('subclass', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;

  -- Aptitudes des sous-classes
  for rec in
    select * from (values
  ($t$Alchimiste$t$, 3, null::text, $t$Maîtrise d'outil$t$, $t$Tool Proficiency$t$, $t$Vous maîtrisez les outils d'alchimiste (ou un autre type d'outils d'artisan si c'était déjà le cas).$t$),
  ($t$Alchimiste$t$, 3, $t$sort_domaine$t$, $t$Sorts d'alchimiste$t$, $t$Alchemist Spells$t$, $t$Toujours préparés : niveau 3 — Mot de guérison, Rayon empoisonné ; niveau 5 — Sphère de feu, Flèche acide de Melf ; niveau 9 — Forme gazeuse, Mot de guérison de groupe ; niveau 13 — Flétrissement, Protection contre la mort ; niveau 17 — Brume mortelle, Rappel à la vie.$t$),
  ($t$Alchimiste$t$, 3, null, $t$Élixir expérimental$t$, $t$Experimental Elixir$t$, $t$Après un repos long, vous produisez un élixir expérimental dont l'effet est tiré au hasard (soins, rapidité, résilience, audace, vol ou transformation) ; vous pouvez en créer d'autres en dépensant un emplacement de sort, en choisissant alors l'effet. Vous en produisez davantage aux niveaux 6 et 15. Les élixirs durent jusqu'à être bus ou jusqu'à votre prochain repos long.$t$),
  ($t$Alchimiste$t$, 5, null, $t$Savant en alchimie$t$, $t$Alchemical Savant$t$, $t$Lorsque vous lancez un sort avec vos outils d'alchimiste comme focaliseur, vous ajoutez votre modificateur d'Intelligence (minimum +1) à un jet de soins ou de dégâts d'acide, de feu, nécrotiques ou de poison du sort.$t$),
  ($t$Alchimiste$t$, 9, null, $t$Réactifs restaurateurs$t$, $t$Restorative Reagents$t$, $t$Boire un de vos élixirs expérimentaux confère 2d6 + votre modificateur d'Intelligence points de vie temporaires. Vous pouvez lancer Restauration partielle sans emplacement ni préparation (outils d'alchimiste comme focaliseur), un nombre de fois égal à votre modificateur d'Intelligence par repos long.$t$),
  ($t$Alchimiste$t$, 15, null, $t$Maîtrise chimique$t$, $t$Chemical Mastery$t$, $t$Vous obtenez la résistance aux dégâts d'acide et de poison et l'immunité à l'état empoisonné. Vous pouvez lancer Restauration supérieure et Guérison une fois chacun par repos long, sans emplacement, préparation ni composante matérielle (outils d'alchimiste comme focaliseur).$t$),
  ($t$Armurier$t$, 3, null, $t$Outils du métier$t$, $t$Tools of the Trade$t$, $t$Vous maîtrisez les armures lourdes et les outils de forgeron (ou un autre type d'outils d'artisan si c'était déjà le cas).$t$),
  ($t$Armurier$t$, 3, $t$sort_domaine$t$, $t$Sorts d'armurier$t$, $t$Armorer Spells$t$, $t$Toujours préparés : niveau 3 — Projectile magique, Vague tonnante ; niveau 5 — Image miroir, Fracassement ; niveau 9 — Motif hypnotique, Éclair ; niveau 13 — Bouclier de feu, Invisibilité supérieure ; niveau 17 — Passe-muraille, Mur de force.$t$),
  ($t$Armurier$t$, 3, null, $t$Armure arcanique$t$, $t$Arcane Armor$t$, $t$Par une action, avec des outils de forgeron, vous transformez l'armure que vous portez en armure arcanique : plus d'exigence de Force, focaliseur d'incantation, impossible à vous retirer contre votre gré, couvre tout votre corps (casque rétractable par une action bonus) et remplace les membres manquants.$t$),
  ($t$Armurier$t$, 3, null, $t$Modèle d'armure$t$, $t$Armor Model$t$, $t$Vous choisissez un modèle, modifiable après un repos : Gardien (gantelets tonnerre 1d8 qui gênent les attaques contre d'autres que vous, et champ défensif accordant des points de vie temporaires égaux à votre niveau par une action bonus) ou Infiltrateur (lanceur de foudre 1d6 à distance avec 1d6 supplémentaires une fois par tour, vitesse +1,50 m, et avantage aux tests de Discrétion). Vous utilisez l'Intelligence pour les attaques de ces armes.$t$),
  ($t$Armurier$t$, 5, null, $t$Attaque supplémentaire$t$, $t$Extra Attack$t$, $t$Vous pouvez attaquer deux fois lorsque vous effectuez l'action Attaque pendant votre tour.$t$),
  ($t$Armurier$t$, 9, null, $t$Modifications d'armure$t$, $t$Armor Modifications$t$, $t$Votre armure arcanique compte comme quatre objets distincts pour vos infusions (plastron, bottes, casque et arme spéciale), et le nombre maximal d'objets infusés augmente de 2, pour ces pièces uniquement.$t$),
  ($t$Armurier$t$, 15, null, $t$Armure perfectionnée$t$, $t$Perfected Armor$t$, $t$Gardien : par une réaction, vous attirez de 7,50 m une créature de taille TG ou inférieure qui finit son tour à 9 m (jet de sauvegarde de Force) et pouvez l'attaquer si elle arrive à votre contact (utilisations égales au bonus de maîtrise). Infiltrateur : une créature touchée par votre lanceur de foudre brille jusqu'à votre prochain tour, a le désavantage aux attaques contre vous, et la prochaine attaque contre elle a l'avantage et inflige 1d6 dégâts de foudre supplémentaires.$t$),
  ($t$Artilleur$t$, 3, null, $t$Maîtrise d'outil$t$, $t$Tool Proficiency$t$, $t$Vous maîtrisez les outils de sculpteur sur bois (ou un autre type d'outils d'artisan si c'était déjà le cas).$t$),
  ($t$Artilleur$t$, 3, $t$sort_domaine$t$, $t$Sorts d'artilleur$t$, $t$Artillerist Spells$t$, $t$Toujours préparés : niveau 3 — Bouclier, Vague tonnante ; niveau 5 — Rayon ardent, Fracassement ; niveau 9 — Boule de feu, Mur de vent ; niveau 13 — Tempête de grêle, Mur de feu ; niveau 17 — Cône de froid, Mur de force.$t$),
  ($t$Artilleur$t$, 3, null, $t$Canon occulte$t$, $t$Eldritch Cannon$t$, $t$Par une action, avec des outils de forgeron ou de sculpteur sur bois, vous créez un canon occulte de taille P ou TP (CA 18, points de vie égaux à 5 × votre niveau) pendant 1 heure. Par une action bonus, vous l'activez : Lance-flammes (cône de 4,50 m, 2d8 dégâts de feu), Baliste de force (attaque à distance, 2d8 dégâts de force et repoussement de 1,50 m) ou Protecteur (1d8 + modificateur d'Intelligence points de vie temporaires aux créatures à 3 m). Une fois par repos long, ou en dépensant un emplacement de sort.$t$),
  ($t$Artilleur$t$, 5, null, $t$Arme à feu arcanique$t$, $t$Arcane Firearm$t$, $t$Après un repos long, vous gravez des sigils sur une baguette, un bâton ou un sceptre qui devient votre arme à feu arcanique : c'est un focaliseur, et vos sorts d'artificier lancés à travers elle ajoutent 1d8 à un jet de dégâts.$t$),
  ($t$Artilleur$t$, 9, null, $t$Canon explosif$t$, $t$Explosive Cannon$t$, $t$Les dégâts de votre canon augmentent de 1d8. Par une action, à 18 m ou moins, vous pouvez le faire exploser : chaque créature à 6 m doit réussir un jet de sauvegarde de Dextérité ou subir 3d8 dégâts de force (moitié en cas de réussite).$t$),
  ($t$Artilleur$t$, 15, null, $t$Position fortifiée$t$, $t$Fortified Position$t$, $t$Vous et vos alliés bénéficiez d'un abri partiel à 3 m ou moins d'un de vos canons. Vous pouvez avoir deux canons en même temps, les créer par la même action et les activer par la même action bonus.$t$),
  ($t$Forgeron de guerre$t$, 3, null, $t$Maîtrise d'outil$t$, $t$Tool Proficiency$t$, $t$Vous maîtrisez les outils de forgeron (ou un autre type d'outils d'artisan si c'était déjà le cas).$t$),
  ($t$Forgeron de guerre$t$, 3, $t$sort_domaine$t$, $t$Sorts de forgeron de guerre$t$, $t$Battle Smith Spells$t$, $t$Toujours préparés : niveau 3 — Héroïsme, Bouclier ; niveau 5 — Châtiment révélateur, Lien de protection ; niveau 9 — Aura de vitalité, Invocation de projectiles ; niveau 13 — Aura de pureté, Bouclier de feu ; niveau 17 — Châtiment du bannissement, Soins de groupe.$t$),
  ($t$Forgeron de guerre$t$, 3, null, $t$Prêt au combat$t$, $t$Battle Ready$t$, $t$Vous maîtrisez les armes de guerre, et pouvez utiliser votre modificateur d'Intelligence pour les jets d'attaque et de dégâts avec une arme magique.$t$),
  ($t$Forgeron de guerre$t$, 3, null, $t$Défenseur d'acier$t$, $t$Steel Defender$t$, $t$Vous créez un compagnon artificiel, le défenseur d'acier, qui agit juste après vous et effectue l'action Esquiver sauf si vous lui ordonnez une autre action par une action bonus. Il peut, par sa réaction, imposer le désavantage à une attaque contre une créature à 1,50 m de lui, et se réparer (2d8 + bonus de maîtrise points de vie, 3 fois par jour).$t$),
  ($t$Forgeron de guerre$t$, 5, null, $t$Attaque supplémentaire$t$, $t$Extra Attack$t$, $t$Vous pouvez attaquer deux fois lorsque vous effectuez l'action Attaque pendant votre tour.$t$),
  ($t$Forgeron de guerre$t$, 9, null, $t$Décharge arcanique$t$, $t$Arcane Jolt$t$, $t$Lorsque vous touchez avec une arme magique ou que votre défenseur touche, vous pouvez infliger 2d6 dégâts de force supplémentaires à la cible, ou rendre 2d6 points de vie à une créature à 9 m ou moins de la cible. Une fois par tour, un nombre de fois égal à votre modificateur d'Intelligence par repos long.$t$),
  ($t$Forgeron de guerre$t$, 15, null, $t$Défenseur amélioré$t$, $t$Improved Defender$t$, $t$La Décharge arcanique passe à 4d6, votre défenseur d'acier gagne +2 à la CA, et lorsqu'il utilise sa réaction de déviation, l'attaquant subit 1d4 + votre modificateur d'Intelligence dégâts de force.$t$)
    ) as t(subclass_fr, level, choice_type, name_fr, name_en, description)
  loop
    select s.id into v_sub
      from public.subclasses s
      join public.translations tr
        on tr.entity_type = 'subclass' and tr.entity_id = s.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where s.class_id = v_class and lower(tr.value) = lower(rec.subclass_fr)
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
    end if;
  end loop;

  -- Liste de sorts de l'artificier (sorts déjà présents en base, Chaudron de Tasha).
  insert into public.spell_classes (spell_id, class_id)
  select sp.id, v_class
    from unnest(array[1,297,209,15,25,261,293,2,16,247,17,371,22,18,3,20,21,23,14,11,224,13,169,
                      58,27,110,50,35,34,402,37,428,40,265,39,57,54,388,48,134,105,
                      60,327,469,240,232,470,62,59,321,282,405,299,100,77,384,389,166,474,301,364,456,
                      131,425,176,194,76,237,475,264,269,245,385,409,424,404,317,
                      356,234,225,302,133,129,416,438,227,366,154,
                      66,312,173,406,63,463,345]) as a(spell_id)
    join public.spells sp on sp.id = a.spell_id
   where not exists (select 1 from public.spell_classes sc where sc.spell_id = sp.id and sc.class_id = v_class);
end $$;

-- Contrôle final
do $$
declare
  v_class int;
  v_n int;
begin
  select c.id into v_class
    from public.classes c
    join public.translations tr
      on tr.entity_type = 'class' and tr.entity_id = c.id::text
     and tr.field_name = 'name' and tr.locale = 'fr'
   where lower(tr.value) = 'artificier';
  if v_class is null then
    raise exception 'Contrôle lot 5d : classe Artificier absente';
  end if;
  select count(*) into v_n from public.class_features where class_id = v_class;
  if v_n < 17 then
    raise exception 'Contrôle lot 5d : % aptitudes de classe sur 17', v_n;
  end if;
  select count(*) into v_n
    from public.subclasses s
   where s.class_id = v_class
     and (select count(*) from public.class_features f where f.subclass_id = s.id) >= 6;
  if v_n <> 4 then
    raise exception 'Contrôle lot 5d : % sous-classes complètes sur 4', v_n;
  end if;
  select count(*) into v_n from public.spell_classes where class_id = v_class;
  if v_n < 90 then
    raise exception 'Contrôle lot 5d : % sorts liés à l''artificier', v_n;
  end if;
end $$;
