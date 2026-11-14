#!/bin/bash
# Preuve par mutation des garde-fous des migrations de la phase 0, sur un Postgres JETABLE (voir jetable.sh).
# Pour chaque garde-fou, on fabrique dans une copie de la base « main » (157 migrations) la situation dangereuse, on applique la
# migration, et on vérifie (1) qu'elle LÈVE l'exception attendue, (2) que RIEN n'a été appliqué (transaction annulée).
# Prérequis : une base `<base_main>` créée par `./jetable.sh replay <base_main> <dossier avec les 157 migrations de main>`.
# Usage : PGPORT=54999 ./garde_fous.sh <base_main>
set -u
[ -n "${PGBIN:-}" ] && export PATH="$PGBIN:$PATH"
export PGCLIENTENCODING=UTF8
unset PGPASSWORD PGSERVICE PGSERVICEFILE PGPASSFILE PGSSLMODE PGSSLROOTCERT DATABASE_URL
H="${PGHOST:-127.0.0.1}"; PT="${PGPORT:-54999}"
case "$H" in 127.0.0.1|localhost) ;; *) echo "REFUS : hôte non local"; exit 1 ;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"; M="$HERE/../../supabase/migrations"
BASE="$1"
PSQL="psql -X -h $H -p $PT -U postgres"
fail=0

new_db() { $PSQL -q -c "drop database if exists $1" -c "create database $1 template $BASE" 2>&1 | grep -v NOTICE; }
apply() { sed -E 's/^create extension if not exists (pg_net|pg_cron) with schema extensions;/select 1;/' "$2" | $PSQL -d "$1" -v ON_ERROR_STOP=1 -1 -f - 2>&1; }
q() { $PSQL -d "$1" -At -c "$2"; }
expect() { # <titre> <sortie> <motif attendu>
  if echo "$2" | grep -q "$3"; then echo "OK   : $1"; else echo "ECHEC : $1 (exception attendue absente)"; echo "$2" | head -5; fail=1; fi
}
same() { # <titre> <attendu> <obtenu>
  if [ "$2" = "$3" ]; then echo "OK   : $1 (= $3)"; else echo "ECHEC : $1 (attendu $2, obtenu $3)"; fail=1; fi
}
f() { ls "$M"/$1*.sql; }

echo "== 1. CHECK : une ligne existante viole une règle -> exception, aucune contrainte ajoutée"
new_db gf1
$PSQL -q -d gf1 -c "insert into auth.users(id,instance_id,aud,role,email,created_at,updated_at) values ('91000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','a','a','gf1@t.l',now(),now())" \
  -c "insert into public.characters(id,owner_id,name,xp,currency_gp) values ('91000000-0000-4000-8000-0000000000a1','91000000-0000-4000-8000-000000000001','fautif',-5,-2)" \
  -c "insert into public.groups(id,name,owner_id,invite_code) values ('91000000-0000-4000-8000-0000000000b1','g','91000000-0000-4000-8000-000000000001','GF1')" \
  -c "update public.group_treasure set currency_cp = -1 where group_id = '91000000-0000-4000-8000-0000000000b1'"
out=$(apply gf1 "$(f 20261115094000)")
expect "exception levée avec table/contrainte/nombre" "$out" "violent des règles"
echo "$out" | grep -E "^  - " | sed 's/^/       /'
same "contraintes phase 0 ajoutées" 0 "$(q gf1 "select count(*) from pg_constraint where conname in ('characters_hp_nonnegative','characters_xp_nonnegative','characters_currency_nonnegative','group_treasure_currency_nonnegative','group_treasure_items_is_array','character_inventory_quantity_nonnegative','character_classes_level_positive','character_spell_slots_counts_nonnegative','character_pact_slots_counts_nonnegative','character_feature_uses_remaining_nonnegative')")"
echo "== 1b. CHECK : contrainte équivalente sous un autre nom -> non recréée (NOTICE), pas d'erreur"
new_db gf1b
$PSQL -q -d gf1b -c "alter table public.characters add constraint xp_ok check (xp >= 0)"
out=$(apply gf1b "$(f 20261115094000)")
expect "équivalent détecté" "$out" "contrainte équivalente déjà présente : xp_ok"
same "characters_xp_nonnegative absente (doublon évité)" 0 "$(q gf1b "select count(*) from pg_constraint where conname = 'characters_xp_nonnegative'")"

