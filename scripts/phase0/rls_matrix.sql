\set ON_ERROR_STOP off
begin;
insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values ('a0000000-0000-4000-8000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'matrix-a@test.local', now(), now());
insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values ('a0000000-0000-4000-8000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'matrix-b@test.local', now(), now());
insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values ('a0000000-0000-4000-8000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'matrix-c@test.local', now(), now());
insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values ('a0000000-0000-4000-8000-00000000000d', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'matrix-d@test.local', now(), now());
insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at) values ('a0000000-0000-4000-8000-00000000000e', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'matrix-e@test.local', now(), now());
insert into public.characters (id, owner_id, name) values ('c0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-00000000000a', 'cA'), ('c0000000-0000-4000-8000-00000000000b', 'a0000000-0000-4000-8000-00000000000b', 'cB'), ('c0000000-0000-4000-8000-00000000000d', 'a0000000-0000-4000-8000-00000000000d', 'cD');
insert into public.groups (id, name, owner_id, invite_code) values ('b0000000-0000-4000-8000-000000000001', 'g1', 'a0000000-0000-4000-8000-00000000000c', 'MATRIX01'), ('b0000000-0000-4000-8000-000000000002', 'g2', 'a0000000-0000-4000-8000-00000000000d', 'MATRIX02');
insert into public.group_members (group_id, user_id, character_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-00000000000a', 'membre'), ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000b', 'c0000000-0000-4000-8000-00000000000b', 'membre'), ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-00000000000d', 'c0000000-0000-4000-8000-00000000000d', 'membre') on conflict do nothing;
insert into public.group_treasure (group_id) values ('b0000000-0000-4000-8000-000000000001'), ('b0000000-0000-4000-8000-000000000002') on conflict do nothing;
insert into public.group_notes (group_id, user_id, character_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-00000000000a', 'na'), ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000b', 'c0000000-0000-4000-8000-00000000000b', 'nb'), ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-00000000000d', 'c0000000-0000-4000-8000-00000000000d', 'nd');
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'ja'), ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000b', 'jb'), ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-00000000000d', 'jd');
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000a', 'ta', 'da', 'mineur'), ('a0000000-0000-4000-8000-00000000000d', 'td', 'dd', 'mineur');
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000a'), ('a0000000-0000-4000-8000-00000000000d');
insert into public.user_push_tokens (token, user_id, platform) values ('tok-a', 'a0000000-0000-4000-8000-00000000000a', 'android'), ('tok-d', 'a0000000-0000-4000-8000-00000000000d', 'ios');
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000a', 'ia'), ('c0000000-0000-4000-8000-00000000000b', 'ib'), ('c0000000-0000-4000-8000-00000000000d', 'id');
insert into public.character_spells (character_id, spell_id, status) select 'c0000000-0000-4000-8000-00000000000a'::uuid, min(id), 'connu' from public.spells union all select 'c0000000-0000-4000-8000-00000000000d'::uuid, min(id), 'connu' from public.spells;

