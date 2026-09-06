// send-push-notification — Edge Function (Deno)
//
// Chantier "Notifications push/email" (app mobile "Personnages") —
// 15-profil-parametres.md section 3.
//
// Fonction de BAS NIVEAU, appelée en interne uniquement (par le trigger DB
// `character_campaigns_notify_access_revoked` via pg_net, ou par
// send-rest-reminders/send-weekly-digest via un appel HTTP direct) -- jamais
// exposée à l'app mobile. Sans rapport avec la synchronisation "Histoires"
// au sens propre (elle ne lit/écrit ni `stories` ni `character_campaigns`,
// seulement `user_push_tokens`) : pas de coordination avec l'équipe web pour
// CETTE fonction. C'est son appelant côté trigger DB
// (20260906160400_notify_character_campaign_access_revoked.sql) qui, lui,
// nécessite cette coordination -- voir le commentaire d'en-tête de cette
// migration.
//
// Authentification : PAS un JWT utilisateur (cette fonction n'agit jamais au
// nom d'un utilisateur précis qui l'appellerait) -- un header
// "Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>" (la même clé
// service_role déjà utilisée ailleurs dans ce projet, pas un nouveau secret)
// prouve que seul le backend Supabase lui-même (trigger pg_net, autre edge
// function) peut l'appeler.
//
// Contrat : POST { userId: uuid, title: string, body: string,
// data?: Record<string,string> } -> 200 { sent: n, failed: m }.
//
// Étapes :
//   1. Vérifie l'auth interne (Authorization: Bearer service_role_key).
//   2. Valide le corps (userId uuid, title/body non vides, data si présent
//      filtré aux seules entrées string -- voir sanitizeNotificationData).
//   3. Lit tous les tokens de user_push_tokens pour userId (client
//      service_role, hors RLS -- voir
//      20260906160200_grant_service_role_notifications.sql pour les GRANTs
//      nécessaires). Aucun token -> 200 { sent: 0, failed: 0 } (utilisateur
//      sans appareil enregistré, pas une erreur).
//   4. Obtient un access token OAuth2 pour l'API FCM HTTP v1, à partir du
//      compte de service Firebase (FIREBASE_SERVICE_ACCOUNT_JSON, secret
//      d'edge function -- voir getFirebaseAccessToken ci-dessous). Le
//      project_id utilisé dans l'URL FCM vient de ce même JSON, jamais codé
//      en dur.
//   5. Envoie un message FCM par token (buildFcmMessage + sendFcmMessage).
//      Si FCM répond que le token est invalide/expiré
//      (error.status = UNREGISTERED | INVALID_ARGUMENT, voir
//      isInvalidFcmTokenError), supprime la ligne user_push_tokens
//      correspondante -- sans faire échouer la requête globale si d'autres
//      tokens ont réussi.
//   6. Retourne 200 { sent: n, failed: m } dans tous les cas où l'étape 3 a
//      réussi.
//
// IMPORTANT -- FIREBASE_SERVICE_ACCOUNT_JSON n'est PAS encore configuré
// (secret Supabase à ajouter par l'utilisateur via Dashboard -> Edge
// Functions -> Secrets). Tant qu'il est absent, getFirebaseAccessToken()
// renvoie systématiquement null : cette fonction répond alors
// { sent: 0, failed: <nombre de tokens> } pour tout utilisateur ayant au
// moins un token enregistré -- comportement de production légitime (secret
// manquant/invalide), pas un bug. L'envoi réel (obtention du token OAuth2 +
// appel FCM) ne peut donc PAS être vérifié de bout en bout tant que ce
// secret n'est pas configuré ; voir index.test.ts pour ce qui reste
// testable sans lui (construction du payload FCM, décision de suppression
// de token, validation du corps de requête).

import {
  corsHeaders,
  createAdminClient,
  jsonResponse,
  readEnvConfig,
} from "../_shared/http.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface SendPushNotificationRequestBody {
  userId?: unknown;
  title?: unknown;
  body?: unknown;
  data?: unknown;
}

