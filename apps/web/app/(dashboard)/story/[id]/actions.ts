"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { pruneRemovedContentImages } from "./content-images";

export type UpdateStoryState = {
  error: string | null;
};

export type UploadContentImageResult = { url: string } | { error: string };

const MAX_CONTENT_IMAGE_BYTES = 8 * 1024 * 1024;

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
