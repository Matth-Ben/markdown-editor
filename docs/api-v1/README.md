# API `api_v1` de DeepCore

API versionnée de la base commune à **Nexus** (app mobile) et **Grimoire** (app de bureau du MJ). Elle remplace peu à peu
les lectures et écritures directes des tables par des fonctions dont le contrat est écrit ici, testé (pgTAP) et stable.

| Document | Contenu |
|---|---|
| [contrat-lecture-grimoire.md](contrat-lecture-grimoire.md) | `my_gm_groups()`, `group_snapshot(uuid, text)`, calcul de la CA (étape 5 de Grimoire) |
| [group_snapshot.schema.json](group_snapshot.schema.json) | Schéma JSON de la réponse de `group_snapshot` (validation côté client, par exemple avec zod) |

## Règles communes

**Exposition.** Le schéma `api_v1` doit figurer dans les « Exposed schemas » de l'API (tableau de bord Supabase > Settings >
API ; `supabase/config.toml` pour la pile locale). Ce réglage se fait **après** l'application de la migration qui crée le
schéma, et se retire **avant** un retour arrière.

**Appel.** supabase-js : `supabase.schema('api_v1').rpc('nom_de_la_fonction', { p_param: valeur })`. HTTP :
`POST /rest/v1/rpc/nom_de_la_fonction` avec l'en-tête `Content-Profile: api_v1` (ou `GET` avec `Accept-Profile: api_v1` pour
une fonction `stable`), le jeton de session de l'utilisateur dans `Authorization: Bearer …` et la clé publique dans `apikey`.

**Droits.**
- `USAGE` sur `api_v1` : `authenticated` seulement. `anon` et `PUBLIC` n'ont rien (ni `USAGE`, ni `EXECUTE`).
- Toute fonction est `security definer`, `stable` pour une lecture, avec `search_path = public, pg_temp`, `EXECUTE` retiré
  à `PUBLIC` et `anon` puis accordé à `authenticated` (les privilèges par défaut de Postgres donnent `EXECUTE` à `PUBLIC` :
  le retrait est toujours explicite). Un test pgTAP vérifie ces règles pour **toutes** les fonctions du schéma.
- Chaque fonction revérifie elle-même `auth.uid()` et le rôle de l'appelant (propriétaire, membre…). Les droits par rôle sont
  écrits dans le contrat de chaque fonction ; tout écart avec la RLS des tables est signalé comme tel.
- Aucune table ni vue dans `api_v1`.

**Erreurs.** Une erreur levée par une fonction porte un `message` stable (code en anglais, en `snake_case`) et un SQLSTATE.
Le client se fie au **`code`** (SQLSTATE) et au **`message`** du corps de l'erreur PostgREST, jamais au seul statut HTTP :
PostgREST traduit certains SQLSTATE de façon peu parlante (par exemple `P0002` en 500).

| `message` | SQLSTATE | Statut HTTP (traduction PostgREST, non vérifiée en local) | Sens |
|---|---|---|---|
| `not_authenticated` | `28000` | 403 | Jeton sans utilisateur |
| `group_not_found` | `P0002` | 500 | Groupe inconnu, identifiant `NULL`, ou appelant sans relation avec le groupe (existence non révélée) |
| `not_group_owner` | `42501` | 403 | Appelant membre du groupe mais pas propriétaire |
| `permission denied for schema api_v1` | `42501` | 401 (anonyme) | Appel sans session : le rôle `anon` n'a pas accès au schéma |

Mêmes codes que les fonctions du combat (`start_combat`…) et `become_group_game_master` : un client peut partager sa table de
traduction des erreurs.

**Versionnage.**
- Ajouter une clé à un objet JSON, une colonne à un résultat ou un paramètre avec valeur par défaut est **compatible** :
  les clients doivent ignorer les clés inconnues (avec zod : objets non stricts).
- Retirer ou renommer une clé, changer son type ou son sens, ou durcir un droit est **incompatible** : nouvelle fonction ou
  `api_v2`, avec une période où les deux coexistent.
- Chaque réponse JSON porte `"v": 1`. Une empreinte commence par `v1:` : un changement de format d'empreinte change le
  préfixe, ce qui force une relecture complète chez les clients.

**Hors ligne.** Les fonctions de lecture ne servent que les données en ligne. Le client garde la dernière réponse avec sa
date et son empreinte, l'affiche hors ligne, et la relit à la reconnexion en envoyant l'empreinte connue.
