-- Statut "archivé" de la liste des personnages (dépôt nexus-jdr-app-mobile,
-- docs/cahier-des-charges/11-fonctionnalites-a-ajouter.md section 2 :
-- "Distinction visuelle personnage actif / archivé") et
-- 10-design-system.md section 4 ("Carte personnage (liste d'accueil)",
-- variante "archivé"). Même précédent que `is_dead`
-- (20260906183956_add_characters_is_dead.sql) : un flag simple, pas de
-- comportement caché derrière (un personnage archivé reste par ailleurs
-- consultable/modifiable normalement, seule sa carte dans la liste change
-- d'apparence).
alter table public.characters
  add column is_archived boolean not null default false;
