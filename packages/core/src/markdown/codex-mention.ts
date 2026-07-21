import { findAndReplace } from "mdast-util-find-and-replace";
import type { Root } from "mdast";
import type {} from "mdast-util-to-hast";
import type { Plugin } from "unified";

const MENTION_PATTERN = /\[\[([^[\]]+)\]\]/g;

/**
 * Reconnaît les mentions `[[Nom de l'entité]]` dans le texte et les tague pour
 * un rendu React via <CodexMentionTooltip>. La résolution du nom vers une fiche
 * réelle (résumé affiché au survol) se fait côté composant, pas ici.
 */
export const remarkCodexMention: Plugin<[], Root> = () => (tree) => {
  findAndReplace(tree, [
    [
      MENTION_PATTERN,
      (_match: string, name: string) => ({
        type: "textDirective",
        name: "codexMention",
        attributes: {},
        data: {
          hName: "codex-mention",
          hProperties: { entityName: name.trim() },
        },
        children: [{ type: "text", value: name.trim() }],
      }),
    ],
  ]);
};
