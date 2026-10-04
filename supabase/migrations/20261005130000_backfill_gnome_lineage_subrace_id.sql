-- Chantier "Personnages" (app mobile) — complète public.race_lineages pour le
-- Gnome, sur le même modèle que le Génasi (voir migration
-- 20260910110000_create_race_lineages_and_racial_innate_spells.sql).
--
-- Constat : pour le Génasi (race_id=23), les 4 lignes de lineage_group
-- 'genasi_elemental_type' ont déjà subrace_id renseigné, pointant vers la
-- sous-race homonyme — convention qui signale "cette lignée est strictement
-- redondante avec une sous-race existante, pas d'écran de choix de lignée
-- séparé, on dérive lineage_id depuis le subrace_id choisi". Pour le Gnome
-- (race_id=6), les 2 lignes de lineage_group '2024_lineage' ont subrace_id
-- NULL, alors que le Gnome a bien 2 sous-races homonymes. Conséquence
-- concrète : les sorts innés raciaux liés à la lignée (public.
-- racial_innate_spells, lignes avec lineage_id non nul pour le Gnome) ne
-- sont aujourd'hui jamais accordables côté mobile, puisque la résolution se
-- base sur subrace_id pour les races où lignée = sous-race.
--
-- Décision produit : pas de nouvel écran de choix de lignée pour le Gnome,
-- on réutilise le choix de sous-race déjà existant. Cette migration se
-- limite donc à un backfill (UPDATE) pour aligner le Gnome sur la
-- convention déjà en place pour le Génasi — pas de nouvelle table/colonne.
--
-- Appariement fait par nom plutôt que par id en dur : on joint la
-- traduction fr de la lignée (public.translations, entity_type=
-- 'race_lineage') à la traduction fr de la sous-race homonyme (entity_type=
-- 'subrace'), pour la race Gnome (race_id=6) uniquement. Vérifié en base
-- avant écriture de cette migration :
--   race_lineages.id=23 "Gnome des forêts" -> subraces.id=8 "Gnome des forêts"
--   race_lineages.id=24 "Gnome des roches" -> subraces.id=9 "Gnome des roches"
-- (public.subraces compte une 3e sous-race pour le Gnome, "Gnome des
-- profondeurs (Svirfnebelin)", qui n'a pas de ligne correspondante dans
-- lineage_group='2024_lineage' et n'est donc pas concernée ici : la jointure
-- par nom ne matche que les 2 lignées existantes.)

update public.race_lineages rl
set subrace_id = s.id
from public.translations lineage_name
join public.translations subrace_name
  on subrace_name.entity_type = 'subrace'
  and subrace_name.field_name = 'name'
  and subrace_name.locale = 'fr'
  and subrace_name.value = lineage_name.value
join public.subraces s
  on s.id = subrace_name.entity_id::int
  and s.race_id = 6
where lineage_name.entity_type = 'race_lineage'
  and lineage_name.field_name = 'name'
  and lineage_name.locale = 'fr'
  and rl.id = lineage_name.entity_id::int
  and rl.race_id = 6
  and rl.lineage_group = '2024_lineage'
  and rl.subrace_id is null;
