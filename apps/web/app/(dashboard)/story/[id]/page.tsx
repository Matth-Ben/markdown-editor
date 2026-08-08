import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { CodexEntrySummary } from "@nexus/ui";
import type { CodexEntry } from "@nexus/core";
import { StoryEditor } from "./story-editor";
import { StoryCover } from "./story-cover";
import { StoryTitle } from "./story-title";

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

  const coverUrl = story.cover_image_path
    ? supabase.storage.from("story-covers").getPublicUrl(story.cover_image_path).data.publicUrl
    : null;

  return (
    <div className="space-y-6">
      <Link
        href="/"
        className="inline-block text-sm text-muted underline underline-offset-4 hover:text-foreground"
      >
        ← Bibliothèque
      </Link>

      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex min-w-0 items-center gap-3">
          <StoryCover storyId={story.id} coverUrl={coverUrl} />
          <StoryTitle storyId={story.id} title={story.title} />
          {!story.published ? (
            <span className="shrink-0 rounded-lg border border-white/20 px-2 py-0.5 text-xs text-muted">
              Brouillon
            </span>
          ) : null}
        </div>
        <div className="flex items-center gap-4">
          <Link
            href={`/story/${id}/codex`}
            className="text-sm text-muted underline underline-offset-4 hover:text-foreground"
          >
            Codex (page dédiée)
          </Link>
          <Link
            href={`/story/${id}/session`}
            className="inline-flex items-center justify-center gap-2 rounded-lg bg-accent-violet px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-accent-violet/90"
          >
            Feuille de route
          </Link>
        </div>
      </div>
      <StoryEditor
        storyId={story.id}
        initialContent={story.content}
        published={story.published}
        entries={(entries ?? []) as CodexEntry[]}
        codexEntries={codexLookup}
      />
    </div>
  );
}
