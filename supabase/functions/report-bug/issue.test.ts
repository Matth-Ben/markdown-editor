// Tests unitaires purs (sans stack Supabase) de la logique de report-bug :
// labels GitHub, validation de screenshotPath, corps de l'issue.
import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import {
  buildIssueBody,
  issueLabels,
  parseScreenshotPath,
  SCREENSHOT_BUCKET,
  SEVERITIES,
} from "./issue.ts";

const UID = "3f0c2b4e-8d1a-4c6b-9e2f-1a2b3c4d5e6f";
const OTHER_UID = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";

Deno.test("SEVERITIES contient les 3 sévérités historiques + contenu", () => {
  assertEquals([...SEVERITIES], ["mineur", "majeur", "bloquant", "contenu"]);
});

Deno.test("issueLabels — priorité par sévérité, type: content pour contenu", () => {
  assertEquals(issueLabels("mineur"), ["bug-report", "priority: low"]);
  assertEquals(issueLabels("majeur"), ["bug-report", "priority: medium"]);
  assertEquals(issueLabels("bloquant"), ["bug-report", "priority: high"]);
  assertEquals(issueLabels("contenu"), ["bug-report", "type: content", "priority: low"]);
});

Deno.test("parseScreenshotPath — absent/vide -> null", () => {
  assertEquals(parseScreenshotPath(undefined, UID), { ok: true, path: null });
  assertEquals(parseScreenshotPath(null, UID), { ok: true, path: null });
  assertEquals(parseScreenshotPath("   ", UID), { ok: true, path: null });
});

Deno.test("parseScreenshotPath — chemins valides sous <uid>/", () => {
  for (const name of ["shot.png", "a.jpg", "b.JPEG", "9b2e-1.webp", "x_y.png"]) {
    assertEquals(parseScreenshotPath(`${UID}/${name}`, UID), {
      ok: true,
      path: `${UID}/${name}`,
    });
  }
  // uid de l'appelant comparé en minuscules (forme renvoyée par Supabase Auth).
  assert(parseScreenshotPath(`${UID}/shot.png`, UID.toUpperCase()).ok);
});

Deno.test("parseScreenshotPath — refuse tout chemin hors du dossier de l'appelant ou mal formé", () => {
  const invalid: unknown[] = [
    42,
    { path: `${UID}/shot.png` },
    `${OTHER_UID}/shot.png`, // dossier d'un autre utilisateur
    `/${UID}/shot.png`, // slash initial
    `${SCREENSHOT_BUCKET}/${UID}/shot.png`, // nom du bucket inclus
    `${UID}shot.png`, // pas de séparateur
    `${UID}/`, // pas de fichier
    `${UID}/sub/shot.png`, // sous-dossier
    `${UID}/../${OTHER_UID}/shot.png`, // traversée
    `${UID}/.hidden.png`, // commence par un point
    `${UID}/shot.gif`, // extension non autorisée par le bucket
    `${UID}/shot`, // sans extension
    `${UID}/sh ot.png`, // espace
    `${UID}/${"a".repeat(130)}.png`, // trop long
  ];
  for (const raw of invalid) {
    const res = parseScreenshotPath(raw, UID);
    assertFalse(res.ok, `devrait être refusé : ${String(raw)}`);
  }
});

Deno.test("buildIssueBody — mention textuelle de la capture, sans URL, chemin, uid ni nom interne", () => {
  const body = buildIssueBody("11111111-2222-4333-8444-555555555555", {
    title: "t",
    description: "Le sort Boule de feu a une portée erronée.",
    severity: "contenu",
    appVersion: "1.0.9",
    platform: "android",
    hasScreenshot: true,
  });
  assert(
    body.includes("**Capture d'écran :** jointe (consultable côté Supabase via l'id du signalement)"),
  );
  assertFalse(body.includes(SCREENSHOT_BUCKET), "aucun nom de bucket dans l'issue publique");
  assertFalse(body.includes("screenshot_path"), "aucun nom de colonne dans l'issue publique");
  assert(body.includes("**Sévérité :** contenu"));
  assertFalse(/https?:\/\//.test(body), "aucune URL dans le corps de l'issue");
  assertFalse(body.includes(UID), "aucun uid dans le corps de l'issue");
  assertFalse(/\.(png|jpe?g|webp)\b/i.test(body), "aucun nom de fichier");
});

Deno.test("buildIssueBody — pas de mention de capture sans capture", () => {
  const body = buildIssueBody("11111111-2222-4333-8444-555555555555", {
    title: "t",
    description: "d",
    severity: "mineur",
    appVersion: null,
    platform: null,
    hasScreenshot: false,
  });
  assertFalse(body.includes("Capture"));
  assertFalse(body.includes(SCREENSHOT_BUCKET));
});
