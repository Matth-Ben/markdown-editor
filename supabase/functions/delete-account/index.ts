// delete-account — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — écran Profil / paramètres du compte,
// section "Confidentialité et données" -> "Suppression de compte"
// (nexus-jdr-app-mobile/docs/cahier-des-charges/15-profil-parametres.md
// section 4). La confirmation à double étape (saisie du mot de passe ou du
// pseudo) est gérée côté mobile AVANT l'appel à cette fonction : un JWT
// valide suffit ici comme preuve d'authentification, exactement comme pour
// les autres actions sensibles déjà couvertes par le flux Supabase Auth
// standard (ex. updatePassword) -- cette fonction ne revalide donc pas de
// mot de passe elle-même.
//
// PAS de coordination requise avec l'équipe web pour CETTE fonction (elle ne
// lit/écrit ni `stories` ni `character_campaigns`, contrairement à
// join-story) -- mais IMPORTANT À SIGNALER : son EFFET l'est. Le compte
// Supabase est unique et partagé entre "Histoires" et "Personnages"
// (01-architecture-technique.md). `auth.users` est référencé par
// `on delete cascade` non seulement depuis `characters.owner_id`
// (20260825090400_create_character_tables.sql) mais aussi depuis
// `stories.user_id` (20260716212008_create_stories.sql),
// `codex_entries.user_id` (20260721214647_create_codex_entries.sql) et
// `admin_roles.user_id` (20260825090000_create_admin_role.sql). Supprimer un
// compte depuis l'app mobile supprime donc AUSSI, silencieusement, toutes
// les histoires/fiches codex que ce même compte posséderait côté web -- ce
// n'est pas un bug de cette fonction (comportement RGPD correct pour une
// suppression de compte complète, le compte étant unique), mais l'équipe web
// doit en être informée avant merge : le texte de confirmation affiché côté
// mobile devrait mentionner cet impact si l'utilisateur est aussi auteur
// d'histoires, et l'équipe web doit savoir que cette fonction existe et peut
// supprimer un compte utilisé côté "Histoires".
//
// Contrat : POST, sans corps (aucun paramètre accepté -- notamment PAS de
// userId : seul l'appelant authentifié peut supprimer SON PROPRE compte,
// dérivé exclusivement de auth.uid() via le JWT, jamais d'une valeur
// transmise par le client).
//
// Réponses :
//   200 { deleted: true }
//   401 { error: "unauthorized"|..., message }   (authenticateRequest)
//   405 { error: "method_not_allowed" }
//   500 { error: "internal_error", message }      (auth.admin.deleteUser a échoué)
//   500 { error: "server_misconfigured" }          (env Supabase manquantes)
//
// Étapes :
//   1. Authentifie l'appelant via le JWT -> auth.uid().
//   2. Nettoyage best-effort du bucket Storage `character-portraits` sous le
//      préfixe `{userId}/` (portraits de personnage + avatar de profil, même
//      bucket -- voir 20260825090400_create_character_tables.sql et
//      15-profil-parametres.md section 2). Parcours récursif (list() n'est
//      pas récursif côté Storage) puis remove() par lots. Toute erreur ici
//      est journalisée puis ignorée : des fichiers orphelins dans le bucket
//      ne sont pas idéaux mais ne doivent JAMAIS empêcher la suppression du
//      compte (priorité RGPD/utilisateur), qui est l'étape suivante.
//   3. supabase.auth.admin.deleteUser(userId) via le client service_role.
//      Cascade automatiquement en base vers toutes les tables qui
//      référencent auth.users(id) en `on delete cascade`, notamment
//      `characters` puis, en cascade depuis `characters`, ses 14 tables
//      enfants (voir 20260825090400_create_character_tables.sql) ainsi que
//      `character_campaigns` (20260830100100_create_character_campaigns.sql)
//      -- aucune suppression manuelle de ces tables n'est donc nécessaire
//      dans cette fonction.
//   4. 200 { deleted: true } si l'étape 3 réussit, quel que soit le résultat
//      de l'étape 2. 500 sinon.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  readEnvConfig,
} from "../_shared/http.ts";

