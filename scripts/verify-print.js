"use strict";

const { app, BrowserWindow } = require("electron");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const projectRoot = path.resolve(__dirname, "..");
const outputDirectory = path.join(projectRoot, "tmp", "pdfs");
const outputPath = path.join(outputDirectory, "MD-Viewer-print-verification.pdf");

function withTimeout(promise, label, milliseconds = 30000) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(
      () => reject(new Error(`${label}超时`)),
      milliseconds
    ))
  ]);
}

async function verifyPrint() {
  const window = new BrowserWindow({
    show: false,
    width: 794,
    height: 1123,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      backgroundThrottling: false
    }
  });

  try {
    process.stderr.write("[print-check] loading renderer\n");
    await withTimeout(
      window.loadFile(path.join(projectRoot, "Linux", "reader.html")),
      "加载打印渲染器"
    );
    const documentPath = path.join(
      projectRoot,
      "MDViewer",
      "Resources",
      "FeatureShowcase.md"
    );
    const markdown = fs.readFileSync(documentPath, "utf8");
    const baseURL = pathToFileURL(path.dirname(documentPath) + path.sep).href;
    const script = `
      (async () => {
        document.getElementById("document-base").href = ${JSON.stringify(baseURL)};
        await window.MDViewer.renderDocument(${JSON.stringify(markdown)}, {
          theme: "light",
          contentWidth: 860,
          fontScale: 1,
          allowRawHTML: false,
          usesDocumentResourceScheme: false,
          handlesLinksViaBridge: false
        });
        await window.MDViewer.preparePrint();
        return {
          math: document.querySelectorAll("mjx-container").length,
          diagrams: document.querySelectorAll(".mermaid svg").length,
          codeBlocks: document.querySelectorAll("pre code").length,
          tables: document.querySelectorAll("table").length,
          printFontSize: getComputedStyle(document.documentElement).fontSize
        };
      })()
    `;
    process.stderr.write("[print-check] rendering document\n");
    const stageTimer = setInterval(async () => {
      if (window.isDestroyed()) return;
      try {
        const stage = await window.webContents.executeJavaScript(`({
          render: document.documentElement.dataset.renderStage || "waiting",
          print: document.documentElement.dataset.printStage || "waiting"
        })`, true);
        process.stderr.write(`[print-check] stage ${JSON.stringify(stage)}\n`);
      } catch (_) {}
    }, 2000);
    let metrics;
    try {
      metrics = await withTimeout(
        window.webContents.executeJavaScript(script, true),
        "渲染打印文档"
      );
    } finally {
      clearInterval(stageTimer);
    }
    process.stderr.write("[print-check] generating PDF\n");
    const pdf = await withTimeout(window.webContents.printToPDF({
      printBackground: true,
      preferCSSPageSize: true,
      pageSize: "A4",
      margins: { top: 0, bottom: 0, left: 0, right: 0 }
    }), "生成打印 PDF");
    fs.mkdirSync(outputDirectory, { recursive: true });
    fs.writeFileSync(outputPath, pdf);
    process.stdout.write(`${JSON.stringify({ outputPath, ...metrics })}\n`);
  } finally {
    if (!window.isDestroyed()) window.destroy();
  }
}

app.whenReady()
  .then(verifyPrint)
  .then(() => app.quit())
  .catch((error) => {
    process.stderr.write(`${error.stack || error}\n`);
    app.exit(1);
  });
