import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { CodexEntry } from "@nexus/core";
import { deleteCodexEntry, updateCodexEntry } from "../actions";
import { CodexEntryForm } from "../codex-entry-form";

export default async function CodexEntryPage({
  params,
}: {
  params: Promise<{ id: string; entryId: string }>;
}) {
  const { id: storyId, entryId } = await params;
  const supabase = await createClient();

  const { data: entry } = await supabase
    .from("codex_entries")
    .select("*")
    .eq("id", entryId)
    .eq("story_id", storyId)
    .single();

  if (!entry) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <Link href={`/story/${storyId}/codex`} className="text-sm text-muted underline underline-offset-4">
        ← Codex
      </Link>

      <h1 className="text-2xl font-semibold text-foreground">{entry.name}</h1>

      <CodexEntryForm
        action={updateCodexEntry}
        storyId={storyId}
        entry={entry as CodexEntry}
        submitLabel="Enregistrer"
        pendingLabel="Enregistrement…"
      />

      <form action={deleteCodexEntry}>
        <input type="hidden" name="storyId" value={storyId} />
        <input type="hidden" name="entryId" value={entry.id} />
        <input type="hidden" name="redirectTo" value={`/story/${storyId}/codex`} />
        <button
          type="submit"
          className="text-sm text-red-400 underline underline-offset-4 hover:text-red-300"
        >
          Supprimer cette fiche
        </button>
      </form>
    </div>
  );
}
