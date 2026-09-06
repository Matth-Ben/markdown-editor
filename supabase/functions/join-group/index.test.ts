// join-group — tests d'intégration (Deno.test)
//
// Même précédent que supabase/functions/join-story/index.test.ts (voir son
// en-tête pour le rationale complet) : logique d'autorisation inter-
// utilisateurs (un joueur qui rejoint le groupe d'un autre via un code) --
// aucun mock, contre le vrai stack Supabase local (Docker), avec de vrais
// utilisateurs auth.users créés/nettoyés à chaque exécution.
//
// Prérequis pour lancer ces tests : voir join-story/index.test.ts (stack
// local démarré, `supabase functions serve --no-verify-jwt` pour servir
// toutes les fonctions du dépôt y compris join-group, puis
// `deno test --allow-net --allow-env supabase/functions/join-group/index.test.ts`
// ou l'équivalent Docker documenté dans join-story/index.test.ts).
//
// Fixtures créées via une connexion Postgres directe (rôle postgres) plutôt
// que via le client service_role/PostgREST, pour ne pas dépendre des
// privilèges accordés à service_role au-delà de ce que join-group/index.ts
// utilise réellement (select sur characters/groups/group_members, insert sur
// group_members -- voir 20260906190000_grant_service_role_group_functions.sql).

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

const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/join-group`;
const TEST_PASSWORD = "join-group-tests-password-123!";

function callJoinGroup(body: unknown, token?: string) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return fetch(FUNCTION_URL, { method: "POST", headers, body: JSON.stringify(body) });
}

Deno.test({
  name: "join-group — flux de rejoindre un groupe via un code (contre le stack Supabase local)",
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
      const email = `join-group-test-${label}-${suffix}@example.invalid`;
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

    async function createGroup(ownerId: string, inviteCode: string, name: string) {
      const rows = await sql<{ id: string }[]>`
        insert into public.groups (name, owner_id, invite_code)
        values (${name}, ${ownerId}, ${inviteCode})
        returning id
      `;
      const id = rows[0]?.id;
      if (!id) throw new Error("Échec création group de test");
      createdGroupIds.push(id);
      return id;
    }

    try {
      const owner = await createUser("owner");
      const player = await createUser("player");
      const otherPlayer = await createUser("other-player");

      const groupCode = `JG${suffix}`.toUpperCase().slice(0, 12);
      const raceCode = `JGRACE${suffix}`.toUpperCase().slice(0, 12);

      const groupId = await createGroup(owner.id, groupCode, `join-group test ${suffix}`);
      // owner rejoint son propre groupe (pas via l'edge function -- fixture
      // directe, comme le ferait create-group/index.ts).
      await sql`
        insert into public.group_members (group_id, character_id, user_id, role)
        values (${groupId}, ${await createCharacter(owner.id, "Owner Hero")}, ${owner.id}, 'owner')
      `;

      const playerCharacterId = await createCharacter(player.id, "Test Hero");
      const playerSecondCharacterId = await createCharacter(player.id, "Second Hero");
      const notOwnedCharacterId = await createCharacter(otherPlayer.id, "Not Mine");

      const playerEmail = `join-group-test-player-${suffix}@example.invalid`;
      const playerToken = await signIn(playerEmail);

      await t.step("code valide -> succès (group_id + name)", async () => {
        const res = await callJoinGroup(
          { code: groupCode, character_id: playerCharacterId },
          playerToken,
        );
        assertEquals(res.status, 200);
        const body = await res.json();
        assertEquals(body.group_id, groupId);
        assertEquals(body.name, `join-group test ${suffix}`);

        const { data: member, error } = await admin
          .from("group_members")
          .select("role")
          .eq("group_id", groupId)
          .eq("user_id", player.id)
          .maybeSingle();
        if (error) throw error;
        assertExists(member);
        assertEquals(member?.role, "membre");
      });

      await t.step("code invalide -> 404 invalid_code", async () => {
        const res = await callJoinGroup(
          { code: "DOES-NOT-EXIST", character_id: playerCharacterId },
          playerToken,
        );
        assertEquals(res.status, 404);
        const body = await res.json();
        assertEquals(body.error, "invalid_code");
      });

      await t.step(
        "personnage n'appartenant pas à l'appelant -> 403 character_not_owned",
        async () => {
          const res = await callJoinGroup(
            { code: groupCode, character_id: notOwnedCharacterId },
            playerToken,
          );
          assertEquals(res.status, 403);
          const body = await res.json();
          assertEquals(body.error, "character_not_owned");
        },
      );

      await t.step(
        "rejoindre deux fois le même groupe avec un autre personnage -> 409 already_in_group",
        async () => {
          // player a déjà rejoint groupId avec playerCharacterId au premier
          // step : retenter avec un second personnage doit être rejeté par
          // la contrainte (group_id, user_id) -- "un joueur ne participe à
          // un groupe qu'avec un seul personnage à la fois".
          const res = await callJoinGroup(
            { code: groupCode, character_id: playerSecondCharacterId },
            playerToken,
          );
          assertEquals(res.status, 409);
          const body = await res.json();
          assertEquals(body.error, "already_in_group");
        },
      );

      await t.step(
        "course entre deux requêtes concurrentes -> une seule réussit, l'autre 409 (contrainte unique 23505)",
        async () => {
          const raceGroupId = await createGroup(owner.id, raceCode, `join-group race ${suffix}`);
          const raceCharacterId = await createCharacter(otherPlayer.id, "Race Hero");
          const otherPlayerEmail = `join-group-test-other-player-${suffix}@example.invalid`;
          const otherPlayerToken = await signIn(otherPlayerEmail);

          const [resA, resB] = await Promise.all([
            callJoinGroup({ code: raceCode, character_id: raceCharacterId }, otherPlayerToken),
            callJoinGroup({ code: raceCode, character_id: raceCharacterId }, otherPlayerToken),
          ]);

          const statuses = [resA.status, resB.status].sort((a, b) => a - b);
          assertEquals(statuses, [200, 409]);

          const winner = resA.status === 200 ? resA : resB;
          const loser = resA.status === 200 ? resB : resA;
          const winnerBody = await winner.json();
          const loserBody = await loser.json();
          assertEquals(winnerBody.group_id, raceGroupId);
          assertEquals(loserBody.error, "already_in_group");

          const { count, error } = await admin
            .from("group_members")
            .select("group_id", { count: "exact", head: true })
            .eq("group_id", raceGroupId)
            .eq("user_id", otherPlayer.id);
          if (error) throw error;
          assertEquals(count, 1, "une seule ligne group_members doit avoir été créée");
        },
      );

      await t.step("requête sans JWT -> 401", async () => {
        const res = await callJoinGroup({ code: groupCode, character_id: playerCharacterId });
        assertEquals(res.status, 401);
      });

      await t.step("requête avec un JWT invalide -> 401", async () => {
        const res = await callJoinGroup(
          { code: groupCode, character_id: playerCharacterId },
          "not-a-real-jwt",
        );
        assertEquals(res.status, 401);
      });
    } finally {
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
