"use client";

import { useActionState, useEffect, useState } from "react";
import { Button } from "@nexus/ui";
import {
  ABILITY_LABELS,
  CODEX_CATEGORIES,
  type AbilityKey,
  type CodexAttributesByCategory,
  type CodexCategory,
  type CodexEntry,
} from "@nexus/core";
import type { CodexActionState } from "./actions";

type ActionFn = (prevState: CodexActionState, formData: FormData) => Promise<CodexActionState>;

export interface CodexEntryInitialValues {
  category?: CodexCategory;
  name?: string;
  summary?: string;
  content?: string;
  attributes?: Record<string, unknown>;
}

const initialState: CodexActionState = { error: null };
const ABILITY_ORDER: AbilityKey[] = ["str", "dex", "con", "int", "wis", "cha"];

export function CodexEntryForm({
  action,
  storyId,
  entry,
  initialValues,
  submitLabel,
  pendingLabel,
  compact = false,
  onSuccess,
}: {
  action: ActionFn;
  storyId: string;
  entry?: CodexEntry;
  initialValues?: CodexEntryInitialValues;
  submitLabel: string;
  pendingLabel: string;
  compact?: boolean;
  onSuccess?: () => void;
}) {
  const seed = entry ?? initialValues;
  const [category, setCategory] = useState<CodexCategory>(seed?.category ?? "pnj");
  const [state, formAction, isPending] = useActionState(action, initialState);
  const gridClass = compact ? "grid grid-cols-1 gap-4" : "grid grid-cols-1 gap-4 sm:grid-cols-2";

  useEffect(() => {
    if (state.success) {
      onSuccess?.();
    }
    // onSuccess volontairement absent des deps : seule une nouvelle soumission (state) doit redéclencher l'effet.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state]);

  return (
    <form
      action={formAction}
      noValidate
      className="space-y-4 rounded-lg border border-white/10 bg-surface p-4"
    >
      <input type="hidden" name="storyId" value={storyId} />
      {entry ? <input type="hidden" name="entryId" value={entry.id} /> : null}

      <div className={gridClass}>
        <div className="space-y-1">
          <label htmlFor="category" className="block text-sm text-foreground">
            Catégorie
          </label>
          <select
            id="category"
            name="category"
            value={category}
            onChange={(event) => setCategory(event.target.value as CodexCategory)}
            className="w-full rounded-lg border border-white/10 bg-background px-3 py-2 text-foreground focus-visible:border-accent-cyan"
          >
            {CODEX_CATEGORIES.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>

        <TextField id="name" name="name" label="Nom" defaultValue={seed?.name} required />
      </div>

      <TextField
        id="summary"
        name="summary"
        label="Résumé (affiché dans l'infobulle)"
        defaultValue={seed?.summary}
      />

      {category === "joueur" ? (
        <PlayerFields
          attributes={(seed?.attributes ?? {}) as CodexAttributesByCategory["joueur"]}
        />
      ) : (
        <CategoryFields
          category={category}
          attributes={(seed?.attributes ?? {}) as Record<string, string>}
          gridClass={gridClass}
        />
      )}

      <div className="space-y-1">
        <label htmlFor="content" className="block text-sm text-foreground">
          Notes complètes (Markdown)
        </label>
        <textarea
          id="content"
          name="content"
          rows={compact ? 4 : 6}
          defaultValue={seed?.content}
          className="w-full rounded-lg border border-white/10 bg-background p-3 font-mono text-sm text-foreground focus-visible:border-accent-cyan"
        />
      </div>

      <div aria-live="polite">
        {state.error ? (
          <p role="alert" className="text-sm text-red-400">
            {state.error}
          </p>
        ) : null}
      </div>

      <Button type="submit" isLoading={isPending}>
        {isPending ? pendingLabel : submitLabel}
      </Button>
    </form>
  );
}

const PLAYER_FORM_TABS = [
  { key: "info", label: "Info globale" },
  { key: "identity", label: "Identité / Apparence" },
  { key: "personality", label: "Personnalité" },
  { key: "background", label: "Historique" },
  { key: "equipment", label: "Sorts & équipement" },
] as const;

type PlayerTabKey = (typeof PLAYER_FORM_TABS)[number]["key"];

function PlayerFields({ attributes }: { attributes: CodexAttributesByCategory["joueur"] }) {
  const [tab, setTab] = useState<PlayerTabKey>("info");

  return (
    <div className="space-y-3">
      <div
        role="tablist"
        aria-label="Sections de la fiche Joueur"
        className="flex flex-wrap gap-1 border-b border-white/10 pb-1"
      >
        {PLAYER_FORM_TABS.map((t) => (
          <button
            key={t.key}
            type="button"
            role="tab"
            aria-selected={tab === t.key}
            onClick={() => setTab(t.key)}
            className={`rounded-t-lg px-2 py-1 text-xs ${
              tab === t.key
                ? "bg-accent-violet text-white"
                : "text-muted hover:bg-background hover:text-foreground"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Chaque section reste montée (hidden plutôt que démontée) : les champs sont non
          contrôlés (defaultValue), un démontage perdrait la saisie en changeant d'onglet. */}
      <div hidden={tab !== "info"} className="space-y-4">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <TextField
            id="player_playerName"
            name="player_playerName"
            label="Nom du joueur"
            defaultValue={attributes.playerName}
          />
          <TextField
            id="player_race"
            name="player_race"
            label="Race"
            defaultValue={attributes.race}
          />
          <TextField
            id="player_class"
            name="player_class"
            label="Classe"
            defaultValue={attributes.characterClass}
          />
          <TextField
            id="player_classPath"
            name="player_classPath"
            label="Voie / Sous-classe"
            defaultValue={attributes.classPath}
          />
          <TextField
            id="player_level"
            name="player_level"
            label="Niveau"
            defaultValue={attributes.level}
          />
        </div>

        <div>
          <p className="mb-1 block text-sm text-foreground">Caractéristiques</p>
          <div className="grid grid-cols-3 gap-3 sm:grid-cols-6">
            {ABILITY_ORDER.map((key) => (
              <TextField
                key={key}
                id={`player_ability_${key}`}
                name={`player_ability_${key}`}
                label={ABILITY_LABELS[key]}
                defaultValue={attributes.abilities?.[key]}
              />
            ))}
          </div>
        </div>
      </div>

      <div hidden={tab !== "identity"} className="space-y-4">
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
          <TextField
            id="player_age"
            name="player_age"
            label="Âge"
            defaultValue={attributes.identity?.age}
          />
          <TextField
            id="player_height"
            name="player_height"
            label="Taille"
            defaultValue={attributes.identity?.height}
          />
          <TextField
            id="player_weight"
            name="player_weight"
            label="Poids"
            defaultValue={attributes.identity?.weight}
          />
          <TextField
            id="player_eyes"
            name="player_eyes"
            label="Yeux"
            defaultValue={attributes.identity?.eyes}
          />
          <TextField
            id="player_skin"
            name="player_skin"
            label="Peau"
            defaultValue={attributes.identity?.skin}
          />
          <TextField
            id="player_hair"
            name="player_hair"
            label="Cheveux"
            defaultValue={attributes.identity?.hair}
          />
        </div>
        <TextAreaField
          id="player_appearance"
          name="player_appearance"
          label="Apparence"
          defaultValue={attributes.identity?.appearance}
          rows={5}
        />
      </div>

      <div hidden={tab !== "personality"} className="space-y-4">
        <TextAreaField
          id="player_traits"
          name="player_traits"
          label="Traits de personnalité"
          defaultValue={attributes.personality?.traits}
        />
        <TextAreaField
          id="player_ideals"
          name="player_ideals"
          label="Idéaux"
          defaultValue={attributes.personality?.ideals}
        />
        <TextAreaField
          id="player_bonds"
          name="player_bonds"
          label="Liens"
          defaultValue={attributes.personality?.bonds}
        />
        <TextAreaField
          id="player_flaws"
          name="player_flaws"
          label="Défauts"
          defaultValue={attributes.personality?.flaws}
        />
      </div>

      <div hidden={tab !== "background"} className="space-y-4">
        <TextAreaField
          id="player_backstory"
          name="player_backstory"
          label="Historique"
          defaultValue={attributes.background?.backstory}
          rows={6}
        />
        <TextAreaField
          id="player_allies"
          name="player_allies"
          label="Alliés"
          defaultValue={attributes.background?.allies}
        />
        <TextAreaField
          id="player_features"
          name="player_features"
          label="Particularités"
          defaultValue={attributes.background?.features}
        />
      </div>

      <div hidden={tab !== "equipment"} className="space-y-4">
        <TextAreaField
          id="player_languages"
          name="player_languages"
          label="Langues (une par ligne)"
          defaultValue={attributes.equipment?.languages?.join("\n")}
          rows={3}
        />
        <TextAreaField
          id="player_spells"
          name="player_spells"
          label="Sorts & invocations (un par ligne)"
          defaultValue={attributes.equipment?.spells?.join("\n")}
          rows={5}
        />
        <TextAreaField
          id="player_items"
          name="player_items"
          label="Objets (un par ligne)"
          defaultValue={attributes.equipment?.items?.join("\n")}
          rows={4}
        />
      </div>
    </div>
  );
}

function CategoryFields({
  category,
  attributes,
  gridClass,
}: {
  category: Exclude<CodexCategory, "joueur">;
  attributes: Record<string, string>;
  gridClass: string;
}) {
  switch (category) {
    case "pnj":
      return (
        <div className={gridClass}>
          <TextField id="attr_role" name="attr_role" label="Rôle" defaultValue={attributes.role} />
          <TextAreaField
            id="attr_stats"
            name="attr_stats"
            label="Stats"
            defaultValue={attributes.stats}
          />
        </div>
      );
    case "bestiaire":
      return (
        <div className={gridClass}>
          <TextField
            id="attr_dangerLevel"
            name="attr_dangerLevel"
            label="Niveau de danger"
            defaultValue={attributes.dangerLevel}
          />
          <TextAreaField
            id="attr_stats"
            name="attr_stats"
            label="Stats"
            defaultValue={attributes.stats}
          />
        </div>
      );
    case "lieu":
      return (
        <div className={gridClass}>
          <TextField
            id="attr_region"
            name="attr_region"
            label="Région"
            defaultValue={attributes.region}
          />
          <TextField
            id="attr_locationType"
            name="attr_locationType"
            label="Type de lieu"
            defaultValue={attributes.locationType}
          />
        </div>
      );
    case "autre":
      return null;
  }
}

function TextField({
  id,
  name,
  label,
  defaultValue,
  required,
}: {
  id: string;
  name: string;
  label: string;
  defaultValue?: string;
  required?: boolean;
}) {
  return (
    <div className="space-y-1">
      <label htmlFor={id} className="block text-sm text-foreground">
        {label}
      </label>
      <input
        id={id}
        name={name}
        type="text"
        required={required}
        defaultValue={defaultValue}
        className="w-full rounded-lg border border-white/10 bg-background px-3 py-2 text-foreground focus-visible:border-accent-cyan"
      />
    </div>
  );
}

function TextAreaField({
  id,
  name,
  label,
  defaultValue,
  rows = 3,
}: {
  id: string;
  name: string;
  label: string;
  defaultValue?: string;
  rows?: number;
}) {
  return (
    <div className="space-y-1">
      <label htmlFor={id} className="block text-sm text-foreground">
        {label}
      </label>
      <textarea
        id={id}
        name={name}
        rows={rows}
        defaultValue={defaultValue}
        className="w-full rounded-lg border border-white/10 bg-background p-2 text-sm text-foreground focus-visible:border-accent-cyan"
      />
    </div>
  );
}
