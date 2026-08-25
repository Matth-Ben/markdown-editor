-- Chantier "Personnages" (app mobile) — Phase 1 — Peuplement du socle.
-- Les 12 classes du Manuel des Joueurs, une sous-classe "iconique" par
-- classe (disponible dès le socle pour rendre un personnage jouable dès la
-- Phase 2 — les sous-classes additionnelles sont un chantier de Phase 5,
-- voir 06-roadmap.md), et les aptitudes de classe des premiers niveaux.
-- Contenu en français, reformulé à partir des règles ouvertes du SRD (pas
-- de copie verbatim d'un texte sous droits), voir 07-source-donnees-i18n.md.
--
-- name/description vivent dans public.translations (migration
-- 20260825090050). Les ids étant générés à l'insertion, chaque ligne est
-- insérée individuellement dans une boucle PL/pgSQL (capture via
-- `returning ... into`) ; les jointures classes/sous-classes par nom
-- (utilisées dans la version précédente de cette migration) sont remplacées
-- par une relecture de public.translations, `classes.name` et
-- `subclasses.name` n'existant plus.

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.classes) then
    return;
  end if;

  for rec in
    select * from (values
      ('Barbare', 'Manuel des Joueurs', 12, '["str"]'::jsonb, '["str", "con"]'::jsonb,
        '["légère", "intermédiaire", "boucliers"]'::jsonb, '["courantes", "martiales"]'::jsonb, '[]'::jsonb,
        '{"count": 2, "choices": ["Dressage", "Athlétisme", "Intimidation", "Nature", "Perception", "Survie"]}'::jsonb,
        $j$Guerrier primitif capable d'entrer dans une rage furieuse au combat.$j$
      ),
      ('Barde', 'Manuel des Joueurs', 8, '["cha"]'::jsonb, '["dex", "cha"]'::jsonb,
        '["légère"]'::jsonb, '["courantes", "arbalète de poing", "épée longue", "rapière", "épée courte"]'::jsonb,
        '{"count": 3, "type": "instrument"}'::jsonb,
        '{"count": 3, "choices": "toutes"}'::jsonb,
        $j$Artiste itinérant dont la magie puise dans la musique, les mots et l'inspiration.$j$
      ),
      ('Clerc', 'Manuel des Joueurs', 8, '["wis"]'::jsonb, '["wis", "cha"]'::jsonb,
        '["légère", "intermédiaire", "boucliers"]'::jsonb, '["courantes"]'::jsonb, '[]'::jsonb,
        '{"count": 2, "choices": ["Histoire", "Perspicacité", "Médecine", "Persuasion", "Religion"]}'::jsonb,
        $j$Intermédiaire entre le monde mortel et le divin, canal des pouvoirs d'une divinité.$j$
      ),
      ('Druide', 'Manuel des Joueurs', 8, '["wis"]'::jsonb, '["int", "wis"]'::jsonb,
        '["légère", "intermédiaire (non métallique)", "boucliers (non métalliques)"]'::jsonb,
        '["bâtons", "dagues", "dards", "gourdins", "faucilles", "cimeterres", "épieux", "marteaux légers", "bâtons de combat", "frondes", "javelines"]'::jsonb,
        '["outils d''herboriste"]'::jsonb,
        '{"count": 2, "choices": ["Arcanes", "Dressage", "Perspicacité", "Médecine", "Nature", "Perception", "Religion", "Survie"]}'::jsonb,
        $j$Gardien de l'équilibre naturel, capable de se métamorphoser en créature animale.$j$
      ),
      ('Guerrier', 'Manuel des Joueurs', 10, '["str", "dex"]'::jsonb, '["str", "con"]'::jsonb,
        '["légère", "intermédiaire", "lourde", "boucliers"]'::jsonb, '["courantes", "martiales"]'::jsonb, '[]'::jsonb,
        '{"count": 2, "choices": ["Acrobaties", "Dressage", "Athlétisme", "Histoire", "Perspicacité", "Intimidation", "Perception", "Survie"]}'::jsonb,
        $j$Maître des armes et de l'armure, formé au combat sous toutes ses formes.$j$
      ),
      ('Moine', 'Manuel des Joueurs', 8, '["dex", "wis"]'::jsonb, '["str", "dex"]'::jsonb,
        '[]'::jsonb, '["courantes", "épées courtes"]'::jsonb,
        '{"count": 1, "type": "outils_artisan_ou_instrument"}'::jsonb,
        '{"count": 2, "choices": ["Acrobaties", "Athlétisme", "Histoire", "Perspicacité", "Religion", "Discrétion"]}'::jsonb,
        $j$Adepte des arts martiaux, canalisant une énergie intérieure appelée ki.$j$
      ),
      ('Paladin', 'Manuel des Joueurs', 10, '["str", "cha"]'::jsonb, '["wis", "cha"]'::jsonb,
        '["légère", "intermédiaire", "lourde", "boucliers"]'::jsonb, '["courantes", "martiales"]'::jsonb, '[]'::jsonb,
        '{"count": 2, "choices": ["Athlétisme", "Perspicacité", "Intimidation", "Médecine", "Persuasion", "Religion"]}'::jsonb,
        $j$Guerrier lié par un serment sacré, mêlant prouesses martiales et magie divine.$j$
      ),
      ('Rôdeur', 'Manuel des Joueurs', 10, '["dex", "wis"]'::jsonb, '["str", "dex"]'::jsonb,
        '["légère", "intermédiaire", "boucliers"]'::jsonb, '["courantes", "martiales"]'::jsonb, '[]'::jsonb,
        '{"count": 3, "choices": ["Dressage", "Athlétisme", "Perspicacité", "Investigation", "Nature", "Perception", "Discrétion", "Survie"]}'::jsonb,
        $j$Chasseur et pisteur, à l'aise dans la nature sauvage comme au combat.$j$
      ),
      ('Roublard', 'Manuel des Joueurs', 8, '["dex"]'::jsonb, '["dex", "int"]'::jsonb,
        '["légère"]'::jsonb, '["courantes", "arbalète de poing", "épée longue", "rapière", "épée courte"]'::jsonb,
        '["outils de voleur"]'::jsonb,
        '{"count": 4, "choices": ["Acrobaties", "Athlétisme", "Perspicacité", "Intimidation", "Investigation", "Perception", "Représentation", "Persuasion", "Escamotage", "Discrétion"]}'::jsonb,
        $j$Expert de la discrétion, de la ruse et des attaques précises portées par surprise.$j$
      ),
      ('Occultiste', 'Manuel des Joueurs', 8, '["cha"]'::jsonb, '["wis", "cha"]'::jsonb,
        '["légère"]'::jsonb, '["courantes"]'::jsonb, '[]'::jsonb,
        '{"count": 2, "choices": ["Arcanes", "Tromperie", "Histoire", "Intimidation", "Investigation", "Nature", "Religion"]}'::jsonb,
        $j$Lanceur de sorts ayant scellé un pacte avec une entité extraplanaire pour obtenir son pouvoir.$j$
      ),
      ('Magicien', 'Manuel des Joueurs', 6, '["int"]'::jsonb, '["int", "wis"]'::jsonb,
        '[]'::jsonb, '["dagues", "dards", "frondes", "bâtons de combat", "arcs courts"]'::jsonb, '[]'::jsonb,
        '{"count": 2, "choices": ["Arcanes", "Histoire", "Perspicacité", "Investigation", "Médecine", "Religion"]}'::jsonb,
        $j$Érudit de la magie arcanique, dont le pouvoir vient de l'étude et d'un grimoire.$j$
      ),
      ('Ensorceleur', 'Manuel des Joueurs', 6, '["cha"]'::jsonb, '["con", "cha"]'::jsonb,
        '[]'::jsonb, '["courantes", "arbalète de poing", "épée longue", "rapière", "épée courte"]'::jsonb, '[]'::jsonb,
        '{"count": 2, "choices": ["Arcanes", "Tromperie", "Perspicacité", "Intimidation", "Persuasion", "Religion"]}'::jsonb,
        $j$Lanceur de sorts dont le pouvoir magique est inné, hérité de son sang ou d'un événement marquant.$j$
      )
    ) as t(
      name, source, hit_die, primary_abilities, saving_throw_proficiencies,
      armor_proficiencies, weapon_proficiencies, tool_proficiencies, skill_choices, description
    )
  loop
    insert into public.classes (
      source, hit_die, primary_abilities, saving_throw_proficiencies,
      armor_proficiencies, weapon_proficiencies, tool_proficiencies, skill_choices
    ) values (
      rec.source, rec.hit_die, rec.primary_abilities, rec.saving_throw_proficiencies,
      rec.armor_proficiencies, rec.weapon_proficiencies, rec.tool_proficiencies, rec.skill_choices
    ) returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('class', v_id::text, 'name', 'fr', rec.name),
      ('class', v_id::text, 'description', 'fr', rec.description);
  end loop;
