"use client";

import { useState, useTransition } from "react";
import { Button, Card, Modal } from "@nexus/ui";
import { generateInviteCode, setInviteCodeEnabled } from "./actions";

const INVITE_LINK_BASE = "https://nexus-jdr.app/join";
const COPY_FEEDBACK_DURATION_MS = 2000;

export function InvitePanel({
  storyId,
  inviteCode,
  inviteCodeEnabled,
}: {
  storyId: string;
  inviteCode: string | null;
  inviteCodeEnabled: boolean;
}) {
  const [code, setCode] = useState(inviteCode);
  const [enabled, setEnabled] = useState(inviteCodeEnabled);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmingRegenerate, setConfirmingRegenerate] = useState(false);
  const [isPending, startTransition] = useTransition();

  const inviteLink = code ? `${INVITE_LINK_BASE}/${code}` : null;

  function handleGenerate() {
    setError(null);
    startTransition(async () => {
      const result = await generateInviteCode(storyId);
      if (result.error) {
        setError(result.error);
        return;
      }
      setCode(result.inviteCode ?? null);
      setEnabled(true);
    });
  }

  function handleRegenerate() {
    setConfirmingRegenerate(false);
    handleGenerate();
  }

  function handleToggleEnabled() {
    setError(null);
    const nextEnabled = !enabled;
    startTransition(async () => {
      const result = await setInviteCodeEnabled(storyId, nextEnabled);
      if (result.error) {
        setError(result.error);
        return;
      }
      setEnabled(nextEnabled);
    });
  }

  async function handleCopy() {
    if (!inviteLink) return;
    try {
      await navigator.clipboard.writeText(inviteLink);
      setCopied(true);
      setTimeout(() => setCopied(false), COPY_FEEDBACK_DURATION_MS);
    } catch {
      setError("Impossible de copier le lien.");
    }
  }

  return (
    <Card className="p-4">
      <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted">
        Inviter des joueurs
      </h2>

      {!inviteLink ? (
        <div className="space-y-3">
          <p className="text-sm text-muted">
            Génère un lien d&apos;invitation à partager avec tes joueurs pour qu&apos;ils
            rattachent un personnage à cette histoire.
          </p>
          <Button type="button" onClick={handleGenerate} isLoading={isPending}>
            Générer un lien d&apos;invitation
          </Button>
        </div>
      ) : (
        <div className="space-y-3">
          <div className="flex flex-wrap items-center gap-2">
            <code className="rounded-lg border border-white/10 bg-background px-3 py-1.5 text-sm text-foreground">
              {inviteLink}
            </code>
            {!enabled ? (
              <span className="rounded-lg border border-white/20 px-2 py-0.5 text-xs text-muted">
                Désactivé
              </span>
            ) : null}
          </div>
          <div className="flex flex-wrap gap-2">
            <Button type="button" variant="ghost" onClick={handleCopy}>
              {copied ? "Copié !" : "Copier"}
            </Button>
            <Button
              type="button"
              variant="ghost"
              onClick={() => setConfirmingRegenerate(true)}
              disabled={isPending}
            >
              Régénérer
            </Button>
            <Button type="button" variant="ghost" onClick={handleToggleEnabled} isLoading={isPending}>
              {enabled ? "Désactiver" : "Réactiver"}
            </Button>
          </div>
        </div>
      )}

      <div aria-live="polite">
        {error ? (
          <p role="alert" className="mt-2 text-sm text-red-400">
            {error}
          </p>
        ) : null}
      </div>

      <Modal
        open={confirmingRegenerate}
        onClose={() => setConfirmingRegenerate(false)}
        title="Régénérer le lien d'invitation ?"
        size="md"
      >
        <div className="space-y-4">
          <p className="text-sm text-muted">
            L&apos;ancien lien cessera de fonctionner immédiatement. Les joueurs qui l&apos;ont
            déjà utilisé pour rejoindre l&apos;histoire ne sont pas affectés.
          </p>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setConfirmingRegenerate(false)}>
              Annuler
            </Button>
            <Button type="button" onClick={handleRegenerate} isLoading={isPending}>
              Régénérer
            </Button>
          </div>
        </div>
      </Modal>
    </Card>
  );
}
