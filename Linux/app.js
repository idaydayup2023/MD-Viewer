"use strict";

(function () {
  const $ = (id) => document.getElementById(id);
  const elements = {
    app: $("app"),
    documentTitle: $("document-title"),
    outline: $("outline"),
    stats: $("document-stats"),
    wordCount: $("word-count"),
    fileSize: $("file-size"),
    mathCount: $("math-count"),
    renderTime: $("render-time"),
    welcome: $("welcome"),
    readerArea: $("reader-area"),
    readerFrame: $("reader-frame"),
    sourcePane: $("source-pane"),
    sourceContent: $("source-content"),
    searchBar: $("search-bar"),
    searchInput: $("search-input"),
    searchResult: $("search-result"),
    settings: $("settings-dialog"),
    appearance: $("appearance"),
    contentWidth: $("content-width"),
    widthOutput: $("width-output"),
    fontScale: $("font-scale"),
    fontOutput: $("font-output"),
    rawHTML: $("raw-html"),
    toast: $("toast")
  };

  const saved = JSON.parse(localStorage.getItem("mdviewer.settings") || "{}");
  const state = {
    document: null,
    sourceVisible: false,
    frameReady: false,
    appearance: saved.appearance || "system",
    contentWidth: Number(saved.contentWidth) || 860,
    fontScale: Number(saved.fontScale) || 1,
    allowRawHTML: Boolean(saved.allowRawHTML)
  };
  const systemTheme = matchMedia("(prefers-color-scheme: dark)");
  let toastTimer;
  let renderTimer;

  function resolvedTheme() {
    if (state.appearance === "system") return systemTheme.matches ? "dark" : "light";
    return state.appearance;
  }

  function saveSettings() {
    localStorage.setItem("mdviewer.settings", JSON.stringify({
      appearance: state.appearance,
      contentWidth: state.contentWidth,
      fontScale: state.fontScale,
      allowRawHTML: state.allowRawHTML
    }));
  }

  function applyTheme() {
    document.documentElement.dataset.theme = resolvedTheme();
    scheduleRender();
  }

  function showToast(message) {
    clearTimeout(toastTimer);
    elements.toast.textContent = message;
    elements.toast.classList.add("visible");
    toastTimer = setTimeout(() => elements.toast.classList.remove("visible"), 3600);
  }

  function formatBytes(value) {
    if (!Number.isFinite(value)) return "";
    const units = ["B", "KB", "MB", "GB"];
    let size = value;
    let unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit += 1;
    }
    return `${size >= 10 || unit === 0 ? size.toFixed(0) : size.toFixed(1)} ${units[unit]}`;
  }

  function documentOptions() {
    return {
      theme: resolvedTheme(),
      contentWidth: state.contentWidth,
      fontScale: state.fontScale,
      allowRawHTML: state.allowRawHTML,
      baseURL: state.document ? state.document.baseURL : undefined
    };
  }

  function renderDocument() {
    if (!state.document || !state.frameReady) return;
    const renderer = elements.readerFrame.contentWindow &&
      elements.readerFrame.contentWindow.MDViewer;
    if (!renderer) return;
    renderer.renderDocument(state.document.markdown, documentOptions());
  }

  function scheduleRender() {
    clearTimeout(renderTimer);
    renderTimer = setTimeout(renderDocument, 40);
  }

  function renderOutline(headings) {
    elements.outline.replaceChildren();
    if (!headings || headings.length === 0) {
      const empty = document.createElement("div");
      empty.className = "empty-outline";
      empty.textContent = "文档没有标题";
      elements.outline.append(empty);
      return;
    }

    for (const heading of headings) {
      const button = document.createElement("button");
      button.className = "outline-button";
      button.textContent = heading.title;
      button.title = heading.title;
      button.style.paddingLeft = `${8 + Math.max(0, heading.level - 1) * 11}px`;
      button.addEventListener("click", () => {
        elements.readerFrame.contentWindow.MDViewer.scrollToHeading(heading.id);
        document.body.classList.remove("sidebar-open");
      });
      elements.outline.append(button);
    }
  }

  function updateStats(report) {
    elements.wordCount.textContent = `${report.wordCount || 0} 字词`;
    elements.mathCount.textContent = `${report.mathCount || 0} 个公式`;
    elements.renderTime.textContent = `${Math.round(report.milliseconds || 0)} ms`;
  }

  function setDocument(documentData) {
    if (!documentData) return;
    state.document = documentData;
    elements.documentTitle.textContent = documentData.title;
    elements.documentTitle.title = documentData.path;
    document.title = `${documentData.title} — MD Viewer`;
    elements.sourceContent.textContent = documentData.markdown;
    elements.fileSize.textContent = formatBytes(documentData.byteCount);
    elements.welcome.hidden = true;
    elements.readerArea.hidden = false;
    elements.searchBar.hidden = false;
    elements.stats.hidden = false;
    document.querySelectorAll(".document-action").forEach((item) => { item.hidden = false; });
    renderOutline([]);
    renderDocument();
  }

  async function perform(action) {
    try {
      const result = await action();
      if (result) setDocument(result);
    } catch (error) {
      showToast(error && error.message ? error.message : String(error));
    }
  }

  function openDocument() {
    perform(() => window.mdViewer.chooseDocument());
  }

  function reloadDocument() {
    if (state.document) {
      perform(() => window.mdViewer.reloadDocument(state.document.path));
    }
  }

  async function printDocument() {
    if (!state.document) return;
    try {
      const result = await window.mdViewer.printDocument({
        title: state.document.title,
        markdown: state.document.markdown,
        baseURL: state.document.baseURL,
        options: documentOptions()
      });
      if (result && !result.success &&
          result.failureReason && !/cancel/i.test(result.failureReason)) {
        showToast(`打印失败：${result.failureReason}`);
      }
    } catch (error) {
      showToast(`打印失败：${error && error.message ? error.message : String(error)}`);
    }
  }

  function toggleSource() {
    if (!state.document) return;
    state.sourceVisible = !state.sourceVisible;
    elements.sourcePane.hidden = !state.sourceVisible;
    elements.readerArea.classList.toggle("with-source", state.sourceVisible);
    $("source-button").classList.toggle("selected", state.sourceVisible);
  }

  function adjustZoom(amount) {
    state.fontScale = Math.min(1.5, Math.max(.8, state.fontScale + amount));
    elements.fontScale.value = String(state.fontScale);
    elements.fontOutput.value = `${Math.round(state.fontScale * 100)}%`;
    saveSettings();
    scheduleRender();
  }

  function openSettings() {
    if (!elements.settings.open) elements.settings.showModal();
  }

  function handleCommand(command) {
    const commands = {
      open: openDocument,
      reload: reloadDocument,
      print: printDocument,
      "focus-search": () => elements.searchInput.focus(),
      "toggle-source": toggleSource,
      "zoom-in": () => adjustZoom(.1),
      "zoom-out": () => adjustZoom(-.1),
      "zoom-reset": () => {
        state.fontScale = 1;
        elements.fontScale.value = "1";
        elements.fontOutput.value = "100%";
        saveSettings();
        scheduleRender();
      },
      settings: openSettings
    };
    if (commands[command]) commands[command]();
  }

  function initializeControls() {
    elements.appearance.value = state.appearance;
    elements.contentWidth.value = String(state.contentWidth);
    elements.widthOutput.value = `${state.contentWidth} px`;
    elements.fontScale.value = String(state.fontScale);
    elements.fontOutput.value = `${Math.round(state.fontScale * 100)}%`;
    elements.rawHTML.checked = state.allowRawHTML;

    $("open-button").addEventListener("click", openDocument);
    $("welcome-open").addEventListener("click", openDocument);
    $("reload-button").addEventListener("click", reloadDocument);
    $("print-button").addEventListener("click", printDocument);
    $("source-button").addEventListener("click", toggleSource);
    $("settings-button").addEventListener("click", openSettings);
    $("sample-button").addEventListener("click", () => perform(() => window.mdViewer.openSample()));
    $("sidebar-button").addEventListener("click", () => {
      if (innerWidth <= 680) {
        document.body.classList.toggle("sidebar-open");
      } else {
        document.body.classList.toggle("sidebar-collapsed");
      }
    });

    elements.appearance.addEventListener("change", () => {
      state.appearance = elements.appearance.value;
      saveSettings();
      applyTheme();
    });
    elements.contentWidth.addEventListener("input", () => {
      state.contentWidth = Number(elements.contentWidth.value);
      elements.widthOutput.value = `${state.contentWidth} px`;
      saveSettings();
      scheduleRender();
    });
    elements.fontScale.addEventListener("input", () => {
      state.fontScale = Number(elements.fontScale.value);
      elements.fontOutput.value = `${Math.round(state.fontScale * 100)}%`;
      saveSettings();
      scheduleRender();
    });
    elements.rawHTML.addEventListener("change", () => {
      state.allowRawHTML = elements.rawHTML.checked;
      saveSettings();
      scheduleRender();
    });

    elements.searchInput.addEventListener("input", async () => {
      const query = elements.searchInput.value.trim();
      elements.searchResult.textContent = query ? "查找中" : "";
      await window.mdViewer.find(query);
      if (query) elements.searchResult.textContent = "";
    });
    elements.searchInput.addEventListener("keydown", async (event) => {
      if (event.key === "Enter") await window.mdViewer.find(elements.searchInput.value.trim());
      if (event.key === "Escape") {
        elements.searchInput.value = "";
        elements.searchResult.textContent = "";
        await window.mdViewer.find("");
      }
    });

    systemTheme.addEventListener("change", () => {
      if (state.appearance === "system") applyTheme();
    });
  }

  window.addEventListener("message", async (event) => {
    if (event.source !== elements.readerFrame.contentWindow || !event.data) return;
    if (event.data.channel === "mdviewer-renderer") {
      const payload = event.data.payload || {};
      if (payload.type === "ready") {
        state.frameReady = true;
        renderDocument();
      } else if (payload.type === "rendered") {
        renderOutline(payload.headings || []);
        updateStats(payload);
      } else if (payload.type === "error") {
        showToast(payload.message || "渲染失败");
      }
    } else if (event.data.channel === "mdviewer-link" && event.data.url) {
      await perform(() => window.mdViewer.openLink(event.data.url));
    }
  });

  elements.readerFrame.addEventListener("load", () => {
    state.frameReady = true;
    renderDocument();
  });

  window.mdViewer.onCommand(handleCommand);
  window.mdViewer.onOpenPath((filePath) => perform(() => window.mdViewer.openPath(filePath)));
  initializeControls();
  applyTheme();
})();
