# Contrat de lecture pour Grimoire : `my_gm_groups`, `group_snapshot`, CA

Étape 5 de `FEUILLE-DE-ROUTE.md` (Grimoire, branche `dev/nexus-desktop`), lancée le 20/11/2026. Migrations :
`20261120090000_private_character_armor_class.sql` (calcul de la CA) et `20261120091000_api_v1_read_contract_for_grimoire.sql`
(schéma `api_v1` et les deux fonctions). Tests : `supabase/tests/api_v1_character_armor_class_test.sql` (70 assertions) et
`supabase/tests/api_v1_read_contract_test.sql` (73 assertions). Règles communes (exposition, appel, erreurs, versionnage) :
[README.md](README.md).

## 1. Droits par rôle

| Appelant | `my_gm_groups()` | `group_snapshot(g, …)` |
|---|---|---|
| Anonyme (sans session) | refusé : `permission denied for schema api_v1` (42501) | refusé, idem |
| Jeton sans utilisateur | `not_authenticated` (28000) | `not_authenticated` (28000) |
| Propriétaire de `g` avec une ligne de membre (MJ, joueur ou orphelin) | ses groupes | servi |
| Propriétaire de `g` **sans** ligne de membre (il a quitté le groupe) | ses groupes | servi |
| Membre de `g` non propriétaire | (`g` n'est pas dans sa liste) | `not_group_owner` (42501) |
| Tiers, groupe inconnu, `p_group_id` `NULL` | (rien) | `group_not_found` (P0002), l'existence du groupe n'est pas révélée |

**Écart avec la RLS, assumé** : la RLS ne donne au propriétaire **sans** ligne de membre ni les lignes `group_members` ni les
fiches de ses membres. `group_snapshot` les lui sert (décision D9 : « groupes dont le compte est propriétaire, avec ou sans
ligne MJ »), réduites au résumé ci-dessous. Les politiques RLS et les privilèges de table ne changent pas : ses lectures
directes restent vides. Il garde par ailleurs ses droits de gestion (renommer, exclure, dissoudre) et lit déjà les combats.

Les membres non propriétaires sont refusés : Grimoire n'affiche que les groupes du propriétaire. Ouvrir l'instantané aux
membres (pour que Nexus remplace ses 6 requêtes de l'écran Groupe) serait un changement compatible, à décider plus tard.

## 2. `api_v1.my_gm_groups()`

```
api_v1.my_gm_groups() returns table (
  id uuid, name text, story_title text,
  member_count integer, dead_count integer, low_hp_count integer,
  has_game_master boolean, owner_has_member_row boolean, owner_plays_character boolean
)
```

Une ligne par groupe dont l'appelant est `groups.owner_id`, triée par `name` puis `id`. Pas de pagination (quelques groupes
par compte).

| Colonne | Sens |
|---|---|
| `member_count` | Toutes les lignes `group_members` : MJ, joueurs, membres orphelins (même compte que l'aperçu d'invitation) |
| `dead_count` | Personnages `is_dead` |
| `low_hp_count` | Personnages vivants avec `max_hp > 0` et `0 < current_hp <= 25 % de max_hp` (même seuil que la vue `group_character_status_overview` de Nexus) |
| `has_game_master` | La ligne du propriétaire est MJ (`group_has_gm`, condition du combat dans Nexus) |
| `owner_has_member_row` | Le propriétaire a une ligne `group_members` |
| `owner_plays_character` | Cette ligne porte un personnage |

Exemple (supabase-js) : `const { data, error } = await supabase.schema('api_v1').rpc('my_gm_groups')`

```json
[
  { "id": "6f0c…", "name": "Les Gardiens", "story_title": "La Mine perdue", "member_count": 6, "dead_count": 1,
    "low_hp_count": 1, "has_game_master": true, "owner_has_member_row": true, "owner_plays_character": false }
]
```

**« Devenir MJ » dans Grimoire** (fonction existante `public.become_group_game_master`, PR DeepCore #49) :

| `has_game_master` | `owner_has_member_row` | `owner_plays_character` | Situation | Ce que Grimoire peut proposer |
|---|---|---|---|---|
| vrai | vrai | faux | Le propriétaire est MJ | Rien |
| faux | vrai | vrai | Le propriétaire joue un personnage | « Devenir MJ » : son personnage quitte le groupe et reste dans sa liste |
| faux | vrai | faux | Ligne orpheline (personnage supprimé) | « Devenir MJ » |
| faux | faux | faux | Le propriétaire a quitté son groupe | « Devenir MJ » répond `not_member` : ne pas le proposer |

`become_group_game_master` peut aussi répondre `mj_already_assigned` (un autre membre est déjà MJ sans personnage) ou
`combat_active` (combat en cours dans Nexus) : à afficher tels quels.

## 3. `api_v1.group_snapshot(p_group_id uuid, p_known_fingerprint text default null)`

Tout le groupe en un appel : le groupe, ses membres et le **résumé** du personnage de chacun, avec la CA calculée par DeepCore.

```js
const { data, error } = await supabase.schema('api_v1')
  .rpc('group_snapshot', { p_group_id: groupId, p_known_fingerprint: cachedFingerprint ?? null })
```

### 3.1 Réponse complète

Exemple réel de forme (valeurs raccourcies ; l'ordre des clés d'un objet JSON n'est pas garanti) :

```json
{
  "v": 1,
  "unchanged": false,
  "fingerprint": "v1:5d0e8f4c3a1b9e7d6c2f0a8b4e6d1c3f5a7b9e0d2c4f6a8b0e1d3c5f7a9b2e4d",
  "group": {
    "id": "e2000000-0000-4000-8000-000000000001",
    "name": "Les Gardiens de la Côte des Épées",
    "story_title": "La Mine perdue de Phandelver",
    "story_summary_public": "Une escorte de chariot vers Phancreux tourne mal…",
    "has_game_master": true
  },
  "members": [
    {
      "membership_id": "25fcaaad-bd6a-4e62-aa3f-7a00be1d13f2",
      "user_id": "e1000000-0000-4000-8000-000000000001",
      "display_name": "Florian",
      "role": "owner",
      "is_owner": true,
      "is_game_master": true,
      "character": null
    },
    {
      "membership_id": "1e7c3421-ecaf-4c4b-b80a-af37f3885658",
      "user_id": "e1000000-0000-4000-8000-000000000004",
      "display_name": "Joueuse 4",
      "role": "membre",
      "is_owner": false,
      "is_game_master": false,
      "character": {
        "id": "46e0c72e-f233-4e48-8346-a603dba43644",
        "name": "Ysolde",
        "portrait_url": "https://<projet>.supabase.co/storage/v1/object/public/character-portraits/<user_id>/<character_id>/1763600000000.png",
        "race_name": "Drakéide",
        "classes": [
          { "class_id": 4, "class_name": "Druide", "subclass_id": 4, "subclass_name": "Cercle de la Terre", "level": 5 },
          { "class_id": 1, "class_name": "Barbare", "subclass_id": null, "subclass_name": null, "level": 2 }
        ],
        "total_level": 7,
        "current_hp": 24,
        "max_hp": 44,
        "temporary_hp": 1,
        "is_dead": false,
        "conditions": ["poisoned", "prone"],
        "armor_class": 18,
        "armor_class_bonus": 0,
        "armor_class_total": 18
      }
    }
  ]
}
```

### 3.2 Champs

Contrat **fermé** : aucune autre clé n'est servie. Toutes les clés sont toujours présentes ; « ou `null` » est explicite.

| Champ | Type | Contenu |
|---|---|---|
| `v` | entier | Version du format : `1` |
| `unchanged` | booléen | `false` pour une réponse complète |
| `fingerprint` | texte | `v1:` + SHA-256 hexadécimal du contenu (§3.4) |
| `group.id`, `group.name` | uuid, texte | Groupe |
| `group.story_title`, `group.story_summary_public` | texte ou `null` | Titre et résumé public de la campagne (étape 4) |
| `group.has_game_master` | booléen | Même règle que `my_gm_groups` |
| `members[]` | tableau | Propriétaire d'abord, puis par date d'adhésion, puis par `membership_id` |
| `membership_id` | uuid | `group_members.id` : permet de filtrer les événements temps réel `DELETE` de `group_members`, qui ne portent que l'`id` |
| `user_id` | uuid | Compte du membre |
| `display_name` | texte ou `null` | Pseudo du compte (`full_name` des métadonnées, rogné ; `null` si absent ou vide). Affichage seulement, jamais une base de droit |
| `role` | `owner` ou `membre` | Valeur stockée. **Ne pas l'utiliser pour reconnaître le propriétaire** : utiliser `is_owner` |
| `is_owner` | booléen | Ce membre est le propriétaire du groupe |
| `is_game_master` | booléen | Ligne MJ sans personnage |
| `character` | objet ou `null` | `null` pour un MJ ou un membre orphelin (personnage supprimé) |
| `character.id`, `character.name` | uuid, texte | Personnage |
| `character.portrait_url` | texte ou `null` | URL telle qu'enregistrée par Nexus (§5) |
| `character.race_name` | texte ou `null` | Race personnalisée du joueur si renseignée, sinon nom français de la race |
| `character.classes[]` | tableau | `class_id`, `class_name` (français), `subclass_id` et `subclass_name` (ou `null`), `level` ; classe principale d'abord, puis niveau décroissant ; vide si aucune classe |
| `character.total_level` | entier | Somme des niveaux, `0` sans classe |
| `character.current_hp`, `max_hp`, `temporary_hp` | entiers | PV de la fiche |
| `character.is_dead` | booléen | État « mort » posé par le joueur |
| `character.conditions` | tableau de textes | Clés d'état de Nexus (`blinded`, `poisoned`, `prone`…), triées, sans doublon |
| `character.armor_class` | entier | CA calculée, **sans** l'ajustement manuel (valeur de la fiche Nexus) |
| `character.armor_class_bonus` | entier | Ajustement manuel du joueur, positif ou négatif |
| `character.armor_class_total` | entier | `armor_class + armor_class_bonus` (valeur de l'écran Groupe de Nexus) |

Les noms de classe, sous-classe et race sont en **français** (comme l'écran Groupe de Nexus). Une langue au choix serait un
paramètre ajouté plus tard (changement compatible).

**Jamais servis** : code d'invitation, histoire personnelle, traits, idéaux, liens, défauts, apparence, notes, inventaire,
monnaie, trésor du groupe, carnet et journal du groupe, jeton de partage, e-mail, dates (`joined_at`, `updated_at`), combat.
Le **code d'invitation** n'est pas dans l'instantané alors que l'étude 09 §2.4 le proposait : Grimoire le lit déjà par un
`select` direct permis au propriétaire (`server/nexus/groups.ts`), l'instantané est mis en cache sur la machine du MJ et
pourra servir à Nexus pour des membres, et changer le code ne doit pas invalider l'empreinte.

### 3.3 Réponse « inchangé »

Si `p_known_fingerprint` est égal à l'empreinte courante :

```json
{ "v": 1, "unchanged": true, "fingerprint": "v1:5d0e…" }
```

Les droits sont vérifiés **avant** l'empreinte : un appelant qui a perdu l'accès reçoit l'erreur, pas `unchanged`.

### 3.4 Empreinte

- `v1:` suivi du SHA-256 (hexadécimal, 64 caractères) du texte JSON du contenu (`group` et `members`).
- **Stable** : même contenu, même empreinte, quel que soit l'ordre physique des lignes en base (chaque tableau est trié
  explicitement, les clés d'objet sont triées par Postgres). Testé : appels répétés, lignes réécrites ou réinsérées, états
  réordonnés.
- Ne change **que** si le contenu du contrat change : PV, états, mort, équipement qui modifie la CA, ajustement, classes ou
  niveaux, nom, portrait, pseudo, rôle, arrivée ou départ d'un membre, nom ou campagne du groupe, présence d'un MJ. Une
  modification hors contrat (histoire personnelle, inventaire sans effet sur la CA, code d'invitation) ne la change pas.
- Le calcul est fait à chaque appel : `unchanged` économise le transfert et le traitement côté client, pas le calcul serveur
  (~6 ms).

### 3.5 Taille et coût mesurés (pile locale, 20/11/2026)

Groupe de 5 personnages + 1 MJ, chaque personnage avec 2 classes, 2 états, une URL de portrait de 140 caractères, un nom de
30 caractères, 22 objets (dont 2 équipés), un résumé public de 120 caractères :

| Mesure | Valeur |
|---|---|
| Réponse complète | **5 366 octets** (1 236 octets compressés en gzip) |
| Réponse `unchanged` | 113 octets |
| Durée de `group_snapshot` | 6 à 7,6 ms |
| Durée de `my_gm_groups` (1 groupe) | 0,55 ms |

Aujourd'hui, Nexus charge le même écran en 6 requêtes et environ 70 Ko (inventaire complet de chaque coéquipier).

### 3.6 Utilisation recommandée par Grimoire

- **Cache** : garder la dernière réponse complète avec son empreinte et sa date dans les tables `nexus_*`, séparées du
  contenu, **jamais** dans les exports. Hors ligne : afficher cette copie avec sa date.
- **Relecture** : à l'ouverture de l'écran, à la reconnexion, et sur tout événement temps réel du groupe (anti-rebond
  ~300 ms), toujours avec `p_known_fingerprint`. Jamais de mise à jour construite depuis la charge brute d'un événement.
- **Temps réel** : avec une ligne de membre, les événements `postgres_changes` sur `characters` et `group_members` arrivent
  comme pour Nexus. **Sans ligne de membre, aucun événement n'arrive** (la RLS filtre chaque événement) : relire
  l'instantané périodiquement (par exemple toutes les 60 s tant que l'écran est ouvert ; 113 octets si rien n'a changé).
  Les tables filles (inventaire, classes…) ne sont pas publiées : un changement d'équipement seul n'émet rien, d'où la
  relecture périodique dans tous les cas.
- **Erreurs** : `group_not_found` = groupe dissous ou accès perdu (passer le lien local à « orphelin », ne rien supprimer
  localement) ; `not_group_owner` = le compte n'est plus propriétaire.

## 4. Calcul de la CA

Fonction interne `private.character_armor_class(uuid)` (non exposée), appelée par `group_snapshot`. Elle reproduit
**exactement** le calcul de Nexus (`lib/features/characters/domain/armor_class_calculator.dart`, « la fiche mobile fait
foi »), écarts aux règles officielles compris (dette D234 du dépôt mobile : à corriger des deux côtés en même temps).

- Entrées : scores de Dex, Con et Sag (absent = 10, modificateur arrondi vers le bas), classes et sous-classes par leur nom
  français exact (« Barbare », « Moine », « Lignage draconique »), style « Défense » choisi sous l'aptitude « Style de
  combat », objets **équipés** du catalogue (armure, bouclier, bonus magiques) et personnalisés (type, CA de base,
  catégorie, bonus magique, harmonisation).
- Ne sont pas lus : quantité, race, niveaux, états, Force, édition.
- **Décision n° 37** : avec deux armures ou deux boucliers équipés, la combinaison qui donne la **meilleure CA** est retenue.
  Conséquence de la règle écrite, testée et à reproduire par Nexus : le bonus « toujours » d'une seconde armure équipée mais
  non retenue compte quand même (écailles de dragon harmonisées + armure complète, Dex 16 : 18 + 1 = **19**).
- Sorties séparées : `armor_class` (sans ajustement), `armor_class_bonus`, `armor_class_total`.
- Parité : les cas C1 à C27 de `regles-dnd` (47 assertions) et 19 sous-cas de plus (décision n° 37, données non lues,
  cas limites) sont dans `supabase/tests/api_v1_character_armor_class_test.sql`, avec les objets réels du catalogue retrouvés par leur nom
  français : si un nom change dans le catalogue, ces tests échouent.

## 5. Portraits

- Le bucket `character-portraits` est **public** (`20260825090400_create_character_tables.sql` : `public = true` et
  politique de lecture pour tous). Une URL `…/storage/v1/object/public/character-portraits/…` se télécharge **sans jeton** :
  le propriétaire sans ligne de membre peut donc télécharger les portraits, sans aucun droit ajouté. Rien n'est modifié
  ici ; le caractère public du bucket (n'importe qui ayant l'URL voit le portrait) est un sujet RGPD existant (D10).
- `portrait_url` peut aussi être une **URL externe** saisie par le joueur (« Utiliser une URL » dans Nexus). Grimoire ne
  doit télécharger automatiquement que les URL qui commencent par `<URL du projet>/storage/v1/object/public/character-portraits/`
  (taille et type d'image limités) ; pour une autre adresse, afficher un portrait par défaut ou demander au MJ. Sinon,
  ouvrir une fiche ferait contacter par la machine du MJ un serveur choisi par un joueur (adresse IP du MJ, contenu
  arbitraire).

## 6. Ce qui n'est pas vérifié

- L'appel HTTP réel par PostgREST : la pile locale n'a pas été redémarrée (la liste des schémas exposés n'est relue qu'au
  démarrage des conteneurs), les statuts HTTP du README sont ceux du code de PostgREST, pas une mesure.
- L'état de la production (rejoué localement à partir des migrations seulement) ; les durées et tailles sont celles de la
  pile locale.
- La parité avec le code Dart est établie par la lecture du calculateur et les cas de `regles-dnd`, pas par l'exécution
  croisée des mêmes fiches dans Nexus.
