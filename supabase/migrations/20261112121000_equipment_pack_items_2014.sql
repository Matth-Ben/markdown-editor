-- Vague 4 / P12 : contenu des paquetages d'équipement en lignes relationnelles (édition 2014 seulement).
--
-- Contexte : `equipment_packs.contents` est un jsonb `[{"item": <nom FR>, "quantity": n}]` sans FK, et
-- il contient des erreurs par rapport au Manuel des Joueurs 2014 (p. 151) : Cambrioleur (billes,
-- ficelle, clochette, lanterne à capote, 2 huiles absentes ; « kit de déguisement » inventé),
-- Ecclésiastique (boîte à aumônes absente), Érudit (« Lettre d'un collègue » et « Sacoche en cuir »
-- à retirer, « Papier » à remplacer par « Parchemin », petit sac de sable absent).
-- Décision de Matthias (12/11/2026) : corriger et éclater le 2014 maintenant ; le 2024 attend sa
-- validation contre le Manuel 2024 et N'EST PAS migré ici (aucune ligne `edition = '2024'`).
-- Spécification : docs/vague4-donnees-reference.md du dépôt mobile (audit regles-dnd du 12/11/2026).
--
-- Ce que fait la migration :
--   1. crée `public.equipment_pack_items` (pack_id, item_id, quantity, edition), lecture seule pour
--      les clients (RLS alignée sur `equipment_packs`/`items` : lecture pour tout `authenticated`,
--      aucune politique ni GRANT d'écriture) ;
--   2. ajoute au catalogue `items` les objets manquants (Cire à sceller, Savon et 7 objets sans
--      caractéristiques RAW dans le seed : poids 0, coût NULL) avec leur nom FR + EN dans
--      `translations` ;
--   3. corrige les poids du catalogue (Marteau, Gamelle, Sac de couchage) ;
--   4. peuple `equipment_pack_items` pour les 7 paquetages 2014, chaque ligne étant rapprochée de
--      `items.id` par nom FR (table de mappage explicite) ; une ligne non appariée ou ambiguë annule
--      toute la migration (RAISE EXCEPTION) : aucune ligne n'est perdue en silence.
--
-- NE SUPPRIME NI NE RENOMME `equipment_packs.contents` NI les noms FR des paquetages :
-- `classes.starting_equipment` (20260930210000) les référence par nom (« Paquetage d'explorateur »,
-- « Paquetage de l'explorateur des donjons »...) et continue donc de fonctionner. `contents` reste
-- tel quel (non corrigé, devenu redondant pour l'édition 2014 : la source de vérité est désormais
-- `equipment_pack_items`).
--
-- Unité de poids : `items.weight` est en kg ; le seed 2014 convertit à 0,45 kg/lb (Sac à dos 5 lb =
-- 2,5 kg... arrondis), le lot SRD 5.2 (20260930090200) à 0,5 kg/lb (Coffre 25 lb = 12,5 kg, Livre
-- 5 lb = 2,5 kg). Les corrections de poids ci-dessous suivent la spec (valeurs 0,45 kg/lb) ; la règle
-- de conversion unique reste une décision produit non tranchée ici.
--
-- Poids totaux RAW 2014 en livres (somme des poids RAW de chaque ligne ; contrôle vs la spec) :
--   Cambrioleur 47,5 | Diplomate 36 | Explorateur des donjons 61,5 | Artiste 38 | Explorateur 59 |
--   Ecclésiastique 24 (hypothèse : boîte à aumônes 1, encensoir 1, vêtements 4 lb...) | Érudit 10
--   (hypothèse : livre de savoir 5 lb). Détail Cambrioleur : sac 5 + billes 2 + pied-de-biche 5 +
--   marteau 3 + pitons 2,5 + lanterne 2 + 2 huiles 2 + 5 rations 10 + briquet 1 + outre 5 +
--   corde 10 = 47,5.
-- Totaux du CATALOGUE en kg avec les poids après correction (unités hétérogènes, voir plus haut) :
--   Cambrioleur 21,9 | Diplomate 17,7 | Explorateur des donjons 28,5 | Artiste 17,6 |
--   Explorateur 27,45 | Ecclésiastique 8,6 | Érudit 2,5 (les 7 objets sans stats RAW pèsent 0 ;
--   un « Livre de savoir » à 2,5 kg porterait l'Érudit à 5,0). Écarts avec la spec (21,4 / 16,2 /
--   27,7 / 17,1 / 26,6 / 10,8 / 4,5) = conversion 0,45 vs 0,5 kg/lb de certains objets du catalogue
--   (Coffre, Kit de déguisement, Piton, Billes...) et poids 0 des objets sans stats : à arbitrer.
--
-- Idempotente : table `if not exists`, objets créés seulement si leur nom FR n'existe pas, poids
-- fixés par nom, lignes de paquetage en `on conflict (pack_id, item_id, edition) do update`.

-- 1. Table ---------------------------------------------------------------------

create table if not exists public.equipment_pack_items (
  id int generated always as identity primary key,
  pack_id int not null references public.equipment_packs (id) on delete cascade,
  item_id int not null references public.items (id),
  quantity int not null check (quantity > 0),
  edition text not null check (edition in ('2014', '2024')),
  unique (pack_id, item_id, edition)
);

comment on table public.equipment_pack_items is
  'Contenu d''un paquetage d''équipement (une ligne par objet du catalogue `items`) et par édition des règles. Remplace, pour l''édition 2014, `equipment_packs.contents` (jsonb libre, conservé mais non corrigé). Seule l''édition 2014 est peuplée à ce jour. Table de référence : lecture authentifiée, aucune écriture client.';
comment on column public.equipment_pack_items.edition is
  'Édition des règles du contenu : 2014 ou 2024. Un même paquetage peut avoir un contenu par édition.';
comment on column public.equipment_packs.contents is
  'Ancien contenu libre du paquetage (jsonb [{"item": nom FR, "quantity": n}], sans FK, avec des erreurs vs le Manuel 2014). Conservé pour compatibilité ; la source de vérité du contenu 2014 est public.equipment_pack_items.';

create index if not exists equipment_pack_items_pack_idx on public.equipment_pack_items (pack_id);
create index if not exists equipment_pack_items_item_idx on public.equipment_pack_items (item_id);

alter table public.equipment_pack_items enable row level security;

-- Même politique de lecture que `equipment_packs` et `items` (public.authenticated, using true).
-- Pas de politique d'écriture : l'écriture client est refusée (RLS) ; le contenu s'alimente par
-- migration. (Les autres tables de référence ont des politiques admin ; ici la consigne est « aucune
-- écriture client », donc volontairement pas de politique is_admin().)
drop policy if exists "Authenticated users can read equipment_pack_items" on public.equipment_pack_items;
create policy "Authenticated users can read equipment_pack_items"
  on public.equipment_pack_items for select
  to authenticated
  using (true);

-- Privilèges : lecture seule pour `authenticated` ; rien pour `anon` (comme `equipment_packs`).
revoke all on table public.equipment_pack_items from anon, authenticated;
grant select on table public.equipment_pack_items to authenticated;

-- 2. Objets manquants du catalogue ------------------------------------------------
-- Cire à sceller (0,5 po) et Savon (0,02 po) : RAW, poids négligeable (0). Les 7 objets suivants
-- n'ont pas de caractéristiques dans le seed : poids 0 et coût NULL (choix produit, à confirmer ;
-- `items.weight` et `items.cost` sont nullables, le schéma le permet). Pas de description.

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
      ('Cire à sceller', 'Sealing Wax', 0::numeric, '{"amount": 0.5, "currency": "gp"}'::jsonb),
      ('Savon', 'Soap', 0::numeric, '{"amount": 0.02, "currency": "gp"}'::jsonb),
      ('Boîte à aumônes', 'Alms Box', 0::numeric, null::jsonb),
      ('Encensoir', 'Censer', 0::numeric, null::jsonb),
      ('Encens (bloc)', 'Incense (Block)', 0::numeric, null::jsonb),
      ('Vêtements sacerdotaux', 'Vestments', 0::numeric, null::jsonb),
      ('Petit couteau', 'Small Knife', 0::numeric, null::jsonb),
      ('Petit sac de sable', 'Little Bag of Sand', 0::numeric, null::jsonb),
      ('Livre de savoir', 'Book of Lore', 0::numeric, null::jsonb)
    ) as t(name_fr, name_en, weight, cost)
  loop
    if not exists (
      select 1 from public.translations tr
       where tr.entity_type = 'item' and tr.field_name = 'name'
         and tr.locale = 'fr' and tr.value = rec.name_fr
    ) then
      insert into public.items (category, weight, cost, consumable, source)
        values ('equipement_general', rec.weight, rec.cost, false, 'Manuel des Joueurs')
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('item', v_id::text, 'name', 'fr', rec.name_fr),
        ('item', v_id::text, 'name', 'en', rec.name_en);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'P12 : % objets ajoutés au catalogue (9 attendus au premier passage, 0 au rejeu).', v_inserted;
