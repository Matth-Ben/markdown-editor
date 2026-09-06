import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { InvitePanel } from "./invite-panel";
import { JoueursView, type PlayerRow } from "./joueurs-view";

export default async function StoryJoueursPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: story } = await supabase
    .from("stories")
    .select("id, title, invite_code, invite_code_enabled")
    .eq("id", id)
    .single();

  if (!story) {
    notFound();
  }

  // Une ligne par personnage joueur rattaché à cette histoire — les PNJ (role='pnj') ne
  // concernent pas ce panneau (cf. docs/cahier-des-charges/12-partage-et-groupes.md section 5.6).
  const { data: campaigns } = await supabase
    .from("character_campaigns")
    .select("id, character_id, joined_at")
    .eq("story_id", id)
    .eq("role", "joueur")
    .order("joined_at", { ascending: true });

  const characterIds = (campaigns ?? []).map((campaign) => campaign.character_id);

  let players: PlayerRow[] = [];

  if (characterIds.length > 0) {
    const [{ data: characters }, { data: primaryClasses }] = await Promise.all([
      supabase
        .from("characters")
        .select("id, name, portrait_url, race_id, race_custom_text")
        .in("id", characterIds),
      supabase
        .from("character_classes")
        .select("character_id, class_id, level")
        .in("character_id", characterIds)
        .eq("is_primary", true),
    ]);

    const characterById = new Map((characters ?? []).map((character) => [character.id, character]));
    const primaryClassByCharacterId = new Map(
      (primaryClasses ?? []).map((primaryClass) => [primaryClass.character_id, primaryClass]),
    );

    // Les noms FR de race/classe vivent dans `translations` (pas de colonne `name` directe sur
    // `races`/`classes`) — voir 12-partage-et-groupes.md section "Schéma déjà vérifié".
    const raceIds = Array.from(
      new Set(
        (characters ?? [])
          .map((character) => character.race_id)
          .filter((raceId): raceId is number => raceId !== null),
      ),
    );
    const classIds = Array.from(
      new Set(
        (primaryClasses ?? [])
          .map((primaryClass) => primaryClass.class_id)
          .filter((classId): classId is number => classId !== null),
      ),
    );

    let raceNameById = new Map<string, string>();
    if (raceIds.length > 0) {
      const { data: raceTranslations } = await supabase
        .from("translations")
        .select("entity_id, value")
        .eq("entity_type", "race")
        .eq("field_name", "name")
        .eq("locale", "fr")
        .in(
          "entity_id",
          raceIds.map((raceId) => String(raceId)),
        );
      raceNameById = new Map(
        (raceTranslations ?? []).map((translation) => [translation.entity_id, translation.value]),
      );
    }

    let classNameById = new Map<string, string>();
    if (classIds.length > 0) {
      const { data: classTranslations } = await supabase
        .from("translations")
        .select("entity_id, value")
        .eq("entity_type", "class")
        .eq("field_name", "name")
        .eq("locale", "fr")
        .in(
          "entity_id",
          classIds.map((classId) => String(classId)),
        );
      classNameById = new Map(
        (classTranslations ?? []).map((translation) => [translation.entity_id, translation.value]),
      );
    }

    players = (campaigns ?? []).flatMap((campaign) => {
      const character = characterById.get(campaign.character_id);
      if (!character) return [];

      const primaryClass = primaryClassByCharacterId.get(campaign.character_id) ?? null;
      const raceLabel =
        (character.race_id !== null ? raceNameById.get(String(character.race_id)) : undefined) ??
        character.race_custom_text ??
        "Race inconnue";
      const classLabel = primaryClass
        ? (classNameById.get(String(primaryClass.class_id)) ?? "Classe inconnue")
        : "Classe inconnue";

      const player: PlayerRow = {
        campaignId: campaign.id,
        characterId: character.id,
        name: character.name,
        portraitUrl: character.portrait_url,
        raceLabel,
        classLabel,
        level: primaryClass?.level ?? null,
      };
      return [player];
    });
  }

  return (
    <div className="space-y-6">
      <div>
        <Link
          href="/"
          className="block text-sm text-muted underline underline-offset-4 hover:text-foreground"
        >
          ← Bibliothèque
        </Link>
        <Link
          href={`/story/${id}`}
          className="text-sm text-muted underline underline-offset-4 hover:text-foreground"
        >
          ← Retour à l&apos;édition
        </Link>
        <h1 className="mt-2 text-2xl font-semibold text-foreground">{story.title}</h1>
      </div>

      <InvitePanel
        storyId={id}
        inviteCode={story.invite_code}
        inviteCodeEnabled={story.invite_code_enabled}
      />

      <JoueursView storyId={id} players={players} />
    </div>
  );
}
