"use client";

import Image from "next/image";
import { useRef, useState, useTransition, type DragEvent } from "react";
import { Button, Modal } from "@nexus/ui";
import { updateStoryCover } from "./actions";

export function StoryCover({ storyId, coverUrl }: { storyId: string; coverUrl: string | null }) {
  const [open, setOpen] = useState(false);
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const inputRef = useRef<HTMLInputElement>(null);

  function resetSelection() {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewFile(null);
    setPreviewUrl(null);
  }

  function openModal() {
    resetSelection();
    setError(null);
    setOpen(true);
  }

  function closeModal() {
    resetSelection();
    setOpen(false);
  }

  function selectFile(file: File | null) {
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      setError("Le fichier doit être une image.");
      return;
    }
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewFile(file);
    setPreviewUrl(URL.createObjectURL(file));
    setError(null);
  }

  function handleDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault();
    setDragOver(false);
    selectFile(event.dataTransfer.files?.[0] ?? null);
  }

  function handleSave() {
    if (!previewFile) return;

    const formData = new FormData();
    formData.set("storyId", storyId);
    formData.set("cover", previewFile);

    startTransition(async () => {
      const result = await updateStoryCover(formData);
      if (result.error) {
        setError(result.error);
        return;
      }
      closeModal();
    });
  }

  const previewSrc = previewUrl ?? coverUrl;

  return (
    <>
      <button
        type="button"
        onClick={openModal}
        aria-label={coverUrl ? "Changer la couverture" : "Ajouter une couverture"}
        title={coverUrl ? "Changer la couverture" : "Ajouter une couverture"}
        className="group relative h-11 w-16 shrink-0 overflow-hidden rounded-lg border border-white/10 bg-surface"
      >
        {coverUrl ? (
          <Image src={coverUrl} alt="" fill sizes="64px" className="object-cover" />
        ) : (
          <span className="flex h-full w-full items-center justify-center text-lg text-muted">+</span>
        )}
        <span
          aria-hidden="true"
          className="absolute inset-0 flex items-center justify-center bg-black/60 text-xs text-white opacity-0 transition-opacity group-hover:opacity-100"
        >
          ✎
        </span>
      </button>

      <Modal open={open} onClose={closeModal} title="Couverture de l'histoire" size="md">
        <div className="space-y-4">
          <div
            onClick={() => inputRef.current?.click()}
            onDragOver={(event) => {
              event.preventDefault();
              setDragOver(true);
            }}
            onDragLeave={() => setDragOver(false)}
            onDrop={handleDrop}
            role="button"
            tabIndex={0}
            onKeyDown={(event) => {
              if (event.key === "Enter" || event.key === " ") {
                event.preventDefault();
                inputRef.current?.click();
              }
            }}
            className={`flex aspect-[3/2] cursor-pointer items-center justify-center overflow-hidden rounded-lg border-2 border-dashed transition-colors ${
              dragOver ? "border-accent-cyan bg-surface" : "border-white/20 bg-background"
            }`}
          >
            {previewSrc ? (
              // Aperçu potentiellement basé sur une blob: URL (fichier local pas encore
              // envoyé) — incompatible avec l'optimisation de next/image.
              // eslint-disable-next-line @next/next/no-img-element
              <img src={previewSrc} alt="Aperçu de la couverture" className="h-full w-full object-cover" />
            ) : (
              <p className="px-6 text-center text-sm text-muted">
                Glisse une image ici, ou clique pour choisir un fichier
              </p>
            )}
          </div>

          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            className="sr-only"
            aria-label="Choisir une image de couverture"
            onChange={(event) => selectFile(event.target.files?.[0] ?? null)}
          />

          <div aria-live="polite">
            {error ? (
              <p role="alert" className="text-sm text-red-400">
                {error}
              </p>
            ) : null}
          </div>

          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={closeModal}>
              Annuler
            </Button>
            <Button type="button" onClick={handleSave} isLoading={isPending} disabled={!previewFile}>
              {isPending ? "Enregistrement…" : "Enregistrer"}
            </Button>
          </div>
        </div>
      </Modal>
    </>
  );
}
