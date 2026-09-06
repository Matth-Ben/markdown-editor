// create-group — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — Système de groupe
// (12-partage-et-groupes.md section 2, dépôt nexus-jdr-app-mobile). Propre à
// l'app mobile, indépendant de l'app web "Histoires" pour cette itération
// (voir 20260906182601_create_groups.sql) : contrairement à
// join-story/preview-story-invite, cette fonction ne touche ni `stories` ni
// `character_campaigns` -- pas de coordination requise avec l'équipe web.
//
// Contrat : POST { name: string, character_id: string }, authentifié via le
// JWT Supabase de l'utilisateur (header "Authorization: Bearer <jwt>").
//   200 { id, name, invite_code }
//   400 { error: "invalid_body" }
//   403 { error: "character_not_owned" }
//   401 { error: "unauthorized" }             (authenticateRequest)
//   500 { error: "internal_error" | "server_misconfigured" }
//
// Étapes (12-partage-et-groupes.md section 2.1/2.2, commentaire de
// 20260906182601_create_groups.sql sur `groups`/`group_members` -- deny-all
// volontaire pour authenticated, créer/rejoindre un groupe DOIT passer par
// une edge function service_role) :
//   1. Authentifie l'appelant via le JWT -> auth.uid().
//   2. Valide name (non vide, trim) et character_id (uuid).
//   3. Vérifie côté serveur (client service_role, jamais en confiance
//      client) que character_id appartient bien à auth.uid().
//   4. Génère un invite_code et insère `groups` (name, owner_id=auth.uid())
//      via le client service_role -- voir
//      ../_shared/group-invite.ts#insertGroupWithGeneratedInviteCode.
//   5. Insère `group_members` (group_id, character_id, user_id=auth.uid(),
//      role='owner') via le même client -- indispensable : le trigger
//      groups_after_insert (20260906182601_create_groups.sql) ne crée que
//      group_treasure, PAS group_members (il ne connaît pas le character_id
//      choisi par le créateur) ; sans cette étape, le créateur ne serait
//      membre d'aucun groupe qu'il vient pourtant de créer.
//   6. Si l'insertion group_members échoue après le succès de l'insertion
//      groups (cas rare -- ex. erreur transitoire), supprime la ligne
//      groups fraîchement créée avant de renvoyer une erreur : rollback
//      applicatif, pas de transaction multi-table possible depuis une edge
//      function sans RPC dédiée -- nécessaire pour ne pas laisser un groupe
//      orphelin sans aucun membre (group_treasure, créée par le trigger,
//      disparaît avec `groups` en cascade -- 20260906182601_create_groups.sql).
//   7. Retourne 200 { id, name, invite_code }.

import {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  insertGroupWithGeneratedInviteCode,
  jsonResponse,
  readEnvConfig,
} from "../_shared/group-invite.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface CreateGroupRequestBody {
  name?: unknown;
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
    console.error("create-group: variables d'environnement Supabase manquantes");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authResult = await authenticateRequest(req, config);
  if ("errorResponse" in authResult) return authResult.errorResponse;
  const { user } = authResult;

  let body: CreateGroupRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(
      { error: "invalid_body", message: "Corps de requête JSON invalide." },
      400,
    );
  }

  const name = typeof body.name === "string" ? body.name.trim() : "";
  const characterId =
    typeof body.character_id === "string" ? body.character_id : "";

  if (!name) {
    return jsonResponse(
      { error: "invalid_body", message: "Le champ name est requis." },
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

  const { data: character, error: characterError } = await admin
    .from("characters")
    .select("id, owner_id")
    .eq("id", characterId)
    .maybeSingle();

  if (characterError) {
    console.error("create-group: erreur de lecture characters", characterError);
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

  const groupResult = await insertGroupWithGeneratedInviteCode(admin, {
    name,
    ownerId: user.id,
  });
  if ("errorResponse" in groupResult) return groupResult.errorResponse;
  const { group } = groupResult;

  const { error: memberError } = await admin.from("group_members").insert({
    group_id: group.id,
    character_id: characterId,
    user_id: user.id,
    role: "owner",
  });

  if (memberError) {
    console.error(
      "create-group: erreur d'insertion group_members, rollback du groupe",
      memberError,
    );
    const { error: rollbackError } = await admin
      .from("groups")
      .delete()
      .eq("id", group.id);
    if (rollbackError) {
      console.error(
        "create-group: échec du rollback de groups après échec de group_members",
        rollbackError,
      );
    }
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  return jsonResponse({ id: group.id, name: group.name, invite_code: group.invite_code });
});
