export type Open5eKind = "creatures" | "spells" | "items" | "magicitems" | "classes" | "species";

interface NamedRef {
  name: string;
  key: string;
}

export interface Open5eSearchResult {
  key: string;
  name: string;
  document?: { name: string; key: string };
}

export interface Open5eCreatureSummary extends Open5eSearchResult {
  type?: NamedRef | string;
  size?: NamedRef | string;
  challenge_rating?: number;
  armor_class?: number;
  hit_points?: number;
}

export interface Open5eCreatureDetail extends Open5eCreatureSummary {
  alignment?: string;
  hit_dice?: string;
  speed?: Record<string, number | string | boolean>;
  ability_scores?: Record<string, number>;
  darkvision_range?: number;
  passive_perception?: number;
  languages?: { as_string?: string };
  actions?: { name: string; desc: string }[];
  traits?: { name: string; desc: string }[];
}

export interface Open5eSpellSummary extends Open5eSearchResult {
  level?: number;
  school?: NamedRef | string;
}

export interface Open5eSpellDetail extends Open5eSpellSummary {
  desc?: string;
  higher_level?: string;
  range_text?: string;
  casting_time?: string;
  duration?: string;
  concentration?: boolean;
  ritual?: boolean;
  verbal?: boolean;
  somatic?: boolean;
  material?: boolean;
  material_specified?: string;
}

export interface Open5eItemSummary extends Open5eSearchResult {
  category?: NamedRef | string;
  rarity?: NamedRef | string;
}

export interface Open5eItemDetail extends Open5eItemSummary {
  desc?: string;
  requires_attunement?: boolean;
  cost?: string;
  weight?: string;
}

export interface Open5eClassSummary extends Open5eSearchResult {
  subclass_of?: NamedRef | null;
}

export interface Open5eClassDetail extends Open5eClassSummary {
  desc?: string;
  hit_dice?: string;
  caster_type?: string;
}

export interface Open5eSpeciesSummary extends Open5eSearchResult {
  is_subspecies?: boolean;
  subspecies_of?: string | null;
}

export interface Open5eSpeciesDetail extends Open5eSpeciesSummary {
  desc?: string;
  traits?: { name: string; desc: string }[];
}

export type Open5eDetail =
  | Open5eCreatureDetail
  | Open5eSpellDetail
  | Open5eItemDetail
  | Open5eClassDetail
  | Open5eSpeciesDetail;
