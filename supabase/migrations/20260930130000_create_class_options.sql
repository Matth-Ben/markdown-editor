-- Lot 6 de l'import du contenu de référence : nouvelle table des options de classe
-- (manœuvres, métamagie, styles de combat, disciplines élémentaires, faveurs de pacte,
-- infusions, tirs arcaniques, runes), jusqu'ici décrites seulement en texte dans une aptitude.
--
-- Nom et description en `translations` (entity_type 'class_option'), comme le reste du
-- référentiel. `option_type` reprend les codes de `class_features.choice_type` existants
-- ('manoeuvre', 'metamagie', 'style_combat', 'discipline_elementaire', 'pacte') et en ajoute
-- trois ('infusion', 'tir_arcanique', 'rune').
-- Texte français reformulé (PHB, Xanathar, Tasha). Idempotente.

create table if not exists public.class_options (
  id integer generated always as identity primary key,
  class_id integer not null references public.classes(id) on delete cascade,
  subclass_id integer references public.subclasses(id) on delete cascade,
  option_type text not null,
  min_level integer not null default 1 check (min_level between 1 and 20),
  prerequisites jsonb not null default '{}'::jsonb,
  source text
);

comment on table public.class_options is
  'Options au choix d''une classe ou sous-classe (manœuvres, métamagie, styles de combat, disciplines, pactes, infusions, tirs arcaniques, runes). Nom/description dans translations (entity_type class_option).';

create index if not exists class_options_class_type_idx on public.class_options (class_id, option_type);
create index if not exists class_options_subclass_idx on public.class_options (subclass_id);

alter table public.class_options enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'class_options' and policyname = 'Anonymous users can read class_options') then
    create policy "Anonymous users can read class_options" on public.class_options for select to anon using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'class_options' and policyname = 'Authenticated users can read class_options') then
    create policy "Authenticated users can read class_options" on public.class_options for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'class_options' and policyname = 'Admins can insert class_options') then
    create policy "Admins can insert class_options" on public.class_options for insert to authenticated with check (is_admin());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'class_options' and policyname = 'Admins can update class_options') then
    create policy "Admins can update class_options" on public.class_options for update to authenticated using (is_admin()) with check (is_admin());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'class_options' and policyname = 'Admins can delete class_options') then
    create policy "Admins can delete class_options" on public.class_options for delete to authenticated using (is_admin());
  end if;
end $$;

do $$
declare
  rec record;
  v_id int;
  v_inserted int := 0;
