"use client";

import { useId, useRef, useState, type KeyboardEvent } from "react";
import { createPortal } from "react-dom";
import { searchOpen5e, type Open5eKind, type Open5eSearchResult } from "@nexus/core";
import { Open5eDetailContent } from "../open5e-detail-content";

const HOVER_DELAY_MS = 350;
const SEARCH_DEBOUNCE_MS = 300;
const PREVIEW_WIDTH = 256;
const PREVIEW_GAP = 8;
const PREVIEW_MAX_HEIGHT = 320;

interface PreviewState {
  key: string;
  top: number;
  left: number;
  maxHeight: number;
}

function optionId(listboxId: string, key: string) {
  return `${listboxId}-option-${key}`;
}

export function Open5eSearchCombobox<T extends Open5eSearchResult>({
  kind,
  placeholder,
  onSelect,
  fetchResults,
  value,
  onValueChange,
  id,
  name,
}: {
  kind: Open5eKind;
  placeholder?: string;
  onSelect: (result: T) => void;
  /** Surcharge la recherche serveur par défaut — utile pour les petits jeux de données
   * (classes, species) dont le filtre `name__icontains` est ignoré côté API. */
  fetchResults?: (query: string) => Promise<T[]>;
  /** Mode contrôlé : ce champ EST le champ réel du formulaire (ex. Race/Classe), pas une
   * recherche transitoire séparée. Dans ce mode, sélectionner un résultat ne vide pas le champ. */
  value?: string;
  onValueChange?: (value: string) => void;
  id?: string;
  name?: string;
}) {
  const isControlled = value !== undefined;
  const [internalQuery, setInternalQuery] = useState("");
  const query = isControlled ? value : internalQuery;
  const [results, setResults] = useState<T[]>([]);
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const [preview, setPreview] = useState<PreviewState | null>(null);
  const hoverTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const searchTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const listboxId = useId();

  function runSearch(value: string) {
    if (searchTimeoutRef.current) clearTimeout(searchTimeoutRef.current);

    if (!value.trim()) {
      setResults([]);
      return;
    }

    searchTimeoutRef.current = setTimeout(() => {
      const resolveResults = fetchResults ?? ((q: string) => searchOpen5e<T>(kind, q));
      resolveResults(value)
        .then((data) => {
          setResults(data);
          setActiveIndex(0);
        })
        .catch(() => setResults([]));
    }, SEARCH_DEBOUNCE_MS);
  }

  function rectFor(target: HTMLElement): { top: number; left: number; maxHeight: number } {
    const rect = target.getBoundingClientRect();
    const overflowsRight = rect.right + PREVIEW_GAP + PREVIEW_WIDTH > window.innerWidth;
    // La hauteur réelle du contenu n'est connue qu'après son chargement asynchrone : on se base
    // sur le pire cas (maxHeight) pour que le popover ne déborde jamais, même si le contenu est
    // plus long que prévu (auto-scroll interne au-delà de cette hauteur).
    const maxHeight = Math.min(PREVIEW_MAX_HEIGHT, window.innerHeight - PREVIEW_GAP * 2);
    const top = Math.min(
      Math.max(rect.top, PREVIEW_GAP),
      window.innerHeight - maxHeight - PREVIEW_GAP,
    );
    return {
      top,
      left: overflowsRight
        ? Math.max(PREVIEW_GAP, rect.left - PREVIEW_WIDTH - PREVIEW_GAP)
        : rect.right + PREVIEW_GAP,
      maxHeight,
    };
  }

  function showPreviewNow(key: string, target: HTMLElement) {
    if (hoverTimeoutRef.current) clearTimeout(hoverTimeoutRef.current);
    setPreview({ key, ...rectFor(target) });
  }

  function scheduleHoverPreview(key: string, target: HTMLElement) {
    if (hoverTimeoutRef.current) clearTimeout(hoverTimeoutRef.current);
    const coords = rectFor(target);
    hoverTimeoutRef.current = setTimeout(() => setPreview({ key, ...coords }), HOVER_DELAY_MS);
  }

  function clearPreview() {
    if (hoverTimeoutRef.current) clearTimeout(hoverTimeoutRef.current);
    setPreview(null);
  }

  function showPreviewForIndex(index: number) {
    const result = results[index];
    if (!result) return;
    const element = document.getElementById(optionId(listboxId, result.key));
    if (element) showPreviewNow(result.key, element);
  }

  function handleChange(newValue: string) {
    if (isControlled) onValueChange?.(newValue);
    else setInternalQuery(newValue);
    setOpen(true);
    runSearch(newValue);
  }

  function selectResult(result: T) {
    onSelect(result);
    if (!isControlled) setInternalQuery("");
    setResults([]);
    setOpen(false);
    clearPreview();
  }

  function handleKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (!open || results.length === 0) return;

    if (event.key === "ArrowDown") {
      event.preventDefault();
      const nextIndex = (activeIndex + 1) % results.length;
      setActiveIndex(nextIndex);
      showPreviewForIndex(nextIndex);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      const nextIndex = (activeIndex - 1 + results.length) % results.length;
      setActiveIndex(nextIndex);
      showPreviewForIndex(nextIndex);
    } else if (event.key === "Enter" || event.key === "Tab") {
      if (results[activeIndex]) {
        event.preventDefault();
        selectResult(results[activeIndex]);
      }
    } else if (event.key === "Escape") {
      setOpen(false);
      clearPreview();
    }
  }

  return (
    <div className="relative">
      <input
        id={id}
        name={name}
        type="text"
        value={query}
        onChange={(event) => handleChange(event.target.value)}
        onFocus={() => setOpen(true)}
        onBlur={() =>
          setTimeout(() => {
            setOpen(false);
            clearPreview();
          }, 150)
        }
        onKeyDown={handleKeyDown}
        role="combobox"
        aria-expanded={open && results.length > 0}
        aria-controls={listboxId}
        aria-autocomplete="list"
        placeholder={placeholder ?? "Rechercher sur Open5e…"}
        className="w-full rounded-lg border border-white/10 bg-background px-2 py-1.5 text-xs text-foreground focus-visible:border-accent-cyan"
      />

      {open && results.length > 0 ? (
        <ul
          id={listboxId}
          role="listbox"
          aria-label="Résultats Open5e"
          className="absolute z-20 mt-1 max-h-56 w-full overflow-auto rounded-lg border border-white/10 bg-surface py-1 shadow-lg"
        >
          {results.map((result, index) => (
            <li key={result.key}>
              <button
                type="button"
                id={optionId(listboxId, result.key)}
                role="option"
                aria-selected={index === activeIndex}
                onMouseEnter={(event) => {
                  setActiveIndex(index);
                  scheduleHoverPreview(result.key, event.currentTarget);
                }}
                onMouseLeave={clearPreview}
                onMouseDown={(event) => {
                  event.preventDefault();
                  selectResult(result);
                }}
                className={`block w-full px-2 py-1.5 text-left text-xs ${
                  index === activeIndex
                    ? "bg-accent-violet text-white"
                    : "text-foreground hover:bg-background"
                }`}
              >
                {result.name}
                {result.document ? (
                  <span className={index === activeIndex ? "ml-1 text-white/70" : "ml-1 text-muted"}>
                    ({result.document.name})
                  </span>
                ) : null}
              </button>
            </li>
          ))}
        </ul>
      ) : null}

      {preview
        ? createPortal(
            <div
              style={{
                position: "fixed",
                top: preview.top,
                left: preview.left,
                width: PREVIEW_WIDTH,
                maxHeight: preview.maxHeight,
              }}
              className="z-50 overflow-y-auto rounded-lg border border-white/10 bg-surface p-2 shadow-xl"
            >
              <Open5eDetailContent kind={kind} entryKey={preview.key} />
            </div>,
            document.body,
          )
        : null}
    </div>
  );
}
