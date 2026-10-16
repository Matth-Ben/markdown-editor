// set-group-character — tests d'intégration (Deno.test)
//
// Même précédent que supabase/functions/join-group/index.test.ts (voir son
// en-tête pour le rationale complet) : logique d'autorisation propre à
// l'appelant (remplacer le personnage de SA PROPRE ligne group_members) --
// aucun mock, contre le vrai stack Supabase local (Docker), avec de vrais
// utilisateurs auth.users créés/nettoyés à chaque exécution.
//
// Prérequis pour lancer ces tests : voir join-story/index.test.ts (stack
// local démarré, `supabase functions serve --no-verify-jwt` pour servir
// toutes les fonctions du dépôt y compris set-group-character, puis
// `deno test --allow-net --allow-env supabase/functions/set-group-character/index.test.ts`
// ou l'équivalent Docker documenté dans join-story/index.test.ts).
//
// Fixtures créées via une connexion Postgres directe (rôle postgres) plutôt
// que via le client service_role/PostgREST, pour ne pas dépendre des
// privilèges accordés à service_role au-delà de ce que
// set-group-character/index.ts utilise réellement (select sur
// characters/group_members, update sur group_members -- voir
// 20261016090000_group_members_orphan_character.sql).

import { assertEquals, assertExists } from "jsr:@std/assert@1";
import { createClient } from "npm:@supabase/supabase-js@2";
import postgres from "npm:postgres@3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";
const DB_URL = Deno.env.get("SUPABASE_DB_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/set-group-character`;
const TEST_PASSWORD = "set-group-character-tests-password-123!";

function callSetGroupCharacter(body: unknown, token?: string) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return fetch(FUNCTION_URL, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

Deno.test({
  name:
    "set-group-character — remplace le personnage d'une ligne group_members orpheline (contre le stack Supabase local)",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const anon = createClient(SUPABASE_URL, ANON_KEY, {
      auth: { persistSession: false },
    });
    const sql = postgres(DB_URL, { max: 1 });

    const suffix = crypto.randomUUID().slice(0, 8);
    const createdUserIds: string[] = [];
    const createdCharacterIds: string[] = [];
    const createdGroupIds: string[] = [];

    async function createUser(label: string) {
      const email = `set-group-char-test-${label}-${suffix}@example.invalid`;
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password: TEST_PASSWORD,
        email_confirm: true,
      });
      if (error || !data.user) {
        throw new Error(
          `Échec création utilisateur de test (${label}): ${error?.message}`,
        );
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
        throw new Error(
          `Échec connexion utilisateur de test (${email}): ${error?.message}`,
        );
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

    async function createGroup(
      ownerId: string,
      inviteCode: string,
      name: string,
    ) {
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

    async function addMember(
      groupId: string,
      userId: string,
      characterId: string | null,
      role: string,
      isGameMaster: boolean,
    ) {
      await sql`
        insert into public.group_members (group_id, character_id, user_id, role, is_game_master)
        values (${groupId}, ${characterId}, ${userId}, ${role}, ${isGameMaster})
      `;
    }

    try {
      const owner = await createUser("owner");
      const orphan = await createUser("orphan");
      const gm = await createUser("gm");
      const notEligible = await createUser("not-eligible");
      const stranger = await createUser("stranger");

      const groupCode = `SGC${suffix}`.toUpperCase().slice(0, 12);
      const groupId = await createGroup(
        owner.id,
        groupCode,
        `set-group-character test ${suffix}`,
      );
      await addMember(
        groupId,
        owner.id,
        await createCharacter(owner.id, "Owner Hero"),
        "owner",
        false,
      );
      // orphan a déjà perdu son personnage (ligne orpheline directement
      // fixturée, comme le ferait on delete set null après suppression du
      // personnage).
      await addMember(groupId, orphan.id, null, "membre", false);
      // gm a volontairement rejoint sans personnage (MJ volontaire) : ne
      // doit jamais pouvoir utiliser set-group-character.
      await addMember(groupId, gm.id, null, "membre", true);
      // notEligible a déjà un personnage : ne doit pas pouvoir utiliser
      // set-group-character pour en changer.
      const notEligibleCharacterId = await createCharacter(
        notEligible.id,
        "Already Has One",
      );
      await addMember(
        groupId,
        notEligible.id,
        notEligibleCharacterId,
        "membre",
        false,
      );

      const newCharacterId = await createCharacter(orphan.id, "New Hero");
      const notOwnedCharacterId = await createCharacter(
        stranger.id,
        "Not Mine",
      );

      const orphanEmail =
        `set-group-char-test-orphan-${suffix}@example.invalid`;
      const orphanToken = await signIn(orphanEmail);

      await t.step(
        "personnage n'appartenant pas à l'appelant -> 403 character_not_owned",
        async () => {
          const res = await callSetGroupCharacter(
            { group_id: groupId, character_id: notOwnedCharacterId },
            orphanToken,
          );
          assertEquals(res.status, 403);
          const body = await res.json();
          assertEquals(body.error, "character_not_owned");
        },
      );

      await t.step("group_id manquant -> 400 invalid_body", async () => {
        const res = await callSetGroupCharacter({
          character_id: newCharacterId,
        }, orphanToken);
        assertEquals(res.status, 400);
        const body = await res.json();
        assertEquals(body.error, "invalid_body");
      });

      await t.step("requête sans JWT -> 401", async () => {
        const res = await callSetGroupCharacter({
          group_id: groupId,
          character_id: newCharacterId,
        });
        assertEquals(res.status, 401);
      });

      await t.step(
        "appelant non membre du groupe -> 404 not_member",
        async () => {
          const strangerEmail =
            `set-group-char-test-stranger-${suffix}@example.invalid`;
          const strangerToken = await signIn(strangerEmail);
          const res = await callSetGroupCharacter(
            { group_id: groupId, character_id: notOwnedCharacterId },
            strangerToken,
          );
          assertEquals(res.status, 404);
          const body = await res.json();
          assertEquals(body.error, "not_member");
        },
      );

      await t.step(
        "MJ volontaire (is_game_master=true) -> 409 not_eligible",
        async () => {
          const gmEmail = `set-group-char-test-gm-${suffix}@example.invalid`;
          const gmToken = await signIn(gmEmail);
          const gmCharacterId = await createCharacter(
            gm.id,
            "GM tries to grab one",
          );
          const res = await callSetGroupCharacter(
            { group_id: groupId, character_id: gmCharacterId },
            gmToken,
          );
          assertEquals(res.status, 409);
          const body = await res.json();
          assertEquals(body.error, "not_eligible");
        },
      );

      await t.step(
        "membre qui a déjà un personnage -> 409 not_eligible",
        async () => {
          const notEligibleEmail =
            `set-group-char-test-not-eligible-${suffix}@example.invalid`;
          const notEligibleToken = await signIn(notEligibleEmail);
          const anotherCharacterId = await createCharacter(
            notEligible.id,
            "Another One",
          );
          const res = await callSetGroupCharacter(
            { group_id: groupId, character_id: anotherCharacterId },
            notEligibleToken,
          );
          assertEquals(res.status, 409);
          const body = await res.json();
          assertEquals(body.error, "not_eligible");
        },
      );

      await t.step(
        "membre orphelin éligible -> 200, character_id mis à jour",
        async () => {
          const res = await callSetGroupCharacter(
            { group_id: groupId, character_id: newCharacterId },
            orphanToken,
          );
          assertEquals(res.status, 200);
          const body = await res.json();
          assertEquals(body.group_id, groupId);

          const { data: member, error } = await admin
            .from("group_members")
            .select("character_id, is_game_master")
            .eq("group_id", groupId)
            .eq("user_id", orphan.id)
            .maybeSingle();
          if (error) throw error;
          assertExists(member);
          assertEquals(member?.character_id, newCharacterId);
          assertEquals(member?.is_game_master, false);
        },
      );

      await t.step(
        "retenter une fois déjà résolu -> 409 not_eligible (plus orphelin)",
        async () => {
          const anotherCharacterId = await createCharacter(
            orphan.id,
            "Yet Another",
          );
          const res = await callSetGroupCharacter(
            { group_id: groupId, character_id: anotherCharacterId },
            orphanToken,
          );
          assertEquals(res.status, 409);
          const body = await res.json();
          assertEquals(body.error, "not_eligible");
        },
      );
    } finally {
      if (createdGroupIds.length) {
        await sql`delete from public.groups where id in ${
          sql(createdGroupIds)
        }`;
      }
      if (createdCharacterIds.length) {
        await sql`delete from public.characters where id in ${
          sql(createdCharacterIds)
        }`;
      }
      await sql.end();
      for (const userId of createdUserIds) {
        await admin.auth.admin.deleteUser(userId);
      }
    }
  },
});