echo "== 2. Droits : appelants anon/public des helpers -> exception, rien révoqué"
for variante in policy_anon policy_sans_to policy_storage vue defaut invoker; do
  new_db gf2
  case $variante in
    policy_anon) sql="create table public.gf_t(id uuid); alter table public.gf_t enable row level security; create policy gf_p on public.gf_t for select to anon using (public.owns_character(id));" ;;
    policy_sans_to) sql="create table public.gf_t(id uuid); alter table public.gf_t enable row level security; create policy gf_p on public.gf_t for select using (public.is_group_member(id));" ;;
    policy_storage) sql="create policy gf_storage on storage.objects for select to public using (public.is_admin());" ;;
    vue) sql="create view public.gf_v as select public.owns_character(gen_random_uuid()) as x;" ;;
    defaut) sql="create table public.gf_d(c boolean default public.is_admin());" ;;
    invoker) sql="create function public.gf_f() returns boolean language sql stable as 'select public.owns_character(gen_random_uuid())'; grant execute on function public.gf_f() to anon;" ;;
  esac
  $PSQL -q -d gf2 -c "$sql"
  out=$(apply gf2 "$(f 20261115093000)")
  expect "garde-fou ($variante)" "$out" "appelants anonymes/publics"
  echo "$out" | grep -E "^  - " | sed 's/^/       /'
  same "anon a toujours EXECUTE sur owns_character ($variante)" t "$(q gf2 "select has_function_privilege('anon','public.owns_character(uuid)','execute')")"
  same "search_path inchangé ($variante)" "{search_path=public}" "$(q gf2 "select proconfig::text from pg_proc where proname='owns_character'")"
done
echo "== 2b. Droits : une politique to authenticated qui utilise un helper NE bloque PAS (cas normal)"
new_db gf2b
$PSQL -q -d gf2b -c "create table public.gf_t(id uuid); alter table public.gf_t enable row level security; create policy gf_p on public.gf_t for select to authenticated using (public.owns_character(id));"
out=$(apply gf2b "$(f 20261115093000)")
expect "migration appliquée" "$out" "phase0 droits : A=10"
same "anon n'a plus EXECUTE" f "$(q gf2b "select has_function_privilege('anon','public.owns_character(uuid)','execute')")"

echo "== 3. Trigger : collision de fonction / autre gestionnaire de updated_at -> exception, rien créé"
new_db gf3
$PSQL -q -d gf3 -c "create function public.characters_touch_updated_at() returns trigger language plpgsql as 'begin return new; end'"
out=$(apply gf3 "$(f 20261115090000)")
expect "collision de fonction (corps différent)" "$out" "existe déjà avec un corps différent"
same "trigger créé" 0 "$(q gf3 "select count(*) from pg_trigger where tgname='characters_set_updated_at'")"
new_db gf3b
$PSQL -q -d gf3b -c "create function public.autre_maj() returns trigger language plpgsql as 'begin new.updated_at := now(); return new; end'" \
  -c "create trigger autre_maj before update on public.characters for each row execute function public.autre_maj()"
out=$(apply gf3b "$(f 20261115090000)")
expect "autre trigger BEFORE UPDATE gérant updated_at" "$out" "gère déjà updated_at"
same "fonction characters_touch_updated_at créée" 0 "$(q gf3b "select count(*) from pg_proc where proname='characters_touch_updated_at'")"
new_db gf3c
$PSQL -q -d gf3c -c "alter table public.characters add column payload json"
out=$(apply gf3c "$(f 20261115090000)")
expect "colonne json dans characters" "$out" "colonne json"

for d in gf1 gf1b gf2 gf2b gf3 gf3b gf3c; do $PSQL -q -c "drop database if exists $d" 2>&1 | grep -v NOTICE; done
[ $fail -eq 0 ] && echo "TOUS LES GARDE-FOUS DÉCLENCHENT L'EXCEPTION ATTENDUE ET RIEN N'EST APPLIQUÉ" || { echo "AU MOINS UN GARDE-FOU EN ÉCHEC"; exit 1; }
