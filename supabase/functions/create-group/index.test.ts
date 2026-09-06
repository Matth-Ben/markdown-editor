// create-group — tests d'intégration (Deno.test)
//
// Même précédent que supabase/functions/join-story/index.test.ts (voir son
// en-tête pour le rationale complet) : logique de création avec un
// rattachement implicite (le créateur devient membre owner de son propre
// groupe) — aucun mock, contre le vrai stack Supabase local (Docker), avec
// de vrais utilisateurs auth.users créés/nettoyés à chaque exécution.
//
// Prérequis pour lancer ces tests : voir join-story/index.test.ts (stack
// local démarré, `supabase functions serve --no-verify-jwt` pour servir
// toutes les fonctions du dépôt y compris create-group, puis
// `deno test --allow-net --allow-env supabase/functions/create-group/index.test.ts`
// ou l'équivalent Docker documenté dans join-story/index.test.ts).
//
// Les clés ANON/SERVICE_ROLE et l'URL Postgres ci-dessous sont les mêmes
// valeurs de démo locales standard de la CLI Supabase que dans
// join-story/index.test.ts (voir son en-tête pour le détail) -- sans valeur
// en dehors du stack Docker local, surchargeables via variables
// d'environnement.
//
// Fixtures créées via une connexion Postgres directe (rôle postgres) plutôt
// que via le client service_role/PostgREST, pour ne pas dépendre -- ni a
// fortiori élargir -- les privilèges accordés à service_role au-delà de ce
// que create-group/index.ts utilise réellement (select sur characters,
// select+insert+delete sur groups, select+insert sur group_members -- voir
// 20260906190000_grant_service_role_group_functions.sql).

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

const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/create-group`;
const TEST_PASSWORD = "create-group-tests-password-123!";

function callCreateGroup(body: unknown, token?: string) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return fetch(FUNCTION_URL, { method: "POST", headers, body: JSON.stringify(body) });
}

Deno.test({
  name: "create-group — création d'un groupe + rattachement owner (contre le stack Supabase local)",
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
    const createdCharacterIds: string[] = [];
    const createdGroupIds: string[] = [];

    async function createUser(label: string) {
      const email = `create-group-test-${label}-${suffix}@example.invalid`;
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
      const owner = await createUser("owner");
      const other = await createUser("other");

      const ownerCharacterId = await createCharacter(owner.id, "Group Hero");
      const notOwnedCharacterId = await createCharacter(other.id, "Not Mine");

      const ownerEmail = `create-group-test-owner-${suffix}@example.invalid`;
      const ownerToken = await signIn(ownerEmail);

      await t.step(
        "création réussie -> 200 { id, name, invite_code }, group_members créée pour l'owner",
        async () => {
          const res = await callCreateGroup(
            { name: `Groupe de test ${suffix}`, character_id: ownerCharacterId },
            ownerToken,
          );
          assertEquals(res.status, 200);
          const body = await res.json();
          assertExists(body.id);
          createdGroupIds.push(body.id);
          assertEquals(body.name, `Groupe de test ${suffix}`);
          assertExists(body.invite_code);
          assertEquals(typeof body.invite_code, "string");
          assertEquals(body.invite_code.length, 8);

          const { data: member, error } = await admin
            .from("group_members")
            .select("group_id, character_id, user_id, role")
            .eq("group_id", body.id)
            .maybeSingle();
          if (error) throw error;
          assertExists(member);
          assertEquals(member?.character_id, ownerCharacterId);
          assertEquals(member?.user_id, owner.id);
          assertEquals(member?.role, "owner");
        },
      );

      await t.step("character_id n'appartenant pas à l'appelant -> 403 character_not_owned", async () => {
        const res = await callCreateGroup(
          { name: `Groupe invalide ${suffix}`, character_id: notOwnedCharacterId },
          ownerToken,
        );
        assertEquals(res.status, 403);
        const body = await res.json();
        assertEquals(body.error, "character_not_owned");

        // Aucun groupe orphelin ne doit avoir été créé (ni tenté) pour cet
        // essai : la vérification de propriété du personnage a lieu avant
        // toute insertion dans `groups`.
        const { count, error } = await admin
          .from("groups")
          .select("id", { count: "exact", head: true })
          .eq("name", `Groupe invalide ${suffix}`);
        if (error) throw error;
        assertEquals(count, 0);
      });

      await t.step("name vide -> 400 invalid_body", async () => {
        const res = await callCreateGroup({ name: "   ", character_id: ownerCharacterId }, ownerToken);
        assertEquals(res.status, 400);
        const body = await res.json();
        assertEquals(body.error, "invalid_body");
      });

      await t.step("character_id non-uuid -> 400 invalid_body", async () => {
        const res = await callCreateGroup(
          { name: `Groupe ${suffix}`, character_id: "not-a-uuid" },
          ownerToken,
        );
        assertEquals(res.status, 400);
        const body = await res.json();
        assertEquals(body.error, "invalid_body");
      });

      await t.step("requête sans JWT -> 401", async () => {
        const res = await callCreateGroup({
          name: `Groupe ${suffix}`,
          character_id: ownerCharacterId,
        });
        assertEquals(res.status, 401);
      });

      await t.step("requête avec un JWT invalide -> 401", async () => {
        const res = await callCreateGroup(
          { name: `Groupe ${suffix}`, character_id: ownerCharacterId },
          "not-a-real-jwt",
        );
        assertEquals(res.status, 401);
      });
    } finally {
      // Nettoyage : characters en cascade supprime group_members
      // (20260906182601_create_groups.sql, "on delete cascade"), groups
      // supprime en cascade group_members ET group_treasure -- supprimer
      // characters et groups suffit.
      if (createdGroupIds.length) {
        await sql`delete from public.groups where id in ${sql(createdGroupIds)}`;
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
