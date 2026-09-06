// send-weekly-digest — tests unitaires (logique pure uniquement)
//
// Même approche que send-push-notification/index.test.ts et
// send-rest-reminders/index.test.ts : la logique pure (échéance du résumé,
// construction du contenu, normalisation de la relation embarquée
// PostgREST, forme de la requête Resend) est exportée et testée ici sans
// stack Supabase local ni réseau :
//
//   deno test --allow-env supabase/functions/send-weekly-digest/index.test.ts

import { assertEquals, assertMatch } from "jsr:@std/assert@1";
import {
  buildDigestSummary,
  buildResendPayload,
  DIGEST_PERIOD_DAYS,
  isDigestDue,
  toLevelUpEntries,
} from "./index.ts";

const NOW = new Date("2026-09-06T09:00:00.000Z");

function daysAgoIso(days: number): string {
  return new Date(NOW.getTime() - days * 24 * 60 * 60 * 1000).toISOString();
}

Deno.test("isDigestDue — jamais envoyé (null) -> true", () => {
  assertEquals(isDigestDue(null, NOW), true);
});

Deno.test("isDigestDue — envoyé récemment (1 jour) -> false", () => {
  assertEquals(isDigestDue(daysAgoIso(1), NOW), false);
});

Deno.test("isDigestDue — envoyé pile au seuil (7 jours) -> true", () => {
  assertEquals(isDigestDue(daysAgoIso(DIGEST_PERIOD_DAYS), NOW), true);
});

Deno.test("buildDigestSummary — aucune montée de niveau -> null (pas d'email)", () => {
  assertEquals(buildDigestSummary([]), null);
});

Deno.test("buildDigestSummary — une montée de niveau -> sujet + contenu HTML", () => {
  const summary = buildDigestSummary([{ characterName: "Aramil", level: 4 }]);
  assertEquals(summary?.subject, "Votre résumé Nexus JDR");
  assertMatch(summary!.html, /Aramil/);
  assertMatch(summary!.html, /niveau 4/);
});

Deno.test("buildDigestSummary — plusieurs montées de niveau -> une entrée par personnage", () => {
  const summary = buildDigestSummary([
    { characterName: "Aramil", level: 4 },
    { characterName: "Borin", level: 2 },
  ]);
  assertMatch(summary!.html, /Aramil/);
  assertMatch(summary!.html, /Borin/);
  assertEquals((summary!.html.match(/<li>/g) ?? []).length, 2);
});

Deno.test("buildDigestSummary — échappe le HTML dans le nom du personnage", () => {
  const summary = buildDigestSummary([{ characterName: "<script>alert(1)</script>", level: 1 }]);
  assertEquals(summary!.html.includes("<script>"), false);
  assertMatch(summary!.html, /&lt;script&gt;/);
});

Deno.test("buildResendPayload — forme attendue par l'API Resend", () => {
  const summary = { subject: "Sujet", html: "<p>contenu</p>" };
  const payload = buildResendPayload("joueur@example.com", summary);
  assertEquals(payload.to, ["joueur@example.com"]);
  assertEquals(payload.subject, "Sujet");
  assertEquals(payload.html, "<p>contenu</p>");
  assertMatch(payload.from, /nexus-jdr/);
});

Deno.test("toLevelUpEntries — relation characters en objet (forme embed classique)", () => {
  const entries = toLevelUpEntries([
    { level: 3, characters: { name: "Aramil" } },
  ]);
  assertEquals(entries, [{ characterName: "Aramil", level: 3 }]);
});

Deno.test("toLevelUpEntries — relation characters en tableau (variante PostgREST)", () => {
  const entries = toLevelUpEntries([
    { level: 5, characters: [{ name: "Borin" }] },
  ]);
  assertEquals(entries, [{ characterName: "Borin", level: 5 }]);
});

Deno.test("toLevelUpEntries — nom absent/vide -> repli 'Votre personnage'", () => {
  const entries = toLevelUpEntries([
    { level: 2, characters: { name: "" } },
    { level: 2, characters: null },
  ]);
  assertEquals(entries, [
    { characterName: "Votre personnage", level: 2 },
    { characterName: "Votre personnage", level: 2 },
  ]);
});
