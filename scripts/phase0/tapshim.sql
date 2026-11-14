-- Mini-shim pgTAP (fonctions plan/ok/is/isnt/lives_ok/throws_ok/finish) pour un Postgres jetable sans extension pgTAP.
create table if not exists public.tap_state(n int default 0, failed int default 0, planned int);
delete from public.tap_state; insert into public.tap_state values (0,0,null);
grant all on public.tap_state to public;
create or replace function public.plan(p int) returns text language sql as $$ update public.tap_state set n=0, failed=0, planned=p; select '1..'||p $$;
create or replace function public.tap_rec(good boolean, d text, diag text default '') returns text language plpgsql security definer as $$
begin update public.tap_state set n=n+1, failed=failed+(case when good then 0 else 1 end);
 return (case when good then 'ok ' else 'not ok ' end)||(select n from public.tap_state)||' - '||d||case when good then '' else E'\n   # '||diag end; end $$;
create or replace function public.ok(b boolean, d text) returns text language sql as $$ select public.tap_rec(coalesce(b,false), d) $$;
create or replace function public.is(a anyelement, b anyelement, d text) returns text language sql as $$ select public.tap_rec(a is not distinct from b, d, 'got '||coalesce(a::text,'NULL')||' expected '||coalesce(b::text,'NULL')) $$;
create or replace function public.isnt(a anyelement, b anyelement, d text) returns text language sql as $$ select public.tap_rec(a is distinct from b, d, 'got '||coalesce(a::text,'NULL')) $$;
create or replace function public.lives_ok(q text, d text) returns text language plpgsql as $$
begin execute q; return public.tap_rec(true,d); exception when others then return public.tap_rec(false,d,sqlstate||' '||sqlerrm); end $$;
create or replace function public.throws_ok(q text, c text, m text, d text) returns text language plpgsql as $$
begin execute q; return public.tap_rec(false,d,'no exception');
exception when others then return public.tap_rec(sqlstate=c and (m is null or sqlerrm=m), d, 'got '||sqlstate||' '||sqlerrm); end $$;
create or replace function public.finish() returns text language sql as $$ select 'planned='||planned||' ran='||n||' failed='||failed from public.tap_state $$;