export interface ParsedSendPushNotificationBody {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export type ParseBodyResult =
  | { ok: true; value: ParsedSendPushNotificationBody }
  | { ok: false; message: string };

/** Pure -- ne fait aucune I/O. Valide et normalise le corps de requête. */
export function parseSendPushNotificationBody(
  raw: SendPushNotificationRequestBody,
): ParseBodyResult {
  const userId = typeof raw.userId === "string" ? raw.userId.trim() : "";
  const title = typeof raw.title === "string" ? raw.title : "";
  const body = typeof raw.body === "string" ? raw.body : "";

  if (!UUID_RE.test(userId)) {
    return { ok: false, message: "userId doit être un uuid valide." };
  }
  if (!title || !body) {
    return { ok: false, message: "Les champs title et body sont requis." };
  }

  return {
    ok: true,
    value: { userId, title, body, data: sanitizeNotificationData(raw.data) },
  };
}

/** Pure -- ne conserve que les entrées dont la valeur est une string
 * (contrat FCM : `data` est un `Map<string,string>`), `undefined` si rien
 * d'exploitable (objet absent, non-objet, tableau, ou aucune entrée string).
 */
export function sanitizeNotificationData(
  raw: unknown,
): Record<string, string> | undefined {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return undefined;

  const entries = Object.entries(raw as Record<string, unknown>).filter(
    (entry): entry is [string, string] => typeof entry[1] === "string",
  );

  return entries.length > 0 ? Object.fromEntries(entries) : undefined;
}

export interface FcmMessage {
  message: {
    token: string;
    notification: { title: string; body: string };
    data?: Record<string, string>;
  };
}

/** Pure -- construit le corps de requête FCM HTTP v1
 * (https://fcm.googleapis.com/v1/projects/{project_id}/messages:send). */
export function buildFcmMessage(
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): FcmMessage {
  return {
    message: {
      token,
      notification: { title, body },
      ...(data ? { data } : {}),
    },
  };
}

const INVALID_TOKEN_FCM_ERROR_STATUSES = new Set([
  "UNREGISTERED",
  "INVALID_ARGUMENT",
]);

/** Pure -- décide si un code d'erreur FCM v1 (`error.status` du corps de
 * réponse) signifie que le token est mort et doit être supprimé de
 * user_push_tokens, plutôt qu'une erreur transitoire à ignorer/réessayer
 * plus tard. */
export function isInvalidFcmTokenError(
  fcmErrorStatus: string | undefined | null,
): boolean {
  return !!fcmErrorStatus && INVALID_TOKEN_FCM_ERROR_STATUSES.has(fcmErrorStatus);
}

// `Deno.serve` n'est appelé que si ce fichier est exécuté directement (voir
// `if (import.meta.main)` tout en bas) -- pas quand index.test.ts l'importe
// pour tester la logique pure ci-dessus, sinon l'import déclencherait un
// vrai `listen()` réseau (échoue sans --allow-net, et laisserait un
// listener ouvert si on l'accordait).
async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const config = readEnvConfig();
  if (!config) {
    console.error(
      "send-push-notification: variables d'environnement Supabase manquantes",
    );
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (authHeader !== `Bearer ${config.serviceRoleKey}`) {
    return jsonResponse(
      {
        error: "unauthorized",
        message: "Fonction interne : appelable uniquement avec la clé service_role.",
      },
      401,
    );
  }

  let rawBody: SendPushNotificationRequestBody;
  try {
    rawBody = await req.json();
  } catch {
    return jsonResponse(
      { error: "invalid_body", message: "Corps de requête JSON invalide." },
      400,
    );
  }

  const parsed = parseSendPushNotificationBody(rawBody);
  if (!parsed.ok) {
    return jsonResponse({ error: "invalid_body", message: parsed.message }, 400);
  }
  const { userId, title, body, data } = parsed.value;

  const admin = createAdminClient(config);

  const { data: tokenRows, error: tokensError } = await admin
    .from("user_push_tokens")
    .select("token")
    .eq("user_id", userId);

  if (tokensError) {
    console.error(
      "send-push-notification: erreur de lecture user_push_tokens",
      tokensError,
    );
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  if (!tokenRows || tokenRows.length === 0) {
    // Utilisateur sans appareil enregistré -- cas normal (ex. jamais ouvert
    // l'app mobile, ou notifications jamais autorisées), pas une erreur.
    return jsonResponse({ sent: 0, failed: 0 });
  }

  const firebase = await getFirebaseAccessToken();
  if (!firebase) {
    // Voir le commentaire d'en-tête : secret absent/invalide, ou échange
    // OAuth2 en échec -- déjà journalisé par getFirebaseAccessToken. Tous
    // les tokens sont comptés en échec, mais la réponse reste 200 (l'appelant
    // -- trigger DB ou fonction planifiée -- ne doit pas être bloqué par
    // ça).
    return jsonResponse({ sent: 0, failed: tokenRows.length });
  }

  let sent = 0;
  let failed = 0;

  for (const { token } of tokenRows) {
    const message = buildFcmMessage(token, title, body, data);
    const result = await sendFcmMessage(firebase.projectId, firebase.accessToken, message);

    if (result.ok) {
      sent++;
      continue;
    }

    failed++;
    console.error(
      "send-push-notification: échec envoi FCM",
      token,
      result.errorMessage,
    );

    if (result.invalidToken) {
      const { error: deleteError } = await admin
        .from("user_push_tokens")
        .delete()
        .eq("token", token);
      if (deleteError) {
        console.error(
          "send-push-notification: échec suppression token invalide",
          token,
          deleteError,
        );
      }
    }
  }

  return jsonResponse({ sent, failed });
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}

// ---------------------------------------------------------------------------
// Partie réseau réelle (obtention du token OAuth2 + appel FCM) -- isolée
// dans les fonctions ci-dessous, non couvertes par index.test.ts (pas
// testable sans FIREBASE_SERVICE_ACCOUNT_JSON réel contre le vrai endpoint
// Google). Tout ce qui précède dans ce fichier (parseSendPushNotificationBody,
// sanitizeNotificationData, buildFcmMessage, isInvalidFcmTokenError) est pur
// et testé.
// ---------------------------------------------------------------------------

interface FirebaseServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

interface FirebaseAccessToken {
  accessToken: string;
  projectId: string;
}

async function getFirebaseAccessToken(): Promise<FirebaseAccessToken | null> {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    console.error(
      "send-push-notification: FIREBASE_SERVICE_ACCOUNT_JSON non configuré (secret Supabase manquant).",
    );
    return null;
  }

  let account: FirebaseServiceAccount;
  try {
    account = JSON.parse(raw);
  } catch {
    console.error(
      "send-push-notification: FIREBASE_SERVICE_ACCOUNT_JSON n'est pas un JSON valide.",
    );
    return null;
  }

  if (!account.project_id || !account.client_email || !account.private_key) {
    console.error(
      "send-push-notification: FIREBASE_SERVICE_ACCOUNT_JSON incomplet (project_id/client_email/private_key requis).",
    );
    return null;
  }

  const tokenUri = account.token_uri ?? "https://oauth2.googleapis.com/token";
  const nowSeconds = Math.floor(Date.now() / 1000);

  const jwtHeader = { alg: "RS256", typ: "JWT" };
  const jwtClaims = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: tokenUri,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };

