// delete-account — tests d'intégration (Deno.test)
//
// Même méthodologie que supabase/functions/join-story/index.test.ts et
// supabase/functions/report-bug/index.test.ts (voir leurs commentaires
// d'en-tête pour le détail : pas de mock de supabase-js, exécution contre le
// vrai stack Supabase local, connexion Postgres directe réservée au harnais
// de test pour créer/vérifier des fixtures dans des tables que
// `service_role` n'a pas forcément le droit de lire/écrire directement via
// PostgREST -- delete-account n'utilise le client service_role que pour
// storage.* et auth.admin.*, jamais pour lire/écrire `characters`/
// `character_*`/`stories` via `.from(...)`).
//
// Prérequis pour lancer ces tests :
//   1. node_modules/.bin/supabase start
//   2. node_modules/.bin/supabase functions serve delete-account --no-verify-jwt
//   3. deno test --allow-net --allow-env supabase/functions/delete-account/index.test.ts
//      (si Deno n'est pas installé sur le poste : voir alternative Docker
//      documentée dans join-story/index.test.ts)
//
// Ce que ces tests couvrent :
//   - Un utilisateur non authentifié / avec un JWT invalide -> 401, aucune
//     suppression.
//   - Aucun paramètre `userId` (ou autre) transmis dans le corps ne permet de
//     cibler un AUTRE compte que l'appelant -- vérifié en envoyant un
//     `userId` pointant vers un second utilisateur de test et en constatant
//     que c'est bien l'appelant qui est supprimé, pas la cible du paramètre.
//   - Cascade DB complète : un personnage de test avec au moins une ligne
//     dans character_classes, character_ability_scores, character_spells,
//     character_inventory et character_campaigns (donc une story associée)
//     disparaît intégralement après suppression du compte, sans requête
//     manuelle de nettoyage de la part de la fonction.
//   - Nettoyage best-effort du bucket `character-portraits` : fichiers
//     déposés sous `{userId}/` (portrait de personnage + avatar de profil,
//     dans des sous-dossiers différents pour vérifier la récursion) absents
//     après suppression.
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