\echo ##### profil anon
set local role anon;
select set_config('request.jwt.claims', '', true) as claims \gset
\echo -- characters
select 'characters' as t, count(*) as lignes, md5(coalesce(string_agg(id::text, ',' order by id::text), '')) as empreinte from public.characters;
savepoint s;
update public.characters set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.characters;
rollback to savepoint s;
\echo insert characters pour soi
savepoint s;
insert into public.characters (owner_id, name) values ('00000000-0000-0000-0000-000000000000', 'nouveau');
rollback to savepoint s;
\echo insert characters pour autre
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_inventory
select 'character_inventory' as t, count(*) as lignes, md5(coalesce(string_agg(custom_name::text, ',' order by custom_name::text), '')) as empreinte from public.character_inventory;
savepoint s;
update public.character_inventory set custom_name = custom_name || '!';
rollback to savepoint s;
savepoint s;
delete from public.character_inventory;
rollback to savepoint s;
\echo insert character_inventory pour soi
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo insert character_inventory pour autre
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_spells
select 'character_spells' as t, count(*) as lignes, md5(coalesce(string_agg(character_id::text, ',' order by character_id::text), '')) as empreinte from public.character_spells;
savepoint s;
update public.character_spells set is_favorite = not is_favorite;
rollback to savepoint s;
savepoint s;
delete from public.character_spells;
rollback to savepoint s;
\echo -- groups
select 'groups' as t, count(*) as lignes, md5(coalesce(string_agg(name::text, ',' order by name::text), '')) as empreinte from public.groups;
savepoint s;
update public.groups set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.groups;
rollback to savepoint s;
\echo insert groups pour soi
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', '00000000-0000-0000-0000-000000000000', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo insert groups pour autre
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000d', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo -- group_members
select 'group_members' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.group_members;
savepoint s;
update public.group_members set role = role;
rollback to savepoint s;
savepoint s;
delete from public.group_members;
rollback to savepoint s;
\echo insert group_members pour soi
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'membre');
rollback to savepoint s;
\echo insert group_members pour autre
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'membre');
rollback to savepoint s;
\echo -- group_treasure
select 'group_treasure' as t, count(*) as lignes, md5(coalesce(string_agg(group_id::text, ',' order by group_id::text), '')) as empreinte from public.group_treasure;
savepoint s;
update public.group_treasure set currency_gp = currency_gp + 1;
rollback to savepoint s;
savepoint s;
delete from public.group_treasure;
rollback to savepoint s;
\echo -- group_notes
select 'group_notes' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_notes;
savepoint s;
update public.group_notes set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_notes;
rollback to savepoint s;
\echo insert group_notes pour soi
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'nouveau');
rollback to savepoint s;
\echo insert group_notes pour autre
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- group_journal_entries
select 'group_journal_entries' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_journal_entries;
savepoint s;
update public.group_journal_entries set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_journal_entries;
rollback to savepoint s;
\echo insert group_journal_entries pour soi
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'nouveau');
rollback to savepoint s;
\echo insert group_journal_entries pour autre
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- bug_reports
select 'bug_reports' as t, count(*) as lignes, md5(coalesce(string_agg(title::text, ',' order by title::text), '')) as empreinte from public.bug_reports;
savepoint s;
update public.bug_reports set title = title || '!';
rollback to savepoint s;
savepoint s;
delete from public.bug_reports;
rollback to savepoint s;
\echo insert bug_reports pour soi
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('00000000-0000-0000-0000-000000000000', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo insert bug_reports pour autre
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000d', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo -- notification_preferences
select 'notification_preferences' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.notification_preferences;
savepoint s;
update public.notification_preferences set push_enabled = push_enabled;
rollback to savepoint s;
savepoint s;
delete from public.notification_preferences;
rollback to savepoint s;
\echo insert notification_preferences pour soi
savepoint s;
insert into public.notification_preferences (user_id) values ('00000000-0000-0000-0000-000000000000');
rollback to savepoint s;
\echo insert notification_preferences pour autre
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000d');
rollback to savepoint s;
\echo -- user_push_tokens
select 'user_push_tokens' as t, count(*) as lignes, md5(coalesce(string_agg(token::text, ',' order by token::text), '')) as empreinte from public.user_push_tokens;
savepoint s;
update public.user_push_tokens set platform = platform;
rollback to savepoint s;
savepoint s;
delete from public.user_push_tokens;
rollback to savepoint s;
\echo insert user_push_tokens pour soi
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), '00000000-0000-0000-0000-000000000000', 'ios');
rollback to savepoint s;
\echo insert user_push_tokens pour autre
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000d', 'ios');
rollback to savepoint s;
reset role;
\echo ##### profil A
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000a","role":"authenticated"}', true) as claims \gset
\echo -- characters
select 'characters' as t, count(*) as lignes, md5(coalesce(string_agg(id::text, ',' order by id::text), '')) as empreinte from public.characters;
savepoint s;
update public.characters set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.characters;
rollback to savepoint s;
\echo insert characters pour soi
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo insert characters pour autre
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_inventory
select 'character_inventory' as t, count(*) as lignes, md5(coalesce(string_agg(custom_name::text, ',' order by custom_name::text), '')) as empreinte from public.character_inventory;
savepoint s;
update public.character_inventory set custom_name = custom_name || '!';
rollback to savepoint s;
savepoint s;
delete from public.character_inventory;
rollback to savepoint s;
\echo insert character_inventory pour soi
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo insert character_inventory pour autre
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_spells
select 'character_spells' as t, count(*) as lignes, md5(coalesce(string_agg(character_id::text, ',' order by character_id::text), '')) as empreinte from public.character_spells;
savepoint s;
update public.character_spells set is_favorite = not is_favorite;
rollback to savepoint s;
savepoint s;
delete from public.character_spells;
rollback to savepoint s;
\echo -- groups
select 'groups' as t, count(*) as lignes, md5(coalesce(string_agg(name::text, ',' order by name::text), '')) as empreinte from public.groups;
savepoint s;
update public.groups set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.groups;
rollback to savepoint s;
\echo insert groups pour soi
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000a', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo insert groups pour autre
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000d', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo -- group_members
select 'group_members' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.group_members;
savepoint s;
update public.group_members set role = role;
rollback to savepoint s;
savepoint s;
delete from public.group_members;
rollback to savepoint s;
\echo insert group_members pour soi
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'membre');
rollback to savepoint s;
\echo insert group_members pour autre
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'membre');
rollback to savepoint s;
\echo -- group_treasure
select 'group_treasure' as t, count(*) as lignes, md5(coalesce(string_agg(group_id::text, ',' order by group_id::text), '')) as empreinte from public.group_treasure;
savepoint s;
update public.group_treasure set currency_gp = currency_gp + 1;
rollback to savepoint s;
savepoint s;
delete from public.group_treasure;
rollback to savepoint s;
\echo -- group_notes
select 'group_notes' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_notes;
savepoint s;
update public.group_notes set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_notes;
rollback to savepoint s;
\echo insert group_notes pour soi
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo insert group_notes pour autre
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- group_journal_entries
select 'group_journal_entries' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_journal_entries;
savepoint s;
update public.group_journal_entries set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_journal_entries;
rollback to savepoint s;
\echo insert group_journal_entries pour soi
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo insert group_journal_entries pour autre
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- bug_reports
select 'bug_reports' as t, count(*) as lignes, md5(coalesce(string_agg(title::text, ',' order by title::text), '')) as empreinte from public.bug_reports;
savepoint s;
update public.bug_reports set title = title || '!';
rollback to savepoint s;
savepoint s;
delete from public.bug_reports;
rollback to savepoint s;
\echo insert bug_reports pour soi
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000a', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo insert bug_reports pour autre
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000d', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo -- notification_preferences
select 'notification_preferences' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.notification_preferences;
savepoint s;
update public.notification_preferences set push_enabled = push_enabled;
rollback to savepoint s;
savepoint s;
delete from public.notification_preferences;
rollback to savepoint s;
\echo insert notification_preferences pour soi
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000a');
rollback to savepoint s;
\echo insert notification_preferences pour autre
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000d');
rollback to savepoint s;
\echo -- user_push_tokens
select 'user_push_tokens' as t, count(*) as lignes, md5(coalesce(string_agg(token::text, ',' order by token::text), '')) as empreinte from public.user_push_tokens;
savepoint s;
update public.user_push_tokens set platform = platform;
rollback to savepoint s;
savepoint s;
delete from public.user_push_tokens;
rollback to savepoint s;
\echo insert user_push_tokens pour soi
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000a', 'ios');
rollback to savepoint s;
\echo insert user_push_tokens pour autre
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000d', 'ios');
rollback to savepoint s;
reset role;
\echo ##### profil B
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000b","role":"authenticated"}', true) as claims \gset
\echo -- characters
select 'characters' as t, count(*) as lignes, md5(coalesce(string_agg(id::text, ',' order by id::text), '')) as empreinte from public.characters;
savepoint s;
update public.characters set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.characters;
rollback to savepoint s;
\echo insert characters pour soi
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000b', 'nouveau');
rollback to savepoint s;
\echo insert characters pour autre
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_inventory
select 'character_inventory' as t, count(*) as lignes, md5(coalesce(string_agg(custom_name::text, ',' order by custom_name::text), '')) as empreinte from public.character_inventory;
savepoint s;
update public.character_inventory set custom_name = custom_name || '!';
rollback to savepoint s;
savepoint s;
delete from public.character_inventory;
rollback to savepoint s;
\echo insert character_inventory pour soi
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000b', 'nouveau');
rollback to savepoint s;
\echo insert character_inventory pour autre
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_spells
select 'character_spells' as t, count(*) as lignes, md5(coalesce(string_agg(character_id::text, ',' order by character_id::text), '')) as empreinte from public.character_spells;
savepoint s;
update public.character_spells set is_favorite = not is_favorite;
rollback to savepoint s;
savepoint s;
delete from public.character_spells;
rollback to savepoint s;
\echo -- groups
select 'groups' as t, count(*) as lignes, md5(coalesce(string_agg(name::text, ',' order by name::text), '')) as empreinte from public.groups;
savepoint s;
update public.groups set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.groups;
rollback to savepoint s;
\echo insert groups pour soi
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000b', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo insert groups pour autre
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000d', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo -- group_members
select 'group_members' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.group_members;
savepoint s;
update public.group_members set role = role;
rollback to savepoint s;
savepoint s;
delete from public.group_members;
rollback to savepoint s;
\echo insert group_members pour soi
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000b', 'membre');
rollback to savepoint s;
\echo insert group_members pour autre
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'membre');
rollback to savepoint s;
\echo -- group_treasure
select 'group_treasure' as t, count(*) as lignes, md5(coalesce(string_agg(group_id::text, ',' order by group_id::text), '')) as empreinte from public.group_treasure;
savepoint s;
update public.group_treasure set currency_gp = currency_gp + 1;
rollback to savepoint s;
savepoint s;
delete from public.group_treasure;
rollback to savepoint s;
\echo -- group_notes
select 'group_notes' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_notes;
savepoint s;
update public.group_notes set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_notes;
rollback to savepoint s;
\echo insert group_notes pour soi
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000b', 'nouveau');
rollback to savepoint s;
\echo insert group_notes pour autre
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- group_journal_entries
select 'group_journal_entries' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_journal_entries;
savepoint s;
update public.group_journal_entries set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_journal_entries;
rollback to savepoint s;
\echo insert group_journal_entries pour soi
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000b', 'nouveau');
rollback to savepoint s;
\echo insert group_journal_entries pour autre
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- bug_reports
select 'bug_reports' as t, count(*) as lignes, md5(coalesce(string_agg(title::text, ',' order by title::text), '')) as empreinte from public.bug_reports;
savepoint s;
update public.bug_reports set title = title || '!';
rollback to savepoint s;
savepoint s;
delete from public.bug_reports;
rollback to savepoint s;
\echo insert bug_reports pour soi
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000b', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo insert bug_reports pour autre
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000d', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo -- notification_preferences
select 'notification_preferences' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.notification_preferences;
savepoint s;
update public.notification_preferences set push_enabled = push_enabled;
rollback to savepoint s;
savepoint s;
delete from public.notification_preferences;
rollback to savepoint s;
\echo insert notification_preferences pour soi
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000b');
rollback to savepoint s;
\echo insert notification_preferences pour autre
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000d');
rollback to savepoint s;
\echo -- user_push_tokens
select 'user_push_tokens' as t, count(*) as lignes, md5(coalesce(string_agg(token::text, ',' order by token::text), '')) as empreinte from public.user_push_tokens;
savepoint s;
update public.user_push_tokens set platform = platform;
rollback to savepoint s;
savepoint s;
delete from public.user_push_tokens;
rollback to savepoint s;
\echo insert user_push_tokens pour soi
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000b', 'ios');
rollback to savepoint s;
\echo insert user_push_tokens pour autre
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000d', 'ios');
rollback to savepoint s;
reset role;
\echo ##### profil C
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000c","role":"authenticated"}', true) as claims \gset
\echo -- characters
select 'characters' as t, count(*) as lignes, md5(coalesce(string_agg(id::text, ',' order by id::text), '')) as empreinte from public.characters;
savepoint s;
update public.characters set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.characters;
rollback to savepoint s;
\echo insert characters pour soi
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000c', 'nouveau');
rollback to savepoint s;
\echo insert characters pour autre
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_inventory
select 'character_inventory' as t, count(*) as lignes, md5(coalesce(string_agg(custom_name::text, ',' order by custom_name::text), '')) as empreinte from public.character_inventory;
savepoint s;
update public.character_inventory set custom_name = custom_name || '!';
rollback to savepoint s;
savepoint s;
delete from public.character_inventory;
rollback to savepoint s;
\echo insert character_inventory pour soi
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo insert character_inventory pour autre
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_spells
select 'character_spells' as t, count(*) as lignes, md5(coalesce(string_agg(character_id::text, ',' order by character_id::text), '')) as empreinte from public.character_spells;
savepoint s;
update public.character_spells set is_favorite = not is_favorite;
rollback to savepoint s;
savepoint s;
delete from public.character_spells;
rollback to savepoint s;
\echo -- groups
select 'groups' as t, count(*) as lignes, md5(coalesce(string_agg(name::text, ',' order by name::text), '')) as empreinte from public.groups;
savepoint s;
update public.groups set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.groups;
rollback to savepoint s;
\echo insert groups pour soi
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000c', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo insert groups pour autre
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000d', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo -- group_members
select 'group_members' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.group_members;
savepoint s;
update public.group_members set role = role;
rollback to savepoint s;
savepoint s;
delete from public.group_members;
rollback to savepoint s;
\echo insert group_members pour soi
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000c', 'membre');
rollback to savepoint s;
\echo insert group_members pour autre
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'membre');
rollback to savepoint s;
\echo -- group_treasure
select 'group_treasure' as t, count(*) as lignes, md5(coalesce(string_agg(group_id::text, ',' order by group_id::text), '')) as empreinte from public.group_treasure;
savepoint s;
update public.group_treasure set currency_gp = currency_gp + 1;
rollback to savepoint s;
savepoint s;
delete from public.group_treasure;
rollback to savepoint s;
\echo -- group_notes
select 'group_notes' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_notes;
savepoint s;
update public.group_notes set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_notes;
rollback to savepoint s;
\echo insert group_notes pour soi
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000c', 'nouveau');
rollback to savepoint s;
\echo insert group_notes pour autre
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- group_journal_entries
select 'group_journal_entries' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_journal_entries;
savepoint s;
update public.group_journal_entries set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_journal_entries;
rollback to savepoint s;
\echo insert group_journal_entries pour soi
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000c', 'nouveau');
rollback to savepoint s;
\echo insert group_journal_entries pour autre
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- bug_reports
select 'bug_reports' as t, count(*) as lignes, md5(coalesce(string_agg(title::text, ',' order by title::text), '')) as empreinte from public.bug_reports;
savepoint s;
update public.bug_reports set title = title || '!';
rollback to savepoint s;
savepoint s;
delete from public.bug_reports;
rollback to savepoint s;
\echo insert bug_reports pour soi
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000c', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo insert bug_reports pour autre
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000d', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo -- notification_preferences
select 'notification_preferences' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.notification_preferences;
savepoint s;
update public.notification_preferences set push_enabled = push_enabled;
rollback to savepoint s;
savepoint s;
delete from public.notification_preferences;
rollback to savepoint s;
\echo insert notification_preferences pour soi
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000c');
rollback to savepoint s;
\echo insert notification_preferences pour autre
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000d');
rollback to savepoint s;
\echo -- user_push_tokens
select 'user_push_tokens' as t, count(*) as lignes, md5(coalesce(string_agg(token::text, ',' order by token::text), '')) as empreinte from public.user_push_tokens;
savepoint s;
update public.user_push_tokens set platform = platform;
rollback to savepoint s;
savepoint s;
delete from public.user_push_tokens;
rollback to savepoint s;
\echo insert user_push_tokens pour soi
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000c', 'ios');
rollback to savepoint s;
\echo insert user_push_tokens pour autre
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000d', 'ios');
rollback to savepoint s;
reset role;
\echo ##### profil D
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000d","role":"authenticated"}', true) as claims \gset
\echo -- characters
select 'characters' as t, count(*) as lignes, md5(coalesce(string_agg(id::text, ',' order by id::text), '')) as empreinte from public.characters;
savepoint s;
update public.characters set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.characters;
rollback to savepoint s;
\echo insert characters pour soi
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo insert characters pour autre
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo -- character_inventory
select 'character_inventory' as t, count(*) as lignes, md5(coalesce(string_agg(custom_name::text, ',' order by custom_name::text), '')) as empreinte from public.character_inventory;
savepoint s;
update public.character_inventory set custom_name = custom_name || '!';
rollback to savepoint s;
savepoint s;
delete from public.character_inventory;
rollback to savepoint s;
\echo insert character_inventory pour soi
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo insert character_inventory pour autre
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo -- character_spells
select 'character_spells' as t, count(*) as lignes, md5(coalesce(string_agg(character_id::text, ',' order by character_id::text), '')) as empreinte from public.character_spells;
savepoint s;
update public.character_spells set is_favorite = not is_favorite;
rollback to savepoint s;
savepoint s;
delete from public.character_spells;
rollback to savepoint s;
\echo -- groups
select 'groups' as t, count(*) as lignes, md5(coalesce(string_agg(name::text, ',' order by name::text), '')) as empreinte from public.groups;
savepoint s;
update public.groups set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.groups;
rollback to savepoint s;
\echo insert groups pour soi
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000d', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo insert groups pour autre
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000a', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo -- group_members
select 'group_members' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.group_members;
savepoint s;
update public.group_members set role = role;
rollback to savepoint s;
savepoint s;
delete from public.group_members;
rollback to savepoint s;
\echo insert group_members pour soi
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'membre');
rollback to savepoint s;
\echo insert group_members pour autre
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'membre');
rollback to savepoint s;
\echo -- group_treasure
select 'group_treasure' as t, count(*) as lignes, md5(coalesce(string_agg(group_id::text, ',' order by group_id::text), '')) as empreinte from public.group_treasure;
savepoint s;
update public.group_treasure set currency_gp = currency_gp + 1;
rollback to savepoint s;
savepoint s;
delete from public.group_treasure;
rollback to savepoint s;
\echo -- group_notes
select 'group_notes' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_notes;
savepoint s;
update public.group_notes set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_notes;
rollback to savepoint s;
\echo insert group_notes pour soi
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo insert group_notes pour autre
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo -- group_journal_entries
select 'group_journal_entries' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_journal_entries;
savepoint s;
update public.group_journal_entries set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_journal_entries;
rollback to savepoint s;
\echo insert group_journal_entries pour soi
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo insert group_journal_entries pour autre
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo -- bug_reports
select 'bug_reports' as t, count(*) as lignes, md5(coalesce(string_agg(title::text, ',' order by title::text), '')) as empreinte from public.bug_reports;
savepoint s;
update public.bug_reports set title = title || '!';
rollback to savepoint s;
savepoint s;
delete from public.bug_reports;
rollback to savepoint s;
\echo insert bug_reports pour soi
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000d', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo insert bug_reports pour autre
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000a', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo -- notification_preferences
select 'notification_preferences' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.notification_preferences;
savepoint s;
update public.notification_preferences set push_enabled = push_enabled;
rollback to savepoint s;
savepoint s;
delete from public.notification_preferences;
rollback to savepoint s;
\echo insert notification_preferences pour soi
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000d');
rollback to savepoint s;
\echo insert notification_preferences pour autre
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000a');
rollback to savepoint s;
\echo -- user_push_tokens
select 'user_push_tokens' as t, count(*) as lignes, md5(coalesce(string_agg(token::text, ',' order by token::text), '')) as empreinte from public.user_push_tokens;
savepoint s;
update public.user_push_tokens set platform = platform;
rollback to savepoint s;
savepoint s;
delete from public.user_push_tokens;
rollback to savepoint s;
\echo insert user_push_tokens pour soi
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000d', 'ios');
rollback to savepoint s;
\echo insert user_push_tokens pour autre
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000a', 'ios');
rollback to savepoint s;
reset role;
\echo ##### profil E
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000e","role":"authenticated"}', true) as claims \gset
\echo -- characters
select 'characters' as t, count(*) as lignes, md5(coalesce(string_agg(id::text, ',' order by id::text), '')) as empreinte from public.characters;
savepoint s;
update public.characters set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.characters;
rollback to savepoint s;
\echo insert characters pour soi
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000e', 'nouveau');
rollback to savepoint s;
\echo insert characters pour autre
savepoint s;
insert into public.characters (owner_id, name) values ('a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_inventory
select 'character_inventory' as t, count(*) as lignes, md5(coalesce(string_agg(custom_name::text, ',' order by custom_name::text), '')) as empreinte from public.character_inventory;
savepoint s;
update public.character_inventory set custom_name = custom_name || '!';
rollback to savepoint s;
savepoint s;
delete from public.character_inventory;
rollback to savepoint s;
\echo insert character_inventory pour soi
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000a', 'nouveau');
rollback to savepoint s;
\echo insert character_inventory pour autre
savepoint s;
insert into public.character_inventory (character_id, custom_name) values ('c0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- character_spells
select 'character_spells' as t, count(*) as lignes, md5(coalesce(string_agg(character_id::text, ',' order by character_id::text), '')) as empreinte from public.character_spells;
savepoint s;
update public.character_spells set is_favorite = not is_favorite;
rollback to savepoint s;
savepoint s;
delete from public.character_spells;
rollback to savepoint s;
\echo -- groups
select 'groups' as t, count(*) as lignes, md5(coalesce(string_agg(name::text, ',' order by name::text), '')) as empreinte from public.groups;
savepoint s;
update public.groups set name = name || '!';
rollback to savepoint s;
savepoint s;
delete from public.groups;
rollback to savepoint s;
\echo insert groups pour soi
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000e', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo insert groups pour autre
savepoint s;
insert into public.groups (name, owner_id, invite_code) values ('nouveau', 'a0000000-0000-4000-8000-00000000000d', 'MX' || substr(md5(random()::text), 1, 6));
rollback to savepoint s;
\echo -- group_members
select 'group_members' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.group_members;
savepoint s;
update public.group_members set role = role;
rollback to savepoint s;
savepoint s;
delete from public.group_members;
rollback to savepoint s;
\echo insert group_members pour soi
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000e', 'membre');
rollback to savepoint s;
\echo insert group_members pour autre
savepoint s;
insert into public.group_members (group_id, user_id, role) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'membre');
rollback to savepoint s;
\echo -- group_treasure
select 'group_treasure' as t, count(*) as lignes, md5(coalesce(string_agg(group_id::text, ',' order by group_id::text), '')) as empreinte from public.group_treasure;
savepoint s;
update public.group_treasure set currency_gp = currency_gp + 1;
rollback to savepoint s;
savepoint s;
delete from public.group_treasure;
rollback to savepoint s;
\echo -- group_notes
select 'group_notes' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_notes;
savepoint s;
update public.group_notes set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_notes;
rollback to savepoint s;
\echo insert group_notes pour soi
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000e', 'nouveau');
rollback to savepoint s;
\echo insert group_notes pour autre
savepoint s;
insert into public.group_notes (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- group_journal_entries
select 'group_journal_entries' as t, count(*) as lignes, md5(coalesce(string_agg(body::text, ',' order by body::text), '')) as empreinte from public.group_journal_entries;
savepoint s;
update public.group_journal_entries set body = body || '!';
rollback to savepoint s;
savepoint s;
delete from public.group_journal_entries;
rollback to savepoint s;
\echo insert group_journal_entries pour soi
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000e', 'nouveau');
rollback to savepoint s;
\echo insert group_journal_entries pour autre
savepoint s;
insert into public.group_journal_entries (group_id, user_id, body) values ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-00000000000d', 'nouveau');
rollback to savepoint s;
\echo -- bug_reports
select 'bug_reports' as t, count(*) as lignes, md5(coalesce(string_agg(title::text, ',' order by title::text), '')) as empreinte from public.bug_reports;
savepoint s;
update public.bug_reports set title = title || '!';
rollback to savepoint s;
savepoint s;
delete from public.bug_reports;
rollback to savepoint s;
\echo insert bug_reports pour soi
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000e', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo insert bug_reports pour autre
savepoint s;
insert into public.bug_reports (reporter_id, title, description, severity) values ('a0000000-0000-4000-8000-00000000000d', 'n', 'n', 'mineur');
rollback to savepoint s;
\echo -- notification_preferences
select 'notification_preferences' as t, count(*) as lignes, md5(coalesce(string_agg(user_id::text, ',' order by user_id::text), '')) as empreinte from public.notification_preferences;
savepoint s;
update public.notification_preferences set push_enabled = push_enabled;
rollback to savepoint s;
savepoint s;
delete from public.notification_preferences;
rollback to savepoint s;
\echo insert notification_preferences pour soi
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000e');
rollback to savepoint s;
\echo insert notification_preferences pour autre
savepoint s;
insert into public.notification_preferences (user_id) values ('a0000000-0000-4000-8000-00000000000d');
rollback to savepoint s;
\echo -- user_push_tokens
select 'user_push_tokens' as t, count(*) as lignes, md5(coalesce(string_agg(token::text, ',' order by token::text), '')) as empreinte from public.user_push_tokens;
savepoint s;
update public.user_push_tokens set platform = platform;
rollback to savepoint s;
savepoint s;
delete from public.user_push_tokens;
rollback to savepoint s;
\echo insert user_push_tokens pour soi
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000e', 'ios');
rollback to savepoint s;
\echo insert user_push_tokens pour autre
savepoint s;
insert into public.user_push_tokens (token, user_id, platform) values ('tok-' || md5(random()::text), 'a0000000-0000-4000-8000-00000000000d', 'ios');
rollback to savepoint s;
reset role;
rollback;
