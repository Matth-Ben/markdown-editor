-- Chantier "Bibliothèque" — propositions de MODIFICATION d'un contenu existant.
--
-- `target_id` = identifiant de la ligne de référence visée (spells, feats,
-- items, races, classes selon `content_type`) ; null = proposition d'un
-- nouveau contenu. Pas de clé étrangère : la cible dépend de `content_type`
-- (5 tables différentes), même compromis que `translations.entity_id`
-- (voir 20260825090050). L'application vérifie que la cible existe ; en base,
-- seule la validité de la valeur est contrôlée.
--
-- Le contenu de la proposition (`payload`) reste la version complète proposée
-- de l'élément. `target_id` est posé à l'insertion et n'est jamais
-- modifiable ensuite (aucun privilège de colonne en update, cf.
-- 20260919090000) ; l'approbation ne fait toujours que changer le statut.

alter table public.content_proposals
  add column target_id integer check (target_id is null or target_id > 0);

create index content_proposals_target_idx
  on public.content_proposals (content_type, target_id)
  where target_id is not null;

comment on column public.content_proposals.target_id is
  'Identifiant de l''élément de référence dont la proposition est une modification (table selon content_type) ; null pour un nouveau contenu.';
