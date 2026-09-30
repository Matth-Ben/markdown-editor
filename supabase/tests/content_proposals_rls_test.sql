-- Vérifie la RLS, les privilèges et les triggers de content_proposals,
-- proposal_comments et proposal_votes (20260919090000_create_content_proposals.sql).
-- Même méthodologie que supabase/tests/bug_reports_rls_test.sql : fixtures en
-- rôle postgres, puis `set local role` + `request.jwt.claims` pour simuler ce
-- que voit PostgREST pour un visiteur (anon), un membre (A, B) ou l'admin.
--
-- Lancer : node_modules/.bin/supabase test db supabase/tests --local
-- BEGIN/ROLLBACK : aucune donnée de test ne persiste.

begin;

select plan(31);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('aaaaaaaa-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-author-a@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{"full_name": "Alice"}', now(), now()),
  ('bbbbbbbb-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-member-b@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now()),
  ('cccccccc-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pgtap-admin@test.local', crypt('password123', gen_salt('bf')), now(), '{}', '{}', now(), now());

insert into public.app_admins (user_id) values ('cccccccc-0000-0000-0000-00000000000c');

-- ---------------------------------------------------------------- A propose
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'aaaaaaaa-0000-0000-0000-00000000000a', 'role', 'authenticated')::text, true);

select lives_ok(
  $$ insert into public.content_proposals (id, author_id, content_type, title, payload)
     values ('11111111-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-00000000000a', 'spell', 'Boule de test', '{"description": "x"}') $$,
  'Un membre peut proposer du contenu pour lui-même (statut pending par défaut)'
);

select throws_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload)
     values ('bbbbbbbb-0000-0000-0000-00000000000b', 'spell', 'Usurpation', '{}') $$,
  '42501', null,
  'On ne peut pas proposer au nom d''un autre utilisateur'
);

select throws_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload, status)
     values ('aaaaaaaa-0000-0000-0000-00000000000a', 'spell', 'Auto-approuvé', '{}', 'approved') $$,
  '42501', null,
  'On ne peut pas créer une proposition déjà approuvée'
);

select throws_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload, votes_up)
     values ('aaaaaaaa-0000-0000-0000-00000000000a', 'spell', 'Votes truqués', '{}', 50) $$,
  '42501', null,
  'On ne peut pas créer une proposition avec des votes préremplis'
);

select throws_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload)
     values ('aaaaaaaa-0000-0000-0000-00000000000a', 'monster', 'Type inconnu', '{}') $$,
  '23514', null,
  'Le type de contenu est limité à spell/feat/item'
);

select lives_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload)
     values ('aaaaaaaa-0000-0000-0000-00000000000a', 'race', 'Race de test', '{"size": "Moyenne"}'),
            ('aaaaaaaa-0000-0000-0000-00000000000a', 'class', 'Classe de test', '{"hit_die": 8}') $$,
  'Les types race et class sont acceptés'
);

select lives_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload)
     values ('aaaaaaaa-0000-0000-0000-00000000000a', 'class', 'Classe volumineuse',
             jsonb_build_object('blob', repeat('x', 40000))) $$,
  'Un contenu volumineux (40 000 octets) est accepté jusqu''à la nouvelle borne'
);

select throws_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload)
     values ('aaaaaaaa-0000-0000-0000-00000000000a', 'class', 'Trop gros',
             jsonb_build_object('blob', repeat('x', 70000))) $$,
  '23514', null,
  'Un contenu de plus de 60 000 octets reste refusé'
);

select throws_ok(
  $$ update public.content_proposals set title = 'Modifié' where id = '11111111-0000-0000-0000-000000000001' $$,
  '42501', null,
  'Même l''auteur ne peut pas modifier le contenu de sa proposition (seuls les champs de décision sont modifiables)'
);

select throws_ok(
  $$ insert into public.proposal_votes (proposal_id, user_id, vote)
     values ('11111111-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-00000000000a', 'up') $$,
  '42501', null,
  'L''auteur ne peut pas voter pour sa propre proposition'
);

reset role;

-- --------------------------------------------------------------- visiteur
set local role anon;
select set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);

select is(
  (select count(*)::int from public.content_proposals),
  4,
  'Un visiteur non connecté peut lire les propositions'
);

select is(
  (select public.content_proposals_author_name(p) from public.content_proposals p where p.id = '11111111-0000-0000-0000-000000000001'),
  'Alice',
  'Le nom d''affichage (full_name) est exposé, jamais l''e-mail'
);

select throws_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload)
     values ('aaaaaaaa-0000-0000-0000-00000000000a', 'spell', 'Anonyme', '{}') $$,
  '42501', null,
  'Un visiteur non connecté ne peut pas proposer'
);

select throws_ok(
  $$ select * from public.proposal_votes $$,
  '42501', null,
  'Un visiteur non connecté ne peut pas lire les votes'
);

reset role;

-- ------------------------------------------------------------------- B vote
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'bbbbbbbb-0000-0000-0000-00000000000b', 'role', 'authenticated')::text, true);

select lives_ok(
  $$ insert into public.proposal_votes (proposal_id, user_id, vote)
     values ('11111111-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-00000000000b', 'up') $$,
  'Un membre peut voter pour la proposition d''un autre'
);

select is(
  (select votes_up from public.content_proposals where id = '11111111-0000-0000-0000-000000000001'),
  1,
  'Le compteur votes_up est mis à jour par trigger'
);

