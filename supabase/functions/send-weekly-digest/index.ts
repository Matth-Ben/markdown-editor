// send-weekly-digest — Edge Function (Deno)
//
// Chantier "Notifications push/email" (app mobile "Personnages") —
// 15-profil-parametres.md section 3.
//
// Fonction planifiée (pg_cron, hebdomadaire lundi 9h UTC -- voir
// 20260906160500_schedule_notification_cron_jobs.sql), appelée en interne
// uniquement (même convention d'authentification que send-push-notification/
// send-rest-reminders : "Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>"),
// jamais exposée à l'app mobile.
//
// Pour chaque utilisateur avec notification_preferences.email_digest_enabled
// = true ET dû pour un résumé (last_email_digest_sent_at null ou plus vieux
// que DIGEST_PERIOD_DAYS jours, voir isDigestDue) :
//   1. Liste les montées de niveau depuis le dernier envoi
//      (character_level_hp.created_at > last_email_digest_sent_at, jointure
//      characters pour le nom -- colonne created_at ajoutée par
//      20260906160000_add_character_level_hp_created_at.sql, absente avant
//      ce chantier).
//   2. "Accès retirés depuis le dernier envoi" -- DÉLIBÉRÉMENT OMIS : aucune
//      table ne trace les révocations dans le temps (character_campaigns
//      est supprimée, pas archivée, à la révocation) ; construire ce suivi
//      sortirait du périmètre de cette tâche (consigne explicite : "sinon
//      omets cette ligne plutôt que d'inventer un tracking supplémentaire").
//   3. Si rien à signaler (buildDigestSummary renvoie null) -> PAS d'email
//      cette semaine-là, mais last_email_digest_sent_at est quand même
//      avancé à maintenant, pour respecter le rythme hebdomadaire (consigne
//      explicite de la tâche).
//   4. Sinon, résout l'email de l'utilisateur (Auth Admin API,
//      admin.auth.admin.getUserById -- pas une table PostgREST, donc aucun
//      GRANT de table à ajouter pour ça) et envoie via l'API HTTP Resend
//      directe (RESEND_API_KEY, secret d'edge function séparé de la config
//      SMTP Supabase Auth déjà utilisée côté web -- celle-ci ne couvre que
//      les emails d'auth, pas cet envoi applicatif).
//
// Comportement en cas d'ÉCHEC TECHNIQUE d'envoi (RESEND_API_KEY absent/
// invalide, API Resend indisponible) : `last_email_digest_sent_at` N'EST PAS
// mis à jour -- volontairement différent du cas "rien à signaler" ci-dessus.
// Cette fonction ne tourne qu'une fois par semaine (pas de retry quotidien
// possible comme send-rest-reminders) : ne pas avancer le curseur en cas
// d'échec technique permet à la prochaine exécution hebdomadaire de retenter
// avec les mêmes montées de niveau, au lieu de les perdre silencieusement.
// Ce choix n'était pas explicite dans la consigne d'origine -- documenté ici
// pour que l'équipe puisse le corriger si un autre comportement est préféré.
//
// Expéditeur (DIGEST_FROM_ADDRESS ci-dessous) : domaine non vérifié côté
// Resend à ce jour -- "nexus-jdr.app" est un choix cohérent avec le nom du
// projet, PAS une confirmation qu'il est configuré/vérifié dans le compte
// Resend. À corriger si le domaine réel diffère.
//
// Ne peut pas être vérifiée de bout en bout (envoi réel) tant que
// RESEND_API_KEY n'est pas configuré -- la sélection des destinataires et la
// construction du résumé restent testables indépendamment, voir
// index.test.ts.

import {
  corsHeaders,
  createAdminClient,
  jsonResponse,
  readEnvConfig,
} from "../_shared/http.ts";
import { isOlderThanDays } from "../_shared/time.ts";

export const DIGEST_PERIOD_DAYS = 7;

/** Pure -- vrai si `lastEmailDigestSentAt` est absent ou plus vieux que
 * DIGEST_PERIOD_DAYS jours. */
export function isDigestDue(
  lastEmailDigestSentAt: string | null,
  now: Date = new Date(),
): boolean {
  return isOlderThanDays(lastEmailDigestSentAt, DIGEST_PERIOD_DAYS, now);
}

export interface LevelUpEntry {
  characterName: string;
  level: number;
}

export interface DigestSummary {
  subject: string;
  html: string;
}

/** Pure -- construit le contenu de l'email, ou `null` si rien à signaler
 * (l'appelant ne doit alors PAS envoyer d'email cette semaine-là, voir le
 * commentaire d'en-tête). */
