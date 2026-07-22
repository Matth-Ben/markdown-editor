import { MarkdownContent, Open5eReferenceButton, type CodexEntrySummary } from "@nexus/ui";
import { CODEX_CATEGORIES, type CodexOpen5eRef, type CodexEntry } from "@nexus/core";
import { PlayerEntryView } from "./player-entry-view";

const ATTRIBUTE_LABELS: Record<string, string> = {
  role: "Rôle",
  stats: "Stats",
  dangerLevel: "Niveau de danger",
  region: "Région",
  locationType: "Type de lieu",
};

export function CodexEntryView({
  entry,
  codexEntries,
}: {
  entry: CodexEntry;
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  if (entry.category === "joueur") {
    return <PlayerEntryView entry={entry} codexEntries={codexEntries} />;
  }

  const categoryLabel = CODEX_CATEGORIES.find((c) => c.value === entry.category)?.label ?? entry.category;
  const rawAttributes = (entry.attributes ?? {}) as Record<string, unknown>;
  const open5eRef = rawAttributes.open5eRef as CodexOpen5eRef | undefined;
  const attributeEntries = Object.entries(rawAttributes).filter(
    (pair): pair is [string, string] => pair[0] !== "open5eRef" && Boolean(pair[1]),
  );

  return (
    <div className="space-y-3 rounded-lg border border-white/10 bg-surface p-3">
      <div className="flex items-center justify-between gap-2">
        <h3 className="text-sm font-semibold text-foreground">{entry.name}</h3>
        <span className="shrink-0 text-xs uppercase tracking-wide text-muted">{categoryLabel}</span>
      </div>

      {entry.summary ? <p className="text-xs text-muted">{entry.summary}</p> : null}

      {open5eRef ? (
        <Open5eReferenceButton kind={open5eRef.kind} entryKey={open5eRef.key} label="Voir sur Open5e" />
      ) : null}

      {attributeEntries.length > 0 ? (
        <dl className="space-y-1 text-xs">
          {attributeEntries.map(([key, value]) => (
            <div key={key}>
              <dt className="inline text-muted">{ATTRIBUTE_LABELS[key] ?? key} : </dt>
              <dd className="inline text-foreground">{value}</dd>
            </div>
          ))}
        </dl>
      ) : null}

      {entry.content ? (
        <div className="prose prose-invert prose-sm max-w-none border-t border-white/10 pt-2">
          <MarkdownContent content={entry.content} codexEntries={codexEntries} />
        </div>
      ) : null}
    </div>
  );
}
