-- Chantier "Personnages" (app mobile) — Phase 1 — Peuplement du socle.
-- Armes, armures/boucliers, matériel d'aventurier courant et packs
-- d'équipement du Manuel des Joueurs. Couverture quasi complète pour les
-- armes/armures/packs (données compactes et structurées, fort ROI), plus un
-- socle de matériel d'aventurier courant (liste non exhaustive du chapitre
-- Équipement du Manuel des Joueurs — les tables `tools` (migration
-- 20260825090500) couvrent déjà les outils/instruments/jeux en tant que
-- compétences ; les entrées `items` correspondantes ne sont pas dupliquées
-- ici pour la Phase 1, un objet non référencé pouvant être ajouté en texte
-- libre via `character_inventory.custom_name`).
--
-- Convention d'unité : `weight` est stocké en kilogrammes (conversion
-- arrondie depuis les livres du SRD), `cost` en pièces d'or (gp) au format
-- {"amount": x, "currency": "gp"} conformément à l'exemple de
-- 02-modele-donnees.md.
--
-- name/description vivent dans public.translations (migration
-- 20260825090050). `items.id` étant généré à l'insertion, chaque objet est
-- inséré individuellement dans une boucle PL/pgSQL pour capturer son id via
-- `returning ... into` ; `weapon_properties`/`armor_properties`
-- (rattachées à `item_id`, clé primaire = clé étrangère, pas de colonne
-- texte) résolvent cet id en relisant public.translations, une jointure
-- directe par `items.name` n'étant plus possible.

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.items) then
    return;
  end if;

  -- Armes courantes de corps à corps, courantes à distance, de guerre de
  -- corps à corps, de guerre à distance.
  for rec in
    select * from (values
      ('Gourdin', 'arme', 1.0, '{"amount": 0.1, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Dague', 'arme', 0.5, '{"amount": 2, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Gourdin à deux mains', 'arme', 4.5, '{"amount": 0.2, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Hachette', 'arme', 1.0, '{"amount": 5, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Javeline', 'arme', 1.0, '{"amount": 0.5, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Marteau léger', 'arme', 1.0, '{"amount": 2, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Masse d''armes', 'arme', 2.0, '{"amount": 5, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Faucille', 'arme', 1.0, '{"amount": 1, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Épieu', 'arme', 1.5, '{"amount": 1, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Bâton de combat', 'arme', 2.0, '{"amount": 0.2, "currency": "gp"}'::jsonb, 'Arme courante de corps à corps.', 'Manuel des Joueurs'),
      ('Arc court', 'arme', 1.0, '{"amount": 25, "currency": "gp"}'::jsonb, 'Arme courante à distance.', 'Manuel des Joueurs'),
      ('Arbalète légère', 'arme', 2.5, '{"amount": 25, "currency": "gp"}'::jsonb, 'Arme courante à distance.', 'Manuel des Joueurs'),
      ('Dard', 'arme', 0.1, '{"amount": 0.05, "currency": "gp"}'::jsonb, 'Arme courante à distance.', 'Manuel des Joueurs'),
      ('Fronde', 'arme', 0.1, '{"amount": 1, "currency": "gp"}'::jsonb, 'Arme courante à distance.', 'Manuel des Joueurs'),
      ('Hache d''armes', 'arme', 2.0, '{"amount": 10, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Fléau d''armes', 'arme', 1.0, '{"amount": 10, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Glaive', 'arme', 3.0, '{"amount": 20, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Grande hache', 'arme', 3.2, '{"amount": 30, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Épée à deux mains', 'arme', 2.7, '{"amount": 50, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Hallebarde', 'arme', 2.7, '{"amount": 20, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Lance de cavalerie', 'arme', 2.7, '{"amount": 10, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Épée longue', 'arme', 1.5, '{"amount": 15, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Maillet', 'arme', 4.5, '{"amount": 10, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Morgenstern', 'arme', 2.0, '{"amount": 15, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Pique', 'arme', 8.0, '{"amount": 5, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Rapière', 'arme', 1.0, '{"amount": 25, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Cimeterre', 'arme', 1.5, '{"amount": 25, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Épée courte', 'arme', 1.0, '{"amount": 10, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Trident', 'arme', 2.0, '{"amount": 5, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Pic de guerre', 'arme', 1.0, '{"amount": 5, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Marteau de guerre', 'arme', 1.0, '{"amount": 15, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Fouet', 'arme', 1.5, '{"amount": 2, "currency": "gp"}'::jsonb, 'Arme de guerre de corps à corps.', 'Manuel des Joueurs'),
      ('Sarbacane', 'arme', 0.5, '{"amount": 10, "currency": "gp"}'::jsonb, 'Arme de guerre à distance.', 'Manuel des Joueurs'),
      ('Arbalète de poing', 'arme', 1.5, '{"amount": 75, "currency": "gp"}'::jsonb, 'Arme de guerre à distance.', 'Manuel des Joueurs'),
      ('Arbalète lourde', 'arme', 8.0, '{"amount": 50, "currency": "gp"}'::jsonb, 'Arme de guerre à distance.', 'Manuel des Joueurs'),
      ('Arc long', 'arme', 1.0, '{"amount": 50, "currency": "gp"}'::jsonb, 'Arme de guerre à distance.', 'Manuel des Joueurs'),
      ('Filet', 'arme', 1.5, '{"amount": 1, "currency": "gp"}'::jsonb, 'Arme de guerre à distance.', 'Manuel des Joueurs')
    ) as t(name, category, weight, cost, description, source)
  loop
    insert into public.items (category, weight, cost, source)
      values (rec.category, rec.weight, rec.cost, rec.source)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('item', v_id::text, 'name', 'fr', rec.name),
      ('item', v_id::text, 'description', 'fr', rec.description);
  end loop;

  -- Armures et boucliers.
  for rec in
    select * from (values
      ('Armure rembourrée', 'armure', 3.6, '{"amount": 5, "currency": "gp"}'::jsonb, 'Armure légère.', 'Manuel des Joueurs'),
      ('Armure de cuir', 'armure', 4.5, '{"amount": 10, "currency": "gp"}'::jsonb, 'Armure légère.', 'Manuel des Joueurs'),
      ('Armure de cuir clouté', 'armure', 5.9, '{"amount": 45, "currency": "gp"}'::jsonb, 'Armure légère.', 'Manuel des Joueurs'),
      ('Armure de peau', 'armure', 5.4, '{"amount": 10, "currency": "gp"}'::jsonb, 'Armure intermédiaire.', 'Manuel des Joueurs'),
      ('Chemise de mailles', 'armure', 9.0, '{"amount": 50, "currency": "gp"}'::jsonb, 'Armure intermédiaire.', 'Manuel des Joueurs'),
      ('Armure d''écailles', 'armure', 20.0, '{"amount": 50, "currency": "gp"}'::jsonb, 'Armure intermédiaire.', 'Manuel des Joueurs'),
      ('Cuirasse', 'armure', 9.0, '{"amount": 400, "currency": "gp"}'::jsonb, 'Armure intermédiaire.', 'Manuel des Joueurs'),
      ('Demi-plate', 'armure', 18.0, '{"amount": 750, "currency": "gp"}'::jsonb, 'Armure intermédiaire.', 'Manuel des Joueurs'),
      ('Cotte à anneaux', 'armure', 18.0, '{"amount": 30, "currency": "gp"}'::jsonb, 'Armure lourde.', 'Manuel des Joueurs'),
      ('Cotte de mailles', 'armure', 25.0, '{"amount": 75, "currency": "gp"}'::jsonb, 'Armure lourde.', 'Manuel des Joueurs'),
      ('Harnois à lattes', 'armure', 27.0, '{"amount": 200, "currency": "gp"}'::jsonb, 'Armure lourde.', 'Manuel des Joueurs'),
      ('Armure complète', 'armure', 29.5, '{"amount": 1500, "currency": "gp"}'::jsonb, 'Armure lourde.', 'Manuel des Joueurs'),
      ('Bouclier', 'bouclier', 3.0, '{"amount": 10, "currency": "gp"}'::jsonb, 'Porté à un bras, accorde un bonus de +2 à la Classe d''Armure (valeur stockée dans armor_properties.ac_base à titre de bonus, pas de CA de base).', 'Manuel des Joueurs')
    ) as t(name, category, weight, cost, description, source)
  loop
    insert into public.items (category, weight, cost, source)
      values (rec.category, rec.weight, rec.cost, rec.source)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value) values
      ('item', v_id::text, 'name', 'fr', rec.name),
      ('item', v_id::text, 'description', 'fr', rec.description);
  end loop;

  -- Matériel d'aventurier courant (sélection large, pas exhaustive).
  for rec in
    select * from (values
      ('Sac à dos', 'equipement_general', 2.5, '{"amount": 2, "currency": "gp"}'::jsonb, 'Peut contenir jusqu''à 1 pied cube ou 13,5 kg d''équipement.', false, 'Manuel des Joueurs'),
      ('Corde en chanvre (15 mètres)', 'equipement_general', 4.5, '{"amount": 1, "currency": "gp"}'::jsonb, 'Corde résistante, utile pour l''escalade et la sécurisation d''équipement.', false, 'Manuel des Joueurs'),
      ('Torche', 'equipement_general', 0.5, '{"amount": 0.01, "currency": "gp"}'::jsonb, 'Éclaire dans un rayon de 6 mètres pendant 1 heure.', true, 'Manuel des Joueurs'),
      ('Silex et briquet', 'equipement_general', 0.5, '{"amount": 0.5, "currency": "gp"}'::jsonb, 'Permet d''allumer un feu.', false, 'Manuel des Joueurs'),
      ('Rations de voyage (1 jour)', 'equipement_general', 0.9, '{"amount": 0.5, "currency": "gp"}'::jsonb, 'Nourriture séchée ou salée pour une journée.', true, 'Manuel des Joueurs'),
      ('Outre', 'equipement_general', 2.3, '{"amount": 0.2, "currency": "gp"}'::jsonb, 'Contient jusqu''à 1,9 litre de liquide.', false, 'Manuel des Joueurs'),
      ('Couverture', 'equipement_general', 1.5, '{"amount": 0.5, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Sac de couchage', 'equipement_general', 3.4, '{"amount": 0.1, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Grappin', 'equipement_general', 1.8, '{"amount": 2, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Lanterne à capote', 'equipement_general', 0.9, '{"amount": 5, "currency": "gp"}'::jsonb, 'Éclaire dans un rayon de 9 mètres pendant 6 heures avec un flacon d''huile.', false, 'Manuel des Joueurs'),
      ('Lanterne sourde', 'equipement_general', 1.0, '{"amount": 10, "currency": "gp"}'::jsonb, 'Éclaire dans un rayon de 18 mètres pendant 6 heures avec un flacon d''huile.', false, 'Manuel des Joueurs'),
      ('Flacon d''huile', 'equipement_general', 0.5, '{"amount": 0.1, "currency": "gp"}'::jsonb, null, true, 'Manuel des Joueurs'),
      ('Bougie', 'equipement_general', 0.0, '{"amount": 0.01, "currency": "gp"}'::jsonb, 'Éclaire dans un rayon de 1,5 mètre pendant 1 heure.', true, 'Manuel des Joueurs'),
      ('Parchemin (feuille)', 'equipement_general', 0.0, '{"amount": 0.1, "currency": "gp"}'::jsonb, null, true, 'Manuel des Joueurs'),
      ('Papier (feuille)', 'equipement_general', 0.0, '{"amount": 0.2, "currency": "gp"}'::jsonb, null, true, 'Manuel des Joueurs'),
      ('Flacon d''encre', 'equipement_general', 0.0, '{"amount": 10, "currency": "gp"}'::jsonb, null, true, 'Manuel des Joueurs'),
      ('Plume', 'equipement_general', 0.0, '{"amount": 0.02, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Sacoche à composants', 'equipement_general', 1.4, '{"amount": 25, "currency": "gp"}'::jsonb, 'Petit sac contenant les composants matériels usuels des sorts.', false, 'Manuel des Joueurs'),
      ('Symbole sacré', 'equipement_general', 0.5, '{"amount": 5, "currency": "gp"}'::jsonb, 'Focaliseur d''incantation pour un clerc ou un paladin.', false, 'Manuel des Joueurs'),
      ('Focaliseur druidique', 'equipement_general', 0.9, '{"amount": 10, "currency": "gp"}'::jsonb, 'Focaliseur d''incantation pour un druide (gui, branche noueuse, etc.).', false, 'Manuel des Joueurs'),
      ('Focaliseur arcanique', 'equipement_general', 0.5, '{"amount": 10, "currency": "gp"}'::jsonb, 'Focaliseur d''incantation pour un magicien, un ensorceleur ou un occultiste (baguette, orbe, bâton...).', false, 'Manuel des Joueurs'),
      ('Kit de soins', 'equipement_general', 1.4, '{"amount": 5, "currency": "gp"}'::jsonb, 'Dix utilisations. Nécessaire pour stabiliser une créature mourante sans jet de caractéristique.', true, 'Manuel des Joueurs'),
      ('Miroir en acier poli', 'equipement_general', 0.2, '{"amount": 5, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Gamelle', 'equipement_general', 0.2, '{"amount": 0.2, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Pied-de-biche', 'equipement_general', 2.3, '{"amount": 2, "currency": "gp"}'::jsonb, 'Confère l''avantage aux jets de Force pour forcer un passage.', false, 'Manuel des Joueurs'),
      ('Marteau', 'equipement_general', 0.5, '{"amount": 1, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Piton', 'equipement_general', 0.1, '{"amount": 0.05, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Cadenas', 'equipement_general', 0.5, '{"amount": 10, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Sac (grand)', 'equipement_general', 0.4, '{"amount": 0.5, "currency": "gp"}'::jsonb, 'Peut contenir jusqu''à 1/4 de pied cube ou 6,8 kg.', false, 'Manuel des Joueurs'),
      ('Sifflet', 'equipement_general', 0.0, '{"amount": 0.05, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Tente (deux personnes)', 'equipement_general', 8.2, '{"amount": 2, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Vêtements communs', 'equipement_general', 1.4, '{"amount": 0.5, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Vêtements de voyage', 'equipement_general', 2.0, '{"amount": 2, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Vêtements fins', 'equipement_general', 2.7, '{"amount": 15, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Costume de déguisement', 'equipement_general', 1.8, '{"amount": 5, "currency": "gp"}'::jsonb, null, false, 'Manuel des Joueurs'),
      ('Bourse', 'equipement_general', 0.1, '{"amount": 5, "currency": "gp"}'::jsonb, 'Peut contenir jusqu''à 50 pièces.', false, 'Manuel des Joueurs')
    ) as t(name, category, weight, cost, description, consumable, source)
  loop
    insert into public.items (category, weight, cost, consumable, source)
      values (rec.category, rec.weight, rec.cost, rec.consumable, rec.source)
      returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value)
      values ('item', v_id::text, 'name', 'fr', rec.name);
    if rec.description is not null then
      insert into public.translations (entity_type, entity_id, field_name, locale, value)
        values ('item', v_id::text, 'description', 'fr', rec.description);
    end if;
  end loop;
