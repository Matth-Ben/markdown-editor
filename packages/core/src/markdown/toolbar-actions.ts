/**
 * Transformations Markdown pures utilisées par la barre d'outils de l'éditeur (WYSIWYG-like).
 * Chaque fonction prend le texte complet + la sélection courante et renvoie le nouveau texte
 * ainsi que la sélection à restaurer dans le textarea, sans jamais toucher au DOM.
 */
export interface TextEditResult {
  text: string;
  selectionStart: number;
  selectionEnd: number;
}

/** Enveloppe la sélection avec un marqueur (gras, italique, barré, code inline), avec bascule :
 * ré-appliquer le même marqueur sur un texte déjà enveloppé le retire. */
export function wrapSelection(
  text: string,
  start: number,
  end: number,
  marker: string,
  placeholder: string,
): TextEditResult {
  const selected = text.slice(start, end) || placeholder;
  const before = text.slice(0, start);
  const after = text.slice(end);

  const alreadyWrapped = before.endsWith(marker) && after.startsWith(marker);
  if (alreadyWrapped) {
    const newBefore = before.slice(0, before.length - marker.length);
    const newAfter = after.slice(marker.length);
    return {
      text: `${newBefore}${selected}${newAfter}`,
      selectionStart: newBefore.length,
      selectionEnd: newBefore.length + selected.length,
    };
  }

  const newBefore = `${before}${marker}`;
  return {
    text: `${newBefore}${selected}${marker}${after}`,
    selectionStart: newBefore.length,
    selectionEnd: newBefore.length + selected.length,
  };
}

/** Ajoute (ou retire, en bascule) un préfixe à chaque ligne couverte par la sélection —
 * titres, citation, listes. `stripPattern` retire un préfixe existant du même type avant
 * d'appliquer le nouveau (ex. passer de "## " à "# "). */
export function toggleLinePrefix(
  text: string,
  start: number,
  end: number,
  prefix: string,
  stripPattern?: RegExp,
): TextEditResult {
  const lineStart = text.lastIndexOf("\n", start - 1) + 1;
  const nextBreak = text.indexOf("\n", end);
  const lineEnd = nextBreak === -1 ? text.length : nextBreak;

  const before = text.slice(0, lineStart);
  const after = text.slice(lineEnd);
  const lines = text.slice(lineStart, lineEnd).split("\n");

  const alreadyApplied = lines.every((line) => line.startsWith(prefix));
  const newLines = lines.map((line) => {
    if (alreadyApplied) return line.slice(prefix.length);
    const stripped = stripPattern ? line.replace(stripPattern, "") : line;
    return `${prefix}${stripped}`;
  });

  const newBlock = newLines.join("\n");
  return {
    text: `${before}${newBlock}${after}`,
    selectionStart: lineStart,
    selectionEnd: lineStart + newBlock.length,
  };
}

/** Insère un lien `[texte](url)`, sélectionnant le texte pour édition immédiate. */
export function insertLink(text: string, start: number, end: number, url: string): TextEditResult {
  const selected = text.slice(start, end) || "texte du lien";
  const before = text.slice(0, start);
  const after = text.slice(end);
  const linkStart = before.length + 1;
  return {
    text: `${before}[${selected}](${url})${after}`,
    selectionStart: linkStart,
    selectionEnd: linkStart + selected.length,
  };
}

/** Insère une image `![alt](url)`, sélectionnant le texte alternatif pour édition immédiate. */
export function insertImage(text: string, start: number, end: number, url: string): TextEditResult {
  const selected = text.slice(start, end) || "description de l'image";
  const before = text.slice(0, start);
  const after = text.slice(end);
  const altStart = before.length + 2;
  return {
    text: `${before}![${selected}](${url})${after}`,
    selectionStart: altStart,
    selectionEnd: altStart + selected.length,
  };
}

/** Insère un bloc de code ``` autour de la sélection, sur ses propres lignes. */
export function insertCodeBlock(text: string, start: number, end: number): TextEditResult {
  const selected = text.slice(start, end) || "code";
  const before = text.slice(0, start);
  const after = text.slice(end);
  const leadingNewline = before.length > 0 && !before.endsWith("\n") ? "\n" : "";
  const trailingNewline = after.length > 0 && !after.startsWith("\n") ? "\n" : "";
  const opening = `${leadingNewline}\`\`\`\n`;
  return {
    text: `${before}${opening}${selected}\n\`\`\`${trailingNewline}${after}`,
    selectionStart: before.length + opening.length,
    selectionEnd: before.length + opening.length + selected.length,
  };
}

/** Insère une ligne horizontale isolée à la position du curseur. */
export function insertHorizontalRule(text: string, start: number, end: number): TextEditResult {
  const before = text.slice(0, start);
  const after = text.slice(end);
  const leadingNewline = before.length > 0 && !before.endsWith("\n") ? "\n\n" : "";
  const trailingNewline = after.length > 0 && !after.startsWith("\n") ? "\n\n" : "\n";
  const inserted = `${leadingNewline}---${trailingNewline}`;
  return {
    text: `${before}${inserted}${after}`,
    selectionStart: before.length + inserted.length,
    selectionEnd: before.length + inserted.length,
  };
}
