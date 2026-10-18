-- Chantier "Personnages" (app mobile) — variantes de sorts de sous-classe.
--
-- `subclass_spells` n'a aujourd'hui aucune colonne pour distinguer plusieurs
-- variantes d'une même sous-classe à un même niveau (ex. Druide, Cercle de la
-- Terre : 8 terrains possibles — Arctique/Côte/Désert/Forêt/Plaine/Montagne/
-- Marais/Outreterre —, chacun avec sa propre liste de sorts toujours
-- préparés aux niveaux 3/5/7/9). Ajoute `option_key`, une clé texte
-- optionnelle, dans le même esprit que `class_features.choice_type` : NULL
-- pour toute ligne sans variante (tout le contenu actuel), une valeur courte
-- et stable (ex. 'arctique', 'cote', 'desert', 'foret', 'plaine', 'montagne',
-- 'marais', 'outreterre') pour les lignes qui en ont besoin.
--
-- Plusieurs terrains du Cercle de la Terre partagent le même sort au même
-- niveau pour le même subclass_id (ex. "Liberté de mouvement" niv.7 pour
-- Arctique/Côte/Forêt/Plaine) : la clé primaire actuelle (subclass_id,
-- spell_id) empêcherait ces lignes coexister. On la remplace donc par un id
-- de substitution, et on recrée l'invariant d'unicité via un index unique
-- qui inclut `option_key` (en normalisant NULL pour continuer à empêcher les
-- doublons involontaires sur les lignes sans variante, où NULL se comporte
-- comme une valeur unique parmi toutes les lignes NULL de ce subclass_id/
-- spell_id, pas comme une valeur toujours distincte des autres NULL comme le
-- ferait une contrainte UNIQUE standard sur une colonne nullable).
--
-- Aucune ligne existante n'est modifiée : `option_key` vaut NULL partout
-- tant qu'aucun INSERT ne le renseigne explicitement.

alter table public.subclass_spells
  add column option_key text;

comment on column public.subclass_spells.option_key is
  'Clé optionnelle distinguant les variantes d''une même sous-classe à un '
  'même niveau de sort (ex. terrain du Cercle de la Terre : ''arctique'', '
  '''cote'', ''desert'', ''foret'', ''plaine'', ''montagne'', ''marais'', '
  '''outreterre''). NULL pour les sous-classes sans variante — même esprit '
  'que class_features.choice_type.';

alter table public.subclass_spells
  drop constraint subclass_spells_pkey;

alter table public.subclass_spells
  add column id bigint generated always as identity;

alter table public.subclass_spells
  add constraint subclass_spells_pkey primary key (id);

create unique index subclass_spells_subclass_spell_option_key_key
  on public.subclass_spells (subclass_id, spell_id, coalesce(option_key, ''));
