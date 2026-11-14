-- Phase 0, étape 5 : trigger `characters_set_updated_at` (20261115090000_phase0_characters_updated_at_trigger.sql).
--
-- Couvre : la colonne est mise à jour par un UPDATE réel (sous le rôle `authenticated`, comme le mobile) ; un UPDATE
-- sans changement la laisse intacte ; une valeur `updated_at` envoyée par le client est ignorée ; les autres personnages
-- ne sont pas touchés ; la RLS est inchangée (un tiers ne modifie rien, donc rien ne bouge) ; l'INSERT et le défaut de
-- colonne sont inchangés ; la fonction de trigger n'est exécutable par aucun client ; `characters` reste publiée pour
-- Realtime.
-- Lancer : supabase test db supabase/tests --local   (BEGIN/ROLLBACK)

begin;

select plan(12);

insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
values ('d0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-upd-a@test.local', now(), now()),
       ('d0000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-upd-b@test.local', now(), now());
-- updated_at historique explicite : now() est figé pendant la transaction du test, une valeur ancienne distingue « mis à jour » de « intact ».
insert into public.characters (id, owner_id, name, updated_at)
values ('d1000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-000000000001', 'Perso A', '2020-01-01 00:00:00+00'),
       ('d1000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000002', 'Perso B', '2020-01-01 00:00:00+00');

select is((select count(*) from pg_trigger where tgrelid = 'public.characters'::regclass and tgname = 'characters_set_updated_at' and not tgisinternal)::int,
          1, 'le trigger characters_set_updated_at existe');
select is((select updated_at from public.characters where id = 'd1000000-0000-4000-8000-000000000001'),
          '2020-01-01 00:00:00+00'::timestamptz, 'l''INSERT ne passe pas par le trigger (valeur fournie conservée)');

-- Propriétaire A, rôle authenticated -----------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"d0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

update public.characters set name = name where id = 'd1000000-0000-4000-8000-000000000001';
select is((select updated_at from public.characters where id = 'd1000000-0000-4000-8000-000000000001'),
          '2020-01-01 00:00:00+00'::timestamptz, 'UPDATE sans changement : updated_at intact');

update public.characters set current_hp = 5, temporary_hp = 2 where id = 'd1000000-0000-4000-8000-000000000001';
select ok((select updated_at from public.characters where id = 'd1000000-0000-4000-8000-000000000001') > '2020-01-01 00:00:00+00'::timestamptz,
          'UPDATE réel (PV) : updated_at avancé');
select is((select updated_at from public.characters where id = 'd1000000-0000-4000-8000-000000000001'), now(),
          'updated_at = now() (horloge serveur)');
select is((select current_hp from public.characters where id = 'd1000000-0000-4000-8000-000000000001'), 5,
          'la donnée modifiée est bien écrite (contrat inchangé)');

-- Valeur envoyée par le client : ignorée.
update public.characters set updated_at = '2001-01-01 00:00:00+00', name = 'Renommé' where id = 'd1000000-0000-4000-8000-000000000001';
select is((select updated_at from public.characters where id = 'd1000000-0000-4000-8000-000000000001'), now(),
          'updated_at envoyé par le client : la valeur serveur l''emporte');

-- Une écriture « no-op » avec updated_at envoyé : la valeur ancienne est conservée, pas celle du client.
update public.characters set updated_at = '2030-01-01 00:00:00+00' where id = 'd1000000-0000-4000-8000-000000000002';
select is((select updated_at from public.characters where id = 'd1000000-0000-4000-8000-000000000002'), null::timestamptz,
          'RLS inchangée : A ne voit pas le personnage de B (aucune ligne visible)');
reset role;
select is((select updated_at from public.characters where id = 'd1000000-0000-4000-8000-000000000002'),
          '2020-01-01 00:00:00+00'::timestamptz, 'le personnage de B n''a pas bougé');

-- Fonction de trigger : aucun client ne peut l'appeler -----------------------------------------
select is(has_function_privilege('authenticated', 'public.characters_touch_updated_at()', 'execute')
          or has_function_privilege('anon', 'public.characters_touch_updated_at()', 'execute'), false,
          'characters_touch_updated_at() : ni authenticated ni anon');
select is((select proconfig from pg_proc where oid = 'public.characters_touch_updated_at()'::regprocedure), array['search_path=public, pg_temp'],
          'characters_touch_updated_at() : search_path fixé avec pg_temp en dernier');

-- Realtime : characters reste publiée.
select is((select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'characters')::int,
          1, 'characters toujours publiée pour Realtime');

select * from finish();
rollback;
