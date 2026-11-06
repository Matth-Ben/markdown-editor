-- F03 : vue d'ensemble multi-groupes pour un MJ (docs/retours-utilisateurs.md,
-- dépôt nexus-jdr-app-mobile, proposition validée par Matthias).
--
-- Besoin : group_list_screen.dart (app mobile) veut afficher, pour chaque
-- groupe dont l'utilisateur connecté est membre, un indicateur de statut
-- prioritaire ("1 mort", "2 PV bas"...) sans payer le coût d'un N+1 --
-- avis de faisabilité qa-testeur (même document) : fetchGroupDetail (seul
-- outil client existant pour obtenir les PV d'un groupe) coûte déjà ~6
-- aller-retours réseau par groupe. Vue d'agrégation SQL plutôt qu'un calcul
-- client, comme convergent dev-backend-supabase et qa-testeur dans ce même
-- avis.
--
-- Règle de "PV bas" retenue ici (aucune règle officielle dans le cahier des
-- charges -- à documenter explicitement plutôt que la laisser implicite) :
-- un personnage vivant (is_dead = false) dont 0 < current_hp <= 25% de
-- max_hp, et max_hp > 0 (exclut une fiche non terminée dont max_hp vaudrait
-- encore 0, pour éviter un faux "PV bas" par comparaison dégénérée). Un
-- personnage à current_hp = 0 est déjà compté dans dead_count seulement si
-- is_dead est vrai -- voir 20260906183956_add_characters_is_dead.sql : le
-- client mobile pose is_dead au moment où current_hp atteint 0, cette vue
-- ne le recalcule pas elle-même, elle lit la colonne telle quelle.
--
-- *** GARDE-FOU DE SÉCURITÉ IMPÉRATIF, NE JAMAIS RETIRER SANS Y REPENSER ***
-- Cette vue DOIT rester `security_invoker = true`. Sans ce flag, une vue
-- s'exécute avec les droits de son PROPRIÉTAIRE (le rôle migrateur,
-- qui contourne de fait la RLS) et non ceux de l'appelant réel -- un MJ
-- pourrait alors voir les groupes et personnages d'un MJ tiers, en clair une
-- fuite de données entre MJ (signalé explicitement par l'avis de
-- faisabilité dev-backend-supabase de F03). Le flag force Postgres à
-- appliquer les policies RLS de group_members/characters avec le rôle de
-- l'appelant (auth.uid() réel), exactement comme s'il interrogeait ces
-- tables directement via PostgREST. Si cette vue est un jour DROP puis
-- recréée (ex. migration de schéma future), le flag doit être reposé
-- EXPLICITEMENT -- il ne se propage jamais automatiquement d'un simple
-- `create or replace view`, et PostgreSQL revient silencieusement à
-- `security_invoker = false` (comportement historique) si l'option est
-- omise.
--
-- Pourquoi les comptages restent corrects malgré ce flag (donc malgré la
-- RLS réelle de l'appelant) : group_members expose déjà, à TOUT membre d'un
-- groupe, TOUTES les lignes group_members de ce groupe -- pas seulement sa
-- propre ligne (policy "Member can select members of their groups",
-- 20260906182601_create_groups.sql, via public.is_group_member). characters
-- expose à son tour, à tout membre d'un groupe, la fiche de ses coéquipiers
-- du MÊME groupe (policy "Group member can select teammates' characters",
-- 20260906190500_group_member_can_read_characters.sql, via public.
-- group_member_can_read_character). Le LEFT JOIN ci-dessous ne peut donc
-- jamais remonter la ligne d'un groupe dont l'appelant n'est pas membre, ni
-- la fiche d'un personnage hors de ce groupe -- la RLS de l'appelant, seule
-- active grâce à security_invoker, suffit à elle seule à délimiter
-- exactement le même périmètre que "mes groupes".
--
-- LEFT JOIN (pas INNER JOIN) délibéré : un groupe dont tous les membres
-- sont des MJ volontaires/orphelins sans personnage (character_id null)
-- doit malgré tout apparaître dans le résultat, avec dead_count = 0 et
-- low_hp_count = 0, plutôt que d'être silencieusement absent.
create view public.group_character_status_overview
with (security_invoker = true) as
select
  gm.group_id,
  count(*) filter (where c.is_dead) as dead_count,
  count(*) filter (
    where c.id is not null
      and not c.is_dead
      and c.max_hp > 0
      and c.current_hp > 0
      and c.current_hp <= c.max_hp * 0.25
  ) as low_hp_count
from public.group_members gm
left join public.characters c on c.id = gm.character_id
group by gm.group_id;

comment on view public.group_character_status_overview is
  'F03 (docs/retours-utilisateurs.md, dépôt nexus-jdr-app-mobile) : une ligne par groupe dont l''appelant est membre (owner ou membre), avec dead_count (personnages is_dead) et low_hp_count (personnages vivants avec 0 < current_hp <= 25% de max_hp, max_hp > 0). Exclut des deux compteurs les membres sans personnage (MJ volontaire ou orphelin, character_id null) -- ils comptent dans aucune des deux colonnes, jamais en erreur. *** security_invoker = true est un garde-fou de sécurité impératif : voir le commentaire complet de la migration qui crée cette vue (20261106100000_create_group_character_status_overview.sql) avant de la DROP/recréer sans ce flag -- son absence ferait fuiter les groupes et personnages d''un MJ tiers vers l''appelant. ***';

grant select on table public.group_character_status_overview to authenticated;
