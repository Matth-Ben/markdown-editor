-- Système de groupe (12-partage-et-groupes.md section 2.3) : "group_treasure
-- est lisible et modifiable par tous les membres du groupe" via RLS directe
-- -- ce qui expose un vrai risque de concurrence pour l'action "S'attribuer"
-- (2 membres réclament simultanément la dernière pièce d'or disponible),
-- signalé explicitement par direction-artistique en spécifiant l'écran
-- "Butin du groupe".
--
-- Décrémentation atomique conditionnelle (UPDATE ... WHERE solde >= montant)
-- plutôt qu'un aller-retour lire-puis-écrire côté client : ferme totalement
-- la course pour la monnaie (le cas le plus fréquent). SECURITY INVOKER
-- (par défaut, pas DEFINER) : l'UPDATE interne s'exécute sous le contexte
-- RLS de l'appelant, donc la policy "Member can update their group_treasure"
-- continue de s'appliquer telle quelle -- un non-membre obtient 0 ligne
-- affectée, exactement comme un appel direct bloqué par RLS.
create or replace function public.claim_group_treasure_currency(
  p_group_id uuid,
  p_currency text,
  p_amount int
) returns boolean
language plpgsql
as $$
declare
  v_updated int;
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

  get diagnostics v_updated = row_count;
  -- v_updated = 0 signifie soit "solde insuffisant" (course perdue contre
  -- un autre membre, ou simplement un montant trop élevé), soit "pas membre
  -- de ce groupe" (RLS a filtré la ligne) -- l'appelant mobile ne peut pas
  -- distinguer les deux, ce qui est le comportement voulu (jamais confirmer
  -- ni infirmer l'appartenance à un groupe via ce canal).
  return v_updated > 0;
end;
$$;

grant execute on function public.claim_group_treasure_currency(uuid, text, int) to authenticated;
