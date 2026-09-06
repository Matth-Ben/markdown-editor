// join-group — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — Système de groupe
// (12-partage-et-groupes.md section 2, dépôt nexus-jdr-app-mobile). Miroir
// exact de join-story pour le parcours "Rejoindre un groupe" : dernière
// étape, après preview-group-invite (résoudre le code, afficher le nom/le
// nombre de membres pour confirmation) et le choix du personnage côté
// mobile -- crée le rattachement, donc ne doit être appelée qu'une fois le
// joueur arrivé au bout du parcours avec un character_id choisi.
//
// Sans rapport avec la synchronisation "Histoires" (système de groupe propre
// à l'app mobile, `groups.campaign_id` n'est pas exploité par cette
// itération -- voir 12-partage-et-groupes.md section 4) : pas de
// coordination requise avec l'équipe web pour cette fonction.
//
// Contrat : POST { code: string, character_id: string }, authentifié via le
// JWT Supabase de l'utilisateur (header "Authorization: Bearer <jwt>").
//   200 { group_id, name }
//   400 { error: "invalid_body" }
//   403 { error: "character_not_owned" }
//   404 { error: "invalid_code" }
//   409 { error: "already_in_group" }
//   401 { error: "unauthorized" }             (authenticateRequest)
//   500 { error: "internal_error" | "server_misconfigured" }
//
// Étapes (12-partage-et-groupes.md section 2.1/2.3, commentaire de
// 20260906182601_create_groups.sql sur `group_members` -- deny-all
// volontaire pour authenticated, rejoindre un groupe DOIT passer par une
// edge function service_role) :
//   1. Authentifie l'appelant via le JWT -> auth.uid().
//   2. Résout le groupe via findJoinableGroup (mêmes erreurs que
//      preview-group-invite -- code introuvable, pas de notion
//      "désactivé" pour les groupes).
//   3. Vérifie côté serveur (client service_role, jamais en confiance
//      client) que character_id appartient bien à auth.uid().
//   4. Vérifie qu'aucune ligne group_members n'existe déjà pour
//      (group_id, user_id=auth.uid()) -- contrainte unique
//      `group_members_group_id_user_id_key` -- avant d'insérer : un joueur
//      ne participe à un même groupe qu'avec UN SEUL personnage à la fois
//      (spec section 2.1), message clair plutôt qu'une 500 issue de la
//      violation de contrainte brute.
//   5. Insère group_members (group_id, character_id, user_id=auth.uid(),
//      role='membre') via le client service_role.
//   6. Retourne 200 { group_id, name } -- assez pour que le mobile navigue
//      directement vers l'écran "Groupe" sans requête supplémentaire.

import {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  findJoinableGroup,
  jsonResponse,
  readEnvConfig,
} from "../_shared/group-invite.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const UNIQUE_VIOLATION_CODE = "23505";

interface JoinGroupRequestBody {
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
    console.error("join-group: variables d'environnement Supabase manquantes");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authResult = await authenticateRequest(req, config);
  if ("errorResponse" in authResult) return authResult.errorResponse;
  const { user } = authResult;

  let body: JoinGroupRequestBody;
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

  if (!code) {
    return jsonResponse(
      { error: "invalid_body", message: "Le champ code est requis." },
      400,
    );
  }

  if (!UUID_RE.test(characterId)) {
    return jsonResponse(
      { error: "invalid_body", message: "character_id doit être un uuid valide." },
      400,
    );
  }

  const admin = createAdminClient(config);

  const groupResult = await findJoinableGroup(admin, code);
  if ("errorResponse" in groupResult) return groupResult.errorResponse;
  const { group } = groupResult;

  const { data: character, error: characterError } = await admin
    .from("characters")
    .select("id, owner_id")
    .eq("id", characterId)
    .maybeSingle();

  if (characterError) {
    console.error("join-group: erreur de lecture characters", characterError);
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
    .from("group_members")
    .select("character_id")
    .eq("group_id", group.id)
    .eq("user_id", user.id)
    .maybeSingle();

  if (existingError) {
    console.error(
      "join-group: erreur de lecture group_members",
      existingError,
    );
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  if (existing) {
    const sameCharacter = existing.character_id === characterId;
    return jsonResponse(
      {
        error: "already_in_group",
        message: sameCharacter
          ? "Vous êtes déjà membre de ce groupe avec ce personnage."
          : "Vous participez déjà à ce groupe avec un autre personnage.",
      },
      409,
    );
  }

  const { error: insertError } = await admin.from("group_members").insert({
    group_id: group.id,
    character_id: characterId,
    user_id: user.id,
    role: "membre",
  });

  if (insertError) {
    // 23505 = unique_violation sur (group_id, user_id) ou (group_id,
    // character_id) : filet de sécurité en cas de course avec une autre
    // requête entre la vérification ci-dessus et cet insert.
    if (insertError.code === UNIQUE_VIOLATION_CODE) {
      // Message neutre plutôt que "avec un autre personnage" : dans ce
      // filet de sécurité (course avec une autre requête concurrente), on
      // ne sait pas si le gagnant de la course a utilisé le MÊME personnage
      // ou un autre -- affirmer "un autre personnage" serait parfois faux
      // (ex. double-tap rapide sur "Rejoindre" avec le même personnage).
      return jsonResponse(
        {
          error: "already_in_group",
          message: "Vous participez déjà à ce groupe.",
        },
        409,
      );
    }
    console.error("join-group: erreur d'insertion group_members", insertError);
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  return jsonResponse({ group_id: group.id, name: group.name });
});