end $$;

-- Une sous-classe "iconique" par classe (socle Phase 1 — voir 06-roadmap.md
-- Phase 5 pour les sous-classes additionnelles).
do $$
declare
  rec record;
  v_id int;
  v_class_id int;
begin
  if exists (select 1 from public.subclasses) then
    return;
  end if;

  for rec in
    select * from (values
      ('Barbare', 'Voie du Berserker', 3, $j$Une rage qui confine à la fureur incontrôlée.$j$),
      ('Barde', 'Collège du Savoir', 3, $j$Des bardes qui rassemblent des connaissances de toutes sortes.$j$),
      ('Clerc', 'Domaine de la Vie', 1, $j$Un domaine tourné vers la préservation et la guérison.$j$),
      ('Druide', 'Cercle de la Terre', 2, $j$Des druides gardiens de la magie et de la tradition d'un lieu précis.$j$),
      ('Guerrier', 'Champion', 3, $j$Un archétype simple et redoutablement efficace, centré sur la puissance martiale brute.$j$),
      ('Moine', 'Voie de la Main Ouverte', 3, $j$Les maîtres ultimes du combat à mains nues.$j$),
      ('Paladin', 'Serment des Anciens', 3, $j$Un serment aussi vieux que le monde, voué à préserver la lumière et la vie.$j$),
      ('Rôdeur', 'Chasseur', 3, $j$Un rôdeur qui a fait de la traque d'ennemis spécifiques sa spécialité.$j$),
      ('Roublard', 'Voleur', 3, $j$Un roublard expert du crochetage, du vol et de l'improvisation.$j$),
      ('Occultiste', 'Protecteur Fiélon', 1, $j$Un pacte scellé avec une entité maléfique venue des Plans Inférieurs.$j$),
      ('Magicien', 'École de l''évocation', 2, $j$Des magiciens spécialisés dans la manipulation brute de l'énergie.$j$),
      ('Ensorceleur', 'Lignage draconique', 1, $j$Un pouvoir magique hérité d'un ancêtre dragon.$j$)
    ) as t(class_name, name, available_from_level, description)
  loop
    select c.id into v_class_id
    from public.translations ct
    join public.classes c on c.id::text = ct.entity_id
    where ct.entity_type = 'class' and ct.field_name = 'name' and ct.locale = 'fr'
      and ct.value = rec.class_name;

    if v_class_id is null then
      raise exception 'Classe introuvable pour la sous-classe % : %', rec.name, rec.class_name;
    end if;

    insert into public.subclasses (class_id, available_from_level)
      values (v_class_id, rec.available_from_level)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('subclass', v_id::text, 'name', 'fr', rec.name),
      ('subclass', v_id::text, 'description', 'fr', rec.description);
  end loop;
end $$;

-- Aptitudes de classe (niveaux 1 à 3, socle Phase 1).
do $$
declare
  rec record;
  v_id int;
  v_class_id int;
begin
  if exists (select 1 from public.class_features where class_id is not null) then
    return;
  end if;

  for rec in
    select * from (values
      ('Barbare', 1, 'Rage', $j$Au combat, vous pouvez entrer dans une rage qui vous donne un bonus aux dégâts en mêlée et une résistance aux dégâts contondants, perforants et tranchants.$j$, null::text, '{"amount": 2, "rest_type": "repos_long"}'::jsonb),
      ('Barbare', 1, 'Défense sans armure', $j$Sans armure, votre Classe d'Armure est égale à 10 + votre modificateur de Dextérité + votre modificateur de Constitution.$j$, null, null),
      ('Barbare', 2, 'Attaque impétueuse', $j$Vous pouvez vous précipiter vers un ennemi dès le premier tour, votre vitesse augmentant de 3 mètres tant que vous n'êtes pas en armure lourde.$j$, null, null),
      ('Barbare', 3, 'Voie primitive', $j$Vous choisissez une voie primitive qui définit votre approche de la rage.$j$, 'sous_classe', null),

      ('Barde', 1, 'Incantation', $j$Vous apprenez à lancer des sorts en puisant dans les émotions que suscite votre art, le Charisme étant votre caractéristique d'incantation.$j$, null, null),
      ('Barde', 1, 'Inspiration bardique', $j$Vous pouvez utiliser une action bonus pour inspirer une autre créature, qui peut ajouter un dé d'inspiration à un jet.$j$, null, '{"amount": null, "rest_type": "repos_court"}'::jsonb),
      ('Barde', 3, 'Collège bardique', $j$Vous rejoignez un collège bardique qui affine votre art.$j$, 'sous_classe', null),

      ('Clerc', 1, 'Incantation', $j$Vous canalisez la puissance divine à travers vos sorts, la Sagesse étant votre caractéristique d'incantation.$j$, null, null),
      ('Clerc', 1, 'Domaine divin', $j$Vous choisissez un domaine lié à votre divinité, qui vous octroie des sorts et aptitudes supplémentaires.$j$, 'sous_classe', null),
      ('Clerc', 2, 'Conduit divin', $j$Vous pouvez canaliser l'énergie divine directement de votre divinité pour produire un effet magique.$j$, null, '{"amount": 1, "rest_type": "repos_court"}'::jsonb),

      ('Druide', 1, 'Druidique', $j$Vous connaissez le langage secret des druides.$j$, null, null),
      ('Druide', 1, 'Incantation', $j$Vous puisez votre magie dans la nature, la Sagesse étant votre caractéristique d'incantation.$j$, null, null),
      ('Druide', 2, 'Forme sauvage', $j$Vous pouvez utiliser votre action pour vous métamorphoser magiquement en une bête que vous avez déjà vue.$j$, null, '{"amount": 2, "rest_type": "repos_court"}'::jsonb),
      ('Druide', 2, 'Cercle druidique', $j$Vous rejoignez un cercle druidique qui approfondit votre lien avec un aspect de la nature.$j$, 'sous_classe', null),

      ('Guerrier', 1, 'Style de combat', $j$Vous adoptez un style de combat qui devient votre spécialité.$j$, 'style_combat', null),
      ('Guerrier', 1, 'Récupération au combat', $j$Une fois par repos court ou long, vous pouvez utiliser une action bonus pour regagner des points de vie.$j$, null, '{"amount": 1, "rest_type": "repos_court"}'::jsonb),
      ('Guerrier', 2, 'Fougue guerrière', $j$Une fois par repos court ou long, vous pouvez prendre une action supplémentaire pendant votre tour.$j$, null, '{"amount": 1, "rest_type": "repos_court"}'::jsonb),
      ('Guerrier', 3, 'Archétype martial', $j$Vous choisissez un archétype qui incarne votre approche du combat.$j$, 'sous_classe', null),

      ('Moine', 1, 'Défense sans armure', $j$Sans armure ni bouclier, votre Classe d'Armure est égale à 10 + votre modificateur de Dextérité + votre modificateur de Sagesse.$j$, null, null),
      ('Moine', 1, 'Arts martiaux', $j$Vous maîtrisez les arts martiaux, permettant d'utiliser Dextérité au lieu de Force pour vos attaques à mains nues et vos armes de moine.$j$, null, null),
      ('Moine', 2, 'Ki', $j$Vous apprenez à maîtriser votre énergie vitale pour produire des effets surnaturels, comme la Paume tremblante ou l'Esquive du vent.$j$, null, null),
      ('Moine', 3, 'Tradition monastique', $j$Vous vous engagez dans une tradition monastique qui oriente votre pratique du ki.$j$, 'sous_classe', null),

      ('Paladin', 1, 'Sens divin', $j$Vous pouvez utiliser votre action pour détecter la présence du mal et du bien.$j$, null, '{"amount": 1, "rest_type": "repos_long"}'::jsonb),
      ('Paladin', 1, 'Imposition des mains', $j$Vous disposez d'une réserve de pouvoir de guérison qui se reconstitue à chaque repos long.$j$, null, null),
      ('Paladin', 2, 'Style de combat', $j$Vous adoptez un style de combat qui devient votre spécialité.$j$, 'style_combat', null),
      ('Paladin', 2, 'Incantation', $j$Vous apprenez à lancer des sorts de paladin, le Charisme étant votre caractéristique d'incantation.$j$, null, null),
      ('Paladin', 3, 'Serment sacré', $j$Vous prêtez le Serment sacré qui vous lie et vous octroie des aptitudes divines.$j$, 'sous_classe', null),

      ('Rôdeur', 1, 'Ennemi juré', $j$Vous choisissez un type d'ennemi favori sur lequel vous avez un avantage tactique.$j$, 'ennemi_jure', null),
      ('Rôdeur', 1, 'Explorateur né', $j$Vous choisissez un type de terrain favori où vos talents d'exploration sont renforcés.$j$, null, null),
      ('Rôdeur', 2, 'Style de combat', $j$Vous adoptez un style de combat qui devient votre spécialité.$j$, 'style_combat', null),
      ('Rôdeur', 2, 'Incantation', $j$Vous apprenez à lancer des sorts de rôdeur, la Sagesse étant votre caractéristique d'incantation.$j$, null, null),
      ('Rôdeur', 3, 'Archétype de rôdeur', $j$Vous choisissez un archétype qui reflète votre approche de la traque.$j$, 'sous_classe', null),

      ('Roublard', 1, 'Expertise', $j$Vous doublez votre bonus de maîtrise pour deux de vos compétences (ou une compétence et vos outils de voleur).$j$, null, null),
      ('Roublard', 1, 'Attaque sournoise', $j$Vous savez frapper avec précision quand vous profitez d'une diversion, infligeant des dégâts supplémentaires.$j$, null, null),
      ('Roublard', 1, 'Argot des voleurs', $j$Vous connaissez le jargon secret utilisé par les criminels.$j$, null, null),
      ('Roublard', 3, 'Archétype de roublard', $j$Vous choisissez un archétype qui définit votre spécialité.$j$, 'sous_classe', null),

      ('Occultiste', 1, 'Magie de pacte', $j$Vos sorts d'occultiste utilisent des emplacements distincts qui se rechargent lors d'un repos court.$j$, null, null),
      ('Occultiste', 1, 'Patron protecteur', $j$Vous avez conclu un pacte avec un protecteur extraplanaire dont vous tirez votre pouvoir.$j$, 'sous_classe', null),
      ('Occultiste', 2, 'Invocations occultes', $j$Vous obtenez des invocations occultes, des bribes de savoir eldritch qui vous confèrent des aptitudes magiques permanentes.$j$, 'invocation', null),

      ('Magicien', 1, 'Incantation', $j$Vous étudiez la magie dans un grimoire, l'Intelligence étant votre caractéristique d'incantation.$j$, null, null),
      ('Magicien', 1, 'Récupération arcanique', $j$Une fois par jour lors d'un repos court, vous pouvez récupérer une partie de vos emplacements de sorts dépensés.$j$, null, null),
      ('Magicien', 2, 'Tradition arcanique', $j$Vous choisissez une tradition arcanique qui oriente votre étude de la magie.$j$, 'sous_classe', null),

      ('Ensorceleur', 1, 'Incantation', $j$Votre magie est innée, le Charisme étant votre caractéristique d'incantation.$j$, null, null),
      ('Ensorceleur', 1, 'Origine magique innée', $j$Une source surnaturelle est à l'origine de votre pouvoir magique inné.$j$, 'sous_classe', null),
      ('Ensorceleur', 2, 'Métamagie', $j$Vous apprenez à manipuler vos sorts pour les adapter à vos besoins du moment.$j$, null, null)
    ) as t(class_name, level, name, description, choice_type, uses_per_rest)
  loop
    select c.id into v_class_id
    from public.translations ct
    join public.classes c on c.id::text = ct.entity_id
    where ct.entity_type = 'class' and ct.field_name = 'name' and ct.locale = 'fr'
      and ct.value = rec.class_name;

    if v_class_id is null then
      raise exception 'Classe introuvable pour l''aptitude % : %', rec.name, rec.class_name;
    end if;

    insert into public.class_features (class_id, level, choice_type, uses_per_rest)
      values (v_class_id, rec.level, rec.choice_type, rec.uses_per_rest)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('class_feature', v_id::text, 'name', 'fr', rec.name),
      ('class_feature', v_id::text, 'description', 'fr', rec.description);
  end loop;
end $$;

-- Une aptitude signature par sous-classe, rattachée au niveau d'obtention
-- de la sous-classe.
do $$
declare
  rec record;
  v_id int;
  v_subclass_id int;
  v_level int;
begin
  if exists (select 1 from public.class_features where subclass_id is not null) then
    return;
  end if;

  for rec in
    select * from (values
      ('Voie du Berserker', 'Fureur sauvage', $j$Tant que vous êtes en rage, vous pouvez faire une attaque supplémentaire en action bonus, au prix de dégâts psychiques infligés à vous-même en cas d'attaques répétées.$j$),
      ('Collège du Savoir', 'Coupure de savoir', $j$Vous pouvez dépenser un dé d'inspiration bardique pour réduire le résultat d'un jet d'attaque, de caractéristique ou de dégâts d'une créature hostile que vous pouvez entendre.$j$),
      ('Domaine de la Vie', 'Disciple de la vie', $j$Vos sorts de guérison restaurent des points de vie supplémentaires.$j$),
      ('Cercle de la Terre', 'Incantation circonstancielle', $j$Vous disposez toujours d'une réserve de sorts liés au terrain de votre cercle, en plus de vos sorts préparés habituels.$j$),
      ('Champion', 'Critique amélioré', $j$Vos attaques d'armes obtiennent un coup critique sur un résultat de 19 ou 20 au dé.$j$),
      ('Voie de la Main Ouverte', 'Technique de la main ouverte', $j$Lorsque vous touchez avec une attaque de ki, vous pouvez imposer à la cible l'un de plusieurs effets défavorables au choix.$j$),
      ('Serment des Anciens', 'Châtiment de la nature', $j$Vous pouvez lancer un sort qui entrave magiquement une créature avec des racines et des lianes.$j$),
      ('Chasseur', 'Proie du chasseur', $j$Vous choisissez une capacité offensive spécialisée contre certains types d'adversaires.$j$),
      ('Voleur', 'Doigts agiles', $j$Vous pouvez utiliser Escamotage, crocheter une serrure ou désamorcer un piège en action bonus.$j$),
      ('Protecteur Fiélon', 'Résilience sombre', $j$Lorsque vous réduisez une créature hostile à 0 point de vie, vous regagnez des points de vie temporaires.$j$),
      ('École de l''évocation', 'Sculpteur de sorts', $j$Vous pouvez épargner certains de vos alliés lorsque vous créez une zone de destruction avec un sort d'évocation.$j$),
      ('Lignage draconique', 'Résilience draconique', $j$Votre maximum de points de vie augmente, et votre peau prend un aspect semblable à des écailles, améliorant votre Classe d'Armure sans armure.$j$)
    ) as t(subclass_name, name, description)
  loop
    select sc.id, sc.available_from_level into v_subclass_id, v_level
    from public.translations st
    join public.subclasses sc on sc.id::text = st.entity_id
    where st.entity_type = 'subclass' and st.field_name = 'name' and st.locale = 'fr'
      and st.value = rec.subclass_name;

    if v_subclass_id is null then
      raise exception 'Sous-classe introuvable pour l''aptitude % : %', rec.name, rec.subclass_name;
    end if;

    insert into public.class_features (subclass_id, level)
      values (v_subclass_id, v_level)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('class_feature', v_id::text, 'name', 'fr', rec.name),
      ('class_feature', v_id::text, 'description', 'fr', rec.description);
  end loop;
end $$;
