-- Chantier "Personnages" (app mobile) -- D10 du registre de dette technique
-- (suite de D56/D09) : contrainte unique (character_id, spell_id) en base
-- sur character_spells, avec detection de doublons existants plutot qu'une
-- migration de nettoyage automatique.
--
-- Le dedoublonnage A LA LECTURE (fusion deterministe par priorite) est deja
-- corrige cote client (PR mobile #84). Mais rien n'empechait encore qu'un
-- futur bug reintroduise des lignes character_spells en double en base :
-- cette migration pose la garde-fou cote base.
--
-- PAS une contrainte unique globale sur (character_id, spell_id) : D43 (voir
-- 20261007100000_character_spells_innate_uses_and_shared_source_class.sql,
-- deja teste par character_spells_innate_uses_test.sql) autorise
-- delibermment qu'un meme sort ait a la fois une ligne status = 'inne' ET une
-- ligne "ordinaire" (status = 'connu' ou 'prepare') pour le meme personnage
-- -- par exemple un sort racial inne qui est aussi appris comme sort de
-- classe. Ce n'est pas un doublon, c'est un cas legitime.
--
-- On pose donc DEUX index uniques partiels, un par "nature" de ligne :
--   - au plus une ligne status = 'inne' par (character_id, spell_id) ;
--   - au plus une ligne "ordinaire" (status <> 'inne', donc 'connu' ou
--     'prepare' -- seules valeurs restantes autorisees par le CHECK existant
--     sur character_spells.status) par (character_id, spell_id).
-- Les deux predicats sont disjoints et couvrent toutes les valeurs possibles
-- de status : aucune ligne n'echappe aux deux index, et le cas D43 reste
-- possible (une ligne de chaque nature peut coexister).
--
-- Detection AVANT contrainte, SANS suppression automatique (decision
-- validee par Matthias) : character_spells est une table de donnees
-- JOUEUR, potentiellement deja peuplee par de vrais testeurs. Choisir seul
-- quelle ligne dupliquee garder (la plus recente ? celle avec
-- innate_uses_spent le plus eleve ? celle avec un source_class_id non nul ?)
-- reviendrait a trancher une question produit a l'aveugle, avec un risque
-- reel de perte de donnee de testeur. Si des doublons reels existent au
-- moment de jouer cette migration, elle echoue explicitement avec le detail
-- (combien de groupes, par nature) et la requete a lancer pour les examiner
-- a la main avant de rejouer la migration une fois le menage fait
-- manuellement. Aucune ligne n'est jamais supprimee par ce fichier.
--
-- Changement additif en cas d'absence de doublons (l'immense majorite des
-- cas) : deux index, aucune colonne ni donnee touchee. Ne touche pas a
-- codex_entries.
--
-- Retour arriere (sans risque, purement structurel) :
--   drop index if exists public.character_spells_unique_innate_per_spell;
--   drop index if exists public.character_spells_unique_ordinary_per_spell;

do $$
declare
  v_duplicate_innate_groups int;
  v_duplicate_ordinary_groups int;
begin
  select count(*) into v_duplicate_innate_groups
  from (
    select character_id, spell_id
    from public.character_spells
    where status = 'inné'
    group by character_id, spell_id
    having count(*) > 1
  ) d;

  select count(*) into v_duplicate_ordinary_groups
  from (
    select character_id, spell_id
    from public.character_spells
    where status <> 'inné'
    group by character_id, spell_id
    having count(*) > 1
  ) d;

  if v_duplicate_innate_groups > 0 or v_duplicate_ordinary_groups > 0 then
    raise exception
      'character_spells contient des doublons reels : % groupe(s) (character_id, spell_id) avec plusieurs lignes "inne", % groupe(s) avec plusieurs lignes "ordinaires" (connu/prepare). Cette migration NE SUPPRIME RIEN automatiquement (donnee de joueur, trop risque de choisir seul la ligne a garder). Pour lister les lignes concernees avant de decider manuellement lesquelles supprimer, lancer :

select character_id, spell_id, status, count(*) as nb_lignes
from public.character_spells
where status = ''inné''
group by character_id, spell_id, status
having count(*) > 1
union all
select character_id, spell_id, status, count(*) as nb_lignes
from public.character_spells
where status <> ''inné''
group by character_id, spell_id, status
having count(*) > 1;

Une fois les lignes en trop supprimees a la main (apres revue au cas par cas -- quelle ligne garder n''est pas une decision a automatiser), rejouer cette migration.',
      v_duplicate_innate_groups, v_duplicate_ordinary_groups;
  end if;
end $$;

create unique index if not exists character_spells_unique_innate_per_spell
  on public.character_spells (character_id, spell_id)
  where status = 'inné';

comment on index public.character_spells_unique_innate_per_spell is
  'Au plus une ligne status = ''inné'' par (character_id, spell_id). Empeche un doublon de sort inne racial pour un meme personnage. N''empeche PAS la coexistence avec une ligne ordinaire du meme sort (cas D43, voir l''en-tete de cette migration) : index partiel disjoint de character_spells_unique_ordinary_per_spell.';

create unique index if not exists character_spells_unique_ordinary_per_spell
  on public.character_spells (character_id, spell_id)
  where status <> 'inné';

comment on index public.character_spells_unique_ordinary_per_spell is
  'Au plus une ligne "ordinaire" (status = ''connu'' ou ''préparé'', seules valeurs restantes autorisees par le CHECK de character_spells.status) par (character_id, spell_id). Empeche un doublon de sort connu/prepare pour un meme personnage. N''empeche PAS la coexistence avec une ligne inné du meme sort (cas D43, voir l''en-tete de cette migration) : index partiel disjoint de character_spells_unique_innate_per_spell.';
