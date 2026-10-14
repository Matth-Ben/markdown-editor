-- Chantier "Notifications push/email" (app mobile "Personnages") —
-- `docs/cahier-des-charges/15-profil-parametres.md` section 3, complété par
-- la préférence `push_new_version_available` ajoutée dans
-- 20261014090000_add_notification_push_new_version_available.sql.
--
-- Portée : app mobile uniquement. Ne touche à aucune table de la
-- synchronisation "Histoires" (`stories`, `codex_entries`,
-- `character_campaigns`) — contrairement à
-- 20260906160400_notify_character_campaign_access_revoked.sql, cette
-- migration ne nécessite PAS de coordination avec l'équipe web avant merge.
--
-- POURQUOI CE TRIGGER EST POSÉ SUR `app_versions` ET PAS DÉCLENCHÉ DEPUIS LA
-- CI MOBILE : la CI mobile (voir `13-depot-versioning-publication.md`)
-- produit un artefact (APK/AAB) qu'il faut encore téléverser À LA MAIN sur
-- la Play Console (et, plus tard, App Store Connect) avant qu'il soit
-- réellement installable par un utilisateur — la fin d'un run CI ne
-- correspond donc à aucune disponibilité réelle. `public.app_versions.
-- latest_version` est en revanche mis à jour manuellement par un admin
-- (policy "Admins can update app_versions",
-- 20260914090000_create_app_versions.sql) précisément au moment où la
-- nouvelle version est publiée sur le store et donc réellement disponible
-- pour l'utilisateur — c'est le seul signal fiable, et c'est aussi le signal
-- déjà lu par l'écran mobile (`AppVersionCheckResult`) pour sa bannière
-- "Nouvelle version disponible". Notifier sur ce changement-là, plutôt que
-- depuis la CI, garantit qu'on ne notifie jamais une version que
-- l'utilisateur ne peut pas encore installer.
--
-- Déclenchement : AFTER INSERT OR UPDATE OF latest_version, FOR EACH ROW.
-- `UPDATE OF latest_version` filtre déjà les UPDATE qui ne touchent pas
-- cette colonne (ex. un admin qui ne change que `min_supported_version` ou
-- `store_url`), mais pas un UPDATE qui réécrit la même valeur (SET
-- latest_version = latest_version, ou un upsert applicatif qui renvoie
-- toujours toutes les colonnes) — d'où le garde `old.latest_version is not
-- distinct from new.latest_version` au tout début du corps, qui couvre
-- aussi le cas où `latest_version` passerait de non-null à null ou
-- inversement sans planter sur une comparaison à null (IS NOT DISTINCT
-- FROM), même motif que `notify_character_campaign_access_revoked`.
--
-- Destinataires : TOUS les utilisateurs (`auth.users`), sans filtrage par
-- plateforme — `new.platform` ne décrit que la ligne `app_versions`
-- modifiée (ex. "android"), pas l'appareil de chaque destinataire ; comme
-- `send-push-notification` envoie déjà à tous les tokens enregistrés d'un
-- `userId` sans distinguer leur plateforme, et qu'iOS n'est pas encore
-- publié (aucun utilisateur n'a de token iOS à ce jour), il n'y a
-- actuellement aucune raison de filtrer les destinataires par plateforme —
-- à revisiter si/quand Android et iOS publient des versions à des rythmes
-- différents. Un utilisateur sans ligne `notification_preferences` est
-- traité comme s'il avait les valeurs par défaut (`push_enabled = true`,
-- `push_new_version_available = true`), même convention que
-- `notify_character_campaign_access_revoked`.
--
-- Volumétrie : une notification par changement de `latest_version`, une
-- invocation HTTP asynchrone (`pg_net`) par utilisateur éligible — acceptable
-- à l'échelle actuelle du projet (peuplement Phase 1-5, pas encore
-- d'utilisateurs en volume) ; à revisiter (ex. edge function dédiée qui
-- paginerait les destinataires) si la base d'utilisateurs grossit
-- significativement avant la prochaine mise à jour de ce trigger.
create or replace function public.notify_new_app_version()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient record;
begin
  if tg_op = 'UPDATE' and old.latest_version is not distinct from new.latest_version then
    return new;
  end if;

  for v_recipient in
    select u.id as user_id
    from auth.users u
    left join public.notification_preferences np on np.user_id = u.id
    where coalesce(np.push_enabled, true)
      and coalesce(np.push_new_version_available, true)
  loop
    perform private.invoke_edge_function(
      'send-push-notification',
      jsonb_build_object(
        'userId', v_recipient.user_id,
        'title', 'Nouvelle version disponible',
        'body', 'Une nouvelle version de Nexus JDR est disponible — mets-la à jour pour profiter des dernières améliorations.',
        'data', jsonb_build_object(
          'type', 'new_version',
          'platform', new.platform,
          'version', new.latest_version
        )
      )
    );
  end loop;

  return new;
exception when others then
  -- Ne jamais faire échouer l'INSERT/UPDATE sur app_versions (le geste de
  -- l'admin qui publie la version) à cause d'un problème côté notification —
  -- même philosophie que notify_character_campaign_access_revoked.
  raise warning 'notify_new_app_version: erreur (%): %', sqlstate, sqlerrm;
  return new;
end;
$$;

comment on function public.notify_new_app_version() is
  'Trigger AFTER INSERT OR UPDATE OF latest_version ON app_versions : notifie (push) tous les utilisateurs éligibles (notification_preferences.push_enabled/push_new_version_available, défaut true si absent de ligne) qu''une nouvelle version de l''app mobile est disponible. Ne fait rien sur UPDATE si latest_version n''a pas réellement changé.';

create trigger app_versions_notify_new_version
after insert or update of latest_version on public.app_versions
for each row
execute function public.notify_new_app_version();
