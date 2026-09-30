-- Bonus de caractéristiques des races « à bonus flexibles » (Monsters of the Multiverse,
-- Strixhaven...) : +2 à une caractéristique et +1 à une autre, ou +1 à trois
-- caractéristiques différentes, au choix du joueur.
--
-- Ces 23 races avaient `ability_bonuses = {}` : l'app mobile ne leur donnait aucun bonus
-- racial (3 points de caractéristiques perdus à la création). Nouvelle clé spéciale
-- `choice_flexible: true`, à côté de `choice_others` (Demi-elfe, Forgelier), lue par
-- l'app mobile (`racial_bonus_choice.dart`) et la Bibliothèque (`formatAbilityBonuses`).
--
-- Idempotente : ne touche que les races encore sans aucun bonus.

update public.races r
   set ability_bonuses = '{"choice_flexible": true}'::jsonb
  from public.translations t
 where t.entity_type = 'race'
   and t.field_name = 'name'
   and t.locale = 'fr'
   and t.entity_id = r.id::text
   and r.ability_bonuses = '{}'::jsonb
   and t.value in (
     'Aasimar', 'Centaure', 'Changeforme', 'Changelin', 'Conil', 'Fée', 'Firbolg',
     'Githyanki', 'Githzerai', 'Gobelin', 'Gobelours', 'Hobgobelin', 'Homme-lézard',
     'Kenku', 'Kobold', 'Minotaure', 'Orc', 'Owlin', 'Satyre', 'Tabaxi', 'Tortue',
     'Triton', 'Yuan-ti'
   );
