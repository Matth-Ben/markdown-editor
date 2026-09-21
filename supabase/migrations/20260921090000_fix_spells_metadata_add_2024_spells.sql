-- Chantier "Personnages" (app mobile) — Phase 5 — Contrôle des sorts contre Open5e (SRD 5.1 / SRD 5.2).
--
-- Trois volets, tous idempotents (rejouables sans effet sur une base déjà corrigée) :
--  1. Correction de métadonnées erronées sur des sorts du socle Phase 1 (composantes,
--     rituel, concentration, école) — vérifiées contre les deux SRD Open5e (2014 et 2024).
--     Une école n'est corrigée que si la valeur actuelle ne correspond à AUCUNE des deux
--     éditions ; harmonisation de « Conjuration » (2 lignes) vers « Invocation » (nom
--     retenu partout ailleurs dans la base).
--  2. Fusion des 2 sorts « placeholder » (is_incomplete) créés par l'import XML aidedd
--     avec leur équivalent du catalogue : les personnages qui les référencent sont
--     re-pointés, puis le placeholder est supprimé. Un 3e placeholder
--     (« protection contre les armes », Blade Ward, hors SRD) n'a pas d'équivalent en
--     base : il est volontairement laissé tel quel.
--  3. Ajout de 6 sorts présents uniquement dans le SRD 5.2 (règles 2024, CC-BY 4.0),
--     traduits fidèlement en français.

-- ---------------------------------------------------------------------------
-- 1. Correction de métadonnées
-- ---------------------------------------------------------------------------
do $$
declare
  rec record;
  v_rows integer;
