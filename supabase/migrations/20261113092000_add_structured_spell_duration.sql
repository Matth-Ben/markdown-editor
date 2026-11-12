-- Chantier "Personnages" (app mobile) — durée structurée des sorts.
--
-- public.spells.duration est un texte libre FR (affichage) ; l'app a besoin d'une durée exploitable
-- (décompte, expiration) sans parser du français. On ajoute trois colonnes structurées, la colonne
-- texte `duration` restant l'affichage et `concentration` n'étant pas touchée :
--   duration_kind  : 'instant' | 'timed' | 'until_dispelled' | 'special'
--   duration_value : entier > 0, renseigné seulement si duration_kind = 'timed'
--   duration_unit  : 'round' | 'minute' | 'hour' | 'day' | 'week' | 'year', renseigné seulement si 'timed'
-- Cohérence imposée par CHECK : timed => value > 0 et unit non nuls ; sinon les deux nuls.
--
-- Formats du texte `duration` reconnus par le backfill (préfixe optionnel « Concentration, jusqu'à »
-- ou « Jusqu'à ») : « Instantanée », « Spéciale », « Jusqu'à dissipation »,
-- « N round(s) / minute(s) / heure(s) / jour(s) / semaine(s) / an(s) ».
--
-- Corrections manuelles préalables sur le socle Phase 1 (20260825090900_seed_spells_core.sql) :
--   * Trique noueuse (Shillelagh) : « Instantanée » (faux)         -> « 1 minute »
--   * Création de flamme (Produce Flame) : « Instantanée ou 1 minute » (faux) -> « 10 minutes »
-- Les formats hors norme « Jusqu'à 1 heure » (Prestidigitation) et « Jusqu'à 1 minute »
-- (Thaumaturgie) gardent leur texte et sont structurés en timed 1 heure / 1 minute.
--
-- Assertion finale : aucun sort ne doit rester sans duration_kind (la migration échoue sinon).
-- RLS inchangée : les nouvelles colonnes héritent des policies et grants de lecture de public.spells.
-- Idempotente : colonnes `if not exists`, contraintes ajoutées seulement si absentes, backfill
-- recalculé à l'identique à chaque exécution.

alter table public.spells
  add column if not exists duration_kind text,
  add column if not exists duration_value int,
  add column if not exists duration_unit text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'spells_duration_kind_check') then
    alter table public.spells add constraint spells_duration_kind_check
      check (duration_kind in ('instant', 'timed', 'until_dispelled', 'special'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'spells_duration_unit_check') then
    alter table public.spells add constraint spells_duration_unit_check
      check (duration_unit in ('round', 'minute', 'hour', 'day', 'week', 'year'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'spells_duration_consistency_check') then
    alter table public.spells add constraint spells_duration_consistency_check
      check (
        (duration_kind = 'timed' and duration_value is not null and duration_value > 0 and duration_unit is not null)
        or (duration_kind is distinct from 'timed' and duration_value is null and duration_unit is null)
      );
  end if;
end $$;

comment on column public.spells.duration_kind is
  'Nature de la durée : instant | timed | until_dispelled | special. Structuré depuis le texte duration (affichage).';
comment on column public.spells.duration_value is
  'Valeur numérique de la durée (> 0), seulement si duration_kind = timed.';
comment on column public.spells.duration_unit is
  'Unité de la durée : round | minute | hour | day | week | year, seulement si duration_kind = timed.';

-- Corrections des deux durées fausses du socle Phase 1 (texte affiché), par nom FR + niveau.
do $$
declare
  rec record;
  v_n int;
begin
  for rec in
    select * from (values
      ('Trique noueuse', 0, '1 minute'),
      ('Création de flamme', 0, '10 minutes')
    ) as t(spell_name_fr, spell_level, new_duration)
  loop
    update public.spells sp
       set duration = rec.new_duration
      from public.translations t
     where t.entity_type = 'spell' and t.entity_id = sp.id::text
       and t.field_name = 'name' and t.locale = 'fr'
       and t.value = rec.spell_name_fr and sp.level = rec.spell_level;
    get diagnostics v_n = row_count;
    if v_n <> 1 then
      raise exception 'Durée structurée : % ligne(s) pour « % » (niveau %), 1 attendue',
        v_n, rec.spell_name_fr, rec.spell_level;
    end if;
  end loop;
end $$;

-- Backfill. Les valeurs sont d'abord remises à NULL pour que le CHECK de cohérence ne bloque pas
-- un rejeu et que le résultat dépende uniquement du texte courant.
update public.spells set duration_kind = null, duration_value = null, duration_unit = null;

-- Durées sans valeur numérique.
update public.spells set duration_kind = 'instant'
 where duration_kind is null and lower(btrim(duration)) in ('instantanée', 'instantanee');
update public.spells set duration_kind = 'special'
 where duration_kind is null and lower(btrim(duration)) in ('spéciale', 'speciale');
update public.spells set duration_kind = 'until_dispelled'
 where duration_kind is null
   and lower(btrim(duration)) in ('jusqu''à dissipation', 'jusqu’à dissipation');

-- Durées chiffrées : [Concentration, jusqu'à | Jusqu'à ] N unité(s).
update public.spells s
   set duration_kind = 'timed',
       duration_value = m.value::int,
       duration_unit = case m.unit
         when 'round' then 'round'
         when 'minute' then 'minute'
         when 'heure' then 'hour'
         when 'jour' then 'day'
         when 'semaine' then 'week'
         when 'an' then 'year'
       end
  from (
    select sp.id,
           (regexp_match(lower(btrim(sp.duration)),
             '^(?:concentration, jusqu[''’]à |jusqu[''’]à )?([0-9]+) (round|minute|heure|jour|semaine|an)s?$'))[1] as value,
           (regexp_match(lower(btrim(sp.duration)),
             '^(?:concentration, jusqu[''’]à |jusqu[''’]à )?([0-9]+) (round|minute|heure|jour|semaine|an)s?$'))[2] as unit
      from public.spells sp
     where sp.duration_kind is null
  ) m
 where s.id = m.id and m.value is not null and m.value::int > 0;

-- Assertion finale : tous les sorts sont structurés.
do $$
declare
  v_n int;
  v_list text;
begin
  select count(*), string_agg(distinct coalesce(duration, '<NULL>'), ' | ')
    into v_n, v_list
    from public.spells
   where duration_kind is null;
  if v_n <> 0 then
    raise exception 'Durée structurée : % sort(s) sans duration_kind (formats non reconnus : %)', v_n, v_list;
  end if;
end $$;
