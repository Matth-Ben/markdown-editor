// Code commun générique (CORS, réponses JSON, config d'environnement,
// authentification par JWT) partagé par toutes les edge functions de ce
// dépôt -- pas seulement celles du parcours "Rejoindre une histoire".
//
// Extrait de ../_shared/story-invite.ts (qui ne contenait, jusqu'à
// report-bug, que des edge functions liées aux invitations MJ<->joueur) au
// moment d'ajouter la première edge function sans rapport avec ce parcours.
// story-invite.ts réexporte ces symboles pour ne rien casser côté
// join-story/preview-story-invite (aucun changement requis dans ces deux
// fichiers). Convention `_` du dossier : voir le commentaire d'en-tête de
// story-invite.ts, inchangé.

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

/** Client service_role : contourne RLS. À réserver aux opérations qui en
 * ont explicitement besoin (voir chaque fonction appelante pour le détail
 * des privilèges de table réellement accordés à service_role). */
export function createAdminClient(config: EnvConfig): SupabaseClient {
  return createClient(config.supabaseUrl, config.serviceRoleKey, {
    auth: { persistSession: false },
  });
}

/** Client "au nom de l'appelant" (clé anon + JWT transmis) : à utiliser pour
 * tout ce qui doit passer par la RLS de l'utilisateur (ex. l'INSERT initial
 * de report-bug), jamais pour lire/écrire des données protégées que
 * l'appelant ne devrait pas voir/modifier directement. */
export function createUserScopedClient(
  config: EnvConfig,
  authHeader: string,
): SupabaseClient {
  return createClient(config.supabaseUrl, config.anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
}

export interface AuthenticatedUser {
  id: string;
  email: string | null;
}

export type AuthResult =
  | { user: AuthenticatedUser; authHeader: string }
  | { errorResponse: Response };

/** Authentifie l'appelant à partir du header Authorization de la requête
 * entrante (JWT Supabase). Ne fait jamais confiance à un user id/email
 * transmis par le corps de la requête -- toujours dérivé du JWT côté
 * serveur. Retourne aussi le header Authorization brut, pour les appelants
 * qui ont ensuite besoin d'un client scoped-utilisateur
 * (createUserScopedClient) sans re-parser la requête. */
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

  // Client "au nom de l'appelant", utilisé ici uniquement pour résoudre
  // auth.uid()/l'email -> jamais pour lire des données protégées par RLS
  // (chaque fonction appelante choisit explicitement le client
  // (service_role vs scoped-utilisateur) adapté à chaque opération).
  const supabaseAuth = createUserScopedClient(config, authHeader);

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

  return { user: { id: user.id, email: user.email ?? null }, authHeader };
}
