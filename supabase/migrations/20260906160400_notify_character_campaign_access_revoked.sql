-- Chantier "Notifications push/email" (app mobile "Personnages") —
-- 15-profil-parametres.md section 3 (déclencheur "le MJ retire l'accès"),
-- 12-partage-et-groupes.md pour le contexte MJ/histoire.
--
-- IMPORTANT — touche à la synchronisation avec l'app "Histoires"
-- (character_campaigns, alimentée par le futur panneau "Joueurs" côté web,
-- voir 12-partage-et-groupes.md section 5.6) : ne pas merger sans
-- coordination avec l'équipe qui maintient apps/ (Next.js), même si cette
-- migration n'ajoute qu'un trigger de lecture/notification et ne modifie
-- aucune donnée lue/écrite par le web.
--
-- Notifie le propriétaire d'un personnage quand son rattachement à une
-- histoire (character_campaigns) est supprimé par quelqu'un d'autre que
-- lui-même — c'est-à-dire quand c'est le MJ qui retire l'accès, pas quand le
-- joueur quitte lui-même l'histoire (dans ce dernier cas, il est déjà au
-- courant de son propre geste, rien à notifier).
--
-- `auth.uid()` est résolu ici dans le contexte de la requête qui a exécuté
-- le DELETE (le GUC `request.jwt.claims` posé par PostgREST/l'edge function
-- appelante reste valide à l'intérieur du trigger, SECURITY DEFINER ou non —
-- SECURITY DEFINER ne change que les droits d'accès aux tables, pas
-- l'identité de session pour auth.uid()).
create or replace function public.notify_character_campaign_access_revoked()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_character_name text;
  v_story_title text;
  v_push_enabled boolean;
  v_push_access_revoked boolean;
begin
  select owner_id, name into v_owner_id, v_character_name
  from public.characters
  where id = old.character_id;

  -- Personnage introuvable (ex. supprimé dans la même transaction par un
  -- ON DELETE CASCADE) : pas de destinataire résolvable, rien à notifier.
  if v_owner_id is null then
    return old;
  end if;

  -- Le joueur qui a lui-même quitté l'histoire (DELETE fait avec son propre
  -- JWT) n'a rien à se faire notifier. `IS NOT DISTINCT FROM` gère aussi le
  -- cas auth.uid() = null (DELETE fait hors contexte de requête HTTP, ex.
  -- console SQL admin) sans planter sur une comparaison à null.
  if auth.uid() is not distinct from v_owner_id then
    return old;
  end if;

  select title into v_story_title
  from public.stories
  where id = old.story_id;

  select push_enabled, push_access_revoked
  into v_push_enabled, v_push_access_revoked
  from public.notification_preferences
  where user_id = v_owner_id;

  -- Absence de ligne == valeurs par défaut (true, true) — convention établie
  -- par 20260906155351_create_notification_infrastructure.sql.
  if not (coalesce(v_push_enabled, true) and coalesce(v_push_access_revoked, true)) then
    return old;
  end if;

  perform private.invoke_edge_function(
    'send-push-notification',
    jsonb_build_object(
      'userId', v_owner_id,
      'title', 'Accès retiré',
      'body', format(
        'Le MJ a retiré %s de %s.',
        coalesce(nullif(v_character_name, ''), 'votre personnage'),
        coalesce(v_story_title, 'l''histoire')
      ),
      'data', jsonb_build_object(
        'type', 'access_revoked',
        'storyId', old.story_id,
        'characterId', old.character_id
      )
    )
  );

  return old;
exception when others then
  -- Ne jamais faire échouer le DELETE (le retrait d'accès lui-même) à cause
  -- d'un problème côté notification.
  raise warning 'notify_character_campaign_access_revoked: erreur (%): %', sqlstate, sqlerrm;
  return old;
end;
$$;

comment on function public.notify_character_campaign_access_revoked() is
  'Trigger AFTER DELETE ON character_campaigns : notifie (push) le propriétaire du personnage quand le rattachement est supprimé par quelqu''un d''autre que lui (le MJ), sous réserve de notification_preferences.push_enabled/push_access_revoked. Ne fait rien si le joueur a lui-même quitté l''histoire.';

create trigger character_campaigns_notify_access_revoked
after delete on public.character_campaigns
for each row
execute function public.notify_character_campaign_access_revoked();
