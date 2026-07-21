import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { CODEX_CATEGORIES, type CodexEntry } from "@nexus/core";
import { CodexCreatePanel } from "./codex-create-panel";

export default async function CodexPage({ params }: { params: Promise<{ id: string }> }) {
  const { id: storyId } = await params;
  const supabase = await createClient();

  const { data: story } = await supabase.from("stories").select("id, title").eq("id", storyId).single();
  if (!story) {
    notFound();
  }

  const { data: entries } = await supabase
    .from("codex_entries")
    .select("*")
    .eq("story_id", storyId)
    .order("name", { ascending: true });

  const entriesByCategory = new Map<string, CodexEntry[]>();
  for (const entry of entries ?? []) {
    const list = entriesByCategory.get(entry.category) ?? [];
    list.push(entry as CodexEntry);
    entriesByCategory.set(entry.category, list);
  }

  return (
    <div className="space-y-8">
      <div>
        <Link href={`/story/${storyId}`} className="text-sm text-muted underline underline-offset-4">
          ← {story.title}
        </Link>
        <h1 className="mt-2 text-2xl font-semibold text-foreground">Codex</h1>
        <p className="mt-1 text-muted">
          Fiches de l&apos;univers — mentionne-les dans le texte avec{" "}
          <code className="text-accent-cyan">[[Nom]]</code>.
        </p>
      </div>

      <CodexCreatePanel storyId={storyId} />

      {CODEX_CATEGORIES.map((category) => {
        const categoryEntries = entriesByCategory.get(category.value);
        if (!categoryEntries || categoryEntries.length === 0) return null;

        return (
          <div key={category.value} className="space-y-2">
            <h2 className="text-sm font-medium uppercase tracking-wide text-muted">
              {category.label}
            </h2>
            <ul className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {categoryEntries.map((entry) => (
                <li key={entry.id}>
                  <Link
                    href={`/story/${storyId}/codex/${entry.id}`}
                    className="block rounded-lg border border-white/10 bg-surface p-3 transition-colors hover:border-accent-cyan/50"
                  >
                    <span className="block text-sm font-medium text-foreground">{entry.name}</span>
                    {entry.summary ? (
                      <span className="mt-1 block text-xs text-muted">{entry.summary}</span>
                    ) : null}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        );
      })}

      {!entries || entries.length === 0 ? (
        <p className="text-muted">Aucune fiche pour l&apos;instant — crée la première ci-dessus.</p>
      ) : null}
    </div>
  );
}
