"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export type UpdateStoryState = {
  error: string | null;
};

export async function updateStoryContent(
  _prevState: UpdateStoryState,
  formData: FormData,
): Promise<UpdateStoryState> {
  const storyId = formData.get("storyId") as string;
  const content = formData.get("content") as string;

  const supabase = await createClient();
  const { error } = await supabase
    .from("stories")
    .update({ content, updated_at: new Date().toISOString() })
    .eq("id", storyId);

  if (error) {
    return { error: "Impossible d'enregistrer les modifications." };
  }

  revalidatePath(`/story/${storyId}`);
  return { error: null };
}
