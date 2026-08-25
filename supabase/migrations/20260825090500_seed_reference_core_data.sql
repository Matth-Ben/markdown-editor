-- Chantier "Personnages" (app mobile) — Phase 1 — Peuplement du socle.
-- Les 6 caractéristiques, les 18 compétences, les 9 alignements, les
-- langues standard/exotiques du Manuel des Joueurs, et les outils/instruments
-- avec lesquels on peut être compétent. Contenu en français directement
-- (voir 07-source-donnees-i18n.md — pas de couche EN pour la Phase 1).
--
-- Le nom affiché de chaque entrée est stocké dans public.translations
-- (locale 'fr') plutôt que dans une colonne `name` — voir migration
-- 20260825090050. Comme les tables `skills`/`alignments`/`languages`/`tools`
-- utilisent un id `generated always as identity` (inconnu avant insertion),
-- chaque ligne est insérée individuellement dans une boucle PL/pgSQL afin de
-- capturer son id via `returning ... into` et l'associer sans ambiguïté à sa
-- traduction — une jointure par nom n'est plus possible puisque `name`
-- n'existe plus comme colonne. `abilities` fait exception : son id est une
-- clé texte déjà connue ('str', 'dex'...), donc pas besoin de boucle.
--
-- Idempotence : chaque bloc vérifie que sa table cible est vide avant
-- d'insérer, pour permettre de rejouer la migration sans dupliquer (mêmes
-- garanties que le `on conflict do nothing` de la version précédente, mais
-- au niveau du bloc plutôt que ligne à ligne, requis par la boucle).

insert into public.abilities (id, "order") values
  ('str', 1),
  ('dex', 2),
  ('con', 3),
  ('int', 4),
  ('wis', 5),
  ('cha', 6)
on conflict (id) do nothing;

insert into public.translations (entity_type, entity_id, field_name, locale, value) values
  ('ability', 'str', 'name', 'fr', 'Force'),
  ('ability', 'dex', 'name', 'fr', 'Dextérité'),
  ('ability', 'con', 'name', 'fr', 'Constitution'),
  ('ability', 'int', 'name', 'fr', 'Intelligence'),
  ('ability', 'wis', 'name', 'fr', 'Sagesse'),
  ('ability', 'cha', 'name', 'fr', 'Charisme')
on conflict (entity_type, entity_id, field_name, locale) do nothing;

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.skills) then
    return;
  end if;

  for rec in
    select * from (values
      ('Acrobaties', 'dex'),
      ('Arcanes', 'int'),
      ('Athlétisme', 'str'),
      ('Discrétion', 'dex'),
      ('Dressage', 'wis'),
      ('Escamotage', 'dex'),
      ('Histoire', 'int'),
      ('Intimidation', 'cha'),
      ('Investigation', 'int'),
      ('Médecine', 'wis'),
      ('Nature', 'int'),
      ('Perception', 'wis'),
      ('Perspicacité', 'wis'),
      ('Persuasion', 'cha'),
      ('Religion', 'int'),
      ('Représentation', 'cha'),
      ('Survie', 'wis'),
      ('Tromperie', 'cha')
    ) as t(name, ability_id)
  loop
    insert into public.skills (ability_id) values (rec.ability_id) returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value)
      values ('skill', v_id::text, 'name', 'fr', rec.name);
  end loop;
end $$;

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.alignments) then
    return;
  end if;

  for rec in
    select * from (values
      ('Loyal Bon'),
      ('Neutre Bon'),
      ('Chaotique Bon'),
      ('Loyal Neutre'),
      ('Neutre'),
      ('Chaotique Neutre'),
      ('Loyal Mauvais'),
      ('Neutre Mauvais'),
      ('Chaotique Mauvais')
    ) as t(name)
  loop
    insert into public.alignments default values returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value)
      values ('alignment', v_id::text, 'name', 'fr', rec.name);
  end loop;
end $$;

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.languages) then
    return;
  end if;

  for rec in
    select * from (values
      ('Commun', 'standard'),
      ('Nain', 'standard'),
      ('Elfique', 'standard'),
      ('Géant', 'standard'),
      ('Gnome', 'standard'),
      ('Gobelin', 'standard'),
      ('Halfelin', 'standard'),
      ('Orc', 'standard'),
      ('Abyssal', 'exotique'),
      ('Céleste', 'exotique'),
      ('Draconique', 'exotique'),
      ('Langue profonde', 'exotique'),
      ('Infernal', 'exotique'),
      ('Primordial', 'exotique'),
      ('Sylvestre', 'exotique'),
      ('Sous-commun', 'exotique')
    ) as t(name, type)
  loop
    insert into public.languages (type) values (rec.type) returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value)
      values ('language', v_id::text, 'name', 'fr', rec.name);
  end loop;
end $$;

do $$
declare
  rec record;
  v_id int;
begin
  if exists (select 1 from public.tools) then
    return;
  end if;

  for rec in
    select * from (values
      ('Outils d''alchimiste', 'outils_artisan'),
      ('Outils de brasseur', 'outils_artisan'),
      ('Outils de calligraphe', 'outils_artisan'),
      ('Outils de charpentier', 'outils_artisan'),
      ('Outils de cartographe', 'outils_artisan'),
      ('Outils de cordonnier', 'outils_artisan'),
      ('Ustensiles de cuisinier', 'outils_artisan'),
      ('Outils de souffleur de verre', 'outils_artisan'),
      ('Outils de joaillier', 'outils_artisan'),
      ('Outils de tanneur', 'outils_artisan'),
      ('Outils de maçon', 'outils_artisan'),
      ('Outils de peintre', 'outils_artisan'),
      ('Outils de potier', 'outils_artisan'),
      ('Outils de forgeron', 'outils_artisan'),
      ('Outils de bricoleur', 'outils_artisan'),
      ('Outils de tisserand', 'outils_artisan'),
      ('Outils de sculpteur sur bois', 'outils_artisan'),
      ('Jeu de dés', 'jeu'),
      ('Jeu d''échecs draconiques', 'jeu'),
      ('Jeu de cartes', 'jeu'),
      ('Cornemuse', 'instrument'),
      ('Tambour', 'instrument'),
      ('Tympanon', 'instrument'),
      ('Flûte', 'instrument'),
      ('Luth', 'instrument'),
      ('Lyre', 'instrument'),
      ('Cor', 'instrument'),
      ('Flûte de Pan', 'instrument'),
      ('Chalémie', 'instrument'),
      ('Vielle', 'instrument'),
      ('Kit de déguisement', 'autre'),
      ('Kit de faussaire', 'autre'),
      ('Kit d''herboriste', 'autre'),
      ('Outils de navigateur', 'autre'),
      ('Kit d''empoisonneur', 'autre'),
      ('Outils de voleur', 'autre')
    ) as t(name, category)
  loop
    insert into public.tools (category) values (rec.category) returning id into v_id;
    insert into public.translations (entity_type, entity_id, field_name, locale, value)
      values ('tool', v_id::text, 'name', 'fr', rec.name);
  end loop;
end $$;
