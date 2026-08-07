"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { pruneRemovedContentImages } from "./content-images";

export type UpdateStoryState = {
  error: string | null;
};

export type UpdateStoryFieldResult = {
  error: string | null;
};

export type UploadContentImageResult = { url: string } | { error: string };

const MAX_CONTENT_IMAGE_BYTES = 8 * 1024 * 1024;
const MAX_COVER_IMAGE_BYTES = 8 * 1024 * 1024;

/** Uploade une image importée depuis la barre d'outils Markdown (histoire ou fiche Codex) et
 * renvoie son URL publique. Invoquée directement depuis un event handler client (pas via
 * <form>), donc appelée avec un FormData construit à la volée plutôt que par soumission native. */
export async function uploadContentImage(formData: FormData): Promise<UploadContentImageResult> {
  const storyId = formData.get("storyId") as string | null;
  const file = formData.get("file") as File | null;

  if (!storyId || !file || file.size === 0) {
    return { error: "Aucune image sélectionnée." };
  }

  if (!file.type.startsWith("image/")) {
    return { error: "Le fichier doit être une image." };
  }

  if (file.size > MAX_CONTENT_IMAGE_BYTES) {
    return { error: "L'image est trop lourde (8 Mo maximum)." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: "Session expirée, reconnecte-toi." };
  }

  const extension = file.name.split(".").pop() ?? "jpg";
  const path = `${user.id}/${storyId}/${crypto.randomUUID()}.${extension}`;
  const { error: uploadError } = await supabase.storage
    .from("story-content-images")
    .upload(path, file);

  if (uploadError) {
    return { error: "Impossible d'envoyer l'image." };
  }

  const {
    data: { publicUrl },
  } = supabase.storage.from("story-content-images").getPublicUrl(path);

  return { url: publicUrl };
}

export async function updateStoryContent(
  _prevState: UpdateStoryState,
  formData: FormData,
): Promise<UpdateStoryState> {
  const storyId = formData.get("storyId") as string;
  const content = formData.get("content") as string;

  const supabase = await createClient();

  const { data: existing } = await supabase
    .from("stories")
    .select("content")
    .eq("id", storyId)
    .single();

  const { error } = await supabase
    .from("stories")
    .update({ content, updated_at: new Date().toISOString() })
    .eq("id", storyId);

  if (error) {
    return { error: "Impossible d'enregistrer les modifications." };
  }

  if (existing?.content) {
    await pruneRemovedContentImages(supabase, existing.content, content);
  }

  revalidatePath(`/story/${storyId}`);
  return { error: null };
}

/** Renomme une histoire, indépendamment de sa couverture (édition inline du titre). */
export async function updateStoryTitle(storyId: string, title: string): Promise<UpdateStoryFieldResult> {
  const trimmed = title.trim();
  if (!trimmed) {
    return { error: "Merci de donner un titre à l'histoire." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("stories")
    .update({ title: trimmed, updated_at: new Date().toISOString() })
    .eq("id", storyId);

  if (error) {
    return { error: "Impossible d'enregistrer le titre." };
  }

  revalidatePath(`/story/${storyId}`);
  revalidatePath("/");
  return { error: null };
}

/** Remplace la couverture d'une histoire, indépendamment de son titre. L'ancienne image est
 * supprimée du Storage pour éviter les fichiers orphelins. */
export async function updateStoryCover(formData: FormData): Promise<UpdateStoryFieldResult> {
  const storyId = formData.get("storyId") as string;
  const cover = formData.get("cover") as File | null;

  if (!cover || cover.size === 0) {
    return { error: "Aucune image sélectionnée." };
  }

  if (!cover.type.startsWith("image/")) {
    return { error: "La couverture doit être une image." };
  }

  if (cover.size > MAX_COVER_IMAGE_BYTES) {
    return { error: "L'image est trop lourde (8 Mo maximum)." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: "Session expirée, reconnecte-toi." };
  }

  const { data: existing } = await supabase
    .from("stories")
    .select("cover_image_path")
    .eq("id", storyId)
    .single();

  const extension = cover.name.split(".").pop() ?? "jpg";
  const path = `${user.id}/${crypto.randomUUID()}.${extension}`;
  const { error: uploadError } = await supabase.storage.from("story-covers").upload(path, cover);

  if (uploadError) {
    return { error: "Impossible d'envoyer l'image de couverture." };
  }

  const { error: updateError } = await supabase
    .from("stories")
    .update({ cover_image_path: path, updated_at: new Date().toISOString() })
    .eq("id", storyId);

  if (updateError) {
    await supabase.storage.from("story-covers").remove([path]);
    return { error: "Impossible d'enregistrer les modifications." };
  }

  if (existing?.cover_image_path) {
    await supabase.storage.from("story-covers").remove([existing.cover_image_path]);
  }

  revalidatePath(`/story/${storyId}`);
  revalidatePath("/");
  return { error: null };
}