  let jwt: string;
  try {
    const unsignedToken =
      `${base64UrlEncode(JSON.stringify(jwtHeader))}.${base64UrlEncode(JSON.stringify(jwtClaims))}`;
    const key = await importPrivateKey(account.private_key);
    const signature = await crypto.subtle.sign(
      { name: "RSASSA-PKCS1-v1_5" },
      key,
      new TextEncoder().encode(unsignedToken),
    );
    jwt = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;
  } catch (err) {
    console.error(
      "send-push-notification: échec de signature du JWT du compte de service",
      String(err),
    );
    return null;
  }

  let tokenRes: Response;
  try {
    tokenRes = await fetch(tokenUri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });
  } catch (err) {
    console.error(
      "send-push-notification: erreur réseau lors de l'échange OAuth2",
      String(err),
    );
    return null;
  }

  if (!tokenRes.ok) {
    console.error(
      "send-push-notification: échec de l'échange OAuth2",
      tokenRes.status,
      await tokenRes.text().catch(() => ""),
    );
    return null;
  }

  const tokenBody = await tokenRes.json().catch(() => null);
  if (!tokenBody || typeof tokenBody.access_token !== "string") {
    console.error(
      "send-push-notification: réponse OAuth2 inattendue (access_token manquant).",
    );
    return null;
  }

  return { accessToken: tokenBody.access_token, projectId: account.project_id };
}

function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

type SendFcmMessageResult =
  | { ok: true }
  | { ok: false; invalidToken: boolean; errorMessage: string };

async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  message: FcmMessage,
): Promise<SendFcmMessageResult> {
  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      },
    );

    if (res.ok) return { ok: true };

    const errorBody = await res.json().catch(() => null);
    const status = errorBody?.error?.status as string | undefined;

    return {
      ok: false,
      invalidToken: isInvalidFcmTokenError(status),
      errorMessage: `FCM ${res.status}: ${JSON.stringify(errorBody ?? {}).slice(0, 500)}`,
    };
  } catch (err) {
    return {
      ok: false,
      invalidToken: false,
      errorMessage: `Erreur réseau FCM: ${String(err)}`,
    };
  }
}
