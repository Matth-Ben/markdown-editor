-- Favoris de sorts (dépôt nexus-jdr-app-mobile,
-- docs/cahier-des-charges/11-fonctionnalites-a-ajouter.md, section "Onglet
-- Sorts" : "Favoris / épinglage des sorts fréquemment utilisés (accès rapide
-- en combat)."). Même précédent que characters.is_dead/is_archived/
-- inspiration : un flag simple, basculé directement par le joueur.
--
-- RLS déjà en place sur character_spells (owner select/insert/update/delete,
-- 20260825090400_create_character_tables.sql) : aucune policy
-- supplémentaire nécessaire, la mise à jour de cette colonne passe par la
-- policy "Owner can update their character_spells" déjà existante.
alter table public.character_spells
  add column is_favorite boolean not null default false;
