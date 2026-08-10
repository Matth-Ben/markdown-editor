import { app, BrowserWindow, Menu, ipcMain } from "electron";
import path from "node:path";

const DEV_SERVER_URL = "http://localhost:3000";

// Pas de barre de menu native (File/Edit/View/Window) : l'app a sa propre barre de titre.
Menu.setApplicationMenu(null);

function createMainWindow(): void {
  const mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 720,
    minHeight: 480,
    backgroundColor: "#0a0a0a",
    frame: false,
    webPreferences: {
      preload: path.join(__dirname, "../preload/index.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  const { webContents } = mainWindow;

  function sendNavigationState(): void {
    webContents.send("titlebar:nav-state", {
      canGoBack: webContents.navigationHistory.canGoBack(),
      canGoForward: webContents.navigationHistory.canGoForward(),
    });
  }

  webContents.on("did-navigate", sendNavigationState);
  webContents.on("did-navigate-in-page", sendNavigationState);
  webContents.on("did-finish-load", sendNavigationState);

  mainWindow.on("maximize", () => webContents.send("titlebar:window-state", { maximized: true }));
  mainWindow.on("unmaximize", () => webContents.send("titlebar:window-state", { maximized: false }));

  if (process.env.NODE_ENV === "development") {
    mainWindow.loadURL(DEV_SERVER_URL);
  } else {
    // TODO: démarrer le build "standalone" de apps/web en local et charger son URL.
  }
}

ipcMain.on("titlebar:minimize", (event) => {
  BrowserWindow.fromWebContents(event.sender)?.minimize();
});

ipcMain.on("titlebar:toggle-maximize", (event) => {
  const window = BrowserWindow.fromWebContents(event.sender);
  if (!window) return;
  if (window.isMaximized()) window.unmaximize();
  else window.maximize();
});

ipcMain.on("titlebar:close", (event) => {
  BrowserWindow.fromWebContents(event.sender)?.close();
});

ipcMain.on("titlebar:go-back", (event) => {
  event.sender.navigationHistory.goBack();
});

ipcMain.on("titlebar:go-forward", (event) => {
  event.sender.navigationHistory.goForward();
});

ipcMain.handle("titlebar:get-state", (event) => {
  const window = BrowserWindow.fromWebContents(event.sender);
  return {
    maximized: window?.isMaximized() ?? false,
    canGoBack: event.sender.navigationHistory.canGoBack(),
    canGoForward: event.sender.navigationHistory.canGoForward(),
  };
});

app.whenReady().then(createMainWindow);

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createMainWindow();
  }
});
