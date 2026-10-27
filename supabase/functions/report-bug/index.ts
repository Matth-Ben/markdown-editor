// report-bug — Edge Function (Deno)
//
// Chantier "Personnages" (app mobile) — bouton "Signaler un bug" côté
// mobile. Décision produit actée : les signalements créent des issues
// GitHub sur Matth-Ben/nexus-jdr-app-mobile (gratuit, déjà l'outil du
// projet, tri/priorité natifs via labels) -- pas d'email, pas d'autre outil.
// Sans rapport avec la synchronisation "Histoires" (ne lit/écrit ni
// `stories` ni `character_campaigns`) : pas de coordination requise avec
// l'équipe web pour cette fonction.
//
// Contrat : POST, authentifié (header "Authorization: Bearer <jwt>", comme
// join-story/preview-story-invite). Corps JSON :
//   {
//     title: string,                 // requis, non vide après trim
//     description: string,           // requis, non vide après trim
//     severity: "mineur"|"majeur"|"bloquant"|"contenu",
//                                    // requis ; "contenu" = contenu D&D
//                                    // incorrect ou manquant
//     appVersion?: string,
//     platform?: string,
//     characterId?: string (uuid),
//     screenshotPath?: string        // facultatif, voir ci-dessous
//   }
//
// Capture d'écran (facultative, une seule image max) — procédure côté app :
//   1. Téléverser l'image dans le bucket Storage PRIVÉ
//      `bug-report-screenshots` (SCREENSHOT_BUCKET), avec le JWT de
//      l'utilisateur, au chemin :
//          <auth.uid()>/<nom de fichier>
//      - exactement un niveau de dossier, égal à l'uid de l'utilisateur
//        connecté (en minuscules, tel que renvoyé par Supabase Auth) ;
//      - nom de fichier : 1 à 128 caractères parmi [A-Za-z0-9._-], ne
//        commençant pas par "." -- recommandé : "<uuid v4>.<ext>" ;
//      - extension .jpg, .jpeg, .png ou .webp ; contentType image/jpeg,
//        image/png ou image/webp ; 5 Mo max (limites du bucket) ;
//      - SANS upsert (upsert: false, valeur par défaut) : le bucket n'expose
//        aucune policy SELECT/UPDATE/DELETE côté client, l'upsert serait
//        refusé. Corollaire : l'app ne peut ni relire ni supprimer l'image.
//   2. Appeler report-bug avec screenshotPath = ce même chemin (sans le nom
//      du bucket, sans "/" initial), ex.
//          "3f0c…-…/9b2e…-….png"
//   report-bug refuse (400 invalid_body) tout chemin qui ne commence pas par
//   "<uid de l'appelant>/" ou ne respecte pas le format, et (400
//   screenshot_not_found) un chemin bien formé dont l'objet n'existe pas
//   dans le bucket. Le chemin est enregistré dans
//   bug_reports.screenshot_path. L'issue GitHub (dépôt PUBLIC) ne contient
//   ni l'image ni aucun lien, même signé : seulement la mention « Capture
//   d'écran : jointe (consultable côté Supabase via l'id du signalement) ».
//   Ni le chemin brut (il contient l'uid de l'utilisateur -- même règle
//   "aucune donnée identifiante" que buildIssueBody) ni les noms internes
//   (bucket, colonne) n'y figurent.
//
// Réponses :
//   200 { id, status: "synced"|"failed", github_issue_url? }
//     -- renvoyé dès que l'INSERT dans bug_reports a réussi, MÊME SI l'appel
//     à l'API GitHub échoue ensuite (status vaut alors "failed", mais la
//     ligne existe en base pour un traitement manuel/rejouable). Voir étapes
//     ci-dessous : c'est le point de conception le plus important de cette
//     fonction.
//   400 { error: "invalid_body", message }
//   400 { error: "screenshot_not_found", message }    (screenshotPath absent du bucket)
//   401 { error: "unauthorized"|..., message }        (authenticateRequest)
//   405 { error: "method_not_allowed" }
//   500 { error: "internal_error", message }           (l'INSERT lui-même, ou la
//                                                       vérification Storage, a échoué)
//   500 { error: "server_misconfigured" }               (env Supabase manquantes)
//
// Étapes :
//   1. Authentifie l'appelant via le JWT -> auth.uid().
//   2. Valide le corps (title/description/severity non vides, severity dans
//      l'enum, characterId bien un uuid si fourni -- pas de vérification
//      d'appartenance : c'est un contexte informatif, pas une donnée
//      sensible modifiée ; screenshotPath au format "<uid appelant>/<fichier>"
//      si fourni, puis existence de l'objet dans le bucket vérifiée avec le
//      client service_role -- le client n'a pas de droit de lecture).
//   3. INSERT dans bug_reports via le client scoped-utilisateur (respecte la
//      policy RLS INSERT -- reporter_id = auth.uid() -- voir
//      20260903100000_create_bug_reports.sql), status='pending' par défaut.
//      Fait AVANT tout appel GitHub, pour ne jamais perdre un signalement si
//      l'API GitHub est indisponible/en erreur.
//   4. Si l'INSERT échoue -> 500 internal_error, on s'arrête là (rien à
//      synchroniser).
//   5. Si l'INSERT réussit, tente de créer l'issue GitHub (API REST,
//      POST /repos/Matth-Ben/nexus-jdr-app-mobile/issues, token
//      GITHUB_BUG_REPORT_TOKEN -- secret d'edge function, PAT fine-grained
//      "Issues: write" sur ce seul dépôt, voir le commentaire plus bas et le
//      rapport de la tâche pour la procédure de génération/configuration).
//   6. Met à jour la ligne (client service_role, hors RLS -- voir
//      20260903100100_grant_service_role_report_bug.sql) : status='synced'
//      + github_issue_number/github_issue_url si succès, status='failed' +
//      error_message sinon (échec réseau, token manquant/expiré, rate
//      limit...). Cette étape échoue silencieusement du point de vue de
//      l'app mobile -- on répond 200 dans tous les cas où l'étape 3 a
//      réussi, voir le contrat ci-dessus.

