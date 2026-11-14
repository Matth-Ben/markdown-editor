#!/bin/bash
# Prépare l'application des migrations de la phase 0 UNE PAR UNE. `supabase db push` applique toutes les migrations en attente et le CLI
# n'a pas d'option « un seul fichier » : ce script met simplement de côté (mv local, rien n'est supprimé, rien n'est envoyé nulle part) les
# fichiers des étapes suivantes dans supabase/.phase0_attente/, pour que seul le prochain fichier soit « en attente ». Il ne lance AUCUNE
# commande vers une base distante.
#
# RÈGLE DE SÉCURITÉ INDÉPENDANTE DU SCRIPT : avant CHAQUE `db push`, `supabase db push --dry-run` doit lister EXACTEMENT UN fichier, le bon.
# Sinon, ne pas pousser.
#
# NUMÉROTATION UNIQUE (la même dans les en-têtes des migrations, les tests, la PR et controles_lecture_seule.sql) :
#   1 trigger updated_at            2 RLS characters + bug_reports      3 RLS tables de groupe        4 RLS notifications + jetons push
#   5 index tables d'un personnage  6 index groupes/combat/divers       7 index tables de référence   8 droits (EXECUTE, search_path)
#   9 CHECK NOT VALID               (puis, plus tard : validation différée, supabase/deferred/)
#
# Usage (UNIQUEMENT dans le worktree dédié mj-ph0, jamais dans un dépôt principal) :
#   bash scripts/phase0/etape.sh <n> <sha-de-la-pointe>   garde dans migrations/ les étapes 1..n, met les suivantes de côté
#   bash scripts/phase0/etape.sh restaurer                remet tous les fichiers en place
# <n> = numéro du DERNIER fichier à garder « en attente » (donc le seul non encore appliqué : 1..n-1 le sont déjà en production).
# <sha-de-la-pointe> = début (au moins 7 caractères hexadécimaux) du sha de la pointe de la branche indiqué dans la PR (le script refuse si HEAD est ailleurs).
# Le dossier supabase/.phase0_attente/ est ajouté à .git/info/exclude, fichier COMMUN à tous les worktrees du dépôt (inoffensif : dossier jamais committé).
# Le script refuse si l'arbre n'est pas propre (hors fichiers déjà mis de côté par lui) et demande une confirmation explicite.
# ATTENTION : toujours lancer `restaurer` AVANT tout commit ou changement de branche (sinon les fichiers apparaîtraient supprimés).
set -eu
cd "$(dirname "$0")/../.."
case "$(basename "$(pwd)")" in mj-ph0) ;; *) echo "REFUS : à lancer dans le worktree dédié mj-ph0 uniquement."; exit 1 ;; esac
MIG=supabase/migrations
HOLD=supabase/.phase0_attente
FILES=(
  20261115090000_phase0_characters_updated_at_trigger.sql
  20261115091000_phase0_rls_auth_uid_initplan_characters.sql
  20261115091100_phase0_rls_auth_uid_initplan_groups.sql
  20261115091200_phase0_rls_auth_uid_initplan_notifications.sql
  20261115092000_phase0_add_fk_indexes_character_tables.sql
  20261115092100_phase0_add_fk_indexes_groups_and_misc.sql
  20261115092200_phase0_add_fk_indexes_reference_tables.sql
  20261115093000_phase0_function_grants_and_search_path.sql
  20261115094000_phase0_add_not_valid_checks.sql
)
# Exclusion locale du dossier de mise de côté (jamais committé).
EXCL="$(git rev-parse --git-path info/exclude)"
grep -qx 'supabase/.phase0_attente/' "$EXCL" 2>/dev/null || { mkdir -p "$(dirname "$EXCL")"; echo 'supabase/.phase0_attente/' >> "$EXCL"; }

restore() { for f in "${FILES[@]}"; do [ -f "$HOLD/$f" ] && mv "$HOLD/$f" "$MIG/$f"; done; return 0; }

if [ "${1:-}" = "restaurer" ]; then
  mkdir -p "$HOLD"; restore; echo "Tout est remis en place."; git status --short; exit 0
fi

n="${1:?usage: etape.sh <1..9> <sha-de-la-pointe> | restaurer}"
want="${2:?usage: etape.sh <1..9> <sha-de-la-pointe> | restaurer}"
case "$n" in [1-9]) ;; *) echo "REFUS : <n> doit être un chiffre de 1 à 9."; exit 1 ;; esac
case "$want" in *[!0-9a-fA-F]*|"") echo "REFUS : <sha> doit être hexadécimal."; exit 1 ;; esac
[ "${#want}" -ge 7 ] || { echo "REFUS : <sha> doit faire au moins 7 caractères hexadécimaux."; exit 1; }
mkdir -p "$HOLD"

# 1. HEAD attendu.
head="$(git rev-parse HEAD)"
case "$head" in "$want"*) ;; *) echo "REFUS : HEAD=$head ne commence pas par $want (pointe attendue de la branche)."; exit 1 ;; esac
# 2. Arbre propre (après remise en place des fichiers que ce script aurait mis de côté).
restore
dirty="$(git status --porcelain)"
if [ -n "$dirty" ]; then echo "REFUS : l'arbre n'est pas propre :"; echo "$dirty"; exit 1; fi
# 3. Mise de côté des étapes > n.
i=0
for f in "${FILES[@]}"; do
  i=$((i+1))
  if [ "$i" -gt "$n" ]; then mv "$MIG/$f" "$HOLD/$f"; fi
done
last="${FILES[$((n-1))]}"
echo "Étapes gardées en attente pour le CLI : 1..$n"
echo "DERNIER fichier gardé (le seul à appliquer maintenant, si 1..$((n-1)) sont déjà appliquées) :"
echo "    $last"
echo "Mis de côté : $(ls "$HOLD" | wc -l) fichier(s) dans $HOLD"
if [ -t 0 ]; then
  read -r -p "Confirmer que « $last » est bien le prochain fichier à appliquer (taper OUI) : " rep
  if [ "$rep" != "OUI" ]; then restore; echo "Annulé : tout est remis en place."; exit 1; fi
else
  restore; echo "REFUS : pas de terminal interactif, confirmation impossible (tout est remis en place)."; exit 1
fi
echo "Avant le db push : « supabase db push --dry-run » doit lister EXACTEMENT UN fichier : $last"
echo "ET lancer « scripts/phase0/etape.sh restaurer » avant tout commit ou changement de branche."
