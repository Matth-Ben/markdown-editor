-- Chantier "Personnages" (app mobile) — Phase 1 — Peuplement du socle.
-- Les 13 historiques principaux du Manuel des Joueurs (voir 06-roadmap.md
-- Phase 1). `equipment` reste en texte libre à ce stade (les objets de
-- référence ne sont peuplés que dans une migration ultérieure) — cohérent
-- avec "item_id ou texte libre" prévu par 02-modele-donnees.md.
--
-- name/feature_name/feature_description/description vivent dans
-- public.translations (migration 20260825090050), pas en colonnes sur
-- backgrounds. `backgrounds.id` étant généré à l'insertion, chaque
-- historique est inséré individuellement dans une boucle PL/pgSQL pour
-- capturer son id via `returning ... into` avant d'insérer ses traductions.

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.backgrounds) then
    return;
  end if;

  for rec in
    select * from (values
      (
        'Acolyte',
        '["Perspicacité", "Religion"]'::jsonb,
        '{"languages": 2}'::jsonb,
        '["Symbole sacré", "Livre de prières ou recueil de prières", "5 bâtons d''encens", "Habit", "Habits communs", "Bourse (15 po)"]'::jsonb,
        'Refuge du fidèle',
        $j$Vous et vos compagnons pouvez recevoir soins et logis gratuits dans un temple, sanctuaire ou autre lieu de culte de votre confession.$j$,
        $j$Vous avez passé votre vie au service d'un temple, assistant les prêtres dans les cérémonies et les rites sacrés.$j$
      ),
      (
        'Charlatan',
        '["Tromperie", "Escamotage"]'::jsonb,
        '{"tools": ["Kit de déguisement", "Kit de faussaire"]}'::jsonb,
        '["Belle tenue", "Outils d''un jeu de dupes au choix", "Kit de déguisement", "Bourse (15 po)"]'::jsonb,
        'Fausse identité',
        $j$Vous avez construit une seconde identité, complète avec papiers et contacts, qui vous permet de dissimuler votre véritable identité.$j$,
        $j$Vous avez toujours su tirer parti de la crédulité d'autrui, par la ruse plutôt que par la force.$j$
      ),
      (
        'Criminel/Espion',
        '["Tromperie", "Discrétion"]'::jsonb,
        '{"tools": ["un type de jeu au choix"]}'::jsonb,
        '["Pied-de-biche", "Habits communs sombres avec capuche", "Bourse (15 po)"]'::jsonb,
        'Contact criminel',
        $j$Vous entretenez une relation fiable avec une personne agissant comme votre intermédiaire dans un réseau criminel.$j$,
        $j$Vous avez vécu en dehors de la loi, que ce soit par nécessité, par vice ou par vocation.$j$
      ),
      (
        'Artiste',
        '["Acrobaties", "Représentation"]'::jsonb,
        '{"tools": ["un instrument de musique au choix"]}'::jsonb,
        '["Instrument de musique au choix", "Costume", "Bourse (15 po)"]'::jsonb,
        'Public conquis',
        $j$Vous pouvez toujours trouver un logement et un repas gratuits dans une communauté où votre réputation d'artiste vous précède.$j$,
        $j$Vous prospérez devant un public, vivant des acclamations et des applaudissements.$j$
      ),
      (
        'Héros du peuple',
        '["Dressage", "Survie"]'::jsonb,
        '{"tools": ["un type d''outils d''artisan au choix"], "vehicles": ["véhicules terrestres"]}'::jsonb,
        '["Un type d''outils d''artisan au choix", "Pelle", "Marmite en fer", "Habits communs", "Bourse (10 po)"]'::jsonb,
        'Hospitalité rustique',
        $j$Les gens du commun vous hébergent et vous protègent, quitte à prendre des risques pour vous mettre à l'abri des autorités.$j$,
        $j$Vous venez d'un milieu modeste, mais vous êtes destiné à bien plus que ce que votre vie de labeur laissait présager.$j$
      ),
      (
        'Artisan de guilde',
        '["Perspicacité", "Persuasion"]'::jsonb,
        '{"tools": ["un type d''outils d''artisan au choix"], "languages": 1}'::jsonb,
        '["Un type d''outils d''artisan au choix", "Lettre d''introduction de votre guilde", "Habits de voyage", "Bourse (15 po)"]'::jsonb,
        'Adhésion à la guilde',
        $j$Votre appartenance à la guilde vous garantit un soutien logistique et politique dans les villes où elle est implantée.$j$,
        $j$Vous êtes membre d'une guilde d'artisans, une confrérie de spécialistes qui veillent les uns sur les autres.$j$
      ),
      (
        'Ermite',
        '["Médecine", "Religion"]'::jsonb,
        '{"tools": ["Outils d''herboriste"], "languages": 1}'::jsonb,
        '["Écrits de vos recherches ou prières", "Outils d''herboriste", "Habits communs", "Bourse (5 po)"]'::jsonb,
        'Découverte',
        $j$Votre isolement vous a permis une découverte unique, d'une importance capitale pour vous ou pour le monde.$j$,
        $j$Vous avez vécu en reclus, que ce soit dans un ermitage ou en pleine nature, loin de la civilisation.$j$
      ),
      (
        'Noble',
        '["Histoire", "Persuasion"]'::jsonb,
        '{"tools": ["un jeu au choix"], "languages": 1}'::jsonb,
        '["Habits fins", "Anneau ou autre signe distinctif de votre rang", "Bourse (25 po)"]'::jsonb,
        'Position privilégiée',
        $j$Votre statut social vous ouvre les portes des hautes sphères ; on vous reçoit avec les égards dus à votre rang.$j$,
        $j$Vous avez grandi dans le pouvoir, la richesse ou le prestige d'une famille bien née.$j$
      ),
      (
        'Solitaire',
        '["Athlétisme", "Survie"]'::jsonb,
        '{"tools": ["un instrument de musique au choix"]}'::jsonb,
        '["Bâton de marche", "Piège à chasse", "Trophée de l''animal que vous avez chassé", "Habits de voyage", "Bourse (10 po)"]'::jsonb,
        'Guide itinérant',
        $j$Vous retrouvez toujours votre chemin et vous rappelez la topographie de toute région où vous avez déjà voyagé.$j$,
        $j$Vous avez grandi loin de la civilisation, dans les grands espaces sauvages.$j$
      ),
      (
        'Sage',
        '["Arcanes", "Histoire"]'::jsonb,
        '{"languages": 2}'::jsonb,
        '["Flacon d''encre", "Plume", "Petit couteau", "Lettre d''un collègue disparu posant une question sans réponse", "Habits communs", "Bourse (10 po)"]'::jsonb,
        'Chercheur',
        $j$Si vous ne connaissez pas une information, vous savez généralement où et auprès de qui la trouver.$j$,
        $j$Vous avez passé des années à étudier les mystères de l'univers dans un cadre académique ou en autodidacte.$j$
      ),
      (
        'Marin',
        '["Acrobaties", "Perception"]'::jsonb,
        '{"tools": ["Outils de navigateur"], "vehicles": ["véhicules d''eau"]}'::jsonb,
        '["Gourdin", "Corde en soie (15 mètres)", "Porte-bonheur", "Habits communs", "Bourse (10 po)"]'::jsonb,
        'Passager clandestin',
        $j$Vous et vos compagnons pouvez voyager gratuitement à bord d'un navire marchand, en échange de votre aide durant le trajet.$j$,
        $j$Vous avez navigué sur les mers, affrontant les tempêtes et le mal du pays.$j$
      ),
      (
        'Soldat',
        '["Athlétisme", "Intimidation"]'::jsonb,
        '{"tools": ["un jeu au choix"], "vehicles": ["véhicules terrestres"]}'::jsonb,
        '["Insigne de rang", "Trophée pris sur un ennemi vaincu", "Jeu de dés ou de cartes", "Habits communs", "Bourse (10 po)"]'::jsonb,
        'Grade militaire',
        $j$Les soldats de votre ancienne armée vous reconnaissent et vous témoignent le respect dû à votre grade.$j$,
        $j$Vous avez servi dans une armée, connaissant la discipline, la camaraderie et les horreurs de la guerre.$j$
      ),
      (
        'Gamin des rues',
        '["Escamotage", "Discrétion"]'::jsonb,
        '{"tools": ["Outils de voleur"], "languages": 1}'::jsonb,
        '["Petit couteau", "Carte de la ville où vous avez grandi", "Souris apprivoisée", "Souvenir de vos parents", "Habits communs", "Bourse (10 po)"]'::jsonb,
        'Contacts dans la ville',
        $j$Vous connaissez les rumeurs, les ragots et les raccourcis de la ville, et savez où trouver presque n'importe quoi.$j$,
        $j$Vous avez grandi dans les rues d'une ville, apprenant à survivre par vous-même dès le plus jeune âge.$j$
      )
    ) as t(name, skill_proficiencies, tool_or_language_choices, equipment, feature_name, feature_description, description)
  loop
    insert into public.backgrounds (skill_proficiencies, tool_or_language_choices, equipment)
      values (rec.skill_proficiencies, rec.tool_or_language_choices, rec.equipment)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('background', v_id::text, 'name', 'fr', rec.name),
      ('background', v_id::text, 'feature_name', 'fr', rec.feature_name),
      ('background', v_id::text, 'feature_description', 'fr', rec.feature_description),
      ('background', v_id::text, 'description', 'fr', rec.description);
  end loop;
end $$;
