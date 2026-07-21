"use client";

import { useState, type ChangeEvent } from "react";
import { createCodexEntry } from "./actions";
import { CodexEntryForm, type CodexEntryInitialValues } from "./codex-entry-form";
import { parseCharacterBuilderXml } from "./parse-character-import";

export function CodexCreatePanel({
  storyId,
  compact,
  onSuccess,
}: {
  storyId: string;
  compact?: boolean;
  onSuccess?: () => void;
}) {
  const [initialValues, setInitialValues] = useState<CodexEntryInitialValues | undefined>(undefined);
  const [importKey, setImportKey] = useState(0);
  const [importError, setImportError] = useState<string | null>(null);

  async function handleFileSelected(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = ""; // permet de réimporter le même fichier ensuite si besoin

    if (!file) return;

    const text = await file.text();
    const parsed = parseCharacterBuilderXml(text);

    if (!parsed) {
      setImportError("Ce fichier ne ressemble pas à une fiche personnage compatible.");
      return;
    }

    setImportError(null);
    setInitialValues(parsed);
    setImportKey((key) => key + 1);
  }

  return (
    <div className="space-y-3">
      <div>
        <label
          htmlFor="codex-import-file"
          className="inline-block cursor-pointer rounded-lg border border-white/10 bg-background px-3 py-1.5 text-sm text-muted hover:text-foreground"
        >
          Importer une fiche personnage (.xml)
        </label>
        <input
          id="codex-import-file"
          type="file"
          accept=".xml,text/xml,application/xml"
          onChange={handleFileSelected}
          className="sr-only"
        />
        <div aria-live="polite">
          {importError ? (
            <p role="alert" className="mt-1 text-sm text-red-400">
              {importError}
            </p>
          ) : null}
        </div>
      </div>

      <CodexEntryForm
        key={importKey}
        action={createCodexEntry}
        storyId={storyId}
        initialValues={initialValues}
        submitLabel="Créer la fiche"
        pendingLabel="Création…"
        compact={compact}
        onSuccess={onSuccess}
      />
    </div>
  );
}
