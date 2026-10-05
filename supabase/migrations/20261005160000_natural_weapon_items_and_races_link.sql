-- Chantier "Personnages" (app mobile) -- 6 races ont un trait "arme naturelle"
-- deja present en texte libre dans races.traits (verifie en base, non
-- modifie ici) : Aarakocra (Serre), Centaure (Sabots), Homme-lezard
-- (Morsure), Minotaure (Cornes), Tabaxi (Griffes felines), Tortue (Griffes).
--
-- Objectif : rendre ces armes naturelles equipables comme n'importe quelle
-- arme du catalogue (l'app mobile les ajoutera automatiquement a
-- l'inventaire a la creation de personnage -- hors perimetre de cette
-- migration), tout en permettant de les exclure du catalogue d'equipement
-- achetable/ajoutable librement par un joueur d'une autre race.
--
-- Tache 1 : 6 nouveaux public.items (category='arme'), weight=0, cost=null
-- (jamais achetable -- 250 items existants ont deja cost null, ce n'est pas
-- un cas inedit), source='Trait racial', et les memes valeurs par defaut
-- qu'une arme ordinaire du catalogue pour rarity/requires_attunement/
-- consumable/ac_bonus/ac_bonus_kind (verifie sur Gourdin/Dague/Hachette
-- etc. : rarity=null, requires_attunement=false, consumable=false,
-- ac_bonus=null, ac_bonus_kind=null). Traduction fr via public.translations
-- (entity_type='item', field_name='name', locale='fr'). Ligne
-- public.weapon_properties correspondante : damage_dice/damage_type par
-- arme, range=null (corps a corps uniquement), properties=["à deux mains",
-- "naturelle"]. L'orthographe exacte de "à deux mains" est copiee de la
-- ligne existante "Gourdin à deux mains" (weapon_properties.properties),
-- verifiee en base avant d'ecrire cette migration -- pas retapee de
-- memoire. "naturelle" est un nouveau marqueur introduit par cette
-- migration, pose uniquement sur ces 6 armes, pour que l'app mobile puisse
-- exclure ces entrees du catalogue d'equipement choisissable (un Humain ne
-- doit jamais pouvoir choisir "Griffes felines"). Aucune autre arme du
-- catalogue ne porte ce marqueur.
--
-- Tache 2 : public.races.natural_weapon_item_id (int, nullable, references
-- public.items(id) on delete set null -- meme convention que
-- characters.lineage_id, cf. 20261005120000_add_lineage_id_to_characters.sql),
-- renseignee uniquement pour ces 6 races (ids verifies par jointure sur
-- translations : Aarakocra=22, Centaure=30, Homme-lezard=40, Minotaure=41,
-- Tabaxi=43, Tortue=44). Toutes les autres races restent a null.
--
-- Ne modifie pas codex_entries. Ne touche a aucune autre colonne/table.
-- Pas de nouvelle policy RLS necessaire : items/weapon_properties/
-- translations/races ont deja leurs policies de lecture publique
-- authentifiee / ecriture admin, qui couvrent ces nouvelles lignes et cette
-- nouvelle colonne.

alter table public.races
  add column natural_weapon_item_id int references public.items (id) on delete set null;

comment on column public.races.natural_weapon_item_id is
  'Arme naturelle (public.items, category=''arme'', properties contient ''naturelle'') accordee par un trait racial a choix structure nul ici : juste un lien vers l''item correspondant au trait "arme naturelle" deja decrit en texte libre dans races.traits. Null pour toutes les races sans arme naturelle.';

create temporary table tmp_natural_weapons (
  slug text primary key,
  name text not null,
  damage_dice text not null,
  damage_type text not null,
  race_id int not null,
  item_id int
) on commit drop;

insert into tmp_natural_weapons (slug, name, damage_dice, damage_type, race_id) values
  ('aarakocra', 'Serre', '1d4', 'tranchant', 22),
  ('centaure', 'Sabots', '1d6', 'contondant', 30),
  ('homme-lezard', 'Morsure', '1d6', 'perforant', 40),
  ('minotaure', 'Cornes', '1d6', 'perforant', 41),
  ('tabaxi', 'Griffes félines', '1d6', 'tranchant', 43),
  ('tortue', 'Griffes', '1d6', 'tranchant', 44);

do $$
declare
  rec record;
  new_id int;
begin
  for rec in select * from tmp_natural_weapons order by slug loop
    insert into public.items (category, weight, cost, source, rarity, requires_attunement, consumable, ac_bonus, ac_bonus_kind)
    values ('arme', 0, null, 'Trait racial', null, false, false, null, null)
    returning id into new_id;

    insert into public.weapon_properties (item_id, damage_dice, damage_type, properties, range)
    values (new_id, rec.damage_dice, rec.damage_type, '["à deux mains", "naturelle"]'::jsonb, null);

    insert into public.translations (entity_type, entity_id, field_name, locale, value)
    values ('item', new_id::text, 'name', 'fr', rec.name);

    update public.races set natural_weapon_item_id = new_id where id = rec.race_id;

    update tmp_natural_weapons set item_id = new_id where slug = rec.slug;
  end loop;
end $$;
