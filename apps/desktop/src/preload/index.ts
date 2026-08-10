import { contextBridge } from "electron";
import { injectTitleBar } from "./title-bar";

// Les bridges audio / filesystem seront exposés ici au fur et à mesure
// (voir packages/core/src/triggers pour l'interface TriggerService côté renderer).
contextBridge.exposeInMainWorld("electronAPI", {});

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", injectTitleBar, { once: true });
} else {
  injectTitleBar();
}
