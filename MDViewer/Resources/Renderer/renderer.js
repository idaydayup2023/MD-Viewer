(function () {
  "use strict";

  const state = {
    markdown: "",
    options: {},
    mathCount: 0,
    diagramCount: 0
  };
  let pendingRender = null;
  let renderLoop = null;

  function post(type, payload) {
    const handler = window.webkit && window.webkit.messageHandlers &&
      window.webkit.messageHandlers.bridge;
    if (handler) handler.postMessage({ type, ...payload });
  }

  document.addEventListener("click", (event) => {
    if (!state.options.handlesLinksViaBridge || event.defaultPrevented || event.button !== 0) {
      return;
    }

    const target = event.target;
    const anchor = target && target.closest ? target.closest("a[href]") : null;
    if (!anchor) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    post("linkActivated", { url: anchor.href });
  });

  function escapeHTML(value) {
    return value
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;");
  }

  function protectMath(source) {
    const code = [];
    const math = [];
    const nonce = "MDV" + Math.random().toString(36).slice(2).toUpperCase();

    // Markdown code must win over formula delimiters.
    source = source.replace(
      /(^|\n)( {0,3})(`{3,}|~{3,})[^\n]*(?:\n[\s\S]*?\n\2\3[ \t]*(?=\n|$)|$)/g,
      (match) => {
        const token = `${nonce}CODE${code.length}TOKEN`;
        code.push(match);
        return token;
      }
    );
    source = source.replace(/(`+)([\s\S]*?)\1/g, (match) => {
      const token = `${nonce}CODE${code.length}TOKEN`;
      code.push(match);
      return token;
    });

    function save(tex, display) {
      const index = math.length;
      const token = `${nonce}${display ? "DISPLAY" : "INLINE"}${index}TOKEN`;
      math.push({ tex, display, token });
      return token;
    }

    source = source.replace(/(^|[^\x5c])\$\$([\s\S]+?)(?<!\x5c)\$\$/g,
      (_, prefix, tex) => prefix + save(tex.trim(), true));
    source = source.replace(/\x5c\[([\s\S]+?)\x5c\]/g,
      (_, tex) => save(tex.trim(), true));
    source = source.replace(/\x5c\(([\s\S]+?)\x5c\)/g,
      (_, tex) => save(tex.trim(), false));

    // Pandoc-like rules avoid treating "$12 and $20" as mathematics.
    source = source.replace(/(^|[^\x5c$])\$([^\s$\n](?:\x5c.|[^$\n])*?[^\s$\n]|[^\s$\n])\$(?!\d)/g,
      (_, prefix, tex) => prefix + save(tex, false));

    code.forEach((value, index) => {
      source = source.replace(`${nonce}CODE${index}TOKEN`, value);
    });
    return { source, math };
  }

  function restoreMath(html, entries) {
    for (const entry of entries) {
      const tex = escapeHTML(entry.tex);
      if (entry.display) {
        const value = `<div class="math-block">\\[${tex}\\]</div>`;
        html = html.replace(`<p>${entry.token}</p>`, value);
        html = html.replace(entry.token, value);
      } else {
        html = html.replace(entry.token, `<span class="math-inline">\\(${tex}\\)</span>`);
      }
    }
    return html;
  }

  function slugify(value, used) {
    let base = value
      .toLowerCase()
      .trim()
      .replace(/<[^>]+>/g, "")
      .replace(/[^\p{L}\p{N}\s_-]/gu, "")
      .replace(/\s+/g, "-") || "section";
    let slug = base;
    let suffix = 2;
    while (used.has(slug)) slug = `${base}-${suffix++}`;
    used.add(slug);
    return slug;
  }

  function makeMarkdown(options) {
    const usedSlugs = new Set();
    const headings = [];
    const md = window.markdownit({
      html: Boolean(options.allowRawHTML),
      linkify: true,
      typographer: true,
      breaks: false,
      highlight(str, language) {
        if (language && window.hljs.getLanguage(language)) {
          try {
            return window.hljs.highlight(str, {
              language,
              ignoreIllegals: true
            }).value;
          } catch (_) {}
        }
        return escapeHTML(str);
      }
    });

    md.use(window.markdownitFootnote)
      .use(window.markdownitTaskLists, { enabled: false, label: true })
      .use(window.markdownitMark)
      .use(window.markdownitSub)
      .use(window.markdownitSup);

    const documentResourceURL = (value) => {
      if (!options.usesDocumentResourceScheme ||
          !value || value.startsWith("#") ||
          /^[a-z][a-z0-9+.-]*:/i.test(value) ||
          value.startsWith("//") || value.startsWith("/")) {
        return value;
      }
      return `mdviewer-resource://document/resource?path=${encodeURIComponent(value)}`;
    };

    const originalImage = md.renderer.rules.image;
    md.renderer.rules.image = function (tokens, index, rendererOptions, env, self) {
      const sourceIndex = tokens[index].attrIndex("src");
      if (sourceIndex >= 0) {
        tokens[index].attrs[sourceIndex][1] =
          documentResourceURL(tokens[index].attrs[sourceIndex][1]);
      }
      return originalImage
        ? originalImage(tokens, index, rendererOptions, env, self)
        : self.renderToken(tokens, index, rendererOptions);
    };

    const originalLinkOpen = md.renderer.rules.link_open;
    md.renderer.rules.link_open = function (tokens, index, rendererOptions, env, self) {
      const hrefIndex = tokens[index].attrIndex("href");
      if (hrefIndex >= 0) {
        tokens[index].attrs[hrefIndex][1] =
          documentResourceURL(tokens[index].attrs[hrefIndex][1]);
      }
      return originalLinkOpen
        ? originalLinkOpen(tokens, index, rendererOptions, env, self)
        : self.renderToken(tokens, index, rendererOptions);
    };

    const originalHeadingOpen = md.renderer.rules.heading_open;
    md.renderer.rules.heading_open = function (tokens, index, rendererOptions, env, self) {
      const inline = tokens[index + 1];
      const title = inline && inline.type === "inline" ? inline.content : "";
      const level = Number(tokens[index].tag.slice(1));
      const id = slugify(title, usedSlugs);
      tokens[index].attrSet("id", id);
      headings.push({ id, level, title });
      return originalHeadingOpen
        ? originalHeadingOpen(tokens, index, rendererOptions, env, self)
        : self.renderToken(tokens, index, rendererOptions);
    };

    return { md, headings };
  }

  async function renderDiagrams() {
    const blocks = Array.from(document.querySelectorAll("pre > code.language-mermaid"));
    state.diagramCount = blocks.length;
    blocks.forEach((code, index) => {
      const container = document.createElement("div");
      container.className = "mermaid";
      container.id = `mdv-mermaid-${index}`;
      container.textContent = code.textContent;
      code.parentElement.replaceWith(container);
    });

    if (!blocks.length || !window.mermaid) return;
    const dark = document.documentElement.dataset.theme === "dark";
    window.mermaid.initialize({
      startOnLoad: false,
      securityLevel: "strict",
      theme: dark ? "dark" : "neutral",
      fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    });
    try {
      await window.mermaid.run({ querySelector: ".mermaid" });
    } catch (error) {
      post("error", { message: `图表渲染失败：${error.message}` });
    }
  }

  async function waitForMathJaxReady() {
    const deadline = performance.now() + 10000;
    while (typeof window.MathJax.typesetPromise !== "function") {
      if (window.__mdvMathJaxError) {
        throw new Error(window.__mdvMathJaxError);
      }
      if (performance.now() >= deadline) {
        throw new Error("MathJax 排版引擎初始化超时");
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
  }

  async function renderDocumentNow(markdown, options) {
    const start = performance.now();
    document.documentElement.dataset.renderStage = "markdown";
    state.markdown = markdown;
    state.options = options || {};
    document.documentElement.dataset.theme = options.theme || "light";
    document.documentElement.style.setProperty("--content-width", `${options.contentWidth || 860}px`);
    document.documentElement.style.setProperty("--font-scale", options.fontScale || 1);

    // YAML front matter is metadata, not document body.
    const bodyMarkdown = markdown.replace(/^---[ \t]*\r?\n[\s\S]*?\r?\n---[ \t]*(?:\r?\n|$)/, "");
    const protectedResult = protectMath(bodyMarkdown);
    state.mathCount = protectedResult.math.length;
    const parser = makeMarkdown(options);
    let html = parser.md.render(protectedResult.source);
    html = restoreMath(html, protectedResult.math);
    const article = document.getElementById("content");
    article.innerHTML = html;

    const words = markdown.match(/[\p{Script=Han}]|[\p{L}\p{N}]+/gu) || [];
    post("rendered", {
      headings: parser.headings,
      milliseconds: performance.now() - start,
      wordCount: words.length,
      mathCount: state.mathCount,
      diagramCount: document.querySelectorAll("pre > code.language-mermaid").length
    });

    document.documentElement.dataset.renderStage = "diagrams";
    await renderDiagrams();
    document.documentElement.dataset.renderStage = "math";
    try {
      // The complete offline component installs its public API
      // asynchronously. Wait for that API directly instead of awaiting the
      // startup promise from inside a dynamic WKWebView render.
      await waitForMathJaxReady();
      if (typeof window.MathJax.typesetClear === "function") {
        window.MathJax.typesetClear([article]);
      }
      await window.MathJax.typesetPromise([article]);
    } catch (error) {
      post("error", { message: `公式渲染失败：${error.message}` });
    }

    post("rendered", {
      headings: parser.headings,
      milliseconds: performance.now() - start,
      wordCount: words.length,
      mathCount: state.mathCount,
      diagramCount: state.diagramCount
    });
    document.documentElement.dataset.renderStage = "ready";
  }

  function renderDocument(markdown, options) {
    // MathJax and Mermaid mutate shared DOM/runtime state asynchronously.
    // Keep one render active and coalesce rapid setting changes to the newest
    // request so an older typeset pass cannot clear a newer document.
    pendingRender = { markdown, options };
    if (renderLoop) return renderLoop;

    renderLoop = (async () => {
      while (pendingRender) {
        const request = pendingRender;
        pendingRender = null;
        await renderDocumentNow(request.markdown, request.options);
      }
    })().finally(() => {
      renderLoop = null;
    });
    return renderLoop;
  }

  function scrollToHeading(id) {
    const element = document.getElementById(id);
    if (element) element.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  async function preparePrint() {
    document.documentElement.dataset.printStage = "render";
    if (renderLoop) await renderLoop;
    document.documentElement.dataset.printStage = "fonts";
    if (document.fonts && document.fonts.ready) {
      await Promise.race([
        document.fonts.ready,
        new Promise((resolve) => setTimeout(resolve, 1500))
      ]);
    }

    const pendingImages = Array.from(document.images)
      .filter((image) => !image.complete)
      .map((image) => new Promise((resolve) => {
        const finish = () => resolve();
        image.addEventListener("load", finish, { once: true });
        image.addEventListener("error", finish, { once: true });
      }));
    if (pendingImages.length) {
      document.documentElement.dataset.printStage = "images";
      await Promise.race([
        Promise.all(pendingImages),
        new Promise((resolve) => setTimeout(resolve, 5000))
      ]);
    }

    document.documentElement.dataset.printStage = "layout";
    document.documentElement.classList.add("printing");
    // Hidden Electron print windows may suspend requestAnimationFrame even
    // when background throttling is disabled. Keep the two-frame path for
    // visible Apple views, with a short timer fallback for headless printing.
    await new Promise((resolve) => {
      let completed = false;
      const finish = () => {
        if (completed) return;
        completed = true;
        resolve();
      };
      requestAnimationFrame(() => requestAnimationFrame(finish));
      setTimeout(finish, 120);
    });
    document.documentElement.dataset.printStage = "ready";
    return true;
  }

  function finishPrint() {
    document.documentElement.classList.remove("printing");
  }

  window.MDViewer = {
    renderDocument,
    scrollToHeading,
    preparePrint,
    finishPrint
  };
  // Let inline vendor bundles finish their own document-load startup before
  // Swift asks them to render dynamic content. In particular, MathJax 4 does
  // not install its public typesetting API until this phase has completed.
  if (document.readyState === "complete") {
    post("ready", {});
  } else {
    window.addEventListener("load", () => post("ready", {}), { once: true });
  }
})();
