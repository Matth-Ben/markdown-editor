-- Corrige un vrai bug trouvé par qa-testeur en vérifiant le chantier
-- notifications push/email en conditions réelles : l'upsert direct sur
-- `user_push_tokens` (onConflict: 'token') échoue avec "new row violates
-- row-level security policy" dès que le token existe déjà pour un AUTRE
-- utilisateur -- ce qui bloque silencieusement le scénario documenté
-- "réinstallation de l'app sous un autre compte sur le même appareil" : la
-- policy UPDATE (`using (auth.uid() = user_id)`) compare au propriétaire
-- ACTUEL de la ligne, jamais vrai pour le nouvel utilisateur qui réclame ce
-- token.
--
-- Plutôt que d'assouplir la policy UPDATE (risque de policy trop permissive
-- si mal bornée), on encapsule la réattribution dans une fonction
-- SECURITY DEFINER dédiée : elle force TOUJOURS `user_id = auth.uid()`,
-- quoi que l'appelant envoie -- un client authentifié ne peut donc jamais
-- réclamer un token "au nom" d'un autre utilisateur, seulement pour
-- lui-même. Les policies RLS existantes (select/insert/update/delete,
-- toutes scoped au propriétaire) restent inchangées pour tout accès direct
-- à la table.
create or replace function public.claim_push_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_platform not in ('android', 'ios') then
    raise exception 'invalid platform: %', p_platform;
  end if;

  insert into public.user_push_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), p_platform, now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = excluded.updated_at;
end;
$$;

grant execute on function public.claim_push_token(text, text) to authenticated;
