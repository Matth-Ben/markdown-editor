"use client";

import Image from "next/image";
import { useState, useTransition } from "react";
import { Button, Card, Modal } from "@nexus/ui";
import { removePlayer } from "./actions";

export interface PlayerRow {
  campaignId: string;
  characterId: string;
  name: string;
  portraitUrl: string | null;
  raceLabel: string;
  classLabel: string;
  level: number | null;
}

function PlayerAvatar({ name, portraitUrl }: { name: string; portraitUrl: string | null }) {
  if (portraitUrl) {
    return (
      <div className="relative h-12 w-12 shrink-0 overflow-hidden rounded-full border border-white/10 bg-background">
        <Image src={portraitUrl} alt="" fill sizes="48px" className="object-cover" />
      </div>
    );
  }

  return (
    <div
      role="img"
      aria-label={`Portrait de ${name}`}
      className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-white/10 bg-background text-muted"
    >
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        aria-hidden="true"
        className="h-6 w-6"
      >
        <circle cx="12" cy="8" r="3.5" />
        <path d="M4.5 19.5c1.5-3.5 4.5-5.5 7.5-5.5s6 2 7.5 5.5" strokeLinecap="round" />
      </svg>
    </div>
  );
}

function summaryLine(player: PlayerRow): string {
  return player.level !== null
    ? `${player.raceLabel} — ${player.classLabel} niveau ${player.level}`
    : `${player.raceLabel} — ${player.classLabel}`;
}

export function JoueursView({
  storyId,
  players: initialPlayers,
}: {
  storyId: string;
  players: PlayerRow[];
}) {
  const [players, setPlayers] = useState(initialPlayers);
  const [playerToRemove, setPlayerToRemove] = useState<PlayerRow | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function handleRemove() {
    if (!playerToRemove) return;
    const campaignId = playerToRemove.campaignId;
    setError(null);
    startTransition(async () => {
      const result = await removePlayer(campaignId, storyId);
      if (result.error) {
        setError(result.error);
        return;
      }
      setPlayers((current) => current.filter((player) => player.campaignId !== campaignId));
      setPlayerToRemove(null);
    });
  }

  return (
    <Card className="p-4">
      <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-muted">
        Joueurs rattachés
      </h2>

      {error ? (
        <p role="alert" className="mb-3 text-sm text-red-400">
          {error}
        </p>
      ) : null}

      {players.length === 0 ? (
        <p className="text-sm text-muted">
          Aucun joueur n&apos;a encore rejoint cette histoire. Partage le lien d&apos;invitation
          ci-dessus pour que tes joueurs rattachent un personnage.
        </p>
      ) : (
        <ul className="divide-y divide-white/10">
          {players.map((player) => (
            <li key={player.campaignId} className="flex items-center gap-3 py-3">
              <PlayerAvatar name={player.name} portraitUrl={player.portraitUrl} />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-foreground">{player.name}</p>
                <p className="truncate text-xs text-muted">{summaryLine(player)}</p>
              </div>
              <Button type="button" variant="ghost" onClick={() => setPlayerToRemove(player)}>
                Retirer
              </Button>
            </li>
          ))}
        </ul>
      )}

      <Modal
        open={playerToRemove !== null}
        onClose={() => setPlayerToRemove(null)}
        title="Retirer ce joueur ?"
        size="md"
      >
        <div className="space-y-4">
          <p className="text-sm text-muted">
            {playerToRemove?.name} ne sera plus rattaché à cette histoire. Son personnage et son
            historique restent intacts — il pourra rejoindre à nouveau via un lien
            d&apos;invitation.
          </p>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={() => setPlayerToRemove(null)}>
              Annuler
            </Button>
            <Button type="button" onClick={handleRemove} isLoading={isPending}>
              Retirer
            </Button>
          </div>
        </div>
      </Modal>
    </Card>
  );
}
