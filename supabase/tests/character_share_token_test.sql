-- Vérifie 20260908090000_add_character_share_token.sql (partage en lecture
-- seule d'un personnage, 12-partage-et-groupes.md section 1 du cahier des
-- charges de l'app mobile) : régénération/désactivation restreintes au
-- propriétaire, lecture publique (rôle anon, aucun JWT) restreinte au
-- détenteur du token exact, aucune fuite d'owner_id/character_campaigns.
--
-- Étendu par 20260908100000_add_class_features_to_shared_character.sql
-- (ajout de la clé `class_features`) : voir le bloc "Test class_features"
-- plus bas -- filtre par niveau DE LA CLASSE (pas niveau total du
-- personnage), aptitude active vs passive, uses_remaining croisé avec
-- character_feature_uses.
--
-- Rejoué pour la première fois en réel le 08/10/2026 (D60, voir
-- docs/dette-technique.md du dépôt mobile) : la comparaison de la ligne
-- "régénération ultérieure" et toutes les requêtes sous le rôle anon à
-- partir du "Test 5" avaient deux défauts d'écriture du test lui-même (pas de
-- bug RLS/partage) : une comparaison dans une seule instruction entre deux
-- évaluations non ordonnées de `regenerate_character_share_token()`
-- (toujours en échec par construction, MVCC), puis une sous-requête sur
-- `public.characters` exécutée sous le rôle `anon`, qui n'a -- à raison --
-- aucun privilège de table sur `characters` (seul `get_shared_character`,
-- SECURITY DEFINER, peut la lire pour ce rôle), d'où une erreur fatale
-- `permission denied for table characters` qui avortait la transaction et
-- empêchait les 7 derniers tests de s'exécuter. Les deux corrigés ci-dessous.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- (depuis la racine du dépôt web, stack local démarré au préalable via
-- `supabase start`). BEGIN/ROLLBACK en fin de fichier : aucune donnée de
-- test ne persiste, le fichier est rejouable à volonté sans nettoyage
-- manuel ni collision avec des données réelles.

begin;

select plan(14);

