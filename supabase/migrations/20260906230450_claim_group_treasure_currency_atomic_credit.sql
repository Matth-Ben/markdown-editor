-- Corrige un vrai bug trouvé en revue de code sur le système de groupe :
-- claim_group_treasure_currency ne décrémentait le butin que côté serveur,
-- laissant le crédit vers l'inventaire personnel du réclamant à un second
-- appel séparé côté app (`UPDATE characters ...`). Si ce second appel
-- échouait (réseau, app tuée, etc.) APRÈS le succès du premier, la monnaie
-- disparaissait du butin commun sans jamais être créditée nulle part --
-- perte silencieuse, pas seulement un risque de concurrence entre deux
-- réclamants (qui, lui, était déjà correctement fermé).
--
-- Signature différente (nouveau paramètre p_character_id) : `create or
-- replace` ne suffit pas, il faut DROP l'ancienne fonction explicitement
-- pour ne pas laisser les deux versions coexister en surcharge.
drop function if exists public.claim_group_treasure_currency(uuid, text, int);

-- Décrémente le butin ET crédite le personnage réclamant dans le MÊME appel
-- de fonction -- un appel de fonction PL/pgSQL est atomique par nature
-- (une exception non interceptée annule tout ce que la fonction a déjà
-- fait) : si le crédit échoue pour une raison quelconque, la décrémentation
-- du butin est automatiquement annulée avec, plutôt que de rester
-- silencieusement appliquée.
--
-- SECURITY INVOKER (par défaut, pas DEFINER) à dessein : l'UPDATE sur
-- `characters` reste soumis à la policy RLS "Owner can update their
-- characters" (auth.uid() = owner_id) -- un appelant qui passerait le
-- character_id de quelqu'un d'autre (ex. appel direct à l'API REST hors de
-- l'app) voit ce second UPDATE filtré à 0 ligne par RLS, ce qui déclenche
-- l'exception ci-dessous et annule tout, plutôt que de siphonner le butin
-- commun sans jamais créditer personne.
create or replace function public.claim_group_treasure_currency(
  p_group_id uuid,
  p_character_id uuid,
  p_currency text,
  p_amount int
) returns boolean
language plpgsql
as $$
declare
  v_treasure_updated int;
  v_character_updated int;
begin
  if p_amount <= 0 then
    raise exception 'p_amount must be positive';
  end if;

  if p_currency = 'gp' then
    update public.group_treasure set currency_gp = currency_gp - p_amount
      where group_id = p_group_id and currency_gp >= p_amount;
  elsif p_currency = 'pp' then
    update public.group_treasure set currency_pp = currency_pp - p_amount
      where group_id = p_group_id and currency_pp >= p_amount;
  elsif p_currency = 'ep' then
    update public.group_treasure set currency_ep = currency_ep - p_amount
      where group_id = p_group_id and currency_ep >= p_amount;
  elsif p_currency = 'sp' then
    update public.group_treasure set currency_sp = currency_sp - p_amount
      where group_id = p_group_id and currency_sp >= p_amount;
  elsif p_currency = 'cp' then
    update public.group_treasure set currency_cp = currency_cp - p_amount
      where group_id = p_group_id and currency_cp >= p_amount;
  else
    raise exception 'invalid p_currency: %', p_currency;
  end if;

  get diagnostics v_treasure_updated = row_count;
  if v_treasure_updated = 0 then
    -- Solde insuffisant (course perdue contre un autre membre, ou montant
    -- trop élevé) OU appelant pas membre de ce groupe (RLS a filtré la
    -- ligne) -- rien n'a été modifié, retour false sans erreur. L'appelant
    -- mobile ne peut pas distinguer les deux, comportement voulu.
    return false;
  end if;

  if p_currency = 'gp' then
    update public.characters set currency_gp = currency_gp + p_amount where id = p_character_id;
  elsif p_currency = 'pp' then
    update public.characters set currency_pp = currency_pp + p_amount where id = p_character_id;
  elsif p_currency = 'ep' then
    update public.characters set currency_ep = currency_ep + p_amount where id = p_character_id;
  elsif p_currency = 'sp' then
    update public.characters set currency_sp = currency_sp + p_amount where id = p_character_id;
  else
    update public.characters set currency_cp = currency_cp + p_amount where id = p_character_id;
  end if;

  get diagnostics v_character_updated = row_count;
  if v_character_updated = 0 then
    raise exception 'character_id % not owned by caller or not found', p_character_id;
  end if;

  return true;
end;
$$;

grant execute on function public.claim_group_treasure_currency(uuid, uuid, text, int) to authenticated;
