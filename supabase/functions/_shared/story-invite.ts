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

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export interface EnvConfig {
  supabaseUrl: string;
  anonKey: string;
  serviceRoleKey: string;
}

/** Lit les variables d'environnement Supabase standard, ou null si l'une
 * d'elles manque (mauvaise config du déploiement/du stack local). */
export function readEnvConfig(): EnvConfig | null {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) return null;
  return { supabaseUrl, anonKey, serviceRoleKey };
}

/** Client service_role : contourne RLS. Seule voie légitime pour lire
 * invite_code (jamais exposé via une policy select publique — voir
 * 20260830100000_add_stories_invite_code.sql). */
export function createAdminClient(config: EnvConfig): SupabaseClient {
  return createClient(config.supabaseUrl, config.serviceRoleKey, {
    auth: { persistSession: false },
  });
}

export type AuthResult =
  | { user: { id: string } }
  | { errorResponse: Response };

/** Authentifie l'appelant à partir du header Authorization de la requête
 * entrante (JWT Supabase). Ne fait jamais confiance à un user id transmis
 * par le corps de la requête — toujours dérivé du JWT côté serveur. */
export async function authenticateRequest(
  req: Request,
  config: EnvConfig,
): Promise<AuthResult> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return {
      errorResponse: jsonResponse(
        { error: "unauthorized", message: "Authentification requise." },
        401,
      ),
    };
  }

  // Client "au nom de l'appelant" (clé anon + JWT transmis), utilisé
  // uniquement pour résoudre auth.uid() -> jamais pour lire des données
  // protégées par RLS (voir findJoinableStory, qui utilise le client
  // service_role pour ça).
  const supabaseAuth = createClient(config.supabaseUrl, config.anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const {
    data: { user },
    error,
  } = await supabaseAuth.auth.getUser();

  if (error || !user) {
    return {
      errorResponse: jsonResponse(
        { error: "unauthorized", message: "Session invalide ou expirée." },
        401,
      ),
    };
  }

  return { user };
}

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
