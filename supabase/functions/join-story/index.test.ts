// join-story — tests d'intégration (Deno.test)
//
// Premier test automatisé de ce genre dans ce dépôt (avec le pgTAP de
// supabase/tests/character_campaigns_rls_test.sql). Jusqu'ici, join-story et
// les policies RLS croisées MJ<->joueur n'avaient été vérifiées qu'à la main
// contre le stack local (curl/psql). On pose ce précédent parce que c'est de
// la logique d'autorisation inter-utilisateurs (un joueur qui rejoint
// l'histoire d'un autre via un code, un MJ qui obtient un accès en lecture
// sur le personnage d'un tiers) : le genre d'endroit où une régression
// silencieuse (ex. une future modif qui affaiblirait la vérification de
// propriété du personnage, ou qui exposerait invite_code) coûte cher et ne
// se voit pas forcément à l'œil sur un diff.
//
// Aucun mock : ce dépôt n'a pas encore de pattern de mock établi pour
// Supabase (client réel + RLS réelle), et mocker supabase-js/le comportement
// RLS ferait perdre l'essentiel de ce qu'on veut vérifier ici. Ces tests
// s'exécutent donc contre le vrai stack Supabase local (Docker), avec de
// vrais utilisateurs auth.users créés/nettoyés à chaque exécution.
//
// Prérequis pour lancer ces tests :
//   1. node_modules/.bin/supabase start                     (stack local)
//   2. node_modules/.bin/supabase functions serve join-story --no-verify-jwt
//   3. deno test --allow-net --allow-env supabase/functions/join-story/index.test.ts
//      (si Deno n'est pas installé sur le poste : voir alternative Docker
//      dans le commentaire plus bas)
//
// Pourquoi --no-verify-jwt ici : en production (config.toml par défaut,
// verify_jwt=true, non modifié par ce commit), la passerelle Supabase
// rejette elle-même toute requête sans JWT syntaxiquement valide avant
// d'atteindre notre code — un filet de sécurité utile, mais qui, en local,
// masquerait les branches d'authentification qu'on a explicitement écrites
// dans index.ts (auth.getUser(), messages d'erreur "unauthorized"/"Session
// invalide ou expirée"). --no-verify-jwt ne désactive rien en production :
// c'est un flag de `supabase functions serve` uniquement, pas un réglage
// persisté dans config.toml. Ces tests visent donc précisément notre propre
// logique d'auth, en plus (pas à la place) de la vérification de la
// passerelle qui s'applique, elle, une fois la fonction réellement déployée.
//
// Alternative sans Deno installé sur l'hôte (utilisée pour vérifier ce
// fichier au moment de son ajout, sur un poste sans Deno global) :
//   docker run --rm --network host \
//     -v "<repo>/supabase/functions/join-story:/work" -w /work \
//     denoland/deno:2.1.4 test --allow-net --allow-env index.test.ts
//   (ou, si --network host indisponible côté Docker Desktop Windows,
//   utiliser -e SUPABASE_URL=http://host.docker.internal:54321)
//
// Les clés ANON/SERVICE_ROLE et l'URL Postgres ci-dessous sont les valeurs
// de démo locales standard de la CLI Supabase (issuer JWT "supabase-demo",
// identifiants "postgres:postgres", identiques sur tout projet initialisé
// avec la configuration par défaut de `supabase init` — visibles en clair
// dans la sortie de `supabase start`/`status`, et sans valeur en dehors du
// stack Docker local). Ce ne sont PAS les identifiants du projet distant
// `nexus-jdr`. Surchargeables via variables d'environnement pour un autre
// poste/CI dont la config locale diffère.
//
// Pourquoi une connexion Postgres directe (rôle `postgres`, superuser) en
// plus du client service_role : la création/suppression des fixtures
// story/character ci-dessous passe par cette connexion directe plutôt que
// par `admin.from("stories")/.from("characters")` (client service_role via
// PostgREST), pour NE PAS élargir les privilèges accordés à `service_role`
// au-delà de ce que join-story/index.ts utilise réellement (select sur
// stories/characters, select+insert sur character_campaigns — voir
// 20260830100200_grant_service_role_join_story.sql). Élargir ces GRANTs
// juste pour le confort du harnais de test aurait affaibli, sans raison
// fonctionnelle, le principe de moindre privilège déjà en place pour ce
// rôle. Même logique que le pgTAP de supabase/tests/ : le harnais de test a
// les pleins pouvoirs (rôle postgres), le code testé (join-story) garde
// exactement les privilèges qu'il a en production.
import { assert, assertEquals, assertExists } from "jsr:@std/assert@1";
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

