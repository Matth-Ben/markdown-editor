"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { deleteAllContentImages, pruneRemovedContentImages } from "../content-images";
import type { CodexCategory, CodexEquipmentItem, CodexOpen5eRef } from "@nexus/core";
import type { Json } from "@nexus/supabase-client";

export type CodexActionState = {
  error: string | null;
  success?: boolean;
};

function isCodexCategory(value: string): value is CodexCategory {
  return ["pnj", "bestiaire", "joueur", "lieu", "autre"].includes(value);
}

function omitEmpty<T extends Record<string, unknown>>(obj: T): Partial<T> {
  const result: Partial<T> = {};
  for (const key in obj) {
    const value = obj[key];
    const isEmpty = value === undefined || value === "" || (Array.isArray(value) && value.length === 0);
    if (!isEmpty) result[key] = value;
  }
  return result;
}

function splitLines(value: string | null): string[] {
  return (value ?? "")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function parseEquipmentJson(value: string | null): CodexEquipmentItem[] {
  if (!value) return [];
  try {
    const parsed: unknown = JSON.parse(value);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (item): item is CodexEquipmentItem =>
        typeof item === "object" && item !== null && typeof (item as { name?: unknown }).name === "string",
    );
  } catch {
    return [];
  }
}

function buildOpen5eRef(formData: FormData, keyField: string, kindField: string): CodexOpen5eRef | undefined {
  const key = (formData.get(keyField) as string | null)?.trim();
  const kind = (formData.get(kindField) as string | null)?.trim();
  if (!key || !kind) return undefined;
  return { key, kind: kind as CodexOpen5eRef["kind"] };
}

const ABILITY_KEYS = ["str", "dex", "con", "int", "wis", "cha"] as const;

function buildAttributes(category: CodexCategory, formData: FormData): Record<string, unknown> {
  const get = (key: string) => (formData.get(key) as string | null)?.trim();

  switch (category) {
    case "pnj":
      return omitEmpty({
        role: get("attr_role"),
        stats: get("attr_stats"),
        open5eRef: buildOpen5eRef(formData, "attr_open5eKey", "attr_open5eKind"),
      });
    case "bestiaire":
      return omitEmpty({
        dangerLevel: get("attr_dangerLevel"),
        stats: get("attr_stats"),
        open5eRef: buildOpen5eRef(formData, "attr_open5eKey", "attr_open5eKind"),
      });
    case "joueur": {
      const abilities = omitEmpty(
        Object.fromEntries(ABILITY_KEYS.map((key) => [key, get(`player_ability_${key}`)])),
      );
      const identity = omitEmpty({
        age: get("player_age"),
        height: get("player_height"),
        weight: get("player_weight"),
        eyes: get("player_eyes"),
        skin: get("player_skin"),
        hair: get("player_hair"),
        appearance: get("player_appearance"),
      });
      const personality = omitEmpty({
        traits: get("player_traits"),
        ideals: get("player_ideals"),
        bonds: get("player_bonds"),
        flaws: get("player_flaws"),
      });
      const background = omitEmpty({
        backstory: get("player_backstory"),
        allies: get("player_allies"),
        features: get("player_features"),
      });
      const equipment = omitEmpty({
        languages: splitLines(formData.get("player_languages") as string | null),
        spells: parseEquipmentJson(formData.get("player_spells_json") as string | null),
        items: parseEquipmentJson(formData.get("player_items_json") as string | null),
      });

      return omitEmpty({
        playerName: get("player_playerName"),
        race: get("player_race"),
        characterClass: get("player_class"),
        classPath: get("player_classPath"),
        level: get("player_level"),
        abilities: Object.keys(abilities).length > 0 ? abilities : undefined,
        identity: Object.keys(identity).length > 0 ? identity : undefined,
        personality: Object.keys(personality).length > 0 ? personality : undefined,
        background: Object.keys(background).length > 0 ? background : undefined,
        equipment: Object.keys(equipment).length > 0 ? equipment : undefined,
      });
    }
    case "lieu":
      return omitEmpty({ region: get("attr_region"), locationType: get("attr_locationType") });
    case "autre":
      return {};
  }
}

function revalidateStoryPaths(storyId: string) {
  revalidatePath(`/story/${storyId}`);
  revalidatePath(`/story/${storyId}/codex`);
}