end $$;

-- Caractéristiques mécaniques des armes, rattachées par relecture de
-- public.translations (jointure par nom devenue impossible, `items.name`
-- n'existant plus).
insert into public.weapon_properties (item_id, damage_dice, damage_type, properties, range)
select i.id, w.damage_dice, w.damage_type, w.properties::jsonb, w.range::jsonb
from (values
  ('Gourdin', '1d4', 'contondant', '["légère"]', null),
  ('Dague', '1d4', 'perforant', '["finesse", "légère", "lancer"]', '{"normal": 6, "max": 18}'),
  ('Gourdin à deux mains', '1d8', 'contondant', '["à deux mains"]', null),
  ('Hachette', '1d6', 'tranchant', '["légère", "lancer"]', '{"normal": 6, "max": 18}'),
  ('Javeline', '1d6', 'perforant', '["lancer"]', '{"normal": 9, "max": 36}'),
  ('Marteau léger', '1d4', 'contondant', '["légère", "lancer"]', '{"normal": 6, "max": 18}'),
  ('Masse d''armes', '1d6', 'contondant', '[]', null),
  ('Faucille', '1d4', 'tranchant', '["légère"]', null),
  ('Épieu', '1d6', 'perforant', '["polyvalente(1d8)", "lancer"]', '{"normal": 6, "max": 18}'),
  ('Bâton de combat', '1d6', 'contondant', '["polyvalente(1d8)"]', null),
  ('Arc court', '1d6', 'perforant', '["munitions", "à deux mains"]', '{"normal": 24, "max": 96}'),
  ('Arbalète légère', '1d8', 'perforant', '["munitions", "chargement", "à deux mains"]', '{"normal": 24, "max": 96}'),
  ('Dard', '1d4', 'perforant', '["finesse", "lancer"]', '{"normal": 6, "max": 18}'),
  ('Fronde', '1d4', 'contondant', '["munitions"]', '{"normal": 9, "max": 36}'),
  ('Hache d''armes', '1d8', 'tranchant', '["polyvalente(1d10)"]', null),
  ('Fléau d''armes', '1d8', 'contondant', '[]', null),
  ('Glaive', '1d10', 'tranchant', '["lourde", "allonge", "à deux mains"]', null),
  ('Grande hache', '1d12', 'tranchant', '["lourde", "à deux mains"]', null),
  ('Épée à deux mains', '2d6', 'tranchant', '["lourde", "à deux mains"]', null),
  ('Hallebarde', '1d10', 'tranchant', '["lourde", "allonge", "à deux mains"]', null),
  ('Lance de cavalerie', '1d12', 'perforant', '["allonge", "spéciale"]', null),
  ('Épée longue', '1d8', 'tranchant', '["polyvalente(1d10)"]', null),
  ('Maillet', '2d6', 'contondant', '["lourde", "à deux mains"]', null),
  ('Morgenstern', '1d8', 'perforant', '[]', null),
  ('Pique', '1d10', 'perforant', '["lourde", "allonge", "à deux mains"]', null),
  ('Rapière', '1d8', 'perforant', '["finesse"]', null),
  ('Cimeterre', '1d6', 'tranchant', '["finesse", "légère"]', null),
  ('Épée courte', '1d6', 'perforant', '["finesse", "légère"]', null),
  ('Trident', '1d6', 'perforant', '["polyvalente(1d8)", "lancer"]', '{"normal": 6, "max": 18}'),
  ('Pic de guerre', '1d8', 'perforant', '[]', null),
  ('Marteau de guerre', '1d8', 'contondant', '["polyvalente(1d10)"]', null),
  ('Fouet', '1d4', 'tranchant', '["finesse", "allonge"]', null),
  ('Sarbacane', '1', 'perforant', '["munitions", "chargement"]', '{"normal": 7.5, "max": 30}'),
  ('Arbalète de poing', '1d6', 'perforant', '["munitions", "légère", "chargement"]', '{"normal": 9, "max": 36}'),
  ('Arbalète lourde', '1d10', 'perforant', '["munitions", "lourde", "chargement", "à deux mains"]', '{"normal": 30, "max": 120}'),
  ('Arc long', '1d8', 'perforant', '["munitions", "lourde", "à deux mains"]', '{"normal": 45, "max": 180}'),
  ('Filet', null, null, '["spéciale", "lancer"]', '{"normal": 4.5, "max": 13.5}')
) as w(item_name, damage_dice, damage_type, properties, range)
join public.translations it
  on it.entity_type = 'item' and it.field_name = 'name' and it.locale = 'fr'
  and it.value = w.item_name
join public.items i on i.id::text = it.entity_id and i.category = 'arme'
where not exists (select 1 from public.weapon_properties);

-- Armures et boucliers.
insert into public.armor_properties (item_id, ac_base, ac_dex_bonus, strength_requirement, stealth_disadvantage)
select i.id, a.ac_base, a.ac_dex_bonus, a.strength_requirement, a.stealth_disadvantage
from (values
  ('Armure rembourrée', 11, 'illimite', null::int, true),
  ('Armure de cuir', 11, 'illimite', null::int, false),
  ('Armure de cuir clouté', 12, 'illimite', null::int, false),
  ('Armure de peau', 12, 'max_2', null::int, false),
  ('Chemise de mailles', 13, 'max_2', null::int, false),
  ('Armure d''écailles', 14, 'max_2', null::int, true),
  ('Cuirasse', 14, 'max_2', null::int, false),
  ('Demi-plate', 15, 'max_2', null::int, true),
  ('Cotte à anneaux', 14, 'aucun', null::int, true),
  ('Cotte de mailles', 16, 'aucun', 13, true),
  ('Harnois à lattes', 17, 'aucun', 15, true),
  ('Armure complète', 18, 'aucun', 15, true),
  ('Bouclier', 2, 'illimite', null::int, false)
) as a(item_name, ac_base, ac_dex_bonus, strength_requirement, stealth_disadvantage)
join public.translations it
  on it.entity_type = 'item' and it.field_name = 'name' and it.locale = 'fr'
  and it.value = a.item_name
join public.items i on i.id::text = it.entity_id
where not exists (select 1 from public.armor_properties);

-- Packs d'équipement (les 7 du Manuel des Joueurs). `contents` référence les
-- objets par nom en texte libre (pas de FK) — inchangé par ce chantier,
-- c'était déjà le cas avant la migration vers public.translations.
do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.equipment_packs) then
    return;
  end if;

  for rec in
    select * from (values
      ('Paquetage du cambrioleur', '[{"item": "Sac à dos", "quantity": 1}, {"item": "Bougie", "quantity": 5}, {"item": "Silex et briquet", "quantity": 1}, {"item": "Pied-de-biche", "quantity": 1}, {"item": "Marteau", "quantity": 1}, {"item": "Piton", "quantity": 10}, {"item": "Corde en chanvre (15 mètres)", "quantity": 1}, {"item": "Outre", "quantity": 1}, {"item": "Rations de voyage (1 jour)", "quantity": 5}, {"item": "Kit de déguisement", "quantity": 1}]'::jsonb),
      ('Paquetage du diplomate', '[{"item": "Malle", "quantity": 1}, {"item": "Étui à cartes ou à parchemins", "quantity": 2}, {"item": "Vêtements fins", "quantity": 1}, {"item": "Flacon d''encre", "quantity": 1}, {"item": "Plume", "quantity": 1}, {"item": "Lampe", "quantity": 1}, {"item": "Flacon d''huile", "quantity": 2}, {"item": "Papier (feuille)", "quantity": 5}, {"item": "Parfum", "quantity": 1}, {"item": "Cire à sceller", "quantity": 1}, {"item": "Savon", "quantity": 1}]'::jsonb),
      ('Paquetage de l''explorateur des donjons', '[{"item": "Sac à dos", "quantity": 1}, {"item": "Pied-de-biche", "quantity": 1}, {"item": "Marteau", "quantity": 1}, {"item": "Piton", "quantity": 10}, {"item": "Torche", "quantity": 10}, {"item": "Silex et briquet", "quantity": 1}, {"item": "Rations de voyage (1 jour)", "quantity": 10}, {"item": "Outre", "quantity": 1}, {"item": "Corde en chanvre (15 mètres)", "quantity": 1}]'::jsonb),
      ('Paquetage de l''artiste', '[{"item": "Sac à dos", "quantity": 1}, {"item": "Sac de couchage", "quantity": 1}, {"item": "Costume", "quantity": 2}, {"item": "Bougie", "quantity": 5}, {"item": "Rations de voyage (1 jour)", "quantity": 5}, {"item": "Outre", "quantity": 1}, {"item": "Kit de déguisement", "quantity": 1}]'::jsonb),
      ('Paquetage d''explorateur', '[{"item": "Sac à dos", "quantity": 1}, {"item": "Sac de couchage", "quantity": 1}, {"item": "Gamelle", "quantity": 1}, {"item": "Silex et briquet", "quantity": 1}, {"item": "Torche", "quantity": 10}, {"item": "Rations de voyage (1 jour)", "quantity": 10}, {"item": "Outre", "quantity": 1}, {"item": "Corde en chanvre (15 mètres)", "quantity": 1}]'::jsonb),
      ('Paquetage d''ecclésiastique', '[{"item": "Sac à dos", "quantity": 1}, {"item": "Couverture", "quantity": 1}, {"item": "Bougie", "quantity": 10}, {"item": "Silex et briquet", "quantity": 1}, {"item": "Encensoir", "quantity": 1}, {"item": "Encens", "quantity": 2}, {"item": "Habit", "quantity": 1}, {"item": "Rations de voyage (1 jour)", "quantity": 2}, {"item": "Outre", "quantity": 1}]'::jsonb),
      ('Paquetage d''érudit', '[{"item": "Sac à dos", "quantity": 1}, {"item": "Livre de savoir", "quantity": 1}, {"item": "Flacon d''encre", "quantity": 1}, {"item": "Plume", "quantity": 1}, {"item": "Petit couteau", "quantity": 1}, {"item": "Lettre d''un collègue", "quantity": 1}, {"item": "Papier (feuille)", "quantity": 10}, {"item": "Sacoche en cuir", "quantity": 1}]'::jsonb)
    ) as t(name, contents)
  loop
    insert into public.equipment_packs (contents) values (rec.contents::jsonb) returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value)
      values ('equipment_pack', v_id::text, 'name', 'fr', rec.name);
  end loop;
end $$;
