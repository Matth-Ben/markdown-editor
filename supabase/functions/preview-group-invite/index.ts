// preview-group-invite — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — Système de groupe
// (12-partage-et-groupes.md section 2, dépôt nexus-jdr-app-mobile). Miroir
// de preview-story-invite pour le parcours "Rejoindre un groupe" : résout un
// code d'invitation et affiche les infos nécessaires à l'écran de
// confirmation mobile ("X membres") AVANT tout engagement (choix du
// personnage), sans jamais créer de rattachement -- join-group (même
// dossier ../join-group) fait tout en un seul appel atomique
// {code, character_id} et crée la ligne group_members ; inutilisable à cette
// étape où character_id n'est pas encore connu.
//
// Sans rapport avec la synchronisation "Histoires" (ne lit/écrit ni
// `stories` ni `character_campaigns`, système de groupe propre à l'app
// mobile) : pas de coordination requise avec l'équipe web pour cette
// fonction.
//
// Contrat : POST { code: string }, authentifié (même exigence que
// join-group/create-group).
//   200 { name, member_count }
//   404 { error: "invalid_code" }
//   401 { error: "unauthorized" }
//   400 { error: "invalid_body" }
//   500 { error: "internal_error" | "server_misconfigured" }
//
// Ne touche jamais group_members en écriture, ne prend pas character_id en
// entrée.

import {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  findJoinableGroup,
  jsonResponse,
  readEnvConfig,
} from "../_shared/group-invite.ts";

interface PreviewGroupInviteRequestBody {
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
      "preview-group-invite: variables d'environnement Supabase manquantes",
    );
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authResult = await authenticateRequest(req, config);
  if ("errorResponse" in authResult) return authResult.errorResponse;

  let body: PreviewGroupInviteRequestBody;
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

  const groupResult = await findJoinableGroup(admin, code);
  if ("errorResponse" in groupResult) return groupResult.errorResponse;
  const { group } = groupResult;

  const { count, error: countError } = await admin
    .from("group_members")
    .select("group_id", { count: "exact", head: true })
    .eq("group_id", group.id);

  if (countError) {
    console.error(
      "preview-group-invite: erreur de comptage group_members",
      countError,
    );
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  return jsonResponse({ name: group.name, member_count: count ?? 0 });
});
