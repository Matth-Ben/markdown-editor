-- Permet à un objet personnalisé (character_inventory.item_id is null,
-- custom_name renseigné) d'avoir une description et, si c'est une arme, ses
-- dégâts/propriétés -- jusqu'ici un objet personnalisé n'avait que
-- custom_name/quantity/notes, contrairement à un objet du catalogue qui
-- bénéficie de items.description et, pour une arme, de weapon_properties
-- (damage_dice/damage_type/properties).
--
-- Décision du chef de projet : ne pas réutiliser `notes`, qui reste réservé
-- à une annotation personnelle du joueur, distincte de la description de
-- l'objet lui-même.
--
-- Format aligné sur weapon_properties (table de référence, voir
-- 20260825090300_create_reference_spells_items_tables.sql) pour que le code
-- client consomme les deux sources sans transformation :
--   - custom_damage_dice : même notation canonique NdM que
--     weapon_properties.damage_dice (ex. "1d8"), consommée telle quelle par
--     DiceNotationParser/DiceTypeBadge côté app mobile.
--   - custom_damage_type : mêmes valeurs minuscules que
--     weapon_properties.damage_type ('tranchant'/'perforant'/'contondant').
--     Pas de contrainte CHECK : weapon_properties.damage_type n'en a pas non
--     plus (vérifié avant d'écrire cette migration), on reste cohérent avec
--     l'existant plutôt que d'ajouter une rigueur que le schéma de
--     référence n'a pas lui-même.
--   - custom_properties : même format que weapon_properties.properties,
--     une liste jsonb de chaînes (ex. '["légère", "finesse"]').
--
-- Les 4 colonnes restent NULL pour :
--   - un objet personnalisé non-arme (seul custom_description peut être
--     renseigné dans ce cas) ;
--   - tout objet du catalogue (item_id non nul), qui continue de passer par
--     items.description/weapon_properties.
-- Aucune contrainte d'exclusivité ajoutée (ex. CHECK empêchant un objet
-- catalogue d'avoir ces colonnes renseignées) : cohérent avec le reste de
-- cette table, qui ne contraint pas ce genre de combinaison (déjà le cas
-- pour custom_name/item_id, voir la contrainte
-- character_inventory_item_or_custom plus bas) -- la discipline reste côté
-- app. Cette contrainte existante (item_id is not null or custom_name is
-- not null) n'est pas affectée : les 4 nouvelles colonnes sont indépendantes
-- et ne figurent dans aucune expression CHECK.
--
-- RLS déjà en place sur character_inventory (owner select/insert/update/
-- delete, 20260825090400_create_character_tables.sql) : aucune policy
-- supplémentaire nécessaire, la mise à jour de ces colonnes passe par la
-- policy "Owner can update their character_inventory" déjà existante.
alter table public.character_inventory
  add column custom_description text,
  add column custom_damage_dice text,
  add column custom_damage_type text,
  add column custom_properties jsonb;

comment on column public.character_inventory.custom_description is
  'Description libre d''un objet personnalisé (item_id is null). NULL pour un objet du catalogue, qui utilise items.description.';

comment on column public.character_inventory.custom_damage_dice is
  'Dégâts d''une arme personnalisée, notation NdM (ex. "1d8"), même format que weapon_properties.damage_dice. NULL si l''objet personnalisé n''est pas une arme, ou pour un objet du catalogue.';

comment on column public.character_inventory.custom_damage_type is
  'Type de dégâts d''une arme personnalisée (''tranchant''/''perforant''/''contondant''), mêmes valeurs que weapon_properties.damage_type. NULL si l''objet personnalisé n''est pas une arme, ou pour un objet du catalogue.';

comment on column public.character_inventory.custom_properties is
  'Propriétés d''une arme personnalisée, liste jsonb de chaînes (ex. ["légère", "finesse"]), même format que weapon_properties.properties. NULL si l''objet personnalisé n''est pas une arme, ou pour un objet du catalogue.';
