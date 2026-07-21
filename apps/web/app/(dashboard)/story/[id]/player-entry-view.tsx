"use client";

import { useState } from "react";
import { MarkdownContent, type CodexEntrySummary } from "@nexus/ui";
import {
  ABILITY_LABELS,
  type AbilityKey,
  type CodexAttributesByCategory,
  type CodexEntry,
} from "@nexus/core";

const ABILITY_ORDER: AbilityKey[] = ["str", "dex", "con", "int", "wis", "cha"];

const TABS = [
  { key: "info", label: "Info globale" },
  { key: "identity", label: "Identité / Apparence" },
  { key: "personality", label: "Personnalité" },
  { key: "background", label: "Historique" },
  { key: "equipment", label: "Sorts & équipement" },
  { key: "notes", label: "Notes" },
] as const;

type TabKey = (typeof TABS)[number]["key"];
type PlayerAttributes = CodexAttributesByCategory["joueur"];

function hasValues(obj: Record<string, unknown> | undefined): boolean {
  return Boolean(obj && Object.values(obj).some((value) => (Array.isArray(value) ? value.length > 0 : value)));
}

export function PlayerEntryView({
  entry,
  codexEntries,
}: {
  entry: CodexEntry;
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  const attributes = (entry.attributes ?? {}) as PlayerAttributes;
  const [activeTab, setActiveTab] = useState<TabKey | null>(null);

  const availability: Record<TabKey, boolean> = {
    info: Boolean(
      attributes.race || attributes.characterClass || attributes.level || hasValues(attributes.abilities),
    ),
    identity: hasValues(attributes.identity),
    personality: hasValues(attributes.personality),
    background: hasValues(attributes.background),
    equipment: hasValues(attributes.equipment),
    notes: Boolean(entry.content),
  };

  const availableTabs = TABS.filter((tab) => availability[tab.key]);
  const effectiveTab = availableTabs.some((tab) => tab.key === activeTab)
    ? (activeTab as TabKey)
    : (availableTabs[0]?.key ?? null);

  return (
    <div className="space-y-3 rounded-lg border border-white/10 bg-surface p-4">
      <div>
        <h3 className="text-base font-semibold text-foreground">{entry.name}</h3>
        {entry.summary ? <p className="mt-1 text-xs text-muted">{entry.summary}</p> : null}
        {attributes.playerName ? (
          <p className="text-xs text-muted">Joué par : {attributes.playerName}</p>
        ) : null}
      </div>

      {availableTabs.length === 0 ? (
        <p className="text-xs text-muted">Aucune information pour l&apos;instant.</p>
      ) : (
        <>
          <div
            role="tablist"
            aria-label="Sections de la fiche"
            className="flex flex-wrap gap-1 border-b border-white/10 pb-1"
          >
            {availableTabs.map((tab) => (
              <button
                key={tab.key}
                type="button"
                role="tab"
                aria-selected={effectiveTab === tab.key}
                onClick={() => setActiveTab(tab.key)}
                className={`rounded-t-lg px-2.5 py-1.5 text-xs ${
                  effectiveTab === tab.key
                    ? "bg-accent-violet text-white"
                    : "text-muted hover:bg-background hover:text-foreground"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div role="tabpanel">
            {effectiveTab === "info" ? <InfoTab attributes={attributes} /> : null}
            {effectiveTab === "identity" ? (
              <IdentityTab identity={attributes.identity} codexEntries={codexEntries} />
            ) : null}
            {effectiveTab === "personality" ? (
              <PersonalityTab personality={attributes.personality} codexEntries={codexEntries} />
            ) : null}
            {effectiveTab === "background" ? (
              <BackgroundTab background={attributes.background} codexEntries={codexEntries} />
            ) : null}
            {effectiveTab === "equipment" ? <EquipmentTab equipment={attributes.equipment} /> : null}
            {effectiveTab === "notes" ? (
              <div className="prose prose-invert prose-sm max-w-none">
                <MarkdownContent content={entry.content} codexEntries={codexEntries} />
              </div>
            ) : null}
          </div>
        </>
      )}
    </div>
  );
}

function InfoTab({ attributes }: { attributes: PlayerAttributes }) {
  const classLine = [attributes.race, attributes.characterClass, attributes.classPath ? `(${attributes.classPath})` : null]
    .filter(Boolean)
    .join(" ");

  return (
    <div className="space-y-4">
      {classLine || attributes.level ? (
        <p className="text-sm text-foreground">
          {classLine}
          {attributes.level ? ` — Niveau ${attributes.level}` : null}
        </p>
      ) : null}

      {hasValues(attributes.abilities) ? (
        <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
          {ABILITY_ORDER.map((key) => {
            const value = attributes.abilities?.[key];
            if (!value) return null;
            return (
              <div
                key={key}
                className="rounded-lg border border-white/10 bg-background p-2 text-center"
              >
                <div className="text-[10px] uppercase tracking-wide text-muted">
                  {ABILITY_LABELS[key]}
                </div>
                <div className="text-lg font-semibold text-foreground">{value}</div>
              </div>
            );
          })}
        </div>
      ) : null}
    </div>
  );
}

function IdentityTab({
  identity,
  codexEntries,
}: {
  identity?: PlayerAttributes["identity"];
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  if (!identity) return null;

  const fields: [string, string | undefined][] = [
    ["Âge", identity.age],
    ["Taille", identity.height],
    ["Poids", identity.weight],
    ["Yeux", identity.eyes],
    ["Peau", identity.skin],
    ["Cheveux", identity.hair],
  ];
  const visibleFields = fields.filter(([, value]) => value);

  return (
    <div className="space-y-4">
      {visibleFields.length > 0 ? (
        <dl className="grid grid-cols-2 gap-3 text-xs sm:grid-cols-3">
          {visibleFields.map(([label, value]) => (
            <div key={label}>
              <dt className="text-muted">{label}</dt>
              <dd className="text-foreground">{value}</dd>
            </div>
          ))}
        </dl>
      ) : null}
      {identity.appearance ? (
        <div className="prose prose-invert prose-sm max-w-none">
          <MarkdownContent content={identity.appearance} codexEntries={codexEntries} />
        </div>
      ) : null}
    </div>
  );
}

function PersonalityTab({
  personality,
  codexEntries,
}: {
  personality?: PlayerAttributes["personality"];
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  if (!personality) return null;

  const fields: [string, string | undefined][] = [
    ["Traits de personnalité", personality.traits],
    ["Idéaux", personality.ideals],
    ["Liens", personality.bonds],
    ["Défauts", personality.flaws],
  ];

  return (
    <div className="space-y-4">
      {fields.map(([label, value]) =>
        value ? (
          <div key={label}>
            <h4 className="text-xs font-semibold uppercase tracking-wide text-muted">{label}</h4>
            <div className="prose prose-invert prose-sm max-w-none">
              <MarkdownContent content={value} codexEntries={codexEntries} />
            </div>
          </div>
        ) : null,
      )}
    </div>
  );
}

function BackgroundTab({
  background,
  codexEntries,
}: {
  background?: PlayerAttributes["background"];
  codexEntries?: Record<string, CodexEntrySummary>;
}) {
  if (!background) return null;

  const fields: [string, string | undefined][] = [
    ["Historique", background.backstory],
    ["Alliés", background.allies],
    ["Particularités", background.features],
  ];

  return (
    <div className="space-y-4">
      {fields.map(([label, value]) =>
        value ? (
          <div key={label}>
            <h4 className="text-xs font-semibold uppercase tracking-wide text-muted">{label}</h4>
            <div className="prose prose-invert prose-sm max-w-none">
              <MarkdownContent content={value} codexEntries={codexEntries} />
            </div>
          </div>
        ) : null,
      )}
    </div>
  );
}

function EquipmentTab({ equipment }: { equipment?: PlayerAttributes["equipment"] }) {
  if (!equipment) return null;

  const groups: [string, string[] | undefined][] = [
    ["Langues", equipment.languages],
    ["Sorts & invocations", equipment.spells],
    ["Objets", equipment.items],
  ];

  return (
    <div className="space-y-4">
      {groups.map(([label, items]) =>
        items && items.length > 0 ? (
          <div key={label}>
            <h4 className="text-xs font-semibold uppercase tracking-wide text-muted">{label}</h4>
            {/* Chaque élément est déjà isolé dans sa propre <li> : point d'accroche naturel
                pour un futur lien vers une fiche Codex correspondante (via API). */}
            <ul className="mt-1 flex flex-wrap gap-1.5">
              {items.map((item) => (
                <li
                  key={item}
                  className="rounded-full border border-white/10 bg-background px-2 py-0.5 text-xs text-foreground"
                >
                  {item}
                </li>
              ))}
            </ul>
          </div>
        ) : null,
      )}
    </div>
  );
}
