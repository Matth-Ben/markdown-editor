-- Stubs minimaux d'un environnement Supabase pour un Postgres jetable (aucun secret).
do $b$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end $b$;
create schema if not exists extensions; create schema if not exists auth; create schema if not exists storage;
create schema if not exists vault; create schema if not exists cron; create schema if not exists net;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;
create table auth.users(id uuid primary key default gen_random_uuid(), instance_id uuid, aud text, role text, email text,
  encrypted_password text, email_confirmed_at timestamptz, raw_app_meta_data jsonb, raw_user_meta_data jsonb,
  created_at timestamptz default now(), updated_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid $$;
create function auth.role() returns text language sql stable as $$ select 'anon'::text $$;
create function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;
create table storage.buckets(id text primary key, name text, public boolean default false, file_size_limit bigint, allowed_mime_types text[], created_at timestamptz default now());
create table storage.objects(id uuid default gen_random_uuid() primary key, bucket_id text references storage.buckets(id), name text, owner uuid, created_at timestamptz default now());
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql as $$ select string_to_array(name,'/') $$;
create view vault.decrypted_secrets as select 'x'::text as name, 'x'::text as decrypted_secret;
create function vault.create_secret(a text, b text default null, c text default null) returns uuid language sql as $$ select gen_random_uuid() $$;
create function cron.schedule(a text, b text, c text) returns bigint language sql as $$ select 1::bigint $$;
create function net.http_post(url text, body jsonb default null, headers jsonb default null, params jsonb default null, timeout_milliseconds int default 1000) returns bigint language sql as $$ select 1::bigint $$;
create publication supabase_realtime;
grant usage on schema public, extensions, auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
