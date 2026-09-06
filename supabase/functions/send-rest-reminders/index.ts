// send-rest-reminders — Edge Function (Deno)
//
// Chantier "Notifications push/email" (app mobile "Personnages") —
// 15-profil-parametres.md section 3.
//
// Fonction planifiée (pg_cron, quotidien 10h UTC -- voir
// 20260906160500_schedule_notification_cron_jobs.sql), appelée en interne
// uniquement (même convention d'authentification que send-push-notification :
// "Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>"), jamais exposée à
// l'app mobile.
//
// Étapes :
//   1. Sélectionne les personnages dont `last_long_rest_at` est `null` OU
//      antérieur à REST_REMINDER_THRESHOLD_DAYS jours (client service_role,
//      hors RLS -- voir 20260830100200_grant_service_role_join_story.sql
//      pour le GRANT select sur `characters`, déjà en place).
//   2. Déduplique par propriétaire (`owner_id`) : un seul rappel par
//      utilisateur, quel que soit le nombre de personnages concernés.
//   3. Filtre selon notification_preferences.push_enabled/push_rest_reminder
//      (défaut true si absent de ligne) ET selon
//      notification_preferences.last_rest_reminder_sent_at (null ou plus
//      vieux que REST_REMINDER_THRESHOLD_DAYS jours -- évite de spammer
//      quotidiennement un utilisateur dont le seuil reste dépassé jour après
//      jour, voir shouldSendRestReminder).
//   4. Pour chaque utilisateur retenu, appelle send-push-notification (HTTP
//      interne, service_role) avec un message générique (voir spec : "un
//      texte générique suffit, pas la peine de lister tous les personnages
//      concernés").
//   5. Met à jour notification_preferences.last_rest_reminder_sent_at (upsert
//      -- crée la ligne avec les valeurs par défaut des autres colonnes si
//      elle n'existait pas encore) que l'appel HTTP à
//      send-push-notification ait réussi ou non (pas de retry quotidien
//      possible pour cette fonction, seul le lendemain est planifié -- voir
//      send-weekly-digest/index.ts pour un choix différent sur ce point,
//      justifié par sa cadence hebdomadaire).
//
// IMPORTANT -- `characters.last_long_rest_at` est mis à jour côté app mobile
// (CharacterRepository.applyRest), chantier séparé en cours en parallèle :
// tant que ce chantier n'est pas mergé, la colonne reste `null` pour TOUS
// les personnages -- traité ici comme "repos jamais pris" (cas normal),
// donc tout personnage existant matchera la condition de l'étape 1 jusqu'à
// ce merge. Rien à corriger ici.
//
// Ne peut pas être vérifiée de bout en bout (envoi FCM réel) tant que
// FIREBASE_SERVICE_ACCOUNT_JSON n'est pas configuré (voir
// send-push-notification/index.ts) -- cette fonction se contente d'un appel
// HTTP interne vers send-push-notification, donc sa propre logique
// (sélection des destinataires) reste vérifiable indépendamment, voir
// index.test.ts.

import {
  type EnvConfig,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  readEnvConfig,
} from "../_shared/http.ts";
import { isOlderThanDays } from "../_shared/time.ts";

export const REST_REMINDER_THRESHOLD_DAYS = 7;

export interface RestReminderPrefs {
  pushEnabled: boolean;
  pushRestReminder: boolean;
  lastRestReminderSentAt: string | null;
}

/** Pure -- décide si cet utilisateur (préférences résolues avec leurs
 * défauts) doit recevoir un rappel de repos maintenant. `prefs` vaut
 * `undefined` si l'utilisateur n'a jamais eu de ligne
 * notification_preferences (défauts : push_enabled=true,
 * push_rest_reminder=true, jamais notifié). */