end $$;

-- 3. Corrections de poids du catalogue (kg) --------------------------------------
-- Marteau 0,5 -> 1,4 (3 lb) ; Gamelle 0,2 -> 0,45 (1 lb) ; Sac de couchage 3,4 -> 3,2 (7 lb).
-- Rapprochement par nom FR exact ; 0 ou plusieurs objets du même nom annule la migration.

do $$
declare
  rec record;
  v_ids int[];
begin
  for rec in
    select * from (values
      ('Marteau', 1.4::numeric),
      ('Gamelle', 0.45::numeric),
      ('Sac de couchage', 3.2::numeric)
    ) as t(name_fr, weight)
  loop
    select array_agg(i.id) into v_ids
      from public.items i
      join public.translations tr
        on tr.entity_type = 'item' and tr.field_name = 'name' and tr.locale = 'fr'
       and tr.entity_id = i.id::text
     where tr.value = rec.name_fr;
    if coalesce(array_length(v_ids, 1), 0) <> 1 then
      raise exception 'P12 : correction de poids « % » : % objet(s) trouvé(s), 1 attendu.',
        rec.name_fr, coalesce(array_length(v_ids, 1), 0);
    end if;
    update public.items set weight = rec.weight where id = v_ids[1];
  end loop;
end $$;

