-- Phase 0 « hygiène invisible » (étape 5/5) : `characters.updated_at` enfin tenu à jour.
--
-- POURQUOI (X02/N04 du diagnostic)
--   `characters.updated_at` (not null default now()) n'est jamais modifiée après la création : ni trigger,
--   ni client (grep updated_at dans lib/ : seule notification_preferences l'écrit). La colonne « ment »,
--   alors que la synchro incrémentale, l'audit et la détection de conflit des phases suivantes en ont besoin.
--
-- EFFET
--   Fonction générique `public.set_updated_at()` (réutilisable par d'autres tables) et trigger
--   `characters_set_updated_at` BEFORE UPDATE sur `characters` : `updated_at := now()` quand la ligne change
--   réellement (si l'UPDATE ne modifie aucune colonne, la valeur reste). Si un client envoie lui-même
--   `updated_at`, la valeur serveur l'emporte. Aucun contrat modifié : colonne, type et défaut identiques ;
--   seule la valeur cesse d'être figée. Les enfants (character_*) ne sont pas touchés (révision/`rev` : phase
--   ultérieure). La fonction n'est exécutable par aucun client (trigger seulement) et utilise
--   `search_path = public, pg_temp`.
--   Realtime : l'événement UPDATE de `characters` est émis comme avant (même nombre d'événements, même
--   filtre) ; le payload contient en plus la nouvelle `updated_at` (champ déjà présent dans la ligne).
--
-- RISQUE
--   Négligeable : un appel de fonction par UPDATE de `characters`. `create trigger` pose un verrou
--   SHARE ROW EXCLUSIVE bref (pas de réécriture de table). `lock_timeout` 10 s. Les lignes existantes ne
--   sont pas modifiées (updated_at reste à sa valeur historique jusqu'au prochain UPDATE).
--
-- RETOUR ARRIÈRE :
--   drop trigger if exists characters_set_updated_at on public.characters;
--   drop function if exists public.set_updated_at();   -- seulement si aucun autre trigger ne l'utilise

set local lock_timeout = '10s';

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  -- Ne touche updated_at que si la ligne change réellement (hors updated_at elle-même).
  if (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at') then
    new.updated_at := now();
  else
    new.updated_at := old.updated_at;
  end if;
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public, anon, authenticated;
grant execute on function public.set_updated_at() to service_role;

comment on function public.set_updated_at() is
  'Trigger BEFORE UPDATE générique : met updated_at à now() quand la ligne change. Phase 0 de la refonte de la base.';

create or replace trigger characters_set_updated_at
  before update on public.characters
  for each row
  execute function public.set_updated_at();