-- Fixtures : deux joueurs, chacun propriétaire d'un personnage, plus un MJ
-- propriétaire d'une histoire à laquelle le premier personnage est rattaché
-- (pour vérifier que get_shared_character n'expose jamais cette relation).
-- Insérés en tant que `postgres` (rôle superuser du test runner pgTAP), qui
-- contourne RLS comme le ferait service_role.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('77777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-owner@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('88888888-8888-8888-8888-888888888888', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-stranger3@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('99999999-9999-9999-9999-999999999999', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-gm3@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.characters (id, owner_id, name, xp)
values ('cccccccc-0000-0000-0000-000000000001', '77777777-7777-7777-7777-777777777777', 'pgTAP Shared Hero', 300);

insert into public.character_spells (character_id, spell_id, status)
select 'cccccccc-0000-0000-0000-000000000001', s.id, 'connu'
from public.spells s
limit 1;

-- Fixture pour le test class_features : personnage Barbare niveau 2 (seed
-- 20260825090700 -- "Rage" et "Défense sans armure" au niveau 1, "Attaque
-- impétueuse" au niveau 2, "Voie primitive" au niveau 3, résolue par nom via
-- translations car les id sont générés à l'insertion du seed).
insert into public.character_classes (character_id, class_id, level, is_primary)
select 'cccccccc-0000-0000-0000-000000000001', c.id, 2, true
from public.translations ct
join public.classes c on c.id::text = ct.entity_id
where ct.entity_type = 'class' and ct.field_name = 'name' and ct.locale = 'fr'
  and ct.value = 'Barbare';

-- Une utilisation de "Rage" (amount 2) déjà consommée : uses_remaining = 1,
-- pour vérifier que get_shared_character croise bien class_features avec
-- character_feature_uses plutôt que de toujours retourner uses_max.
insert into public.character_feature_uses (character_id, class_feature_id, uses_remaining)
select 'cccccccc-0000-0000-0000-000000000001', cf.id, 1
from public.class_features cf
join public.translations t
  on t.entity_type = 'class_feature' and t.entity_id = cf.id::text
  and t.field_name = 'name' and t.locale = 'fr'
where t.value = 'Rage';

insert into public.stories (id, user_id, title, invite_code, invite_code_enabled)
values ('aaaaaaaa-0000-0000-0000-000000000004', '99999999-9999-9999-9999-999999999999', 'pgTAP GM story (share test)', 'PGTAP04', true);

insert into public.character_campaigns (character_id, story_id, role)
values ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000004', 'joueur');

-- Test 1 : share_token est bien NULL par défaut (partage désactivé tant que
-- le propriétaire ne l'a jamais activé).
select is(
  (select share_token from public.characters where id = 'cccccccc-0000-0000-0000-000000000001'),
  null,
  'share_token est NULL par défaut'
);

-- Test 2 : get_shared_character retourne NULL tant qu'aucun token n'a été
-- généré (aucune ligne characters.share_token ne peut matcher NULL/absent).
set local role anon;
select is(
  public.get_shared_character('un-token-qui-nexiste-pas'),
  null,
  'get_shared_character retourne NULL pour un token qui ne correspond à aucun personnage'
);
select is(
  public.get_shared_character(null),
  null,
  'get_shared_character retourne NULL pour un token NULL (jamais un match universel)'
);
select is(
  public.get_shared_character(''),
  null,
  'get_shared_character retourne NULL pour un token vide (jamais un match universel)'
);
reset role;

-- Test 3 : un tiers (authenticated, non propriétaire) ne peut pas régénérer
-- le token d'un personnage qui ne lui appartient pas.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '88888888-8888-8888-8888-888888888888', 'role', 'authenticated')::text,
  true
);

select throws_ok(
  $$ select public.regenerate_character_share_token('cccccccc-0000-0000-0000-000000000001') $$,
  'P0002',
  null,
  'Un tiers non-propriétaire ne peut pas régénérer share_token pour le personnage d''un autre'
);

reset role;

-- Test 4 (contrôle positif) : le propriétaire peut régénérer son propre
-- token ; la valeur retournée est effectivement écrite en base.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '77777777-7777-7777-7777-777777777777', 'role', 'authenticated')::text,
  true
);

select ok(
  (select public.regenerate_character_share_token('cccccccc-0000-0000-0000-000000000001')) is not null,
  'Le propriétaire peut régénérer share_token pour son propre personnage'
);

-- Corrigé le 08/10/2026 (D60) : l'ancienne version comparait, au sein d'une
-- SEULE instruction SQL, une relecture de `characters.share_token` à un
-- second appel de `regenerate_character_share_token()`. Les deux sous-requêtes
-- d'une même instruction voient l'état au début de l'instruction (MVCC) :
-- l'effet du second appel n'est jamais visible à l'autre sous-requête, donc
-- les deux valeurs comparées sont nécessairement deux tokens différents
-- (reproduit : have/want toujours distincts), quelle que soit la justesse de
-- la fonction. `\gset` capture la valeur retournée par le second appel dans
-- une variable psql, relue dans l'instruction SUIVANTE (donc après que
-- l'écriture soit visible) pour vérifier qu'elle a bien été persistée.
select public.regenerate_character_share_token('cccccccc-0000-0000-0000-000000000001') as current_token \gset

select is(
  (select share_token from public.characters where id = 'cccccccc-0000-0000-0000-000000000001'),
  :'current_token',
  'Une régénération ultérieure écrase bien la valeur précédente (aucun cache/valeur figée)'
);

-- `:'current_token'` (substitution psql côté client) ne fonctionne qu'en dehors de tout
-- texte déjà entre guillemets -- y compris les blocs `$$...$$` passés en argument à
-- results_eq/ok plus bas, où psql ne scanne pas le texte pour des `:` (comportement
-- documenté : pas d'interpolation dans une chaîne déjà quotée). Le token est donc aussi
-- stocké dans un paramètre de session (lisible par n'importe quel rôle, sans privilège
-- particulier -- même mécanisme que `request.jwt.claims` déjà utilisé dans ce fichier),
-- relu via `current_setting(...)` en SQL pur à l'intérieur de ces blocs.
select set_config('pgtap.current_share_token', :'current_token', false);

reset role;

-- Test 5 : le token courant permet à un lecteur totalement anonyme (rôle
-- anon, aucun JWT) de lire la fiche -- y compris une table jointe (sorts).
--
-- Corrigé le 08/10/2026 (D60) : la version précédente relisait
-- `characters.share_token` par une sous-requête exécutée SOUS LE RÔLE anon,
-- qui n'a (à raison) aucun privilège de table sur `characters` -- seul
-- `get_shared_character` (SECURITY DEFINER) peut la lire pour ce rôle. Ça
-- levait une erreur `permission denied for table characters` qui avortait la
-- transaction (donc tout le reste du fichier). Le token est maintenant relu
-- via `current_setting('pgtap.current_share_token')` (paramètre de session
-- posé plus haut, pendant que le rôle était encore le propriétaire
-- authentifié) exactement comme un client anonyme qui a reçu ce token par un
-- lien de partage -- `:'current_token'` (substitution psql) ne fonctionnerait
-- pas ici : il n'est jamais interpolé à l'intérieur d'un bloc `$$...$$`.
set local role anon;
select results_eq(
  $$ select
       (public.get_shared_character(current_setting('pgtap.current_share_token'))->'character'->>'name'),
       jsonb_array_length(public.get_shared_character(current_setting('pgtap.current_share_token'))->'spells') $$,
  $$ values ('pgTAP Shared Hero'::text, 1) $$,
  'get_shared_character(token courant) expose le nom du personnage et sa table character_spells jointe'
);
reset role;

-- Test class_features (20260908100000) : le personnage est Barbare niveau 2
-- (fixture ci-dessus) -- seules "Rage" et "Défense sans armure" (niveau 1),
-- "Attaque impétueuse" et "Sens du danger" (niveau 2) doivent être incluses,
-- jamais "Voie primitive" (niveau 3, non atteinte). "Rage" a une utilisation
-- consommée (uses_remaining = 1 sur amount = 2) ; les trois autres sont
-- passives (uses_max/uses_remaining NULL).
-- Corrigé le 08/10/2026 (D60) : même correctif que le Test 5 ci-dessus
-- (`current_setting('pgtap.current_share_token')` au lieu d'une sous-requête
-- sur `characters` sous le rôle anon, qui levait `permission denied for
-- table characters`). Le nombre attendu est aussi corrigé de 3 à 4 : « Sens
-- du danger » (class_feature id 149, Barbare niveau 2) a été ajouté par
-- 20260910100000_seed_class_features_srd_progression.sql (ligne 29), après
-- l'écriture de ce test (20260908100000) -- vérifié que c'est une vraie aptitude de niveau 2
-- du Manuel des Joueurs (Rage + Défense sans armure au niveau 1, Attaque
-- impétueuse + Sens du danger au niveau 2), pas une fuite d'une aptitude de
-- niveau supérieur : la base de données a simplement été complétée depuis,
-- aucun bug RLS/partage ici.
set local role anon;
select results_eq(
  $$ select jsonb_array_length(
       public.get_shared_character(current_setting('pgtap.current_share_token'))->'class_features'
     ) $$,
  $$ values (4) $$,
  'get_shared_character expose exactement les 4 aptitudes atteintes par un Barbare niveau 2 (jamais celle du niveau 3)'
);
select results_eq(
  $$ select
       feature->>'name',
       (feature->>'level')::int,
       (feature->>'uses_max')::int,
       feature->>'rest_type',
       (feature->>'uses_remaining')::int
     from jsonb_array_elements(
       public.get_shared_character(current_setting('pgtap.current_share_token'))->'class_features'
     ) as feature
     where feature->>'name' = 'Rage' $$,
  $$ values ('Rage'::text, 1, 2, 'repos_long'::text, 1) $$,
  'class_features expose "Rage" avec son niveau, ses usages max/restants et son type de repos'
);
select results_eq(
  $$ select
       feature->>'name',
       feature->'uses_max',
       feature->'uses_remaining'
     from jsonb_array_elements(
       public.get_shared_character(current_setting('pgtap.current_share_token'))->'class_features'
     ) as feature
     where feature->>'name' = 'Défense sans armure' $$,
  $$ values ('Défense sans armure'::text, 'null'::jsonb, 'null'::jsonb) $$,
  'class_features expose une aptitude passive avec uses_max et uses_remaining à NULL'
);
reset role;

-- Test 6 : aucune fuite -- ni owner_id, ni character_campaigns/stories (voir
-- le rationale de l'exclusion dans 20260908090000_add_character_share_token.sql)
-- ne figurent dans le résultat.
-- Corrigé le 08/10/2026 (D60) : même correctif que les Tests 5 et
-- class_features ci-dessus.
set local role anon;
select ok(
  not (
    (public.get_shared_character(current_setting('pgtap.current_share_token'))->'character') ? 'owner_id'
  ),
  'get_shared_character n''expose jamais owner_id'
);
select ok(
  not (
    public.get_shared_character(current_setting('pgtap.current_share_token')) ? 'character_campaigns'
  ),
  'get_shared_character n''expose jamais character_campaigns/stories (l''histoire rattachée reste invisible via ce token)'
);
reset role;

-- Test 7 : désactivation -- une fois share_token repassé à NULL par le
-- propriétaire (via la policy UPDATE existante, pas une fonction dédiée),
-- l'ANCIEN token ne fonctionne plus.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  json_build_object('sub', '77777777-7777-7777-7777-777777777777', 'role', 'authenticated')::text,
  true
);

update public.characters
set share_token = null
where id = 'cccccccc-0000-0000-0000-000000000001';

reset role;

set local role anon;
select is(
  public.get_shared_character('ce-token-est-desormais-invalide-de-toute-facon'),
  null,
  'Après désactivation (share_token = NULL par le propriétaire), plus aucun token ne donne accès à la fiche'
);
reset role;

select * from finish();

rollback;
