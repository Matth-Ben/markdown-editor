// send-push-notification — tests unitaires (logique pure uniquement)
//
// Contrairement à report-bug/index.test.ts (tests d'intégration contre le
// vrai stack Supabase local), cette fonction n'a pas d'INSERT/UPDATE
// applicatif "cœur" comparable au signalement de bug -- sa seule I/O propre
// (lecture/suppression de user_push_tokens) est secondaire par rapport à sa
// vraie logique métier (validation du corps, construction du payload FCM,
// décision de suppression de token), qui est entièrement pure et exportée
// par index.ts. Ce fichier teste donc CETTE logique directement, sans
// stack Supabase local ni réseau -- `deno test` seul suffit :
//
//   deno test --allow-env supabase/functions/send-push-notification/index.test.ts
//
// La partie réseau réelle (obtention du token OAuth2 Firebase, appel FCM)
// n'est délibérément PAS testée ici : elle nécessiterait
// FIREBASE_SERVICE_ACCOUNT_JSON configuré contre le vrai endpoint Google,
// donc non vérifiable en CI -- voir le commentaire d'en-tête d'index.ts.

import { assertEquals } from "jsr:@std/assert@1";
import {
  buildFcmMessage,
  isInvalidFcmTokenError,
  parseSendPushNotificationBody,
  sanitizeNotificationData,
} from "./index.ts";

Deno.test("parseSendPushNotificationBody — corps valide minimal (sans data)", () => {
  const result = parseSendPushNotificationBody({
    userId: "11111111-1111-1111-1111-111111111111",
    title: "Titre",
    body: "Corps",
  });
  assertEquals(result, {
    ok: true,
    value: {
      userId: "11111111-1111-1111-1111-111111111111",
      title: "Titre",
      body: "Corps",
      data: undefined,
    },
  });
});

Deno.test("parseSendPushNotificationBody — corps valide avec data string uniquement", () => {
  const result = parseSendPushNotificationBody({
    userId: "11111111-1111-1111-1111-111111111111",
    title: "Titre",
    body: "Corps",
    data: { type: "access_revoked", storyId: "abc" },
  });
  assertEquals(result.ok, true);
  if (result.ok) {
    assertEquals(result.value.data, { type: "access_revoked", storyId: "abc" });
  }
});

Deno.test("parseSendPushNotificationBody — userId non-uuid -> invalide", () => {
  const result = parseSendPushNotificationBody({
    userId: "pas-un-uuid",
    title: "Titre",
    body: "Corps",
  });
  assertEquals(result.ok, false);
});

Deno.test("parseSendPushNotificationBody — userId absent -> invalide", () => {
  const result = parseSendPushNotificationBody({ title: "Titre", body: "Corps" });
  assertEquals(result.ok, false);
});

Deno.test("parseSendPushNotificationBody — title vide -> invalide", () => {
  const result = parseSendPushNotificationBody({
    userId: "11111111-1111-1111-1111-111111111111",
    title: "",
    body: "Corps",
  });
  assertEquals(result.ok, false);
});

Deno.test("parseSendPushNotificationBody — body manquant -> invalide", () => {
  const result = parseSendPushNotificationBody({
    userId: "11111111-1111-1111-1111-111111111111",
    title: "Titre",
  });
  assertEquals(result.ok, false);
});

Deno.test("sanitizeNotificationData — filtre les valeurs non-string", () => {
  const result = sanitizeNotificationData({
    keep: "oui",
    drop_number: 42,
    drop_bool: true,
    drop_null: null,
  });
  assertEquals(result, { keep: "oui" });
});

Deno.test("sanitizeNotificationData — objet vide -> undefined", () => {
  assertEquals(sanitizeNotificationData({}), undefined);
});

Deno.test("sanitizeNotificationData — undefined/non-objet/tableau -> undefined", () => {
  assertEquals(sanitizeNotificationData(undefined), undefined);
  assertEquals(sanitizeNotificationData(null), undefined);
  assertEquals(sanitizeNotificationData("chaine"), undefined);
  assertEquals(sanitizeNotificationData(["a", "b"]), undefined);
});

Deno.test("buildFcmMessage — sans data, la clé 'data' est absente du message", () => {
  const message = buildFcmMessage("token-abc", "Titre", "Corps");
  assertEquals(message, {
    message: {
      token: "token-abc",
      notification: { title: "Titre", body: "Corps" },
    },
  });
  assertEquals("data" in message.message, false);
});

Deno.test("buildFcmMessage — avec data, la clé 'data' est présente et fidèle", () => {
  const message = buildFcmMessage("token-abc", "Titre", "Corps", { type: "access_revoked" });
  assertEquals(message, {
    message: {
      token: "token-abc",
      notification: { title: "Titre", body: "Corps" },
      data: { type: "access_revoked" },
    },
  });
});

Deno.test("isInvalidFcmTokenError — UNREGISTERED et INVALID_ARGUMENT -> true", () => {
  assertEquals(isInvalidFcmTokenError("UNREGISTERED"), true);
  assertEquals(isInvalidFcmTokenError("INVALID_ARGUMENT"), true);
});

Deno.test("isInvalidFcmTokenError — autres codes/valeurs absentes -> false", () => {
  assertEquals(isInvalidFcmTokenError("UNAVAILABLE"), false);
  assertEquals(isInvalidFcmTokenError("INTERNAL"), false);
  assertEquals(isInvalidFcmTokenError(undefined), false);
  assertEquals(isInvalidFcmTokenError(null), false);
});
