import type { Tables } from "@nexus/supabase-client";
import type { Open5eKind } from "../open5e/types";

export type Story = Tables<"stories">;

/** Référence vers une ressource Open5e (résolue à la demande, jamais copiée en dur). */
export interface CodexOpen5eRef {
  kind: Open5eKind;
  key: string;
}

export interface CodexEquipmentItem {
  name: string;
  open5eRef?: CodexOpen5eRef;
}

export type CodexCategory = "pnj" | "bestiaire" | "joueur" | "lieu" | "autre";

export type CodexEntry = Omit<Tables<"codex_entries">, "category"> & {
  category: CodexCategory;
};

export const CODEX_CATEGORIES: { value: CodexCategory; label: string }[] = [
  { value: "pnj", label: "PNJ" },
  { value: "bestiaire", label: "Bestiaire" },
  { value: "joueur", label: "Joueur" },
  { value: "lieu", label: "Lieu" },
  { value: "autre", label: "Autre" },
];

export interface CodexAttributesByCategory {
  pnj: { role?: string; stats?: string; open5eRef?: CodexOpen5eRef };
  bestiaire: { dangerLevel?: string; stats?: string; open5eRef?: CodexOpen5eRef };
  joueur: {
    playerName?: string;
    race?: string;
    characterClass?: string;
    classPath?: string;
    level?: string;
    abilities?: {
      str?: string;
      dex?: string;
      con?: string;
      int?: string;
      wis?: string;
      cha?: string;
    };
    identity?: {
      age?: string;
      height?: string;
      weight?: string;
      eyes?: string;
      skin?: string;
      hair?: string;
      appearance?: string;
    };
    personality?: {
      traits?: string;
      ideals?: string;
      bonds?: string;
      flaws?: string;
    };
    background?: {
      backstory?: string;
      allies?: string;
      features?: string;
    };
    equipment?: {
      languages?: string[];
      spells?: CodexEquipmentItem[];
      items?: CodexEquipmentItem[];
    };
  };
  lieu: { region?: string; locationType?: string };
  autre: Record<string, never>;
}

export type AbilityKey = keyof NonNullable<CodexAttributesByCategory["joueur"]["abilities"]>;

export const ABILITY_LABELS: Record<AbilityKey, string> = {
  str: "Force",
  dex: "Dextérité",
  con: "Constitution",
  int: "Intelligence",
  wis: "Sagesse",
  cha: "Charisme",
};

// Settings — à modéliser une fois l'écran Paramètres construit.
