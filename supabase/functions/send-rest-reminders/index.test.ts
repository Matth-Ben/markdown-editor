// send-rest-reminders — tests unitaires (logique pure uniquement)
//
// Même approche que send-push-notification/index.test.ts : la vraie logique
// métier de cette fonction (sélection des destinataires) est pure et
// exportée, testée ici sans stack Supabase local ni réseau :
//
//   deno test --allow-env supabase/functions/send-rest-reminders/index.test.ts
//
// Non testé ici (nécessite le stack Supabase local + réseau) : les requêtes
// PostgREST elles-mêmes (characters/notification_preferences) et l'appel
// HTTP interne à send-push-notification.

import { assertEquals } from "jsr:@std/assert@1";
import {
  isCharacterRestStale,
  REST_REMINDER_THRESHOLD_DAYS,
  shouldSendRestReminder,
} from "./index.ts";

const NOW = new Date("2026-09-06T10:00:00.000Z");

function daysAgoIso(days: number): string {
  return new Date(NOW.getTime() - days * 24 * 60 * 60 * 1000).toISOString();
}

Deno.test("shouldSendRestReminder — aucune ligne de préférences -> défauts (true, true), jamais notifié -> true", () => {
  assertEquals(shouldSendRestReminder(undefined, NOW), true);
});

Deno.test("shouldSendRestReminder — push_enabled=false -> false même si jamais notifié", () => {
  assertEquals(
    shouldSendRestReminder(
      { pushEnabled: false, pushRestReminder: true, lastRestReminderSentAt: null },
      NOW,
    ),
    false,
  );
});

Deno.test("shouldSendRestReminder — push_rest_reminder=false -> false", () => {
  assertEquals(
    shouldSendRestReminder(
      { pushEnabled: true, pushRestReminder: false, lastRestReminderSentAt: null },
      NOW,
    ),
    false,
  );
});

Deno.test("shouldSendRestReminder — déjà notifié récemment (< 7 jours) -> false", () => {
  assertEquals(
    shouldSendRestReminder(
      {
        pushEnabled: true,
        pushRestReminder: true,
        lastRestReminderSentAt: daysAgoIso(1),
      },
      NOW,
    ),
    false,
  );
});

Deno.test("shouldSendRestReminder — dernier rappel pile au seuil (7 jours) -> true", () => {
  assertEquals(
    shouldSendRestReminder(
      {
        pushEnabled: true,
        pushRestReminder: true,
        lastRestReminderSentAt: daysAgoIso(REST_REMINDER_THRESHOLD_DAYS),
      },
      NOW,
    ),
    true,
  );
});

Deno.test("shouldSendRestReminder — dernier rappel bien plus vieux que 7 jours -> true", () => {
  assertEquals(
    shouldSendRestReminder(
      {
        pushEnabled: true,
        pushRestReminder: true,
        lastRestReminderSentAt: daysAgoIso(30),
      },
      NOW,
    ),
    true,
  );
});

Deno.test("isCharacterRestStale — last_long_rest_at null -> true (jamais reposé)", () => {
  assertEquals(isCharacterRestStale(null, NOW), true);
});

Deno.test("isCharacterRestStale — repos long récent (1 jour) -> false", () => {
  assertEquals(isCharacterRestStale(daysAgoIso(1), NOW), false);
});

Deno.test("isCharacterRestStale — repos long vieux de 8 jours -> true", () => {
  assertEquals(isCharacterRestStale(daysAgoIso(8), NOW), true);
});
