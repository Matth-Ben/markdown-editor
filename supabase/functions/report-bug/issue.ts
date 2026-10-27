// report-bug — logique pure (sans I/O) partagée par index.ts et testée
// unitairement par issue.test.ts : énumération des sévérités, labels GitHub,
// validation de screenshotPath, corps de l'issue GitHub.

export const SEVERITIES = ["mineur", "majeur", "bloquant", "contenu"] as const;
export type Severity = (typeof SEVERITIES)[number];

/** Bucket Storage privé des captures d'écran (voir
 * 20261027090000_bug_reports_content_severity_and_screenshot.sql). */
export const SCREENSHOT_BUCKET = "bug-report-screenshots";

// Nom de fichier accepté sous le dossier <uid>/ : même motif que la
// contrainte bug_reports_screenshot_path_owner_check côté base, restreint en
// plus aux extensions d'image autorisées par le bucket.
const SCREENSHOT_FILENAME_RE =
  /^[A-Za-z0-9_-][A-Za-z0-9._-]{0,127}$/;
const SCREENSHOT_EXTENSION_RE = /\.(jpe?g|png|webp)$/i;

// Convention de labels GitHub pour ce dépôt (documentée ici faute d'autre
// endroit établi -- première intégration GitHub Issues du projet) :
// "bug-report" systématique + des labels dérivés de severity (priorité, et
// type pour les bugs de contenu D&D). Ces
// labels doivent exister sur Matth-Ben/nexus-jdr-app-mobile (créés
// manuellement ou au premier usage selon la configuration du dépôt -- l'API
// Issues de GitHub crée les labels inconnus automatiquement par défaut).
const SEVERITY_LABELS: Record<Severity, readonly string[]> = {
  mineur: ["priority: low"],
  majeur: ["priority: medium"],
  bloquant: ["priority: high"],
  contenu: ["type: content", "priority: low"],
};

/** Labels GitHub complets d'un signalement. */
export function issueLabels(severity: Severity): string[] {
  return ["bug-report", ...SEVERITY_LABELS[severity]];
}

/** Valide screenshotPath pour l'appelant `userId`. Renvoie le chemin
 * normalisé, null si absent, ou une erreur. */
export function parseScreenshotPath(
  raw: unknown,
  userId: string,
): { ok: true; path: string | null } | { ok: false; message: string } {
  if (raw === undefined || raw === null) return { ok: true, path: null };
  if (typeof raw !== "string") {
    return { ok: false, message: "screenshotPath doit être une chaîne." };
  }
  const path = raw.trim();
  if (!path) return { ok: true, path: null };
  const prefix = `${userId.toLowerCase()}/`;
  if (!path.startsWith(prefix)) {
    return {
      ok: false,
      message: "screenshotPath doit commencer par l'uid de l'utilisateur connecté suivi de \"/\".",
    };
  }
  const fileName = path.slice(prefix.length);
  if (!SCREENSHOT_FILENAME_RE.test(fileName) || !SCREENSHOT_EXTENSION_RE.test(fileName)) {
    return {
      ok: false,
      message:
        "screenshotPath invalide : nom de fichier simple attendu ([A-Za-z0-9._-], extension .jpg/.jpeg/.png/.webp).",
    };
  }
  return { ok: true, path };
}

export interface SyncInput {
  title: string;
  description: string;
  severity: Severity;
  appVersion: string | null;
  platform: string | null;
  hasScreenshot: boolean;
}

/** Corps de l'issue GitHub. Le dépôt cible est PUBLIC : rien d'identifiant
 * ni aucun lien vers la capture d'écran. */
export function buildIssueBody(bugReportId: string, input: SyncInput): string {
  const lines = [
    input.description,
    "",
    "---",
    `**Sévérité :** ${input.severity}`,
    `**Version de l'app :** ${input.appVersion ?? "non renseignée"}`,
    `**Plateforme :** ${input.platform ?? "non renseignée"}`,
  ];
  // Aucune donnée identifiante (e-mail, reporter_id, character_id) : le dépôt
  // cible est PUBLIC. Ces informations restent dans bug_reports, retrouvable
  // via l'identifiant ci-dessous (voir la politique de confidentialité,
  // apps/web/app/confidentialite).
  if (input.hasScreenshot) {
    // Ni image, ni URL (même signée), ni chemin brut (il commence par l'uid
    // de l'utilisateur) : dépôt PUBLIC. Le chemin se retrouve en base via
    // l'identifiant du signalement ci-dessous.
    lines.push(
      `**Capture d'écran :** jointe (consultable dans Supabase Storage, bucket \`${SCREENSHOT_BUCKET}\`, chemin indiqué dans \`bug_reports.screenshot_path\` pour ce signalement)`,
    );
  }
  lines.push(`**Signalement (bug_reports.id) :** ${bugReportId}`);
  return lines.join("\n");
}
