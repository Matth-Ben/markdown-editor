-- Vague 4 / P13 : catégorie, source et édition des dons (`public.feats`).
--
-- Pourquoi : la table mélange 116 dons de natures très différentes (dons d'origine, dons généraux,
-- faveurs épiques de niveau 19, dons de suppléments de campagne...) sans aucun marqueur ; l'app
-- mobile ne peut ni les étiqueter ni les regrouper. Décisions de Matthias (12/11/2026) :
--   * la catégorie est celle de l'homonyme 2024 quand il existe, avec `edition = '2014'` quand le
--     texte en base est celui du Manuel 2014 / Tasha (c'est le cas de presque tous) ;
--   * un don sans homonyme 2024 est `legacy` ; défaut pour une source inconnue = `legacy` ;
--   * côté UI : simple pastille d'étiquette (« Campagne », « Épopée »), jamais de don grisé/masqué
--     (tâche dev-flutter distincte, après l'application de cette migration).
-- Spécification : docs/vague4-donnees-reference.md du dépôt mobile (audit regles-dnd du 12/11/2026).
--
-- Ce que fait la migration :
--   1. ajoute `category`, `source`, `edition` (nullables, avec CHECK) ;
--   2. remplit les trois colonnes par jointure sur le nom FR (public.translations, entity_type
--      'feat', field_name 'name', locale 'fr' : les ids de `feats` sont générés, donc le nom est la
--      seule clé stable), via la table de correspondance ci-dessous (116 noms) ;
--   3. contrôle de couverture (RAISE NOTICE + exceptions ciblées, voir plus bas).
--
-- Ne touche à AUCUN texte (nom, description) ni à `prerequisites`/`ability_increase`.
-- Aucune fonction/RPC existante n'est modifiée : apply_level_up (20261009090000) ne lit que
-- `feats.ability_increase` par id, la fiche partagée ne lit pas `feats` ; ajouter des colonnes
-- nullables est sans effet sur eux. Les GRANT (table entière) et la RLS de `feats` couvrent
-- automatiquement les nouvelles colonnes.
--
-- Idempotente : `add column if not exists`, contraintes gardées par un test sur pg_constraint, et le
-- backfill ne remplit que les lignes dont `category` est encore NULL (un rejeu ne réécrit donc pas
-- une correction manuelle faite ensuite par un admin ; pour re-classer un don, le mettre à NULL).
-- Aucun don 'fighting_style' n'est seedé à ce jour (0 ligne attendue pour cette catégorie : les
-- dons de style de combat 2024 restent à ajouter, sans invention de contenu ici).

-- 1. Colonnes et contraintes -------------------------------------------------

alter table public.feats add column if not exists category text;
alter table public.feats add column if not exists source text;
alter table public.feats add column if not exists edition text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'feats_category_check'
                  and conrelid = 'public.feats'::regclass) then
    alter table public.feats add constraint feats_category_check
      check (category in ('origin', 'general', 'fighting_style', 'epic_boon', 'legacy'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'feats_edition_check'
                  and conrelid = 'public.feats'::regclass) then
    alter table public.feats add constraint feats_edition_check
      check (edition in ('2014', '2024'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'feats_source_check'
                  and conrelid = 'public.feats'::regclass) then
    -- NULL autorisé (source inconnue). PHB14/PHB24 = Manuels des Joueurs 2014/2024, SRD52 = SRD 5.2,
    -- XGtE = Xanathar, TCoE = Tasha, FToD = Fizban, BGG = Bigby (Géants), PSAiM = Planescape,
    -- DSotDQ = Dragonlance. Empoignade (SRD 5.1) est rangé sous PHB14 : la liste de la spec n'a
    -- pas de valeur SRD51.
    alter table public.feats add constraint feats_source_check
      check (source in ('PHB14', 'PHB24', 'SRD52', 'XGtE', 'TCoE', 'FToD', 'BGG', 'PSAiM', 'DSotDQ'));
  end if;
end $$;

comment on column public.feats.category is
  'Catégorie du don : origin (don d''origine), general (don général), fighting_style (style de combat), epic_boon (faveur épique, niveau 19), legacy (sans équivalent 2024 : dons 2014 retirés, Xanathar, Tasha sans homonyme, suppléments de campagne). NULL = non classé.';
comment on column public.feats.source is
  'Livre source : PHB14, PHB24, SRD52, XGtE, TCoE, FToD, BGG, PSAiM, DSotDQ. NULL = inconnue. Les suppléments de campagne (FToD, BGG, PSAiM, DSotDQ) portent la pastille « Campagne » côté UI.';
comment on column public.feats.edition is
  'Édition du TEXTE stocké en base : 2014 (Manuel 2014, Tasha, suppléments) ou 2024 (SRD 5.2 / Manuel 2024). La catégorie, elle, suit l''homonyme 2024 quand il existe.';

create index if not exists feats_category_idx on public.feats (category);

-- 2. Table de correspondance (nom FR -> catégorie, source, édition) -----------

create temp table _feat_category_map (
  name_fr text primary key,
  category text not null,
  source text not null,
  edition text not null
);

insert into _feat_category_map (name_fr, category, source, edition) values
    ($t$Alerte$t$, 'origin', 'PHB14', '2014'),
    ($t$Guérisseur$t$, 'origin', 'PHB14', '2014'),
    ($t$Initié à la magie$t$, 'origin', 'PHB14', '2014'),
    ($t$Frappeur sauvage$t$, 'origin', 'PHB14', '2014'),
    ($t$Qualifié$t$, 'origin', 'PHB14', '2014'),
    ($t$Bagarreur de taverne$t$, 'origin', 'PHB14', '2014'),
    ($t$Robuste physiquement$t$, 'origin', 'PHB14', '2014'),
    ($t$Chanceux$t$, 'origin', 'PHB14', '2014'),
    ($t$Artisan$t$, 'origin', 'PHB24', '2024'),
    ($t$Musicien$t$, 'origin', 'PHB24', '2024'),
    ($t$Acteur$t$, 'general', 'PHB14', '2014'),
    ($t$Athlète$t$, 'general', 'PHB14', '2014'),
    ($t$Chargeur$t$, 'general', 'PHB14', '2014'),
    ($t$Expert des armes à distance$t$, 'general', 'PHB14', '2014'),
    ($t$Frappeur à deux armes$t$, 'general', 'PHB14', '2014'),
    ($t$Endurant$t$, 'general', 'PHB14', '2014'),
    ($t$Maître d'armes lourdes$t$, 'general', 'PHB14', '2014'),
    ($t$Pourfendeur de mages$t$, 'general', 'PHB14', '2014'),
    ($t$Cavalier hors pair$t$, 'general', 'PHB14', '2014'),
    ($t$Maître de la hallebarde$t$, 'general', 'PHB14', '2014'),
    ($t$Robuste$t$, 'general', 'PHB14', '2014'),
    ($t$Sentinelle$t$, 'general', 'PHB14', '2014'),
    ($t$Tireur d'élite$t$, 'general', 'PHB14', '2014'),
    ($t$Maître du bouclier$t$, 'general', 'PHB14', '2014'),
    ($t$Armure légère$t$, 'general', 'PHB14', '2014'),
    ($t$Duelliste défensif$t$, 'general', 'PHB14', '2014'),
    ($t$Sournois$t$, 'general', 'PHB14', '2014'),
    ($t$Meneur inspirant$t$, 'general', 'PHB14', '2014'),
    ($t$Observateur$t$, 'general', 'PHB14', '2014'),
    ($t$Armure lourde$t$, 'general', 'PHB14', '2014'),
    ($t$Maître de l'armure intermédiaire$t$, 'general', 'PHB14', '2014'),
    ($t$Armure intermédiaire$t$, 'general', 'PHB14', '2014'),
    ($t$Maître de l'armure lourde$t$, 'general', 'PHB14', '2014'),
    ($t$Adepte élémentaire$t$, 'general', 'PHB14', '2014'),
    ($t$Tireur d'élite occulte$t$, 'general', 'PHB14', '2014'),
    ($t$Guerrier-sorcier$t$, 'general', 'PHB14', '2014'),
    ($t$Rituels magiques$t$, 'general', 'PHB14', '2014'),
    ($t$Esprit vif$t$, 'general', 'PHB14', '2014'),
    ($t$Empoignade$t$, 'general', 'PHB14', '2014'),
    ($t$Entraînement aux armes de guerre$t$, 'general', 'PHB24', '2024'),
    ($t$Véloce$t$, 'general', 'PHB24', '2024'),
    ($t$Amélioration de caractéristique$t$, 'general', 'SRD52', '2024'),
    ($t$Explorateur de donjon$t$, 'legacy', 'PHB14', '2014'),
    ($t$Adepte martial$t$, 'legacy', 'PHB14', '2014'),
    ($t$Mobile$t$, 'legacy', 'PHB14', '2014'),
    ($t$Maître d'armes$t$, 'legacy', 'PHB14', '2014'),
    ($t$Linguiste$t$, 'legacy', 'PHB14', '2014'),
    ($t$Faveur de prouesse martiale$t$, 'epic_boon', 'SRD52', '2024'),
    ($t$Faveur de voyage dimensionnel$t$, 'epic_boon', 'SRD52', '2024'),
    ($t$Faveur du destin$t$, 'epic_boon', 'SRD52', '2024'),
    ($t$Faveur d'offensive irrésistible$t$, 'epic_boon', 'SRD52', '2024'),
    ($t$Faveur de rappel des sorts$t$, 'epic_boon', 'SRD52', '2024'),
    ($t$Faveur de l'esprit nocturne$t$, 'epic_boon', 'SRD52', '2024'),
    ($t$Faveur de vision véritable$t$, 'epic_boon', 'SRD52', '2024'),
    ($t$Faveur de résistance énergétique$t$, 'epic_boon', 'PHB24', '2024'),
    ($t$Faveur de robustesse$t$, 'epic_boon', 'PHB24', '2024'),
    ($t$Faveur de récupération$t$, 'epic_boon', 'PHB24', '2024'),
    ($t$Faveur de compétence$t$, 'epic_boon', 'PHB24', '2024'),
    ($t$Faveur de célérité$t$, 'epic_boon', 'PHB24', '2024'),
    ($t$Chef$t$, 'general', 'TCoE', '2014'),
    ($t$Écraseur$t$, 'general', 'TCoE', '2014'),
    ($t$Perforateur$t$, 'general', 'TCoE', '2014'),
    ($t$Empoisonneur$t$, 'general', 'TCoE', '2014'),
    ($t$Touché par l'ombre$t$, 'general', 'TCoE', '2014'),
    ($t$Touché par les fées$t$, 'general', 'TCoE', '2014'),
    ($t$Expert en compétences$t$, 'general', 'TCoE', '2014'),
    ($t$Trancheur$t$, 'general', 'TCoE', '2014'),
    ($t$Télékinésiste$t$, 'general', 'TCoE', '2014'),
    ($t$Télépathe$t$, 'general', 'TCoE', '2014'),
    ($t$Initié artificier$t$, 'legacy', 'TCoE', '2014'),
    ($t$Adepte occulte$t$, 'legacy', 'TCoE', '2014'),
    ($t$Initié au combat$t$, 'legacy', 'TCoE', '2014'),
    ($t$Artilleur$t$, 'legacy', 'TCoE', '2014'),
    ($t$Adepte de la métamagie$t$, 'legacy', 'TCoE', '2014'),
    ($t$Chance généreuse$t$, 'legacy', 'XGtE', '2014'),
    ($t$Terreur draconique$t$, 'legacy', 'XGtE', '2014'),
    ($t$Peau de dragon$t$, 'legacy', 'XGtE', '2014'),
    ($t$Haute magie drow$t$, 'legacy', 'XGtE', '2014'),
    ($t$Robustesse naine$t$, 'legacy', 'XGtE', '2014'),
    ($t$Précision elfique$t$, 'legacy', 'XGtE', '2014'),
    ($t$Évanescence$t$, 'legacy', 'XGtE', '2014'),
    ($t$Téléportation féerique$t$, 'legacy', 'XGtE', '2014'),
    ($t$Flammes de Phlégéthos$t$, 'legacy', 'XGtE', '2014'),
    ($t$Constitution infernale$t$, 'legacy', 'XGtE', '2014'),
    ($t$Fureur orque$t$, 'legacy', 'XGtE', '2014'),
    ($t$Prodige$t$, 'legacy', 'XGtE', '2014'),
    ($t$Seconde chance$t$, 'legacy', 'XGtE', '2014'),
    ($t$Agilité trapue$t$, 'legacy', 'XGtE', '2014'),
    ($t$Magie des elfes sylvains$t$, 'legacy', 'XGtE', '2014'),
    ($t$Don du dragon chromatique$t$, 'legacy', 'FToD', '2014'),
    ($t$Don du dragon de gemme$t$, 'legacy', 'FToD', '2014'),
    ($t$Don du dragon métallique$t$, 'legacy', 'FToD', '2014'),
    ($t$Frappe des géants$t$, 'legacy', 'BGG', '2014'),
    ($t$Braise du géant du feu$t$, 'legacy', 'BGG', '2014'),
    ($t$Fureur du géant du givre$t$, 'legacy', 'BGG', '2014'),
    ($t$Ruse du géant des nuages$t$, 'legacy', 'BGG', '2014'),
    ($t$Acuité du géant des pierres$t$, 'legacy', 'BGG', '2014'),
    ($t$Âme du géant des tempêtes$t$, 'legacy', 'BGG', '2014'),
    ($t$Vigueur du géant des collines$t$, 'legacy', 'BGG', '2014'),
    ($t$Façonneur de runes$t$, 'legacy', 'BGG', '2014'),
    ($t$Rejeton des plans extérieurs$t$, 'legacy', 'PSAiM', '2014'),
    ($t$Agent de l'ordre$t$, 'legacy', 'PSAiM', '2014'),
    ($t$Rejeton funeste$t$, 'legacy', 'PSAiM', '2014'),
    ($t$Cohorte du chaos$t$, 'legacy', 'PSAiM', '2014'),
    ($t$Émissaire des Terres Extérieures$t$, 'legacy', 'PSAiM', '2014'),
    ($t$Vagabond planaire$t$, 'legacy', 'PSAiM', '2014'),
    ($t$Héritier vertueux$t$, 'legacy', 'PSAiM', '2014'),
    ($t$Initié de la Haute Sorcellerie$t$, 'legacy', 'DSotDQ', '2014'),
    ($t$Adepte des Robes noires$t$, 'legacy', 'DSotDQ', '2014'),
    ($t$Adepte des Robes rouges$t$, 'legacy', 'DSotDQ', '2014'),
    ($t$Adepte des Robes blanches$t$, 'legacy', 'DSotDQ', '2014'),
    ($t$Favori divin$t$, 'legacy', 'DSotDQ', '2014'),
    ($t$Écuyer de Solamnie$t$, 'legacy', 'DSotDQ', '2014'),
    ($t$Chevalier de la Couronne$t$, 'legacy', 'DSotDQ', '2014'),
    ($t$Chevalier de la Rose$t$, 'legacy', 'DSotDQ', '2014'),
    ($t$Chevalier de l'Épée$t$, 'legacy', 'DSotDQ', '2014');

-- 3. Backfill idempotent ---------------------------------------------------
-- Pour chaque don dont la catégorie est vide : valeurs de la table de correspondance si son nom FR y
-- figure, sinon le défaut legacy / 2014 / source NULL.

update public.feats f
   set category = coalesce(m.category, 'legacy'),
       source   = m.source,
       edition  = coalesce(m.edition, '2014')
  from public.feats f2
  left join public.translations t
         on t.entity_type = 'feat' and t.field_name = 'name' and t.locale = 'fr'
        and t.entity_id = f2.id::text
  left join _feat_category_map m on m.name_fr = t.value
 where f.id = f2.id
   and f.category is null;

-- 4. Contrôle de couverture ---------------------------------------------------

do $$
declare
  v_total int;
  v_unmatched_names text;
  v_defaulted text;
  v_by_category text;
  v_map_size int;
  v_matched int;
  v_missing_map int;
begin
  select count(*) into v_total from public.feats;
  select count(*) into v_map_size from _feat_category_map;

  -- Dons effectivement appariés à une ligne de la table de correspondance.
  select count(*) into v_matched
    from public.feats f
    join public.translations t
      on t.entity_type = 'feat' and t.field_name = 'name' and t.locale = 'fr' and t.entity_id = f.id::text
    join _feat_category_map m on m.name_fr = t.value;

  -- Noms de la table de correspondance sans don en base.
  select string_agg(m.name_fr, ', ' order by m.name_fr), count(*)
    into v_unmatched_names, v_missing_map
    from _feat_category_map m
   where not exists (
     select 1 from public.translations t
      where t.entity_type = 'feat' and t.field_name = 'name' and t.locale = 'fr' and t.value = m.name_fr);

  -- Dons en base absents de la table de correspondance (reçoivent le défaut legacy/2014/NULL).
  select string_agg(coalesce(t.value, '(sans nom FR, id ' || f.id || ')'), ', ' order by f.id)
    into v_defaulted
    from public.feats f
    left join public.translations t
      on t.entity_type = 'feat' and t.field_name = 'name' and t.locale = 'fr' and t.entity_id = f.id::text
   where not exists (select 1 from _feat_category_map m where m.name_fr = t.value);

  select string_agg(cat || '=' || n, ', ' order by cat)
    into v_by_category
    from (select coalesce(category, 'NULL') as cat, count(*) as n
            from public.feats group by 1) s;

  raise notice 'P13 : % dons en base, % lignes dans la table de correspondance, % dons appariés.',
    v_total, v_map_size, v_matched;
  raise notice 'P13 : noms de la correspondance sans don en base (%) : %',
    v_missing_map, coalesce(v_unmatched_names, '(aucun)');
  raise notice 'P13 : dons non listés, classés par défaut legacy/2014/source NULL : %',
    coalesce(v_defaulted, '(aucun)');
  raise notice 'P13 : total par catégorie : %', coalesce(v_by_category, '(table vide)');

  -- Exceptions (annulent la migration), volontairement étroites :
  --  a) aucun don apparié alors qu'il y en a : la convention de `translations` a changé ou le
  --     filtre est faux, tout aurait été classé « legacy » en silence ;
  --  b) plus de dons appariés que de lignes de correspondance : un nom FR en double en base
  --     (l'un des doublons serait mal classé) ;
  --  c) dans l'état audité (116 dons), un nom de la correspondance sans don : les noms du seed et
  --     ceux de la spec ont divergé, il faut corriger la table avant d'appliquer. Si la base a
  --     d'autres effectifs (dons ajoutés/retirés depuis), seul le NOTICE ci-dessus est émis.
  if v_total > 0 and v_matched = 0 then
    raise exception 'P13 : aucun don apparié par nom FR (% dons en base) : migration annulée.', v_total;
  end if;
  if v_matched > v_map_size then
    raise exception 'P13 : % dons appariés pour % lignes de correspondance : noms FR en double en base.',
      v_matched, v_map_size;
  end if;
  if v_total = 116 and v_missing_map > 0 then
    raise exception 'P13 : 116 dons en base mais % noms de la correspondance sans don : %',
      v_missing_map, v_unmatched_names;
  end if;
  if exists (select 1 from public.feats where category is null or edition is null) then
    raise exception 'P13 : des dons sont restés sans catégorie ou sans édition.';
  end if;
end $$;

drop table if exists _feat_category_map;
