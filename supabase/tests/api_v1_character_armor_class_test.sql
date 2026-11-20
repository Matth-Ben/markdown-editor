-- Tests de 20261120090000_private_character_armor_class.sql : parité de la CA calculée par DeepCore avec le calcul de Nexus
-- (lib/features/characters/domain/armor_class_calculator.dart), cas C1 à C27 de la spécification de `regles-dnd` du 20/11/2026,
-- en sous-cas, plus la décision n° 37 (deux armures ou deux boucliers équipés : meilleure CA) et les données non lues.
--
-- Les objets, classes, sous-classes et aptitudes sont ceux du catalogue rejoué par les migrations, retrouvés par leur NOM
-- FRANÇAIS (comme Nexus) : si un nom change dans le catalogue, ces tests échouent au lieu de valider un calcul qui ne verrait
-- plus « Barbare », « Moine », « Lignage draconique », « Style de combat » ou « Bouclier ».
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- BEGIN/ROLLBACK : rejouable, aucune donnée ne persiste.

begin;

select plan(70);

-- Fixtures ----------------------------------------------------------------------------------------------------------------------
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values ('ac000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'pgtap-ca-01@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

create temp table chars (k text primary key, id uuid not null);

-- Identifiant d'un objet du catalogue par son nom français ; échoue si le nom n'existe pas ou n'est pas unique.
create function pg_temp.item(p_name text) returns integer
language plpgsql stable as $$
declare
  v_n integer;
  v_id integer;
begin
  select count(*), min(t.entity_id::integer) into v_n, v_id
    from public.translations t
   where t.entity_type = 'item' and t.field_name = 'name' and t.locale = 'fr' and t.value = p_name;
  if v_n <> 1 then
    raise exception 'objet « % » : % ligne(s) dans le catalogue', p_name, v_n;
  end if;
  return v_id;
end;
$$;

-- Identifiant d'une entité de référence (classe, sous-classe, aptitude) par son nom français ; le plus petit si plusieurs.
create function pg_temp.ref(p_type text, p_name text) returns integer
language plpgsql stable as $$
declare
  v_id integer;
begin
  select min(t.entity_id::integer) into v_id
    from public.translations t
   where t.entity_type = p_type and t.field_name = 'name' and t.locale = 'fr' and t.value = p_name;
  if v_id is null then
    raise exception '% « % » absent du catalogue', p_type, p_name;
  end if;
  return v_id;
end;
$$;

-- Personnage : scores ({"dex": 14, ...}), classes par nom, sous-classe draconique (portée par un Ensorceleur), style Défense
-- (sous l'aptitude p_style_feature), ajustement manuel.
create function pg_temp.new_char(
  p_key text,
  p_scores jsonb default '{}',
  p_classes text[] default '{}',
  p_subclass text default null,
  p_defense boolean default false,
  p_bonus integer default 0,
  p_style_feature text default 'Style de combat'
) returns uuid
language plpgsql as $$
declare
  v_id uuid := gen_random_uuid();
  v_class text;
  v_level integer := 1;
begin
  insert into public.characters (id, owner_id, name, armor_class_bonus)
  values (v_id, 'ac000000-0000-4000-8000-000000000001', 'CA ' || p_key, p_bonus);
  insert into public.character_ability_scores (character_id, ability_id, score)
  select v_id, s.key, s.value::integer from jsonb_each_text(p_scores) s;
  foreach v_class in array p_classes loop
    insert into public.character_classes (character_id, class_id, level, is_primary)
    values (v_id, pg_temp.ref('class', v_class), v_level, v_level = 1);
    v_level := v_level + 4; -- niveaux variés : jamais lus par le calcul
  end loop;
  if p_subclass is not null then
    insert into public.character_classes (character_id, class_id, subclass_id, level, is_primary)
    values (v_id, pg_temp.ref('class', 'Ensorceleur'), pg_temp.ref('subclass', p_subclass), 3, cardinality(p_classes) = 0);
  end if;
  if p_defense then
    insert into public.character_class_options (character_id, class_feature_id, level, chosen_value)
    values (v_id, pg_temp.ref('class_feature', p_style_feature), 1, 'Défense');
  end if;
  insert into chars (k, id) values (p_key, v_id);
  return v_id;
end;
$$;

create function pg_temp.c(p_key text) returns uuid
language sql stable as $$ select id from chars where k = p_key $$;

-- Objet du catalogue dans l'inventaire.
create function pg_temp.give(
  p_key text, p_item text, p_equipped boolean default true, p_attuned boolean default false, p_quantity integer default 1
) returns uuid
language sql as $$
  insert into public.character_inventory (character_id, item_id, quantity, equipped, is_attuned)
  values (pg_temp.c(p_key), pg_temp.item(p_item), p_quantity, p_equipped, p_attuned)
  returning id;
$$;

-- Objet personnalisé (P7).
create function pg_temp.give_custom(
  p_key text, p_kind text, p_ac_base integer, p_category text default null, p_magic integer default null,
  p_requires_attunement boolean default false, p_attuned boolean default false, p_equipped boolean default true
) returns uuid
language sql as $$
  insert into public.character_inventory (
    character_id, custom_name, equipped, is_attuned, custom_kind, custom_ac_base, custom_armor_category, custom_magic_bonus,
    custom_requires_attunement
  )
  values (pg_temp.c(p_key), 'Objet perso ' || coalesce(p_kind, 'sans type'), p_equipped, p_attuned, p_kind, p_ac_base,
          p_category, p_magic, p_requires_attunement)
  returning id;
$$;

-- Harmonise tous les objets du personnage (cas « harmonisé »).
create function pg_temp.attune_all(p_key text) returns void
language sql as $$ update public.character_inventory set is_attuned = true where character_id = pg_temp.c(p_key) $$;

create function pg_temp.ac(p_key text) returns integer
language sql stable as $$ select armor_class from private.character_armor_class(pg_temp.c(p_key)) $$;

-- Droits ------------------------------------------------------------------------------------------------------------------------
select ok(
  not has_function_privilege('anon', 'private.character_armor_class(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.character_armor_class(uuid)', 'execute'),
  'character_armor_class : ni anon ni authenticated n''ont EXECUTE'
);
select is(
  (select count(*)::int from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
    where p.oid = 'private.character_armor_class(uuid)'::regprocedure and x.grantee = 0),
  0,
  'character_armor_class : PUBLIC sans EXECUTE'
);
select ok(
  not has_schema_privilege('anon', 'private', 'usage') and not has_schema_privilege('authenticated', 'private', 'usage'),
  'Schéma private : aucun USAGE pour anon ni authenticated'
);
select is(
  (select (not p.prosecdef) and p.provolatile = 's' and p.proconfig = array['search_path=public, pg_temp']
     from pg_proc p where p.oid = 'private.character_armor_class(uuid)'::regprocedure),
  true,
  'character_armor_class : security invoker, stable, search_path = public, pg_temp'
);

-- C1 à C3 : sans armure -----------------------------------------------------------------------------------------------------------
select pg_temp.new_char('C1');
select is(pg_temp.ac('C1'), 10, 'C1 : aucun score, rien d''équipé -> 10');

select pg_temp.new_char('C2', '{"dex": 14}');
select is(pg_temp.ac('C2'), 12, 'C2 : Dex 14 -> 12');
select pg_temp.give('C2', 'Bouclier');
select is(pg_temp.ac('C2'), 14, 'C2 : Dex 14 + bouclier (+2) -> 14');

select pg_temp.new_char('C3', '{"dex": 9}');
select is(pg_temp.ac('C3'), 9, 'C3 : Dex 9 -> 9 (modificateur -1 : plancher, pas troncature)');

-- C4 à C9 : armures du catalogue ------------------------------------------------------------------------------------------------
select pg_temp.new_char('C4', '{"dex": 20}');
select pg_temp.give('C4', 'Armure de cuir clouté');
select is(pg_temp.ac('C4'), 17, 'C4 : Dex 20, légère 12 illimitée -> 17');

select pg_temp.new_char('C5', '{"dex": 6}');
select pg_temp.give('C5', 'Armure de cuir');
select is(pg_temp.ac('C5'), 9, 'C5 : Dex 6, légère 11 -> 9');

select pg_temp.new_char('C6', '{"dex": 18}');
select pg_temp.give('C6', 'Cuirasse');
select is(pg_temp.ac('C6'), 16, 'C6 : Dex 18, intermédiaire 14 max 2 -> 16');

select pg_temp.new_char('C7', '{"dex": 7}');
select pg_temp.give('C7', 'Cuirasse');
select is(pg_temp.ac('C7'), 12, 'C7 : Dex 7, intermédiaire 14 -> 12 (Dex négative non plafonnée)');

select pg_temp.new_char('C8', '{"dex": 20}');
select pg_temp.give('C8', 'Armure complète');
select pg_temp.give('C8', 'Bouclier');
select is(pg_temp.ac('C8'), 20, 'C8 : Dex 20, lourde 18 + bouclier -> 20');

select pg_temp.new_char('C9', '{"dex": 6}');
select pg_temp.give('C9', 'Cotte de mailles');
select is(pg_temp.ac('C9'), 16, 'C9 : Dex 6, lourde 16 -> 16 (Dex ignorée)');

-- C10, C11 : style Défense --------------------------------------------------------------------------------------------------------
select pg_temp.new_char('C10', '{"dex": 14}', p_defense => true);
select pg_temp.give('C10', 'Cuirasse');
select pg_temp.give('C10', 'Bouclier');
select is(pg_temp.ac('C10'), 19, 'C10 : Dex 14, intermédiaire 14 + bouclier + Défense -> 19');

select pg_temp.new_char('C11', '{"dex": 14}', p_defense => true);
select is(pg_temp.ac('C11'), 12, 'C11 : Dex 14 sans armure, Défense -> 12 (Défense exige une armure)');

-- C12 à C16 : Défense sans armure et Résilience draconique -----------------------------------------------------------------------
select pg_temp.new_char('C12', '{"dex": 14, "con": 16}', array['Barbare']);
select is(pg_temp.ac('C12'), 15, 'C12 : Barbare Dex 14 Con 16 -> 15');
select pg_temp.give('C12', 'Bouclier');
select is(pg_temp.ac('C12'), 17, 'C12 : Barbare + bouclier -> 17');

select pg_temp.new_char('C13', '{"dex": 14, "con": 16}', array['Barbare']);
select pg_temp.give('C13', 'Cuirasse');
select is(pg_temp.ac('C13'), 16, 'C13 : Barbare Dex 14 Con 16, intermédiaire 14 -> 16');

select pg_temp.new_char('C14', '{"dex": 16, "wis": 16}', array['Moine']);
select is(pg_temp.ac('C14'), 16, 'C14 : Moine Dex 16 Sag 16 -> 16');
select pg_temp.give('C14', 'Bouclier');
select is(pg_temp.ac('C14'), 15, 'C14 : Moine + bouclier -> 15 (Défense du Moine perdue)');

select pg_temp.new_char('C15', '{"dex": 14, "con": 12, "wis": 18}', array['Barbare', 'Moine']);
select is(pg_temp.ac('C15'), 16, 'C15 : Barbare + Moine Dex 14 Con 12 Sag 18 -> 16 (maximum, écart E1 de D234)');
select pg_temp.give('C15', 'Bouclier');
select is(pg_temp.ac('C15'), 15, 'C15 : Barbare + Moine + bouclier -> 15');

select pg_temp.new_char('C16', '{"dex": 14}', p_subclass => 'Lignage draconique');
select is(pg_temp.ac('C16'), 15, 'C16 : Lignage draconique Dex 14 -> 15');
select pg_temp.give('C16', 'Bouclier');
select is(pg_temp.ac('C16'), 17, 'C16 : Lignage draconique + bouclier -> 17');

-- C17 à C22 : objets magiques du catalogue ---------------------------------------------------------------------------------------
select pg_temp.new_char('C17', '{"dex": 14}');
select pg_temp.give('C17', 'Anneau de protection');
select is(pg_temp.ac('C17'), 12, 'C17 : Anneau de protection non harmonisé -> 12');
select pg_temp.attune_all('C17');
select is(pg_temp.ac('C17'), 13, 'C17 : Anneau de protection harmonisé -> 13');

select pg_temp.new_char('C18', '{"dex": 16}');
select pg_temp.give('C18', 'Armure d''écailles de dragon');
select is(pg_temp.ac('C18'), 16, 'C18 : Écailles de dragon non harmonisées -> 16 (la base compte toujours)');
select pg_temp.attune_all('C18');
select is(pg_temp.ac('C18'), 17, 'C18 : Écailles de dragon harmonisées -> 17');

select pg_temp.new_char('C19', '{"dex": 14}');
select pg_temp.give('C19', 'Cotte de mailles');
select pg_temp.give('C19', 'Armure +1');
select is(pg_temp.ac('C19'), 17, 'C19 : cotte de mailles 16 + Armure +1 -> 17');
select pg_temp.new_char('C19b', '{"dex": 14}');
select pg_temp.give('C19b', 'Armure +1');
select is(pg_temp.ac('C19b'), 12, 'C19 : Armure +1 seule -> 12 (écart E7 de D234)');

select pg_temp.new_char('C20', '{"dex": 14}');
select pg_temp.give('C20', 'Bracelets de défense', p_attuned => true);
select is(pg_temp.ac('C20'), 14, 'C20 : Bracelets de défense harmonisés -> 14');
select pg_temp.give('C20', 'Bouclier');
select is(pg_temp.ac('C20'), 14, 'C20 : Bracelets + bouclier -> 14 (bonus des bracelets perdu)');
select pg_temp.new_char('C20m', '{"dex": 16, "wis": 16}', array['Moine']);
select pg_temp.give('C20m', 'Bracelets de défense', p_attuned => true);
select is(pg_temp.ac('C20m'), 18, 'C20 : Moine Dex 16 Sag 16 + Bracelets -> 18');

select pg_temp.new_char('C21', '{"dex": 14}');
select pg_temp.give('C21', 'Robe de l''archimage', p_attuned => true);
select is(pg_temp.ac('C21'), 17, 'C21 : Robe de l''archimage harmonisée -> 17');
select pg_temp.give('C21', 'Bouclier');
select is(pg_temp.ac('C21'), 19, 'C21 : Robe + bouclier -> 19');
select pg_temp.new_char('C21n', '{"dex": 14}');
select pg_temp.give('C21n', 'Robe de l''archimage');
select is(pg_temp.ac('C21n'), 12, 'C21 : Robe non harmonisée -> 12');
select pg_temp.new_char('C21m', '{"dex": 14, "wis": 18}', array['Moine']);
select pg_temp.give('C21m', 'Robe de l''archimage', p_attuned => true);
select is(pg_temp.ac('C21m'), 17, 'C21 : Moine Dex 14 Sag 18 + Robe -> 17');

select pg_temp.new_char('C22', '{"dex": 14}');
select pg_temp.give('C22', 'Bouclier +2');
select is(pg_temp.ac('C22'), 16, 'C22 : Bouclier +2 (emplacement bouclier, base 4) -> 16');

-- C23, C24 : objets personnalisés ------------------------------------------------------------------------------------------------
select pg_temp.new_char('C23', '{"dex": 16}');
select pg_temp.give_custom('C23', 'armure', 15, 'intermediaire', 1, p_requires_attunement => true);
select is(pg_temp.ac('C23'), 17, 'C23 : armure perso 15 intermédiaire +1 à harmoniser, non harmonisée -> 17');
select pg_temp.attune_all('C23');
select is(pg_temp.ac('C23'), 18, 'C23 : harmonisée -> 18');

select pg_temp.new_char('C24', '{"dex": 14}');
select pg_temp.give_custom('C24', 'bouclier', 2, null, 2);
select is(pg_temp.ac('C24'), 16, 'C24 : bouclier perso 2 +2 sans harmonisation -> 16');
select pg_temp.new_char('C24a', '{"dex": 14}');
select pg_temp.give_custom('C24a', 'autre', 15);
select is(pg_temp.ac('C24a'), 12, 'C24 : objet perso « autre » avec custom_ac_base 15 -> 12 (ignoré)');
select pg_temp.new_char('C24n', '{"dex": 14}');
select pg_temp.give_custom('C24n', null, 15);
select is(pg_temp.ac('C24n'), 12, 'C24 : objet perso sans type avec custom_ac_base 15 -> 12 (ignoré)');
select pg_temp.new_char('C24b', '{"dex": 14, "con": 16}', array['Barbare']);
select pg_temp.give_custom('C24b', 'autre', 15);
select is(pg_temp.ac('C24b'), 15, 'C24 : Barbare Con 16 + objet perso « autre » -> 15 (reste sans armure)');

-- C25 : ajustement manuel, séparé ----------------------------------------------------------------------------------------------
select pg_temp.new_char('C25', '{"dex": 14}', p_bonus => 2);
select is(
  (select row(armor_class, armor_class_bonus, armor_class_total)::text from private.character_armor_class(pg_temp.c('C25'))),
  '(12,2,14)',
  'C25 : ajustement +2 -> CA 12, ajustement 2, total 14'
);
select pg_temp.new_char('C25m', '{"dex": 14}', p_bonus => -3);
select is(
  (select row(armor_class, armor_class_bonus, armor_class_total)::text from private.character_armor_class(pg_temp.c('C25m'))),
  '(12,-3,9)',
  'C25 : ajustement -3 -> CA 12, ajustement -3, total 9'
);

-- C26 : non équipé, aucun score -------------------------------------------------------------------------------------------------
select pg_temp.new_char('C26', '{"dex": 14}');
select pg_temp.give('C26', 'Armure complète', p_equipped => false);
select pg_temp.give('C26', 'Bouclier', p_equipped => false);
select pg_temp.give('C26', 'Anneau de protection', p_equipped => false, p_attuned => true);
select is(pg_temp.ac('C26'), 12, 'C26 : armure, bouclier et anneau harmonisé non équipés -> 12');
select pg_temp.new_char('C26z');
select pg_temp.give('C26z', 'Cuirasse');
select is(pg_temp.ac('C26z'), 14, 'C26 : intermédiaire 14 sans aucun score -> 14');

-- C27 : décision n° 37, plusieurs armures ou boucliers équipés -> meilleure CA ------------------------------------------------
select pg_temp.new_char('C27', '{"dex": 14}');
select pg_temp.give('C27', 'Armure complète');
select pg_temp.give('C27', 'Armure de cuir');
select is(pg_temp.ac('C27'), 18, 'C27 : lourde 18 et légère 11 équipées -> 18 (meilleure CA)');
select pg_temp.new_char('C27r', '{"dex": 14}');
select pg_temp.give('C27r', 'Armure de cuir');
select pg_temp.give('C27r', 'Armure complète');
select is(pg_temp.ac('C27r'), 18, 'C27 : même résultat dans l''ordre d''inventaire inverse (déterministe)');
select pg_temp.new_char('C27s', '{"dex": 14}');
select pg_temp.give('C27s', 'Bouclier');
select pg_temp.give('C27s', 'Bouclier +2');
select is(pg_temp.ac('C27s'), 16, 'C27 : deux boucliers (2 et 4) -> 16 (le meilleur)');
select pg_temp.give('C27s', 'Cuirasse');
select is(pg_temp.ac('C27s'), 20, 'C27 : intermédiaire 14 + deux boucliers -> 20');
select pg_temp.new_char('C27m', '{"dex": 16, "wis": 16}', array['Moine']);
select pg_temp.give('C27m', 'Bouclier');
select pg_temp.give('C27m', 'Bouclier +2');
select is(pg_temp.ac('C27m'), 17, 'C27 : Moine avec deux boucliers -> 17 (toujours avec bouclier)');
select pg_temp.new_char('C27d', '{"dex": 16}');
select pg_temp.give('C27d', 'Armure d''écailles de dragon', p_attuned => true);
select pg_temp.give('C27d', 'Armure complète');
select is(pg_temp.ac('C27d'), 19,
  'C27 : écailles de dragon harmonisées + armure complète -> 19 (18 retenue, +1 « toujours » des écailles compte encore)');
select pg_temp.new_char('C27c', '{"dex": 16}');
select pg_temp.give('C27c', 'Cotte de mailles');
select pg_temp.give_custom('C27c', 'armure', 12, 'legere', 3);
select is(pg_temp.ac('C27c'), 18, 'C27 : cotte 16 contre armure perso légère 12 +3 -> 18 (bonus magique de la combinaison)');
select pg_temp.new_char('C27h', '{"dex": 16}');
select pg_temp.give_custom('C27h', 'armure', 12, 'legere', 3, p_requires_attunement => true);
select pg_temp.give('C27h', 'Cotte de mailles');
select is(pg_temp.ac('C27h'), 16, 'C27 : même armure perso non harmonisée -> 16 (la cotte gagne)');
select pg_temp.new_char('C27a', '{"dex": 14}');
select pg_temp.give('C27a', 'Armure complète');
select pg_temp.give('C27a', 'Armure de cuir');
select pg_temp.give('C27a', 'Armure +1');
select is(pg_temp.ac('C27a'), 19, 'C27 : deux armures + Armure +1 -> 19 (bonus « avec armure » compté une fois)');

-- Données non lues et cas limites (parité avec le Dart) --------------------------------------------------------------------------
select pg_temp.new_char('Q0', '{"dex": 14}');
select pg_temp.give('Q0', 'Cuirasse', p_quantity => 0);
select is(pg_temp.ac('Q0'), 16, 'Quantité non lue : armure équipée en quantité 0 -> compte quand même');

select pg_temp.new_char('SUP', '{"dex": 14}', p_defense => true, p_style_feature => 'Style de combat supplémentaire');
select pg_temp.give('SUP', 'Cuirasse');
select is(pg_temp.ac('SUP'), 16, 'Défense choisie sous « Style de combat supplémentaire » : ignorée (comme Nexus)');

select pg_temp.new_char('OTH', '{"dex": 14}');
insert into public.character_class_options (character_id, class_feature_id, level, chosen_value)
values (pg_temp.c('OTH'), pg_temp.ref('class_feature', 'Style de combat'), 1, 'défense');
select pg_temp.give('OTH', 'Cuirasse');
select is(pg_temp.ac('OTH'), 16, 'Défense : comparaison exacte, casse comprise (« défense » ignoré)');

select pg_temp.new_char('STR', '{"dex": 14, "str": 3, "con": 20, "wis": 20}');
select pg_temp.give('STR', 'Armure complète');
select is(pg_temp.ac('STR'), 18, 'Force non lue (armure lourde avec Force 3) ; Con et Sag sans effet hors Barbare/Moine');

select pg_temp.new_char('LVL', '{"dex": 14, "con": 16}', array['Guerrier', 'Barbare']);
select is(pg_temp.ac('LVL'), 15, 'Barbare en seconde classe (multiclassage) : Défense sans armure appliquée, niveau non lu');

update public.characters set conditions = '["unconscious", "prone"]', is_dead = true, current_hp = 0
 where id = pg_temp.c('LVL');
select is(pg_temp.ac('LVL'), 15, 'États, mort et PV non lus');

select pg_temp.new_char('CUS', '{"dex": 14}');
select pg_temp.give_custom('CUS', 'armure', 13, 'lourde', 2, p_equipped => false);
select is(pg_temp.ac('CUS'), 12, 'Armure perso non équipée -> 12');
update public.character_inventory set equipped = true where character_id = pg_temp.c('CUS');
select is(pg_temp.ac('CUS'), 15, 'Armure perso lourde 13 +2 équipée -> 15 (Dex ignorée)');

select pg_temp.new_char('ROB2', '{"dex": 14}');
select pg_temp.give('ROB2', 'Robe de l''archimage', p_attuned => true);
select pg_temp.give('ROB2', 'Armure de cuir');
select is(pg_temp.ac('ROB2'), 13, 'Robe harmonisée + armure de cuir -> 13 (la base de la robe ne vaut que sans armure)');

select pg_temp.new_char('ARM1', '{"dex": 14}');
select pg_temp.give('ARM1', 'Cotte de mailles');
select pg_temp.give('ARM1', 'Bracelets de défense', p_attuned => true);
select pg_temp.give('ARM1', 'Anneau de protection', p_attuned => true);
select is(pg_temp.ac('ARM1'), 17, 'Cotte 16 + bracelets (ignorés avec armure) + anneau (+1) -> 17');

select is(
  (select count(*)::int from private.character_armor_class('ac000000-0000-4000-8000-0000000000ff')),
  0,
  'Personnage inconnu : aucune ligne'
);
select is(
  (select count(*)::int from private.character_armor_class(null)),
  0,
  'Identifiant NULL : aucune ligne'
);

select * from finish();
rollback;
