-- Inspiration D&D 5e (jeton accordé par le MJ), affichée sur l'onglet
-- "Personnage" (dépôt nexus-jdr-app-mobile,
-- docs/cahier-des-charges/11-fonctionnalites-a-ajouter.md, section "Onglet
-- Personnage" : "Inspiration (jeton D&D 5e accordé par le MJ) — absent du
-- doc actuel."). Même précédent que `is_dead`/`is_archived` : un simple
-- flag manuel, basculé directement par le joueur (l'app ne modélise aucune
-- transaction MJ↔joueur, juste l'état courant du jeton).
alter table public.characters
  add column inspiration boolean not null default false;
