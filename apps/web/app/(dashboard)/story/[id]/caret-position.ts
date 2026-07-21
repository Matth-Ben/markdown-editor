const MIRRORED_STYLE_PROPERTIES: (keyof CSSStyleDeclaration)[] = [
  "boxSizing",
  "width",
  "paddingTop",
  "paddingRight",
  "paddingBottom",
  "paddingLeft",
  "borderTopWidth",
  "borderRightWidth",
  "borderBottomWidth",
  "borderLeftWidth",
  "fontFamily",
  "fontSize",
  "fontWeight",
  "lineHeight",
  "letterSpacing",
];

/**
 * Approxime la position pixel du caret dans un <textarea> via la technique du "mirror div" :
 * un clone invisible reproduit les styles du textarea, on y insère le texte jusqu'au caret,
 * puis on mesure la position d'un marqueur inséré à cet endroit.
 */
export function getCaretCoordinates(
  textarea: HTMLTextAreaElement,
  position: number,
): { top: number; left: number } {
  const div = document.createElement("div");
  const computed = window.getComputedStyle(textarea);

  for (const prop of MIRRORED_STYLE_PROPERTIES) {
    // @ts-expect-error -- copie dynamique de propriétés CSS calculées
    div.style[prop] = computed[prop];
  }

  div.style.position = "absolute";
  div.style.visibility = "hidden";
  div.style.whiteSpace = "pre-wrap";
  div.style.wordWrap = "break-word";
  div.style.top = "0";
  div.style.left = "-9999px";
  div.style.height = "auto";

  div.textContent = textarea.value.slice(0, position);

  const marker = document.createElement("span");
  marker.textContent = "​";
  div.appendChild(marker);

  document.body.appendChild(div);
  const { offsetTop, offsetLeft } = marker;
  document.body.removeChild(div);

  return {
    top: offsetTop - textarea.scrollTop,
    left: offsetLeft - textarea.scrollLeft,
  };
}
