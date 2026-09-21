-- Chantier "Personnages" (app mobile) — Sorts toujours préparés des sous-classes.
--
-- Crée public.subclass_spells : sorts accordés automatiquement par une sous-classe à un
-- niveau de CLASSE donné (sorts de domaine du Clerc, sorts de serment du Paladin), toujours
-- préparés et ne comptant pas dans la limite de sorts préparés. L'app les dérive à
-- l'affichage à partir de la sous-classe et du niveau du personnage (aucune écriture dans
-- character_spells).
--
-- Périmètre : 10 domaines de Clerc (PHB, Xanathar, Tasha) et 7 serments de Paladin (PHB,
-- Xanathar, Tasha) — listes vérifiées une à une contre les règles, avec contrôle
-- automatique que chaque sort a bien le niveau d'emplacement correspondant au niveau de
-- classe. HORS périmètre volontaire : Cercle de la Terre (sorts dépendant du terrain
-- choisi) et listes étendues des patrons d'Occultiste (sorts ajoutés au CHOIX, jamais
-- préparés d'office : sémantique différente).
--
-- Corrige au passage la description des aptitudes « Sorts de domaine / de serment »
-- existantes (plusieurs listes étaient fausses : Domaine de la Nature niv. 5, Serment des
-- Anciens et Serment de vengeance) en la regénérant depuis les mêmes données.

create table if not exists public.subclass_spells (
  subclass_id int not null references public.subclasses (id) on delete cascade,
  spell_id    int not null references public.spells (id) on delete cascade,
  class_level int not null check (class_level between 1 and 20),
  primary key (subclass_id, spell_id)
);

alter table public.subclass_spells enable row level security;

drop policy if exists "Authenticated users can read subclass_spells" on public.subclass_spells;
create policy "Authenticated users can read subclass_spells"
  on public.subclass_spells for select
  to authenticated
  using (true);

drop policy if exists "Admins can insert subclass_spells" on public.subclass_spells;
create policy "Admins can insert subclass_spells"
  on public.subclass_spells for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "Admins can update subclass_spells" on public.subclass_spells;
create policy "Admins can update subclass_spells"
  on public.subclass_spells for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Admins can delete subclass_spells" on public.subclass_spells;
create policy "Admins can delete subclass_spells"
  on public.subclass_spells for delete
  to authenticated
  using (public.is_admin());

grant select on table public.subclass_spells to authenticated;

do $$
declare
  rec record;
  v_subclass integer;
  v_spell integer;
  v_inserted integer := 0;