import {
  authenticateRequest,
  corsHeaders,
  createAdminClient,
  createUserScopedClient,
  jsonResponse,
  readEnvConfig,
} from "../_shared/http.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  buildIssueBody,
  issueLabels,
  parseScreenshotPath,
  SCREENSHOT_BUCKET,
  type Severity,
  SEVERITIES,
  type SyncInput,
} from "./issue.ts";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const GITHUB_REPO = "Matth-Ben/nexus-jdr-app-mobile";

interface ReportBugRequestBody {
  title?: unknown;
  description?: unknown;
  severity?: unknown;
  appVersion?: unknown;
  platform?: unknown;
  characterId?: unknown;
  screenshotPath?: unknown;
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
    console.error("report-bug: variables d'environnement Supabase manquantes");
    return jsonResponse({ error: "server_misconfigured" }, 500);
  }

  const authResult = await authenticateRequest(req, config);
  if ("errorResponse" in authResult) return authResult.errorResponse;
  const { user, authHeader } = authResult;

  let body: ReportBugRequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(
      { error: "invalid_body", message: "Corps de requête JSON invalide." },
      400,
    );
  }

  const title = typeof body.title === "string" ? body.title.trim() : "";
  const description =
    typeof body.description === "string" ? body.description.trim() : "";
  const severity =
    typeof body.severity === "string" ? (body.severity as Severity) : undefined;
  const appVersion =
    typeof body.appVersion === "string" && body.appVersion.trim()
      ? body.appVersion.trim()
      : null;
  const platform =
    typeof body.platform === "string" && body.platform.trim()
      ? body.platform.trim()
      : null;
  const characterIdRaw =
    typeof body.characterId === "string" ? body.characterId.trim() : "";
  const characterId = characterIdRaw || null;

  if (!title || !description || !severity || !SEVERITIES.includes(severity)) {
    return jsonResponse(
      {
        error: "invalid_body",
        message:
          "Les champs title, description et severity (mineur/majeur/bloquant/contenu) sont requis.",
      },
      400,
    );
  }

  if (characterId && !UUID_RE.test(characterId)) {
    return jsonResponse(
      { error: "invalid_body", message: "characterId doit être un uuid valide." },
      400,
    );
  }

  const screenshot = parseScreenshotPath(body.screenshotPath, user.id);
  if (!screenshot.ok) {
    return jsonResponse({ error: "invalid_body", message: screenshot.message }, 400);
  }
  const screenshotPath = screenshot.path;

  const admin = createAdminClient(config);

  if (screenshotPath) {
    const exists = await screenshotExists(admin, screenshotPath);
    if (exists === "error") {
      return jsonResponse(
        { error: "internal_error", message: "Erreur serveur." },
        500,
      );
    }
    if (!exists) {
      return jsonResponse(
        {
          error: "screenshot_not_found",
          message: "Aucune capture d'écran trouvée à ce chemin dans le bucket.",
        },
        400,
      );
    }
  }

  // Étape 3 : INSERT via le client scoped-utilisateur (JWT transmis), pour
  // que la garantie "reporter_id = auth.uid()" vienne de la policy RLS
  // INSERT elle-même, pas seulement de ce qu'on écrit ici applicativement.
  const userClient = createUserScopedClient(config, authHeader);

  const { data: bugReport, error: insertError } = await userClient
    .from("bug_reports")
    .insert({
      reporter_id: user.id,
      title,
      description,
      severity,
      app_version: appVersion,
      platform,
      character_id: characterId,
      screenshot_path: screenshotPath,
    })
    .select("id, created_at")
    .single();

  if (insertError || !bugReport) {
    console.error("report-bug: erreur d'insertion bug_reports", insertError);
    return jsonResponse(
      { error: "internal_error", message: "Erreur serveur." },
      500,
    );
  }

  // À partir d'ici, le signalement est en base (status='pending') : la
  // réponse à l'app mobile sera 200 quoi qu'il arrive dans la suite. Tout ce
  // qui suit est "best effort" et ne doit plus jamais faire échouer la
  // réponse HTTP.
  const syncResult = await syncToGithub(bugReport.id, {
    title,
    description,
    severity,
    appVersion,
    platform,
    hasScreenshot: screenshotPath !== null,
  });

  if (syncResult.ok) {
    const { error: updateError } = await admin
      .from("bug_reports")
      .update({
        status: "synced",
        github_issue_number: syncResult.issueNumber,
        github_issue_url: syncResult.issueUrl,
      })
      .eq("id", bugReport.id);
    if (updateError) {
      // La ligne reste "pending" en base -- pas idéal (l'issue existe bien
      // côté GitHub mais ce n'est pas tracé) mais ne doit pas faire échouer
      // la réponse à l'app mobile : le signalement lui-même n'est pas perdu.
      console.error(
        "report-bug: erreur de mise à jour bug_reports après succès GitHub",
        updateError,
      );
    }
    return jsonResponse({
      id: bugReport.id,
      status: "synced",
      github_issue_url: syncResult.issueUrl,
    });
  }

  const { error: updateError } = await admin
    .from("bug_reports")
    .update({ status: "failed", error_message: syncResult.errorMessage })
    .eq("id", bugReport.id);
  if (updateError) {
    console.error(
      "report-bug: erreur de mise à jour bug_reports après échec GitHub",
      updateError,
    );
  }

  return jsonResponse({ id: bugReport.id, status: "failed" });
});