export async function createCodexEntry(
  _prevState: CodexActionState,
  formData: FormData,
): Promise<CodexActionState> {
  const storyId = formData.get("storyId") as string;
  const name = (formData.get("name") as string | null)?.trim();
  const summary = (formData.get("summary") as string | null)?.trim() ?? "";
  const content = (formData.get("content") as string | null) ?? "";
  const categoryRaw = formData.get("category") as string;

  if (!name) {
    return { error: "Merci de donner un nom à la fiche." };
  }
  if (!isCodexCategory(categoryRaw)) {
    return { error: "Catégorie invalide." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: "Session expirée, reconnecte-toi." };
  }

  const { error } = await supabase.from("codex_entries").insert({
    story_id: storyId,
    user_id: user.id,
    category: categoryRaw,
    name,
    summary,
    content,
    attributes: buildAttributes(categoryRaw, formData) as Json,
  });

  if (error) {
    if (error.code === "23505") {
      return { error: "Une fiche porte déjà ce nom dans cette histoire." };
    }
    return { error: "Impossible de créer la fiche." };
  }

  revalidateStoryPaths(storyId);
  return { error: null, success: true };
}

export async function updateCodexEntry(
  _prevState: CodexActionState,
  formData: FormData,
): Promise<CodexActionState> {
  const storyId = formData.get("storyId") as string;
  const entryId = formData.get("entryId") as string;
  const name = (formData.get("name") as string | null)?.trim();
  const summary = (formData.get("summary") as string | null)?.trim() ?? "";
  const content = (formData.get("content") as string | null) ?? "";
  const categoryRaw = formData.get("category") as string;

  if (!name) {
    return { error: "Merci de donner un nom à la fiche." };
  }
  if (!isCodexCategory(categoryRaw)) {
    return { error: "Catégorie invalide." };
  }

  const supabase = await createClient();

  const { data: existing } = await supabase
    .from("codex_entries")
    .select("content")
    .eq("id", entryId)
    .single();

  const { error } = await supabase
    .from("codex_entries")
    .update({
      category: categoryRaw,
      name,
      summary,
      content,
      attributes: buildAttributes(categoryRaw, formData) as Json,
      updated_at: new Date().toISOString(),
    })
    .eq("id", entryId);

  if (error) {
    if (error.code === "23505") {
      return { error: "Une fiche porte déjà ce nom dans cette histoire." };
    }
    return { error: "Impossible d'enregistrer les modifications." };
  }

  if (existing?.content) {
    await pruneRemovedContentImages(supabase, existing.content, content);
  }

  revalidateStoryPaths(storyId);
  return { error: null, success: true };
}

export async function deleteCodexEntry(formData: FormData): Promise<void> {
  const storyId = formData.get("storyId") as string;
  const entryId = formData.get("entryId") as string;
  const redirectTo = formData.get("redirectTo") as string | null;

  const supabase = await createClient();

  const { data: existing } = await supabase
    .from("codex_entries")
    .select("content")
    .eq("id", entryId)
    .single();

  await supabase.from("codex_entries").delete().eq("id", entryId);

  if (existing?.content) {
    await deleteAllContentImages(supabase, existing.content);
  }

  revalidateStoryPaths(storyId);

  if (redirectTo) {
    redirect(redirectTo);
  }
}

function parseEntryIds(formData: FormData): string[] {
  return ((formData.get("entryIds") as string | null) ?? "").split(",").filter(Boolean);
}

export async function deleteCodexEntries(formData: FormData): Promise<void> {
  const storyId = formData.get("storyId") as string;
  const entryIds = parseEntryIds(formData);
  if (entryIds.length === 0) return;

  const supabase = await createClient();

  const { data: existingEntries } = await supabase
    .from("codex_entries")
    .select("content")
    .in("id", entryIds);

  await supabase.from("codex_entries").delete().in("id", entryIds);

  const combinedContent = (existingEntries ?? []).map((entry) => entry.content ?? "").join("\n");
  await deleteAllContentImages(supabase, combinedContent);

  revalidateStoryPaths(storyId);
}

export async function moveCodexEntriesToCategory(formData: FormData): Promise<void> {
  const storyId = formData.get("storyId") as string;
  const entryIds = parseEntryIds(formData);
  const category = formData.get("category") as string;
  if (entryIds.length === 0 || !isCodexCategory(category)) return;

  const supabase = await createClient();
  await supabase
    .from("codex_entries")
    .update({ category, updated_at: new Date().toISOString() })
    .in("id", entryIds);

  revalidateStoryPaths(storyId);
}
