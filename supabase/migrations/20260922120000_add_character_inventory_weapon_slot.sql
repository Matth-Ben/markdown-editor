-- Rattrapage d'historique de migration (même classe de bug que D58 pour
-- `characters.is_incomplete`) : la colonne `character_inventory.weapon_slot`
-- existe déjà sur le projet Supabase distant (vérifié par un dump en
-- lecture seule de la structure, 09/10/2026 — colonne `text` nullable,
-- contrainte `CHECK` déjà présente côté base sous le nom
-- `character_inventory_weapon_slot_check`), mais n'a jamais été posée par
-- une migration de ce dépôt : `grep -rn weapon_slot supabase/migrations/`
-- ne retournait rien avant ce fichier. Elle a dû être ajoutée hors
-- migration à un moment donné. Conséquence concrète : `supabase db reset`
-- échouait dès qu'une requête touchait cette colonne
-- (`column character_inventory_1.weapon_slot does not exist`), ce qui
-- faisait échouer les tests d'intégration du dépôt mobile qui l'utilisent
-- depuis le 22/09/2026 (`lib/features/characters/domain/weapon_slot.dart`,
-- `lib/features/characters/data/character_inventory_row_mapper.dart`,
-- `character_repository.dart`) — datée ici en conséquence, juste après les
-- migrations du 22/09 (subclass spells / Blade Ward).
--
-- Sémantique (déduite du code client, confirmée par le dump distant) :
-- `NULL` = arme non équipée dans un set ; `'principal'`/`'secondaire'` =
-- set d'armes équipées correspondant (`WeaponSlot.value` côté mobile). La
-- contrainte CHECK ci-dessous reproduit celle déjà en place en base, pour
-- qu'elle existe aussi après un `db reset` local.
--
-- RLS déjà en place sur character_inventory (owner select/insert/update/
-- delete, 20260825090400_create_character_tables.sql) : aucune policy
-- supplémentaire nécessaire, la mise à jour de cette colonne passe par la
-- policy "Owner can update their character_inventory" déjà existante.
alter table public.character_inventory
  add column if not exists weapon_slot text
  check (weapon_slot in ('principal', 'secondaire'));

comment on column public.character_inventory.weapon_slot is
  'Set d''armes équipées (''principal''/''secondaire'') ; NULL si l''arme n''est pas équipée dans un set. Un personnage peut équiper au plus deux sets simultanément (voir lib/features/characters/domain/weapon_slot.dart, dépôt mobile). Ne concerne pas l''arme de pacte (Pacte de la lame).';
