export interface AmbianceTriggerButtonProps {
  ambianceType?: string | null;
  volume?: number;
  loop?: boolean;
  light?: string | null;
  description?: string;
  invalid?: boolean;
}

// TODO: câbler onClick vers TriggerService (packages/core/src/triggers) une fois
// l'appairage Hue et la config audio locale disponibles (écran Paramètres).
export function AmbianceTriggerButton({
  ambianceType,
  description,
  invalid,
}: AmbianceTriggerButtonProps) {
  if (invalid || !ambianceType) {
    return (
      <p
        role="alert"
        className="my-2 rounded-lg border border-red-400/40 bg-red-950/30 px-3 py-2 text-sm text-red-300"
      >
        Bloc ambiance invalide : l&apos;attribut « type » est manquant.
      </p>
    );
  }

  return (
    <button
      type="button"
      aria-label={`Déclencher l'ambiance ${ambianceType}`}
      className="my-2 block w-full rounded-lg border border-accent-violet/40 bg-transparent px-3 py-2 text-left transition-colors hover:bg-surface"
    >
      <span className="block text-sm text-foreground">🎧 {ambianceType}</span>
      {description ? <span className="block text-xs text-muted">{description}</span> : null}
    </button>
  );
}
