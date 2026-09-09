-- Chantier "Personnages" (app mobile) -- contenu D&D, correctif lot 1.
-- Les 4 sous-races Génasi (migration 20260910090000) portaient une faute
-- d'accord répétée sur leur sort inné : "Le Constitution est votre
-- caractéristique d'incantation" au lieu de "La Constitution" (Constitution
-- est féminin en français). Trouvée en relecture par le chef de projet
-- avant de considérer le lot 1 terminé.

update public.subraces
set traits = (
  select jsonb_agg(
    jsonb_set(
      elem,
      '{description}',
      to_jsonb(replace(elem->>'description', 'Le Constitution est votre caractéristique', 'La Constitution est votre caractéristique'))
    )
  )
  from jsonb_array_elements(traits) elem
)
where traits::text like '%Le Constitution est votre caractéristique%';
