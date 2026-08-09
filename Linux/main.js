"use strict";

const { app, BrowserWindow, dialog, ipcMain, Menu, shell } = require("electron");
const fs = require("node:fs");
const path = require("node:path");
const { fileURLToPath, pathToFileURL } = require("node:url");

const documentExtensions = new Set([".md", ".markdown", ".mdown", ".mkd", ".txt"]);
let mainWindow;
let queuedDocument;

function isDocumentPath(filePath) {
  return typeof filePath === "string" &&
    documentExtensions.has(path.extname(filePath).toLowerCase());
}

function argumentDocument(argv) {
  return argv.find((value) => isDocumentPath(value) && fs.existsSync(value));
}

function decodeUTF32(buffer, littleEndian) {
  const start = 4;
  const codePoints = [];
  for (let index = start; index + 3 < buffer.length; index += 4) {
    const value = littleEndian
      ? buffer.readUInt32LE(index)
      : buffer.readUInt32BE(index);
    if (value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff)) {
      throw new Error("UTF-32 文档包含无效字符");
    }
    codePoints.push(value);
  }
  const chunks = [];
  for (let index = 0; index < codePoints.length; index += 4096) {
    chunks.push(String.fromCodePoint(...codePoints.slice(index, index + 4096)));
  }
  return chunks.join("");
}

function decodeText(buffer) {
  if (buffer.length >= 4 && buffer.subarray(0, 4).equals(Buffer.from([0xff, 0xfe, 0x00, 0x00]))) {
    return decodeUTF32(buffer, true);
  }
  if (buffer.length >= 4 && buffer.subarray(0, 4).equals(Buffer.from([0x00, 0x00, 0xfe, 0xff]))) {
    return decodeUTF32(buffer, false);
  }
  if (buffer.length >= 2 && buffer[0] === 0xff && buffer[1] === 0xfe) {
    return new TextDecoder("utf-16le", { fatal: true }).decode(buffer.subarray(2));
  }
  if (buffer.length >= 2 && buffer[0] === 0xfe && buffer[1] === 0xff) {
    const swapped = Buffer.allocUnsafe(buffer.length - 2);
    for (let index = 2; index + 1 < buffer.length; index += 2) {
      swapped[index - 2] = buffer[index + 1];
      swapped[index - 1] = buffer[index];
    }
    return new TextDecoder("utf-16le", { fatal: true }).decode(swapped);
  }

  try {
    return new TextDecoder("utf-8", { fatal: true }).decode(buffer);
  } catch (_) {
    return new TextDecoder("gb18030", { fatal: true }).decode(buffer);
  }
}

async function readDocument(filePath) {
  if (!isDocumentPath(filePath)) throw new Error("请选择 Markdown 或纯文本文件。");
  const resolved = path.resolve(filePath);
  const [buffer, stat] = await Promise.all([
    fs.promises.readFile(resolved),
    fs.promises.stat(resolved)
  ]);
  const directoryURL = pathToFileURL(path.dirname(resolved) + path.sep).href;
  return {
    path: resolved,
    title: path.basename(resolved),
    markdown: decodeText(buffer),
    byteCount: stat.size,
    baseURL: directoryURL
  };
}

async function chooseDocument() {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: "打开 Markdown 文件",
    properties: ["openFile"],
    filters: [
      { name: "Markdown", extensions: ["md", "markdown", "mdown", "mkd"] },
      { name: "纯文本", extensions: ["txt"] }
    ]
  });
  if (result.canceled || !result.filePaths[0]) return null;
  return readDocument(result.filePaths[0]);
}

function sendCommand(command) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send("app:command", command);
  }
}

async function printDocument(payload) {
  if (!payload || typeof payload.markdown !== "string") {
    throw new Error("没有可打印的文档。")
  }

  const printWindow = new BrowserWindow({
    show: false,
    parent: mainWindow,
    width: 794,
    height: 1123,
    backgroundColor: "#ffffff",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      backgroundThrottling: false
    }
  });

  try {
    await printWindow.loadFile(path.join(__dirname, "reader.html"));
    const title = typeof payload.title === "string" ? payload.title : "MD Viewer";
    const baseURL = typeof payload.baseURL === "string" ? payload.baseURL : "";
    const options = {
      ...(payload.options || {}),
      theme: "light",
      handlesLinksViaBridge: false
    };
    const script = `
      (async () => {
        document.title = ${JSON.stringify(title)};
        const base = document.getElementById("document-base");
        if (base && ${JSON.stringify(baseURL)}) base.href = ${JSON.stringify(baseURL)};
        await window.MDViewer.renderDocument(
          ${JSON.stringify(payload.markdown)},
          ${JSON.stringify(options)}
        );
        return await window.MDViewer.preparePrint();
      })()
    `;
    await printWindow.webContents.executeJavaScript(script, true);

    return await new Promise((resolve) => {
      printWindow.webContents.print({
        silent: false,
        printBackground: true,
        color: true,
        landscape: false,
        pageSize: "A4",
        margins: { marginType: "none" }
      }, (success, failureReason) => {
        resolve({ success, failureReason: failureReason || "" });
      });
    });
  } finally {
    if (!printWindow.isDestroyed()) printWindow.destroy();
  }
}