begin
  for rec in
    select * from (values
  ($sp$Domaine de la Vie$sp$, 3, 1, $sp$Bénédiction$sp$, 1),
  ($sp$Domaine de la Vie$sp$, 3, 1, $sp$Soins$sp$, 1),
  ($sp$Domaine de la Vie$sp$, 3, 3, $sp$Restauration partielle$sp$, 2),
  ($sp$Domaine de la Vie$sp$, 3, 3, $sp$Arme spirituelle$sp$, 2),
  ($sp$Domaine de la Vie$sp$, 3, 5, $sp$Lueur d'espoir$sp$, 3),
  ($sp$Domaine de la Vie$sp$, 3, 5, $sp$Retour à la vie$sp$, 3),
  ($sp$Domaine de la Vie$sp$, 3, 7, $sp$Protection contre la mort$sp$, 4),
  ($sp$Domaine de la Vie$sp$, 3, 7, $sp$Gardien de la foi$sp$, 4),
  ($sp$Domaine de la Vie$sp$, 3, 9, $sp$Soins de groupe$sp$, 5),
  ($sp$Domaine de la Vie$sp$, 3, 9, $sp$Rappel à la vie$sp$, 5),
  ($sp$Duperie$sp$, 3, 1, $sp$Charme-personne$sp$, 1),
  ($sp$Duperie$sp$, 3, 1, $sp$Déguisement$sp$, 1),
  ($sp$Duperie$sp$, 3, 3, $sp$Image miroir$sp$, 2),
  ($sp$Duperie$sp$, 3, 3, $sp$Passage sans trace$sp$, 2),
  ($sp$Duperie$sp$, 3, 5, $sp$Clignotement$sp$, 3),
  ($sp$Duperie$sp$, 3, 5, $sp$Dissipation de la magie$sp$, 3),
  ($sp$Duperie$sp$, 3, 7, $sp$Porte dimensionnelle$sp$, 4),
  ($sp$Duperie$sp$, 3, 7, $sp$Métamorphose$sp$, 4),
  ($sp$Duperie$sp$, 3, 9, $sp$Domination de personne$sp$, 5),
  ($sp$Duperie$sp$, 3, 9, $sp$Modification de mémoire$sp$, 5),
  ($sp$Guerre$sp$, 3, 1, $sp$Faveur divine$sp$, 1),
  ($sp$Guerre$sp$, 3, 1, $sp$Bouclier de la foi$sp$, 1),
  ($sp$Guerre$sp$, 3, 3, $sp$Arme magique$sp$, 2),
  ($sp$Guerre$sp$, 3, 3, $sp$Arme spirituelle$sp$, 2),
  ($sp$Guerre$sp$, 3, 5, $sp$Aura du croisé$sp$, 3),
  ($sp$Guerre$sp$, 3, 5, $sp$Esprits gardiens$sp$, 3),
  ($sp$Guerre$sp$, 3, 7, $sp$Liberté de mouvement$sp$, 4),
  ($sp$Guerre$sp$, 3, 7, $sp$Peau de pierre$sp$, 4),
  ($sp$Guerre$sp$, 3, 9, $sp$Colonne de flamme$sp$, 5),
  ($sp$Guerre$sp$, 3, 9, $sp$Immobilisation de monstre$sp$, 5),
  ($sp$Lumière$sp$, 3, 1, $sp$Mains brûlantes$sp$, 1),
  ($sp$Lumière$sp$, 3, 1, $sp$Feu follet$sp$, 1),
  ($sp$Lumière$sp$, 3, 3, $sp$Sphère de feu$sp$, 2),
  ($sp$Lumière$sp$, 3, 3, $sp$Rayon ardent$sp$, 2),
  ($sp$Lumière$sp$, 3, 5, $sp$Lumière du jour$sp$, 3),
  ($sp$Lumière$sp$, 3, 5, $sp$Boule de feu$sp$, 3),
  ($sp$Lumière$sp$, 3, 7, $sp$Gardien de la foi$sp$, 4),
  ($sp$Lumière$sp$, 3, 7, $sp$Mur de feu$sp$, 4),
  ($sp$Lumière$sp$, 3, 9, $sp$Colonne de flamme$sp$, 5),
  ($sp$Lumière$sp$, 3, 9, $sp$Scrutation$sp$, 5),
  ($sp$Nature$sp$, 3, 1, $sp$Amitié avec les animaux$sp$, 1),
  ($sp$Nature$sp$, 3, 1, $sp$Parole avec les animaux$sp$, 1),
  ($sp$Nature$sp$, 3, 3, $sp$Peau d'écorce$sp$, 2),
  ($sp$Nature$sp$, 3, 3, $sp$Croissance d'épines$sp$, 2),
  ($sp$Nature$sp$, 3, 5, $sp$Croissance végétale$sp$, 3),
  ($sp$Nature$sp$, 3, 5, $sp$Mur de vent$sp$, 3),
  ($sp$Nature$sp$, 3, 7, $sp$Domination de bête$sp$, 4),
  ($sp$Nature$sp$, 3, 7, $sp$Liane avide$sp$, 4),
  ($sp$Nature$sp$, 3, 9, $sp$Fléau d'insectes$sp$, 5),
  ($sp$Nature$sp$, 3, 9, $sp$Passage par les arbres$sp$, 5),
  ($sp$Savoir$sp$, 3, 1, $sp$Injonction$sp$, 1),
  ($sp$Savoir$sp$, 3, 1, $sp$Identification$sp$, 1),
  ($sp$Savoir$sp$, 3, 3, $sp$Augure$sp$, 2),
  ($sp$Savoir$sp$, 3, 3, $sp$Suggestion$sp$, 2),
  ($sp$Savoir$sp$, 3, 5, $sp$Antidétection$sp$, 3),
  ($sp$Savoir$sp$, 3, 5, $sp$Communication avec les morts$sp$, 3),
  ($sp$Savoir$sp$, 3, 7, $sp$Oeil magique$sp$, 4),
  ($sp$Savoir$sp$, 3, 7, $sp$Confusion$sp$, 4),
  ($sp$Savoir$sp$, 3, 9, $sp$Mythes et légendes$sp$, 5),
  ($sp$Savoir$sp$, 3, 9, $sp$Scrutation$sp$, 5),
  ($sp$Tempête$sp$, 3, 1, $sp$Nappe de brouillard$sp$, 1),
  ($sp$Tempête$sp$, 3, 1, $sp$Vague tonnerre$sp$, 1),
  ($sp$Tempête$sp$, 3, 3, $sp$Bourrasque$sp$, 2),
  ($sp$Tempête$sp$, 3, 3, $sp$Fracassement$sp$, 2),
  ($sp$Tempête$sp$, 3, 5, $sp$Appel de la foudre$sp$, 3),
  ($sp$Tempête$sp$, 3, 5, $sp$Tempête de neige$sp$, 3),
  ($sp$Tempête$sp$, 3, 7, $sp$Contrôle de l'eau$sp$, 4),
  ($sp$Tempête$sp$, 3, 7, $sp$Tempête de grêle$sp$, 4),
  ($sp$Tempête$sp$, 3, 9, $sp$Vague destructrice$sp$, 5),
  ($sp$Tempête$sp$, 3, 9, $sp$Fléau d'insectes$sp$, 5),
  ($sp$Forge$sp$, 3, 1, $sp$Identification$sp$, 1),
  ($sp$Forge$sp$, 3, 1, $sp$Châtiment calcinant$sp$, 1),
  ($sp$Forge$sp$, 3, 3, $sp$Métal brûlant$sp$, 2),
  ($sp$Forge$sp$, 3, 3, $sp$Arme magique$sp$, 2),
  ($sp$Forge$sp$, 3, 5, $sp$Arme élémentaire$sp$, 3),
  ($sp$Forge$sp$, 3, 5, $sp$Protection contre une énergie$sp$, 3),
  ($sp$Forge$sp$, 3, 7, $sp$Fabrication$sp$, 4),
  ($sp$Forge$sp$, 3, 7, $sp$Mur de feu$sp$, 4),
  ($sp$Forge$sp$, 3, 9, $sp$Animation d'objets$sp$, 5),
  ($sp$Forge$sp$, 3, 9, $sp$Création$sp$, 5),
  ($sp$Tombe$sp$, 3, 1, $sp$Flétrissure$sp$, 1),
  ($sp$Tombe$sp$, 3, 1, $sp$Simulacre de vie$sp$, 1),
  ($sp$Tombe$sp$, 3, 3, $sp$Préservation des morts$sp$, 2),
  ($sp$Tombe$sp$, 3, 3, $sp$Rayon affaiblissant$sp$, 2),
  ($sp$Tombe$sp$, 3, 5, $sp$Retour à la vie$sp$, 3),
  ($sp$Tombe$sp$, 3, 5, $sp$Toucher du vampire$sp$, 3),
  ($sp$Tombe$sp$, 3, 7, $sp$Flétrissement$sp$, 4),
  ($sp$Tombe$sp$, 3, 7, $sp$Protection contre la mort$sp$, 4),
  ($sp$Tombe$sp$, 3, 9, $sp$Coquille antivie$sp$, 5),
  ($sp$Tombe$sp$, 3, 9, $sp$Rappel à la vie$sp$, 5),
  ($sp$Crépuscule$sp$, 3, 1, $sp$Feu follet$sp$, 1),
  ($sp$Crépuscule$sp$, 3, 1, $sp$Sommeil$sp$, 1),
  ($sp$Crépuscule$sp$, 3, 3, $sp$Rayon de lune$sp$, 2),
  ($sp$Crépuscule$sp$, 3, 3, $sp$Voir l'invisible$sp$, 2),
  ($sp$Crépuscule$sp$, 3, 5, $sp$Aura de vitalité$sp$, 3),
  ($sp$Crépuscule$sp$, 3, 5, $sp$Petite hutte de Léomund$sp$, 3),
  ($sp$Crépuscule$sp$, 3, 7, $sp$Aura de vie$sp$, 4),
  ($sp$Crépuscule$sp$, 3, 7, $sp$Invisibilité supérieure$sp$, 4),
  ($sp$Crépuscule$sp$, 3, 9, $sp$Cercle de pouvoir$sp$, 5),
  ($sp$Crépuscule$sp$, 3, 9, $sp$Double illusoire$sp$, 5),
  ($sp$Serment de dévotion$sp$, 7, 3, $sp$Protection contre le mal et le bien$sp$, 1),
  ($sp$Serment de dévotion$sp$, 7, 3, $sp$Sanctuaire$sp$, 1),
  ($sp$Serment de dévotion$sp$, 7, 5, $sp$Restauration partielle$sp$, 2),
  ($sp$Serment de dévotion$sp$, 7, 5, $sp$Zone de vérité$sp$, 2),
  ($sp$Serment de dévotion$sp$, 7, 9, $sp$Lueur d'espoir$sp$, 3),
  ($sp$Serment de dévotion$sp$, 7, 9, $sp$Dissipation de la magie$sp$, 3),
  ($sp$Serment de dévotion$sp$, 7, 13, $sp$Liberté de mouvement$sp$, 4),
  ($sp$Serment de dévotion$sp$, 7, 13, $sp$Gardien de la foi$sp$, 4),
  ($sp$Serment de dévotion$sp$, 7, 17, $sp$Communion$sp$, 5),
  ($sp$Serment de dévotion$sp$, 7, 17, $sp$Colonne de flamme$sp$, 5),
  ($sp$Serment des Anciens$sp$, 7, 3, $sp$Frappe piégeuse$sp$, 1),
  ($sp$Serment des Anciens$sp$, 7, 3, $sp$Parole avec les animaux$sp$, 1),
  ($sp$Serment des Anciens$sp$, 7, 5, $sp$Rayon de lune$sp$, 2),
  ($sp$Serment des Anciens$sp$, 7, 5, $sp$Foulée brumeuse$sp$, 2),
  ($sp$Serment des Anciens$sp$, 7, 9, $sp$Croissance végétale$sp$, 3),
  ($sp$Serment des Anciens$sp$, 7, 9, $sp$Protection contre une énergie$sp$, 3),
  ($sp$Serment des Anciens$sp$, 7, 13, $sp$Tempête de grêle$sp$, 4),
  ($sp$Serment des Anciens$sp$, 7, 13, $sp$Peau de pierre$sp$, 4),
  ($sp$Serment des Anciens$sp$, 7, 17, $sp$Communion avec la nature$sp$, 5),
  ($sp$Serment des Anciens$sp$, 7, 17, $sp$Passage par les arbres$sp$, 5),
  ($sp$Serment de vengeance$sp$, 7, 3, $sp$Flétrissure$sp$, 1),
  ($sp$Serment de vengeance$sp$, 7, 3, $sp$Marque du chasseur$sp$, 1),
  ($sp$Serment de vengeance$sp$, 7, 5, $sp$Immobilisation de personne$sp$, 2),
  ($sp$Serment de vengeance$sp$, 7, 5, $sp$Foulée brumeuse$sp$, 2),
  ($sp$Serment de vengeance$sp$, 7, 9, $sp$Hâte$sp$, 3),
  ($sp$Serment de vengeance$sp$, 7, 9, $sp$Protection contre une énergie$sp$, 3),
  ($sp$Serment de vengeance$sp$, 7, 13, $sp$Bannissement$sp$, 4),
  ($sp$Serment de vengeance$sp$, 7, 13, $sp$Porte dimensionnelle$sp$, 4),
  ($sp$Serment de vengeance$sp$, 7, 17, $sp$Immobilisation de monstre$sp$, 5),
  ($sp$Serment de vengeance$sp$, 7, 17, $sp$Scrutation$sp$, 5),
  ($sp$Serment de conquête$sp$, 7, 3, $sp$Armure d'Agathys$sp$, 1),
  ($sp$Serment de conquête$sp$, 7, 3, $sp$Injonction$sp$, 1),
  ($sp$Serment de conquête$sp$, 7, 5, $sp$Immobilisation de personne$sp$, 2),
  ($sp$Serment de conquête$sp$, 7, 5, $sp$Arme spirituelle$sp$, 2),
  ($sp$Serment de conquête$sp$, 7, 9, $sp$Malédiction$sp$, 3),
  ($sp$Serment de conquête$sp$, 7, 9, $sp$Peur$sp$, 3),
  ($sp$Serment de conquête$sp$, 7, 13, $sp$Domination de bête$sp$, 4),
  ($sp$Serment de conquête$sp$, 7, 13, $sp$Peau de pierre$sp$, 4),
  ($sp$Serment de conquête$sp$, 7, 17, $sp$Brume mortelle$sp$, 5),
  ($sp$Serment de conquête$sp$, 7, 17, $sp$Domination de personne$sp$, 5),
  ($sp$Serment de gloire$sp$, 7, 3, $sp$Éclair traçant$sp$, 1),
  ($sp$Serment de gloire$sp$, 7, 3, $sp$Vaillance$sp$, 1),
  ($sp$Serment de gloire$sp$, 7, 5, $sp$Amélioration de caractéristique$sp$, 2),
  ($sp$Serment de gloire$sp$, 7, 5, $sp$Arme magique$sp$, 2),
  ($sp$Serment de gloire$sp$, 7, 9, $sp$Hâte$sp$, 3),
  ($sp$Serment de gloire$sp$, 7, 9, $sp$Protection contre une énergie$sp$, 3),
  ($sp$Serment de gloire$sp$, 7, 13, $sp$Compulsion$sp$, 4),
  ($sp$Serment de gloire$sp$, 7, 13, $sp$Liberté de mouvement$sp$, 4),
  ($sp$Serment de gloire$sp$, 7, 17, $sp$Communion$sp$, 5),
  ($sp$Serment de gloire$sp$, 7, 17, $sp$Colonne de flamme$sp$, 5),
  ($sp$Serment des guetteurs$sp$, 7, 3, $sp$Alarme$sp$, 1),
  ($sp$Serment des guetteurs$sp$, 7, 3, $sp$Détection de la magie$sp$, 1),
  ($sp$Serment des guetteurs$sp$, 7, 5, $sp$Rayon de lune$sp$, 2),
  ($sp$Serment des guetteurs$sp$, 7, 5, $sp$Voir l'invisible$sp$, 2),
  ($sp$Serment des guetteurs$sp$, 7, 9, $sp$Contresort$sp$, 3),
  ($sp$Serment des guetteurs$sp$, 7, 9, $sp$Antidétection$sp$, 3),
  ($sp$Serment des guetteurs$sp$, 7, 13, $sp$Aura de pureté$sp$, 4),
  ($sp$Serment des guetteurs$sp$, 7, 13, $sp$Bannissement$sp$, 4),
  ($sp$Serment des guetteurs$sp$, 7, 17, $sp$Immobilisation de monstre$sp$, 5),
  ($sp$Serment des guetteurs$sp$, 7, 17, $sp$Scrutation$sp$, 5),
  ($sp$Serment de rédemption$sp$, 7, 3, $sp$Sanctuaire$sp$, 1),
  ($sp$Serment de rédemption$sp$, 7, 3, $sp$Sommeil$sp$, 1),
  ($sp$Serment de rédemption$sp$, 7, 5, $sp$Apaisement des émotions$sp$, 2),
  ($sp$Serment de rédemption$sp$, 7, 5, $sp$Immobilisation de personne$sp$, 2),
  ($sp$Serment de rédemption$sp$, 7, 9, $sp$Contresort$sp$, 3),
  ($sp$Serment de rédemption$sp$, 7, 9, $sp$Motif hypnotique$sp$, 3),
  ($sp$Serment de rédemption$sp$, 7, 13, $sp$Sphère résiliente d'Otiluke$sp$, 4),
  ($sp$Serment de rédemption$sp$, 7, 13, $sp$Peau de pierre$sp$, 4),
  ($sp$Serment de rédemption$sp$, 7, 17, $sp$Immobilisation de monstre$sp$, 5),
  ($sp$Serment de rédemption$sp$, 7, 17, $sp$Mur de force$sp$, 5)
    ) as t(subclass_name, class_id, class_level, spell_name, spell_level)
  loop
    select sc.id into strict v_subclass
      from public.subclasses sc
      join public.translations tr
        on tr.entity_type = 'subclass' and tr.entity_id = sc.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where tr.value = rec.subclass_name and sc.class_id = rec.class_id;

    select sp.id into strict v_spell
      from public.spells sp
      join public.translations tr
        on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where tr.value = rec.spell_name and sp.level = rec.spell_level and not sp.is_incomplete;

    insert into public.subclass_spells (subclass_id, spell_id, class_level)
      values (v_subclass, v_spell, rec.class_level)
      on conflict (subclass_id, spell_id) do update set class_level = excluded.class_level;
    v_inserted := v_inserted + 1;
  end loop;
  if v_inserted <> 170 then
    raise exception 'subclass_spells : % lignes traitées, 170 attendues', v_inserted;
  end if;
end $$;

-- Regénère la description FR des aptitudes « Sorts de domaine/serment (Niveau de X n) »
-- depuis subclass_spells (une ligne class_features par sous-classe et niveau, si elle existe).
update public.translations d
   set value = (case when sc.class_id = 3 then 'Sorts de domaine' else 'Sorts de serment' end)
               || ' toujours préparés : ' || sub.spell_names || '.'
  from public.class_features cf
  join public.subclasses sc on sc.id = cf.subclass_id
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
     where ss.subclass_id = cf.subclass_id and ss.class_level = cf.level
  ) sub on sub.spell_names is not null
 where d.entity_type = 'class_feature' and d.entity_id = cf.id::text
   and d.field_name = 'description' and d.locale = 'fr'
   and (nm.value like 'Sorts de domaine (Niveau de clerc %' or nm.value like 'Sorts de serment (Niveau de paladin %');
