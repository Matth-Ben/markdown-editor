-- Gap réel trouvé en spécifiant l'écran "Groupe" (12-partage-et-groupes.md
-- section 2.2, dépôt nexus-jdr-app-mobile) : le statut "mort" y est décrit
-- comme "réutilise le statut mort déjà prévu sur la fiche et dans la liste
-- des personnages, en tant que simple flag manuel" -- mais ce flag n'existe
-- nulle part dans le schéma ni dans l'app mobile (seul "inconscient" est
-- dérivé de current_hp = 0, jamais stocké). Sans cette colonne, le badge
-- "MORT" de l'écran Groupe serait un état inatteignable.
alter table public.characters
  add column is_dead boolean not null default false;
