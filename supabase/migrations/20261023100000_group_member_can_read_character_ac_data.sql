-- Complément de 20260906190500_group_member_can_read_characters.sql : la
-- liste "Membres" d'un groupe (app mobile) va afficher la Classe d'Armure de
-- chaque coéquipier, sous les PV. Calculer une CA RAW-correcte (même formule
-- que ArmorClassCalculator côté mobile : base d'armure + Dex, bouclier,
-- bonus d'objets magiques, défenses sans armure Barbare/Moine/Résilience
-- draconique, +1 avec le style de combat Défense) nécessite de lire, pour un
-- coéquipier, ses modificateurs de caractéristiques, son inventaire équipé
-- et ses choix de classe (styles de combat) -- pas seulement characters/
-- character_classes déjà ouverts par la migration ci-dessus.
--
-- Même principe que 20260906190500 : RLS ne restreint que des LIGNES, pas
-- des colonnes. On réutilise donc exactement la même fonction
-- security-definer public.group_member_can_read_character(uuid) (déjà créée,
-- non redéfinie ici) pour accorder, à tout membre du même groupe qu'un
-- personnage, un accès en lecture à la ligne entière de ces 3 tables pour ce
-- personnage. La restriction d'affichage (uniquement la CA calculée, pas le
-- détail de l'inventaire/des caractéristiques d'un coéquipier) reste
-- appliquée côté client mobile.
--
-- armor_properties (table de référence, par item_id) est déjà lisible par
-- authenticated depuis sa création (20260825090300_create_reference_spells_items_tables.sql,
-- policy "Authenticated users can read armor_properties") : pas de nouvelle
-- policy nécessaire ici.

create policy "Group member can select teammates' character_ability_scores"
  on public.character_ability_scores for select
  to authenticated
  using (public.group_member_can_read_character(character_id));

create policy "Group member can select teammates' character_inventory"
  on public.character_inventory for select
  to authenticated
  using (public.group_member_can_read_character(character_id));

create policy "Group member can select teammates' character_class_options"
  on public.character_class_options for select
  to authenticated
  using (public.group_member_can_read_character(character_id));
