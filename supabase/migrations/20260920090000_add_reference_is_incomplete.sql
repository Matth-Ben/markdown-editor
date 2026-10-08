-- Dette technique D58 (voir docs/dette-technique.md, dépôt mobile) : la colonne
-- `is_incomplete` sur `spells`, `races` et `backgrounds` est utilisée par des migrations
-- à partir du 21/09 (`20260921090000_fix_spells_metadata_add_2024_spells.sql` et
-- suivantes) mais aucune migration ne la créait : elle n'existait que sur le projet
-- Supabase distant, ajoutée hors migration à un moment donné (vraisemblablement par
-- l'approbation d'une proposition de contenu incomplète, ou par l'import XML aidedd
-- pour les sorts placeholder). `supabase db reset` échouait dès ce fichier avec
-- `column ... is_incomplete does not exist`.
--
-- Chaque ligne existante est réputée complète (`false`) : les lignes "placeholder"
-- (ex. sorts « vague tonnante »/« communication avec les animaux », race « Nain des
-- collines », historique « Grand voyageur » id 16) n'existent que sur le distant,
-- créées hors migration — elles n'existent pas dans une base rejouée depuis zéro, donc
-- rien à marquer `true` ici. Les migrations qui les complètent ou les suppriment
-- (20260921090000, 20260922110000, 20260929110000, 20260930110000,
-- 20260930140000) continuent de fonctionner sans erreur sur un `db reset` local : elles
-- ne trouvent simplement aucune ligne `is_incomplete` à traiter et n'ont pas d'effet sur
-- ce point précis.

alter table public.spells
  add column if not exists is_incomplete boolean not null default false;

alter table public.races
  add column if not exists is_incomplete boolean not null default false;

alter table public.backgrounds
  add column if not exists is_incomplete boolean not null default false;

comment on column public.spells.is_incomplete is
  'Vrai pour une fiche placeholder (nom/école minimal, le reste à compléter) créée par import ou proposition de contenu approuvée ; faux une fois la fiche complétée.';
comment on column public.races.is_incomplete is
  'Vrai pour une fiche placeholder créée par import ou proposition de contenu approuvée ; faux une fois la fiche complétée.';
comment on column public.backgrounds.is_incomplete is
  'Vrai pour une fiche placeholder créée par import ou proposition de contenu approuvée ; faux une fois la fiche complétée.';
