"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { deleteAllContentImages } from "./story/[id]/content-images";

export type CreateStoryState = {
  error: string | null;
};

export type DeleteStoryResult = {
  error: string | null;
};

const DEFAULT_NEW_STORY_TITLE = "Nouvelle histoire";

/** Crée une histoire brouillon (invisible dans la Bibliothèque tant qu'elle n'est pas publiée) et
 * ouvre directement son éditeur — le titre, la couverture et le contenu se personnalisent ensuite
 * depuis la page d'édition, puis « Publier » la rend visible dans la Bibliothèque. */
export async function createStory(): Promise<CreateStoryState> {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: "Session expirée, reconnecte-toi." };
  }

  const { data: story, error: insertError } = await supabase
    .from("stories")
    .insert({ user_id: user.id, title: DEFAULT_NEW_STORY_TITLE, published: false })
    .select("id")
    .single();

  if (insertError || !story) {
    return { error: "Impossible de créer l'histoire." };
  }

  redirect(`/story/${story.id}`);
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
