"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState, useTransition, type MouseEvent } from "react";
import { Button, Card, Modal } from "@nexus/ui";
import type { Story } from "@nexus/core";
import { deleteStory } from "./actions";

export function StoryCard({ story, coverUrl }: { story: Story; coverUrl: string | null }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!menuOpen) return;

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") setMenuOpen(false);
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [menuOpen]);

  function openMenuAtCursor(event: MouseEvent) {
    event.preventDefault();
    setMenuOpen(true);
  }

  function toggleMenu(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();
    setMenuOpen((open) => !open);
  }

  function handleDelete() {
    const formData = new FormData();
    formData.set("storyId", story.id);

    startTransition(async () => {
      const result = await deleteStory(formData);
      if (result.error) {
        setError(result.error);
        return;
      }
      setConfirmOpen(false);
    });
  }

  return (
    <div className="group relative" onContextMenu={openMenuAtCursor}>
      <Link href={`/story/${story.id}`} className="block rounded-xl">
        <Card className="flex flex-col transition-colors hover:border-accent-cyan/50">
          <div className="aspect-[3/2] bg-background">
            {coverUrl ? (
              <Image
                src={coverUrl}
                alt=""
                width={400}
                height={267}
                className="h-full w-full object-cover"
              />
            ) : null}
          </div>
          <div className="p-4">
            <h2 className="text-sm font-medium text-foreground">{story.title}</h2>
          </div>
        </Card>
      </Link>

      <button
        type="button"
        onClick={toggleMenu}
        aria-label="Options de l'histoire"
        aria-haspopup="menu"
        aria-expanded={menuOpen}
        className="absolute right-2 top-2 rounded-lg bg-black/60 p-1.5 text-white opacity-0 backdrop-blur-sm transition-opacity hover:bg-black/80 focus-visible:opacity-100 group-hover:opacity-100"
      >
        ⋮
      </button>

      {menuOpen ? (
        <>
          <div
            className="fixed inset-0 z-10"
            onClick={() => setMenuOpen(false)}
            aria-hidden="true"
          />
          <div
            ref={menuRef}
            role="menu"
            aria-label={`Options pour ${story.title}`}
            className="absolute right-2 top-11 z-20 w-40 overflow-hidden rounded-lg border border-white/10 bg-surface/95 py-1 shadow-lg backdrop-blur-md"
          >
            <Link
              href={`/story/${story.id}`}
              role="menuitem"
              onClick={() => setMenuOpen(false)}
              className="block px-3 py-2 text-sm text-foreground hover:bg-white/10"
            >
              Ouvrir
            </Link>
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                setMenuOpen(false);
                setError(null);
                setConfirmOpen(true);
              }}
              className="block w-full px-3 py-2 text-left text-sm text-red-400 hover:bg-white/10"
            >
              Supprimer
            </button>
          </div>
        </>
      ) : null}

      <Modal
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        title="Supprimer l'histoire"
        size="md"
      >
        <div className="space-y-4">
          <p className="text-sm text-foreground">
            Supprimer définitivement « {story.title} » ? Les fiches Codex associées seront aussi
            supprimées. Cette action est irréversible.
          </p>

          <div aria-live="polite">
            {error ? (
              <p role="alert" className="text-sm text-red-400">
                {error}
              </p>
            ) : null}
          </div>

          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setConfirmOpen(false)}>
              Annuler
            </Button>
            <button
              type="button"
              onClick={handleDelete}
              disabled={isPending}
              aria-busy={isPending || undefined}
              className="rounded-lg bg-red-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-red-500 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {isPending ? "Suppression…" : "Supprimer"}
            </button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