const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/delete-account`;
const PORTRAITS_BUCKET = "character-portraits";
const TEST_PASSWORD = "delete-account-tests-password-123!";

function callDeleteAccount(token?: string, body?: unknown) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return fetch(FUNCTION_URL, {
    method: "POST",
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

Deno.test({
  name:
    "delete-account — suppression de compte -> cascade DB complète + nettoyage storage (contre le stack Supabase local)",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const anon = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } });
    // Connexion directe (rôle postgres, superuser) réservée au harnais de
    // test -- crée/vérifie des fixtures dans des tables (stories,
    // characters, character_*) sans dépendre des privilèges accordés à
    // service_role, qui ne sont volontairement pas élargis au-delà de ce que
    // delete-account/index.ts utilise réellement (storage.* et auth.admin.*
    // seulement -- voir le commentaire d'en-tête de ce fichier).
    const sql = postgres(DB_URL, { max: 1 });

    const suffix = crypto.randomUUID().slice(0, 8);
    const createdUserIds: string[] = [];

    async function createUser(label: string) {
      const email = `delete-account-test-${label}-${suffix}@example.invalid`;
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

    /** Construit un personnage de test avec au moins une ligne dans chacune
     * des familles de tables enfants représentatives (classe, caractéristique,
     * sort, inventaire) plus un rattachement character_campaigns (donc une
     * story), pour vérifier une cascade de bout en bout la plus large
     * possible sans dupliquer les 14 tables enfants une à une. */
    async function seedCharacterWithChildren(ownerId: string) {
      const [character] = await sql<{ id: string }[]>`
        insert into public.characters (owner_id, name)
        values (${ownerId}, 'Test Cascade Hero')
        returning id
      `;
      const characterId = character.id;

      const [classRow] = await sql<{ id: number }[]>`select id from public.classes limit 1`;
      const [abilityRow] = await sql<{ id: string }[]>`select id from public.abilities limit 1`;
      const [spellRow] = await sql<{ id: number }[]>`select id from public.spells limit 1`;
      if (!classRow || !abilityRow || !spellRow) {
        throw new Error(
          "Fixtures de référence manquantes (classes/abilities/spells) -- socle Phase 1 non peuplé sur ce stack local.",
        );
      }

      await sql`
        insert into public.character_classes (character_id, class_id, level, is_primary)
        values (${characterId}, ${classRow.id}, 1, true)
      `;
      await sql`
        insert into public.character_ability_scores (character_id, ability_id, score)
        values (${characterId}, ${abilityRow.id}, 10)
      `;
      await sql`
        insert into public.character_spells (character_id, spell_id, status)
        values (${characterId}, ${spellRow.id}, 'connu')
      `;
      await sql`
        insert into public.character_inventory (character_id, custom_name, quantity)
        values (${characterId}, 'Test Item', 1)
      `;

      const [story] = await sql<{ id: string }[]>`
        insert into public.stories (user_id, title)
        values (${ownerId}, 'Test Story pour cascade')
        returning id
      `;
      await sql`
        insert into public.character_campaigns (character_id, story_id, role)
        values (${characterId}, ${story.id}, 'joueur')
      `;

      return { characterId, storyId: story.id };
    }

    async function countRows(table: string, column: string, value: string) {
      const rows = await sql`select 1 from ${sql(table)} where ${sql(column)} = ${value}`;
      return rows.length;
    }

    async function uploadPortraitFiles(token: string, userId: string, characterId: string) {
      const client = createClient(SUPABASE_URL, ANON_KEY, {
        auth: { persistSession: false },
        global: { headers: { Authorization: `Bearer ${token}` } },
      });
      const avatarPath = `${userId}/avatar.png`;
      const portraitPath = `${userId}/${characterId}/portrait.png`;
      const bytes = new Uint8Array([1, 2, 3, 4]);

      const up1 = await client.storage
        .from(PORTRAITS_BUCKET)
        .upload(avatarPath, bytes, { contentType: "image/png" });
      if (up1.error) throw new Error(`Échec upload avatar de test: ${up1.error.message}`);

      const up2 = await client.storage
        .from(PORTRAITS_BUCKET)
        .upload(portraitPath, bytes, { contentType: "image/png" });
      if (up2.error) throw new Error(`Échec upload portrait de test: ${up2.error.message}`);

      return { avatarPath, portraitPath };
    }

    try {
      await t.step("requête sans JWT -> 401", async () => {
        const res = await callDeleteAccount();
        assertEquals(res.status, 401);
      });

      await t.step("requête avec un JWT invalide -> 401", async () => {
        const res = await callDeleteAccount("not-a-real-jwt");
        assertEquals(res.status, 401);
      });

      const victim = await createUser("victim");
      const victimEmail = `delete-account-test-victim-${suffix}@example.invalid`;
      const victimToken = await signIn(victimEmail);

      await t.step(
        "un userId dans le corps ne permet PAS de cibler un autre compte -- seul l'appelant est supprimé",
        async () => {
          const other = await createUser("other-target");
          const res = await callDeleteAccount(victimToken, { userId: other.id });
          assertEquals(res.status, 200);
          const body = await res.json();
          assertEquals(body.deleted, true);

          // L'appelant (victim) est bien supprimé...
          const { data: victimAfter } = await admin.auth.admin.getUserById(victim.id);
          assertEquals(victimAfter.user, null);

          // ...mais PAS le compte "other" mentionné dans le corps -- la
          // preuve que userId n'est jamais lu par la fonction.
          const { data: otherAfter, error: otherError } = await admin.auth.admin.getUserById(
            other.id,
          );
          assertEquals(otherError, null);
          assertExists(otherAfter.user);
        },
      );

      const cascadeUser = await createUser("cascade");
      const cascadeEmail = `delete-account-test-cascade-${suffix}@example.invalid`;
      const cascadeToken = await signIn(cascadeEmail);
      const { characterId, storyId } = await seedCharacterWithChildren(cascadeUser.id);
      const { avatarPath, portraitPath } = await uploadPortraitFiles(
        cascadeToken,
        cascadeUser.id,
        characterId,
      );

      await t.step(
        "sanity check -- les fixtures existent bien avant suppression",
        async () => {
          assertEquals(await countRows("characters", "id", characterId), 1);
          assertEquals(await countRows("character_classes", "character_id", characterId), 1);
          assertEquals(
            await countRows("character_ability_scores", "character_id", characterId),
            1,
          );
          assertEquals(await countRows("character_spells", "character_id", characterId), 1);
          assertEquals(await countRows("character_inventory", "character_id", characterId), 1);
          assertEquals(await countRows("character_campaigns", "character_id", characterId), 1);
          assertEquals(await countRows("stories", "id", storyId), 1);

          const { data: filesBefore, error } = await admin.storage
            .from(PORTRAITS_BUCKET)
            .list(cascadeUser.id, { limit: 10 });
          assertEquals(error, null);
          assertExists(filesBefore);
        },
      );

      await t.step("suppression -> 200 { deleted: true }", async () => {
        const res = await callDeleteAccount(cascadeToken);
        assertEquals(res.status, 200);
        const body = await res.json();
        assertEquals(body.deleted, true);
      });

      await t.step("auth.users -- le compte n'existe plus", async () => {
        const { data } = await admin.auth.admin.getUserById(cascadeUser.id);
        assertEquals(data.user, null);
        // Retiré de la liste de nettoyage : déjà supprimé par la fonction,
        // un deuxième deleteUser en fin de test échouerait sinon "not found"
        // (sans gravité, mais évité pour un journal de test propre).
        const idx = createdUserIds.indexOf(cascadeUser.id);
        if (idx !== -1) createdUserIds.splice(idx, 1);
      });

      await t.step(
        "cascade DB complète -- characters et toutes les tables enfants testées ont disparu",
        async () => {
          assertEquals(await countRows("characters", "id", characterId), 0);
          assertEquals(await countRows("character_classes", "character_id", characterId), 0);
          assertEquals(
            await countRows("character_ability_scores", "character_id", characterId),
            0,
          );
          assertEquals(await countRows("character_spells", "character_id", characterId), 0);
          assertEquals(await countRows("character_inventory", "character_id", characterId), 0);
          assertEquals(await countRows("character_campaigns", "character_id", characterId), 0);
          // stories.user_id -> auth.users on delete cascade (indépendant de
          // characters) : la story de test disparaît aussi, cohérent avec le
          // commentaire d'en-tête de index.ts sur l'effet cross-app.
          assertEquals(await countRows("stories", "id", storyId), 0);
        },
      );

      await t.step(
        "storage -- portrait de personnage ET avatar de profil supprimés du bucket",
        async () => {
          const { data: avatarList } = await admin.storage
            .from(PORTRAITS_BUCKET)
            .list(cascadeUser.id, { limit: 10 });
          assertEquals((avatarList ?? []).find((f) => f.name === "avatar.png"), undefined);

          const { data: characterFolderList } = await admin.storage
            .from(PORTRAITS_BUCKET)
            .list(`${cascadeUser.id}/${characterId}`, { limit: 10 });
          assertEquals((characterFolderList ?? []).length, 0);

          void avatarPath;
          void portraitPath;
        },
      );
    } finally {
      await sql.end();
      for (const userId of createdUserIds) {
        await admin.auth.admin.deleteUser(userId).catch(() => {});
      }
    }
  },
});
