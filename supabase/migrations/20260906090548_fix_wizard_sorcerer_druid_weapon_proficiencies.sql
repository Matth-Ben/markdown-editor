-- Corrige 3 erreurs de contenu RAW 5e dans classes.weapon_proficiencies,
-- invisibles jusqu'ici (aucun affichage permanent des maîtrises d'armes
-- n'existait côté app mobile), désormais exposées au joueur par la carte
-- "MAÎTRISES D'ARMES" de l'onglet Compétences. Trouvées par qa-testeur en
-- vérifiant les tables de maîtrises de multiclassage contre le RAW PHB.
--
-- Magicien (id=11) : "arcs courts" (short bows) n'est pas une arme RAW du
-- Magicien -- doit être "arbalète légère" (light crossbow).
-- Ensorceleur (id=12) : liste entièrement erronée, copiée du Barde/Roublard
-- -- RAW, l'Ensorceleur a exactement la même liste que le Magicien.
-- Druide (id=4) : "bâtons" est un doublon de "bâtons de combat" (déjà
-- présent) -- retiré ; "marteaux légers" (arme martiale, hors RAW Druide)
-- doit être "masse d'armes" (arme simple RAW pour le Druide).

update classes
set weapon_proficiencies = '["dagues", "dards", "frondes", "bâtons de combat", "arbalète légère"]'::jsonb
where id = 11;

update classes
set weapon_proficiencies = '["dagues", "dards", "frondes", "bâtons de combat", "arbalète légère"]'::jsonb
where id = 12;

update classes
set weapon_proficiencies = '["dagues", "dards", "gourdins", "faucilles", "cimeterres", "épieux", "masse d''armes", "bâtons de combat", "frondes", "javelines"]'::jsonb
where id = 4;
