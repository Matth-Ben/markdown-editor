// preview-story-invite — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — Phase 4, étape 2 du parcours
// "Rejoindre une histoire" (04-fonctionnalites-app-mobile.md section 7.1,
// dépôt nexus-jdr-app-mobile) : Code -> **Confirmation (nom + couverture de
// l'histoire, avant tout engagement)** -> Choix du personnage -> Validation.
//
// join-story (12-partage-et-groupes.md section 5.4) fait tout en un seul
// appel atomique {code, character_id} et crée le rattachement dans
// character_campaigns : inutilisable à l'étape 2 du parcours, où
// character_id n'est pas encore connu (le choix du personnage vient après
// la confirmation) et où aucun engagement ne doit encore être pris.
// preview-story-invite couvre uniquement les étapes 1-2 de join-story
// (résoudre le code, vérifier que l'invitation est active), en réutilisant
// la même logique via ../_shared/story-invite.ts pour rester garantie
// cohérente avec join-story (mêmes codes/messages d'erreur) — et ne touche
// jamais character_campaigns, ni ne prend character_id en entrée.
//
// IMPORTANT — À COORDONNER AVEC L'ÉQUIPE WEB AVANT MERGE : même motif que
// join-story (lit stories.invite_code/invite_code_enabled).
//
// Contrat : POST { code: string }, authentifié (même exigence que
// join-story — l'utilisateur doit être connecté à ce stade du parcours
// mobile, cf. 04-fonctionnalites-app-mobile.md section 7.1).
//   200 { title, cover_image_path }
//   404 { error: "invalid_code" }
//   403 { error: "invite_disabled" }
//   401 { error: "unauthorized" }
//
// Note produit (décision du 30/08/2026, remontée par le chef de projet) :
// pas de "MJ : {nom}" dans la réponse — aucune notion de profil
// utilisateur/nom d'affichage n'existe dans ce schéma, et en ajouter une
// pour ce seul champ secondaire sort du périmètre de ce préalable. Le nom
// et la couverture de l'histoire suffisent pour l'étape de confirmation.

import {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  findJoinableStory,
  jsonResponse,
  readEnvConfig,
} from "../_shared/story-invite.ts";

interface PreviewStoryInviteRequestBody {
  code?: unknown;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const config = readEnvConfig();
  if (!config) {
    console.error(
      "preview-story-invite: variables d'environnement Supabase manquantes",
    );
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authResult = await authenticateRequest(req, config);
  if ("errorResponse" in authResult) return authResult.errorResponse;

  let body: PreviewStoryInviteRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(
      { error: "invalid_body", message: "Corps de requête JSON invalide." },
      400,
    );
  }

  const code = typeof body.code === "string" ? body.code.trim() : "";

  if (!code) {
    return jsonResponse(
      { error: "invalid_body", message: "Le champ code est requis." },
      400,
    );
  }

  const admin = createAdminClient(config);

  const storyResult = await findJoinableStory(admin, code);
  if ("errorResponse" in storyResult) return storyResult.errorResponse;
  const { story } = storyResult;

  return jsonResponse({
    title: story.title,
    cover_image_path: story.cover_image_path,
  });
});
