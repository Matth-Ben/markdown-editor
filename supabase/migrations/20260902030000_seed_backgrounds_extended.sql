-- Chantier "Personnages" (app mobile) — Phase 5, lot 3 — Historiques étendus.
-- Étoffe public.backgrounds au-delà des 13 historiques du socle Phase 1 (voir
-- 20260825090800_seed_backgrounds.sql, qui n'est pas modifiée ici) avec les 2
-- historiques manquants du Character Builder AideDD, pour un total de 15
-- historiques — voir 06-roadmap.md Phase 5 du cahier des charges de l'app
-- mobile.
--
-- Source : fichier local CodexArcanum_V2.html (bloc BACKGROUND_DATA_RAW), qui
-- liste 15 historiques au total.
--
-- Dédoublonnage contre les 13 déjà en base : le fichier source contient une
-- entrée pour chacun des 13, dont 3 sous un nom différent de celui retenu par
-- le socle Phase 1 (même trait/mécanique, vérifié un à un) :
--   Criminel/Espion (base)  = Criminel (fichier)
--   Gamin des rues (base)   = Enfant des rues (fichier)
--   Solitaire (base)        = Sauvageon (fichier, traduction alternative
--                              d'"Outlander")
-- Les 10 autres noms du fichier (Acolyte, Artisan de guilde, Artiste,
-- Charlatan, Ermite, Héros du peuple, Marin, Noble, Sage, Soldat) sont
-- identiques à ceux déjà en base et correspondent bien au même historique
-- (même trait, même mécanique de maîtrises/équipement à la traduction près)
-- — vérifiés un à un plutôt que dédoublonnés par simple égalité de nom,
-- même logique que 20260902012940_seed_spells_extended.sql pour les sorts.
-- Seul point notable : le "Marin" du fichier liste les compétences
-- Athlétisme/Perception alors que le "Marin" déjà en base liste
-- Acrobaties/Perception ; il s'agit malgré tout du même historique (trait de
-- passage gratuit à bord d'un navire, même équipement, mêmes maîtrises
-- d'outils) — écart de traduction préexistant en base, non corrigé ici
-- (les 13 historiques déjà en base ne sont ni dupliqués ni modifiés par
-- cette migration).
--
-- Seuls 2 historiques du fichier sont donc réellement nouveaux :
--   - Chevalier : reprend les maîtrises d'outils du Noble d'après le fichier
--     source (commentaire "Chevalier reprend les maitrises du Noble" dans
--     BACKGROUND_TOOL_RULES) ; tool_or_language_choices repris à l'identique
--     de celui du Noble en base.
--   - Pirate : reprend les maîtrises d'outils du Marin d'après le fichier
--     source ("Pirate reprend celles du Marin") ; tool_or_language_choices
--     repris à l'identique de celui du Marin en base.
-- Le fichier ne fournit pas de paragraphe de "description" (contexte narratif
-- de l'historique, distinct du trait) comme le fait le socle Phase 1 pour
-- les 13 premiers — une description courte, cohérente avec le trait et
-- l'équipement fournis, est donc rédigée pour ces 2 nouveaux historiques.
--
-- name/feature_name/feature_description/description vivent dans
-- public.translations (migration 20260825090050), pas en colonnes sur
-- backgrounds. `backgrounds.id` étant généré à l'insertion, chaque nouvel
-- historique est inséré individuellement dans une boucle PL/pgSQL, avec une
-- garde `if not exists` par nom fr comme filet de sécurité pour une
-- ré-application de cette migration.

do $$
declare
  rec record;
  v_id int;
begin
  for rec in
    select * from (values
      (
        'Chevalier',
        '["Histoire", "Persuasion"]'::jsonb,
        '{"tools": ["un jeu au choix"], "languages": 1}'::jsonb,
        '["Habits de voyage", "Armoiries de votre maison", "Bourse (10 po)"]'::jsonb,
        'Retenue',
        $j$Vous pouvez faire appel à des soldats et gardes de votre maison pour un service de faible ampleur.$j$,
        $j$Vous êtes un chevalier assermenté au service d'une maison noble, lié par un serment de loyauté et d'honneur envers vos suzerains.$j$
      ),
      (
        'Pirate',
        '["Athlétisme", "Perception"]'::jsonb,
        '{"tools": ["Outils de navigateur"], "vehicles": ["véhicules d''eau"]}'::jsonb,
        '["Gourdin", "Corde en soie (15 mètres)", "Habits communs", "Bourse (10 po)"]'::jsonb,
        'Réputation flibustière',
        $j$Vous savez où trouver un équipage disposé à naviguer sous votre bannière.$j$,
        $j$Vous avez vécu en marge de la loi sur les mers, pillant les navires marchands et défiant l'autorité des royaumes côtiers.$j$
      )
    ) as t(name, skill_proficiencies, tool_or_language_choices, equipment, feature_name, feature_description, description)
  loop
    if not exists (
      select 1
      from public.translations bt
      where bt.entity_type = 'background' and bt.field_name = 'name' and bt.locale = 'fr'
        and bt.value = rec.name
    ) then
      insert into public.backgrounds (skill_proficiencies, tool_or_language_choices, equipment)
        values (rec.skill_proficiencies, rec.tool_or_language_choices, rec.equipment)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('background', v_id::text, 'name', 'fr', rec.name),
        ('background', v_id::text, 'feature_name', 'fr', rec.feature_name),
        ('background', v_id::text, 'feature_description', 'fr', rec.feature_description),
        ('background', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;
