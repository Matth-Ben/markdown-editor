-- Distingue les brouillons (créés en cliquant sur « Nouveau », pas encore visibles dans la
-- Bibliothèque) des histoires publiées. Les histoires existantes sont considérées publiées ;
-- le défaut de colonne passe ensuite à false pour les nouvelles insertions.
alter table public.stories
  add column published boolean not null default true;

alter table public.stories
  alter column published set default false;
