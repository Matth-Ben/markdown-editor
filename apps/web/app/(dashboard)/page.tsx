import { createClient } from "@/lib/supabase/server";
import { NewStoryButton } from "./new-story-button";
import { StoryCard } from "./story-card";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: stories } = await supabase
    .from("stories")
    .select("*")
    .eq("published", true)
    .order("created_at", { ascending: false });

  return (
    <div className="space-y-8">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Bibliothèque</h1>
          <p className="mt-1 text-muted">Tes campagnes et scénarios.</p>
        </div>
        <NewStoryButton />
      </div>

      {stories && stories.length > 0 ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {stories.map((story, index) => (
            <StoryCard
              key={story.id}
              story={story}
              coverUrl={
                story.cover_image_path
                  ? supabase.storage.from("story-covers").getPublicUrl(story.cover_image_path)
                      .data.publicUrl
                  : null
              }
              // La grille passe jusqu'à 4 colonnes (xl:grid-cols-4) : ces cartes sont donc les
              // seules garanties au-dessus de la ligne de flottaison au premier rendu.
              eagerLoadCover={index < 4}
            />
          ))}
        </div>
      ) : (
        <p className="text-muted">Aucune histoire pour l&apos;instant — crée la première ci-dessus.</p>
      )}
    </div>
  );
}
