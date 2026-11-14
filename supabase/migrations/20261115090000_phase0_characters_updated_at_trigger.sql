-- Phase 0 « hygiène invisible » (étape 1/6) : `characters.updated_at` enfin tenu à jour.
--
-- POURQUOI (X02/N04 du diagnostic)
--   `characters.updated_at` (not null default now()) n'est jamais modifiée après la création : ni trigger, ni client (grep
--   updated_at dans lib/ : seule notification_preferences l'écrit). La synchro incrémentale, l'audit et la détection de conflit des
--   phases suivantes en ont besoin.
--
-- EFFET
--   Fonction dédiée `public.characters_touch_updated_at()` (nom spécifique : aucune collision possible avec un `set_updated_at` qui
--   existerait en production hors dépôt) et trigger `characters_set_updated_at` BEFORE UPDATE sur `characters` :
--   `updated_at := now()` quand la ligne change réellement ; si l'UPDATE ne modifie rien, la valeur reste ; si un client envoie
--   lui-même `updated_at`, la valeur serveur l'emporte. Colonne, type et défaut inchangés : seule la valeur cesse d'être figée.
--   Realtime : même nombre d'événements UPDATE, même filtre ; le payload porte la nouvelle `updated_at`.
--   Implémentation : `new.updated_at := old.updated_at; if new is distinct from old then new.updated_at := now(); end if;` (comparaison
--   de lignes native, moins coûteuse qu'une conversion en jsonb). Elle exige que toutes les colonnes de `characters` aient un opérateur
--   d'égalité : la migration refuse de continuer si une colonne de type `json` (sans opérateur) existe (aucune dans le schéma rejoué).
--
-- GARDE-FOUS (la migration échoue proprement, sans rien appliquer, plutôt que de casser la production)
--   - une fonction `public.characters_touch_updated_at()` existe déjà avec un corps différent (collision) : exception ;
--   - un autre trigger BEFORE UPDATE de `characters` (hors le nôtre) dont la fonction mentionne `updated_at`, ou un trigger du même
--     nom pointant vers une autre fonction : exception (deux gestionnaires de la même colonne) ;
--   - une colonne `json` dans `characters` : exception.
--
-- RISQUE : un appel de fonction par UPDATE de `characters`. `create trigger` pose un verrou SHARE ROW EXCLUSIVE bref (pas de réécriture).
--   `lock_timeout` 10 s. Les lignes existantes ne sont pas modifiées.
--
-- RETOUR ARRIÈRE :
--   drop trigger if exists characters_set_updated_at on public.characters;
--   drop function if exists public.characters_touch_updated_at();

set local lock_timeout = '10s';

do $phase0$
declare
  v_expected constant text := $body$
begin
  new.updated_at := old.updated_at;
  if new is distinct from old then
    new.updated_at := now();
  end if;
  return new;
end;
$body$;
  v_src text;
  r record;
begin
  -- Colonne json (sans opérateur d'égalité) : `new is distinct from old` échouerait à l'exécution.
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'characters' and data_type = 'json') then
    raise exception 'phase0 trigger : characters contient une colonne json (sans opérateur d''égalité), migration interrompue';
  end if;

  -- Collision de fonction (comparaison insensible aux fins de ligne CRLF d'un checkout Windows).
  select prosrc into v_src from pg_proc
   where pronamespace = 'public'::regnamespace and proname = 'characters_touch_updated_at' and pronargs = 0;
  if found and replace(v_src, E'', '') is distinct from replace(v_expected, E'', '') then
    raise exception 'phase0 trigger : public.characters_touch_updated_at() existe déjà avec un corps différent, migration interrompue';
  end if;

  -- Autre gestionnaire de updated_at sur characters.
  for r in
    select t.tgname, p.proname, p.prosrc
      from pg_trigger t join pg_proc p on p.oid = t.tgfoid
     where t.tgrelid = 'public.characters'::regclass and not t.tgisinternal
       and (t.tgtype & 2) = 2 and (t.tgtype & 16) = 16          -- BEFORE ... UPDATE
  loop
    if r.tgname = 'characters_set_updated_at' then
      if r.proname <> 'characters_touch_updated_at' then
        raise exception 'phase0 trigger : le trigger characters_set_updated_at existe déjà avec la fonction %, migration interrompue', r.proname;
      end if;
    elsif r.prosrc ~* 'updated_at' or r.proname ~* '(updated_at|moddatetime)' then
      raise exception 'phase0 trigger : le trigger BEFORE UPDATE % (fonction %) gère déjà updated_at sur characters, migration interrompue', r.tgname, r.proname;
    end if;
  end loop;

  if v_src is null then
    execute 'create function public.characters_touch_updated_at() returns trigger language plpgsql '
         || 'set search_path = public, pg_temp as $f$' || replace(v_expected, E'', '') || '$f$';
  end if;
end
$phase0$;

revoke all on function public.characters_touch_updated_at() from public, anon, authenticated;
grant execute on function public.characters_touch_updated_at() to service_role;

comment on function public.characters_touch_updated_at() is
  'Trigger BEFORE UPDATE de characters : met updated_at à now() quand la ligne change. Phase 0 de la refonte de la base.';

create or replace trigger characters_set_updated_at
  before update on public.characters
  for each row
  execute function public.characters_touch_updated_at();