const PORTRAITS_BUCKET = "character-portraits";
// Storage.list() pagine par défaut à 100 ; on force une limite haute pour
// limiter le nombre d'aller-retours -- best-effort, pas critique si un
// dossier dépasse cette taille (cas non réaliste ici : un seul utilisateur).
const LIST_LIMIT = 1000;
// storage.objects.remove() accepte un tableau de chemins ; on saucissonne
// par prudence plutôt que d'envoyer un tableau arbitrairement long en un
// seul appel.
const REMOVE_CHUNK_SIZE = 100;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const config = readEnvConfig();
  if (!config) {
    console.error("delete-account: variables d'environnement Supabase manquantes");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authResult = await authenticateRequest(req, config);
  if ("errorResponse" in authResult) return authResult.errorResponse;
  const { user } = authResult;

  const admin = createAdminClient(config);

  // Étape 2 : nettoyage best-effort du bucket. Ne fait jamais échouer la
  // requête -- voir le commentaire d'en-tête.
  await deletePortraitFiles(admin, user.id);

  // Étape 3 : suppression du compte lui-même, l'action prioritaire.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);

  if (deleteError) {
    console.error("delete-account: échec auth.admin.deleteUser", deleteError);
    return jsonResponse(
      {
        error: "internal_error",
        message: "Erreur serveur lors de la suppression du compte.",
      },
      500,
    );
  }

  return jsonResponse({ deleted: true });
});

async function deletePortraitFiles(admin: SupabaseClient, userId: string): Promise<void> {
  try {
    const filePaths = await listAllFilePaths(admin, userId);
    if (filePaths.length === 0) return;

    for (let i = 0; i < filePaths.length; i += REMOVE_CHUNK_SIZE) {
      const chunk = filePaths.slice(i, i + REMOVE_CHUNK_SIZE);
      const { error } = await admin.storage.from(PORTRAITS_BUCKET).remove(chunk);
      if (error) {
        console.error(
          `delete-account: échec suppression storage (${chunk.length} fichier(s))`,
          error,
        );
        // best-effort : on continue avec les lots suivants malgré l'échec.
      }
    }
  } catch (err) {
    console.error("delete-account: erreur inattendue lors du nettoyage storage", err);
  }
}

/** Liste récursivement tous les chemins de fichiers sous `{userId}/` dans le
 * bucket `character-portraits`. Storage.list() ne renvoie que le niveau
 * demandé (les sous-dossiers apparaissent comme des entrées sans `id`), d'où
 * le parcours en largeur ci-dessous. Best-effort : une erreur de list() sur
 * un sous-dossier est journalisée puis ignorée (on garde ce qu'on a pu
 * collecter ailleurs) plutôt que de faire échouer tout le nettoyage. */
async function listAllFilePaths(admin: SupabaseClient, userId: string): Promise<string[]> {
  const filePaths: string[] = [];
  const foldersToVisit: string[] = [userId];

  while (foldersToVisit.length > 0) {
    const folder = foldersToVisit.shift()!;
    const { data: entries, error } = await admin.storage
      .from(PORTRAITS_BUCKET)
      .list(folder, { limit: LIST_LIMIT });

    if (error) {
      console.error(`delete-account: échec list() sur "${folder}"`, error);
      continue;
    }

    for (const entry of entries ?? []) {
      const entryPath = `${folder}/${entry.name}`;
      // Convention Supabase Storage : un "dossier" virtuel n'a pas d'id (ni
      // de métadonnées) -- seuls les objets réels (fichiers) en ont un.
      if (entry.id === null || entry.id === undefined) {
        foldersToVisit.push(entryPath);
      } else {
        filePaths.push(entryPath);
      }
    }
  }

  return filePaths;
}
