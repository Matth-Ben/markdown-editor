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
//   200 { title, cover_image_path, gm_display_name }
//   404 { error: "invalid_code" }
//   403 { error: "invite_disabled" }
//   401 { error: "unauthorized" }
//
// Note produit (mise à jour du 06/09/2026, remplace la décision du
// 30/08/2026 qui excluait le nom du MJ de la réponse) : ce n'est plus vrai
// depuis qu'un utilisateur peut renseigner un nom d'affichage via
// `auth.updateUser({data: {full_name: ...}})` côté app mobile
// (`user_metadata.full_name`, Supabase Auth standard, partagé entre les
// deux apps). gm_display_name est ce nom, ou `null` si le MJ ne l'a pas
// renseigné (cas courant tant qu'aucune UI web ne permet de le faire) —
// voir 20260906000000_add_stories_gm_display_name.sql pour la fonction
// Postgres qui porte ce repli. Le mobile doit donc afficher un repli propre
// (ex. masquer la ligne "MJ") quand ce champ est `null`, jamais une chaîne
// vide.

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
    gm_display_name: story.gm_display_name,
  });
});
