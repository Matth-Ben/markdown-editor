import { contextBridge } from "electron";

// Les bridges audio / filesystem seront exposés ici au fur et à mesure
// (voir packages/core/src/triggers pour l'interface TriggerService côté renderer).
contextBridge.exposeInMainWorld("electronAPI", {});
