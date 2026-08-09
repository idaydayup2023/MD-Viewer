"use strict";

(function () {
  const originalRender = window.MDViewer.renderDocument;
  window.MDViewer.renderDocument = function (markdown, options) {
    if (options && options.baseURL) {
      document.getElementById("document-base").href = options.baseURL;
    }
    return originalRender(markdown, options);
  };

  document.addEventListener("click", (event) => {
    if (event.defaultPrevented || event.button !== 0) return;
    const target = event.target;
    const anchor = target && target.closest ? target.closest("a[href]") : null;
    if (!anchor) return;
    event.preventDefault();
    event.stopPropagation();
    window.parent.postMessage({
      channel: "mdviewer-link",
      url: anchor.href
    }, "*");
  });
})();
