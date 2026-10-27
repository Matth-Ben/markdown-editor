// report-bug — tests d'intégration (Deno.test)
//
// Même méthodologie que supabase/functions/join-story/index.test.ts (voir
// son commentaire d'en-tête pour le détail : pas de mock de supabase-js,
// exécution contre le vrai stack Supabase local, connexion Postgres directe
// réservée au harnais de test pour ne pas élargir les GRANTs service_role
// au-delà de ce que report-bug/index.ts utilise réellement -- ici, `update`
// uniquement, voir 20260903100100_grant_service_role_report_bug.sql -- donc
// la vérification des lignes bug_reports insérées passe par la connexion
// `sql` directe, pas par un client service_role qui n'a pas le droit de
// lire cette table).
//
// Prérequis pour lancer ces tests :
//   1. node_modules/.bin/supabase start
//   2. node_modules/.bin/supabase functions serve report-bug --no-verify-jwt
//   3. deno test --allow-net --allow-env supabase/functions/report-bug/index.test.ts
//
// IMPORTANT -- pourquoi ces tests ne déclenchent jamais un vrai appel à
// l'API GitHub (pas de pollution de Matth-Ben/nexus-jdr-app-mobile avec des
// issues de test) : le secret GITHUB_BUG_REPORT_TOKEN n'est délibérément
// PAS configuré dans l'environnement local par défaut (c'est une étape
// manuelle réservée au déploiement réel, voir le rapport de la tâche qui a
// introduit cette fonction). Sans ce secret, `syncToGithub` (index.ts)
// retourne systématiquement { ok: false } avant tout `fetch` réseau -- les
// tests ci-dessous vérifient donc précisément ce chemin (status='failed',
// error_message renseigné), qui est un comportement de production légitime
// (ex. token expiré/révoqué), pas seulement un artefact de test. Le chemin
// "succès GitHub" (status='synced', github_issue_number/url renseignés)
// n'est PAS couvert par ce fichier : il ne peut être vérifié qu'avec un vrai
// token contre un vrai dépôt, donc manuellement/ponctuellement, jamais en CI
// -- si ce secret est un jour exporté dans l'environnement où ces tests
// tournent, CE FICHIER CRÉERA DE VRAIES ISSUES sur nexus-jdr-app-mobile.
import { assert, assertEquals, assertExists, assertMatch } from "jsr:@std/assert@1";
import { createClient } from "npm:@supabase/supabase-js@2";
import postgres from "npm:postgres@3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const ANON_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";
const DB_URL =
  Deno.env.get("SUPABASE_DB_URL") ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/report-bug`;
const SCREENSHOT_BUCKET = "bug-report-screenshots";
// PNG 1x1 transparent, pour les téléversements de test.
const PNG_1X1 = Uint8Array.from(
  atob(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  ),
  (c) => c.charCodeAt(0),
);
const TEST_PASSWORD = "report-bug-tests-password-123!";

function callReportBug(body: unknown, token?: string) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return fetch(FUNCTION_URL, { method: "POST", headers, body: JSON.stringify(body) });
}

Deno.test({
  name: "report-bug — signalement de bug -> bug_reports (contre le stack Supabase local, sans appel GitHub réel)",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const anon = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } });
    // Connexion directe (rôle postgres) réservée au harnais de test -- seule
    // façon de relire les lignes bug_reports depuis ce fichier, puisque
    // service_role n'a que `update` sur cette table en production (voir
    // 20260903100100_grant_service_role_report_bug.sql) et que le client
    // scoped-utilisateur ne verrait, via RLS, que ses propres lignes.
    const sql = postgres(DB_URL, { max: 1 });

    const suffix = crypto.randomUUID().slice(0, 8);
    const createdUserIds: string[] = [];
    const createdCharacterIds: string[] = [];
    const uploadedPaths: string[] = [];

    function userClient(token: string) {
      return createClient(SUPABASE_URL, ANON_KEY, {
        auth: { persistSession: false },
        global: { headers: { Authorization: `Bearer ${token}` } },
      });
    }

    async function createUser(label: string) {
      const email = `report-bug-test-${label}-${suffix}@example.invalid`;
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password: TEST_PASSWORD,
        email_confirm: true,
      });
      if (error || !data.user) {
        throw new Error(`Échec création utilisateur de test (${label}): ${error?.message}`);
      }
      createdUserIds.push(data.user.id);
      return data.user;
    }

    async function signIn(email: string) {
      const { data, error } = await anon.auth.signInWithPassword({
        email,
        password: TEST_PASSWORD,
      });
      if (error || !data.session) {
        throw new Error(`Échec connexion utilisateur de test (${email}): ${error?.message}`);
      }
      return data.session.access_token;
    }

    async function createCharacter(ownerId: string, name: string) {
      const rows = await sql<{ id: string }[]>`
        insert into public.characters (owner_id, name)
        values (${ownerId}, ${name})
        returning id
      `;
      const id = rows[0]?.id;
      if (!id) throw new Error("Échec création character de test");
      createdCharacterIds.push(id);
      return id;
    }

    try {
      const reporter = await createUser("reporter");
      const reporterEmail = `report-bug-test-reporter-${suffix}@example.invalid`;
      const reporterToken = await signIn(reporterEmail);
      const characterId = await createCharacter(reporter.id, "Test Hero");

      await t.step(
        "signalement minimal valide -> 200, status=failed (pas de GITHUB_BUG_REPORT_TOKEN en local), ligne bug_reports en base",
        async () => {
          const res = await callReportBug(
            {
              title: `pgTAP-like bug ${suffix}`,
              description: "Description du bug de test.",
              severity: "mineur",
            },
            reporterToken,
          );
          assertEquals(res.status, 200);
          const responseBody = await res.json();
          assertExists(responseBody.id);
          // Voir le commentaire d'en-tête : sans GITHUB_BUG_REPORT_TOKEN
          // configuré en local, la synchronisation échoue systématiquement
          // (avant tout appel réseau) -- c'est le comportement attendu ici,
          // pas un bug du test.
          assertEquals(responseBody.status, "failed");
          assertEquals(responseBody.github_issue_url, undefined);

          const rows = await sql`select * from public.bug_reports where id = ${responseBody.id}`;
          assertEquals(rows.length, 1);
          const row = rows[0];
          assertEquals(row.reporter_id, reporter.id);
          assertEquals(row.severity, "mineur");
          assertEquals(row.status, "failed");
          assertExists(row.error_message);
          assertMatch(row.error_message as string, /GITHUB_BUG_REPORT_TOKEN/);
          assertEquals(row.github_issue_number, null);
          assertEquals(row.github_issue_url, null);
          assertEquals(row.character_id, null);
        },
      );

      await t.step(
        "signalement complet (appVersion/platform/characterId) -> ligne bug_reports avec ce contexte",
        async () => {
          const res = await callReportBug(
            {
              title: `pgTAP-like bug complet ${suffix}`,
              description: "Description complète.",
              severity: "bloquant",
              appVersion: "1.2.3",
              platform: "android",
              characterId,
            },
            reporterToken,
          );
          assertEquals(res.status, 200);
          const responseBody = await res.json();

          const rows = await sql`select * from public.bug_reports where id = ${responseBody.id}`;
          const row = rows[0];
          assertEquals(row.app_version, "1.2.3");
          assertEquals(row.platform, "android");
          assertEquals(row.character_id, characterId);
          assertEquals(row.severity, "bloquant");
        },
      );

      await t.step("severity 'contenu' acceptée -> 200, ligne bug_reports severity=contenu", async () => {
        const res = await callReportBug(
          {
            title: `bug de contenu ${suffix}`,
            description: "La portée du sort Boule de feu est erronée.",
            severity: "contenu",
          },
          reporterToken,
        );
        assertEquals(res.status, 200);
        const responseBody = await res.json();
        const rows = await sql`select severity, screenshot_path from public.bug_reports where id = ${responseBody.id}`;
        assertEquals(rows[0].severity, "contenu");
        assertEquals(rows[0].screenshot_path, null);
      });

      const other = await createUser("other");
      const otherToken = await signIn(`report-bug-test-other-${suffix}@example.invalid`);
      const screenshotPath = `${reporter.id}/${crypto.randomUUID()}.png`;

      await t.step("Storage : le reporter téléverse sous <uid>/ (sans upsert) -> OK", async () => {
        const { error } = await userClient(reporterToken)
          .storage.from(SCREENSHOT_BUCKET)
          .upload(screenshotPath, PNG_1X1, { contentType: "image/png" });
        assertEquals(error, null);
        uploadedPaths.push(screenshotPath);
      });

      await t.step("Storage : téléversement dans le dossier d'un autre utilisateur -> refusé", async () => {
        const path = `${other.id}/${crypto.randomUUID()}.png`;
        const { error } = await userClient(reporterToken)
          .storage.from(SCREENSHOT_BUCKET)
          .upload(path, PNG_1X1, { contentType: "image/png" });
        assertExists(error);
        uploadedPaths.push(path); // au cas où, pour le nettoyage
      });

      await t.step("Storage : sous-dossier sous <uid>/ -> refusé", async () => {
        const path = `${reporter.id}/sub/${crypto.randomUUID()}.png`;
        const { error } = await userClient(reporterToken)
          .storage.from(SCREENSHOT_BUCKET)
          .upload(path, PNG_1X1, { contentType: "image/png" });
        assertExists(error);
        uploadedPaths.push(path);
      });

      await t.step("Storage : type MIME non image -> refusé par le bucket", async () => {
        const path = `${reporter.id}/${crypto.randomUUID()}.png`;
        const { error } = await userClient(reporterToken)
          .storage.from(SCREENSHOT_BUCKET)
          .upload(path, new TextEncoder().encode("pas une image"), { contentType: "text/plain" });
        assertExists(error);
        uploadedPaths.push(path);
      });

      await t.step("Storage : bucket privé, aucune lecture/suppression côté client (même propriétaire)", async () => {
        const reporterStorage = userClient(reporterToken).storage.from(SCREENSHOT_BUCKET);
        const { data: downloaded, error: downloadError } = await reporterStorage.download(screenshotPath);
        assertEquals(downloaded, null);
        assertExists(downloadError);

        const { data: signed } = await reporterStorage.createSignedUrl(screenshotPath, 60);
        assertEquals(signed, null);

        // remove() ne renvoie pas d'erreur sous RLS : il supprime 0 objet.
        await reporterStorage.remove([screenshotPath]);
        const stillThere = await sql`
          select 1 from storage.objects where bucket_id = ${SCREENSHOT_BUCKET} and name = ${screenshotPath}
        `;
        assertEquals(stillThere.length, 1);

        const { data: publicUrl } = reporterStorage.getPublicUrl(screenshotPath);
        const publicRes = await fetch(publicUrl.publicUrl);
        await publicRes.body?.cancel();
        assert(publicRes.status >= 400, `URL publique inaccessible (reçu ${publicRes.status})`);
      });

      await t.step("screenshotPath valide (objet existant) -> 200, enregistré dans bug_reports.screenshot_path", async () => {
        const res = await callReportBug(
          {
            title: `bug avec capture ${suffix}`,
            description: "Voir la capture.",
            severity: "majeur",
            screenshotPath,
          },
          reporterToken,
        );
        assertEquals(res.status, 200);
        const responseBody = await res.json();
        const rows = await sql`select screenshot_path from public.bug_reports where id = ${responseBody.id}`;
        assertEquals(rows[0].screenshot_path, screenshotPath);
      });

      await t.step("screenshotPath dans le dossier d'un autre utilisateur -> 400 invalid_body", async () => {
        const res = await callReportBug(
          { title: "t", description: "d", severity: "mineur", screenshotPath },
          otherToken,
        );
        assertEquals(res.status, 400);
        assertEquals((await res.json()).error, "invalid_body");
      });

      await t.step("screenshotPath mal formé (traversée, bucket inclus) -> 400 invalid_body", async () => {
        for (const bad of [
          `${reporter.id}/../${other.id}/x.png`,
          `${SCREENSHOT_BUCKET}/${screenshotPath}`,
          `${reporter.id}/x.gif`,
        ]) {
          const res = await callReportBug(
            { title: "t", description: "d", severity: "mineur", screenshotPath: bad },
            reporterToken,
          );
          assertEquals(res.status, 400, bad);
          assertEquals((await res.json()).error, "invalid_body");
        }
      });

      await t.step("screenshotPath bien formé mais objet absent -> 400 screenshot_not_found, aucune ligne", async () => {
        const missing = `${reporter.id}/${crypto.randomUUID()}.png`;
        const res = await callReportBug(
          { title: `absent ${suffix}`, description: "d", severity: "mineur", screenshotPath: missing },
          reporterToken,
        );
        assertEquals(res.status, 400);
        assertEquals((await res.json()).error, "screenshot_not_found");
        const rows = await sql`select 1 from public.bug_reports where screenshot_path = ${missing}`;
        assertEquals(rows.length, 0);
      });

      await t.step("INSERT direct PostgREST avec le screenshot_path d'un autre -> refusé par la contrainte", async () => {
        const { error } = await userClient(otherToken).from("bug_reports").insert({
          reporter_id: other.id,
          title: "t",
          description: "d",
          severity: "mineur",
          screenshot_path: screenshotPath,
        });
        assertExists(error);
        assertMatch(error.message, /bug_reports_screenshot_path_owner_check/);
      });

      await t.step("title manquant -> 400 invalid_body", async () => {
        const res = await callReportBug(
          { description: "desc", severity: "mineur" },
          reporterToken,
        );
        assertEquals(res.status, 400);
        const body = await res.json();
        assertEquals(body.error, "invalid_body");
      });

      await t.step("severity hors énumération -> 400 invalid_body", async () => {
        const res = await callReportBug(
          { title: "t", description: "d", severity: "catastrophique" },
          reporterToken,
        );
        assertEquals(res.status, 400);
        const body = await res.json();
        assertEquals(body.error, "invalid_body");
      });

      await t.step("characterId non-uuid -> 400 invalid_body", async () => {
        const res = await callReportBug(
          { title: "t", description: "d", severity: "mineur", characterId: "not-a-uuid" },
          reporterToken,
        );
        assertEquals(res.status, 400);
        const body = await res.json();
        assertEquals(body.error, "invalid_body");
      });

      await t.step("requête sans JWT -> 401", async () => {
        const res = await callReportBug({
          title: "t",
          description: "d",
          severity: "mineur",
        });
        assertEquals(res.status, 401);
      });

      await t.step("requête avec un JWT invalide -> 401", async () => {
        const res = await callReportBug(
          { title: "t", description: "d", severity: "mineur" },
          "not-a-real-jwt",
        );
        assertEquals(res.status, 401);
      });

      assert(createdUserIds.length >= 1, "sanity check sur les fixtures créées");
    } finally {
      // Nettoyage : suppression via la connexion postgres directe pour
      // characters, puis suppression des utilisateurs Auth (cascade vers
      // bug_reports via reporter_id on delete cascade -- voir
      // 20260903100000_create_bug_reports.sql). Les captures téléversées
      // sont d'abord retirées du bucket via l'API Storage (service_role) :
      // Storage interdit la suppression directe en SQL.
      if (uploadedPaths.length) {
        const { error } = await admin.storage.from(SCREENSHOT_BUCKET).remove(uploadedPaths);
        if (error) console.error("nettoyage Storage des captures de test en échec", error);
      }
      if (createdCharacterIds.length) {
        await sql`delete from public.characters where id in ${sql(createdCharacterIds)}`;
      }
      await sql.end();
      for (const userId of createdUserIds) {
        await admin.auth.admin.deleteUser(userId);
      }
    }
  },
});
