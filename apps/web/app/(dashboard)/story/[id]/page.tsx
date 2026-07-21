import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { CodexEntrySummary } from "@nexus/ui";
import type { CodexEntry } from "@nexus/core";
import { StoryEditor } from "./story-editor";

export default async function StoryPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data: story } = await supabase.from("stories").select("*").eq("id", id).single();

  if (!story) {
    notFound();
  }

  const { data: entries } = await supabase
    .from("codex_entries")
    .select("*")
    .eq("story_id", id)
    .order("name", { ascending: true });

  const codexLookup: Record<string, CodexEntrySummary> = {};
  for (const entry of entries ?? []) {
    codexLookup[entry.name.trim().toLowerCase()] = {
      category: entry.category,
      summary: entry.summary,
    };
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-foreground">{story.title}</h1>
        <Link
          href={`/story/${id}/codex`}
          className="text-sm text-muted underline underline-offset-4 hover:text-foreground"
        >
          Codex (page dédiée)
        </Link>
      </div>
      <StoryEditor
        storyId={story.id}
        initialContent={story.content}
        entries={(entries ?? []) as CodexEntry[]}
        codexEntries={codexLookup}
      />
    </div>
  );
}