-- 4. Contenu des 7 paquetages 2014 (PHB p. 151) --------------------------------
-- Mappage explicite « nom FR de l'objet dans la spec -> nom FR du catalogue » (les noms divergents
-- sont rapprochés ici, jamais par approximation) :
--   Malle -> Coffre ; Étui à cartes ou à parchemins -> Étui à cartes ou parchemins ;
--   Parfum -> Parfum (fiole) ; Costume -> Costume de déguisement ; Papier -> Papier (feuille) ;
--   Parchemin -> Parchemin (feuille) ; Rations -> Rations de voyage (1 jour) ;
--   Bille(s) -> Billes (sac de 1 000) ; Ficelle -> Ficelle (3 m) ; Encens -> Encens (bloc) ;
--   Corde en chanvre -> Corde en chanvre (15 mètres) ; Livre de savoir -> Livre de savoir (créé).
-- (« Miroir » -> « Miroir en acier poli » : aucun paquetage 2014 n'en contient ; réservé au 2024.)

create temp table _pack_lines (
  pack_name text not null,
  item_name text not null,
  quantity int not null
);

insert into _pack_lines (pack_name, item_name, quantity) values
  -- Cambrioleur (16 po)
  ($t$Paquetage du cambrioleur$t$, $t$Sac à dos$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Billes (sac de 1 000)$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Ficelle (3 m)$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Clochette$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Bougie$t$, 5),
  ($t$Paquetage du cambrioleur$t$, $t$Pied-de-biche$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Marteau$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Piton$t$, 10),
  ($t$Paquetage du cambrioleur$t$, $t$Lanterne à capote$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Flacon d'huile$t$, 2),
  ($t$Paquetage du cambrioleur$t$, $t$Rations de voyage (1 jour)$t$, 5),
  ($t$Paquetage du cambrioleur$t$, $t$Silex et briquet$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Outre$t$, 1),
  ($t$Paquetage du cambrioleur$t$, $t$Corde en chanvre (15 mètres)$t$, 1),
  -- Diplomate (39 po)
  ($t$Paquetage du diplomate$t$, $t$Coffre$t$, 1),
  ($t$Paquetage du diplomate$t$, $t$Étui à cartes ou parchemins$t$, 2),
  ($t$Paquetage du diplomate$t$, $t$Vêtements fins$t$, 1),
  ($t$Paquetage du diplomate$t$, $t$Flacon d'encre$t$, 1),
  ($t$Paquetage du diplomate$t$, $t$Plume$t$, 1),
  ($t$Paquetage du diplomate$t$, $t$Lampe$t$, 1),
  ($t$Paquetage du diplomate$t$, $t$Flacon d'huile$t$, 2),
  ($t$Paquetage du diplomate$t$, $t$Papier (feuille)$t$, 5),
  ($t$Paquetage du diplomate$t$, $t$Parfum (fiole)$t$, 1),
  ($t$Paquetage du diplomate$t$, $t$Cire à sceller$t$, 1),
  ($t$Paquetage du diplomate$t$, $t$Savon$t$, 1),
  -- Explorateur des donjons (12 po)
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Sac à dos$t$, 1),
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Pied-de-biche$t$, 1),
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Marteau$t$, 1),
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Piton$t$, 10),
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Torche$t$, 10),
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Silex et briquet$t$, 1),
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Rations de voyage (1 jour)$t$, 10),
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Outre$t$, 1),
  ($t$Paquetage de l'explorateur des donjons$t$, $t$Corde en chanvre (15 mètres)$t$, 1),
  -- Artiste (40 po)
  ($t$Paquetage de l'artiste$t$, $t$Sac à dos$t$, 1),
  ($t$Paquetage de l'artiste$t$, $t$Sac de couchage$t$, 1),
  ($t$Paquetage de l'artiste$t$, $t$Costume de déguisement$t$, 2),
  ($t$Paquetage de l'artiste$t$, $t$Bougie$t$, 5),
  ($t$Paquetage de l'artiste$t$, $t$Rations de voyage (1 jour)$t$, 5),
  ($t$Paquetage de l'artiste$t$, $t$Outre$t$, 1),
  ($t$Paquetage de l'artiste$t$, $t$Kit de déguisement$t$, 1),
  -- Explorateur (10 po)
  ($t$Paquetage d'explorateur$t$, $t$Sac à dos$t$, 1),
  ($t$Paquetage d'explorateur$t$, $t$Sac de couchage$t$, 1),
  ($t$Paquetage d'explorateur$t$, $t$Gamelle$t$, 1),
  ($t$Paquetage d'explorateur$t$, $t$Silex et briquet$t$, 1),
  ($t$Paquetage d'explorateur$t$, $t$Torche$t$, 10),
  ($t$Paquetage d'explorateur$t$, $t$Rations de voyage (1 jour)$t$, 10),
  ($t$Paquetage d'explorateur$t$, $t$Outre$t$, 1),
  ($t$Paquetage d'explorateur$t$, $t$Corde en chanvre (15 mètres)$t$, 1),
  -- Ecclésiastique (19 po)
  ($t$Paquetage d'ecclésiastique$t$, $t$Sac à dos$t$, 1),
  ($t$Paquetage d'ecclésiastique$t$, $t$Couverture$t$, 1),
  ($t$Paquetage d'ecclésiastique$t$, $t$Bougie$t$, 10),
  ($t$Paquetage d'ecclésiastique$t$, $t$Silex et briquet$t$, 1),
  ($t$Paquetage d'ecclésiastique$t$, $t$Boîte à aumônes$t$, 1),
  ($t$Paquetage d'ecclésiastique$t$, $t$Encens (bloc)$t$, 2),
  ($t$Paquetage d'ecclésiastique$t$, $t$Encensoir$t$, 1),
  ($t$Paquetage d'ecclésiastique$t$, $t$Vêtements sacerdotaux$t$, 1),
  ($t$Paquetage d'ecclésiastique$t$, $t$Rations de voyage (1 jour)$t$, 2),
  ($t$Paquetage d'ecclésiastique$t$, $t$Outre$t$, 1),
  -- Érudit (40 po)
  ($t$Paquetage d'érudit$t$, $t$Sac à dos$t$, 1),
  ($t$Paquetage d'érudit$t$, $t$Livre de savoir$t$, 1),
  ($t$Paquetage d'érudit$t$, $t$Flacon d'encre$t$, 1),
  ($t$Paquetage d'érudit$t$, $t$Plume$t$, 1),
  ($t$Paquetage d'érudit$t$, $t$Parchemin (feuille)$t$, 10),
  ($t$Paquetage d'érudit$t$, $t$Petit sac de sable$t$, 1),
  ($t$Paquetage d'érudit$t$, $t$Petit couteau$t$, 1);

do $$
declare
  rec record;
  v_pack_ids int[];
  v_item_ids int[];
  v_lines int := 0;
  v_expected int;
  v_actual int;
begin
  -- Résolution stricte : chaque nom de paquetage et d'objet doit désigner exactement une ligne.
  for rec in select pack_name, item_name, quantity from _pack_lines loop
    select array_agg(p.id) into v_pack_ids
      from public.equipment_packs p
      join public.translations tp
        on tp.entity_type = 'equipment_pack' and tp.field_name = 'name' and tp.locale = 'fr'
       and tp.entity_id = p.id::text
     where tp.value = rec.pack_name;
    if coalesce(array_length(v_pack_ids, 1), 0) <> 1 then
      raise exception 'P12 : paquetage « % » : % trouvé(s), 1 attendu (ligne « % » non appariée).',
        rec.pack_name, coalesce(array_length(v_pack_ids, 1), 0), rec.item_name;
    end if;

    select array_agg(i.id) into v_item_ids
      from public.items i
      join public.translations ti
        on ti.entity_type = 'item' and ti.field_name = 'name' and ti.locale = 'fr'
       and ti.entity_id = i.id::text
     where ti.value = rec.item_name;
    if coalesce(array_length(v_item_ids, 1), 0) <> 1 then
      raise exception 'P12 : objet « % » (paquetage « % ») : % trouvé(s) dans le catalogue, 1 attendu.',
        rec.item_name, rec.pack_name, coalesce(array_length(v_item_ids, 1), 0);
    end if;

    insert into public.equipment_pack_items (pack_id, item_id, quantity, edition)
      values (v_pack_ids[1], v_item_ids[1], rec.quantity, '2014')
      on conflict (pack_id, item_id, edition) do update set quantity = excluded.quantity;
    v_lines := v_lines + 1;
  end loop;

  -- Contrôle de cohérence final : 7 paquetages 2014, autant de lignes que dans le mappage.
  select count(*) into v_expected from _pack_lines;
  select count(*) into v_actual from public.equipment_pack_items where edition = '2014';
  if v_actual <> v_expected then
    raise exception 'P12 : % lignes 2014 en base pour % attendues.', v_actual, v_expected;
  end if;
  if (select count(distinct pack_id) from public.equipment_pack_items where edition = '2014') <> 7 then
    raise exception 'P12 : 7 paquetages 2014 attendus dans equipment_pack_items.';
  end if;
  if exists (select 1 from public.equipment_pack_items where edition = '2024') then
    raise exception 'P12 : des lignes 2024 existent : cette migration ne doit pas en créer.';
  end if;
  raise notice 'P12 : % lignes de paquetage 2014 écrites (% attendues), 7 paquetages.', v_lines, v_expected;
end $$;

drop table if exists _pack_lines;
