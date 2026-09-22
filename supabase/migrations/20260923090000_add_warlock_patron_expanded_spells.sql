-- Chantier "Personnages" (app mobile) — Listes de sorts étendues des patrons d'Occultiste.
--
-- Étend public.subclass_spells (migration 20260922090000) avec une colonne grant_kind :
--   - 'always_prepared' (défaut) : sorts accordés d'office (domaines de Clerc, serments de Paladin) ;
--   - 'extends_list'             : sorts ajoutés à la liste des sorts que le joueur peut CHOISIR
--                                  d'apprendre (patrons d'Occultiste) — jamais préparés d'office.
-- Pour 'extends_list', class_level est le niveau d'Occultiste à partir duquel un sort de ce
-- niveau est accessible (sort niv. 1/2/3/4/5 = niveau de classe 1/3/5/7/9, comme les lignes
-- class_features « Liste de sorts étendue »).
--
-- Périmètre : 7 patrons (Fiélon, Grand Ancien, Archifée, Céleste, Lame maudite, Mort-vivant,
-- Insondable) + les 4 génies (sorts communs + sorts du génie). L'Immortel n'existe pas dans le
-- catalogue de sous-classes. Listes vérifiées une à une, avec contrôle automatique du niveau
-- de chaque sort. Corrige au passage les descriptions fausses des aptitudes « Liste de sorts
-- étendue » (Grand Ancien et Archifée notamment).

alter table public.subclass_spells
  add column if not exists grant_kind text not null default 'always_prepared';

alter table public.subclass_spells
  drop constraint if exists subclass_spells_grant_kind_check;
alter table public.subclass_spells
  add constraint subclass_spells_grant_kind_check
  check (grant_kind in ('always_prepared', 'extends_list'));

do $$
declare
  rec record;
  v_subclass integer;
  v_spell integer;
  v_done integer := 0;
