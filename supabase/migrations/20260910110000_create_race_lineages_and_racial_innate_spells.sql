-- Chantier "Personnages" (app mobile) -- contenu D&D, lot 3.
-- Nouvelles tables public.race_lineages et public.racial_innate_spells, absentes du
-- schéma existant (rien ne représentait jusqu'ici le concept "lignée/ascendance" -- ex.
-- couleur de dragon du Drakéide -- ni "cette race/sous-race accorde tel sort inné à tel
-- niveau"). Contenu issu de race_lineages.json / racial_innate_spells.json, déjà
-- reformulé légalement par la source (résumés mécaniques originaux pour le hors-SRD),
-- donc pas de besoin de relecture différée comme le lot 4.
--
-- 2 entrées de race_lineages.json (drakéide chromatique/diamantin Fizban's, gap de
-- données documenté explicitement "Ne pas utiliser tel quel" par la source) sont
-- ignorées. 1 entrée de racial_innate_spells.json (Aasimar) est ignorée car sa race
-- n'est pas en base (traits non rédigés, voir lot "brouillon" -- scripts/
-- class_features_non_srd_draft.json). 9 lignes de racial_innate_spells sur 36 ont un
-- spell_id volontairement NULL (8 sorts introuvables dans public.spells au moment de
-- cette migration -- Lumières dansantes, Lueurs féeriques, Illusion mineure, Flammes,
-- Grande foulée -- + le choix libre du Haut-elfe, jamais un sort fixe) : explication
-- dans public.translations (entity_type = 'racial_innate_spell', field_name =
-- 'unresolved_note'), voir le rapport de tâche pour le détail.

create table public.race_lineages (
  id int generated always as identity primary key,
  race_id int not null references public.races (id) on delete cascade,
  subrace_id int references public.subraces (id) on delete cascade,
  lineage_group text not null,
  grants_ability_bonus boolean not null default false,
  ability_bonuses jsonb,
  damage_type text,
  resistance_damage_type text,
  source_book text
);

alter table public.race_lineages enable row level security;

create policy "Authenticated users can read race_lineages"
  on public.race_lineages for select
  to authenticated
  using (true);

create policy "Admins can insert race_lineages"
  on public.race_lineages for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update race_lineages"
  on public.race_lineages for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete race_lineages"
  on public.race_lineages for delete
  to authenticated
  using (public.is_admin());

create table public.racial_innate_spells (
  id int generated always as identity primary key,
  race_id int not null references public.races (id) on delete cascade,
  subrace_id int references public.subraces (id) on delete cascade,
  lineage_id int references public.race_lineages (id) on delete cascade,
  spell_id int references public.spells (id) on delete set null,
  character_level int not null,
  ability_used_for_dc text not null
);

alter table public.racial_innate_spells enable row level security;

create policy "Authenticated users can read racial_innate_spells"
  on public.racial_innate_spells for select
  to authenticated
  using (true);

create policy "Admins can insert racial_innate_spells"
  on public.racial_innate_spells for insert
  to authenticated
  with check (public.is_admin());

create policy "Admins can update racial_innate_spells"
  on public.racial_innate_spells for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "Admins can delete racial_innate_spells"
  on public.racial_innate_spells for delete
  to authenticated
  using (public.is_admin());

do $$
declare
  rec record;
  v_id int;
  v_race_id int;
  v_subrace_id int;
