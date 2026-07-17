import { createClient } from "@/lib/supabase/server";
import { NewStoryForm } from "./new-story-form";
import { StoryCard } from "./story-card";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: stories } = await supabase
    .from("stories")
    .select("*")
    .order("created_at", { ascending: false });

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Bibliothèque</h1>
        <p className="mt-1 text-muted">Tes campagnes et scénarios.</p>
      </div>

      <NewStoryForm />

      {stories && stories.length > 0 ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {stories.map((story) => (
            <StoryCard
              key={story.id}
              story={story}
              coverUrl={
                story.cover_image_path
                  ? supabase.storage.from("story-covers").getPublicUrl(story.cover_image_path)
                      .data.publicUrl
                  : null
              }
            />
          ))}
        </div>
      ) : (
        <p className="text-muted">Aucune histoire pour l&apos;instant — crée la première ci-dessus.</p>
      )}
    </div>
  );
}
