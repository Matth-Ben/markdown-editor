// join-story — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — Phase 4, prérequis "Invitation d'un
// joueur par le MJ" (12-partage-et-groupes.md section 5, 02-modele-donnees.md
// section 4 du cahier des charges de l'app mobile, dépôt
// nexus-jdr-app-mobile/docs/cahier-des-charges/).
//
// Étape 4 (dernière) du parcours mobile "Rejoindre une histoire"
// (04-fonctionnalites-app-mobile.md section 7.1) : Code -> Confirmation ->
// Choix du personnage -> **Validation**. Les étapes 1-2 (résoudre le code,
// afficher nom/couverture pour confirmation, AVANT tout engagement) sont
// couvertes par preview-story-invite, pas par cette fonction : join-story
// crée le rattachement, donc ne doit être appelée qu'une fois le joueur
// arrivé au bout du parcours avec un character_id choisi.
//
// IMPORTANT — À COORDONNER AVEC L'ÉQUIPE WEB AVANT MERGE : cette fonction
// touche à la synchronisation avec l'app "Histoires" (lit
// stories.invite_code/invite_code_enabled, insère dans character_campaigns
// qui alimente le futur panneau "Joueurs" côté web — voir
// 12-partage-et-groupes.md section 5.6). Ne pas merger sans validation de
// l'équipe qui maintient apps/ (Next.js).
//
// Contrat : POST { code: string, character_id: string }, authentifié via le
// JWT Supabase de l'utilisateur (header "Authorization: Bearer <jwt>").
//
// Étapes (12-partage-et-groupes.md section 5.4) :
//   1. Authentifie l'appelant via le JWT -> auth.uid().
//   2. Cherche la story par invite_code = code. Absente ou
//      invite_code_enabled = false -> erreur explicite ("code invalide" /
//      "invitation désactivée par le MJ", cf. messages attendus dans
//      04-fonctionnalites-app-mobile.md section 7.1). Logique partagée avec
//      preview-story-invite via ../_shared/story-invite.ts.
//   3. Vérifie côté serveur (client service_role, jamais en confiance
//      client) que character_id appartient bien à auth.uid().
//   4. Vérifie que (character_id, story_id) n'existe pas déjà dans
//      character_campaigns -> message clair "personnage déjà rattaché à
//      cette histoire" (pas une 500).
//   5. Insère character_campaigns (character_id, story_id, role='joueur')
//      via le client service_role — seule voie légitime d'insertion, RLS
//      n'autorise aucun insert direct côté client (voir
//      20260830100100_create_character_campaigns.sql).
//   6. Retourne un succès avec l'id de la ligne créée et les infos
//      minimales de l'histoire (nom, image de couverture) pour que l'app
//      mobile affiche la confirmation sans requête supplémentaire.

import {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  findJoinableStory,
  jsonResponse,
  readEnvConfig,
} from "../_shared/story-invite.ts";

interface JoinStoryRequestBody {
  code?: unknown;
  character_id?: unknown;
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
    console.error("join-story: variables d'environnement Supabase manquantes");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authResult = await authenticateRequest(req, config);
  if ("errorResponse" in authResult) return authResult.errorResponse;
  const { user } = authResult;

  let body: JoinStoryRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(
      { error: "invalid_body", message: "Corps de requête JSON invalide." },
      400,
    );
  }

  const code = typeof body.code === "string" ? body.code.trim() : "";
  const characterId =
    typeof body.character_id === "string" ? body.character_id : "";

  if (!code || !characterId) {
    return jsonResponse(
      {
        error: "invalid_body",
        message: "Les champs code et character_id sont requis.",
      },
      400,
    );
  }

  const admin = createAdminClient(config);

  const storyResult = await findJoinableStory(admin, code);
  if ("errorResponse" in storyResult) return storyResult.errorResponse;
  const { story } = storyResult;

  const { data: character, error: characterError } = await admin
    .from("characters")
    .select("id, owner_id")
    .eq("id", characterId)
    .maybeSingle();

  if (characterError) {
    console.error("join-story: erreur de lecture characters", characterError);
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  if (!character || character.owner_id !== user.id) {
    return jsonResponse(
      {
        error: "character_not_owned",
        message: "Ce personnage ne vous appartient pas.",
      },
      403,
    );
  }

  const { data: existing, error: existingError } = await admin
    .from("character_campaigns")
    .select("id")
    .eq("character_id", characterId)
    .eq("story_id", story.id)
    .maybeSingle();

  if (existingError) {
    console.error(
      "join-story: erreur de lecture character_campaigns",
      existingError,
    );
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  if (existing) {
    return jsonResponse(
      {
        error: "already_joined",
        message: "Ce personnage est déjà rattaché à cette histoire.",
      },
      409,
    );
  }

  const { data: campaign, error: insertError } = await admin
    .from("character_campaigns")
    .insert({ character_id: characterId, story_id: story.id, role: "joueur" })
    .select("id, joined_at")
    .single();

  if (insertError || !campaign) {
    // 23505 = unique_violation sur (character_id, story_id) : filet de
    // sécurité en cas de course avec une autre requête entre la
    // vérification ci-dessus et cet insert.
    if (insertError?.code === "23505") {
      return jsonResponse(
        {
          error: "already_joined",
          message: "Ce personnage est déjà rattaché à cette histoire.",
        },
        409,
      );
    }
    console.error(
      "join-story: erreur d'insertion character_campaigns",
      insertError,
    );
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  return jsonResponse({
    character_campaign_id: campaign.id,
    joined_at: campaign.joined_at,
    story: {
      id: story.id,
      title: story.title,
      cover_image_path: story.cover_image_path,
    },
  });
});
