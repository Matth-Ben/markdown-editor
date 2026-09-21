-- Chantier "Personnages" (app mobile) — Occultiste : prérequis d'invocations structurés.
--
-- Jusqu'ici invocations.prerequisites ne contenait qu'un texte libre
-- ({"text": "Niveau 12, aptitude Pacte de la lame"}), affiché mais jamais vérifié par
-- l'app. Cette migration AJOUTE des clés structurées à côté de "text" (conservé tel quel
-- pour l'affichage) :
--   - "level"            : niveau d'Occultiste minimum (int)
--   - "pact"             : faveur de pacte requise — 'lame' | 'chaine' | 'grimoire'
--   - "cantrip_spell_id" : spells.id du sort mineur requis (Décharge occulte)
-- Idempotente : rejouable sans effet (les clés sont recalculées depuis "text").

do $$
declare
  v_eldritch_blast integer;
  v_unparsed integer;
begin
  select sp.id into v_eldritch_blast
    from public.spells sp
    join public.translations tr
      on tr.entity_type = 'spell' and tr.entity_id = sp.id::text
     and tr.field_name = 'name' and tr.locale = 'fr'
   where tr.value = $sp$Décharge occulte$sp$ and sp.level = 0;
  if v_eldritch_blast is null then
    raise exception 'Sort mineur "Décharge occulte" introuvable dans public.spells';
  end if;

  update public.invocations
     set prerequisites = prerequisites || jsonb_strip_nulls(jsonb_build_object(
           'level', substring(prerequisites->>'text' from 'Niveau ([0-9]+)')::int,
           'pact', case
                     when prerequisites->>'text' like '%Pacte de la lame%'    then 'lame'
                     when prerequisites->>'text' like '%Pacte de la chaîne%'  then 'chaine'
                     when prerequisites->>'text' like '%Pacte du grimoire%'   then 'grimoire'
                   end,
           'cantrip_spell_id', case
                     when prerequisites->>'text' like '%Décharge occulte%' then v_eldritch_blast
                   end
         ))
   where prerequisites ? 'text';

  -- Garde-fou : tout prérequis textuel mentionnant un niveau, un pacte ou un sort mineur
  -- doit avoir sa clé structurée correspondante.
  select count(*) into v_unparsed
    from public.invocations
   where (prerequisites->>'text' ~ 'Niveau'  and not prerequisites ? 'level')
      or (prerequisites->>'text' ~ 'Pacte'   and not prerequisites ? 'pact')
      or (prerequisites->>'text' ~ 'Décharge' and not prerequisites ? 'cantrip_spell_id');
  if v_unparsed > 0 then
    raise exception '% invocation(s) avec un prérequis textuel non structuré', v_unparsed;
  end if;
end $$;