begin
  for rec in
    select * from (values
      ($q$lineage_dragonborn_phb_black$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$acide$q$, $q$acide$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Noir$q$, $q$Résistance aux dégâts de acide (Acid). Souffle (action, 1x puis recharge par repos court ou long) : ligne 1,5 x 9 m (JdS Dex.) (5 ft. by 30 ft. line (Dex. save)), dégâts de acide égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_blue$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$foudre$q$, $q$foudre$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Bleu$q$, $q$Résistance aux dégâts de foudre (Lightning). Souffle (action, 1x puis recharge par repos court ou long) : ligne 1,5 x 9 m (JdS Dex.) (5 ft. by 30 ft. line (Dex. save)), dégâts de foudre égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_brass$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$feu$q$, $q$feu$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Airain$q$, $q$Résistance aux dégâts de feu (Fire). Souffle (action, 1x puis recharge par repos court ou long) : ligne 1,5 x 9 m (JdS Dex.) (5 ft. by 30 ft. line (Dex. save)), dégâts de feu égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_bronze$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$foudre$q$, $q$foudre$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Bronze$q$, $q$Résistance aux dégâts de foudre (Lightning). Souffle (action, 1x puis recharge par repos court ou long) : ligne 1,5 x 9 m (JdS Dex.) (5 ft. by 30 ft. line (Dex. save)), dégâts de foudre égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_copper$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$acide$q$, $q$acide$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Cuivre$q$, $q$Résistance aux dégâts de acide (Acid). Souffle (action, 1x puis recharge par repos court ou long) : ligne 1,5 x 9 m (JdS Dex.) (5 ft. by 30 ft. line (Dex. save)), dégâts de acide égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_gold$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$feu$q$, $q$feu$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Or$q$, $q$Résistance aux dégâts de feu (Fire). Souffle (action, 1x puis recharge par repos court ou long) : cône de 4,5 m (JdS Dex.) (15 ft. cone (Dex. save)), dégâts de feu égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_green$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$poison$q$, $q$poison$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Vert$q$, $q$Résistance aux dégâts de poison (Poison). Souffle (action, 1x puis recharge par repos court ou long) : cône de 4,5 m (JdS Con.) (15 ft. cone (Con. save)), dégâts de poison égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_red$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$feu$q$, $q$feu$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Rouge$q$, $q$Résistance aux dégâts de feu (Fire). Souffle (action, 1x puis recharge par repos court ou long) : cône de 4,5 m (JdS Dex.) (15 ft. cone (Dex. save)), dégâts de feu égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_silver$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$froid$q$, $q$froid$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Argent$q$, $q$Résistance aux dégâts de froid (Cold). Souffle (action, 1x puis recharge par repos court ou long) : cône de 4,5 m (JdS Con.) (15 ft. cone (Con. save)), dégâts de froid égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_phb_white$q$, $q$Drakéide$q$, null, $q$phb_ancestry$q$, false, null::jsonb, $q$froid$q$, $q$froid$q$, $q$Player's Handbook (2014)$q$, $q$Ascendance draconique : Blanc$q$, $q$Résistance aux dégâts de froid (Cold). Souffle (action, 1x puis recharge par repos court ou long) : cône de 4,5 m (JdS Con.) (15 ft. cone (Con. save)), dégâts de froid égaux à 2d6 (niv.1), 3d6 (niv.6), 4d6 (niv.11), 5d6 (niv.16) ; moitié dégâts si jet de sauvegarde réussi, DD = 8 + mod. Constitution + bonus de maîtrise.$q$),
      ($q$lineage_dragonborn_fizban_metallic_brass$q$, $q$Drakéide$q$, null, $q$fizban_metallic$q$, false, null::jsonb, $q$feu$q$, $q$feu$q$, $q$Fizban's Treasury of Dragons (2021)$q$, $q$Ascendance métallique (Fizban's) : Airain$q$, $q$Résistance aux dégâts de feu (Fire). Souffle (remplace 1 attaque de l'action Attaquer, pas d'action séparée) : cône de 4,5 m, JdS Dex, DD = 8 + mod.Con + bonus de maîtrise, dégâts de feu 1d10 (niv.1) -> 2d10 (niv.5) -> 3d10 (niv.11) -> 4d10 (niv.17) ; utilisations = bonus de maîtrise par repos long (pas 'illimité avec recharge repos court/long' comme la version PHB). Dès le niveau 5, 2e souffle ('Souffle métallique', même zone) au choix : Souffle débilitant (JdS Con ou incapable d'agir jusqu'au prochain tour) ou Souffle répulsif (JdS Force ou repoussé de 6 m et à terre) ; 1x/repos long.$q$),
      ($q$lineage_dragonborn_fizban_metallic_silver$q$, $q$Drakéide$q$, null, $q$fizban_metallic$q$, false, null::jsonb, $q$froid$q$, $q$froid$q$, $q$Fizban's Treasury of Dragons (2021)$q$, $q$Ascendance métallique (Fizban's) : Argent$q$, $q$Résistance aux dégâts de froid (Cold). Souffle (remplace 1 attaque de l'action Attaquer, pas d'action séparée) : cône de 4,5 m, JdS Dex, DD = 8 + mod.Con + bonus de maîtrise, dégâts de froid 1d10 (niv.1) -> 2d10 (niv.5) -> 3d10 (niv.11) -> 4d10 (niv.17) ; utilisations = bonus de maîtrise par repos long (pas 'illimité avec recharge repos court/long' comme la version PHB). Dès le niveau 5, 2e souffle ('Souffle métallique', même zone) au choix : Souffle débilitant (JdS Con ou incapable d'agir jusqu'au prochain tour) ou Souffle répulsif (JdS Force ou repoussé de 6 m et à terre) ; 1x/repos long.$q$),
      ($q$lineage_dragonborn_fizban_metallic_bronze$q$, $q$Drakéide$q$, null, $q$fizban_metallic$q$, false, null::jsonb, $q$foudre$q$, $q$foudre$q$, $q$Fizban's Treasury of Dragons (2021)$q$, $q$Ascendance métallique (Fizban's) : Bronze$q$, $q$Résistance aux dégâts de foudre (Lightning). Souffle (remplace 1 attaque de l'action Attaquer, pas d'action séparée) : cône de 4,5 m, JdS Dex, DD = 8 + mod.Con + bonus de maîtrise, dégâts de foudre 1d10 (niv.1) -> 2d10 (niv.5) -> 3d10 (niv.11) -> 4d10 (niv.17) ; utilisations = bonus de maîtrise par repos long (pas 'illimité avec recharge repos court/long' comme la version PHB). Dès le niveau 5, 2e souffle ('Souffle métallique', même zone) au choix : Souffle débilitant (JdS Con ou incapable d'agir jusqu'au prochain tour) ou Souffle répulsif (JdS Force ou repoussé de 6 m et à terre) ; 1x/repos long.$q$),
      ($q$lineage_dragonborn_fizban_metallic_copper$q$, $q$Drakéide$q$, null, $q$fizban_metallic$q$, false, null::jsonb, $q$acide$q$, $q$acide$q$, $q$Fizban's Treasury of Dragons (2021)$q$, $q$Ascendance métallique (Fizban's) : Cuivre$q$, $q$Résistance aux dégâts de acide (Acid). Souffle (remplace 1 attaque de l'action Attaquer, pas d'action séparée) : cône de 4,5 m, JdS Dex, DD = 8 + mod.Con + bonus de maîtrise, dégâts de acide 1d10 (niv.1) -> 2d10 (niv.5) -> 3d10 (niv.11) -> 4d10 (niv.17) ; utilisations = bonus de maîtrise par repos long (pas 'illimité avec recharge repos court/long' comme la version PHB). Dès le niveau 5, 2e souffle ('Souffle métallique', même zone) au choix : Souffle débilitant (JdS Con ou incapable d'agir jusqu'au prochain tour) ou Souffle répulsif (JdS Force ou repoussé de 6 m et à terre) ; 1x/repos long.$q$),
      ($q$lineage_dragonborn_fizban_metallic_gold$q$, $q$Drakéide$q$, null, $q$fizban_metallic$q$, false, null::jsonb, $q$feu$q$, $q$feu$q$, $q$Fizban's Treasury of Dragons (2021)$q$, $q$Ascendance métallique (Fizban's) : Or$q$, $q$Résistance aux dégâts de feu (Fire). Souffle (remplace 1 attaque de l'action Attaquer, pas d'action séparée) : cône de 4,5 m, JdS Dex, DD = 8 + mod.Con + bonus de maîtrise, dégâts de feu 1d10 (niv.1) -> 2d10 (niv.5) -> 3d10 (niv.11) -> 4d10 (niv.17) ; utilisations = bonus de maîtrise par repos long (pas 'illimité avec recharge repos court/long' comme la version PHB). Dès le niveau 5, 2e souffle ('Souffle métallique', même zone) au choix : Souffle débilitant (JdS Con ou incapable d'agir jusqu'au prochain tour) ou Souffle répulsif (JdS Force ou repoussé de 6 m et à terre) ; 1x/repos long.$q$),
      ($q$lineage_genasi_air_genasi$q$, $q$Génasi$q$, $q$Génasi de l'air$q$, $q$genasi_elemental_type$q$, true, $q${"dex":1}$q$::jsonb, null, null, $q$Elemental Evil Player's Companion$q$, $q$Génasi de l'air$q$, $q$Vitesse de base inchangée mais 'Souffle sans fin' (respiration illimitée) ; sort inné Lévitation (1x/repos long, Constitution). +1 Dex.$q$),
      ($q$lineage_genasi_earth_genasi$q$, $q$Génasi$q$, $q$Génasi de la terre$q$, $q$genasi_elemental_type$q$, true, $q${"str":1}$q$::jsonb, null, null, $q$Elemental Evil Player's Companion$q$, $q$Génasi de la terre$q$, $q$'Marche de la terre' (terrain difficile de pierre/terre ignoré) ; sort inné Passage sans trace (1x/repos long, Constitution). +1 Force.$q$),
      ($q$lineage_genasi_fire_genasi$q$, $q$Génasi$q$, $q$Génasi du feu$q$, $q$genasi_elemental_type$q$, true, $q${"int":1}$q$::jsonb, null, null, $q$Elemental Evil Player's Companion$q$, $q$Génasi du feu$q$, $q$Résistance aux dégâts de feu ; vision dans le noir (teintée de rouge) ; sorts innés Flammes (cantrip) et Mains brûlantes (niv. perso 3, 1x/repos long), Constitution. +1 Intelligence.$q$),
      ($q$lineage_genasi_water_genasi$q$, $q$Génasi$q$, $q$Génasi de l'eau$q$, $q$genasi_elemental_type$q$, true, $q${"wis":1}$q$::jsonb, null, null, $q$Elemental Evil Player's Companion$q$, $q$Génasi de l'eau$q$, $q$Résistance aux dégâts d'acide ; Amphibien (respire air et eau) ; vitesse de nage 9 m ; sorts innés Façonnage de l'eau (cantrip) et Création ou destruction d'eau (niv. perso 3, 1x/repos long), Constitution. +1 Sagesse.$q$),
      ($q$lineage_elf_2024_drow$q$, $q$Elfe$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Drow$q$, $q$Vision dans le noir portée à 36 m. Lumières dansantes au niveau 1, Lueurs féeriques au niveau 3 et Ténèbres au niveau 5. Intelligence, Sagesse ou Charisme est choisie comme caractéristique d'incantation. Les sorts de niveaux 3 et 5 sont toujours préparés, lançables 1x/repos long sans emplacement et également avec des emplacements appropriés.$q$),
      ($q$lineage_elf_2024_high_elf$q$, $q$Elfe$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Haut-elfe$q$, $q$Prestidigitation au niveau 1, remplaçable après chaque repos long par un autre tour de magie de Magicien ; Détection de la magie au niveau 3 et Pas brumeux au niveau 5. Intelligence, Sagesse ou Charisme est choisie comme caractéristique d'incantation. Les sorts de niveaux 3 et 5 sont toujours préparés, lançables 1x/repos long sans emplacement et également avec des emplacements appropriés.$q$),
      ($q$lineage_elf_2024_wood_elf$q$, $q$Elfe$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Elfe des bois$q$, $q$Vitesse portée à 10,5 m. Druidisme au niveau 1, Grande foulée au niveau 3 et Passage sans trace au niveau 5. Intelligence, Sagesse ou Charisme est choisie comme caractéristique d'incantation. Les sorts de niveaux 3 et 5 sont toujours préparés, lançables 1x/repos long sans emplacement et également avec des emplacements appropriés.$q$),
      ($q$lineage_gnome_2024_forest_gnome$q$, $q$Gnome$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Gnome des forêts$q$, $q$Connaît Illusion mineure. Communication avec les animaux est toujours préparé et peut être lancé sans emplacement un nombre de fois égal au bonus de maîtrise par repos long, ou avec des emplacements. Intelligence, Sagesse ou Charisme est choisie comme caractéristique d'incantation.$q$),
      ($q$lineage_gnome_2024_rock_gnome$q$, $q$Gnome$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Gnome des roches$q$, $q$Connaît Réparation et Prestidigitation. Peut lancer Prestidigitation pendant 10 minutes pour créer un dispositif mécanique TP reproduisant un de ses effets ; maximum trois dispositifs, durée 8 heures. Intelligence, Sagesse ou Charisme est choisie comme caractéristique d'incantation.$q$),
      ($q$lineage_goliath_2024_clouds_jaunt$q$, $q$Goliath$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Géant des nuages$q$, $q$Action bonus : téléportation magique jusqu'à 9 m vers un espace libre visible. Utilisations : bonus de maîtrise par repos long.$q$),
      ($q$lineage_goliath_2024_fires_burn$q$, $q$Goliath$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Géant du feu$q$, $q$Après avoir touché et infligé des dégâts avec une attaque : +1d10 dégâts de feu à la cible. Utilisations : bonus de maîtrise par repos long.$q$),
      ($q$lineage_goliath_2024_frosts_chill$q$, $q$Goliath$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Géant du givre$q$, $q$Après avoir touché et infligé des dégâts avec une attaque : +1d6 dégâts de froid et vitesse de la cible réduite de 3 m jusqu'au début de votre prochain tour. Utilisations : bonus de maîtrise par repos long.$q$),
      ($q$lineage_goliath_2024_hills_tumble$q$, $q$Goliath$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Géant des collines$q$, $q$Après avoir touché une créature de taille G ou inférieure et infligé des dégâts : vous pouvez lui imposer l'état À terre. Utilisations : bonus de maîtrise par repos long.$q$),
      ($q$lineage_goliath_2024_stones_endurance$q$, $q$Goliath$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Géant de pierre$q$, $q$Réaction lorsque vous subissez des dégâts : lancez 1d12, ajoutez le modificateur de Constitution et réduisez les dégâts de ce total. Utilisations : bonus de maîtrise par repos long.$q$),
      ($q$lineage_goliath_2024_storms_thunder$q$, $q$Goliath$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Géant des tempêtes$q$, $q$Réaction après avoir subi des dégâts d'une créature à 18 m ou moins : infligez-lui 1d8 dégâts de tonnerre. Utilisations : bonus de maîtrise par repos long.$q$),
      ($q$lineage_tiefling_2024_abyssal$q$, $q$Tieffelin$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Abyssal$q$, $q$Résistance au poison ; Bouffée de poison au niveau 1, Rayon empoisonné au niveau 3, Immobilisation de personne au niveau 5. Intelligence, Sagesse ou Charisme est choisie comme caractéristique d'incantation. Les sorts de niveaux 3 et 5 sont toujours préparés, lançables 1x/repos long sans emplacement et également avec des emplacements appropriés.$q$),
      ($q$lineage_tiefling_2024_chthonic$q$, $q$Tieffelin$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Chtonien$q$, $q$Résistance nécrotique ; Contact glacial au niveau 1, Simulacre de vie au niveau 3, Rayon affaiblissant au niveau 5. Intelligence, Sagesse ou Charisme est choisie comme caractéristique d'incantation. Les sorts de niveaux 3 et 5 sont toujours préparés, lançables 1x/repos long sans emplacement et également avec des emplacements appropriés.$q$),
      ($q$lineage_tiefling_2024_infernal$q$, $q$Tieffelin$q$, null, $q$2024_lineage$q$, false, null::jsonb, null, null, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Infernal$q$, $q$Résistance au feu ; Trait de feu au niveau 1, Représailles infernales au niveau 3, Ténèbres au niveau 5. Intelligence, Sagesse ou Charisme est choisie comme caractéristique d'incantation. Les sorts de niveaux 3 et 5 sont toujours préparés, lançables 1x/repos long sans emplacement et également avec des emplacements appropriés.$q$),
      ($q$lineage_dragonborn_2024_black$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$acide$q$, $q$acide$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Noir$q$, $q$Résistance aux dégâts de acide (Acid). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, acide 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_blue$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$foudre$q$, $q$foudre$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Bleu$q$, $q$Résistance aux dégâts de foudre (Lightning). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, foudre 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_brass$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$feu$q$, $q$feu$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Airain$q$, $q$Résistance aux dégâts de feu (Fire). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, feu 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_bronze$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$foudre$q$, $q$foudre$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Bronze$q$, $q$Résistance aux dégâts de foudre (Lightning). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, foudre 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_copper$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$acide$q$, $q$acide$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Cuivre$q$, $q$Résistance aux dégâts de acide (Acid). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, acide 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_gold$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$feu$q$, $q$feu$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Or$q$, $q$Résistance aux dégâts de feu (Fire). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, feu 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_green$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$poison$q$, $q$poison$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Vert$q$, $q$Résistance aux dégâts de poison (Poison). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, poison 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_red$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$feu$q$, $q$feu$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Rouge$q$, $q$Résistance aux dégâts de feu (Fire). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, feu 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_silver$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$froid$q$, $q$froid$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Argent$q$, $q$Résistance aux dégâts de froid (Cold). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, froid 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$),
      ($q$lineage_dragonborn_2024_white$q$, $q$Drakéide$q$, null, $q$2024_lineage$q$, false, null::jsonb, $q$froid$q$, $q$froid$q$, $q$Player's Handbook (2024) / SRD 5.2$q$, $q$Ancêtre draconique 2024 : Blanc$q$, $q$Résistance aux dégâts de froid (Cold). Souffle remplaçant une attaque : cône de 4,5 m OU ligne de 9 m sur 1,5 m (forme choisie à chaque usage), JdS Dex, DD 8 + mod.Con + bonus de maîtrise, froid 1d10 puis 2d10/3d10/4d10 aux niveaux 5/11/17 ; bonus de maîtrise utilisations par repos long. Vol draconique commun à tous les ancêtres au niveau 5 (action bonus, 10 minutes, vitesse de vol égale à la vitesse, 1x/repos long).$q$)
    ) as t(id_temp, race_name, subrace_name, lineage_group, grants_ability_bonus, ability_bonuses, damage_type, resistance_damage_type, source_book, name_fr, mechanical_effect)
  loop
    select r.id into v_race_id from public.races r
    join public.translations t on t.entity_type = 'race' and t.entity_id = r.id::text and t.field_name = 'name' and t.locale = 'fr'
    where t.value = rec.race_name;
    if v_race_id is null then
      raise exception 'Race introuvable pour la lignée % : %', rec.id_temp, rec.race_name;
    end if;

    v_subrace_id := null;
    if rec.subrace_name is not null then
      select s.id into v_subrace_id from public.subraces s
      join public.translations t on t.entity_type = 'subrace' and t.entity_id = s.id::text and t.field_name = 'name' and t.locale = 'fr'
      where s.race_id = v_race_id and t.value = rec.subrace_name;
      if v_subrace_id is null then
        raise exception 'Sous-race introuvable pour la lignée % : %', rec.id_temp, rec.subrace_name;
      end if;
    end if;

    if not exists (
      select 1 from public.race_lineages rl
      join public.translations n on n.entity_type = 'race_lineage' and n.entity_id = rl.id::text and n.field_name = 'name' and n.locale = 'fr'
      where rl.race_id = v_race_id and n.value = rec.name_fr
    ) then
      insert into public.race_lineages (race_id, subrace_id, lineage_group, grants_ability_bonus, ability_bonuses, damage_type, resistance_damage_type, source_book)
        values (v_race_id, v_subrace_id, rec.lineage_group, rec.grants_ability_bonus, rec.ability_bonuses, rec.damage_type, rec.resistance_damage_type, rec.source_book)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('race_lineage', v_id::text, 'name', 'fr', rec.name_fr),
        ('race_lineage', v_id::text, 'mechanical_effect', 'fr', rec.mechanical_effect);
    end if;
  end loop;
end $$;

do $$
declare
  rec record;
  v_id int;
  v_race_id int;
  v_subrace_id int;
  v_lineage_id int;
  v_spell_id int;
begin
  for rec in
    select * from (values
      ($q$Tieffelin$q$, null, null, $q$Thaumaturgie$q$, null, 1, $q$cha$q$),
      ($q$Tieffelin$q$, null, null, $q$Représailles infernales$q$, null, 3, $q$cha$q$),
      ($q$Tieffelin$q$, null, null, $q$Ténèbres$q$, null, 5, $q$cha$q$),
      ($q$Elfe$q$, $q$Elfe noir (Drow)$q$, null, null, $q$Sort "Lumières dansantes" (Dancing Lights) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.$q$, 1, $q$cha$q$),
      ($q$Elfe$q$, $q$Elfe noir (Drow)$q$, null, null, $q$Sort "Lueurs féeriques" (Faerie Fire) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.$q$, 3, $q$cha$q$),
      ($q$Elfe$q$, $q$Elfe noir (Drow)$q$, null, $q$Ténèbres$q$, null, 5, $q$cha$q$),
      ($q$Elfe$q$, $q$Haut-elfe$q$, null, null, $q$Choix libre du joueur parmi les sorts mineurs de la liste de Magicien (trait "Cantrip elfique" du Haut-elfe) — pas un sort fixe, aucune ligne spells associée.$q$, 1, $q$int$q$),
      ($q$Gnome$q$, $q$Gnome des forêts$q$, null, null, $q$Sort "Illusion mineure" (Minor Illusion) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.$q$, 1, $q$int$q$),
      ($q$Génasi$q$, $q$Génasi de l'air$q$, null, $q$Lévitation$q$, null, 1, $q$con$q$),
      ($q$Génasi$q$, $q$Génasi de la terre$q$, null, $q$Passage sans trace$q$, null, 1, $q$con$q$),
      ($q$Génasi$q$, $q$Génasi du feu$q$, null, null, $q$Sort "Flammes" (Produce Flame) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.$q$, 1, $q$con$q$),
      ($q$Génasi$q$, $q$Génasi du feu$q$, null, $q$Mains brûlantes$q$, null, 3, $q$con$q$),
      ($q$Génasi$q$, $q$Génasi de l'eau$q$, null, $q$Façonnage de l'eau$q$, null, 1, $q$con$q$),
      ($q$Génasi$q$, $q$Génasi de l'eau$q$, null, $q$Création ou destruction d'eau$q$, null, 3, $q$con$q$),
      ($q$Elfe$q$, null, $q$Drow$q$, null, $q$Sort "Lumières dansantes" (Dancing Lights) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.$q$, 1, $q$int|wis|cha$q$),
      ($q$Elfe$q$, null, $q$Drow$q$, null, $q$Sort "Lueurs féeriques" (Faerie Fire) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.$q$, 3, $q$int|wis|cha$q$),
      ($q$Elfe$q$, null, $q$Drow$q$, $q$Ténèbres$q$, null, 5, $q$int|wis|cha$q$),
      ($q$Elfe$q$, null, $q$Haut-elfe$q$, $q$Prestidigitation$q$, null, 1, $q$int|wis|cha$q$),
      ($q$Elfe$q$, null, $q$Haut-elfe$q$, $q$Détection de la magie$q$, null, 3, $q$int|wis|cha$q$),
      ($q$Elfe$q$, null, $q$Haut-elfe$q$, $q$Foulée brumeuse$q$, null, 5, $q$int|wis|cha$q$),
      ($q$Elfe$q$, null, $q$Elfe des bois$q$, $q$Druidisme$q$, null, 1, $q$int|wis|cha$q$),
      ($q$Elfe$q$, null, $q$Elfe des bois$q$, null, $q$Sort "Grande foulée" (Longstrider) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.$q$, 3, $q$int|wis|cha$q$),
      ($q$Elfe$q$, null, $q$Elfe des bois$q$, $q$Passage sans trace$q$, null, 5, $q$int|wis|cha$q$),
      ($q$Gnome$q$, null, $q$Gnome des forêts$q$, null, $q$Sort "Illusion mineure" (Minor Illusion) non trouvé dans public.spells au moment de cette migration — à ajouter au catalogue de sorts puis relier ultérieurement.$q$, 1, $q$int|wis|cha$q$),
      ($q$Gnome$q$, null, $q$Gnome des forêts$q$, $q$Parole avec les animaux$q$, null, 1, $q$int|wis|cha$q$),
      ($q$Gnome$q$, null, $q$Gnome des roches$q$, $q$Réparation$q$, null, 1, $q$int|wis|cha$q$),
      ($q$Gnome$q$, null, $q$Gnome des roches$q$, $q$Prestidigitation$q$, null, 1, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Abyssal$q$, $q$Aspersion empoisonnée$q$, null, 1, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Abyssal$q$, $q$Rayon empoisonné$q$, null, 3, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Abyssal$q$, $q$Immobilisation de personne$q$, null, 5, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Chtonien$q$, $q$Contact glacial$q$, null, 1, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Chtonien$q$, $q$Simulacre de vie$q$, null, 3, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Chtonien$q$, $q$Rayon affaiblissant$q$, null, 5, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Infernal$q$, $q$Trait de feu$q$, null, 1, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Infernal$q$, $q$Représailles infernales$q$, null, 3, $q$int|wis|cha$q$),
      ($q$Tieffelin$q$, null, $q$Infernal$q$, $q$Ténèbres$q$, null, 5, $q$int|wis|cha$q$)
    ) as t(race_name, subrace_name, lineage_name, spell_name, unresolved_note, character_level, ability_used_for_dc)
  loop
    select r.id into v_race_id from public.races r
    join public.translations t on t.entity_type = 'race' and t.entity_id = r.id::text and t.field_name = 'name' and t.locale = 'fr'
    where t.value = rec.race_name;
    if v_race_id is null then
      raise exception 'Race introuvable pour un sort inné : %', rec.race_name;
    end if;

    v_subrace_id := null;
    if rec.subrace_name is not null then
      select s.id into v_subrace_id from public.subraces s
      join public.translations t on t.entity_type = 'subrace' and t.entity_id = s.id::text and t.field_name = 'name' and t.locale = 'fr'
      where s.race_id = v_race_id and t.value = rec.subrace_name;
      if v_subrace_id is null then
        raise exception 'Sous-race introuvable pour un sort inné : %', rec.subrace_name;
      end if;
    end if;

    v_lineage_id := null;
    if rec.lineage_name is not null then
      -- lineage_name porte directement le nom fr de la lignée (résolu côté script Node)
      select rl.id into v_lineage_id from public.race_lineages rl
      join public.translations n on n.entity_type = 'race_lineage' and n.entity_id = rl.id::text and n.field_name = 'name' and n.locale = 'fr'
      where rl.race_id = v_race_id and n.value = rec.lineage_name;
      if v_lineage_id is null then
        raise exception 'Lignée introuvable pour un sort inné : %', rec.lineage_name;
      end if;
    end if;

    v_spell_id := null;
    if rec.spell_name is not null then
      select sp.id into v_spell_id from public.spells sp
      join public.translations t on t.entity_type = 'spell' and t.entity_id = sp.id::text and t.field_name = 'name' and t.locale = 'fr'
      where t.value = rec.spell_name;
      if v_spell_id is null then
        raise exception 'Sort introuvable : %', rec.spell_name;
      end if;
    end if;

    if not exists (
      select 1 from public.racial_innate_spells ris
      where ris.race_id = v_race_id
        and ris.subrace_id is not distinct from v_subrace_id
        and ris.lineage_id is not distinct from v_lineage_id
        and ris.spell_id is not distinct from v_spell_id
        and ris.character_level = rec.character_level
        and ris.ability_used_for_dc = rec.ability_used_for_dc
    ) then
      insert into public.racial_innate_spells (race_id, subrace_id, lineage_id, spell_id, character_level, ability_used_for_dc)
        values (v_race_id, v_subrace_id, v_lineage_id, v_spell_id, rec.character_level, rec.ability_used_for_dc)
        returning id into v_id;
      if rec.unresolved_note is not null then
        insert into public.translations (entity_type, entity_id, field_name, locale, value) values
          ('racial_innate_spell', v_id::text, 'unresolved_note', 'fr', rec.unresolved_note);
      end if;
    end if;
  end loop;
end $$;
