-- Équipement de départ des classes (règles 2024 : option A = objets + or, option B = or
-- seul ; le Guerrier a trois options). L'app mobile ne proposait jusqu'ici que
-- l'équipement de l'historique : un Paladin démarrait sans armure ni bouclier.
--
-- Format de `classes.starting_equipment` (jsonb) :
--   {"options": [{"label": "A", "items": [{"item": "Cotte de mailles", "quantity": 1}], "gold": 9},
--                {"label": "B", "items": [], "gold": 150}]}
-- `item` est le nom FR d'un objet du catalogue (`translations`, entity_type 'item') ; un nom
-- sans correspondance (paquetages, grimoire, instrument au choix) devient une ligne
-- d'inventaire libre, même règle que l'équipement d'historique. Même format d'entrée que
-- `equipment_packs.contents`.
--
-- Idempotente.

alter table public.classes add column if not exists starting_equipment jsonb;

update public.classes c
   set starting_equipment = v.equipment::jsonb
  from (values
  ('Artificier', $j${"options": [
    {"label": "A", "gold": 16, "items": [
      {"item": "Armure de cuir", "quantity": 1}, {"item": "Dague", "quantity": 1},
      {"item": "Outils de voleur", "quantity": 1}, {"item": "Outils de bricoleur", "quantity": 1},
      {"item": "Paquetage de l'explorateur des donjons", "quantity": 1}]},
    {"label": "B", "gold": 150, "items": []}]}$j$),
  ('Barbare', $j${"options": [
    {"label": "A", "gold": 15, "items": [
      {"item": "Grande hache", "quantity": 1}, {"item": "Hachette", "quantity": 4},
      {"item": "Paquetage d'explorateur", "quantity": 1}]},
    {"label": "B", "gold": 75, "items": []}]}$j$),
  ('Barde', $j${"options": [
    {"label": "A", "gold": 19, "items": [
      {"item": "Armure de cuir", "quantity": 1}, {"item": "Dague", "quantity": 2},
      {"item": "Instrument de musique au choix", "quantity": 1},
      {"item": "Paquetage de l'artiste", "quantity": 1}]},
    {"label": "B", "gold": 90, "items": []}]}$j$),
  ('Clerc', $j${"options": [
    {"label": "A", "gold": 7, "items": [
      {"item": "Chemise de mailles", "quantity": 1}, {"item": "Bouclier", "quantity": 1},
      {"item": "Masse d'armes", "quantity": 1}, {"item": "Symbole sacré", "quantity": 1},
      {"item": "Paquetage d'ecclésiastique", "quantity": 1}]},
    {"label": "B", "gold": 110, "items": []}]}$j$),
  ('Druide', $j${"options": [
    {"label": "A", "gold": 9, "items": [
      {"item": "Armure de cuir", "quantity": 1}, {"item": "Bouclier", "quantity": 1},
      {"item": "Faucille", "quantity": 1}, {"item": "Bâton de combat", "quantity": 1},
      {"item": "Paquetage d'explorateur", "quantity": 1}, {"item": "Kit d'herboriste", "quantity": 1}]},
    {"label": "B", "gold": 50, "items": []}]}$j$),
  ('Ensorceleur', $j${"options": [
    {"label": "A", "gold": 28, "items": [
      {"item": "Épieu", "quantity": 1}, {"item": "Dague", "quantity": 2},
      {"item": "Focaliseur arcanique", "quantity": 1},
      {"item": "Paquetage de l'explorateur des donjons", "quantity": 1}]},
    {"label": "B", "gold": 50, "items": []}]}$j$),
  ('Guerrier', $j${"options": [
    {"label": "A", "gold": 4, "items": [
      {"item": "Cotte de mailles", "quantity": 1}, {"item": "Épée à deux mains", "quantity": 1},
      {"item": "Fléau d'armes", "quantity": 1}, {"item": "Javeline", "quantity": 8},
      {"item": "Paquetage de l'explorateur des donjons", "quantity": 1}]},
    {"label": "B", "gold": 11, "items": [
      {"item": "Armure de cuir clouté", "quantity": 1}, {"item": "Cimeterre", "quantity": 1},
      {"item": "Épée courte", "quantity": 1}, {"item": "Arc long", "quantity": 1},
      {"item": "Flèches (20)", "quantity": 1}, {"item": "Carquois", "quantity": 1},
      {"item": "Paquetage de l'explorateur des donjons", "quantity": 1}]},
    {"label": "C", "gold": 155, "items": []}]}$j$),
  ('Magicien', $j${"options": [
    {"label": "A", "gold": 5, "items": [
      {"item": "Dague", "quantity": 2}, {"item": "Bâton de combat", "quantity": 1},
      {"item": "Robe", "quantity": 1}, {"item": "Grimoire", "quantity": 1},
      {"item": "Paquetage d'érudit", "quantity": 1}]},
    {"label": "B", "gold": 55, "items": []}]}$j$),
  ('Moine', $j${"options": [
    {"label": "A", "gold": 11, "items": [
      {"item": "Épieu", "quantity": 1}, {"item": "Dague", "quantity": 5},
      {"item": "Outils d'artisan ou instrument de musique au choix", "quantity": 1},
      {"item": "Paquetage d'explorateur", "quantity": 1}]},
    {"label": "B", "gold": 50, "items": []}]}$j$),
  ('Occultiste', $j${"options": [
    {"label": "A", "gold": 15, "items": [
      {"item": "Armure de cuir", "quantity": 1}, {"item": "Faucille", "quantity": 1},
      {"item": "Dague", "quantity": 2}, {"item": "Focaliseur arcanique", "quantity": 1},
      {"item": "Livre", "quantity": 1}, {"item": "Paquetage d'érudit", "quantity": 1}]},
    {"label": "B", "gold": 100, "items": []}]}$j$),
  ('Paladin', $j${"options": [
    {"label": "A", "gold": 9, "items": [
      {"item": "Cotte de mailles", "quantity": 1}, {"item": "Bouclier", "quantity": 1},
      {"item": "Épée longue", "quantity": 1}, {"item": "Javeline", "quantity": 6},
      {"item": "Symbole sacré", "quantity": 1}, {"item": "Paquetage d'ecclésiastique", "quantity": 1}]},
    {"label": "B", "gold": 150, "items": []}]}$j$),
  ('Rôdeur', $j${"options": [
    {"label": "A", "gold": 7, "items": [
      {"item": "Armure de cuir clouté", "quantity": 1}, {"item": "Cimeterre", "quantity": 1},
      {"item": "Épée courte", "quantity": 1}, {"item": "Arc long", "quantity": 1},
      {"item": "Flèches (20)", "quantity": 1}, {"item": "Carquois", "quantity": 1},
      {"item": "Focaliseur druidique", "quantity": 1}, {"item": "Paquetage d'explorateur", "quantity": 1}]},
    {"label": "B", "gold": 150, "items": []}]}$j$),
  ('Roublard', $j${"options": [
    {"label": "A", "gold": 8, "items": [
      {"item": "Armure de cuir", "quantity": 1}, {"item": "Dague", "quantity": 2},
      {"item": "Épée courte", "quantity": 1}, {"item": "Arc court", "quantity": 1},
      {"item": "Flèches (20)", "quantity": 1}, {"item": "Carquois", "quantity": 1},
      {"item": "Outils de voleur", "quantity": 1}, {"item": "Paquetage du cambrioleur", "quantity": 1}]},
    {"label": "B", "gold": 100, "items": []}]}$j$)
  ) as v(class_name, equipment)
  join public.translations t
    on t.entity_type = 'class' and t.field_name = 'name' and t.locale = 'fr' and t.value = v.class_name
 where c.id = t.entity_id::int;
