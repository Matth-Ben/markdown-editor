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
//   { title: string, description: string, severity: "mineur"|"majeur"|"bloquant",
//     appVersion?: string, platform?: string, characterId?: string (uuid) }
//
// Réponses :
//   200 { id, status: "synced"|"failed", github_issue_url? }
//     -- renvoyé dès que l'INSERT dans bug_reports a réussi, MÊME SI l'appel
//     à l'API GitHub échoue ensuite (status vaut alors "failed", mais la
//     ligne existe en base pour un traitement manuel/rejouable). Voir étapes
//     ci-dessous : c'est le point de conception le plus important de cette
//     fonction.
//   400 { error: "invalid_body", message }
//   401 { error: "unauthorized"|..., message }        (authenticateRequest)
//   405 { error: "method_not_allowed" }
//   500 { error: "internal_error", message }           (l'INSERT lui-même a échoué)
//   500 { error: "server_misconfigured" }               (env Supabase manquantes)
//
// Étapes :
//   1. Authentifie l'appelant via le JWT -> auth.uid()/email.
//   2. Valide le corps (title/description/severity non vides, severity dans
//      l'enum, characterId bien un uuid si fourni -- pas de vérification
//      d'appartenance : c'est un contexte informatif, pas une donnée
//      sensible modifiée).
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

const SEVERITIES = ["mineur", "majeur", "bloquant"] as const;
type Severity = (typeof SEVERITIES)[number];

// Convention de labels GitHub pour ce dépôt (documentée ici faute d'autre
// endroit établi -- première intégration GitHub Issues du projet) :
// "bug-report" systématique + un label de priorité dérivé de severity. Ces
// labels doivent exister sur Matth-Ben/nexus-jdr-app-mobile (créés
// manuellement ou au premier usage selon la configuration du dépôt -- l'API
// Issues de GitHub crée les labels inconnus automatiquement par défaut).
const PRIORITY_LABEL: Record<Severity, string> = {
  mineur: "priority: low",
  majeur: "priority: medium",
  bloquant: "priority: high",
};

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
          "Les champs title, description et severity (mineur/majeur/bloquant) sont requis.",
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
  const admin = createAdminClient(config);
  const syncResult = await syncToGithub(bugReport.id, {
    title,
    description,
    severity,
    appVersion,
    platform,
    characterId,
    reporterEmail: user.email,
    reporterId: user.id,
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

interface SyncInput {
  title: string;
  description: string;
  severity: Severity;
  appVersion: string | null;
  platform: string | null;
  characterId: string | null;
  reporterEmail: string | null;
  reporterId: string;
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
    labels: ["bug-report", PRIORITY_LABEL[input.severity]],
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

function buildIssueBody(bugReportId: string, input: SyncInput): string {
  const lines = [
    input.description,
    "",
    "---",
    `**Sévérité :** ${input.severity}`,
    `**Version de l'app :** ${input.appVersion ?? "non renseignée"}`,
    `**Plateforme :** ${input.platform ?? "non renseignée"}`,
    `**Signalé par :** ${input.reporterEmail ?? "email inconnu"} (reporter_id: ${input.reporterId})`,
  ];
  if (input.characterId) {
    lines.push(`**Personnage concerné (character_id) :** ${input.characterId}`);
  }
  lines.push(`**Signalement (bug_reports.id) :** ${bugReportId}`);
  return lines.join("\n");
}
