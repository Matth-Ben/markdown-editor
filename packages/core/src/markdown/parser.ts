import remarkGfm from "remark-gfm";
import remarkDirective from "remark-directive";
import { remarkAmbianceDirective } from "./ambiance-directive";
import { remarkCodexMention } from "./codex-mention";

/** Plugins remark à passer à react-markdown (remarkPlugins) pour le rendu des histoires. */
export const markdownRemarkPlugins = [
  remarkGfm,
  remarkDirective,
  remarkAmbianceDirective,
  remarkCodexMention,
];