export function buildDigestSummary(levelUps: LevelUpEntry[]): DigestSummary | null {
  if (levelUps.length === 0) return null;

  const items = levelUps
    .map(
      (entry) =>
        `<li>${escapeHtml(entry.characterName)} a atteint le niveau ${entry.level}.</li>`,
    )
    .join("");

  return {
    subject: "Votre résumé Nexus JDR",
    html: `<p>Voici ce qui s'est passé cette semaine :</p><ul>${items}</ul>`,
  };
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export interface ResendEmailPayload {
  from: string;
  to: string[];
  subject: string;
  html: string;
}

// Voir le commentaire d'en-tête : domaine non confirmé côté Resend.
const DIGEST_FROM_ADDRESS = "Nexus JDR <notifications@nexus-jdr.app>";

/** Pure -- construit le corps de requête POST https://api.resend.com/emails. */
export function buildResendPayload(to: string, summary: DigestSummary): ResendEmailPayload {
  return { from: DIGEST_FROM_ADDRESS, to: [to], subject: summary.subject, html: summary.html };
}

interface CharacterLevelHpRow {
  level: number;
  characters: { name: string } | { name: string }[] | null;
}

/** Pure -- normalise la forme renvoyée par l'embedding PostgREST
 * (`characters` peut être un objet ou un tableau à un élément selon la
 * version de PostgREST/la relation) en LevelUpEntry[]. */
export function toLevelUpEntries(rows: CharacterLevelHpRow[]): LevelUpEntry[] {
  return rows.map((row) => {
    const character = Array.isArray(row.characters) ? row.characters[0] : row.characters;
    const characterName = character?.name?.trim() || "Votre personnage";
    return { characterName, level: row.level };
  });
}

// `Deno.serve` n'est appelé que si ce fichier est exécuté directement (voir
// `if (import.meta.main)` plus bas) -- pas quand index.test.ts l'importe
// pour tester la logique pure ci-dessus (même motif que
// send-push-notification/index.ts).
async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const config = readEnvConfig();
  if (!config) {
    console.error("send-weekly-digest: variables d'environnement Supabase manquantes");
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

  const admin = createAdminClient(config);
  const now = new Date();

  const { data: prefsRows, error: prefsError } = await admin
    .from("notification_preferences")
    .select("user_id, last_email_digest_sent_at")
    .eq("email_digest_enabled", true);

  if (prefsError) {
    console.error("send-weekly-digest: erreur de lecture notification_preferences", prefsError);
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  const dueUsers = (prefsRows ?? []).filter((p) =>
    isDigestDue(p.last_email_digest_sent_at as string | null, now)
  );

  let emailsSent = 0;
  let skippedEmpty = 0;
  let failed = 0;

  for (const row of dueUsers) {
    const userId = row.user_id as string;
    const lastSentAt = row.last_email_digest_sent_at as string | null;

    const { data: levelUpRows, error: levelUpError } = await admin
      .from("character_level_hp")
      .select("level, created_at, characters!inner(name, owner_id)")
      .eq("characters.owner_id", userId)
      .gt("created_at", lastSentAt ?? "1970-01-01T00:00:00.000Z")
      .order("created_at", { ascending: true });

    if (levelUpError) {
      console.error(
        "send-weekly-digest: erreur de lecture character_level_hp",
        userId,
        levelUpError,
      );
      failed++;
      continue; // ne bloque pas les autres utilisateurs
    }

    const summary = buildDigestSummary(toLevelUpEntries(levelUpRows ?? []));

    if (!summary) {
      skippedEmpty++;
      await touchLastDigestSentAt(admin, userId, now);
      continue;
    }

    const { data: userData, error: userError } = await admin.auth.admin.getUserById(userId);
    const email = userData?.user?.email;
    if (userError || !email) {
      console.error(
        "send-weekly-digest: impossible de résoudre l'email de l'utilisateur",
        userId,
        userError,
      );
      failed++;
      continue;
    }

    const sent = await sendDigestEmail(email, summary);
    if (!sent) {
      // Échec technique : voir le commentaire d'en-tête -- pas de mise à
      // jour de last_email_digest_sent_at, nouvelle tentative la semaine
      // prochaine.
      failed++;
      continue;
    }

    emailsSent++;
    await touchLastDigestSentAt(admin, userId, now);
  }

  return jsonResponse({
    emails_sent: emailsSent,
    skipped_empty: skippedEmpty,
    failed,
    evaluated: dueUsers.length,
  });
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}

// deno-lint-ignore no-explicit-any
async function touchLastDigestSentAt(admin: any, userId: string, now: Date): Promise<void> {
  const { error } = await admin
    .from("notification_preferences")
    .update({ last_email_digest_sent_at: now.toISOString() })
    .eq("user_id", userId);
  if (error) {
    console.error(
      "send-weekly-digest: échec mise à jour last_email_digest_sent_at",
      userId,
      error,
    );
  }
}

/** Isolé du reste (appel réseau réel vers l'API Resend) pour que la
 * sélection des destinataires et la construction du résumé restent
 * testables sans réseau ni RESEND_API_KEY. */
async function sendDigestEmail(to: string, summary: DigestSummary): Promise<boolean> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    console.error("send-weekly-digest: RESEND_API_KEY non configuré (secret Supabase manquant) -- envoi ignoré.");
    return false;
  }

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(buildResendPayload(to, summary)),
    });

    if (!res.ok) {
      console.error(
        "send-weekly-digest: échec API Resend",
        res.status,
        await res.text().catch(() => ""),
      );
      return false;
    }
    return true;
  } catch (err) {
    console.error("send-weekly-digest: erreur réseau Resend", String(err));
    return false;
  }
}
