-- Chantier "Bibliothèque" — propositions de races et de classes.
--
-- 1. Deux nouveaux types de contenu proposables : 'race' et 'class'.
-- 2. Limite de taille du contenu proposé relevée de 20 000 à 60 000 octets :
--    une classe complète (aptitudes niveau par niveau + sous-classes) ou une
--    race avec plusieurs sous-races dépasse facilement 20 000 octets, alors
--    qu'un sort/don/objet reste très en deçà. La borne reste là pour qu'un
--    client ne puisse pas stocker n'importe quoi.
--
-- Les contraintes ont été créées en ligne dans 20260919090000 : leurs noms
-- sont ceux générés par PostgreSQL (vérifiés sur une base locale).

alter table public.content_proposals
  drop constraint content_proposals_content_type_check,
  drop constraint content_proposals_payload_check;

alter table public.content_proposals
  add constraint content_proposals_content_type_check
    check (content_type in ('spell', 'feat', 'item', 'race', 'class')),
  add constraint content_proposals_payload_check
    check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 60000);
