"use server";

import { randomInt } from "node:crypto";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";

export type GenerateInviteCodeResult = { error: string | null; inviteCode?: string };
export type UpdateActionResult = { error: string | null };

const INVITE_CODE_LENGTH = 8;
// Alphanumérique majuscule, sans caractères ambigus (0/O, 1/I/L) — cf.
// docs/cahier-des-charges/12-partage-et-groupes.md section 5.6 (dépôt mobile).
const INVITE_CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
const MAX_GENERATION_ATTEMPTS = 5;
const UNIQUE_VIOLATION_CODE = "23505";

function generateInviteCodeCandidate(): string {
  let code = "";
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    code += INVITE_CODE_ALPHABET[randomInt(INVITE_CODE_ALPHABET.length)];
  }
  return code;
}

/** Génère (ou régénère) le code d'invitation d'une histoire. Un code fraîchement généré est
 * actif immédiatement (`invite_code_enabled: true`), pas d'étape d'activation séparée. Retente
 * en cas de collision sur la contrainte unique `stories_invite_code_key` : l'espace de codes
 * (31^8) rend une collision réelle improbable, mais le cas est géré proprement plutôt que de
 * remonter une erreur brute à l'utilisateur. */
export async function generateInviteCode(storyId: string): Promise<GenerateInviteCodeResult> {
  const supabase = await createClient();

  for (let attempt = 0; attempt < MAX_GENERATION_ATTEMPTS; attempt++) {
    const inviteCode = generateInviteCodeCandidate();
    const { error } = await supabase
      .from("stories")
      .update({ invite_code: inviteCode, invite_code_enabled: true })
      .eq("id", storyId);

    if (!error) {
      revalidatePath(`/story/${storyId}/joueurs`);
      return { error: null, inviteCode };
    }

    if (error.code !== UNIQUE_VIOLATION_CODE) {
      return { error: "Impossible de générer le lien d'invitation." };
    }
  }

  return { error: "Impossible de générer un code unique, réessaie." };
}

/** Active/désactive le code d'invitation existant sans le changer (réversible, pas de perte). */
export async function setInviteCodeEnabled(
  storyId: string,
  enabled: boolean,
): Promise<UpdateActionResult> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("stories")
    .update({ invite_code_enabled: enabled })
    .eq("id", storyId);

  if (error) {
    return { error: "Impossible de mettre à jour le lien d'invitation." };
  }

  revalidatePath(`/story/${storyId}/joueurs`);
  return { error: null };
}

/** Retire le rattachement d'un joueur à l'histoire (supprime la ligne `character_campaigns`),
 * sans jamais supprimer le personnage ni son historique. */
export async function removePlayer(
  campaignId: string,
  storyId: string,
): Promise<UpdateActionResult> {
  const supabase = await createClient();
  const { error } = await supabase.from("character_campaigns").delete().eq("id", campaignId);

  if (error) {
    return { error: "Impossible de retirer ce joueur." };
  }

  revalidatePath(`/story/${storyId}/joueurs`);
  return { error: null };
}
