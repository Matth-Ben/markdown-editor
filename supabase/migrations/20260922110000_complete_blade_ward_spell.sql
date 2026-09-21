-- Chantier "Personnages" — complète le sort « Protection contre les armes » (Blade Ward,
-- sort mineur du Manuel des Joueurs, hors SRD) créé comme placeholder (is_incomplete) par
-- l'import XML aidedd, et référencé par un personnage. Le contenu ci-dessous est une
-- reformulation originale des règles (mécanique inchangée : résistance aux dégâts
-- contondants, perforants et tranchants des attaques d'arme jusqu'à la fin du prochain tour),
-- pas une reproduction du texte du livre. Idempotente : ne touche que le placeholder.

do $$
declare
  v_id integer;
begin
  select sp.id into v_id
    from public.spells sp
    join public.translations tr
      on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
     and tr.field_name = 'name' and tr.locale = 'fr'
   where sp.is_incomplete and lower(tr.value) = 'protection contre les armes';

  if v_id is null then
    return;  -- déjà complété (ou absent) : rien à faire
  end if;

  update public.spells
     set level = 0,
         school = $sp$Abjuration$sp$,
         casting_time = $sp$1 action$sp$,
         range = $sp$Personnelle$sp$,
         components = '{"verbal": true, "somatic": true, "material": false}'::jsonb,
         duration = $sp$1 round$sp$,
         concentration = false,
         ritual = false,
         source = $sp$Manuel des Joueurs$sp$,
         is_incomplete = false
   where id = v_id;

  update public.translations
     set value = $sp$Protection contre les armes$sp$
   where entity_type = 'spell' and entity_id = v_id::text
     and field_name = 'name' and locale = 'fr';

  insert into public.translations (entity_type, entity_id, field_name, locale, value) values
    ('spell', v_id::text, 'description', 'fr',
     $sp$Vous tendez la main et tracez dans l'air un signe de protection. Jusqu'à la fin de votre prochain tour, vous avez la résistance contre les dégâts contondants, perforants et tranchants infligés par les attaques d'arme.$sp$),
    ('spell', v_id::text, 'description', 'en',
     $sp$You extend your hand and trace a sigil of warding in the air. Until the end of your next turn, you have resistance against bludgeoning, piercing, and slashing damage dealt by weapon attacks.$sp$);

  insert into public.spell_classes (spell_id, class_id)
    select v_id, c.id
      from public.classes c
      join public.translations tc
        on tc.entity_type = 'class' and tc.entity_id = c.id::text
       and tc.field_name = 'name' and tc.locale = 'fr'
     where tc.value in ('Barde', 'Ensorceleur', 'Occultiste', 'Magicien')
    on conflict do nothing;
end $$;