begin
  for rec in
    select * from (values
  -- Manœuvres (Guerrier — Maître de guerre, 48)
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Embuscade$t$, $t$Ambush$t$, $t$Lorsque vous faites un test de Dextérité (Discrétion) ou un jet d'initiative, vous pouvez dépenser un dé de supériorité et l'ajouter au résultat, si vous n'êtes pas neutralisé.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Échange de position$t$, $t$Bait and Switch$t$, $t$À votre tour, vous dépensez un dé et 1,50 m de déplacement pour échanger votre place avec une créature consentante à 1,50 m ou moins ; vous ou elle ajoutez le dé à la CA jusqu'au début de votre prochain tour.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Parade préparée$t$, $t$Brace$t$, $t$Par une réaction, lorsqu'une créature que vous voyez entre dans votre allonge, vous dépensez un dé pour lui porter une attaque armée ; si elle touche, ajoutez le dé aux dégâts.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Frappe du commandant$t$, $t$Commander's Strike$t$, $t$Vous renoncez à une attaque de votre action Attaque et, par une action bonus, dépensez un dé : un allié qui vous voit ou vous entend peut utiliser sa réaction pour porter une attaque armée, en ajoutant le dé aux dégâts.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Présence imposante$t$, $t$Commanding Presence$t$, $t$Lorsque vous faites un test de Charisme (Intimidation, Représentation ou Persuasion), vous pouvez dépenser un dé et l'ajouter au résultat.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Attaque désarmante$t$, $t$Disarming Attack$t$, $t$Quand vous touchez une créature, vous dépensez un dé et l'ajoutez aux dégâts ; elle doit réussir un jet de sauvegarde de Force ou lâcher un objet de votre choix qu'elle tient, qui tombe à ses pieds.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Frappe distrayante$t$, $t$Distracting Strike$t$, $t$Quand vous touchez une créature, vous dépensez un dé et l'ajoutez aux dégâts ; la prochaine attaque contre elle par une autre créature que vous, avant le début de votre prochain tour, a l'avantage.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Jeu de jambes évasif$t$, $t$Evasive Footwork$t$, $t$Lorsque vous vous déplacez, vous pouvez dépenser un dé et l'ajouter à votre CA jusqu'à ce que vous arrêtiez de bouger.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Feinte$t$, $t$Feinting Attack$t$, $t$Par une action bonus, vous dépensez un dé pour feinter une créature à 1,50 m : votre prochaine attaque contre elle ce tour-ci a l'avantage, et si elle touche, vous ajoutez le dé aux dégâts.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Attaque provocante$t$, $t$Goading Attack$t$, $t$Quand vous touchez une créature, vous dépensez un dé et l'ajoutez aux dégâts ; elle doit réussir un jet de sauvegarde de Sagesse ou avoir le désavantage aux attaques contre d'autres cibles que vous jusqu'à la fin de votre prochain tour.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Frappe agrippante$t$, $t$Grappling Strike$t$, $t$Immédiatement après avoir touché au corps à corps, vous pouvez dépenser un dé pour tenter d'empoigner la cible par une action bonus, en ajoutant le dé à votre test de Force (Athlétisme).$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Attaque en fente$t$, $t$Lunging Attack$t$, $t$Lors d'une attaque armée au corps à corps, vous dépensez un dé pour augmenter votre allonge de 1,50 m pour cette attaque ; si elle touche, ajoutez le dé aux dégâts.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Attaque manœuvrante$t$, $t$Maneuvering Attack$t$, $t$Quand vous touchez une créature, vous dépensez un dé et l'ajoutez aux dégâts ; un allié qui vous voit ou vous entend peut utiliser sa réaction pour se déplacer de la moitié de sa vitesse sans provoquer d'attaque d'opportunité de la cible.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Attaque menaçante$t$, $t$Menacing Attack$t$, $t$Quand vous touchez une créature, vous dépensez un dé et l'ajoutez aux dégâts ; elle doit réussir un jet de sauvegarde de Sagesse ou être effrayée par vous jusqu'à la fin de votre prochain tour.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Parade$t$, $t$Parry$t$, $t$Par une réaction lorsqu'une attaque au corps à corps vous inflige des dégâts, vous dépensez un dé pour réduire ces dégâts du résultat + votre modificateur de Dextérité.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Attaque précise$t$, $t$Precision Attack$t$, $t$Lorsque vous faites un jet d'attaque armée, vous pouvez dépenser un dé et l'ajouter au jet, avant ou après l'avoir lancé mais avant de connaître le résultat.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Attaque repoussante$t$, $t$Pushing Attack$t$, $t$Quand vous touchez une créature, vous dépensez un dé et l'ajoutez aux dégâts ; si elle est de taille G ou inférieure, elle doit réussir un jet de sauvegarde de Force ou être repoussée jusqu'à 4,50 m.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Lancer rapide$t$, $t$Quick Toss$t$, $t$Par une action bonus, vous dépensez un dé pour lancer une arme ayant la propriété lancer (en la dégainant au passage) ; si elle touche, ajoutez le dé aux dégâts.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Ralliement$t$, $t$Rally$t$, $t$Par une action bonus, vous dépensez un dé : un allié qui vous voit ou vous entend gagne des points de vie temporaires égaux au résultat + votre modificateur de Charisme.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Riposte$t$, $t$Riposte$t$, $t$Par une réaction lorsqu'une créature vous rate au corps à corps, vous dépensez un dé pour lui porter une attaque armée au corps à corps ; si elle touche, ajoutez le dé aux dégâts.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Attaque circulaire$t$, $t$Sweeping Attack$t$, $t$Quand vous touchez au corps à corps, vous dépensez un dé pour viser une autre créature à 1,50 m de la cible et dans votre allonge : si votre jet initial l'aurait touchée, elle subit des dégâts égaux au dé, du même type que l'attaque.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Évaluation tactique$t$, $t$Tactical Assessment$t$, $t$Lorsque vous faites un test d'Intelligence (Investigation ou Histoire) ou de Sagesse (Intuition), vous pouvez dépenser un dé et l'ajouter au résultat.$t$),
  (5, 48, $t$manoeuvre$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Croc-en-jambe$t$, $t$Trip Attack$t$, $t$Quand vous touchez une créature, vous dépensez un dé et l'ajoutez aux dégâts ; si elle est de taille G ou inférieure, elle doit réussir un jet de sauvegarde de Force ou tomber à terre.$t$),
  -- Métamagie (Ensorceleur, 12)
  (12, null, $t$metamagie$t$, 3, $t${"cost":"1 point de sorcellerie"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Sort prudent$t$, $t$Careful Spell$t$, $t$Lorsque vous lancez un sort imposant un jet de sauvegarde, jusqu'à votre modificateur de Charisme créatures de votre choix réussissent automatiquement ce jet.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"1 point de sorcellerie"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Sort distant$t$, $t$Distant Spell$t$, $t$La portée d'un sort d'au moins 1,50 m est doublée ; un sort de contact voit sa portée passer à 9 m.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"1 point de sorcellerie"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Sort renforcé$t$, $t$Empowered Spell$t$, $t$Lorsque vous lancez les dégâts d'un sort, vous pouvez relancer jusqu'à votre modificateur de Charisme dés. Cumulable avec une autre option de métamagie.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"1 point de sorcellerie"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Sort prolongé$t$, $t$Extended Spell$t$, $t$La durée d'un sort d'au moins 1 minute est doublée, jusqu'à un maximum de 24 heures.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"3 points de sorcellerie"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Sort intensifié$t$, $t$Heightened Spell$t$, $t$Une cible du sort a le désavantage à son premier jet de sauvegarde contre celui-ci.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"2 points de sorcellerie"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Sort accéléré$t$, $t$Quickened Spell$t$, $t$Un sort au temps d'incantation d'une action peut être lancé par une action bonus.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"2 points de sorcellerie"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Sort guidé$t$, $t$Seeking Spell$t$, $t$Si vous ratez un jet d'attaque de sort, vous pouvez le relancer une fois et devez garder le nouveau résultat. Utilisable même avec une autre option de métamagie sur le même sort.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"1 point de sorcellerie"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Sort subtil$t$, $t$Subtle Spell$t$, $t$Vous lancez le sort sans composantes verbales ni somatiques.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"1 point de sorcellerie"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Sort transmuté$t$, $t$Transmuted Spell$t$, $t$Un sort infligeant des dégâts d'acide, de feu, de foudre, de froid, de poison ou de tonnerre peut infliger à la place un autre de ces types.$t$),
  (12, null, $t$metamagie$t$, 3, $t${"cost":"points de sorcellerie égaux au niveau du sort (1 pour un sort mineur)"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Sort jumeau$t$, $t$Twinned Spell$t$, $t$Un sort qui ne cible qu'une créature et n'a pas une portée personnelle peut viser une seconde créature à portée.$t$),
  -- Styles de combat (Guerrier 5 ; Paladin 7 et Rôdeur 8 pour leurs styles propres)
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Paladin, Rôdeur"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Archerie$t$, $t$Archery$t$, $t$Vous gagnez un bonus de +2 aux jets d'attaque avec les armes à distance.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Paladin, Rôdeur"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Combat en aveugle$t$, $t$Blind Fighting$t$, $t$Vous avez une vision aveugle de 3 m : dans cette zone, vous voyez ce qui n'est pas derrière un abri total, même aveuglé ou dans l'obscurité, ainsi que les créatures invisibles qui ne se cachent pas.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Paladin, Rôdeur"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Défense$t$, $t$Defense$t$, $t$Tant que vous portez une armure, vous gagnez un bonus de +1 à la CA.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Paladin, Rôdeur"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Duel$t$, $t$Dueling$t$, $t$Lorsque vous maniez une arme de corps à corps d'une main et aucune autre arme, vous gagnez un bonus de +2 aux jets de dégâts avec cette arme.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Paladin"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Armes à deux mains$t$, $t$Great Weapon Fighting$t$, $t$Lorsque vous obtenez 1 ou 2 à un dé de dégâts d'une arme de corps à corps à deux mains ou polyvalente tenue à deux mains, vous pouvez relancer le dé et devez garder le nouveau résultat.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Paladin"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Interception$t$, $t$Interception$t$, $t$Par une réaction, lorsqu'une créature que vous voyez touche une autre cible à 1,50 m de vous, vous réduisez les dégâts de 1d10 + votre bonus de maîtrise. Vous devez tenir un bouclier ou une arme courante ou de guerre.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Paladin"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Protection$t$, $t$Protection$t$, $t$Par une réaction, lorsqu'une créature que vous voyez attaque une autre cible à 1,50 m de vous, vous lui imposez le désavantage à ce jet. Vous devez tenir un bouclier.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Technique supérieure$t$, $t$Superior Technique$t$, $t$Vous apprenez une manœuvre du Maître de guerre et gagnez un dé de supériorité (d6), récupéré après un repos court ou long.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Rôdeur"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Combat aux armes de jet$t$, $t$Thrown Weapon Fighting$t$, $t$Vous pouvez dégainer une arme de jet dans le cadre de l'attaque, et gagnez un bonus de +2 aux dégâts des attaques à distance avec une arme de jet.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier, Rôdeur"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Combat à deux armes$t$, $t$Two-Weapon Fighting$t$, $t$Lorsque vous combattez à deux armes, vous ajoutez votre modificateur de caractéristique aux dégâts de la seconde attaque.$t$),
  (5, null, $t$style_combat$t$, 1, $t${"text":"Guerrier"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Combat à mains nues$t$, $t$Unarmed Fighting$t$, $t$Vos frappes à mains nues infligent 1d6 + modificateur de Force dégâts contondants (1d8 sans arme ni bouclier en main). Au début de chacun de vos tours, vous infligez 1d4 dégâts contondants à une créature que vous empoignez.$t$),
  (7, null, $t$style_combat$t$, 2, $t${"text":"Paladin"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Guerrier béni$t$, $t$Blessed Warrior$t$, $t$Vous apprenez deux sorts mineurs de clerc, qui comptent comme des sorts de paladin ; le Charisme est votre caractéristique d'incantation pour eux.$t$),
  (8, null, $t$style_combat$t$, 2, $t${"text":"Rôdeur"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Guerrier druidique$t$, $t$Druidic Warrior$t$, $t$Vous apprenez deux sorts mineurs de druide, qui comptent comme des sorts de rôdeur ; la Sagesse est votre caractéristique d'incantation pour eux.$t$),
  -- Disciplines élémentaires (Moine — Voie des quatre éléments, 66)
  (6, 66, $t$discipline_elementaire$t$, 3, $t${"cost":"0 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Harmonie élémentaire$t$, $t$Elemental Attunement$t$, $t$Par une action, vous produisez un effet élémentaire mineur à 9 m : sensation (brise, embruns…), allumer ou éteindre une petite flamme, refroidir ou réchauffer un objet pendant 1 heure, ou faire prendre une forme grossière à un peu d'élément pendant 1 minute.$t$),
  (6, 66, $t$discipline_elementaire$t$, 3, $t${"cost":"1 ki (+1 ki pour +1d10)"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Crocs du serpent de feu$t$, $t$Fangs of the Fire Snake$t$, $t$Pendant l'action Attaque, vos frappes à mains nues ont 3 m d'allonge supplémentaire et infligent des dégâts de feu ; en cas de touche, vous pouvez dépenser 1 ki de plus pour ajouter 1d10 dégâts de feu.$t$),
  (6, 66, $t$discipline_elementaire$t$, 3, $t${"cost":"2 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Poing des quatre tonnerres$t$, $t$Fist of Four Thunders$t$, $t$Vous lancez Vague tonnante.$t$),
  (6, 66, $t$discipline_elementaire$t$, 3, $t${"cost":"2 ki (+1d10 par ki supplémentaire)"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Poing de l'air invaincu$t$, $t$Fist of Unbroken Air$t$, $t$Par une action, une créature à 9 m ou moins doit réussir un jet de sauvegarde de Force ou subir 3d10 dégâts contondants, être repoussée de 6 m et tomber à terre (moitié des dégâts seulement en cas de réussite).$t$),
  (6, 66, $t$discipline_elementaire$t$, 3, $t${"cost":"2 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Ruée des esprits du vent$t$, $t$Rush of the Gale Spirits$t$, $t$Vous lancez Bourrasque.$t$),
  (6, 66, $t$discipline_elementaire$t$, 3, $t${"cost":"1 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Façonner le fleuve$t$, $t$Shape the Flowing River$t$, $t$Par une action, vous façonnez l'eau ou la glace dans un cube de 9 m à 36 m ou moins : geler ou dégeler, creuser des tranchées ou élever des murs (jusqu'à la moitié de la dimension de la zone).$t$),
  (6, 66, $t$discipline_elementaire$t$, 3, $t${"cost":"2 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Frappe des cendres ardentes$t$, $t$Sweeping Cinder Strike$t$, $t$Vous lancez Mains brûlantes.$t$),
  (6, 66, $t$discipline_elementaire$t$, 3, $t${"cost":"2 ki (+1d10 par ki supplémentaire)"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Fouet d'eau$t$, $t$Water Whip$t$, $t$Par une action bonus, une créature à 9 m ou moins doit réussir un jet de sauvegarde de Dextérité ou subir 3d10 dégâts contondants et tomber à terre ou être attirée de 7,50 m vers vous (moitié des dégâts seulement en cas de réussite).$t$),
  (6, 66, $t$discipline_elementaire$t$, 6, $t${"cost":"3 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Étreinte du vent du nord$t$, $t$Clench of the North Wind$t$, $t$Vous lancez Immobilisation de personne.$t$),
  (6, 66, $t$discipline_elementaire$t$, 6, $t${"cost":"3 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Gong du sommet$t$, $t$Gong of the Summit$t$, $t$Vous lancez Fracassement.$t$),
  (6, 66, $t$discipline_elementaire$t$, 11, $t${"cost":"5 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Défense de la montagne éternelle$t$, $t$Eternal Mountain Defense$t$, $t$Vous lancez Peau de pierre sur vous-même.$t$),
  (6, 66, $t$discipline_elementaire$t$, 11, $t${"cost":"4 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Flammes du phénix$t$, $t$Flames of the Phoenix$t$, $t$Vous lancez Boule de feu.$t$),
  (6, 66, $t$discipline_elementaire$t$, 11, $t${"cost":"4 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Posture de brume$t$, $t$Mist Stance$t$, $t$Vous lancez Forme gazeuse sur vous-même.$t$),
  (6, 66, $t$discipline_elementaire$t$, 11, $t${"cost":"4 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Chevaucher le vent$t$, $t$Ride the Wind$t$, $t$Vous lancez Vol sur vous-même.$t$),
  (6, 66, $t$discipline_elementaire$t$, 17, $t${"cost":"6 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Souffle de l'hiver$t$, $t$Breath of Winter$t$, $t$Vous lancez Cône de froid.$t$),
  (6, 66, $t$discipline_elementaire$t$, 17, $t${"cost":"5 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Rivière de flammes affamées$t$, $t$River of Hungry Flame$t$, $t$Vous lancez Mur de feu.$t$),
  (6, 66, $t$discipline_elementaire$t$, 17, $t${"cost":"6 ki"}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Vague de terre déferlante$t$, $t$Wave of Rolling Earth$t$, $t$Vous lancez Mur de pierre.$t$),
  -- Faveurs de pacte (Occultiste, 10)
  (10, null, $t$pacte$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Pacte de la chaîne$t$, $t$Pact of the Chain$t$, $t$Vous apprenez Appel de familier et le lancez comme rituel ; votre familier peut aussi prendre la forme d'un diablotin, d'un pseudodragon, d'un quasit ou d'un sprite. Lorsque vous effectuez l'action Attaque, vous pouvez renoncer à une attaque pour que votre familier attaque par sa réaction.$t$),
  (10, null, $t$pacte$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Pacte de la lame$t$, $t$Pact of the Blade$t$, $t$Par une action, vous créez une arme de pacte de corps à corps de la forme de votre choix, que vous maîtrisez et qui compte comme magique. Vous pouvez aussi lier une arme magique par un rituel d'une heure.$t$),
  (10, null, $t$pacte$t$, 3, $t${}$t$::jsonb, $t$Manuel des Joueurs$t$, $t$Pacte du grimoire$t$, $t$Pact of the Tome$t$, $t$Votre protecteur vous donne un Livre des Ombres : vous apprenez trois sorts mineurs de n'importe quelle classe, qui comptent comme des sorts d'occultiste, tant que le livre est sur vous.$t$),
  (10, null, $t$pacte$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Pacte du talisman$t$, $t$Pact of the Talisman$t$, $t$Votre protecteur vous donne une amulette : son porteur peut ajouter 1d4 à un test de caractéristique raté, un nombre de fois égal à votre bonus de maîtrise par repos long.$t$),
  -- Infusions (Artificier, 13)
  (13, null, $t$infusion$t$, 14, $t${"text":"Armure"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Armure à propulsion arcanique$t$, $t$Arcane Propulsion Armor$t$, $t$Armure (harmonisation) : vitesse +1,50 m, gantelets servant d'armes magiques lancées (1d8 dégâts de force, portée 6/18 m, retour dans la main), impossible à retirer contre votre gré, et remplace les membres manquants.$t$),
  (13, null, $t$infusion$t$, 10, $t${"text":"Armure"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Armure de force magique$t$, $t$Armor of Magical Strength$t$, $t$Armure (harmonisation) avec 6 charges : dépensez-en une pour ajouter votre modificateur d'Intelligence à un test ou jet de sauvegarde de Force, ou, par une réaction, pour ne pas être jeté à terre. Recharge 1d6 à l'aube.$t$),
  (13, null, $t$infusion$t$, 6, $t${"text":"Bottes"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Bottes du chemin sinueux$t$, $t$Boots of the Winding Path$t$, $t$Bottes (harmonisation) : par une action bonus, vous vous téléportez jusqu'à 4,50 m dans un espace inoccupé que vous avez occupé pendant ce tour.$t$),
  (13, null, $t$infusion$t$, 2, $t${"text":"Bâton, baguette ou sceptre"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Focaliseur arcanique amélioré$t$, $t$Enhanced Arcane Focus$t$, $t$Focaliseur (harmonisation) : +1 aux jets d'attaque de sort (+2 au niveau 10), et vos attaques de sort ignorent l'abri partiel.$t$),
  (13, null, $t$infusion$t$, 2, $t${"text":"Armure ou bouclier"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Défense améliorée$t$, $t$Enhanced Defense$t$, $t$L'armure ou le bouclier confère un bonus de +1 à la CA (+2 au niveau 10).$t$),
  (13, null, $t$infusion$t$, 2, $t${"text":"Arme courante ou de guerre"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Arme améliorée$t$, $t$Enhanced Weapon$t$, $t$L'arme devient une arme magique +1 aux jets d'attaque et de dégâts (+2 au niveau 10).$t$),
  (13, null, $t$infusion$t$, 10, $t${"text":"Heaume"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Heaume de vigilance$t$, $t$Helm of Awareness$t$, $t$Heaume (harmonisation) : avantage aux jets d'initiative, et vous ne pouvez pas être surpris tant que vous n'êtes pas neutralisé.$t$),
  (13, null, $t$infusion$t$, 2, $t${"text":"Gemme ou cristal de 100 po"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Serviteur homoncule$t$, $t$Homunculus Servant$t$, $t$Vous créez un homoncule mécanique qui vous obéit, agit à votre initiative (Esquiver sauf ordre en action bonus) et peut transmettre vos sorts de contact.$t$),
  (13, null, $t$infusion$t$, 2, $t${"text":"Armure ou robe"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Aiguiseur d'esprit$t$, $t$Mind Sharpener$t$, $t$Armure ou robe avec 4 charges : par une réaction lorsque vous ratez un jet de sauvegarde de concentration, dépensez une charge pour le réussir. Recharge 1d4 à l'aube.$t$),
  (13, null, $t$infusion$t$, 6, $t${"text":"Arme courante ou de guerre"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Arme radieuse$t$, $t$Radiant Weapon$t$, $t$Arme +1 (harmonisation) qui émet de la lumière sur 9 m, avec 4 charges : par une réaction lorsque vous êtes touché, vous aveuglez l'attaquant jusqu'à la fin de son prochain tour (jet de sauvegarde de Constitution). Recharge 1d4 à l'aube.$t$),
  (13, null, $t$infusion$t$, 2, $t${"text":"Arme courante ou de guerre à munitions"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Tir répété$t$, $t$Repeating Shot$t$, $t$Arme +1 (harmonisation) qui ignore la propriété chargement et produit ses propres munitions magiques.$t$),
  (13, null, $t$infusion$t$, 2, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Réplique d'objet magique$t$, $t$Replicate Magic Item$t$, $t$Vous reproduisez un objet magique d'une liste qui s'étend avec votre niveau (sac sans fond, lunettes de nuit, cape de la raie manta… puis bottes de lévitation, anneau de nage…). Peut être choisie plusieurs fois.$t$),
  (13, null, $t$infusion$t$, 6, $t${"text":"Bouclier"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Bouclier de répulsion$t$, $t$Repulsion Shield$t$, $t$Bouclier (harmonisation) : +1 à la CA et 4 charges ; par une réaction lorsqu'une créature vous touche au corps à corps, vous la repoussez de 4,50 m. Recharge 1d4 à l'aube.$t$),
  (13, null, $t$infusion$t$, 6, $t${"text":"Armure"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Armure résistante$t$, $t$Resistant Armor$t$, $t$Armure (harmonisation) qui confère la résistance à un type de dégâts choisi à l'infusion (acide, feu, force, foudre, froid, nécrotique, poison, psychique, radiant ou tonnerre).$t$),
  (13, null, $t$infusion$t$, 2, $t${"text":"Arme courante ou de guerre avec la propriété lancer"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Arme boomerang$t$, $t$Returning Weapon$t$, $t$Arme +1 qui revient dans votre main juste après avoir été lancée.$t$),
  (13, null, $t$infusion$t$, 6, $t${"text":"Anneau"}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Anneau de recharge de sort$t$, $t$Spell-Refueling Ring$t$, $t$Anneau (harmonisation) : par une action, vous récupérez un emplacement de sort de niveau 3 ou inférieur. Une fois par jour.$t$),
  -- Tirs arcaniques (Guerrier — Archer arcanique, 50)
  (5, 50, $t$tir_arcanique$t$, 3, $t${}$t$::jsonb, $t$Guide de Xanathar$t$, $t$Flèche de bannissement$t$, $t$Banishing Arrow$t$, $t$La cible doit réussir un jet de sauvegarde de Charisme ou être bannie dans la Féerie jusqu'à la fin de son prochain tour (neutralisée). Au niveau 18, elle subit aussi 2d6 dégâts de force.$t$),
  (5, 50, $t$tir_arcanique$t$, 3, $t${}$t$::jsonb, $t$Guide de Xanathar$t$, $t$Flèche charmeuse$t$, $t$Beguiling Arrow$t$, $t$La cible subit 2d6 dégâts psychiques supplémentaires et doit réussir un jet de sauvegarde de Sagesse ou être charmée par un allié de votre choix à 9 m d'elle jusqu'au début de votre prochain tour (4d6 au niveau 18).$t$),
  (5, 50, $t$tir_arcanique$t$, 3, $t${}$t$::jsonb, $t$Guide de Xanathar$t$, $t$Flèche explosive$t$, $t$Bursting Arrow$t$, $t$La flèche explose : la cible et chaque créature à 3 m d'elle subissent 2d6 dégâts de force (4d6 au niveau 18).$t$),
  (5, 50, $t$tir_arcanique$t$, 3, $t${}$t$::jsonb, $t$Guide de Xanathar$t$, $t$Flèche débilitante$t$, $t$Enfeebling Arrow$t$, $t$La cible subit 2d6 dégâts nécrotiques supplémentaires et doit réussir un jet de sauvegarde de Constitution ou voir les dégâts de ses attaques armées réduits de moitié jusqu'au début de votre prochain tour (4d6 au niveau 18).$t$),
  (5, 50, $t$tir_arcanique$t$, 3, $t${}$t$::jsonb, $t$Guide de Xanathar$t$, $t$Flèche agrippante$t$, $t$Grasping Arrow$t$, $t$La cible subit 2d6 dégâts de poison supplémentaires, sa vitesse diminue de 3 m, et elle subit 2d6 dégâts tranchants la première fois qu'elle se déplace à chaque tour, pendant 1 minute ou jusqu'à réussir un test de Force (Athlétisme) (4d6 au niveau 18).$t$),
  (5, 50, $t$tir_arcanique$t$, 3, $t${}$t$::jsonb, $t$Guide de Xanathar$t$, $t$Flèche perforante$t$, $t$Piercing Arrow$t$, $t$Sans jet d'attaque, la flèche traverse une ligne de 9 m : chaque créature sur la ligne doit réussir un jet de sauvegarde de Dextérité ou subir les dégâts normaux de la flèche + 1d6 perforants (moitié en cas de réussite ; 2d6 au niveau 18).$t$),
  (5, 50, $t$tir_arcanique$t$, 3, $t${}$t$::jsonb, $t$Guide de Xanathar$t$, $t$Flèche chercheuse$t$, $t$Seeking Arrow$t$, $t$Sans jet d'attaque, visez une créature vue dans la dernière minute : la flèche contourne les obstacles dans sa portée ; la cible doit réussir un jet de sauvegarde de Dextérité ou subir les dégâts de la flèche + 1d6 de force et vous révéler sa position (moitié en cas de réussite ; 2d6 au niveau 18).$t$),
  (5, 50, $t$tir_arcanique$t$, 3, $t${}$t$::jsonb, $t$Guide de Xanathar$t$, $t$Flèche d'ombre$t$, $t$Shadow Arrow$t$, $t$La cible subit 2d6 dégâts psychiques supplémentaires et doit réussir un jet de sauvegarde de Sagesse ou ne plus rien voir au-delà de 1,50 m jusqu'au début de votre prochain tour (4d6 au niveau 18).$t$),
  -- Runes (Guerrier — Chevalier runique, 52)
  (5, 52, $t$rune$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Rune du nuage$t$, $t$Cloud Rune$t$, $t$Passif : avantage aux tests de Dextérité (Escamotage) et de Charisme (Tromperie). Actif : par une réaction lorsque vous ou une créature à 9 m êtes touchés, vous redirigez l'attaque vers une autre créature à 9 m ou moins (hors attaquant).$t$),
  (5, 52, $t$rune$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Rune du feu$t$, $t$Fire Rune$t$, $t$Passif : bonus de maîtrise doublé pour les tests d'outils. Actif : quand vous touchez avec une arme, la cible subit 2d6 dégâts de feu supplémentaires et doit réussir un jet de sauvegarde de Force ou être entravée 1 minute, subissant 2d6 dégâts de feu au début de chacun de ses tours.$t$),
  (5, 52, $t$rune$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Rune du givre$t$, $t$Frost Rune$t$, $t$Passif : avantage aux tests de Sagesse (Dressage) et de Charisme (Intimidation). Actif : par une action bonus, +2 à tous vos tests et jets de sauvegarde de Force et de Constitution pendant 10 minutes.$t$),
  (5, 52, $t$rune$t$, 3, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Rune de pierre$t$, $t$Stone Rune$t$, $t$Passif : avantage aux tests de Sagesse (Intuition) et vision dans le noir de 36 m. Actif : par une réaction lorsqu'une créature termine son tour à 9 m, elle doit réussir un jet de sauvegarde de Sagesse ou être charmée 1 minute (neutralisée, vitesse 0).$t$),
  (5, 52, $t$rune$t$, 7, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Rune de la colline$t$, $t$Hill Rune$t$, $t$Passif : avantage aux jets de sauvegarde contre le poison et résistance aux dégâts de poison. Actif : par une action bonus, résistance aux dégâts contondants, perforants et tranchants pendant 1 minute.$t$),
  (5, 52, $t$rune$t$, 7, $t${}$t$::jsonb, $t$Chaudron de Tasha$t$, $t$Rune de la tempête$t$, $t$Storm Rune$t$, $t$Passif : avantage aux tests d'Intelligence (Arcanes) et impossible à surprendre tant que vous n'êtes pas neutralisé. Actif : par une action bonus, pendant 1 minute, par votre réaction vous accordez l'avantage ou le désavantage à un jet d'attaque, test ou jet de sauvegarde d'une créature à 18 m.$t$)
    ) as t(class_id, subclass_id, option_type, min_level, prerequisites, source, name_fr, name_en, description)
  loop
    if not exists (
      select 1 from public.class_options o
        join public.translations tr
          on tr.entity_type = 'class_option' and tr.entity_id = o.id::text
         and tr.field_name = 'name' and tr.locale = 'fr'
       where o.option_type = rec.option_type and lower(tr.value) = lower(rec.name_fr)
    ) then
      insert into public.class_options (class_id, subclass_id, option_type, min_level, prerequisites, source)
        values (rec.class_id, rec.subclass_id, rec.option_type, rec.min_level, rec.prerequisites, rec.source)
        returning id into v_id;
      insert into public.translations (entity_type, entity_id, field_name, locale, value) values
        ('class_option', v_id::text, 'name', 'fr', rec.name_fr),
        ('class_option', v_id::text, 'name', 'en', rec.name_en),
        ('class_option', v_id::text, 'description', 'fr', rec.description);
      v_inserted := v_inserted + 1;
    end if;
  end loop;
  raise notice 'options de classe insérées : %', v_inserted;
end $$;

-- Contrôle final
do $$
declare
  v_n int;
begin
  select count(*) into v_n from public.class_options;
  if v_n < 97 then
    raise exception 'Contrôle lot 6 : % options de classe, 97 attendues', v_n;
  end if;
end $$;
