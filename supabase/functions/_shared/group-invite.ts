// Code commun à create-group, join-group et preview-group-invite (voir leurs
// fichiers respectifs). Miroir de ../_shared/story-invite.ts pour le
// parcours "Système de groupe" (12-partage-et-groupes.md section 2, dépôt
// nexus-jdr-app-mobile) : les trois fonctions authentifient l'appelant via
// son JWT, puis résolvent/créent un groupe avec exactement les mêmes règles
// -- factorisé ici plutôt que dupliqué.
//
// Différence avec story-invite.ts : les groupes n'ont pas d'équivalent
// `invite_code_enabled` -- pas de désactivation prévue dans la spec section
// 2.2 (qui ne liste que "renommer, régénérer le code, dissoudre le groupe"
// comme actions de gestion). "Code introuvable" est donc la SEULE erreur
// possible ici, pas de notion "désactivé" comme pour les histoires.
//
// Cette factorisation contient aussi la génération de code d'invitation
// (utilisée par create-group uniquement, ni join-group ni
// preview-group-invite n'en ont besoin) -- placée ici plutôt que dans
// create-group/index.ts pour rester cohérente avec le seul autre générateur
// de ce type du dépôt (apps/web/app/(dashboard)/story/[id]/joueurs/actions.ts,
// `generateInviteCode`) : même alphabet, même longueur, même stratégie de
// retry borné sur une violation de contrainte unique -- un futur ajustement
// de l'un des deux algorithmes reste une décision consciente plutôt qu'une
// dérive silencieuse.
//
// Convention `_` du dossier : voir le commentaire d'en-tête de
// story-invite.ts, inchangé.

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

export interface GroupInviteRow {
  id: string;
  name: string;
  owner_id: string;
}

export type FindGroupResult =
  | { group: GroupInviteRow }
  | { errorResponse: Response };

/** Cherche un groupe par invite_code. Utilisé par join-group (avant de
 * vérifier/rattacher un personnage) et preview-group-invite (qui s'arrête
 * là). `admin` doit être un client service_role : invite_code n'est jamais
 * lisible via une policy select cliente (20260906182601_create_groups.sql,
 * "Pas de policy INSERT pour authenticated"). Contrairement à
 * findJoinableStory, aucune notion de désactivation -- un groupe créé a
 * toujours un code actif, voir le commentaire d'en-tête. */
export async function findJoinableGroup(
  admin: SupabaseClient,
  code: string,
): Promise<FindGroupResult> {
  const { data: group, error } = await admin
    .from("groups")
    .select("id, name, owner_id")
    .eq("invite_code", code)
    .maybeSingle();

  if (error) {
    console.error("group-invite: erreur de lecture groups", error);
    return {
      errorResponse: jsonResponse(
        { error: "internal_error", message: "Erreur serveur." },
        500,
      ),
    };
  }

  if (!group) {
    return {
      errorResponse: jsonResponse({ error: "invalid_code", message: "Code invalide." }, 404),
    };
  }

  return { group };
}

// Génération du code d'invitation ------------------------------------------

const INVITE_CODE_LENGTH = 8;
// Alphanumérique majuscule, sans caractères ambigus (0/O, 1/I/L) -- même
// alphabet que celui déjà choisi côté web pour les histoires
// (apps/web/app/(dashboard)/story/[id]/joueurs/actions.ts), reste cohérent.
const INVITE_CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
const MAX_GENERATION_ATTEMPTS = 5;
const UNIQUE_VIOLATION_CODE = "23505";

/** Pure -- génère un candidat de code d'invitation (pas de garantie
 * d'unicité, à tenter contre la contrainte unique de la table). Web Crypto
 * (`crypto.getRandomValues`, disponible nativement dans le runtime Deno des
 * edge functions) plutôt que `node:crypto`/`randomInt` (utilisé côté
 * actions.ts Next.js) : pas de raison d'ajouter une dépendance npm ici pour
 * un besoin déjà couvert par l'API standard du runtime cible. */
export function generateInviteCodeCandidate(): string {
  const bytes = new Uint8Array(INVITE_CODE_LENGTH);
  crypto.getRandomValues(bytes);
  let code = "";
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    code += INVITE_CODE_ALPHABET[bytes[i] % INVITE_CODE_ALPHABET.length];
  }
  return code;
}

export interface NewGroupRow {
  id: string;
  name: string;
  invite_code: string;
}

export type CreateGroupRowResult =
  | { group: NewGroupRow }
  | { errorResponse: Response };

/** Insère la ligne `groups` (name, owner_id, invite_code généré) via le
 * client service_role -- seule voie légitime d'insertion, RLS n'autorise
 * aucun insert direct côté client sur `groups` (deny-all volontaire, voir
 * 20260906182601_create_groups.sql). Retente jusqu'à
 * MAX_GENERATION_ATTEMPTS fois en cas de collision de code (violation de
 * contrainte unique Postgres 23505 sur `groups.invite_code`), avant
 * d'abandonner avec une erreur serveur explicite -- l'espace de codes
 * (31^8) rend une collision réelle improbable, mais le cas est géré
 * proprement plutôt que de remonter une erreur brute à l'appelant. */
export async function insertGroupWithGeneratedInviteCode(
  admin: SupabaseClient,
  params: { name: string; ownerId: string },
): Promise<CreateGroupRowResult> {
  for (let attempt = 0; attempt < MAX_GENERATION_ATTEMPTS; attempt++) {
    const inviteCode = generateInviteCodeCandidate();
    const { data, error } = await admin
      .from("groups")
      .insert({ name: params.name, owner_id: params.ownerId, invite_code: inviteCode })
      .select("id, name, invite_code")
      .single();

    if (!error && data) {
      return { group: data };
    }

    if (error?.code !== UNIQUE_VIOLATION_CODE) {
      console.error("group-invite: erreur d'insertion groups", error);
      return {
        errorResponse: jsonResponse(
          { error: "internal_error", message: "Erreur serveur." },
          500,
        ),
      };
    }
    // Collision de code (23505) : on retente avec un nouveau candidat.
  }

  console.error(
    `group-invite: échec de génération d'un invite_code unique après ${MAX_GENERATION_ATTEMPTS} tentatives`,
  );
  return {
    errorResponse: jsonResponse(
      {
        error: "internal_error",
        message: "Impossible de générer un code d'invitation unique, réessaie.",
      },
      500,
    ),
  };
}
