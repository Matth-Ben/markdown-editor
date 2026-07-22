import type { createClient } from "@/lib/supabase/server";

type SupabaseServerClient = Awaited<ReturnType<typeof createClient>>;

const CONTENT_IMAGE_PATH_PATTERN = /\/storage\/v1\/object\/public\/story-content-images\/([^)\s"]+)/g;

/** Extrait les chemins de stockage (bucket `story-content-images`) référencés dans un contenu
 * Markdown, pour savoir quelles images importées via la barre d'outils sont encore utilisées. */
export function extractContentImagePaths(content: string): Set<string> {
  const paths = new Set<string>();
  for (const match of content.matchAll(CONTENT_IMAGE_PATH_PATTERN)) {
    paths.add(decodeURIComponent(match[1]));
  }
  return paths;
}

/** Supprime du Storage les images qui étaient référencées dans `previousContent` mais qui ont
 * disparu de `nextContent` (image retirée du texte lors d'une édition). Ne supprime jamais un
 * fichier encore présent dans le nouveau contenu. */
export async function pruneRemovedContentImages(
  supabase: SupabaseServerClient,
  previousContent: string,
  nextContent: string,
): Promise<void> {
  const previousPaths = extractContentImagePaths(previousContent);
  const nextPaths = extractContentImagePaths(nextContent);
  const removed = [...previousPaths].filter((path) => !nextPaths.has(path));
  if (removed.length === 0) return;

  await supabase.storage.from("story-content-images").remove(removed);
}

/** Supprime toutes les images référencées dans un contenu — utilisé quand la fiche/l'histoire
 * qui les contient est supprimée définitivement, pas seulement éditée. */
export async function deleteAllContentImages(
  supabase: SupabaseServerClient,
  content: string,
): Promise<void> {
  const paths = [...extractContentImagePaths(content)];
  if (paths.length === 0) return;
  await supabase.storage.from("story-content-images").remove(paths);
}
