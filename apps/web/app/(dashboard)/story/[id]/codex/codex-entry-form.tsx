"use client";

import { useActionState, useEffect, useRef, useState } from "react";
import { Button, MarkdownToolbar, Open5eReferenceButton, Open5eSearchCombobox } from "@nexus/ui";
import {
  ABILITY_LABELS,
  CODEX_CATEGORIES,
  getOpen5eDetail,
  listAllOpen5e,
  type AbilityKey,
  type CodexAttributesByCategory,
  type CodexCategory,
  type CodexEntry,
  type CodexEquipmentItem,
  type CodexOpen5eRef,
  type Open5eClassSummary,
  type Open5eCreatureDetail,
  type Open5eCreatureSummary,
  type Open5eItemSummary,
  type Open5eKind,
  type Open5eSearchResult,
  type Open5eSpeciesSummary,
  type Open5eSpellSummary,
} from "@nexus/core";
import { uploadContentImage } from "../actions";
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
  const [name, setName] = useState(seed?.name ?? "");
  const [summary, setSummary] = useState(seed?.summary ?? "");
  const [content, setContent] = useState(seed?.content ?? "");
  const contentTextareaRef = useRef<HTMLTextAreaElement>(null);
  const [state, formAction, isPending] = useActionState(action, initialState);
  const gridClass = compact ? "grid grid-cols-1 gap-4" : "grid grid-cols-1 gap-4 sm:grid-cols-2";

  useEffect(() => {
    if (state.success) {
      onSuccess?.();
    }
    // onSuccess volontairement absent des deps : seule une nouvelle soumission (state) doit redéclencher l'effet.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state]);

  async function handleUploadImage(file: File) {
    const formData = new FormData();
    formData.set("storyId", storyId);
    formData.set("file", file);
    const result = await uploadContentImage(formData);
    if ("error" in result) throw new Error(result.error);
    return result.url;
  }

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

        <TextField id="name" name="name" label="Nom" value={name} onChange={setName} required />
      </div>

      <TextField
        id="summary"
        name="summary"
        label="Résumé (affiché dans l'infobulle)"
        value={summary}
        onChange={setSummary}
      />

      {category === "joueur" ? (
        <PlayerFields
          attributes={(seed?.attributes ?? {}) as CodexAttributesByCategory["joueur"]}
        />
      ) : (
        <CategoryFields
          category={category}
          attributes={(seed?.attributes ?? {}) as Record<string, string>}
          open5eRef={(seed?.attributes as { open5eRef?: CodexOpen5eRef } | undefined)?.open5eRef}
          gridClass={gridClass}
          onNameChange={setName}
          onSummaryChange={setSummary}
        />
      )}

      <div className="space-y-1">
        <label htmlFor="content" className="block text-sm text-foreground">
          Notes complètes (Markdown)
        </label>
        <MarkdownToolbar
          textareaRef={contentTextareaRef}
          value={content}
          onChange={setContent}
          onUploadImage={handleUploadImage}
        />
        <textarea
          ref={contentTextareaRef}
          id="content"
          name="content"
          rows={compact ? 4 : 6}
          value={content}
          onChange={(event) => setContent(event.target.value)}
          className="w-full rounded-b-lg rounded-t-none border border-white/10 bg-background p-3 font-mono text-sm text-foreground focus-visible:border-accent-cyan"
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

function filterByName<T extends { name: string }>(list: T[], query: string): T[] {
  const trimmed = query.trim().toLowerCase();
  if (!trimmed) return [];
  return list.filter((entry) => entry.name.toLowerCase().includes(trimmed)).slice(0, 8);
}

function Open5eAssistedField<T extends Open5eSearchResult>({
  id,
  name,
  label,
  value,
  onChange,
  kind,
  fetchResults,
}: {
  id: string;
  name: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  kind: Open5eKind;
  fetchResults: (query: string) => Promise<T[]>;
}) {
  return (
    <div className="space-y-1">
      <label htmlFor={id} className="block text-sm text-foreground">
        {label}
      </label>
      <Open5eSearchCombobox<T>
        id={id}
        name={name}
        kind={kind}
        placeholder={label}
        value={value}
        onValueChange={onChange}
        fetchResults={fetchResults}
        onSelect={(result) => onChange(result.name)}
      />
    </div>
  );
}

function PlayerFields({ attributes }: { attributes: CodexAttributesByCategory["joueur"] }) {
  const [tab, setTab] = useState<PlayerTabKey>("info");
  const [race, setRace] = useState(attributes.race ?? "");
  const [characterClass, setCharacterClass] = useState(attributes.characterClass ?? "");
  const [classPath, setClassPath] = useState(attributes.classPath ?? "");
  const [speciesList, setSpeciesList] = useState<Open5eSpeciesSummary[]>([]);
  const [classList, setClassList] = useState<Open5eClassSummary[]>([]);

  // Le filtre `name__icontains` d'Open5e est silencieusement ignoré sur ces deux endpoints
  // (classes/species) : on récupère la liste complète une fois puis on filtre côté client.
  useEffect(() => {
    listAllOpen5e<Open5eSpeciesSummary>("species")
      .then(setSpeciesList)
      .catch(() => setSpeciesList([]));
    listAllOpen5e<Open5eClassSummary>("classes")
      .then(setClassList)
      .catch(() => setClassList([]));
  }, []);

  async function fetchSpecies(query: string) {
    return filterByName(speciesList, query);
  }

  async function fetchBaseClasses(query: string) {
    return filterByName(
      classList.filter((entry) => !entry.subclass_of),
      query,
    );
  }

  async function fetchSubclasses(query: string) {
    return filterByName(
      classList.filter((entry) => entry.subclass_of),
      query,
    );
  }

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
          <Open5eAssistedField<Open5eSpeciesSummary>
            id="player_race"
            name="player_race"
            label="Race"
            value={race}
            onChange={setRace}
            kind="species"
            fetchResults={fetchSpecies}
          />
          <Open5eAssistedField<Open5eClassSummary>
            id="player_class"
            name="player_class"
            label="Classe"
            value={characterClass}
            onChange={setCharacterClass}
            kind="classes"
            fetchResults={fetchBaseClasses}
          />
          <Open5eAssistedField<Open5eClassSummary>
            id="player_classPath"
            name="player_classPath"
            label="Voie / Sous-classe"
            value={classPath}
            onChange={setClassPath}
            kind="classes"
            fetchResults={fetchSubclasses}
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
        <EquipmentListEditor
          fieldNamePrefix="player_spells"
          label="Sorts & invocations"
          kind="spells"
          initialItems={attributes.equipment?.spells}
        />
        <EquipmentListEditor
          fieldNamePrefix="player_items"
          label="Objets"
          kind="magicitems"
          initialItems={attributes.equipment?.items}
        />
      </div>
    </div>
  );
}

function CategoryFields({
  category,
  attributes,
  open5eRef,
  gridClass,
  onNameChange,
  onSummaryChange,
}: {
  category: Exclude<CodexCategory, "joueur">;
  attributes: Record<string, string>;
  open5eRef?: CodexOpen5eRef;
  gridClass: string;
  onNameChange: (value: string) => void;
  onSummaryChange: (value: string) => void;
}) {
  switch (category) {
    case "pnj":
      return (
        <CreatureLinkedFields
          primaryFieldName="attr_role"
          primaryFieldLabel="Rôle"
          primaryDefault={attributes.role}
          statsDefault={attributes.stats}
          open5eRefDefault={open5eRef}
          gridClass={gridClass}
          onNameChange={onNameChange}
          onSummaryChange={onSummaryChange}
        />
      );
    case "bestiaire":
      return (
        <CreatureLinkedFields
          primaryFieldName="attr_dangerLevel"
          primaryFieldLabel="Niveau de danger"
          primaryDefault={attributes.dangerLevel}
          statsDefault={attributes.stats}
          open5eRefDefault={open5eRef}
          gridClass={gridClass}
          onNameChange={onNameChange}
          onSummaryChange={onSummaryChange}
        />
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

function nameOfRef(value: { name: string } | string | undefined): string | undefined {
  return typeof value === "string" ? value : value?.name;
}

function CreatureLinkedFields({
  primaryFieldName,
  primaryFieldLabel,
  primaryDefault,
  statsDefault,
  open5eRefDefault,
  gridClass,
  onNameChange,
  onSummaryChange,
}: {
  primaryFieldName: string;
  primaryFieldLabel: string;
  primaryDefault?: string;
  statsDefault?: string;
  open5eRefDefault?: CodexOpen5eRef;
  gridClass: string;
  onNameChange: (value: string) => void;
  onSummaryChange: (value: string) => void;
}) {
  const [primaryValue, setPrimaryValue] = useState(primaryDefault ?? "");
  const [statsValue, setStatsValue] = useState(statsDefault ?? "");
  const [open5eRef, setOpen5eRef] = useState<CodexOpen5eRef | undefined>(open5eRefDefault);
  const [loadingDetail, setLoadingDetail] = useState(false);

  async function handleSelect(result: Open5eCreatureSummary) {
    const type = nameOfRef(result.type);
    const size = nameOfRef(result.size);
    const crLabel = result.challenge_rating !== undefined ? `FP ${result.challenge_rating}` : null;

    // Pré-remplissage immédiat avec les données déjà disponibles dans le résultat de recherche.
    onNameChange(result.name);
    onSummaryChange([size, type, crLabel].filter(Boolean).join(" · "));
    setPrimaryValue([type, crLabel].filter(Boolean).join(" — "));
    setStatsValue(
      [
        result.armor_class !== undefined ? `CA ${result.armor_class}` : null,
        result.hit_points !== undefined ? `PV ${result.hit_points}` : null,
      ]
        .filter(Boolean)
        .join(" · "),
    );
    setOpen5eRef({ kind: "creatures", key: result.key });

    // Puis on enrichit avec le détail complet (vitesse, caractéristiques, perception...).
    setLoadingDetail(true);
    try {
      const detail = await getOpen5eDetail<Open5eCreatureDetail>("creatures", result.key);
      const abilityLine = detail.ability_scores
        ? Object.entries(detail.ability_scores)
            .map(([key, value]) => `${key.slice(0, 3).toUpperCase()} ${value}`)
            .join(" · ")
        : null;
      const speedLine = detail.speed
        ? Object.entries(detail.speed)
            .filter(([, value]) => typeof value === "number" && value > 0)
            .map(([key, value]) => `${key} ${value}ft`)
            .join(", ")
        : null;

      setStatsValue(
        [
          detail.armor_class !== undefined ? `CA ${detail.armor_class}` : null,
          detail.hit_points !== undefined ? `PV ${detail.hit_points}` : null,
          speedLine ? `Vitesse : ${speedLine}` : null,
          abilityLine,
          detail.passive_perception !== undefined
            ? `Perception passive ${detail.passive_perception}`
            : null,
        ]
          .filter(Boolean)
          .join("\n"),
      );
    } catch {
      // Le résumé de recherche a déjà été appliqué ci-dessus : on garde ça plutôt que d'échouer.
    } finally {
      setLoadingDetail(false);
    }
  }

  return (
    <div className="space-y-3">
      <div className="space-y-1">
        <label className="block text-sm text-foreground">Rechercher sur Open5e (optionnel)</label>
        <Open5eSearchCombobox<Open5eCreatureSummary> kind="creatures" onSelect={handleSelect} />
        {loadingDetail ? <p className="text-xs text-muted">Récupération des détails…</p> : null}
      </div>

      {open5eRef ? (
        <div className="flex items-center gap-2 text-xs text-muted">
          <input type="hidden" name="attr_open5eKey" value={open5eRef.key} />
          <input type="hidden" name="attr_open5eKind" value={open5eRef.kind} />
          Lié à Open5e —{" "}
          <Open5eReferenceButton kind={open5eRef.kind} entryKey={open5eRef.key} label="Voir le détail" />
        </div>
      ) : null}

      <div className={gridClass}>
        <div className="space-y-1">
          <label htmlFor="attr-primary-field" className="block text-sm text-foreground">
            {primaryFieldLabel}
          </label>
          <input
            id="attr-primary-field"
            name={primaryFieldName}
            type="text"
            value={primaryValue}
            onChange={(event) => setPrimaryValue(event.target.value)}
            className="w-full rounded-lg border border-white/10 bg-background px-3 py-2 text-foreground focus-visible:border-accent-cyan"
          />
        </div>
        <div className="space-y-1">
          <label htmlFor="attr_stats" className="block text-sm text-foreground">
            Stats
          </label>
          <textarea
            id="attr_stats"
            name="attr_stats"
            rows={3}
            value={statsValue}
            onChange={(event) => setStatsValue(event.target.value)}
            className="w-full rounded-lg border border-white/10 bg-background p-2 text-sm text-foreground focus-visible:border-accent-cyan"
          />
        </div>
      </div>
    </div>
  );
}

function EquipmentListEditor({
  fieldNamePrefix,
  label,
  kind,
  initialItems,
}: {
  fieldNamePrefix: string;
  label: string;
  kind: "spells" | "magicitems";
  initialItems?: CodexEquipmentItem[];
}) {
  const [items, setItems] = useState<CodexEquipmentItem[]>(initialItems ?? []);
  const [manualName, setManualName] = useState("");

  function addItem(item: CodexEquipmentItem) {
    setItems((previous) => [...previous, item]);
  }

  function addManual() {
    const trimmed = manualName.trim();
    if (!trimmed) return;
    addItem({ name: trimmed });
    setManualName("");
  }

  function removeItem(index: number) {
    setItems((previous) => previous.filter((_, current) => current !== index));
  }

  return (
    <div className="space-y-2">
      <label className="block text-sm text-foreground">{label}</label>

      <Open5eSearchCombobox<Open5eSpellSummary | Open5eItemSummary>
        kind={kind}
        placeholder={`Rechercher ${label.toLowerCase()} sur Open5e…`}
        onSelect={(result) => addItem({ name: result.name, open5eRef: { kind, key: result.key } })}
      />

      <div className="flex gap-2">
        <input
          type="text"
          value={manualName}
          onChange={(event) => setManualName(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              addManual();
            }
          }}
          placeholder="Ou ajouter un nom libre…"
          className="flex-1 rounded-lg border border-white/10 bg-background px-2 py-1.5 text-xs text-foreground focus-visible:border-accent-cyan"
        />
        <button
          type="button"
          onClick={addManual}
          className="rounded-lg bg-surface px-2 py-1 text-xs text-foreground hover:bg-white/10"
        >
          Ajouter
        </button>
      </div>

      <input type="hidden" name={`${fieldNamePrefix}_json`} value={JSON.stringify(items)} />

      {items.length > 0 ? (
        <ul className="flex flex-wrap gap-1.5">
          {items.map((item, index) => (
            <li
              key={`${item.name}-${index}`}
              className="flex items-center gap-1 rounded-full border border-white/10 bg-background px-2 py-0.5 text-xs text-foreground"
            >
              {item.name}
              <button
                type="button"
                onClick={() => removeItem(index)}
                aria-label={`Retirer ${item.name}`}
                className="text-muted hover:text-red-400"
              >
                ✕
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

function TextField({
  id,
  name,
  label,
  defaultValue,
  value,
  onChange,
  required,
}: {
  id: string;
  name: string;
  label: string;
  defaultValue?: string;
  value?: string;
  onChange?: (value: string) => void;
  required?: boolean;
}) {
  const controlledProps =
    value !== undefined ? { value, onChange: (e: React.ChangeEvent<HTMLInputElement>) => onChange?.(e.target.value) } : { defaultValue };

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
        {...controlledProps}
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
