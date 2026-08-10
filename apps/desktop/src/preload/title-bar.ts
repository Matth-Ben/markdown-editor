import { ipcRenderer } from "electron";

const APP_NAME = "Nexus JDR";
const BAR_HEIGHT = 36;

const ICONS = {
  back: '<path d="M12.5 4 7 9l5.5 5" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
  forward:
    '<path d="M5.5 4 11 9l-5.5 5" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
  minimize: '<path d="M3 9h12" stroke="currentColor" stroke-width="1.2"/>',
  maximize:
    '<rect x="3.5" y="3.5" width="11" height="11" stroke="currentColor" stroke-width="1.2" fill="none"/>',
  restore:
    '<path d="M5.5 5.5h8v8h-8z" stroke="currentColor" stroke-width="1.2" fill="none"/><path d="M5.5 5.5V3.5h8v8h-2" stroke="currentColor" stroke-width="1.2" fill="none"/>',
  close:
    '<path d="M4 4l10 10M14 4 4 14" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/>',
};

function icon(name: keyof typeof ICONS): string {
  return `<svg viewBox="0 0 18 18" width="14" height="14" aria-hidden="true">${ICONS[name]}</svg>`;
}

function navButton(id: string, label: string, iconName: keyof typeof ICONS): string {
  return `<button type="button" id="${id}" class="nexus-titlebar__btn nexus-titlebar__nav" aria-label="${label}" title="${label}">${icon(iconName)}</button>`;
}

function windowButton(id: string, label: string, iconName: keyof typeof ICONS, variant = ""): string {
  return `<button type="button" id="${id}" class="nexus-titlebar__btn nexus-titlebar__window ${variant}" aria-label="${label}" title="${label}">${icon(iconName)}</button>`;
}

const STYLES = `
  body { margin-top: ${BAR_HEIGHT}px; }
  .nexus-titlebar {
    position: fixed;
    top: 0; left: 0; right: 0;
    height: ${BAR_HEIGHT}px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: #0a0a0a;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
    z-index: 2147483647;
    -webkit-app-region: drag;
    user-select: none;
    font-family: system-ui, sans-serif;
  }
  .nexus-titlebar__nav-group { display: flex; align-items: center; gap: 2px; padding-left: 8px; -webkit-app-region: no-drag; }
  .nexus-titlebar__name { color: #a3a3a3; font-size: 12px; letter-spacing: 0.02em; pointer-events: none; }
  .nexus-titlebar__window-group { display: flex; align-items: stretch; height: 100%; -webkit-app-region: no-drag; }
  .nexus-titlebar__btn {
    display: flex; align-items: center; justify-content: center;
    background: transparent; border: none; color: #ededed; cursor: pointer;
    padding: 0;
  }
  .nexus-titlebar__nav { width: 28px; height: 28px; border-radius: 6px; }
  .nexus-titlebar__nav:hover:not(:disabled) { background: rgba(255, 255, 255, 0.1); }
  .nexus-titlebar__nav:disabled { color: #525252; cursor: default; }
  .nexus-titlebar__window { width: 44px; height: 100%; }
  .nexus-titlebar__window:hover { background: rgba(255, 255, 255, 0.1); }
  .nexus-titlebar__window.nexus-titlebar__close:hover { background: #e81123; color: #fff; }
  .nexus-titlebar__btn:focus-visible { outline: 2px solid #22d3ee; outline-offset: -2px; }
`;

export function injectTitleBar(): void {
  const bar = document.createElement("div");
  bar.className = "nexus-titlebar";
  bar.innerHTML = `
    <div class="nexus-titlebar__nav-group">
      ${navButton("nexus-titlebar-back", "Retour en arrière", "back")}
      ${navButton("nexus-titlebar-forward", "Retour en avant", "forward")}
    </div>
    <span class="nexus-titlebar__name">${APP_NAME}</span>
    <div class="nexus-titlebar__window-group">
      ${windowButton("nexus-titlebar-minimize", "Réduire", "minimize")}
      ${windowButton("nexus-titlebar-maximize", "Agrandir", "maximize")}
      ${windowButton("nexus-titlebar-close", "Fermer", "close", "nexus-titlebar__close")}
    </div>
  `;

  const style = document.createElement("style");
  style.textContent = STYLES;

  document.head.appendChild(style);
  // Attachée en dehors de <body> (sibling au niveau de <html>) plutôt qu'à l'intérieur, pour ne
  // pas ajouter un nœud inattendu dans l'arbre que React hydrate et casser l'hydratation.
  document.documentElement.appendChild(bar);

  const backButton = bar.querySelector<HTMLButtonElement>("#nexus-titlebar-back")!;
  const forwardButton = bar.querySelector<HTMLButtonElement>("#nexus-titlebar-forward")!;
  const minimizeButton = bar.querySelector<HTMLButtonElement>("#nexus-titlebar-minimize")!;
  const maximizeButton = bar.querySelector<HTMLButtonElement>("#nexus-titlebar-maximize")!;
  const closeButton = bar.querySelector<HTMLButtonElement>("#nexus-titlebar-close")!;

  backButton.addEventListener("click", () => ipcRenderer.send("titlebar:go-back"));
  forwardButton.addEventListener("click", () => ipcRenderer.send("titlebar:go-forward"));
  minimizeButton.addEventListener("click", () => ipcRenderer.send("titlebar:minimize"));
  maximizeButton.addEventListener("click", () => ipcRenderer.send("titlebar:toggle-maximize"));
  closeButton.addEventListener("click", () => ipcRenderer.send("titlebar:close"));
  bar.addEventListener("dblclick", (event) => {
    if (event.target === bar || (event.target as HTMLElement).classList.contains("nexus-titlebar__name")) {
      ipcRenderer.send("titlebar:toggle-maximize");
    }
  });

  function setMaximized(maximized: boolean): void {
    maximizeButton.innerHTML = icon(maximized ? "restore" : "maximize");
    maximizeButton.setAttribute("aria-label", maximized ? "Restaurer" : "Agrandir");
    maximizeButton.setAttribute("title", maximized ? "Restaurer" : "Agrandir");
  }

  ipcRenderer.on("titlebar:nav-state", (_event, state: { canGoBack: boolean; canGoForward: boolean }) => {
    backButton.disabled = !state.canGoBack;
    forwardButton.disabled = !state.canGoForward;
  });

  ipcRenderer.on("titlebar:window-state", (_event, state: { maximized: boolean }) => {
    setMaximized(state.maximized);
  });

  ipcRenderer
    .invoke("titlebar:get-state")
    .then((state: { maximized: boolean; canGoBack: boolean; canGoForward: boolean }) => {
      setMaximized(state.maximized);
      backButton.disabled = !state.canGoBack;
      forwardButton.disabled = !state.canGoForward;
    });
}
