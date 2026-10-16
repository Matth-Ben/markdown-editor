// join-group — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — Système de groupe
// (12-partage-et-groupes.md section 2, dépôt nexus-jdr-app-mobile). Miroir
// exact de join-story pour le parcours "Rejoindre un groupe" : dernière
// étape, après preview-group-invite (résoudre le code, afficher le nom/le
// nombre de membres pour confirmation) et le choix du personnage côté
// mobile (ou le choix explicite de rejoindre sans personnage, comme MJ) --
// crée le rattachement, donc ne doit être appelée qu'une fois le joueur
// arrivé au bout du parcours.
//
// Sans rapport avec la synchronisation "Histoires" (système de groupe propre
// à l'app mobile, `groups.campaign_id` n'est pas exploité par cette
// itération -- voir 12-partage-et-groupes.md section 4) : pas de
// coordination requise avec l'équipe web pour cette fonction.
//
// Contrat : POST { code: string, character_id?: string }, authentifié via
// le JWT Supabase de l'utilisateur (header "Authorization: Bearer <jwt>").
// `character_id` est optionnel depuis la décision du 12/10/2026
// (12-partage-et-groupes.md section 2, 20261013100000_group_member_without_
// character.sql) : un joueur peut rejoindre un groupe SANS personnage, avec
// le rôle de MJ -- absent, null ou chaîne vide sont tous traités comme "pas
// de personnage" (`group_members.character_id = null`, `is_game_master =
// true`). Au plus UN membre MJ volontaire par groupe (contrainte base
// `group_members_one_game_master_per_group`,
// 20261016090000_group_members_orphan_character.sql -- ne compte plus un
// membre ORPHELIN, `is_game_master = false`, dont le personnage a été
// supprimé après coup : voir cette migration pour le détail de la
// distinction).
//   200 { group_id, name }
//   400 { error: "invalid_body" }
//   403 { error: "character_not_owned" }
//   404 { error: "invalid_code" }
//   409 { error: "already_in_group" }
//   409 { error: "mj_already_assigned" }
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
//   3. Si character_id est fourni, vérifie côté serveur (client
//      service_role, jamais en confiance client) qu'il appartient bien à
//      auth.uid(). Si absent, aucune vérification à faire (rien à
//      vérifier) : l'appelant rejoint comme MJ sans personnage.
//   4. Vérifie qu'aucune ligne group_members n'existe déjà pour
//      (group_id, user_id=auth.uid()) -- contrainte unique
//      `group_members_group_id_user_id_key` -- avant d'insérer : un joueur
//      ne participe à un même groupe qu'avec UN SEUL rattachement à la fois
//      (spec section 2.1), message clair plutôt qu'une 500 issue de la
//      violation de contrainte brute.
//   5. Si character_id est absent, vérifie qu'aucun MJ VOLONTAIRE
//      (character_id is null ET is_game_master = true) n'existe déjà pour ce
//      groupe -- contrainte unique partielle
//      `group_members_one_game_master_per_group`
//      (20261016090000_group_members_orphan_character.sql) -- avant
//      d'insérer : un seul MJ sans personnage par groupe, même message clair
//      (`mj_already_assigned`) plutôt qu'une 500 brute. Un membre ORPHELIN
//      (personnage supprimé après coup, is_game_master = false) ne compte
//      PAS dans cette vérification -- ce n'est pas un MJ, il ne doit jamais
//      bloquer un vrai MJ qui rejoint.
//   6. Insère group_members (group_id, character_id ou null,
//      user_id=auth.uid(), role='membre', is_game_master=true si
//      character_id est absent) via le client service_role. Les
//      vérifications 4 et 5 ci-dessus laissent malgré tout une fenêtre de
//      course entre deux requêtes concurrentes (même limite que l'existant
//      pour `already_in_group`) -- un filet de sécurité sur la violation de
//      contrainte 23505 retraduit l'erreur en 409 explicite plutôt que de
//      laisser passer une 500 brute.
//   7. Retourne 200 { group_id, name } -- assez pour que le mobile navigue
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
  // Absent, null ou chaîne vide -> pas de personnage (l'appelant rejoint
  // comme MJ sans personnage). Distingué explicitement de "fourni mais
  // invalide", qui doit rester une erreur 400 plutôt que d'être
  // silencieusement traité comme absent.
  const characterIdProvided = typeof body.character_id === "string" &&
    body.character_id.trim() !== "";
  const characterId = characterIdProvided
    ? (body.character_id as string).trim()
    : null;

  if (!code) {
    return jsonResponse(
      { error: "invalid_body", message: "Le champ code est requis." },
      400,
    );
  }

  if (characterIdProvided && !UUID_RE.test(characterId as string)) {
    return jsonResponse(
      {
        error: "invalid_body",
        message: "character_id doit être un uuid valide.",
      },
      400,
    );
  }

  const admin = createAdminClient(config);

  const groupResult = await findJoinableGroup(admin, code);
  if ("errorResponse" in groupResult) return groupResult.errorResponse;
  const { group } = groupResult;

  if (characterIdProvided) {
    const { data: character, error: characterError } = await admin
      .from("characters")
      .select("id, owner_id")
      .eq("id", characterId as string)
      .maybeSingle();

    if (characterError) {
      console.error("join-group: erreur de lecture characters", characterError);
      return jsonResponse({
        error: "internal_error",
        message: "Erreur serveur.",
      }, 500);
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
    return jsonResponse(
      { error: "internal_error", message: "Erreur serveur." },
      500,
    );
  }

  if (existing) {
    // null === null -> true : couvre aussi le cas "déjà membre sans
    // personnage" (MJ), pas seulement l'égalité entre deux character_id.
    const sameCharacter = existing.character_id === characterId;
    const message = characterId === null
      ? (existing.character_id === null
        ? "Vous êtes déjà membre de ce groupe sans personnage (MJ)."
        : "Vous participez déjà à ce groupe avec un personnage.")
      : (sameCharacter
        ? "Vous êtes déjà membre de ce groupe avec ce personnage."
        : "Vous participez déjà à ce groupe avec un autre personnage.");
    return jsonResponse({ error: "already_in_group", message }, 409);
  }

  // Un seul MJ VOLONTAIRE sans personnage par groupe (contrainte base
  // `group_members_one_game_master_per_group`,
  // 20261016090000_group_members_orphan_character.sql) : contrôle
  // applicatif avant l'insert pour un message d'erreur clair -- la
  // violation de contrainte en cas de course est quand même retraduite
  // plus bas (filet de sécurité). `is_game_master` (pas seulement
  // `character_id is null`) exclut volontairement les membres ORPHELINS
  // (personnage supprimé après coup) de cette vérification : un orphelin
  // n'est pas un MJ et ne doit jamais bloquer un vrai MJ qui rejoint.
  if (characterId === null) {
    const { data: existingMj, error: existingMjError } = await admin
      .from("group_members")
      .select("id")
      .eq("group_id", group.id)
      .is("character_id", null)
      .eq("is_game_master", true)
      .maybeSingle();

    if (existingMjError) {
      console.error(
        "join-group: erreur de lecture group_members (MJ sans personnage)",
        existingMjError,
      );
      return jsonResponse({
        error: "internal_error",
        message: "Erreur serveur.",
      }, 500);
    }

    if (existingMj) {
      return jsonResponse(
        {
          error: "mj_already_assigned",
          message: "Ce groupe a déjà un MJ sans personnage.",
        },
        409,
      );
    }
  }

  const { error: insertError } = await admin.from("group_members").insert({
    group_id: group.id,
    character_id: characterId,
    user_id: user.id,
    role: "membre",
    is_game_master: characterId === null,
  });

  if (insertError) {
    // 23505 = unique_violation : filet de sécurité en cas de course avec
    // une autre requête entre les vérifications ci-dessus et cet insert.
    // Trois contraintes uniques peuvent déclencher ce code
    // (20261013100000_group_member_without_character.sql et
    // 20261016090000_group_members_orphan_character.sql pour les deux
    // dernières) :
    //   - group_members_group_id_user_id_key -> already_in_group
    //   - group_members_group_id_character_id_key -> already_in_group
    //     (ne peut en pratique jamais se produire ici : un personnage
    //     n'appartient qu'à un seul utilisateur, déjà couvert par la
    //     contrainte précédente, mais le filet reste correct si ça change)
    //   - group_members_one_game_master_per_group -> mj_already_assigned
    if (insertError.code === UNIQUE_VIOLATION_CODE) {
      const constraintHint = `${insertError.message ?? ""} ${
        insertError.details ?? ""
      }`;
      if (constraintHint.includes("group_members_one_game_master_per_group")) {
        return jsonResponse(
          {
            error: "mj_already_assigned",
            message: "Ce groupe a déjà un MJ sans personnage.",
          },
          409,
        );
      }
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
    return jsonResponse(
      { error: "internal_error", message: "Erreur serveur." },
      500,
    );
  }

  return jsonResponse({ group_id: group.id, name: group.name });
});