select throws_ok(
  $$ insert into public.proposal_votes (proposal_id, user_id, vote)
     values ('11111111-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-00000000000b', 'down') $$,
  '23505', null,
  'Un second vote du même membre est refusé par la clé primaire (un vote par personne)'
);

update public.proposal_votes set vote = 'down'
  where proposal_id = '11111111-0000-0000-0000-000000000001' and user_id = 'bbbbbbbb-0000-0000-0000-00000000000b';

select is(
  (select votes_up::text || '/' || votes_down::text from public.content_proposals where id = '11111111-0000-0000-0000-000000000001'),
  '0/1',
  'Changer son vote déplace le compteur (0 pour / 1 contre)'
);

update public.content_proposals set status = 'approved' where id = '11111111-0000-0000-0000-000000000001';

select is(
  (select status from public.content_proposals where id = '11111111-0000-0000-0000-000000000001'),
  'pending',
  'Un membre ordinaire ne peut pas approuver : la RLS filtre la ligne, le statut reste pending'
);

select lives_ok(
  $$ insert into public.proposal_comments (proposal_id, author_id, body)
     values ('11111111-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-00000000000b', 'Bonne idée, mais trop puissant.') $$,
  'Un membre peut commenter'
);

select is(
  (select comments_count from public.content_proposals where id = '11111111-0000-0000-0000-000000000001'),
  1,
  'Le compteur comments_count est mis à jour par trigger'
);

reset role;

-- ----------------------------------------------------------------- A relit
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'aaaaaaaa-0000-0000-0000-00000000000a', 'role', 'authenticated')::text, true);

select is(
  (select count(*)::int from public.proposal_votes),
  0,
  'A ne voit pas le vote de B (chacun ne lit que son propre vote)'
);

delete from public.proposal_comments where author_id = 'bbbbbbbb-0000-0000-0000-00000000000b';
reset role;

select is(
  (select count(*)::int from public.proposal_comments),
  1,
  'A ne peut pas supprimer le commentaire de B'
);

-- ------------------------------------------------------------- admin décide
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'cccccccc-0000-0000-0000-00000000000c', 'role', 'authenticated')::text, true);

select throws_ok(
  $$ update public.content_proposals set status = 'approved', rejection_reason = 'incohérent' where id = '11111111-0000-0000-0000-000000000001' $$,
  '23514', null,
  'Un motif de refus n''est accepté que pour le statut rejected'
);

update public.content_proposals set status = 'approved' where id = '11111111-0000-0000-0000-000000000001';

select is(
  (select status || ':' || (reviewed_by = 'cccccccc-0000-0000-0000-00000000000c')::text from public.content_proposals where id = '11111111-0000-0000-0000-000000000001'),
  'approved:true',
  'L''admin peut approuver ; reviewed_by est posé par la base'
);

reset role;

-- ------------------------------------------------- après approbation, B
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'bbbbbbbb-0000-0000-0000-00000000000b', 'role', 'authenticated')::text, true);

select throws_ok(
  $$ update public.proposal_votes set vote = 'up' where proposal_id = '11111111-0000-0000-0000-000000000001' $$,
  '42501', null,
  'On ne peut plus changer son vote une fois la proposition décidée'
);

reset role;

-- --------------------------------------------- A supprime une proposition
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'aaaaaaaa-0000-0000-0000-00000000000a', 'role', 'authenticated')::text, true);

insert into public.content_proposals (id, author_id, content_type, title, payload)
values ('11111111-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-00000000000a', 'feat', 'Brouillon à retirer', '{}');
delete from public.content_proposals where id = '11111111-0000-0000-0000-000000000002';
delete from public.content_proposals where id = '11111111-0000-0000-0000-000000000001';

reset role;

select is(
  (select count(*)::int from public.content_proposals where id = '11111111-0000-0000-0000-000000000002'),
  0,
  'L''auteur peut retirer sa proposition en attente'
);

select is(
  (select count(*)::int from public.content_proposals where id = '11111111-0000-0000-0000-000000000001'),
  1,
  'L''auteur ne peut plus supprimer une proposition déjà décidée'
);

-- ------------------------------------- propositions de modification (target_id)
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'aaaaaaaa-0000-0000-0000-00000000000a', 'role', 'authenticated')::text, true);

select lives_ok(
  $$ insert into public.content_proposals (id, author_id, content_type, title, payload, target_id)
     values ('11111111-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-00000000000a', 'spell', 'Acide fusant (révisé)', '{"description": "x"}', 1) $$,
  'Un membre peut proposer la modification d''un élément existant (target_id)'
);

select throws_ok(
  $$ insert into public.content_proposals (author_id, content_type, title, payload, target_id)
     values ('aaaaaaaa-0000-0000-0000-00000000000a', 'spell', 'Cible invalide', '{}', 0) $$,
  '23514', null,
  'Une cible invalide (0) est refusée'
);

reset role;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', 'cccccccc-0000-0000-0000-00000000000c', 'role', 'authenticated')::text, true);

select throws_ok(
  $$ update public.content_proposals set target_id = 5 where id = '11111111-0000-0000-0000-000000000003' $$,
  '42501', null,
  'La cible n''est jamais modifiable après coup, même par l''admin (privilège de colonne)'
);

reset role;

select * from finish();

rollback;