begin
  for rec in
    select * from (values
      ($sp$Protecteur Fiélon$sp$, 1, $sp$Mains brûlantes$sp$, 1),
      ($sp$Protecteur Fiélon$sp$, 1, $sp$Injonction$sp$, 1),
      ($sp$Protecteur Fiélon$sp$, 3, $sp$Cécité/Surdité$sp$, 2),
      ($sp$Protecteur Fiélon$sp$, 3, $sp$Rayon ardent$sp$, 2),
      ($sp$Protecteur Fiélon$sp$, 5, $sp$Boule de feu$sp$, 3),
      ($sp$Protecteur Fiélon$sp$, 5, $sp$Nuage nauséabond$sp$, 3),
      ($sp$Protecteur Fiélon$sp$, 7, $sp$Bouclier de feu$sp$, 4),
      ($sp$Protecteur Fiélon$sp$, 7, $sp$Mur de feu$sp$, 4),
      ($sp$Protecteur Fiélon$sp$, 9, $sp$Colonne de flamme$sp$, 5),
      ($sp$Protecteur Fiélon$sp$, 9, $sp$Sanctification$sp$, 5),
      ($sp$Grand Ancien$sp$, 1, $sp$Murmures dissonants$sp$, 1),
      ($sp$Grand Ancien$sp$, 1, $sp$Rire hideux de Tasha$sp$, 1),
      ($sp$Grand Ancien$sp$, 3, $sp$Détection des pensées$sp$, 2),
      ($sp$Grand Ancien$sp$, 3, $sp$Force fantasmagorique$sp$, 2),
      ($sp$Grand Ancien$sp$, 5, $sp$Clairvoyance$sp$, 3),
      ($sp$Grand Ancien$sp$, 5, $sp$Communication à distance$sp$, 3),
      ($sp$Grand Ancien$sp$, 7, $sp$Domination de bête$sp$, 4),
      ($sp$Grand Ancien$sp$, 7, $sp$Tentacules noirs d'Evard$sp$, 4),
      ($sp$Grand Ancien$sp$, 9, $sp$Domination de personne$sp$, 5),
      ($sp$Grand Ancien$sp$, 9, $sp$Télékinésie$sp$, 5),
      ($sp$Archifée$sp$, 1, $sp$Feu follet$sp$, 1),
      ($sp$Archifée$sp$, 1, $sp$Sommeil$sp$, 1),
      ($sp$Archifée$sp$, 3, $sp$Apaisement des émotions$sp$, 2),
      ($sp$Archifée$sp$, 3, $sp$Force fantasmagorique$sp$, 2),
      ($sp$Archifée$sp$, 5, $sp$Clignotement$sp$, 3),
      ($sp$Archifée$sp$, 5, $sp$Croissance végétale$sp$, 3),
      ($sp$Archifée$sp$, 7, $sp$Domination de bête$sp$, 4),
      ($sp$Archifée$sp$, 7, $sp$Invisibilité supérieure$sp$, 4),
      ($sp$Archifée$sp$, 9, $sp$Domination de personne$sp$, 5),
      ($sp$Archifée$sp$, 9, $sp$Apparence trompeuse$sp$, 5),
      ($sp$Céleste$sp$, 1, $sp$Soins$sp$, 1),
      ($sp$Céleste$sp$, 1, $sp$Éclair traçant$sp$, 1),
      ($sp$Céleste$sp$, 3, $sp$Sphère de feu$sp$, 2),
      ($sp$Céleste$sp$, 3, $sp$Restauration partielle$sp$, 2),
      ($sp$Céleste$sp$, 5, $sp$Lumière du jour$sp$, 3),
      ($sp$Céleste$sp$, 5, $sp$Retour à la vie$sp$, 3),
      ($sp$Céleste$sp$, 7, $sp$Gardien de la foi$sp$, 4),
      ($sp$Céleste$sp$, 7, $sp$Mur de feu$sp$, 4),
      ($sp$Céleste$sp$, 9, $sp$Colonne de flamme$sp$, 5),
      ($sp$Céleste$sp$, 9, $sp$Restauration supérieure$sp$, 5),
      ($sp$Lame maudite$sp$, 1, $sp$Bouclier$sp$, 1),
      ($sp$Lame maudite$sp$, 1, $sp$Châtiment courroucé$sp$, 1),
      ($sp$Lame maudite$sp$, 3, $sp$Flou$sp$, 2),
      ($sp$Lame maudite$sp$, 3, $sp$Châtiment révélateur$sp$, 2),
      ($sp$Lame maudite$sp$, 5, $sp$Clignotement$sp$, 3),
      ($sp$Lame maudite$sp$, 5, $sp$Arme élémentaire$sp$, 3),
      ($sp$Lame maudite$sp$, 7, $sp$Assassin imaginaire$sp$, 4),
      ($sp$Lame maudite$sp$, 7, $sp$Châtiment débilitant$sp$, 4),
      ($sp$Lame maudite$sp$, 9, $sp$Châtiment du ban$sp$, 5),
      ($sp$Lame maudite$sp$, 9, $sp$Cône de froid$sp$, 5),
      ($sp$Mort-vivant$sp$, 1, $sp$Flétrissure$sp$, 1),
      ($sp$Mort-vivant$sp$, 1, $sp$Simulacre de vie$sp$, 1),
      ($sp$Mort-vivant$sp$, 3, $sp$Cécité/Surdité$sp$, 2),
      ($sp$Mort-vivant$sp$, 3, $sp$Force fantasmagorique$sp$, 2),
      ($sp$Mort-vivant$sp$, 5, $sp$Monture fantôme$sp$, 3),
      ($sp$Mort-vivant$sp$, 5, $sp$Communication avec les morts$sp$, 3),
      ($sp$Mort-vivant$sp$, 7, $sp$Protection contre la mort$sp$, 4),
      ($sp$Mort-vivant$sp$, 7, $sp$Invisibilité supérieure$sp$, 4),
      ($sp$Mort-vivant$sp$, 9, $sp$Coquille antivie$sp$, 5),
      ($sp$Mort-vivant$sp$, 9, $sp$Brume mortelle$sp$, 5),
      ($sp$Insondable$sp$, 1, $sp$Création ou destruction d'eau$sp$, 1),
      ($sp$Insondable$sp$, 1, $sp$Vague tonnerre$sp$, 1),
      ($sp$Insondable$sp$, 3, $sp$Bourrasque$sp$, 2),
      ($sp$Insondable$sp$, 3, $sp$Silence$sp$, 2),
      ($sp$Insondable$sp$, 5, $sp$Éclair$sp$, 3),
      ($sp$Insondable$sp$, 5, $sp$Tempête de neige$sp$, 3),
      ($sp$Insondable$sp$, 7, $sp$Contrôle de l'eau$sp$, 4),
      ($sp$Insondable$sp$, 7, $sp$Convocation d'élémentaire$sp$, 4),
      ($sp$Insondable$sp$, 9, $sp$Main de Bigby$sp$, 5),
      ($sp$Insondable$sp$, 9, $sp$Cône de froid$sp$, 5),
      ($sp$Génie - Dao$sp$, 1, $sp$Détection du mal et du bien$sp$, 1),
      ($sp$Génie - Dao$sp$, 3, $sp$Force fantasmagorique$sp$, 2),
      ($sp$Génie - Dao$sp$, 5, $sp$Création de nourriture et d'eau$sp$, 3),
      ($sp$Génie - Dao$sp$, 7, $sp$Assassin imaginaire$sp$, 4),
      ($sp$Génie - Dao$sp$, 9, $sp$Création$sp$, 5),
      ($sp$Génie - Dao$sp$, 1, $sp$Sanctuaire$sp$, 1),
      ($sp$Génie - Dao$sp$, 3, $sp$Croissance d'épines$sp$, 2),
      ($sp$Génie - Dao$sp$, 5, $sp$Fusion dans la pierre$sp$, 3),
      ($sp$Génie - Dao$sp$, 7, $sp$Façonnage de la pierre$sp$, 4),
      ($sp$Génie - Dao$sp$, 9, $sp$Mur de pierre$sp$, 5),
      ($sp$Génie - Djinn$sp$, 1, $sp$Détection du mal et du bien$sp$, 1),
      ($sp$Génie - Djinn$sp$, 3, $sp$Force fantasmagorique$sp$, 2),
      ($sp$Génie - Djinn$sp$, 5, $sp$Création de nourriture et d'eau$sp$, 3),
      ($sp$Génie - Djinn$sp$, 7, $sp$Assassin imaginaire$sp$, 4),
      ($sp$Génie - Djinn$sp$, 9, $sp$Création$sp$, 5),
      ($sp$Génie - Djinn$sp$, 1, $sp$Vague tonnerre$sp$, 1),
      ($sp$Génie - Djinn$sp$, 3, $sp$Bourrasque$sp$, 2),
      ($sp$Génie - Djinn$sp$, 5, $sp$Mur de vent$sp$, 3),
      ($sp$Génie - Djinn$sp$, 7, $sp$Invisibilité supérieure$sp$, 4),
      ($sp$Génie - Djinn$sp$, 9, $sp$Apparence trompeuse$sp$, 5),
      ($sp$Génie - Éfrit$sp$, 1, $sp$Détection du mal et du bien$sp$, 1),
      ($sp$Génie - Éfrit$sp$, 3, $sp$Force fantasmagorique$sp$, 2),
      ($sp$Génie - Éfrit$sp$, 5, $sp$Création de nourriture et d'eau$sp$, 3),
      ($sp$Génie - Éfrit$sp$, 7, $sp$Assassin imaginaire$sp$, 4),
      ($sp$Génie - Éfrit$sp$, 9, $sp$Création$sp$, 5),
      ($sp$Génie - Éfrit$sp$, 1, $sp$Mains brûlantes$sp$, 1),
      ($sp$Génie - Éfrit$sp$, 3, $sp$Rayon ardent$sp$, 2),
      ($sp$Génie - Éfrit$sp$, 5, $sp$Boule de feu$sp$, 3),
      ($sp$Génie - Éfrit$sp$, 7, $sp$Bouclier de feu$sp$, 4),
      ($sp$Génie - Éfrit$sp$, 9, $sp$Colonne de flamme$sp$, 5),
      ($sp$Génie - Maride$sp$, 1, $sp$Détection du mal et du bien$sp$, 1),
      ($sp$Génie - Maride$sp$, 3, $sp$Force fantasmagorique$sp$, 2),
      ($sp$Génie - Maride$sp$, 5, $sp$Création de nourriture et d'eau$sp$, 3),
      ($sp$Génie - Maride$sp$, 7, $sp$Assassin imaginaire$sp$, 4),
      ($sp$Génie - Maride$sp$, 9, $sp$Création$sp$, 5),
      ($sp$Génie - Maride$sp$, 1, $sp$Nappe de brouillard$sp$, 1),
      ($sp$Génie - Maride$sp$, 3, $sp$Flou$sp$, 2),
      ($sp$Génie - Maride$sp$, 5, $sp$Tempête de neige$sp$, 3),
      ($sp$Génie - Maride$sp$, 7, $sp$Contrôle de l'eau$sp$, 4),
      ($sp$Génie - Maride$sp$, 9, $sp$Cône de froid$sp$, 5)
    ) as t(subclass_name, class_level, spell_name, spell_level)
  loop
    select sc.id into strict v_subclass
      from public.subclasses sc
      join public.translations tr
        on tr.entity_type = 'subclass' and tr.entity_id = sc.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where tr.value = rec.subclass_name and sc.class_id = 10;

    select sp.id into strict v_spell
      from public.spells sp
      join public.translations tr
        on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where tr.value = rec.spell_name and sp.level = rec.spell_level and not sp.is_incomplete;

    insert into public.subclass_spells (subclass_id, spell_id, class_level, grant_kind)
      values (v_subclass, v_spell, rec.class_level, 'extends_list')
      on conflict (subclass_id, spell_id)
      do update set class_level = excluded.class_level, grant_kind = 'extends_list';
    v_done := v_done + 1;
  end loop;
  if v_done <> 110 then
    raise exception 'subclass_spells (patrons) : % lignes traitées, 110 attendues', v_done;
  end if;
end $$;

-- Regénère la description FR des aptitudes « Liste de sorts étendue (Niveau de sort n) » depuis
-- les données (une ligne class_features par sous-classe et niveau, si elle existe).
update public.translations d
   set value = 'Liste de sorts étendue (sorts de niveau ' || ((cf.level + 1) / 2) || ') : ' || sub.spell_names
               || '. Ces sorts s''ajoutent à la liste parmi laquelle vous choisissez vos sorts d''Occultiste.'
  from public.class_features cf
  join public.translations nm
    on nm.entity_type = 'class_feature' and nm.entity_id = cf.id::text
   and nm.field_name = 'name' and nm.locale = 'fr'
  join lateral (
    select string_agg(st.value, ', ' order by sp.level, st.value) as spell_names
      from public.subclass_spells ss
      join public.spells sp on sp.id = ss.spell_id
      join public.translations st
        on st.entity_type = 'spell' and st.entity_id = sp.id::text
       and st.field_name = 'name' and st.locale = 'fr'
     where ss.subclass_id = cf.subclass_id and ss.grant_kind = 'extends_list'
       and ss.class_level = cf.level
  ) sub on sub.spell_names is not null
 where d.entity_type = 'class_feature' and d.entity_id = cf.id::text
   and d.field_name = 'description' and d.locale = 'fr'
   and nm.value like 'Liste de sorts étendue (Niveau de sort %'
   and cf.level <= 9;
