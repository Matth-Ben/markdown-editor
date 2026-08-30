-- Chantier "Personnages" (app mobile) — Phase 4 — préalable côté web.
-- Complète 20260830100100_create_character_campaigns.sql : trou de RLS
-- signalé par dev-flutter (vérifié empiriquement contre le stack local en
-- implémentant la carte "Aventures" de l'onglet "Personnage", voir
-- 04-fonctionnalites-app-mobile.md section 7.2 côté dépôt mobile) — seule la
-- policy symétrique existait (le MJ propriétaire de l'histoire peut lire les
-- personnages rattachés, via story_owner_can_read_character), pas
-- l'inverse : un joueur qui a rejoint une histoire ne pouvait pas lire la
-- ligne `stories` correspondante pour en afficher le titre/la couverture,
-- alors que c'est justement le cas d'usage principal de cette carte (le
-- joueur consultant ses propres histoires rejointes). PostgREST renvoyait
-- `stories: null` sur l'embed `character_campaigns(...stories(...))`, que le
-- mapper mobile (`character_detail_row_mapper.dart::parseAdventures`)
-- omettait silencieusement plutôt que d'planter — dégradation propre, mais
-- la fonctionnalité ne marchait pas réellement.

-- Helper security-definer, même style et même fichier d'origine que
-- public.story_owner_can_read_character (20260830100100_create_character_campaigns.sql),
-- dans l'autre sens : vrai si p_story_id est une histoire à laquelle un
-- personnage possédé par auth.uid() est rattaché via character_campaigns.
create or replace function public.character_owner_can_read_joined_story(p_story_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.character_campaigns cc
    join public.characters c on c.id = cc.character_id
    where cc.story_id = p_story_id
      and c.owner_id = auth.uid()
  );
$$;

grant execute on function public.character_owner_can_read_joined_story(uuid) to authenticated;

comment on function public.character_owner_can_read_joined_story(uuid) is
  'Retourne vrai si p_story_id est une histoire à laquelle un personnage possédé par auth.uid() est rattaché (via character_campaigns). Donne au joueur un accès lecture seule à la ligne stories de chaque histoire qu''il a rejointe (carte "Aventures" côté mobile, 04-fonctionnalites-app-mobile.md section 7.2).';

-- S'ajoute à "Users can view their own stories" (20260716212008_create_stories.sql) :
-- plusieurs policies "for select" sur une même table se combinent en OR en
-- PostgreSQL, donc ceci ne remplace ni ne restreint rien d'existant pour le
-- propriétaire de l'histoire.
create policy "Character owner can select joined stories"
  on public.stories for select
  to authenticated
  using (public.character_owner_can_read_joined_story(id));

-- Note de sécurité (arbitrage documenté, pas un oubli) : cette policy est
-- une policy RLS standard, donc au niveau de la LIGNE — un joueur rattaché
-- obtient techniquement accès à la ligne stories complète, y compris
-- invite_code/invite_code_enabled (jamais exposés à un client par une autre
-- policy select, voir 20260830100000_add_stories_invite_code.sql), pas
-- seulement à title/cover_image_path.
--
-- Alternatives écartées pour ce correctif ciblé/isolé (faible risque
-- demandé) :
-- - Une vue restreinte aux colonnes sûres (title, cover_image_path) : pas de
--   précédent dans ce dépôt (aucune vue dans supabase/migrations/ à ce
--   jour), et casserait l'embed PostgREST déjà implémenté et testé côté
--   mobile (`character_campaigns(id, story_id, stories(title,
--   cover_image_path))`, qui résout `stories` par la relation de clé
--   étrangère réelle character_campaigns.story_id -> stories.id — un nom de
--   relation différent ne serait plus auto-embarqué sans changement côté
--   client mobile).
-- - Des privilèges de colonne (GRANT SELECT (title, cover_image_path) ...)
--   ne fonctionnent pas ici : un seul rôle Postgres `authenticated` sert à
--   la fois le MJ propriétaire (qui a besoin de tout lire, y compris
--   invite_code, pour le futur panneau "Joueurs" web) et le joueur rattaché
--   — un GRANT de colonne s'applique au rôle entier, pas par policy/ligne,
--   il ne peut donc pas autoriser l'un sans l'autre.
--
-- Risque accepté en l'état, mais à ne PAS lire comme "aucun risque" — deux
-- cas bien distincts (revue code-reviewer du 30/08/2026) :
-- 1. Le code que ce joueur a lui-même utilisé pour rejoindre : sans enjeu,
--    il le connaissait déjà par construction (12-partage-et-groupes.md
--    section 5.3, flux "Le joueur ouvre le lien").
-- 2. Un code RÉGÉNÉRÉ par le MJ *après* que ce joueur a rejoint, pendant
--    qu'il reste rattaché : ce cas a un enjeu réel. Cette policy le laisse
--    lire le nouveau code courant via une requête PostgREST manuelle
--    (`select invite_code from stories where id = ...`, jamais fait par le
--    code mobile actuel, mais pas empêché par la base). Or
--    12-partage-et-groupes.md section 5.4 précise que la régénération sert
--    justement à couper l'accès aux détenteurs de l'ancien code — un MJ qui
--    régénère pour se débarrasser d'un joueur suspect sans l'exclure
--    explicitement (`character_campaigns` intact) verrait cette policy
--    annuler une partie de l'intérêt de la régénération pour CE joueur
--    précis, puisqu'il resterait rattaché et pourrait relire le code neuf.
--    Le seul rempart réel contre ce cas reste le retrait explicite du
--    rattachement ("Retirer ce joueur", section 5.4) : la régénération
--    seule ne suffit plus à isoler un joueur toujours rattaché.
--
-- Accepté malgré tout pour ce correctif ciblé/isolé (faible risque demandé)
-- parce que le code mobile actuel ne lit jamais ces colonnes et que le
-- contournement décrit ci-dessus nécessite une requête manuelle délibérée,
-- pas un chemin emprunté par l'app. Si une traçabilité/isolation plus
-- stricte des invitations devient nécessaire, la normalisation propre
-- serait de sortir invite_code/invite_code_enabled de `stories` vers une
-- table dédiée (RLS MJ uniquement) — hors périmètre de ce correctif ciblé,
-- à remonter en backlog si besoin. Verrouillé par un test qui épingle
-- explicitement ce compromis (supabase/tests/stories_joined_player_select_test.sql,
-- assertion sur invite_code) plutôt que par la seule documentation : toute
-- dérive future (resserrement accidentel ou élargissement supplémentaire)
-- doit faire échouer ce test.