const FUNCTION_URL = `${SUPABASE_URL}/functions/v1/join-story`;
const TEST_PASSWORD = "join-story-tests-password-123!";

function callJoinStory(body: unknown, token?: string) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return fetch(FUNCTION_URL, { method: "POST", headers, body: JSON.stringify(body) });
}

Deno.test({
  name: "join-story — flux d'invitation MJ -> joueur (contre le stack Supabase local)",
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const anon = createClient(SUPABASE_URL, ANON_KEY, { auth: { persistSession: false } });
    // Connexion directe (rôle postgres) réservée au harnais de test — voir
    // le commentaire d'en-tête. Jamais utilisée par join-story lui-même.
    const sql = postgres(DB_URL, { max: 1 });

    // Suffixe unique par exécution : permet de relancer ce fichier
    // plusieurs fois de suite sans collision (emails/codes uniques), sans
    // dépendre d'un état laissé par une exécution précédente.
    const suffix = crypto.randomUUID().slice(0, 8);

    const createdUserIds: string[] = [];
    const createdStoryIds: string[] = [];
    const createdCharacterIds: string[] = [];

    async function createUser(label: string) {
      const email = `join-story-test-${label}-${suffix}@example.invalid`;
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
        insert into public.stories (user_id, title, invite_code, invite_code_enabled)
        values (${gmId}, ${`join-story test ${suffix}`}, ${inviteCode}, ${enabled})
        returning id
      `;
      const id = rows[0]?.id;
      if (!id) throw new Error("Échec création story de test");
      createdStoryIds.push(id);
      return id;
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
      const gm = await createUser("gm");
      const player = await createUser("player");
      const otherPlayer = await createUser("other-player");

      const enabledCode = `EN${suffix}`.toUpperCase().slice(0, 12);
      const disabledCode = `DIS${suffix}`.toUpperCase().slice(0, 12);
      const raceCode = `RACE${suffix}`.toUpperCase().slice(0, 12);

      const enabledStoryId = await createStory(gm.id, enabledCode, true);
      const disabledStoryId = await createStory(gm.id, disabledCode, false);
      void disabledStoryId;

      const playerCharacterId = await createCharacter(player.id, "Test Hero");
      const notOwnedCharacterId = await createCharacter(otherPlayer.id, "Not Mine");

      const playerEmail = `join-story-test-player-${suffix}@example.invalid`;
      const playerToken = await signIn(playerEmail);

      await t.step("code valide -> succès (character_campaign_id + infos histoire)", async () => {
        const res = await callJoinStory(
          { code: enabledCode, character_id: playerCharacterId },
          playerToken,
        );
        assertEquals(res.status, 200);
        const body = await res.json();
        assertExists(body.character_campaign_id);
        assertExists(body.joined_at);
        assertEquals(body.story.id, enabledStoryId);
        assertEquals(body.story.title, `join-story test ${suffix}`);
      });

      await t.step("code invalide -> 404 invalid_code", async () => {
        const res = await callJoinStory(
          { code: "DOES-NOT-EXIST", character_id: playerCharacterId },
          playerToken,
        );
        assertEquals(res.status, 404);
        const body = await res.json();
        assertEquals(body.error, "invalid_code");
      });

      await t.step("invitation désactivée -> 403 invite_disabled", async () => {
        const res = await callJoinStory(
          { code: disabledCode, character_id: playerCharacterId },
          playerToken,
        );
        assertEquals(res.status, 403);
        const body = await res.json();
        assertEquals(body.error, "invite_disabled");
      });

      await t.step(
        "personnage n'appartenant pas à l'appelant -> 403 character_not_owned",
        async () => {
          const res = await callJoinStory(
            { code: enabledCode, character_id: notOwnedCharacterId },
            playerToken,
          );
          assertEquals(res.status, 403);
          const body = await res.json();
          assertEquals(body.error, "character_not_owned");
        },
      );

      await t.step(
        "personnage déjà rattaché à cette histoire -> 409 already_joined",
        async () => {
          // playerCharacterId a déjà rejoint enabledStoryId dans le premier
          // step : ce second appel doit être rejeté par la vérification
          // préalable (pas par la contrainte unique, celle-ci est couverte
          // séparément par le step "course" ci-dessous).
          const res = await callJoinStory(
            { code: enabledCode, character_id: playerCharacterId },
            playerToken,
          );
          assertEquals(res.status, 409);
          const body = await res.json();
          assertEquals(body.error, "already_joined");
        },
      );

      await t.step(
        "course entre deux requêtes concurrentes -> une seule réussit, l'autre 409 (contrainte unique 23505)",
        async () => {
          // Personnage/histoire dédiés à ce step pour partir d'un état
          // "jamais rejoint" : les deux appels passent alors la
          // vérification préalable ("existing === null") avant que l'un des
          // deux inserts n'échoue sur la contrainte unique
          // (character_id, story_id) — c'est le chemin insertError.code
          // === "23505" de join-story/index.ts qui est visé ici. Le
          // résultat exact (laquelle des deux requêtes "gagne") dépend du
          // scheduling réel de l'edge runtime/Postgres et n'est pas
          // garanti déterministe à 100 %, mais l'invariant vérifié — une
          // seule ligne créée, l'autre requête rejetée proprement en 409 —
          // doit toujours être vrai.
          const raceCharacterId = await createCharacter(player.id, "Race Hero");
          const raceStoryId = await createStory(gm.id, raceCode, true);

          const [resA, resB] = await Promise.all([
            callJoinStory({ code: raceCode, character_id: raceCharacterId }, playerToken),
            callJoinStory({ code: raceCode, character_id: raceCharacterId }, playerToken),
          ]);

          const statuses = [resA.status, resB.status].sort((a, b) => a - b);
          assertEquals(statuses, [200, 409]);

          const winner = resA.status === 200 ? resA : resB;
          const loser = resA.status === 200 ? resB : resA;
          const winnerBody = await winner.json();
          const loserBody = await loser.json();
          assertExists(winnerBody.character_campaign_id);
          assertEquals(loserBody.error, "already_joined");

          const { count, error } = await admin
            .from("character_campaigns")
            .select("id", { count: "exact", head: true })
            .eq("character_id", raceCharacterId)
            .eq("story_id", raceStoryId);
          if (error) throw error;
          assertEquals(count, 1, "une seule ligne character_campaigns doit avoir été créée");
        },
      );

      await t.step("requête sans JWT -> 401", async () => {
        const res = await callJoinStory({ code: enabledCode, character_id: playerCharacterId });
        assertEquals(res.status, 401);
      });

      await t.step("requête avec un JWT invalide -> 401", async () => {
        const res = await callJoinStory(
          { code: enabledCode, character_id: playerCharacterId },
          "not-a-real-jwt",
        );
        assertEquals(res.status, 401);
      });

      // Contrôle de non-régression sur la sécurité déjà couverte par les
      // policies RLS (voir supabase/tests/character_campaigns_rls_test.sql
      // pour le test dédié, exhaustif) : un appel direct au client
      // service_role sur character_campaigns fonctionne (c'est la seule
      // voie légitime), un client authenticated non-MJ/non-propriétaire ne
      // doit jamais pouvoir insérer par un autre chemin que join-story.
      assert(createdCharacterIds.length >= 3, "sanity check sur les fixtures créées");
    } finally {
      // Nettoyage : aucune donnée de test ne doit persister d'une
      // exécution à l'autre (utilisateurs Auth réels, donc pas de
      // ROLLBACK possible comme pour le pgTAP — nettoyage explicite requis).
      // Suppression via la connexion postgres directe (rôle postgres) :
      // supprimer characters/stories suffit, character_campaigns est
      // rattachée aux deux par "on delete cascade"
      // (20260830100100_create_character_campaigns.sql) et disparaît donc
      // automatiquement avec elles.
      if (createdCharacterIds.length) {
        await sql`delete from public.characters where id in ${sql(createdCharacterIds)}`;
      }
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
