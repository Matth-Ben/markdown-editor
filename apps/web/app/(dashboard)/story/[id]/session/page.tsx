import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { CodexEntry } from "@nexus/core";
import type { CodexEntrySummary } from "@nexus/ui";
import { SessionView } from "./session-view";

export default async function StorySessionPage({ params }: { params: Promise<{ id: string }> }) {
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
      <div className="flex flex-wrap items-center justify-between gap-4">
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
        <span className="rounded-lg border border-accent-cyan/40 px-3 py-1.5 text-sm text-accent-cyan">
          Feuille de route
        </span>
      </div>

      <SessionView
        content={story.content}
        entries={(entries ?? []) as CodexEntry[]}
        codexEntries={codexLookup}
      />
    </div>
  );
}