function buildMenu() {
  const template = [
    {
      label: "文件",
      submenu: [
        { label: "打开…", accelerator: "CmdOrCtrl+O", click: () => sendCommand("open") },
        { label: "重新载入", accelerator: "CmdOrCtrl+R", click: () => sendCommand("reload") },
        { type: "separator" },
        { label: "打印…", accelerator: "CmdOrCtrl+P", click: () => sendCommand("print") },
        { type: "separator" },
        { role: "quit", label: "退出" }
      ]
    },
    {
      label: "编辑",
      submenu: [
        { role: "copy", label: "复制" },
        { role: "selectAll", label: "全选" },
        { type: "separator" },
        { label: "查找", accelerator: "CmdOrCtrl+F", click: () => sendCommand("focus-search") }
      ]
    },
    {
      label: "阅读",
      submenu: [
        {
          label: "显示/隐藏源文",
          accelerator: "CmdOrCtrl+\\",
          click: () => sendCommand("toggle-source")
        },
        { type: "separator" },
        { label: "放大", accelerator: "CmdOrCtrl+Plus", click: () => sendCommand("zoom-in") },
        { label: "缩小", accelerator: "CmdOrCtrl+-", click: () => sendCommand("zoom-out") },
        { label: "实际大小", accelerator: "CmdOrCtrl+0", click: () => sendCommand("zoom-reset") },
        { type: "separator" },
        { label: "阅读设置…", accelerator: "CmdOrCtrl+,", click: () => sendCommand("settings") }
      ]
    }
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    title: "MD Viewer",
    width: 1180,
    height: 780,
    minWidth: 760,
    minHeight: 520,
    backgroundColor: "#fbfbfc",
    icon: path.join(__dirname, "assets", "icon.png"),
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true
    }
  });

  mainWindow.loadFile(path.join(__dirname, "index.html"));
  mainWindow.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  mainWindow.webContents.on("will-navigate", (event, url) => {
    if (url !== mainWindow.webContents.getURL()) event.preventDefault();
  });
  mainWindow.webContents.on("did-finish-load", () => {
    if (queuedDocument) {
      mainWindow.webContents.send("document:open-path", queuedDocument);
      queuedDocument = undefined;
    }
  });
}

function registerIPC() {
  ipcMain.handle("document:choose", () => chooseDocument());
  ipcMain.handle("document:reload", (_, filePath) => readDocument(filePath));
  ipcMain.handle("document:sample", () => {
    return readDocument(path.join(
      __dirname,
      "..",
      "MDViewer",
      "Resources",
      "FeatureShowcase.md"
    ));
  });
  ipcMain.handle("link:open", async (_, value) => {
    const url = new URL(value);
    if (["http:", "https:", "mailto:"].includes(url.protocol)) {
      await shell.openExternal(url.href);
      return null;
    }
    if (url.protocol === "file:") {
      const filePath = fileURLToPath(url);
      if (isDocumentPath(filePath)) return readDocument(filePath);
      await shell.openPath(filePath);
      return null;
    }
    throw new Error("已阻止不受支持的链接协议。");
  });
  ipcMain.handle("document:from-path", (_, filePath) => readDocument(filePath));
  ipcMain.handle("document:print", (_, payload) => printDocument(payload));
  ipcMain.handle("page:find", (_, query) => {
    if (!mainWindow || mainWindow.isDestroyed()) return 0;
    if (!query) {
      mainWindow.webContents.stopFindInPage("clearSelection");
      return 0;
    }
    return mainWindow.webContents.findInPage(query, {
      forward: true,
      findNext: false,
      matchCase: false
    });
  });
}

const hasLock = app.requestSingleInstanceLock();
if (!hasLock) {
  app.quit();
} else {
  app.on("second-instance", (_, argv) => {
    const filePath = argumentDocument(argv);
    if (filePath) {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send("document:open-path", path.resolve(filePath));
      } else {
        queuedDocument = path.resolve(filePath);
      }
    }
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });

  app.whenReady().then(() => {
    queuedDocument = argumentDocument(process.argv.slice(1));
    registerIPC();
    buildMenu();
    createWindow();
  });

  app.on("window-all-closed", () => app.quit());
}
