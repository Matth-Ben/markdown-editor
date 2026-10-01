-- Données structurées pour deux règles que l'app mobile ne pouvait pas appliquer :
--
-- 1. Demi-dons : `feats.ability_increase` (jsonb) — caractéristiques éligibles au +1 du don,
--    montant et plafond : {"abilities": ["str", "dex"], "amount": 1, "max": 20}. Plafond 30
--    pour les faveurs épiques. `null` pour un don sans augmentation. Reprend le texte de la
--    description de chaque don (« Force ou Dextérité +1 (max. 20) »...).
--
-- 2. Classe d'armure des objets magiques :
--    - `armor_properties.slot` ('armure' | 'bouclier') : pour les armures et boucliers
--      magiques (catégorie `objet_magique`), qui reçoivent ici leurs propriétés d'armure
--      (Harnois nain 20, Bouclier +2 = 4...) ; `null` = déduit de `items.category`.
--    - `items.ac_bonus` + `items.ac_bonus_kind` : bonus de CA d'un objet, selon sa nature —
--      'toujours' (Anneau/Cape de protection, bonus magique d'une armure à harmonisation),
--      'avec_armure' (Armure +N, ajoutée à l'armure portée), 'sans_armure_ni_bouclier'
--      (Bracelets de défense), 'base_sans_armure' (Robe de l'archimage : CA de base 15 + Dex).
--      Un objet qui requiert une harmonisation ne compte que s'il est harmonisé (app).
--
-- Idempotente.

-- 1. Demi-dons ---------------------------------------------------------------

alter table public.feats add column if not exists ability_increase jsonb;

update public.feats f
   set ability_increase = jsonb_build_object(
         'abilities', to_jsonb(v.abilities),
         'amount', 1,
         'max', v.max_score)
  from (values
    ('Acteur', array['cha'], 20),
    ('Athlète', array['str', 'dex'], 20),
    ('Endurant', array['con'], 20),
    ('Robuste', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 20),
    ('Bagarreur de taverne', array['str', 'con'], 20),
    ('Maître d''armes', array['str', 'dex'], 20),
    ('Armure légère', array['str', 'dex'], 20),
    ('Observateur', array['int', 'wis'], 20),
    ('Armure lourde', array['str'], 20),
    ('Armure intermédiaire', array['str', 'dex'], 20),
    ('Maître de l''armure lourde', array['str'], 20),
    ('Linguiste', array['int'], 20),
    ('Esprit vif', array['int'], 20),
    ('Faveur de prouesse martiale', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de voyage dimensionnel', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur du destin', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur d''offensive irrésistible', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de rappel des sorts', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de l''esprit nocturne', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de vision véritable', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de résistance énergétique', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de robustesse', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de récupération', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de compétence', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Faveur de célérité', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 30),
    ('Terreur draconique', array['str', 'con', 'cha'], 20),
    ('Peau de dragon', array['str', 'con', 'cha'], 20),
    ('Robustesse naine', array['con'], 20),
    ('Précision elfique', array['dex', 'int', 'wis', 'cha'], 20),
    ('Évanescence', array['dex', 'int'], 20),
    ('Téléportation féerique', array['int', 'cha'], 20),
    ('Flammes de Phlégéthos', array['int', 'cha'], 20),
    ('Constitution infernale', array['con'], 20),
    ('Fureur orque', array['str', 'con'], 20),
    ('Seconde chance', array['dex', 'con', 'cha'], 20),
    ('Agilité trapue', array['str', 'dex'], 20),
    ('Chef', array['con', 'wis'], 20),
    ('Écraseur', array['str', 'con'], 20),
    ('Touché par les fées', array['int', 'wis', 'cha'], 20),
    ('Artilleur', array['dex'], 20),
    ('Perforateur', array['str', 'dex'], 20),
    ('Touché par l''ombre', array['int', 'wis', 'cha'], 20),
    ('Expert en compétences', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 20),
    ('Trancheur', array['str', 'dex'], 20),
    ('Télékinésiste', array['int', 'wis', 'cha'], 20),
    ('Télépathe', array['int', 'wis', 'cha'], 20),
    ('Entraînement aux armes de guerre', array['str', 'dex'], 20),
    ('Véloce', array['dex', 'con'], 20),
    ('Don du dragon de gemme', array['int', 'wis', 'cha'], 20),
    ('Braise du géant du feu', array['str', 'con', 'wis'], 20),
    ('Fureur du géant du givre', array['str', 'con', 'wis'], 20),
    ('Ruse du géant des nuages', array['str', 'con', 'cha'], 20),
    ('Acuité du géant des pierres', array['str', 'con', 'wis'], 20),
    ('Âme du géant des tempêtes', array['str', 'wis', 'cha'], 20),
    ('Vigueur du géant des collines', array['str', 'con', 'wis'], 20),
    ('Agent de l''ordre', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 20),
    ('Rejeton funeste', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 20),
    ('Cohorte du chaos', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 20),
    ('Émissaire des Terres Extérieures', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 20),
    ('Héritier vertueux', array['str', 'dex', 'con', 'int', 'wis', 'cha'], 20),
    ('Chevalier de la Couronne', array['str', 'dex', 'con'], 20),
    ('Chevalier de la Rose', array['con', 'wis', 'cha'], 20),
    ('Chevalier de l''Épée', array['int', 'wis', 'cha'], 20)
  ) as v(feat_name, abilities, max_score)
  join public.translations t
    on t.entity_type = 'feat' and t.field_name = 'name' and t.locale = 'fr' and t.value = v.feat_name
 where f.id = t.entity_id::int;

-- 2. Classe d'armure des objets magiques ----------------------------------

alter table public.armor_properties add column if not exists slot text;
alter table public.armor_properties drop constraint if exists armor_properties_slot_check;
alter table public.armor_properties
  add constraint armor_properties_slot_check check (slot in ('armure', 'bouclier'));

alter table public.items add column if not exists ac_bonus integer;
alter table public.items add column if not exists ac_bonus_kind text;
alter table public.items drop constraint if exists items_ac_bonus_kind_check;
alter table public.items
  add constraint items_ac_bonus_kind_check
  check (ac_bonus_kind in ('toujours', 'avec_armure', 'sans_armure_ni_bouclier', 'base_sans_armure'));

-- Armures et boucliers magiques de type fixe (bonus sans harmonisation inclus dans ac_base).
insert into public.armor_properties (item_id, ac_base, ac_dex_bonus, strength_requirement, stealth_disadvantage, slot)
select t.entity_id::int, v.ac_base, v.ac_dex_bonus, v.strength, v.stealth, v.slot
  from (values
    ('Armure d''écailles de dragon', 14, 'max_2', null::int, true, 'armure'),
    ('Armure d''invulnérabilité', 18, 'aucun', 15, true, 'armure'),
    ('Armure de vulnérabilité', 18, 'aucun', 15, true, 'armure'),
    ('Armure démoniaque', 18, 'aucun', 15, true, 'armure'),
    ('Armure éthérée', 18, 'aucun', 15, true, 'armure'),
    ('Cotte de mailles elfique', 14, 'max_2', null::int, false, 'armure'),
    ('Harnois nain', 20, 'aucun', 15, true, 'armure'),
    ('Bouclier +1', 3, 'illimite', null::int, false, 'bouclier'),
    ('Bouclier +2', 4, 'illimite', null::int, false, 'bouclier'),
    ('Bouclier +3', 5, 'illimite', null::int, false, 'bouclier'),
    ('Bouclier animé', 2, 'illimite', null::int, false, 'bouclier'),
    ('Bouclier attrape-flèches', 2, 'illimite', null::int, false, 'bouclier'),
    ('Bouclier d''attraction des projectiles', 2, 'illimite', null::int, false, 'bouclier'),
    ('Bouclier gardesort', 2, 'illimite', null::int, false, 'bouclier')
  ) as v(item_name, ac_base, ac_dex_bonus, strength, stealth, slot)
  join public.translations t
    on t.entity_type = 'item' and t.field_name = 'name' and t.locale = 'fr' and t.value = v.item_name
on conflict (item_id) do update
   set ac_base = excluded.ac_base,
       ac_dex_bonus = excluded.ac_dex_bonus,
       strength_requirement = excluded.strength_requirement,
       stealth_disadvantage = excluded.stealth_disadvantage,
       slot = excluded.slot;

-- Bonus de CA (les objets à harmonisation ne comptent qu'harmonisés, côté app).
update public.items i
   set ac_bonus = v.bonus, ac_bonus_kind = v.kind
  from (values
    ('Armure +1', 1, 'avec_armure'),
    ('Armure +2', 2, 'avec_armure'),
    ('Armure +3', 3, 'avec_armure'),
    ('Armure d''écailles de dragon', 1, 'toujours'),
    ('Armure démoniaque', 1, 'toujours'),
    ('Anneau de protection', 1, 'toujours'),
    ('Cape de protection', 1, 'toujours'),
    ('Bracelets de défense', 2, 'sans_armure_ni_bouclier'),
    ('Robe de l''archimage', 15, 'base_sans_armure')
  ) as v(item_name, bonus, kind)
  join public.translations t
    on t.entity_type = 'item' and t.field_name = 'name' and t.locale = 'fr' and t.value = v.item_name
 where i.id = t.entity_id::int;
