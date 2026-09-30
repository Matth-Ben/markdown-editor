-- Contenu D&D — corrections relevées par la comparaison de la base avec
-- dnd5e.wikidot.com et Open5e (2026-09-29), validées par Matthias.
--
-- 1. Héroïsme : 20260929100000_seed_cleric_domains_complete.sql l'a déclaré
--    absent du catalogue, mais il y est sous le nom « Vaillance » (id 53,
--    rapproché de « Heroism » par sa description anglaise). On le rattache
--    aux domaines de l'Ordre et de la Paix (niveau de clerc 1) et on aligne la
--    description de leur aptitude « Sorts de domaine (Niveau de clerc 1) ».
-- 2. « Aide » (sort mineur, id 2) est en réalité Guidance, dont le nom VF est
--    « Assistance » : deux sorts portaient le nom « Aide » (avec « Aide »,
--    niveau 2). Renommage seul — l'id est référencé par des personnages.
-- 3. « Défense féerique » (id 9) est un doublon de « Protection contre les
--    armes » (id 480, Blade Ward) : même description. L'id 9 n'est référencé
--    par aucun personnage, sort de sous-classe ni sort racial ; il est supprimé.
-- 4. Race « Nain des collines » : coquille vide (is_incomplete, sans taille,
--    vitesse ni traits) créée par l'import XML de l'app mobile, doublon de la
--    sous-race du même nom. Aucun personnage ne la référence ; supprimée.
--
-- Idempotente : chaque étape vérifie l'état avant d'agir.

-- 1. Héroïsme (« Vaillance ») pour l'Ordre et la Paix -----------------------

do $$
declare
  v_spell int;
  v_subclass int;
begin
  select sp.id into v_spell
    from public.spells sp
    join public.translations tr
      on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
     and tr.field_name = 'name' and tr.locale = 'fr'
   where tr.value = 'Vaillance' and sp.level = 1;

  if v_spell is null then
    raise exception 'Sort « Vaillance » (niveau 1) introuvable';
  end if;

  for v_subclass in
    select sc.id
      from public.subclasses sc
      join public.translations tr
        on tr.entity_type = 'subclass' and tr.entity_id = sc.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where sc.class_id = 3 and tr.value in ('Ordre', 'Paix')
  loop
    insert into public.subclass_spells (subclass_id, spell_id, class_level, grant_kind)
      values (v_subclass, v_spell, 1, 'always_prepared')
      on conflict (subclass_id, spell_id) do nothing;
  end loop;
end $$;

update public.translations d
   set value = replace(d.value, 'Héroïsme', 'Vaillance')
  from public.class_features cf
  join public.subclasses sc on sc.id = cf.subclass_id and sc.class_id = 3
  join public.translations sn
    on sn.entity_type = 'subclass' and sn.entity_id = sc.id::text
   and sn.field_name = 'name' and sn.locale = 'fr' and sn.value in ('Ordre', 'Paix')
 where d.entity_type = 'class_feature' and d.entity_id = cf.id::text
   and d.field_name = 'description' and d.locale = 'fr'
   and cf.choice_type = 'sort_domaine' and cf.level = 1
   and d.value like '%Héroïsme%';

-- 2. Guidance : « Aide » (niveau 0) -> « Assistance » -----------------------

update public.translations t
   set value = 'Assistance'
  from public.spells sp
 where t.entity_type = 'spell' and t.entity_id = sp.id::text
   and t.field_name = 'name' and t.locale = 'fr'
   and t.value = 'Aide' and sp.level = 0;

-- 3. Doublon de Blade Ward : « Défense féerique » ---------------------------

do $$
declare
  v_id int;
begin
  select sp.id into v_id
    from public.spells sp
    join public.translations tr
      on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
     and tr.field_name = 'name' and tr.locale = 'fr'
   where tr.value = 'Défense féerique' and sp.level = 0;

  if v_id is null then
    return;
  end if;
  if exists (select 1 from public.character_spells where spell_id = v_id)
     or exists (select 1 from public.subclass_spells where spell_id = v_id)
     or exists (select 1 from public.racial_innate_spells where spell_id = v_id) then
    raise exception 'Sort « Défense féerique » (id %) référencé : suppression annulée', v_id;
  end if;

  delete from public.spell_classes where spell_id = v_id;
  delete from public.translations where entity_type = 'spell' and entity_id = v_id::text;
  delete from public.spells where id = v_id;
end $$;

-- 4. Race placeholder « Nain des collines » ---------------------------------

do $$
declare
  v_id int;
begin
  select r.id into v_id
    from public.races r
    join public.translations tr
      on tr.entity_type = 'race' and tr.entity_id = r.id::text
     and tr.field_name = 'name' and tr.locale = 'fr'
   where tr.value = 'Nain des collines' and r.is_incomplete;

  if v_id is null then
    return;
  end if;
  if exists (select 1 from public.characters where race_id = v_id)
     or exists (select 1 from public.subraces where race_id = v_id)
     or exists (select 1 from public.race_lineages where race_id = v_id)
     or exists (select 1 from public.racial_innate_spells where race_id = v_id) then
    raise exception 'Race « Nain des collines » (id %) référencée : suppression annulée', v_id;
  end if;

  delete from public.translations where entity_type = 'race' and entity_id = v_id::text;
  delete from public.races where id = v_id;
end $$;
