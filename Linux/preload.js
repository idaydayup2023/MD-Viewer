"use strict";

const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("mdViewer", {
  chooseDocument: () => ipcRenderer.invoke("document:choose"),
  reloadDocument: (filePath) => ipcRenderer.invoke("document:reload", filePath),
  openSample: () => ipcRenderer.invoke("document:sample"),
  openLink: (url) => ipcRenderer.invoke("link:open", url),
  openPath: (filePath) => ipcRenderer.invoke("document:from-path", filePath),
  printDocument: (payload) => ipcRenderer.invoke("document:print", payload),
  find: (query) => ipcRenderer.invoke("page:find", query),
  onCommand: (callback) => {
    const listener = (_, command) => callback(command);
    ipcRenderer.on("app:command", listener);
  },
  onOpenPath: (callback) => {
    const listener = (_, filePath) => callback(filePath);
    ipcRenderer.on("document:open-path", listener);
  }
});
