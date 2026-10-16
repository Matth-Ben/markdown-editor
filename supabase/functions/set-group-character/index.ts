// set-group-character — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — Système de groupe
// (12-partage-et-groupes.md section 2, dépôt nexus-jdr-app-mobile). Corrige
// le bug produit "un groupe disparaît de la liste quand le personnage qui y
// participe est supprimé" : depuis
// 20261016090000_group_members_orphan_character.sql, supprimer un
// personnage ne supprime plus la ligne group_members (`on delete set null`
// au lieu de `on delete cascade`) -- elle devient ORPHELINE
// (character_id = null, is_game_master = false). Cette fonction est
// l'UNIQUE voie pour qu'un joueur réattache un nouveau personnage à sa
// ligne orpheline et continue de suivre le groupe.
//
// Sans rapport avec la synchronisation "Histoires" (ne touche ni `stories`
// ni `character_campaigns`, système de groupe propre à l'app mobile) : pas
// de coordination requise avec l'équipe web pour cette fonction.
//
// Contrat : POST { group_id: string, character_id: string }, authentifié
// via le JWT Supabase de l'utilisateur (header "Authorization: Bearer
// <jwt>"). PAS de character_id optionnel ici (contrairement à
// create-group/join-group) : cette fonction ne sert JAMAIS à "redevenir MJ
// sans personnage", seulement à sortir de l'état orphelin avec un vrai
// personnage.
//   200 { group_id }
//   400 { error: "invalid_body" }
//   401 { error: "unauthorized" }               (authenticateRequest)
//   403 { error: "character_not_owned" }
//   404 { error: "not_member" }
//   409 { error: "not_eligible" }
//   409 { error: "already_in_group" }
//   500 { error: "internal_error" | "server_misconfigured" }
//
// Étapes :
//   1. Authentifie l'appelant via le JWT -> auth.uid().
//   2. Valide group_id et character_id (uuid, tous deux requis -- aucun des
//      deux n'est optionnel ici, contrairement à create-group/join-group).
//   3. Vérifie côté serveur (client service_role, jamais en confiance
//      client) que character_id appartient bien à auth.uid()
//      (characters.owner_id = auth.uid()) -- même vérification que
//      create-group/join-group.
//   4. Cherche la ligne group_members pour (group_id, user_id=auth.uid()).
//      Absente -> 404 not_member (l'appelant n'est pas/plus membre de ce
//      groupe).
//   5. Vérifie que cette ligne est bien dans l'état ORPHELIN
//      (character_id is null ET is_game_master = false) -- SEULE voie de
//      remplacement légitime d'un personnage supprimé, jamais un moyen
//      général de changer de personnage dans un groupe, jamais utilisable
//      par un vrai MJ volontaire (is_game_master = true) pour s'attribuer un
//      personnage après coup. Si la ligne a déjà un personnage, ou est MJ
//      volontaire -> 409 not_eligible.
//   6. Met à jour cette ligne (character_id = nouveau personnage) via le
//      client service_role.
//   7. Filet de sécurité sur violation de contrainte unique 23505 (ex. ce
//      personnage est déjà engagé ailleurs dans le même groupe par une
//      course concurrente avec une autre requête) -> 409 already_in_group,
//      même style que join-group.
//   8. Retourne 200 { group_id }.

import {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  readEnvConfig,
} from "../_shared/group-invite.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const UNIQUE_VIOLATION_CODE = "23505";

interface SetGroupCharacterRequestBody {
  group_id?: unknown;
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
    console.error(
      "set-group-character: variables d'environnement Supabase manquantes",
    );
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authResult = await authenticateRequest(req, config);
  if ("errorResponse" in authResult) return authResult.errorResponse;
  const { user } = authResult;

  let body: SetGroupCharacterRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(
      { error: "invalid_body", message: "Corps de requête JSON invalide." },
      400,
    );
  }

  const groupId = typeof body.group_id === "string" ? body.group_id.trim() : "";
  const characterId = typeof body.character_id === "string"
    ? body.character_id.trim()
    : "";

  if (!groupId || !UUID_RE.test(groupId)) {
    return jsonResponse(
      { error: "invalid_body", message: "group_id doit être un uuid valide." },
      400,
    );
  }

  if (!characterId || !UUID_RE.test(characterId)) {
    return jsonResponse(
      {
        error: "invalid_body",
        message: "character_id doit être un uuid valide.",
      },
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
    console.error(
      "set-group-character: erreur de lecture characters",
      characterError,
    );
    return jsonResponse(
      { error: "internal_error", message: "Erreur serveur." },
      500,
    );
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

  const { data: member, error: memberError } = await admin
    .from("group_members")
    .select("id, character_id, is_game_master")
    .eq("group_id", groupId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (memberError) {
    console.error(
      "set-group-character: erreur de lecture group_members",
      memberError,
    );
    return jsonResponse(
      { error: "internal_error", message: "Erreur serveur." },
      500,
    );
  }

  if (!member) {
    return jsonResponse(
      {
        error: "not_member",
        message: "Vous n'êtes pas membre de ce groupe.",
      },
      404,
    );
  }

  // Seul un membre ORPHELIN (personnage supprimé après coup) peut utiliser
  // cette voie -- jamais un membre qui a déjà un personnage, jamais un MJ
  // volontaire. Voir le commentaire d'en-tête de
  // 20261016090000_group_members_orphan_character.sql pour la distinction
  // complète.
  if (member.character_id !== null || member.is_game_master) {
    return jsonResponse(
      {
        error: "not_eligible",
        message:
          "Ce rattachement n'est disponible que pour remplacer un personnage supprimé.",
      },
      409,
    );
  }

  const { error: updateError } = await admin
    .from("group_members")
    .update({ character_id: characterId })
    .eq("id", member.id);

  if (updateError) {
    // 23505 = unique_violation : filet de sécurité en cas de course avec une
    // autre requête concurrente -- ce personnage a été engagé ailleurs dans
    // le même groupe (group_members_group_id_character_id_key) entre la
    // lecture ci-dessus et cet update.
    if (updateError.code === UNIQUE_VIOLATION_CODE) {
      return jsonResponse(
        {
          error: "already_in_group",
          message: "Ce personnage participe déjà à ce groupe.",
        },
        409,
      );
    }
    console.error(
      "set-group-character: erreur de mise à jour group_members",
      updateError,
    );
    return jsonResponse(
      { error: "internal_error", message: "Erreur serveur." },
      500,
    );
  }

  return jsonResponse({ group_id: groupId });
});
