"use client";

import { useMemo, useState } from "react";
import { CODEX_CATEGORIES, type CodexCategory, type CodexEntry } from "@nexus/core";
import { Modal, type CodexEntrySummary } from "@nexus/ui";
import {
  deleteCodexEntries,
  deleteCodexEntry,
  moveCodexEntriesToCategory,
  updateCodexEntry,
} from "./codex/actions";
import { CodexCreatePanel } from "./codex/codex-create-panel";
import { CodexEntryForm } from "./codex/codex-entry-form";
import { CodexEntryView } from "./codex-entry-view";

type SortOrder = "name-asc" | "name-desc" | "recent";

export function CodexSidebar({
  storyId,
  entries,
  codexEntries,
}: {
  storyId: string;
  entries: CodexEntry[];
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  const [manageMode, setManageMode] = useState(false);
  const [selectedEntryId, setSelectedEntryId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [categoryFilter, setCategoryFilter] = useState<CodexCategory | "all">("all");
  const [search, setSearch] = useState("");
  const [sortOrder, setSortOrder] = useState<SortOrder>("name-asc");
  const [checkedIds, setCheckedIds] = useState<Set<string>>(new Set());
  const [bulkCategory, setBulkCategory] = useState<CodexCategory>("pnj");

  const selectedEntry = entries.find((entry) => entry.id === selectedEntryId) ?? null;
  const isOpen = creating || selectedEntry !== null;

  const categoryCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const entry of entries) counts.set(entry.category, (counts.get(entry.category) ?? 0) + 1);
    return counts;
  }, [entries]);

  const visibleEntries = useMemo(() => {
    let list = entries;
    if (categoryFilter !== "all") list = list.filter((entry) => entry.category === categoryFilter);
    if (search.trim()) {
      const query = search.trim().toLowerCase();
      list = list.filter((entry) => entry.name.toLowerCase().includes(query));
    }
    const sorted = [...list];
    if (sortOrder === "name-asc") sorted.sort((a, b) => a.name.localeCompare(b.name));
    else if (sortOrder === "name-desc") sorted.sort((a, b) => b.name.localeCompare(a.name));
    else sorted.sort((a, b) => new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime());
    return sorted;
  }, [entries, categoryFilter, search, sortOrder]);

  // Intersection avec les entries actuelles : les ids d'une sélection passée qui ont depuis
  // été supprimés/déplacés disparaissent naturellement, sans synchronisation manuelle.
  const existingCheckedIds = useMemo(
    () => entries.map((entry) => entry.id).filter((id) => checkedIds.has(id)),
    [entries, checkedIds],
  );

  function toggleChecked(id: string) {
    setCheckedIds((previous) => {
      const next = new Set(previous);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function selectEntry(id: string) {
    setCreating(false);
    setSelectedEntryId(id);
  }

  function startCreating() {
    setSelectedEntryId(null);
    setCreating(true);
  }

  function closeModal() {
    setCreating(false);
    setSelectedEntryId(null);
  }

  const modalTitle = creating ? "Nouvelle fiche" : (selectedEntry?.name ?? "Fiche");
  const modalSize = creating || selectedEntry?.category === "joueur" ? "xl" : "md";

  return (
    <aside aria-label="Codex" className="w-full shrink-0 space-y-3 lg:w-72">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted">Codex</h2>
        <div className="flex gap-1">
          <button
            type="button"
            onClick={startCreating}
            aria-label="Ajouter une fiche"
            title="Ajouter une fiche"
            className="rounded-lg px-2 py-1 text-sm text-muted hover:bg-surface hover:text-foreground"
          >
            +
          </button>
          <button
            type="button"
            onClick={() => setManageMode((value) => !value)}
            aria-pressed={manageMode}
            aria-label="Gérer les fiches (modifier, supprimer, sélection multiple)"
            title="Gérer les fiches (modifier, supprimer, sélection multiple)"
            className={`rounded-lg px-2 py-1 text-sm hover:bg-surface hover:text-foreground ${
              manageMode ? "bg-surface text-accent-cyan" : "text-muted"
            }`}
          >
            ⚙
          </button>
        </div>
      </div>

      <div className="space-y-2">
        <label htmlFor="codex-category-filter" className="sr-only">
          Filtrer par catégorie
        </label>
        <select
          id="codex-category-filter"
          value={categoryFilter}
          onChange={(event) => setCategoryFilter(event.target.value as CodexCategory | "all")}
          className="w-full rounded-lg border border-white/10 bg-background px-2 py-1.5 text-xs text-foreground focus-visible:border-accent-cyan"
        >
          <option value="all">Toutes ({entries.length})</option>
          {CODEX_CATEGORIES.map((category) => (
            <option key={category.value} value={category.value}>
              {category.label} ({categoryCounts.get(category.value) ?? 0})
            </option>
          ))}
        </select>

        <label htmlFor="codex-search" className="sr-only">
          Rechercher une fiche
        </label>
        <input
          id="codex-search"
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Rechercher une fiche…"
          className="w-full rounded-lg border border-white/10 bg-background px-2 py-1.5 text-xs text-foreground focus-visible:border-accent-cyan"
        />

        <label htmlFor="codex-sort" className="sr-only">
          Trier
        </label>
        <select
          id="codex-sort"
          value={sortOrder}
          onChange={(event) => setSortOrder(event.target.value as SortOrder)}
          className="w-full rounded-lg border border-white/10 bg-background px-2 py-1.5 text-xs text-foreground focus-visible:border-accent-cyan"
        >
          <option value="name-asc">Nom (A → Z)</option>
          <option value="name-desc">Nom (Z → A)</option>
          <option value="recent">Modifié récemment</option>
        </select>
      </div>

      {manageMode ? (
        <p className="text-xs text-muted">
          Mode gestion actif : cliquer une fiche l&apos;ouvre en modification, cases à cocher pour
          les actions groupées.
        </p>
      ) : null}

      {manageMode && existingCheckedIds.length > 0 ? (
        <div className="space-y-2 rounded-lg border border-white/10 bg-background p-2">
          <p className="text-xs text-muted">{existingCheckedIds.length} sélectionnée(s)</p>
          <div className="flex flex-wrap items-center gap-2">
            <select
              aria-label="Nouvelle catégorie pour la sélection"
              value={bulkCategory}
              onChange={(event) => setBulkCategory(event.target.value as CodexCategory)}
              className="rounded-lg border border-white/10 bg-surface px-2 py-1 text-xs text-foreground"
            >
              {CODEX_CATEGORIES.map((category) => (
                <option key={category.value} value={category.value}>
                  {category.label}
                </option>
              ))}
            </select>
            <form action={moveCodexEntriesToCategory}>
              <input type="hidden" name="storyId" value={storyId} />
              <input type="hidden" name="entryIds" value={existingCheckedIds.join(",")} />
              <input type="hidden" name="category" value={bulkCategory} />
              <button
                type="submit"
                className="rounded-lg bg-surface px-2 py-1 text-xs text-foreground hover:bg-white/10"
              >
                Déplacer
              </button>
            </form>
            <form action={deleteCodexEntries}>
              <input type="hidden" name="storyId" value={storyId} />
              <input type="hidden" name="entryIds" value={existingCheckedIds.join(",")} />
              <button type="submit" className="rounded-lg px-2 py-1 text-xs text-red-400 hover:text-red-300">
                Supprimer la sélection
              </button>
            </form>
          </div>
        </div>
      ) : null}

      <ul className="space-y-1">
        {visibleEntries.map((entry) => (
          <li key={entry.id} className="flex items-center gap-1.5">
            {manageMode ? (
              <input
                type="checkbox"
                checked={checkedIds.has(entry.id)}
                onChange={() => toggleChecked(entry.id)}
                aria-label={`Sélectionner ${entry.name}`}
                className="shrink-0"
              />
            ) : null}
            <button
              type="button"
              onClick={() => selectEntry(entry.id)}
              className="block w-full truncate rounded-lg px-2 py-1.5 text-left text-sm text-foreground hover:bg-surface"
            >
              {entry.name}
            </button>
          </li>
        ))}
        {visibleEntries.length === 0 ? (
          <li className="text-xs text-muted">
            {entries.length === 0 ? "Aucune fiche pour l'instant." : "Aucune fiche ne correspond."}
          </li>
        ) : null}
      </ul>

      <Modal open={isOpen} onClose={closeModal} title={modalTitle} size={modalSize}>
        {creating ? (
          <CodexCreatePanel storyId={storyId} compact onSuccess={closeModal} />
        ) : selectedEntry && manageMode ? (
          <div className="space-y-2">
            <CodexEntryForm
              action={updateCodexEntry}
              storyId={storyId}
              entry={selectedEntry}
              submitLabel="Enregistrer"
              pendingLabel="Enregistrement…"
              compact
            />
            <form action={deleteCodexEntry}>
              <input type="hidden" name="storyId" value={storyId} />
              <input type="hidden" name="entryId" value={selectedEntry.id} />
              <button
                type="submit"
                className="text-sm text-red-400 underline underline-offset-4 hover:text-red-300"
              >
                Supprimer cette fiche
              </button>
            </form>
          </div>
        ) : selectedEntry ? (
          <CodexEntryView entry={selectedEntry} codexEntries={codexEntries} />
        ) : null}
      </Modal>
    </aside>
  );
}
