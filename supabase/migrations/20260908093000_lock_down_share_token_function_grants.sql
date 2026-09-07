-- Complète 20260908090000_add_character_share_token.sql : verrouille
-- explicitement l'EXECUTE des fonctions qui n'ont pas vocation à être
-- appelables par n'importe qui.
--
-- Constat fait en vérifiant cette même migration contre le projet distant
-- (smoke test via l'API REST publique, clé publishable/anon, avant de
-- déclarer la tâche terminée) : PostgreSQL accorde par défaut EXECUTE à
-- PUBLIC sur toute fonction nouvellement créée (contrairement aux tables),
-- et ce projet ne révoque ce défaut nulle part. Résultat observé
-- empiriquement : `regenerate_character_share_token` et `get_translation`
-- étaient toutes les deux directement appelables via
-- `/rest/v1/rpc/<nom>` par un client anonyme (clé publishable seule, sans
-- session), alors que :
-- - `regenerate_character_share_token` n'accordait explicitement EXECUTE
--   qu'à `authenticated` (le GRANT explicite ne retire pas le GRANT par
--   défaut à PUBLIC -- les deux s'additionnent).
-- - `get_translation` n'accordait explicitement EXECUTE à personne, son
--   commentaire affirmant à tort "pas exposée en EXECUTE à anon/
--   authenticated" -- affirmation fausse en pratique tant que PUBLIC
--   conserve son EXECUTE implicite.
--
-- Sans risque de sécurité réel dans les deux cas (voir le détail dans
-- chaque commentaire de fonction, inchangé par cette migration) :
-- `regenerate_character_share_token` appelée par anon échoue toujours avec
-- P0002 (auth.uid() vaut NULL, ne peut jamais égaler un owner_id réel, donc
-- l'UPDATE interne ne trouve jamais de ligne) ; `get_translation` ne fait
-- que retourner du texte déjà destiné à l'affichage joueur (traductions de
-- races/classes/objets...), jamais de donnée sensible. Verrouillé quand même
-- par rigueur (moins de surface d'API exposée sans raison, et pour que le
-- commentaire de get_translation redevienne exact) plutôt que laissé "sans
-- risque donc sans importance".
--
-- get_shared_character et regenerate_character_share_token gardent leurs
-- GRANT explicites déjà posés par 20260908090000 (`to anon, authenticated`
-- et `to authenticated` respectivement) -- inchangés, seul le GRANT
-- implicite à PUBLIC est retiré ici, ce qui ne change rien pour les rôles
-- qui doivent effectivement pouvoir les appeler.
--
-- Note pour la suite : ce gap (EXECUTE PUBLIC implicite non révoqué) existe
-- probablement aussi sur les fonctions helper security-definer précédentes
-- de ce dépôt (owns_character, character_owner_can_read_joined_story,
-- group_member_can_read_character...), mais elles restent sans risque
-- observable par construction : appelées par anon, elles évaluent
-- auth.uid() = NULL et retournent systématiquement false, sans fuite
-- d'information. Hors périmètre de cette tâche (partage de personnage) --
-- à traiter globalement si une revue de sécurité dédiée est planifiée.

revoke execute on function public.regenerate_character_share_token(uuid) from public;
revoke execute on function public.get_translation(text, text, text) from public;
revoke execute on function public.get_shared_character(text) from public;

-- Re-déclarés pour que chaque fonction porte explicitement la liste complète
-- et volontaire de ses grantees, sans dépendre d'un état antérieur implicite
-- (idempotent : ces GRANT existent déjà depuis 20260908090000, mais les
-- répéter ici rend cette migration lisible seule, sans avoir à recroiser la
-- précédente pour savoir qui a accès à quoi après application).
grant execute on function public.regenerate_character_share_token(uuid) to authenticated;
grant execute on function public.get_shared_character(text) to anon, authenticated;
-- get_translation : aucun grant explicite -- reste un helper interne, appelé
-- uniquement depuis l'intérieur de get_shared_character (SECURITY DEFINER,
-- exécute avec les privilèges du propriétaire de la fonction, qui a
-- implicitement EXECUTE sur ses propres fonctions -- le retrait d'EXECUTE à
-- PUBLIC ci-dessus ne casse donc pas cet appel interne).

comment on function public.get_translation(text, text, text) is
  'Résout une traduction fr (public.translations) par (entity_type, entity_id, field_name). Retourne NULL si p_entity_id est NULL ou si aucune traduction n''existe. Usage interne à get_shared_character : EXECUTE explicitement retiré à PUBLIC (20260908093000), aucun GRANT à anon/authenticated -- non appelable directement via /rest/v1/rpc/get_translation.';
