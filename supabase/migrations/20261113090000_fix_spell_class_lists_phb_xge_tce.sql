-- Chantier "Personnages" (app mobile) — correction des listes de classes des sorts (spell_classes).
--
-- Périmètre figé (décision produit) : listes de classes = Manuel des Joueurs 2014 + Guide de
-- Xanathar + Chaudron de Tasha, c'est-à-dire, dans le JSON 5etools épinglé du script
-- scripts/import-spells.mjs (commit 50fe7eb…), `meta.class` + les entrées de `meta.classVariant`
-- dont `definedInSource` vaut XGE ou TCE. Les 6 sorts exclusivement 2024
-- (source = 'Manuel des Joueurs (2024)') ne sont pas touchés.
--
-- Différentiel calculé (rejeu des migrations en base jetable vs JSON 5etools, 507 sorts comparés) :
--   * 16 liens EN TROP, tous issus du socle Phase 1 (20260825090900_seed_spells_core.sql,
--     liste écrite à la main) :
--       Occultiste x 14 : Lueurs dansantes, Lumière, Message, Réparation, Armure de mage,
--         Déguisement, Détection de la magie, Identification, Chute plume, Sommeil,
--         Vague tonnerre, Vitesse supérieure, Image silencieuse, Bond ;
--       Clerc x 1 : Compréhension des langues ;
--       Ensorceleur x 1 : Rire hideux de Tasha.
--   * 5 liens MANQUANTS :
--       Barde x 3 : Feu follet, Serviteur invisible, Vague tonnerre ;
--       Ensorceleur x 1 : Compréhension des langues ;
--       Druide x 1 : Protection contre le mal et le bien (variante TCE du JSON, pas dans
--         la liste d'audit initiale).
--   * Aucun écart sur les 360 sorts du Manuel des Joueurs issus de l'import étendu, ni sur la
--     liste de l'Artificier (100 liens = 95 PHB/XGE/TCE + 5 Spelljammer/Strixhaven/Fizban,
--     identiques au JSON).
--
-- Les sorts sont retrouvés par (nom FR, niveau) dans public.translations, jamais par id numérique.
-- Chaque ligne du différentiel doit résoudre exactement 1 sort et 1 classe, sinon la migration
-- échoue (aucun no-op silencieux). Idempotente : DELETE ciblés + INSERT ... ON CONFLICT DO NOTHING.

drop table if exists tmp_spell_class_fixes;
create temporary table tmp_spell_class_fixes (
  action text not null check (action in ('delete', 'insert')),
  spell_name_fr text not null,
  spell_level int not null,
  class_name_fr text not null,
  spell_id int,
  class_id int
);

insert into tmp_spell_class_fixes (action, spell_name_fr, spell_level, class_name_fr) values
  -- Liens en trop (Occultiste)
  ('delete', 'Lueurs dansantes', 0, 'Occultiste'),
  ('delete', 'Lumière', 0, 'Occultiste'),
  ('delete', 'Message', 0, 'Occultiste'),
  ('delete', 'Réparation', 0, 'Occultiste'),
  ('delete', 'Armure de mage', 1, 'Occultiste'),
  ('delete', 'Déguisement', 1, 'Occultiste'),
  ('delete', 'Détection de la magie', 1, 'Occultiste'),
  ('delete', 'Identification', 1, 'Occultiste'),
  ('delete', 'Chute plume', 1, 'Occultiste'),
  ('delete', 'Sommeil', 1, 'Occultiste'),
  ('delete', 'Vague tonnerre', 1, 'Occultiste'),
  ('delete', 'Vitesse supérieure', 1, 'Occultiste'),
  ('delete', 'Image silencieuse', 1, 'Occultiste'),
  ('delete', 'Bond', 1, 'Occultiste'),
  -- Liens en trop (autres classes)
  ('delete', 'Compréhension des langues', 1, 'Clerc'),
  ('delete', 'Rire hideux de Tasha', 1, 'Ensorceleur'),
  -- Liens manquants
  ('insert', 'Feu follet', 1, 'Barde'),
  ('insert', 'Serviteur invisible', 1, 'Barde'),
  ('insert', 'Vague tonnerre', 1, 'Barde'),
  ('insert', 'Compréhension des langues', 1, 'Ensorceleur'),
  ('insert', 'Protection contre le mal et le bien', 1, 'Druide');

do $$
declare
  rec record;
  v_n int;
begin
  -- Résolution des sorts (nom FR + niveau) et des classes (nom FR).
  update tmp_spell_class_fixes f
     set spell_id = (
           select sp.id
             from public.spells sp
             join public.translations t
               on t.entity_type = 'spell' and t.entity_id = sp.id::text
              and t.field_name = 'name' and t.locale = 'fr'
            where t.value = f.spell_name_fr and sp.level = f.spell_level
         ),
         class_id = (
           select c.id
             from public.classes c
             join public.translations t
               on t.entity_type = 'class' and t.entity_id = c.id::text
              and t.field_name = 'name' and t.locale = 'fr'
            where t.value = f.class_name_fr
         );

  -- Un sort dupliqué sur (nom FR, niveau) ferait échouer la sous-requête scalaire ci-dessus
  -- (plus d'une ligne) ; un sort ou une classe absents donnent NULL : on refuse explicitement.
  for rec in
    select * from tmp_spell_class_fixes where spell_id is null or class_id is null
  loop
    raise exception 'Correction spell_classes : sort ou classe introuvable (% / niveau % / %)',
      rec.spell_name_fr, rec.spell_level, rec.class_name_fr;
  end loop;

  delete from public.spell_classes sc
   using tmp_spell_class_fixes f
   where f.action = 'delete' and sc.spell_id = f.spell_id and sc.class_id = f.class_id;

  insert into public.spell_classes (spell_id, class_id)
  select f.spell_id, f.class_id
    from tmp_spell_class_fixes f
   where f.action = 'insert'
  on conflict (spell_id, class_id) do nothing;

  -- Assertions finales : plus aucun lien supprimé, tous les liens ajoutés présents.
  select count(*) into v_n
    from tmp_spell_class_fixes f
    join public.spell_classes sc on sc.spell_id = f.spell_id and sc.class_id = f.class_id
   where f.action = 'delete';
  if v_n <> 0 then
    raise exception 'Correction spell_classes : % lien(s) à supprimer toujours présent(s)', v_n;
  end if;

  select count(*) into v_n
    from tmp_spell_class_fixes f
    join public.spell_classes sc on sc.spell_id = f.spell_id and sc.class_id = f.class_id
   where f.action = 'insert';
  if v_n <> (select count(*) from tmp_spell_class_fixes where action = 'insert') then
    raise exception 'Correction spell_classes : liens à ajouter manquants après insertion';
  end if;
end $$;

drop table tmp_spell_class_fixes;
