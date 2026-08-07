"use client";

import { useRef, useState, type RefObject } from "react";
import {
  insertCodeBlock,
  insertHorizontalRule,
  insertImage,
  insertLink,
  toggleLinePrefix,
  wrapSelection,
  type TextEditResult,
} from "@nexus/core";

const HEADING_STRIP_PATTERN = /^#{1,6}\s+/;

export function MarkdownToolbar({
  textareaRef,
  value,
  onChange,
  onUploadImage,
}: {
  textareaRef: RefObject<HTMLTextAreaElement | null>;
  value: string;
  onChange: (value: string) => void;
  /** Si fourni, ajoute un bouton "Importer" à côté de "Image" pour uploader un fichier local
   * plutôt que de saisir une URL. Doit renvoyer l'URL publique une fois l'image hébergée. */
  onUploadImage?: (file: File) => Promise<string>;
}) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  function applyEdit(edit: (text: string, start: number, end: number) => TextEditResult) {
    const textarea = textareaRef.current;
    if (!textarea) return;

    const result = edit(value, textarea.selectionStart, textarea.selectionEnd);
    onChange(result.text);

    requestAnimationFrame(() => {
      textarea.focus();
      textarea.setSelectionRange(result.selectionStart, result.selectionEnd);
    });
  }

  function insertLinkWithPrompt() {
    const url = window.prompt("URL du lien :", "https://");
    if (!url) return;
    applyEdit((text, start, end) => insertLink(text, start, end, url));
  }

  function insertImageWithPrompt() {
    const url = window.prompt("URL de l'image :", "https://");
    if (!url) return;
    applyEdit((text, start, end) => insertImage(text, start, end, url));
  }

  async function handleFileSelected(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file || !onUploadImage) return;

    setUploading(true);
    setUploadError(null);
    try {
      const url = await onUploadImage(file);
      applyEdit((text, start, end) => insertImage(text, start, end, url));
    } catch {
      setUploadError("Impossible d'importer cette image.");
    } finally {
      setUploading(false);
    }
  }

  return (
    <div>
      <div
        role="toolbar"
        aria-label="Mise en forme Markdown"
        className="flex flex-wrap items-center gap-1 rounded-t-lg border border-b-0 border-white/10 bg-surface p-1"
      >
      <ToolbarGroup>
        <ToolbarButton
          label="H1"
          title="Titre 1"
          onClick={() => applyEdit((t, s, e) => toggleLinePrefix(t, s, e, "# ", HEADING_STRIP_PATTERN))}
        />
        <ToolbarButton
          label="H2"
          title="Titre 2"
          onClick={() => applyEdit((t, s, e) => toggleLinePrefix(t, s, e, "## ", HEADING_STRIP_PATTERN))}
        />
        <ToolbarButton
          label="H3"
          title="Titre 3"
          onClick={() => applyEdit((t, s, e) => toggleLinePrefix(t, s, e, "### ", HEADING_STRIP_PATTERN))}
        />
      </ToolbarGroup>

      <ToolbarSeparator />

      <ToolbarGroup>
        <ToolbarButton
          label="G"
          title="Gras"
          className="font-bold"
          onClick={() => applyEdit((t, s, e) => wrapSelection(t, s, e, "**", "texte en gras"))}
        />
        <ToolbarButton
          label="I"
          title="Italique"
          className="italic"
          onClick={() => applyEdit((t, s, e) => wrapSelection(t, s, e, "*", "texte en italique"))}
        />
        <ToolbarButton
          label="S"
          title="Barré"
          className="line-through"
          onClick={() => applyEdit((t, s, e) => wrapSelection(t, s, e, "~~", "texte barré"))}
        />
        <ToolbarButton
          label="</>"
          title="Code en ligne"
          onClick={() => applyEdit((t, s, e) => wrapSelection(t, s, e, "`", "code"))}
        />
      </ToolbarGroup>

      <ToolbarSeparator />

      <ToolbarGroup>
        <ToolbarButton label="Lien" title="Insérer un lien" onClick={insertLinkWithPrompt} />
        <ToolbarButton
          label="Image"
          title="Insérer une image depuis une URL"
          onClick={insertImageWithPrompt}
        />
        {onUploadImage ? (
          <>
            <ToolbarButton
              label={uploading ? "Envoi…" : "Importer"}
              title="Importer une image depuis l'ordinateur"
              disabled={uploading}
              onClick={() => fileInputRef.current?.click()}
            />
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handleFileSelected}
            />
          </>
        ) : null}
      </ToolbarGroup>

      <ToolbarSeparator />

      <ToolbarGroup>
        <ToolbarButton
          label="Citation"
          title="Citation"
          onClick={() => applyEdit((t, s, e) => toggleLinePrefix(t, s, e, "> "))}
        />
        <ToolbarButton
          label="• Liste"
          title="Liste à puces"
          onClick={() => applyEdit((t, s, e) => toggleLinePrefix(t, s, e, "- "))}
        />
        <ToolbarButton
          label="1. Liste"
          title="Liste numérotée"
          onClick={() => applyEdit((t, s, e) => toggleLinePrefix(t, s, e, "1. "))}
        />
        <ToolbarButton label="```" title="Bloc de code" onClick={() => applyEdit(insertCodeBlock)} />
        <ToolbarButton
          label="―"
          title="Ligne horizontale"
          onClick={() => applyEdit(insertHorizontalRule)}
        />
      </ToolbarGroup>
      </div>

      {uploadError ? (
        <p role="alert" className="text-xs text-red-400">
          {uploadError}
        </p>
      ) : null}
    </div>
  );
}

function ToolbarGroup({ children }: { children: React.ReactNode }) {
  return <div className="flex items-center gap-0.5">{children}</div>;
}

function ToolbarSeparator() {
  return <div aria-hidden className="mx-0.5 h-5 w-px bg-white/10" />;
}

function ToolbarButton({
  label,
  title,
  onClick,
  className = "",
  disabled = false,
}: {
  label: string;
  title: string;
  onClick: () => void;
  className?: string;
  disabled?: boolean;
}) {
  return (
    <button
      type="button"
      title={title}
      aria-label={title}
      disabled={disabled}
      onMouseDown={(event) => event.preventDefault()}
      onClick={onClick}
      className={`rounded px-2 py-1 text-xs text-foreground hover:bg-white/10 disabled:opacity-50 ${className}`}
    >
      {label}
    </button>
  );
}
