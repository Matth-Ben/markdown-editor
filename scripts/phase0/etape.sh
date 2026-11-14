#!/bin/bash
# Prépare l'application des migrations de la phase 0 UNE PAR UNE. `supabase db push` applique toutes les migrations en attente et le
# CLI n'a pas d'option « un seul fichier » : ce script met simplement de côté (mv local, rien n'est supprimé, rien n'est envoyé nulle
# part) les fichiers des étapes suivantes dans supabase/.phase0_attente/, pour que seul le prochain fichier soit « en attente ».
# Il ne lance AUCUNE commande vers une base distante : c'est Matthias qui lance ensuite `--dry-run` puis `db push`.
#
# À utiliser UNIQUEMENT dans le worktree dédié (H:\Projets\Labo\mj-ph0), jamais dans un dépôt principal.
#   scripts/phase0/etape.sh <n>          garde dans migrations/ les étapes 1..n, met les suivantes de côté
#   scripts/phase0/etape.sh restaurer    remet tous les fichiers en place (git status doit redevenir propre)
# Étapes : 1 trigger, 2 politiques RLS, 3 index (3 fichiers : 3, 4, 5), 6 droits, 7 CHECK NOT VALID.
# Rappel : dans l'ordre recommandé, avancer de n-1 à n signifie que n-1 est DÉJÀ appliquée en production.
set -eu
cd "$(dirname "$0")/../.."
case "$(basename "$(pwd)")" in mj-ph0) ;; *) echo "REFUS : à lancer dans le worktree dédié mj-ph0 uniquement."; exit 1 ;; esac
MIG=supabase/migrations
HOLD=supabase/.phase0_attente
FILES=(
  20261115090000_phase0_characters_updated_at_trigger.sql
  20261115091000_phase0_rls_auth_uid_initplan.sql
  20261115092000_phase0_add_fk_indexes_character_tables.sql
  20261115092100_phase0_add_fk_indexes_groups_and_misc.sql
  20261115092200_phase0_add_fk_indexes_reference_tables.sql
  20261115093000_phase0_function_grants_and_search_path.sql
  20261115094000_phase0_add_not_valid_checks.sql
)
mkdir -p "$HOLD"
for f in "${FILES[@]}"; do [ -f "$HOLD/$f" ] && mv "$HOLD/$f" "$MIG/$f"; done
if [ "${1:-}" = "restaurer" ]; then echo "Tout est remis en place."; git status --short; exit 0; fi
n="${1:?usage: etape.sh <1..7|restaurer>}"
i=0
for f in "${FILES[@]}"; do
  i=$((i+1))
  if [ "$i" -gt "$n" ]; then mv "$MIG/$f" "$HOLD/$f"; fi
done
echo "Fichiers « en attente » pour le CLI (étapes 1..$n) :"
ls "$MIG" | grep '^20261115' || true
echo "Mis de côté : $(ls "$HOLD" | wc -l) fichier(s) dans $HOLD"
echo "Rappel : n'appliquer que le DERNIER fichier non encore appliqué ; vérifier avec « supabase migration list » avant le dry-run."
