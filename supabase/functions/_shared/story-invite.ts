// Code commun à join-story et preview-story-invite (voir leurs fichiers
// respectifs). Les deux fonctions authentifient l'appelant via son JWT puis
// résolvent une histoire par invite_code avec exactement les mêmes règles
// (code absent -> invalid_code/404, invitation désactivée ->
// invite_disabled/403) — factorisé ici plutôt que dupliqué, pour que les
// deux fonctions restent garanties cohérentes (mêmes messages, même
// comportement) sans synchronisation manuelle.
//
// Convention utilisée : le préfixe `_` (supabase/functions/_shared/) est la
// convention standard de la CLI/plateforme Supabase pour un dossier qui
// n'est PAS déployé comme une fonction lui-même, uniquement importé par
// d'autres fonctions du même projet — pas de précédent dans ce dépôt avant
// preview-story-invite (deuxième edge function), mais c'est le pattern
// documenté par Supabase pour ce cas.
//
// Les briques génériques (CORS, réponses JSON, config d'environnement,
// authentification JWT) ont été extraites vers ../_shared/http.ts au moment
// d'ajouter report-bug (première edge function sans rapport avec le
// parcours "Rejoindre une histoire") -- réexportées ici pour ne rien casser
// côté join-story/preview-story-invite, qui continuent d'importer depuis ce
// fichier sans changement.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { jsonResponse } from "./http.ts";

export {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  readEnvConfig,
} from "./http.ts";
export type { AuthResult, EnvConfig } from "./http.ts";

export interface StoryInviteRow {
  id: string;
  title: string;
  cover_image_path: string | null;
  invite_code_enabled: boolean;
}

export type FindStoryResult =
  | { story: StoryInviteRow }
  | { errorResponse: Response };

/** Cherche une histoire par invite_code et vérifie qu'elle est joignable
 * (code existant + invitation active). Utilisé par join-story (avant de
 * vérifier/rattacher un personnage) et preview-story-invite (qui s'arrête
 * là). `admin` doit être un client service_role : invite_code n'est jamais
 * lisible via une policy select cliente. */
export async function findJoinableStory(
  admin: SupabaseClient,
  code: string,
): Promise<FindStoryResult> {
  const { data: story, error } = await admin
    .from("stories")
    .select("id, title, cover_image_path, invite_code_enabled")
    .eq("invite_code", code)
    .maybeSingle();

  if (error) {
    console.error("story-invite: erreur de lecture stories", error);
    return {
      errorResponse: jsonResponse(
        { error: "internal_error", message: "Erreur serveur." },
        500,
      ),
    };
  }

  if (!story) {
    return {
      errorResponse: jsonResponse({ error: "invalid_code", message: "Code invalide." }, 404),
    };
  }

  if (!story.invite_code_enabled) {
    return {
      errorResponse: jsonResponse(
        { error: "invite_disabled", message: "Invitation désactivée par le MJ." },
        403,
      ),
    };
  }

  return { story };
}
