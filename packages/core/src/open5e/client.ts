import type { Open5eKind, Open5eSearchResult } from "./types";

const OPEN5E_BASE_URL = "https://api.open5e.com/v2";

interface Open5eListResponse<T> {
  count: number;
  results: T[];
}

async function open5eFetch<T>(path: string): Promise<T> {
  const response = await fetch(`${OPEN5E_BASE_URL}${path}`);
  if (!response.ok) {
    throw new Error(`Open5e a répondu ${response.status} pour ${path}`);
  }
  return response.json() as Promise<T>;
}

/** Recherche par nom (partiel, insensible à la casse) sur un type de ressource Open5e. */
export async function searchOpen5e<T extends Open5eSearchResult>(
  kind: Open5eKind,
  query: string,
  limit = 8,
): Promise<T[]> {
  const trimmed = query.trim();
  if (!trimmed) return [];

  const params = new URLSearchParams({ name__icontains: trimmed, limit: String(limit) });
  const data = await open5eFetch<Open5eListResponse<T>>(`/${kind}/?${params}`);
  return data.results;
}

/** Récupère le détail complet d'une ressource par sa clé (toujours à la demande, jamais mis en cache). */
export async function getOpen5eDetail<T>(kind: Open5eKind, key: string): Promise<T> {
  return open5eFetch<T>(`/${kind}/${encodeURIComponent(key)}/`);
}

/**
 * Certains endpoints (classes, species) sont de petite taille et n'implémentent pas le filtre
 * `name__icontains` (il est silencieusement ignoré, toute la liste est renvoyée quel que soit
 * le filtre). Pour ceux-là, on récupère la liste complète une seule fois et on filtre côté
 * client plutôt que de faire une recherche serveur peu fiable.
 */
export async function listAllOpen5e<T extends Open5eSearchResult>(
  kind: Open5eKind,
  limit = 300,
): Promise<T[]> {
  const data = await open5eFetch<Open5eListResponse<T>>(`/${kind}/?limit=${limit}`);
  return data.results;
}
