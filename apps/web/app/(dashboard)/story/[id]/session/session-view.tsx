"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { CODEX_CATEGORIES, type CodexEntry } from "@nexus/core";
import { MarkdownContent, Modal, type CodexEntrySummary } from "@nexus/ui";
import { CodexEntryView } from "../codex-entry-view";

interface OutlineItem {
  id: string;
  text: string;
  level: number;
}

const COMBINING_DIACRITIC_RANGE_START = 0x0300;
const COMBINING_DIACRITIC_RANGE_END = 0x036f;

function stripDiacritics(text: string): string {
  return Array.from(text.normalize("NFD"))
    .filter((char) => {
      const code = char.codePointAt(0) ?? 0;
      return code < COMBINING_DIACRITIC_RANGE_START || code > COMBINING_DIACRITIC_RANGE_END;
    })
    .join("");
}

function slugify(text: string): string {
  const slug = stripDiacritics(text)
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug || "section";
}

export function SessionView({
  content,
  entries,
  codexEntries,
}: {
  content: string;
  entries: CodexEntry[];
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  const contentRef = useRef<HTMLDivElement>(null);
  const [outline, setOutline] = useState<OutlineItem[]>([]);
  const [selectedEntryId, setSelectedEntryId] = useState<string | null>(null);

  // Le sommaire est dérivé des titres effectivement rendus (après application du
  // markdown/des mentions Codex) plutôt que du texte brut, pour rester fidèle à l'affichage.
  useEffect(() => {
    const container = contentRef.current;
    if (!container) return;

    const headings = Array.from(container.querySelectorAll<HTMLHeadingElement>("h1, h2, h3"));
    const seen = new Map<string, number>();
    const items = headings.map((heading) => {
      const text = heading.textContent?.trim() ?? "";
      const base = slugify(text);
      const occurrence = seen.get(base) ?? 0;
      seen.set(base, occurrence + 1);
      const id = occurrence > 0 ? `${base}-${occurrence}` : base;
      heading.id = id;
      return { id, text, level: Number(heading.tagName[1]) };
    });
    setOutline(items);
  }, [content]);

  const entriesByCategory = useMemo(() => {
    const map = new Map<string, CodexEntry[]>();
    for (const entry of entries) {
      const list = map.get(entry.category) ?? [];
      list.push(entry);
      map.set(entry.category, list);
    }
    for (const list of map.values()) list.sort((a, b) => a.name.localeCompare(b.name));
    return map;
  }, [entries]);

  const selectedEntry = entries.find((entry) => entry.id === selectedEntryId) ?? null;

  return (
    <div className="flex flex-col gap-4 lg:flex-row lg:items-start">
      <div
        ref={contentRef}
        className="prose prose-invert prose-lg min-w-0 max-w-none flex-1 rounded-lg border border-white/10 bg-surface p-6"
      >
        <MarkdownContent content={content} codexEntries={codexEntries} />
      </div>

      <aside
        aria-label="Navigation de la feuille de route"
        className="w-full shrink-0 space-y-4 lg:sticky lg:top-8 lg:w-72"
      >
        {outline.length > 0 ? (
          <nav aria-label="Sommaire" className="space-y-2">
            <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">Sommaire</h2>
            <ul className="space-y-1">
              {outline.map((item) => (
                <li key={item.id} style={{ paddingLeft: `${(item.level - 1) * 12}px` }}>
                  <a
                    href={`#${item.id}`}
                    className="block truncate rounded-lg px-2 py-1.5 text-sm text-muted hover:bg-surface hover:text-foreground focus-visible:bg-surface focus-visible:text-accent-cyan"
                  >
                    {item.text}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        ) : null}

        <div className="space-y-2">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">Codex</h2>
          {entries.length === 0 ? (
            <p className="text-xs text-muted">Aucune fiche pour l&apos;instant.</p>
          ) : (
            <div className="space-y-3">
              {CODEX_CATEGORIES.map((category) => {
                const categoryEntries = entriesByCategory.get(category.value);
                if (!categoryEntries || categoryEntries.length === 0) return null;

                return (
                  <div key={category.value}>
                    <h3 className="mb-1 text-xs uppercase tracking-wide text-muted">
                      {category.label}
                    </h3>
                    <ul className="space-y-1">
                      {categoryEntries.map((entry) => (
                        <li key={entry.id}>
                          <button
                            type="button"
                            onClick={() => setSelectedEntryId(entry.id)}
                            className="block w-full truncate rounded-lg px-2 py-1.5 text-left text-sm text-foreground hover:bg-surface"
                          >
                            {entry.name}
                          </button>
                        </li>
                      ))}
                    </ul>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </aside>

      <Modal
        open={selectedEntry !== null}
        onClose={() => setSelectedEntryId(null)}
        title={selectedEntry?.name ?? "Fiche"}
        size={selectedEntry?.category === "joueur" ? "xl" : "md"}
      >
        {selectedEntry ? <CodexEntryView entry={selectedEntry} codexEntries={codexEntries} /> : null}
      </Modal>
    </div>
  );
}
