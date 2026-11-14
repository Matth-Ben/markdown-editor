#!/bin/bash
# Outils de vérification de la phase 0 sur un Postgres 17 JETABLE (jamais une base distante).
#
# Prérequis : une instance locale démarrée par vos soins, p. ex. (Windows, Git Bash) :
#   initdb -D <dossier_jetable> -U postgres --auth=trust -E UTF8 --locale=C
#   pg_ctl -D <dossier_jetable> -o "-p 54999 -c listen_addresses=127.0.0.1 -c fsync=off" -l pg.log start
# puis l'arrêter et supprimer le dossier à la fin (pg_ctl -D <dossier_jetable> stop).
# Aucune clé, aucune donnée de production : tout est recréé depuis supabase/migrations/ + des stubs.
#
# Usage :
#   PGPORT=54999 ./jetable.sh replay  <base> [dossier_migrations]   recrée <base> (stubs + shim pgTAP + toutes les migrations, une transaction par fichier)
#   PGPORT=54999 ./jetable.sh reapply <base> <fichier.sql>...        rejoue des migrations sur une base déjà migrée (test d'idempotence)
#   PGPORT=54999 ./jetable.sh test    <base> <test.sql>              exécute un test et résume (ok / not ok)
#   PGPORT=54999 ./jetable.sh matrix  <base> <sortie.txt>            matrice RLS (diff entre deux schémas : doit être vide)
#   PGPORT=54999 ./jetable.sh dump    <base> <sortie.sql>            pg_dump --schema-only (comparaison de schémas)
# Variables : PGPORT (54999), PGHOST (127.0.0.1), PGBIN (chemin des binaires si absents du PATH).
# Limites : le shim pgTAP n'implémente que plan/ok/is/isnt/lives_ok/throws_ok/finish ; les anciens tests qui utilisent
# d'autres fonctions pgTAP (results_eq, throws_like...) ne s'y exécutent qu'en partie : le vrai harnais reste
# `supabase test db supabase/tests --local`.
set -u
[ -n "${PGBIN:-}" ] && export PATH="$PGBIN:$PATH"
export PGCLIENTENCODING=UTF8
H="${PGHOST:-127.0.0.1}"; PT="${PGPORT:-54999}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PSQL="psql -X -h $H -p $PT -U postgres"
cmd="$1"; shift

case "$cmd" in
  replay)
    DB="$1"; DIR="${2:-$HERE/../../supabase/migrations}"
    $PSQL -q -c "drop database if exists $DB" \
      -c "create database $DB template template0 encoding 'UTF8' locale_provider icu icu_locale 'fr-FR' locale 'C'" || exit 1
    # Comme sur Supabase : search_path de la base = "$user", public, extensions.
    $PSQL -q -c 'alter database '"$DB"' set search_path = "$user", public, extensions'
    $PSQL -q -v ON_ERROR_STOP=1 -d "$DB" -f "$HERE/stubs_supabase.sql" -f "$HERE/tapshim.sql" >/dev/null 2>&1 || exit 1
    n=0
    for f in $(ls "$DIR"/*.sql | sort); do
      # pg_net / pg_cron ne sont pas installables sur ce Postgres : leurs schémas sont fournis par les stubs.
      sed -E 's/^create extension if not exists (pg_net|pg_cron) with schema extensions;/select 1;/' "$f" \
        | $PSQL -q -v ON_ERROR_STOP=1 -d "$DB" -1 -f - >/dev/null 2>/tmp/jetable_err.txt \
        || { echo "ECHEC $(basename "$f")"; cat /tmp/jetable_err.txt; exit 2; }
      n=$((n+1))
    done
    echo "OK : $n migrations rejouées dans $DB" ;;
  reapply)
    DB="$1"; shift
    for f in "$@"; do
      echo "== $(basename "$f")"
      $PSQL -q -v ON_ERROR_STOP=1 -d "$DB" -1 -f "$f" 2>&1 | sed -E 's/^psql:[^ ]*sql:[0-9]+: //' | grep -E "NOTICE|ERROR"
    done ;;
  test)
    DB="$1"; T="$2"
    OUT=$($PSQL -At -d "$DB" -f "$T" 2>&1)
    echo "$OUT" | grep -E "^(not ok|   #|ERROR|psql:.*ERROR)" | head -20
    echo "ok: $(echo "$OUT" | grep -c '^ok ')  not ok: $(echo "$OUT" | grep -c '^not ok ')  $(echo "$OUT" | grep -E '^planned=')" ;;
  matrix)
    DB="$1"; OUTF="$2"
    $PSQL -d "$DB" -f "$HERE/rls_matrix.sql" 2>&1 | sed -E 's/^psql:.*rls_matrix\.sql:[0-9]+: //' | grep -v '^$' > "$OUTF"
    echo "matrice écrite : $(wc -l < "$OUTF") lignes" ;;
  dump)
    pg_dump -h "$H" -p "$PT" -U postgres -s --no-owner -d "$1" > "$2" && echo "schéma écrit : $2" ;;
  *) echo "commande inconnue : $cmd"; exit 1 ;;
esac
