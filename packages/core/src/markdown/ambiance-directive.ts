import { visit } from "unist-util-visit";
import { toString as mdastToString } from "mdast-util-to-string";
import type { Root } from "mdast";
import type {} from "mdast-util-directive";
import type {} from "mdast-util-to-hast";
import type { Plugin } from "unified";

export interface AmbianceAttributes {
  type: string;
  volume: number;
  loop: boolean;
  light?: string;
}

/** Valeurs appliquées quand un attribut optionnel est omis du bloc ::: ambiance. */
export const DEFAULT_AMBIANCE_ATTRIBUTES: Pick<AmbianceAttributes, "volume" | "loop"> = {
  volume: 0.7,
  loop: true,
};

function parseVolume(raw: string | null | undefined): number {
  const parsed = raw == null ? NaN : Number(raw);
  if (Number.isNaN(parsed)) return DEFAULT_AMBIANCE_ATTRIBUTES.volume;
  return Math.min(1, Math.max(0, parsed));
}

function parseLoop(raw: string | null | undefined): boolean {
  if (raw == null) return DEFAULT_AMBIANCE_ATTRIBUTES.loop;
  return raw === "true";
}

/**
 * Reconnaît les blocs `:::ambiance{type="..." volume="..." loop="..." light="..."}`
 * (syntaxe remark-directive) et les tague pour un rendu React via <AmbianceTriggerButton>.
 * Le contenu textuel du bloc est conservé (description affichée) mais ignoré pour l'exécution.
 */
export const remarkAmbianceDirective: Plugin<[], Root> = () => (tree) => {
  visit(tree, "containerDirective", (node) => {
    if (node.name !== "ambiance") return;

    const attributes = node.attributes ?? {};
    const type = attributes.type ?? undefined;
    const description = mdastToString(node);

    const data = node.data ?? (node.data = {});
    data.hName = "ambiance-trigger";
    data.hProperties = {
      ambianceType: type ?? null,
      volume: parseVolume(attributes.volume),
      loop: parseLoop(attributes.loop),
      light: attributes.light ?? null,
      description,
      invalid: !type,
    };
  });
};
