-- Corrections après l'import des créatures SRD 5.2 (20260930160000 et suivantes).
--
-- 1. Tailles : la source (Open5e v2) ne connaît pas la taille « Très petite » et ramène les
--    tailles doubles du Manuel des Monstres 2024 (« Moyenne ou Petite ») à « Small ». Les 84
--    créatures importées en « Petite » sont reprises d'après le SRD 5.2.
-- 2. Lecture anonyme : la policy de lecture des traductions par les visiteurs de la
--    Bibliothèque ne couvrait pas les créatures, invocations, lignées, options de classe et
--    historiques, affichés sans nom hors connexion.
--
-- Idempotente.

update public.creatures c
   set size = v.size
  from (values
    ('Archmage', 'Moyenne ou Petite'), ('Assassin', 'Moyenne ou Petite'),
    ('Badger', 'Très petite'), ('Bandit', 'Moyenne ou Petite'), ('Bandit Captain', 'Moyenne ou Petite'),
    ('Bat', 'Très petite'), ('Berserker', 'Moyenne ou Petite'), ('Cat', 'Très petite'),
    ('Commoner', 'Moyenne ou Petite'), ('Crab', 'Très petite'), ('Cultist', 'Moyenne ou Petite'),
    ('Cultist Fanatic', 'Moyenne ou Petite'), ('Druid', 'Moyenne ou Petite'), ('Flying Snake', 'Très petite'),
    ('Frog', 'Très petite'), ('Gladiator', 'Moyenne ou Petite'), ('Guard', 'Moyenne ou Petite'),
    ('Guard Captain', 'Moyenne ou Petite'), ('Hawk', 'Très petite'), ('Homunculus', 'Très petite'),
    ('Imp', 'Très petite'), ('Knight', 'Moyenne ou Petite'), ('Lizard', 'Très petite'),
    ('Mage', 'Moyenne ou Petite'), ('Mummy', 'Moyenne ou Petite'), ('Mummy Lord', 'Moyenne ou Petite'),
    ('Noble', 'Moyenne ou Petite'), ('Owl', 'Très petite'), ('Piranha', 'Très petite'),
    ('Pirate', 'Moyenne ou Petite'), ('Pirate Captain', 'Moyenne ou Petite'), ('Priest', 'Moyenne ou Petite'),
    ('Priest Acolyte', 'Moyenne ou Petite'), ('Pseudodragon', 'Très petite'), ('Quasit', 'Très petite'),
    ('Rat', 'Très petite'), ('Raven', 'Très petite'), ('Scorpion', 'Très petite'),
    ('Scout', 'Moyenne ou Petite'), ('Seahorse', 'Très petite'), ('Sphinx of Wonder', 'Très petite'),
    ('Spider', 'Très petite'), ('Sprite', 'Très petite'), ('Spy', 'Moyenne ou Petite'),
    ('Stirge', 'Très petite'), ('Tough', 'Moyenne ou Petite'), ('Tough Boss', 'Moyenne ou Petite'),
    ('Vampire', 'Moyenne ou Petite'), ('Vampire Familiar', 'Moyenne ou Petite'),
    ('Vampire Spawn', 'Moyenne ou Petite'), ('Venomous Snake', 'Très petite'),
    ('Warrior Infantry', 'Moyenne ou Petite'), ('Warrior Veteran', 'Moyenne ou Petite'),
    ('Weasel', 'Très petite'), ('Werebear', 'Moyenne ou Petite'), ('Wereboar', 'Moyenne ou Petite'),
    ('Wererat', 'Moyenne ou Petite'), ('Weretiger', 'Moyenne ou Petite'), ('Werewolf', 'Moyenne ou Petite'),
    ('Will-o''-Wisp', 'Très petite'), ('Wraith', 'Moyenne ou Petite')
  ) as v(name_en, size)
  join public.translations t
    on t.entity_type = 'creature' and t.field_name = 'name' and t.locale = 'en' and t.value = v.name_en
 where c.id = t.entity_id::int
   and c.size is distinct from v.size;

drop policy if exists "Anonymous users can read library translations" on public.translations;
create policy "Anonymous users can read library translations"
  on public.translations
  for select
  to anon
  using (entity_type = any (array[
    'spell', 'race', 'subrace', 'class', 'subclass', 'class_feature', 'feat', 'item',
    'creature', 'invocation', 'race_lineage', 'class_option', 'background'
  ]));
