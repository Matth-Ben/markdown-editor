-- Chantier "Personnages" (app mobile) — sorts innés raciaux : renseigne les spell_id restés NULL.
--
-- 20260910110000 a créé public.racial_innate_spells avec 9 lignes dont spell_id = NULL (8 sorts
-- alors absents de public.spells + le choix libre du Haut-elfe). Les sorts existent depuis
-- (import étendu / socle Phase 1) mais les lignes n'ont jamais été reliées, et l'app ignore les
-- lignes sans spell_id. Cette migration relie les 8 lignes résolubles ; la 9e (Haut-elfe,
-- trait « Cantrip elfique », choix libre du joueur) reste volontairement NULL.
--
-- Rapprochement (nom FR de la note `unresolved_note`  ->  sort actuel en base, nom FR + niveau) :
--   « Lumières dansantes » (Dancing Lights)  ->  « Lueurs dansantes » (niv. 0)
--       lignes Drow classique (niv. perso 1) et Drow 2024 (niv. perso 1)
--   « Lueurs féeriques »   (Faerie Fire)      ->  « Feu follet » (niv. 1)
--       lignes Drow classique (niv. perso 3) et Drow 2024 (niv. perso 3)
--   « Illusion mineure »   (Minor Illusion)   ->  « Baguette d'illusion » (niv. 0)
--       lignes Gnome des forêts classique et 2024
--   « Flammes »            (Produce Flame)    ->  « Création de flamme » (niv. 0)
--       ligne Génasi du feu
--   « Grande foulée »      (Longstrider)      ->  « Vitesse supérieure » (niv. 1)
--       ligne Elfe des bois 2024
--
-- Les lignes sont repérées par leur note `unresolved_note` (stable d'un environnement à
-- l'autre, contrairement aux ids) ET par la garde `spell_id is null`. Une fois reliée, la note
-- « non trouvé… » devient fausse : elle est supprimée pour les lignes traitées. Les sorts cibles
-- doivent exister (exactement 1 par nom FR + niveau), sinon la migration échoue.
-- Idempotente : un rejeu ne trouve plus de ligne NULL à traiter.

do $$
declare
  rec record;
  v_spell_id int;
  v_n int;
begin
  for rec in
    select * from (values
      ('(Dancing Lights)', 'Lueurs dansantes', 0),
      ('(Faerie Fire)', 'Feu follet', 1),
      ('(Minor Illusion)', 'Baguette d''illusion', 0),
      ('(Produce Flame)', 'Création de flamme', 0),
      ('(Longstrider)', 'Vitesse supérieure', 1)
    ) as t(note_marker, spell_name_fr, spell_level)
  loop
    select sp.id into v_spell_id
      from public.spells sp
      join public.translations t
        on t.entity_type = 'spell' and t.entity_id = sp.id::text
       and t.field_name = 'name' and t.locale = 'fr'
     where t.value = rec.spell_name_fr and sp.level = rec.spell_level;
    if v_spell_id is null then
      raise exception 'Sorts innés : sort cible introuvable (% / niveau %)', rec.spell_name_fr, rec.spell_level;
    end if;

    -- Relie les lignes concernées, puis supprime la note « non trouvé » devenue fausse.
    with linked as (
      update public.racial_innate_spells r
         set spell_id = v_spell_id
       where r.spell_id is null
         and exists (
           select 1 from public.translations n
            where n.entity_type = 'racial_innate_spell' and n.field_name = 'unresolved_note'
              and n.entity_id = r.id::text
              and position(rec.note_marker in n.value) > 0
         )
      returning r.id
    )
    delete from public.translations n
     using linked
     where n.entity_type = 'racial_innate_spell' and n.field_name = 'unresolved_note'
       and n.entity_id = linked.id::text;
  end loop;

  -- Assertion finale : seule la ligne « choix libre » du Haut-elfe peut rester sans sort.
  select count(*) into v_n
    from public.racial_innate_spells r
   where r.spell_id is null
     and not exists (
       select 1 from public.translations n
        where n.entity_type = 'racial_innate_spell' and n.field_name = 'unresolved_note'
          and n.entity_id = r.id::text
          and n.value like 'Choix libre du joueur%'
     );
  if v_n <> 0 then
    raise exception 'Sorts innés : % ligne(s) racial_innate_spells sans spell_id non résolue(s)', v_n;
  end if;
end $$;
