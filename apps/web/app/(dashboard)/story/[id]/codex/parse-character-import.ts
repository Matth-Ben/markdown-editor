import type { AbilityKey, CodexAttributesByCategory } from "@nexus/core";
import type { CodexEntryInitialValues } from "./codex-entry-form";

const ABILITY_KEYS: AbilityKey[] = ["str", "dex", "con", "int", "wis", "cha"];

// Marqueur fiable de cette corruption : "Ã"/"Â" (U+00C3/U+00C2) suivi d'un octet
// de continuation UTF-8 (U+0080-U+00BF une fois relu en Latin-1).
const MOJIBAKE_MARKER = /[ÃÂ][\u0080-\u00bf]/;

/**
 * De nombreux exports de cet outil sont doublement encodés (UTF-8 relu en Latin-1,
 * ex: "Ã©" au lieu de "é"). On corrige en réinterprétant les code units de la chaîne
 * comme des octets UTF-8. Décodage non strict : certains textes source ont en plus
 * perdu des octets isolés (ex: une apostrophe typographique tronquée) — mieux vaut
 * restituer le reste du texte correctement avec un "�" isolé que d'abandonner la
 * correction de tout le paragraphe pour un seul octet imparfait.
 */
function fixMojibake(text: string): string {
  if (!MOJIBAKE_MARKER.test(text)) return text;
  const bytes = Uint8Array.from(Array.from(text, (char) => char.charCodeAt(0) & 0xff));
  return new TextDecoder("utf-8").decode(bytes);
}

function getText(doc: Document, tag: string): string {
  const raw = doc.getElementsByTagName(tag)[0]?.textContent?.trim() ?? "";
  return raw ? fixMojibake(raw) : "";
}

function getAllText(doc: Document, tag: string): string[] {
  return Array.from(doc.getElementsByTagName(tag))
    .map((node) => node.textContent?.trim())
    .filter((value): value is string => Boolean(value))
    .map(fixMojibake);
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

/**
 * Parse le format XML "builder" (fiches de personnage D&D 5e) et extrait uniquement
 * les champs directement lisibles (nom, race/classe/niveau, caractéristiques,
 * identité, personnalité, sorts connus par leur nom, langues), chacun conservé comme
 * champ distinct plutôt que concaténé en texte. Les identifiants numériques
 * d'objets/armes/compétences (ex: <item>56,82,80...</item>) référencent une base
 * interne à l'outil source et ne sont volontairement pas résolus : les inclure tel
 * quel serait plus trompeur qu'utile.
 */
export function parseCharacterBuilderXml(xmlText: string): CodexEntryInitialValues | null {
  const doc = new DOMParser().parseFromString(xmlText, "application/xml");
  if (doc.getElementsByTagName("parsererror").length > 0) {
    return null;
  }
  if (doc.getElementsByTagName("character").length === 0) {
    return null;
  }

  const name = getText(doc, "name");
  const race = getText(doc, "race") || getText(doc, "raceCustom");
  const characterClass = getText(doc, "class");
  const classPath = getText(doc, "classPath");
  const level = getText(doc, "level");
  const background = getText(doc, "background");

  const abilities = omitEmpty(
    Object.fromEntries(ABILITY_KEYS.map((key) => [key, getText(doc, key)])) as Record<
      AbilityKey,
      string
    >,
  );

  const identity = omitEmpty({
    age: getText(doc, "age"),
    height: getText(doc, "height"),
    weight: getText(doc, "weight"),
    eyes: getText(doc, "eyes"),
    skin: getText(doc, "skin"),
    hair: getText(doc, "hair"),
    appearance: getText(doc, "appearance"),
  });

  const personality = omitEmpty({
    traits: getText(doc, "traits"),
    ideals: getText(doc, "ideals"),
    bonds: getText(doc, "bonds"),
    flaws: getText(doc, "flaws"),
  });

  const backgroundSection = omitEmpty({
    backstory: getText(doc, "backstory"),
    allies: getText(doc, "allies"),
    features: getText(doc, "features"),
  });

  const equipment = omitEmpty({
    languages: getAllText(doc, "languages"),
    // Pas de clé Open5e à l'import : les noms de l'outil source ne correspondent pas
    // forcément exactement aux entrées Open5e. L'utilisateur peut relier manuellement
    // via le formulaire d'édition ensuite si besoin.
    spells: [
      ...getAllText(doc, "knownSpell"),
      ...getAllText(doc, "innateSpell"),
      ...getAllText(doc, "knownInvocation"),
    ].map((name) => ({ name })),
    items: getText(doc, "itemX")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean)
      .map((name) => ({ name })),
  });

  const classLabelWithLevel = [
    [race, characterClass, classPath ? `(${classPath})` : null].filter(Boolean).join(" "),
    level ? `— niveau ${level}` : null,
  ]
    .filter(Boolean)
    .join(" ");

  const attributes: CodexAttributesByCategory["joueur"] = omitEmpty({
    race: race || undefined,
    characterClass: characterClass || undefined,
    classPath: classPath || undefined,
    level: level || undefined,
    abilities: Object.keys(abilities).length > 0 ? abilities : undefined,
    identity: Object.keys(identity).length > 0 ? identity : undefined,
    personality: Object.keys(personality).length > 0 ? personality : undefined,
    background: Object.keys(backgroundSection).length > 0 ? backgroundSection : undefined,
    equipment: Object.keys(equipment).length > 0 ? equipment : undefined,
  });

  return {
    category: "joueur",
    name: name || "Personnage importé",
    summary: [classLabelWithLevel, background ? `Historique : ${background}` : null]
      .filter(Boolean)
      .join(" — "),
    content: "",
    attributes,
  };
}
