// preview-story-invite — tests d'intégration (Deno.test)
//
// Même précédent que supabase/functions/join-story/index.test.ts (voir son
// en-tête pour le rationale complet) : logique d'autorisation exposée à un
// utilisateur qui n'est pas encore engagé dans quoi que ce soit (étape 2 du
// parcours "Rejoindre une histoire", avant le choix du personnage) — aucun
// mock, contre le vrai stack Supabase local, avec de vrais utilisateurs
// auth.users créés/nettoyés à chaque exécution.
//
// Prérequis pour lancer ces tests : voir join-story/index.test.ts (stack
// local démarré, `supabase functions serve --no-verify-jwt` pour servir
// toutes les fonctions du dépôt y compris preview-story-invite, puis
// `deno test --allow-net --allow-env supabase/functions/preview-story-invite/index.test.ts`
// ou l'équivalent Docker documenté dans join-story/index.test.ts).
//
// Les clés ANON/SERVICE_ROLE et l'URL Postgres ci-dessous sont les mêmes
// valeurs de démo locales standard de la CLI Supabase que dans
// join-story/index.test.ts (voir son en-tête pour le détail) — sans valeur
// en dehors du stack Docker local, surchargeables via variables
// d'environnement.
//
// Fixtures créées via une connexion Postgres directe (rôle postgres) plutôt
// que via le client service_role/PostgREST, pour ne pas dépendre — ni a
// fortiori élargir — les privilèges accordés à service_role sur
// stories/characters (voir join-story/index.test.ts pour le rationale
// complet ; preview-story-invite n'a d'ailleurs besoin que de select sur
// stories, déjà couvert par 20260830100200_grant_service_role_join_story.sql).

import { assertEquals, assertExists } from "jsr:@std/assert@1";
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

const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/preview-story-invite`;
const TEST_PASSWORD = "preview-story-invite-tests-password-123!";

function callPreview(body: unknown, token?: string) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return fetch(FUNCTION_URL, { method: "POST", headers, body: JSON.stringify(body) });
}

Deno.test({
  name: "preview-story-invite — étape 2 du parcours \"Rejoindre une histoire\" (contre le stack Supabase local)",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const anon = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } });
    const sql = postgres(DB_URL, { max: 1 });

    const suffix = crypto.randomUUID().slice(0, 8);
    const createdUserIds: string[] = [];
    const createdStoryIds: string[] = [];

    async function createUser(label: string) {
      const email = `preview-story-invite-test-${label}-${suffix}@example.invalid`;
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

    async function createStory(gmId: string, inviteCode: string, enabled: boolean) {
      const rows = await sql<{ id: string }[]>`
        insert into public.stories (user_id, title, cover_image_path, invite_code, invite_code_enabled)
        values (${gmId}, ${`preview-story-invite test ${suffix}`}, ${"covers/test.png"}, ${inviteCode}, ${enabled})
        returning id
      `;
      const id = rows[0]?.id;
      if (!id) throw new Error("Échec création story de test");
      createdStoryIds.push(id);
      return id;
    }

    try {
      const gm = await createUser("gm");
      await createUser("player");

      const enabledCode = `PV${suffix}EN`.toUpperCase().slice(0, 12);
      const disabledCode = `PV${suffix}DIS`.toUpperCase().slice(0, 12);

      await createStory(gm.id, enabledCode, true);
      await createStory(gm.id, disabledCode, false);

      const playerEmail = `preview-story-invite-test-player-${suffix}@example.invalid`;
      const playerToken = await signIn(playerEmail);

      await t.step(
        "code valide -> 200 { title, cover_image_path }, sans character_id",
        async () => {
          const res = await callPreview({ code: enabledCode }, playerToken);
          assertEquals(res.status, 200);
          const body = await res.json();
          assertEquals(body.title, `preview-story-invite test ${suffix}`);
          assertEquals(body.cover_image_path, "covers/test.png");
          // Aucun engagement pris : pas d'id de rattachement, pas de nom de
          // MJ (décision produit du 30/08/2026, voir index.ts).
          assertEquals("character_campaign_id" in body, false);
          assertEquals("gm_name" in body, false);
        },
      );

      await t.step("code invalide -> 404 invalid_code", async () => {
        const res = await callPreview({ code: "DOES-NOT-EXIST" }, playerToken);
        assertEquals(res.status, 404);
        const body = await res.json();
        assertEquals(body.error, "invalid_code");
      });

      await t.step("invitation désactivée -> 403 invite_disabled", async () => {
        const res = await callPreview({ code: disabledCode }, playerToken);
        assertEquals(res.status, 403);
        const body = await res.json();
        assertEquals(body.error, "invite_disabled");
      });

      await t.step("requête sans JWT -> 401", async () => {
        const res = await callPreview({ code: enabledCode });
        assertEquals(res.status, 401);
        const body = await res.json();
        assertEquals(body.error, "unauthorized");
      });

      await t.step("requête avec un JWT invalide -> 401", async () => {
        const res = await callPreview({ code: enabledCode }, "not-a-real-jwt");
        assertEquals(res.status, 401);
      });

      await t.step(
        "appeler cette fonction ne crée jamais de rattachement (aucun character_campaigns créé)",
        async () => {
          await callPreview({ code: enabledCode }, playerToken);
          const rows = await sql<{ count: string }[]>`
            select count(*)::text as count
            from public.character_campaigns cc
            join public.stories s on s.id = cc.story_id
            where s.invite_code = ${enabledCode}
          `;
          assertExists(rows[0]);
          assertEquals(rows[0].count, "0");
        },
      );
    } finally {
      if (createdStoryIds.length) {
        await sql`delete from public.stories where id in ${sql(createdStoryIds)}`;
      }
      await sql.end();
      for (const userId of createdUserIds) {
        await admin.auth.admin.deleteUser(userId);
      }
    }
  },
});
