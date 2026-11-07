-- Bug F04 (chantier "simulation utilisateur" de l'app mobile, voir
-- docs/retours-utilisateurs.md du dépôt nexus-jdr-app-mobile) : l'option A de
-- l'équipement de départ du Clerc (classes.id = 3) référence "Chemise de
-- mailles" au lieu de "Armure d'écailles" — une erreur de saisie dans la
-- migration 20260930210000_classes_starting_equipment.sql, pas une
-- régression. Observé en jeu : un Clerc créé via l'option A affichait CA 17
-- (Chemise de mailles 13 + Dex max 2 + bouclier 2) au lieu de CA 18
-- (Armure d'écailles 14 + Dex max 2 + bouclier 2), la valeur RAW attendue
-- du Manuel des Joueurs.
--
-- Le catalogue `items` lui-même est correct (Armure de cuir 10po/id=39,
-- Chemise de mailles 50po/id=42, Armure d'écailles 50po/id=43, Cotte de
-- mailles 75po/id=47) ; seule la référence dans `classes.starting_equipment`
-- pour le Clerc était fausse.
--
-- Correction ciblée via jsonb_set sur le seul chemin
-- {options,0,items,0,item} (option "A", premier item de la liste) pour ne
-- pas toucher au reste de la structure (gold, bouclier, masse d'armes,
-- symbole sacré, paquetage d'ecclésiastique, option B). Le WHERE vérifie la
-- valeur actuelle à ce chemin pour rendre la migration idempotente (no-op
-- si déjà corrigée) et pour ne pas écraser une valeur différente par erreur
-- si la structure a changé entre-temps.
--
-- Point ouvert, non traité ici : le modèle `starting_equipment` ne permet
-- qu'une armure fixe par option, alors que le Clerc a RAW un vrai choix
-- entre Armure d'écailles / Armure de cuir / Cotte de mailles pour
-- l'option A. Cette migration fige le résultat sur Armure d'écailles
-- (le standard implicite), mais une UI de sous-choix reste un chantier
-- séparé — voir la description de la PR.

update public.classes
   set starting_equipment = jsonb_set(
         starting_equipment,
         '{options,0,items,0,item}',
         '"Armure d''écailles"'
       )
 where id = 3
   and starting_equipment #>> '{options,0,items,0,item}' = 'Chemise de mailles';