begin
  for rec in
    select * from (values
      -- composantes (jsonb fusionné : seules les clés listées changent)
      ($sp$Flétrissure$sp$,            1, '{"somatic": true}'::jsonb,                    null::boolean, null::boolean, null::text, null::text),
      ($sp$Feu follet$sp$,             1, '{"somatic": false}'::jsonb,                   null, null, null, null),
      ($sp$Chute plume$sp$,            1, '{"somatic": false, "material": true}'::jsonb, null, null, null, null),
      ($sp$Détection du mal et du bien$sp$, 1, '{"material": false}'::jsonb,            null, null, null, null),
      ($sp$Baguette d'illusion$sp$,    0, '{"verbal": false, "material": true}'::jsonb,  null, null, null, null),
      -- Coup au but (SRD 5.1) : S seul, concentration jusqu'à 1 round
      ($sp$Avertissement occulte$sp$,  0, '{"verbal": false, "somatic": true}'::jsonb,   null, true, $sp$Concentration, jusqu'à 1 round$sp$, null),
      -- rituels manquants
      ($sp$Écriture illusoire$sp$,     1, null::jsonb, true, null, null, null),
      ($sp$Serviteur invisible$sp$,    1, null, true, null, null, $sp$Invocation$sp$),
      -- écoles
      ($sp$Main du mage$sp$,           0, null, null, null, null, $sp$Invocation$sp$),
      ($sp$Soins de groupe$sp$,        5, null, null, null, null, $sp$Invocation$sp$),
      ($sp$Guérison de groupe$sp$,     9, null, null, null, null, $sp$Invocation$sp$),
      ($sp$Aspersion empoisonnée$sp$,  0, null, null, null, null, $sp$Invocation$sp$),
      ($sp$Création de flamme$sp$,     0, null, null, null, null, $sp$Invocation$sp$),
      ($sp$Thaumaturgie$sp$,           0, null, null, null, null, $sp$Transmutation$sp$)
    ) as t(name, level, comp_patch, ritual, concentration, duration, school)
  loop
    update public.spells sp
       set components    = case when rec.comp_patch is null then sp.components else sp.components || rec.comp_patch end,
           ritual        = coalesce(rec.ritual, sp.ritual),
           concentration = coalesce(rec.concentration, sp.concentration),
           duration      = coalesce(rec.duration, sp.duration),
           school        = coalesce(rec.school, sp.school)
      from public.translations tr
     where tr.entity_type = 'spell' and tr.entity_id = sp.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
       and tr.value = rec.name and sp.level = rec.level;
    get diagnostics v_rows = row_count;
    if v_rows <> 1 then
      raise exception 'Correction de métadonnées : % ligne(s) pour "%" (niveau %), 1 attendue', v_rows, rec.name, rec.level;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Fusion des placeholders avec leur équivalent du catalogue
-- ---------------------------------------------------------------------------
do $$
declare
  rec record;
  v_placeholder integer;
  v_target integer;
begin
  for rec in
    select * from (values
      ($sp$vague tonnante$sp$,                  $sp$Vague tonnerre$sp$,        1),
      ($sp$communication avec les animaux$sp$,  $sp$Parole avec les animaux$sp$, 1)
    ) as t(placeholder_name, target_name, target_level)
  loop
    select sp.id into v_placeholder
      from public.spells sp
      join public.translations tr
        on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where sp.is_incomplete and tr.value = rec.placeholder_name;

    select sp.id into v_target
      from public.spells sp
      join public.translations tr
        on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
       and tr.field_name = 'name' and tr.locale = 'fr'
     where not sp.is_incomplete and sp.level = rec.target_level and tr.value = rec.target_name;

    if v_placeholder is not null and v_target is not null then
      -- un personnage qui a déjà le sort cible n'a pas besoin d'une seconde ligne
      delete from public.character_spells ph
       where ph.spell_id = v_placeholder
         and exists (
           select 1 from public.character_spells t
            where t.character_id = ph.character_id and t.spell_id = v_target
         );
      update public.character_spells set spell_id = v_target where spell_id = v_placeholder;
      update public.racial_innate_spells set spell_id = v_target where spell_id = v_placeholder;
      delete from public.translations
       where entity_type = 'spell' and entity_id = v_placeholder::text;
      delete from public.spells where id = v_placeholder;  -- spell_classes : ON DELETE CASCADE
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Six sorts du SRD 5.2 (2024) absents du catalogue
-- ---------------------------------------------------------------------------
do $$
declare
  rec record;
  v_id integer;
begin
  for rec in
    select * from (values
      (
        $sp$Élémentalisme$sp$, 0, $sp$Transmutation$sp$, $sp$1 action$sp$, $sp$9 mètres$sp$,
        '{"verbal": true, "somatic": true, "material": false}'::jsonb, $sp$Instantanée$sp$, false, false,
        $sp$Vous exercez un contrôle sur les éléments et créez à portée l'un des effets suivants.

***Appel de l'air.*** Vous créez une brise assez forte pour agiter le tissu, soulever la poussière, faire bruire les feuilles et fermer les portes et volets ouverts, le tout dans un cube de 1,50 mètre d'arête. Les portes et volets maintenus ouverts par quelqu'un ou quelque chose ne sont pas affectés.

***Appel de la terre.*** Vous créez une fine couche de poussière ou de sable qui recouvre les surfaces d'une zone de 1,50 mètre de côté, ou vous faites apparaître un mot, de votre écriture, dans une plaque de terre ou de sable.

***Appel du feu.*** Vous créez un mince nuage de braises inoffensives et de fumée colorée et parfumée dans un cube de 1,50 mètre d'arête. Vous choisissez la couleur et l'odeur, et les braises peuvent allumer bougies, torches ou lampes dans cette zone. L'odeur de la fumée persiste 1 minute.

***Appel de l'eau.*** Vous créez un jet de brume fraîche qui humidifie légèrement les créatures et les objets dans un cube de 1,50 mètre d'arête. Vous pouvez aussi créer une tasse d'eau claire, dans un récipient ouvert ou sur une surface ; l'eau s'évapore en 1 minute.

***Façonnage d'élément.*** Vous faites prendre une forme grossière (par exemple celle d'une créature) à de la terre, du sable, du feu, de la fumée, de la brume ou de l'eau tenant dans un cube de 30 centimètres d'arête, pendant 1 heure.$sp$,
        $sp$You exert control over the elements, creating one of the following effects within range.

***Beckon Air.*** You create a breeze strong enough to ripple cloth, stir dust, rustle leaves, and close open doors and shutters, all in a 5-foot Cube. Doors and shutters being held open by someone or something aren't affected.

***Beckon Earth.*** You create a thin shroud of dust or sand that covers surfaces in a 5-foot-square area, or you cause a single word to appear in your handwriting in a patch of dirt or sand.

***Beckon Fire.*** You create a thin cloud of harmless embers and colored, scented smoke in a 5-foot Cube. You choose the color and scent, and the embers can light candles, torches, or lamps in that area. The smoke's scent lingers for 1 minute.

***Beckon Water.*** You create a spray of cool mist that lightly dampens creatures and objects in a 5-foot Cube. Alternatively, you create 1 cup of clean water either in an open container or on a surface, and the water evaporates in 1 minute.

***Sculpt Element.*** You cause dirt, sand, fire, smoke, mist, or water that can fit in a 1-foot Cube to assume a crude shape (such as that of a creature) for 1 hour.$sp$,
        array[$sp$Druide$sp$, $sp$Ensorceleur$sp$, $sp$Magicien$sp$]
      ),
      (
        $sp$Explosion ensorcelée$sp$, 0, $sp$Évocation$sp$, $sp$1 action$sp$, $sp$36 mètres$sp$,
        '{"verbal": true, "somatic": true, "material": false}'::jsonb, $sp$Instantanée$sp$, false, false,
        $sp$Vous projetez de l'énergie sorcière sur une créature ou un objet à portée. Faites une attaque de sort à distance contre la cible. En cas de réussite, la cible subit 1d8 dégâts d'un type de votre choix : acide, froid, feu, foudre, poison, psychique ou tonnerre. Si vous obtenez un 8 sur un d8 pour ce sort, vous pouvez lancer un d8 supplémentaire et l'ajouter aux dégâts. Le nombre maximal de d8 que vous pouvez ainsi ajouter aux dégâts du sort est égal à votre modificateur de caractéristique d'incantation.

Aux niveaux supérieurs. Les dégâts augmentent de 1d8 aux niveaux 5 (2d8), 11 (3d8) et 17 (4d8).$sp$,
        $sp$You cast sorcerous energy at one creature or object within range. Make a ranged spell attack against the target. On a hit, the target takes 1d8 damage of a type you choose: Acid, Cold, Fire, Lightning, Poison, Psychic, or Thunder. If you roll an 8 on a d8 for this spell, you can roll another d8, and add it to the damage. When you cast this spell, the maximum number of these d8s you can add to the spell's damage equals your spellcasting ability modifier.

The damage increases by 1d8 when you reach levels 5 (2d8), 11 (3d8), and 17 (4d8).$sp$,
        array[$sp$Ensorceleur$sp$]
      ),
      (
        $sp$Volute étoilée$sp$, 0, $sp$Évocation$sp$, $sp$1 action$sp$, $sp$18 mètres$sp$,
        '{"verbal": true, "somatic": true, "material": false}'::jsonb, $sp$Instantanée$sp$, false, false,
        $sp$Vous lancez une particule de lumière sur une créature ou un objet à portée. Faites une attaque de sort à distance contre la cible. En cas de réussite, la cible subit 1d8 dégâts radiants et, jusqu'à la fin de votre prochain tour, elle émet une lumière faible dans un rayon de 3 mètres et ne peut pas bénéficier de la condition invisible.

Aux niveaux supérieurs. Les dégâts augmentent de 1d8 aux niveaux 5 (2d8), 11 (3d8) et 17 (4d8).$sp$,
        $sp$You launch a mote of light at one creature or object within range. Make a ranged spell attack against the target. On a hit, the target takes 1d8 Radiant damage, and until the end of your next turn, it emits Dim Light in a 10-foot radius and can't benefit from the Invisible condition.

The damage increases by 1d8 when you reach levels 5 (2d8), 11 (3d8), and 17 (4d8).$sp$,
        array[$sp$Barde$sp$, $sp$Druide$sp$]
      ),
      (
        $sp$Châtiment divin$sp$, 1, $sp$Évocation$sp$, $sp$1 action bonus$sp$, $sp$Personnelle$sp$,
        '{"verbal": true, "somatic": false, "material": false}'::jsonb, $sp$Instantanée$sp$, false, false,
        $sp$La cible subit 2d8 dégâts radiants supplémentaires de l'attaque. Les dégâts augmentent de 1d8 si la cible est un fiélon ou un mort-vivant.

Aux niveaux supérieurs. Les dégâts augmentent de 1d8 pour chaque niveau d'emplacement de sort au-dessus du niveau 1.$sp$,
        $sp$The target takes an extra 2d8 Radiant damage from the attack. The damage increases by 1d8 if the target is a Fiend or an Undead.

The damage increases by 1d8 for each spell slot level above 1.$sp$,
        array[$sp$Paladin$sp$]
      ),
      (
        $sp$Châtiment radieux$sp$, 2, $sp$Transmutation$sp$, $sp$1 action bonus$sp$, $sp$Personnelle$sp$,
        '{"verbal": true, "somatic": false, "material": false}'::jsonb, $sp$Concentration, jusqu'à 1 minute$sp$, true, false,
        $sp$La cible touchée par la frappe subit 2d6 dégâts radiants supplémentaires de l'attaque. Jusqu'à la fin du sort, la cible émet une lumière vive dans un rayon de 1,50 mètre, les jets d'attaque contre elle ont l'avantage et elle ne peut pas bénéficier de la condition invisible.

Aux niveaux supérieurs. Les dégâts augmentent de 1d6 pour chaque niveau d'emplacement de sort au-dessus du niveau 2.$sp$,
        $sp$The target hit by the strike takes an extra 2d6 Radiant damage from the attack. Until the spell ends, the target sheds Bright Light in a 5-foot radius, attack rolls against it have Advantage, and it can't benefit from the Invisible condition.

The damage increases by 1d6 for each spell slot level above 2.$sp$,
        array[$sp$Paladin$sp$]
      ),
      (
        $sp$Convocation de dragon$sp$, 5, $sp$Invocation$sp$, $sp$1 action$sp$, $sp$18 mètres$sp$,
        '{"verbal": true, "somatic": true, "material": true}'::jsonb, $sp$Concentration, jusqu'à 1 heure$sp$, true, false,
        $sp$Vous faites venir un esprit draconique. Il se manifeste dans un espace inoccupé que vous voyez à portée et utilise le profil d'Esprit draconique. La créature disparaît lorsqu'elle tombe à 0 point de vie ou lorsque le sort prend fin.

La créature est un allié pour vous et vos alliés. En combat, elle partage votre décompte d'initiative, mais son tour a lieu immédiatement après le vôtre. Elle obéit à vos ordres verbaux (aucune action requise de votre part). Si vous n'en donnez aucun, elle effectue l'action Esquive et utilise son déplacement pour éviter le danger.

Composante matérielle : un objet portant l'image gravée d'un dragon, d'une valeur d'au moins 500 po, consommé par le sort.

Aux niveaux supérieurs. Utilisez le niveau de l'emplacement de sort comme niveau du sort dans le profil de la créature.$sp$,
        $sp$You call forth a Dragon spirit. It manifests in an unoccupied space that you can see within range and uses the Draconic Spirit stat block. The creature disappears when it drops to 0 Hit Points or when the spell ends. The creature is an ally to you and your allies. In combat, the creature shares your Initiative count, but it takes its turn immediately after yours. It obeys your verbal commands (no action required by you). If you don't issue any, it takes the Dodge action and uses its movement to avoid danger.

Material component: an object with the image of a dragon engraved on it worth 500+ GP, consumed by the spell.

Use the spell slot's level for the spell's level in the stat block.$sp$,
        array[$sp$Magicien$sp$]
      )
    ) as t(name, level, school, casting_time, range, components, duration, concentration, ritual, description_fr, description_en, class_names)
  loop
    if not exists (
      select 1
        from public.spells sp
        join public.translations tr
          on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
         and tr.field_name = 'name' and tr.locale = 'fr'
       where tr.value = rec.name and sp.level = rec.level
    ) then
      insert into public.spells (level, school, casting_time, range, components, duration, concentration, ritual, source)
        values (rec.level, rec.school, rec.casting_time, rec.range, rec.components, rec.duration, rec.concentration, rec.ritual, $sp$Manuel des Joueurs (2024)$sp$)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('spell', v_id::text, 'name', 'fr', rec.name),
        ('spell', v_id::text, 'description', 'fr', rec.description_fr),
        ('spell', v_id::text, 'description', 'en', rec.description_en);
      insert into public.spell_classes (spell_id, class_id)
        select v_id, c.id
          from public.classes c
          join public.translations tc
            on tc.entity_type = 'class' and tc.entity_id = c.id::text
           and tc.field_name = 'name' and tc.locale = 'fr'
         where tc.value = any (rec.class_names);
    end if;
  end loop;
end $$;
