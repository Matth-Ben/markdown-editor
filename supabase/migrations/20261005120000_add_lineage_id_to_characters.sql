-- Chantier "Personnages" (app mobile) — permet de stocker le choix de lignée/
-- ascendance d'un personnage (ex. couleur de souffle/résistance du Drakéide,
-- sous-race élémentaire du Génasi, variante 2024 d'Elfe/Gnome/Goliath/
-- Tieffelin...), représenté par public.race_lineages (voir migration
-- 20260910110000_create_race_lineages_and_racial_innate_spells.sql).
--
-- Colonne volontairement générique (pas de nom spécifique au Drakéide) : ce
-- chantier mobile consommera progressivement les autres lineage_group
-- existants (2024_lineage pour Elfe/Gnome/Goliath/Tieffelin,
-- genasi_elemental_type pour Génasi).
--
-- Même style que race_id/subrace_id sur characters : colonne nullable (brouillon
-- possible avant d'avoir choisi une lignée, ou race sans lignée), FK sans nom de
-- contrainte explicite, on delete set null pour ne jamais bloquer une suppression
-- de contenu de référence (cf. 20260825090400_create_character_tables.sql).
--
-- Pas de nouvelle policy RLS : public.characters a déjà des policies
-- select/insert/update/delete par owner_id couvrant la ligne entière (donc
-- toutes ses colonnes, y compris celle-ci).

alter table public.characters
  add column lineage_id int references public.race_lineages (id) on delete set null;
