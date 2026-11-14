-- Phase 0, étape 4 : droits EXECUTE explicites et `pg_temp` en dernier dans le search_path
-- (20261115093000_phase0_function_grants_and_search_path.sql).
--
-- Couvre : pour chaque fonction du groupe A (helpers de RLS et RPC réservées aux connectés) anon et PUBLIC n'ont
-- plus EXECUTE, authenticated et service_role le gardent ; groupe B (fonctions internes/triggers) : seul service_role ;
-- aucun droit utile perdu : anon garde get_shared_character (partage public), la lecture des tables de référence,
-- d'app_versions et de content_proposals ; les politiques RLS `to authenticated` continuent d'évaluer les helpers (le
-- propriétaire voit ses lignes, le MJ d'histoire lié voit le personnage lié) ; les triggers se déclenchent toujours
-- (suppression d'un lien histoire par le propriétaire du personnage ; création d'un groupe) ; `pg_temp` est en dernier
-- dans le search_path des 24 fonctions definer listées.
-- Fichier généré. Lancer : supabase test db supabase/tests --local   (BEGIN/ROLLBACK)

begin;

select plan(63);

insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
values ('e0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-grants-a@test.local', now(), now()),
       ('e0000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-grants-b@test.local', now(), now());
insert into public.characters (id, owner_id, name) values ('e1000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 'Perso A');
insert into public.stories (id, user_id, title) values ('e2000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000002', 'Histoire');
insert into public.character_campaigns (id, character_id, story_id) values ('e3000000-0000-4000-8000-000000000001', 'e1000000-0000-4000-8000-000000000001', 'e2000000-0000-4000-8000-000000000001');

select is(has_function_privilege('anon', 'public.owns_character(uuid)', 'execute'), false, 'owns_character : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.owns_character(uuid)'::regprocedure and x.grantee = 0)::int, 0, 'owns_character : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.owns_character(uuid)', 'execute') and has_function_privilege('service_role', 'public.owns_character(uuid)', 'execute'), true, 'owns_character : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.is_group_member(uuid)', 'execute'), false, 'is_group_member : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.is_group_member(uuid)'::regprocedure and x.grantee = 0)::int, 0, 'is_group_member : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.is_group_member(uuid)', 'execute') and has_function_privilege('service_role', 'public.is_group_member(uuid)', 'execute'), true, 'is_group_member : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.is_admin()', 'execute'), false, 'is_admin : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.is_admin()'::regprocedure and x.grantee = 0)::int, 0, 'is_admin : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.is_admin()', 'execute') and has_function_privilege('service_role', 'public.is_admin()', 'execute'), true, 'is_admin : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.group_member_can_read_character(uuid)', 'execute'), false, 'group_member_can_read_character : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.group_member_can_read_character(uuid)'::regprocedure and x.grantee = 0)::int, 0, 'group_member_can_read_character : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.group_member_can_read_character(uuid)', 'execute') and has_function_privilege('service_role', 'public.group_member_can_read_character(uuid)', 'execute'), true, 'group_member_can_read_character : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.story_owner_can_read_character(uuid)', 'execute'), false, 'story_owner_can_read_character : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.story_owner_can_read_character(uuid)'::regprocedure and x.grantee = 0)::int, 0, 'story_owner_can_read_character : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.story_owner_can_read_character(uuid)', 'execute') and has_function_privilege('service_role', 'public.story_owner_can_read_character(uuid)', 'execute'), true, 'story_owner_can_read_character : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.character_owner_can_read_joined_story(uuid)', 'execute'), false, 'character_owner_can_read_joined_story : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.character_owner_can_read_joined_story(uuid)'::regprocedure and x.grantee = 0)::int, 0, 'character_owner_can_read_joined_story : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.character_owner_can_read_joined_story(uuid)', 'execute') and has_function_privilege('service_role', 'public.character_owner_can_read_joined_story(uuid)', 'execute'), true, 'character_owner_can_read_joined_story : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.claim_push_token(text, text)', 'execute'), false, 'claim_push_token : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.claim_push_token(text, text)'::regprocedure and x.grantee = 0)::int, 0, 'claim_push_token : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.claim_push_token(text, text)', 'execute') and has_function_privilege('service_role', 'public.claim_push_token(text, text)', 'execute'), true, 'claim_push_token : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.release_push_token(text)', 'execute'), false, 'release_push_token : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.release_push_token(text)'::regprocedure and x.grantee = 0)::int, 0, 'release_push_token : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.release_push_token(text)', 'execute') and has_function_privilege('service_role', 'public.release_push_token(text)', 'execute'), true, 'release_push_token : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.claim_group_treasure_currency(uuid, uuid, text, integer)', 'execute'), false, 'claim_group_treasure_currency : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.claim_group_treasure_currency(uuid, uuid, text, integer)'::regprocedure and x.grantee = 0)::int, 0, 'claim_group_treasure_currency : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.claim_group_treasure_currency(uuid, uuid, text, integer)', 'execute') and has_function_privilege('service_role', 'public.claim_group_treasure_currency(uuid, uuid, text, integer)', 'execute'), true, 'claim_group_treasure_currency : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.get_group_member_character(uuid, uuid)', 'execute'), false, 'get_group_member_character : anon sans EXECUTE');
select is((select count(*) from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x where p.oid = 'public.get_group_member_character(uuid, uuid)'::regprocedure and x.grantee = 0)::int, 0, 'get_group_member_character : PUBLIC sans EXECUTE');
select is(has_function_privilege('authenticated', 'public.get_group_member_character(uuid, uuid)', 'execute') and has_function_privilege('service_role', 'public.get_group_member_character(uuid, uuid)', 'execute'), true, 'get_group_member_character : authenticated et service_role gardent EXECUTE');
select is(has_function_privilege('anon', 'public.refresh_proposal_counts(uuid)', 'execute') or has_function_privilege('authenticated', 'public.refresh_proposal_counts(uuid)', 'execute'), false, 'refresh_proposal_counts : interne, ni anon ni authenticated');
select is(has_function_privilege('service_role', 'public.refresh_proposal_counts(uuid)', 'execute'), true, 'refresh_proposal_counts : service_role garde EXECUTE');
select is(has_function_privilege('anon', 'public.notify_character_campaign_access_revoked()', 'execute') or has_function_privilege('authenticated', 'public.notify_character_campaign_access_revoked()', 'execute'), false, 'notify_character_campaign_access_revoked : interne, ni anon ni authenticated');
select is(has_function_privilege('service_role', 'public.notify_character_campaign_access_revoked()', 'execute'), true, 'notify_character_campaign_access_revoked : service_role garde EXECUTE');
select is(has_function_privilege('anon', 'public.notify_new_app_version()', 'execute') or has_function_privilege('authenticated', 'public.notify_new_app_version()', 'execute'), false, 'notify_new_app_version : interne, ni anon ni authenticated');
select is(has_function_privilege('service_role', 'public.notify_new_app_version()', 'execute'), true, 'notify_new_app_version : service_role garde EXECUTE');
select is(has_function_privilege('anon', 'public.on_group_created()', 'execute') or has_function_privilege('authenticated', 'public.on_group_created()', 'execute'), false, 'on_group_created : interne, ni anon ni authenticated');
select is(has_function_privilege('service_role', 'public.on_group_created()', 'execute'), true, 'on_group_created : service_role garde EXECUTE');
select is(has_function_privilege('anon', 'public.trg_content_proposals_review()', 'execute') or has_function_privilege('authenticated', 'public.trg_content_proposals_review()', 'execute'), false, 'trg_content_proposals_review : interne, ni anon ni authenticated');
select is(has_function_privilege('service_role', 'public.trg_content_proposals_review()', 'execute'), true, 'trg_content_proposals_review : service_role garde EXECUTE');
select is(has_function_privilege('anon', 'public.trg_refresh_proposal_counts()', 'execute') or has_function_privilege('authenticated', 'public.trg_refresh_proposal_counts()', 'execute'), false, 'trg_refresh_proposal_counts : interne, ni anon ni authenticated');
select is(has_function_privilege('service_role', 'public.trg_refresh_proposal_counts()', 'execute'), true, 'trg_refresh_proposal_counts : service_role garde EXECUTE');
-- Anonyme : appels directs refusés (42501), usages publics conservés.
set local role anon;
select set_config('request.jwt.claims', '', true);
select throws_ok($q$select public.owns_character('e1000000-0000-4000-8000-000000000001')$q$, '42501', 'permission denied for function owns_character', 'anon ne peut plus appeler owns_character');
select throws_ok($q$select public.is_admin()$q$, '42501', 'permission denied for function is_admin', 'anon ne peut plus appeler is_admin');
select throws_ok($q$select public.claim_push_token('x', 'android')$q$, '42501', 'permission denied for function claim_push_token', 'anon ne peut plus appeler claim_push_token');
select throws_ok($q$select public.refresh_proposal_counts('e1000000-0000-4000-8000-000000000001')$q$, '42501', 'permission denied for function refresh_proposal_counts', 'anon ne peut plus appeler refresh_proposal_counts');
select lives_ok($q$select public.get_shared_character('jeton-inexistant')$q$, 'anon garde get_shared_character (partage public)');
select lives_ok($q$select count(*) from public.abilities$q$, 'anon lit toujours la référence');
select lives_ok($q$select count(*) from public.app_versions$q$, 'anon lit toujours app_versions');
select lives_ok($q$select count(*) from public.content_proposals$q$, 'anon lit toujours content_proposals (lecture publique inchangée)');
select is((select count(*) from public.characters)::int, 0, 'anon ne voit aucun personnage');
reset role;
-- Propriétaire connecté : les politiques évaluent toujours les helpers.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"e0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select public.owns_character('e1000000-0000-4000-8000-000000000001')), true, 'authenticated : owns_character fonctionne (propriétaire)');
select is((select count(*) from public.characters)::int, 1, 'propriétaire : voit son personnage (politique + helper)');
select lives_ok($q$select public.claim_push_token('tok-pgtap', 'android')$q$, 'authenticated : claim_push_token fonctionne');
select is((select count(*) from public.user_push_tokens)::int, 1, 'authenticated : son jeton push est enregistré');
select lives_ok($q$select public.release_push_token('tok-pgtap')$q$, 'authenticated : release_push_token fonctionne');
reset role;
-- MJ de l'histoire liée (autre utilisateur).
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"e0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((select count(*) from public.characters)::int, 1, 'MJ de l''histoire liée : voit le personnage lié (story_owner_can_read_character inchangé)');
select is((select public.owns_character('e1000000-0000-4000-8000-000000000001')), false, 'MJ : owns_character faux (il n''est pas propriétaire)');
reset role;
-- Trigger : la suppression du lien par le propriétaire du personnage déclenche toujours notify_*, sans EXECUTE direct.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"e0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok($q$delete from public.character_campaigns where id = 'e3000000-0000-4000-8000-000000000001'$q$, 'authenticated : delete avec trigger notify_character_campaign_access_revoked fonctionne'); 
reset role;
-- Trigger on_group_created : un groupe créé par service_role crée toujours son trésor.
set local role service_role;
insert into public.groups (id, name, owner_id, invite_code) values ('e4000000-0000-4000-8000-000000000001', 'pgTAP grants', 'e0000000-0000-4000-8000-000000000001', 'PGTAPGR1');
select is((select count(*) from public.group_treasure where group_id = 'e4000000-0000-4000-8000-000000000001')::int, 1, 'service_role : on_group_created crée toujours le trésor du groupe');
reset role;
-- Liste blanche : aucune fonction security definer de public (hors shim de test tap_*) n'est exécutable par anon, sauf celles-ci.
select is((select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.prosecdef and p.proname not like 'tap\_%' and has_function_privilege('anon', p.oid, 'execute') and p.proname <> all (array['get_shared_character', 'content_proposals_author_name', 'group_members_display_name', 'proposal_comments_author_name', 'stories_gm_display_name']))::int, 0, 'aucune fonction definer exécutable par anon hors liste blanche');
-- search_path
select is((select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef and p.proname = any (array['apply_level_up','apply_rest','build_character_sheet_json','character_owner_can_read_joined_story','claim_push_token','content_proposals_author_name','create_character','get_group_member_character','get_shared_character','get_translation','group_member_can_read_character','group_members_display_name','is_admin','is_group_member','notify_character_campaign_access_revoked','notify_new_app_version','on_group_created','owns_character','proposal_comments_author_name','refresh_proposal_counts','release_push_token','stories_gm_display_name','story_owner_can_read_character','trg_refresh_proposal_counts']) and p.proconfig = array['search_path=public, pg_temp'])::int, 24, '24 fonctions definer avec search_path = public, pg_temp');
select is((select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef and p.proname = any (array['apply_level_up','apply_rest','build_character_sheet_json','character_owner_can_read_joined_story','claim_push_token','content_proposals_author_name','create_character','get_group_member_character','get_shared_character','get_translation','group_member_can_read_character','group_members_display_name','is_admin','is_group_member','notify_character_campaign_access_revoked','notify_new_app_version','on_group_created','owns_character','proposal_comments_author_name','refresh_proposal_counts','release_push_token','stories_gm_display_name','story_owner_can_read_character','trg_refresh_proposal_counts']) and not (p.proconfig::text ~ 'pg_temp'))::int, 0, 'aucune des 24 fonctions sans pg_temp');

select * from finish();
rollback;
