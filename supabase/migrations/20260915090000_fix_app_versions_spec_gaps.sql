-- Correctif d'écart de spec sur public.app_versions, créée hier dans
-- 20260914090000_create_app_versions.sql. Cette dernière n'avait pas été
-- confrontée à la spec déjà écrite dans
-- docs/cahier-des-charges/13-depot-versioning-publication.md (section 3.3,
-- dépôt mobile) avant d'être écrite, ce qui a introduit trois écarts :
--
-- 1. Nom de colonne : la spec documente `min_supported_version`, la
--    migration précédente avait créé `minimum_supported_version`.
-- 2. Colonne manquante : la spec prévoit `store_url` (lien direct vers la
--    fiche store, `itms-apps://...` pour iOS, `market://details?id=...`
--    pour Android) — absente jusqu'ici, ce qui avait forcé le client
--    Flutter à reconstruire ces URLs lui-même de façon approximative.
-- 3. RLS trop restrictive : la spec est explicite ("lecture publique, y
--    compris non authentifié, puisque ce contrôle a lieu avant/pendant la
--    connexion"). La policy précédente limitait la lecture à
--    `authenticated`, ce qui rend le contrôle de version inopérant tant
--    que l'utilisateur n'est pas connecté (AppBootstrap l'appelle dès la
--    fin de l'initialisation Supabase, potentiellement avant connexion) —
--    la vérification échoue silencieusement et retombe sur un statut "à
--    jour" par défaut côté client, sans trace en prod.
--
-- On corrige par ALTER plutôt que de réécrire la migration du 14/09 (déjà
-- poussée sur main) pour ne jamais réécrire un historique de migrations
-- déjà appliqué en distant.

-- 1. Renommage de colonne.
alter table public.app_versions
  rename column minimum_supported_version to min_supported_version;

-- 2. Colonne manquante, nullable : l'app n'est pas encore publiée sur les
-- stores, il n'existe donc aucune vraie URL à ce jour (même remarque sur
-- la neutralité des valeurs seedées que dans la migration précédente :
-- ces valeurs devront être mises à jour à la main après une vraie
-- publication, pas de contrainte NOT NULL qui obligerait à seeder une
-- valeur bidon en attendant).
alter table public.app_versions
  add column store_url text;

comment on column public.app_versions.store_url is
  'Lien direct vers la fiche store (itms-apps:// pour iOS, market://details?id=... pour Android). Nullable tant que l''app n''est pas publiée ; à renseigner manuellement après la première soumission.';

-- 3. RLS : remplacement de la policy SELECT authenticated-only par une
-- lecture vraiment publique (anon + authenticated), conformément à la
-- spec. Les policies INSERT/UPDATE/DELETE (réservées à public.is_admin())
-- restent inchangées.
drop policy "Authenticated users can read app_versions" on public.app_versions;

create policy "Anyone can read app_versions"
  on public.app_versions for select
  to anon, authenticated
  using (true);

comment on table public.app_versions is
  'Source de vérité distante pour les écrans "Mise à jour obligatoire"/"Mise à jour suggérée" de l''app mobile Personnages. Une ligne par plateforme (android/ios). Lecture publique (anon + authenticated, y compris avant connexion) ; écriture admin uniquement.';

-- 4. Seed store_url pour les 2 lignes existantes : pas de vraie valeur
-- disponible, laissé à NULL plutôt qu'une URL bidon.
update public.app_versions
set store_url = null
where platform in ('android', 'ios');