/** Vérifie, avec le client service_role (le client n'a aucune policy
 * SELECT sur ce bucket), que l'objet existe, via un appel direct
 * `exists(path)` (HEAD sur l'objet). Contrat de storage-js : data=true si
 * l'objet existe, data=false (avec error) sur 400/404, exception pour toute
 * autre erreur. "error" dans ce dernier cas, pour ne pas confondre une panne
 * Storage avec un chemin inexistant. */
async function screenshotExists(
  admin: SupabaseClient,
  path: string,
): Promise<boolean | "error"> {
  try {
    const { data } = await admin.storage.from(SCREENSHOT_BUCKET).exists(path);
    return data === true;
  } catch (err) {
    console.error("report-bug: erreur de vérification Storage", err);
    return "error";
  }
}

type SyncResult =
  | { ok: true; issueNumber: number; issueUrl: string }
  | { ok: false; errorMessage: string };

/** Tente de créer l'issue GitHub correspondant au signalement déjà inséré
 * (bugReportId, uniquement utilisé pour le traçer dans le corps de
 * l'issue). Ne lève jamais -- toute erreur (réseau, token manquant, réponse
 * GitHub non-2xx) est renvoyée comme { ok: false, errorMessage } pour que
 * l'appelant puisse la stocker dans bug_reports.error_message. */
async function syncToGithub(
  bugReportId: string,
  input: SyncInput,
): Promise<SyncResult> {
  const token = Deno.env.get("GITHUB_BUG_REPORT_TOKEN");
  if (!token) {
    return {
      ok: false,
      errorMessage:
        "GITHUB_BUG_REPORT_TOKEN non configuré côté edge function (secret Supabase manquant).",
    };
  }

  const body = {
    title: input.title,
    body: buildIssueBody(bugReportId, input),
    labels: issueLabels(input.severity),
  };

  try {
    const res = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/issues`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
        "User-Agent": "nexus-jdr-report-bug-edge-function",
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const responseText = await res.text().catch(() => "");
      return {
        ok: false,
        errorMessage: `GitHub API ${res.status} ${res.statusText}: ${responseText.slice(0, 500)}`,
      };
    }

    const issue = await res.json();
    if (typeof issue.number !== "number" || typeof issue.html_url !== "string") {
      return {
        ok: false,
        errorMessage: "Réponse GitHub inattendue (number/html_url manquants).",
      };
    }

    return { ok: true, issueNumber: issue.number, issueUrl: issue.html_url };
  } catch (err) {
    return {
      ok: false,
      errorMessage: `Erreur réseau lors de l'appel GitHub: ${String(err)}`,
    };
  }
}
