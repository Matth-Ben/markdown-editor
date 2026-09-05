-- Chantier "Personnages" (app mobile) — comble un gap de schéma pour le
-- repos court (character_detail_screen.dart côté mobile) : rien ne suit
-- combien de dés de vie un personnage a déjà dépensés depuis son dernier
-- repos long, alors que la règle RAW 5e permet de dépenser un dé de vie
-- pour récupérer des PV pendant un repos court.
--
-- Sur character_classes et pas characters : un personnage a un dé de vie
-- par niveau de classe, et le type de dé (classes.hit_die) dépend de la
-- classe. En prévision du multiclassage (actuellement bloqué côté mobile,
-- mais chantier séparé de cette même session qui lève ce blocage juste
-- après celui-ci), une ligne par classe permet de suivre correctement le
-- nombre de dés dépensés PAR TYPE DE DÉ. Pour un personnage mono-classé
-- (100% des personnages existants aujourd'hui), c'est simplement une seule
-- ligne, donc pas de complexité ajoutée dans l'immédiat.
--
-- Pas de RLS à ajouter : les policies existantes sur character_classes
-- (20260825090400_create_character_tables.sql pour le propriétaire,
-- 20260830100100_create_character_campaigns.sql pour le MJ en lecture
-- seule via story_owner_can_read_character) couvrent déjà toutes les
-- colonnes de la table — les policies RLS Postgres portent sur des lignes,
-- pas des colonnes.

alter table public.character_classes
  add column hit_dice_spent integer not null default 0;

alter table public.character_classes
  add constraint character_classes_hit_dice_spent_range
  check (hit_dice_spent >= 0 and hit_dice_spent <= level);
