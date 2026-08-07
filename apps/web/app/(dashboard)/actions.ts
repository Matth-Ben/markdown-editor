"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { deleteAllContentImages } from "./story/[id]/content-images";

export type CreateStoryState = {
  error: string | null;
};

export type DeleteStoryResult = {
  error: string | null;
};

export async function createStory(
  _prevState: CreateStoryState,
  formData: FormData,
): Promise<CreateStoryState> {
  const title = (formData.get("title") as string | null)?.trim();
  const cover = formData.get("cover") as File | null;

  if (!title) {
    return { error: "Merci de donner un titre à ton histoire." };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: "Session expirée, reconnecte-toi." };
  }

  let coverImagePath: string | null = null;

  if (cover && cover.size > 0) {
    if (!cover.type.startsWith("image/")) {
      return { error: "La couverture doit être une image." };
    }

    const extension = cover.name.split(".").pop() ?? "jpg";
    const path = `${user.id}/${crypto.randomUUID()}.${extension}`;
    const { error: uploadError } = await supabase.storage
      .from("story-covers")
      .upload(path, cover);

    if (uploadError) {
      return { error: "Impossible d'envoyer l'image de couverture." };
    }

    coverImagePath = path;
  }

  const { error: insertError } = await supabase.from("stories").insert({
    user_id: user.id,
    title,
    cover_image_path: coverImagePath,
  });

  if (insertError) {
    return { error: "Impossible de créer l'histoire." };
  }

  revalidatePath("/");
  return { error: null };
}

/** Supprime définitivement une histoire (les fiches Codex associées disparaissent en cascade en
 * base) et nettoie le Storage : couverture + images de contenu de l'histoire et de ses fiches. */
export async function deleteStory(formData: FormData): Promise<DeleteStoryResult> {
  const storyId = formData.get("storyId") as string;

  const supabase = await createClient();

  const { data: story } = await supabase
    .from("stories")
    .select("content, cover_image_path")
    .eq("id", storyId)
    .single();

  if (!story) {
    return { error: "Cette histoire n'existe plus." };
  }

  const { data: entries } = await supabase
    .from("codex_entries")
    .select("content")
    .eq("story_id", storyId);

  const { error: deleteError } = await supabase.from("stories").delete().eq("id", storyId);

  if (deleteError) {
    return { error: "Impossible de supprimer l'histoire." };
  }

  if (story.cover_image_path) {
    await supabase.storage.from("story-covers").remove([story.cover_image_path]);
  }

  const combinedContent = [story.content, ...(entries ?? []).map((entry) => entry.content ?? "")].join(
    "\n",
  );
  await deleteAllContentImages(supabase, combinedContent);

  revalidatePath("/");
  return { error: null };
}
