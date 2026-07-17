import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { StoryEditor } from "./story-editor";

export default async function StoryPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: story } = await supabase.from("stories").select("*").eq("id", id).single();

  if (!story) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold text-foreground">{story.title}</h1>
      <StoryEditor storyId={story.id} initialContent={story.content} />
    </div>
  );
}