export function shouldSendRestReminder(
  prefs: RestReminderPrefs | undefined,
  now: Date = new Date(),
): boolean {
  const pushEnabled = prefs?.pushEnabled ?? true;
  const pushRestReminder = prefs?.pushRestReminder ?? true;
  if (!pushEnabled || !pushRestReminder) return false;

  return isOlderThanDays(
    prefs?.lastRestReminderSentAt ?? null,
    REST_REMINDER_THRESHOLD_DAYS,
    now,
  );
}

/** Pure -- un personnage est "en attente de repos" si `lastLongRestAt` est
 * absent ou antérieur au seuil. Réexposé isolément (et pas seulement via
 * shouldSendRestReminder) parce que ce seuil s'applique à characters, pas à
 * notification_preferences -- deux notions distinctes malgré la même durée. */
export function isCharacterRestStale(
  lastLongRestAt: string | null,
  now: Date = new Date(),
): boolean {
  return isOlderThanDays(lastLongRestAt, REST_REMINDER_THRESHOLD_DAYS, now);
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
    console.error("send-rest-reminders: variables d'environnement Supabase manquantes");
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
  const staleThresholdIso = new Date(
    now.getTime() - REST_REMINDER_THRESHOLD_DAYS * 24 * 60 * 60 * 1000,
  ).toISOString();

  const { data: staleCharacters, error: charactersError } = await admin
    .from("characters")
    .select("owner_id, last_long_rest_at")
    .or(`last_long_rest_at.is.null,last_long_rest_at.lt.${staleThresholdIso}`);

  if (charactersError) {
    console.error("send-rest-reminders: erreur de lecture characters", charactersError);
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  const ownerIds = [...new Set((staleCharacters ?? []).map((c) => c.owner_id as string))];
  if (ownerIds.length === 0) {
    return jsonResponse({ notified: 0 });
  }

  const { data: prefsRows, error: prefsError } = await admin
    .from("notification_preferences")
    .select("user_id, push_enabled, push_rest_reminder, last_rest_reminder_sent_at")
    .in("user_id", ownerIds);

  if (prefsError) {
    console.error(
      "send-rest-reminders: erreur de lecture notification_preferences",
      prefsError,
    );
    return jsonResponse({ error: "internal_error", message: "Erreur serveur." }, 500);
  }

  const prefsByUser = new Map(
    (prefsRows ?? []).map((p) => [
      p.user_id as string,
      {
        pushEnabled: p.push_enabled as boolean,
        pushRestReminder: p.push_rest_reminder as boolean,
        lastRestReminderSentAt: p.last_rest_reminder_sent_at as string | null,
      } satisfies RestReminderPrefs,
    ]),
  );

  const recipients = ownerIds.filter((ownerId) =>
    shouldSendRestReminder(prefsByUser.get(ownerId), now)
  );

  let notified = 0;
  for (const userId of recipients) {
    const ok = await sendRestReminderPush(config, userId);
    if (ok) notified++;

    const { error: upsertError } = await admin
      .from("notification_preferences")
      .upsert(
        { user_id: userId, last_rest_reminder_sent_at: now.toISOString() },
        { onConflict: "user_id" },
      );
    if (upsertError) {
      console.error(
        "send-rest-reminders: échec mise à jour last_rest_reminder_sent_at",
        userId,
        upsertError,
      );
    }
  }

  return jsonResponse({ notified, evaluated: recipients.length });
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}

/** Isolé du reste (appel réseau interne à send-push-notification) pour que
 * la sélection des destinataires ci-dessus reste testable sans réseau. */
async function sendRestReminderPush(config: EnvConfig, userId: string): Promise<boolean> {
  try {
    const res = await fetch(`${config.supabaseUrl}/functions/v1/send-push-notification`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${config.serviceRoleKey}`,
      },
      body: JSON.stringify({
        userId,
        title: "Repos mérité",
        body: "Un de vos personnages n'a pas pris de repos long depuis un moment.",
      }),
    });
    return res.ok;
  } catch (err) {
    console.error("send-rest-reminders: erreur d'appel send-push-notification", userId, String(err));
    return false;
  }
}
