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

> **Ordre impératif.** Un schéma exposé qui n'existe pas fait tomber **toute** l'API, Nexus compris. Observé sur la pile
> locale (PostgREST 14.15, 20/11/2026) : `Failed to load the schema cache … schema "api_v1" does not exist`, puis **503
> `PGRST002`** sur toutes les requêtes, `public` comprise, avec des nouvelles tentatives de plus en plus espacées (8 s, 16 s…).
> Retour à la normale tout seul, 4 s après la recréation du schéma. Donc : jamais exposer avant la migration, toujours retirer
> l'exposition avant de supprimer le schéma.

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
Le client se fie au **`code`** et au **`message`** du corps de l'erreur PostgREST, jamais au seul statut HTTP : PostgREST
traduit certains SQLSTATE de façon peu parlante (`P0002` en 500, comme une vraie panne). Statuts mesurés par appel HTTP réel
sur la pile locale (20/11/2026), sauf mention contraire.

| `code` | `message` | HTTP | Sens |
|---|---|---|---|
| `28000` | `not_authenticated` | 403 (non mesuré : code de PostgREST) | Jeton sans utilisateur |
| `P0002` | `group_not_found` | 500 | Groupe inconnu, identifiant `NULL`, ou appelant sans relation avec le groupe (existence non révélée) |
| `42501` | `not_group_owner` | 403 | Appelant membre du groupe mais pas propriétaire |
| `42501` | `permission denied for schema api_v1` | 401 | Appel sans session : le rôle `anon` n'a pas accès au schéma |
| `PGRST202` | `Could not find the function api_v1.… in the schema cache` | 404 | Fonction ou paramètres inconnus : migration pas encore appliquée (ou annulée), nom ou paramètre faux |
| `PGRST106` | `Invalid schema: api_v1` | 406 | `api_v1` n'est pas (ou plus) dans les « Exposed schemas » |
| `PGRST002` | `Could not query the database for the schema cache. Retrying.` | 503 | PostgREST n'a pas chargé son cache : **toute** l'API est indisponible (voir « Ordre impératif ») |

Mêmes codes métier que les fonctions du combat (`start_combat`…) et `become_group_game_master` : un client peut partager sa
table de traduction des erreurs.

**Réaction du client (Grimoire).** Seul `code = 'P0002'` **et** `message = 'group_not_found'` signifie que le groupe a disparu
ou que l'accès est perdu : c'est le **seul** cas qui fait passer le lien local d'une campagne au statut « orphelin ». Toute
autre erreur (`PGRST106`, `PGRST202`, `PGRST002`, 401, 403, 5xx sans ce code, réseau) laisse le lien tel quel : afficher la
dernière copie en cache avec sa date et réessayer plus tard. Sinon, Grimoire rendrait orphelins tous ses groupes entre
l'application de la migration et le réglage d'exposition, ou pendant un retour arrière.

**Versionnage.**
- Ajouter une clé à un objet JSON, une colonne à un résultat ou un paramètre avec valeur par défaut est **compatible** :
  les clients doivent ignorer les clés inconnues (avec zod : objets non stricts).
- Retirer ou renommer une clé, changer son type ou son sens, ou durcir un droit est **incompatible** : nouvelle fonction ou
  `api_v2`, avec une période où les deux coexistent.
- Chaque réponse JSON porte `"v": 1`. Une empreinte commence par `v1:` : un changement de format d'empreinte change le
  préfixe, ce qui force une relecture complète chez les clients.

**Hors ligne.** Les fonctions de lecture ne servent que les données en ligne. Le client garde la dernière réponse avec sa
date et son empreinte, l'affiche hors ligne, et la relit à la reconnexion en envoyant l'empreinte connue.
