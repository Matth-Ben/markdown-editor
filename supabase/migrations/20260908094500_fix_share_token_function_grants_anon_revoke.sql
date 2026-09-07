-- Corrige 20260908093000_lock_down_share_token_function_grants.sql : le
-- `revoke ... from public` de cette migration précédente s'est révélé
-- insuffisant, vérifié empiriquement (nouveau smoke test via l'API REST
-- publique après application, même méthode que la migration précédente) --
-- `get_translation` restait appelable par un client anonyme malgré le
-- revoke.
--
-- Cause : ce projet Supabase applique (comme tout projet Supabase
-- provisionné standard) des `alter default privileges in schema public
-- grant ... to anon, authenticated, service_role` au niveau base, qui
-- accordent EXECUTE directement aux rôles `anon`/`authenticated` (pas
-- seulement à PUBLIC) sur toute fonction nouvellement créée dans le schéma
-- public. `revoke ... from public` ne retire donc que le droit implicite
-- "tout le monde" -- il ne retire pas le droit explicite déjà accordé
-- séparément et automatiquement à `anon`/`authenticated` par ce mécanisme de
-- privilèges par défaut. Il faut révoquer explicitement de CHAQUE rôle
-- concerné, pas seulement de PUBLIC.

revoke execute on function public.get_translation(text, text, text) from anon, authenticated, public;
revoke execute on function public.regenerate_character_share_token(uuid) from anon, public;

-- Re-déclaré explicitement (déjà en place depuis 20260908090000, non
-- affecté par les revoke ci-dessus qui ciblent anon/public, pas
-- authenticated) -- gardé pour que cette fonction reste lisible seule.
grant execute on function public.regenerate_character_share_token(uuid) to authenticated;

comment on function public.get_translation(text, text, text) is
  'Résout une traduction fr (public.translations) par (entity_type, entity_id, field_name). Retourne NULL si p_entity_id est NULL ou si aucune traduction n''existe. Usage interne à get_shared_character : EXECUTE explicitement retiré à anon/authenticated/PUBLIC (20260908093000 puis 20260908094500 -- la première tentative de retrait, limitée à PUBLIC, s''est révélée insuffisante face aux "alter default privileges" de ce projet qui accordent EXECUTE directement aux rôles anon/authenticated, pas seulement à PUBLIC). Non appelable directement via /rest/v1/rpc/get_translation, vérifié par smoke test contre le projet distant.';

comment on function public.regenerate_character_share_token(uuid) is
  'Régénère share_token pour p_character_id (invalide l''ancien) et retourne la nouvelle valeur. SECURITY INVOKER : aucune élévation de privilège, l''UPDATE interne reste entièrement soumis à la policy "Owner can update their characters" existante -- cette fonction garantit seulement que la valeur écrite est générée côté serveur (gen_random_uuid()) plutôt que fournie par l''appelant. Lève une exception (P0002) si p_character_id n''existe pas ou n''appartient pas à auth.uid(). EXECUTE explicitement retiré à anon/PUBLIC (20260908094500, corrige 20260908093000) : seul le rôle authenticated peut l''appeler -- un appel anon échouait déjà systématiquement en pratique (auth.uid() vaut NULL, ne peut jamais égaler un owner_id réel) mais reste désormais aussi bloqué au niveau du GRANT, pas seulement par la logique interne.';
