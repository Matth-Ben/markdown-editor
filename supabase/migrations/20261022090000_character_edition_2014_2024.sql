-- Chantier "choix d'édition RAW (2014/2024) par personnage" (app mobile).
--
-- `public.characters` gagne `edition`, choisie une fois à la création et
-- immuable ensuite (même principe que race/classe : rien ici n'empêche une
-- UPDATE côté SQL, l'immuabilité est appliquée côté application, pas par
-- contrainte). Défaut `'2014'` pour que tout personnage déjà existant garde
-- exactement son comportement actuel sans migration de données
-- supplémentaire sur cette table.
--
-- `public.class_features.edition`/`public.class_options.edition` :
-- `NULL` = la ligne s'applique aux deux éditions (le cas de la grande
-- majorité des lignes existantes, non ambiguës entre 2014 et 2024 — elles
-- restent `NULL`, aucune ligne existante n'est modifiée par cette
-- migration). Une valeur ('2014' ou '2024') restreint la ligne à cette
-- édition pour un contenu qui diffère réellement entre les deux textes
-- (ex. Métamagie de l'Ensorceleur, Expertise du Barde — voir script de
-- contenu séparé, pas inclus dans cette migration de schéma).
--
-- Contenu pilote (3 mécaniques) et script UPDATE/INSERT associé : hors
-- périmètre de cette migration de schéma, exécutés séparément par
-- Matthias.

alter table public.characters
  add column edition text not null default '2014'
  check (edition in ('2014', '2024'));

comment on column public.characters.edition is
  'Édition des règles D&D choisie à la création du personnage (''2014'' ou ''2024''), immuable ensuite (appliqué côté application, pas par contrainte). Défaut ''2014'' pour préserver le comportement des personnages déjà existants.';

alter table public.class_features
  add column edition text
  check (edition in ('2014', '2024'));

comment on column public.class_features.edition is
  'NULL = s''applique aux deux éditions (cas par défaut, non ambigu). Une valeur restreint la ligne à cette édition pour un contenu qui diffère réellement entre 2014 et 2024 (ex. niveaux de déclenchement de la Métamagie/Expertise).';

alter table public.class_options
  add column edition text
  check (edition in ('2014', '2024'));

comment on column public.class_options.edition is
  'Même convention que class_features.edition : NULL = s''applique aux deux éditions, une valeur restreint l''option à cette édition.';
