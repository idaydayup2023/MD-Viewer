import Foundation

enum RendererBundle {
    private static let vendorScripts = [
        "markdown-it.min",
        "markdown-it-footnote.min",
        "markdown-it-task-lists.min",
        "markdown-it-mark.min",
        "markdown-it-sub.min",
        "markdown-it-sup.min",
        "highlight.min",
        "mermaid.min"
    ]

    static let html: String = {
        let style = resource("style", extension: "css")
        let highlightLight = resource("highlight-light", extension: "css")
        let highlightDark = resource("highlight-dark", extension: "css")
        let libraries = vendorScripts
            .map { scriptTag(resource($0, extension: "js")) }
            .joined(separator: "\n")
        let mathJax = scriptTag(resource("mathjax-tex-mml-svg", extension: "js"))
        let renderer = scriptTag(resource("renderer", extension: "js"))

        return """
        <!doctype html>
        <html lang="zh-Hans" data-theme="light">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <style>\(style)</style>
          <style>\(highlightLight)</style>
          <style>
            :root[data-theme="dark"] .hljs { color: #c9d1d9; background: #0d1117; }
            @media (prefers-color-scheme: dark) {
              :root[data-theme="system"] .hljs { color: #c9d1d9; background: #0d1117; }
            }
          </style>
          \(libraries)
          <script>
            window.MathJax = {
              loader: {
                failed(error) {
                  window.__mdvMathJaxError = error && error.message
                    ? error.message
                    : String(error);
                  console.error("MathJax loader failed", error);
                }
              },
              tex: {
                inlineMath: [["\\\\(", "\\\\)"]],
                displayMath: [["\\\\[", "\\\\]"]],
                processEscapes: true,
                processEnvironments: true,
                tags: "ams"
              },
              svg: { fontCache: "local" },
              options: {
                enableMenu: true,
                enableSpeech: false,
                enableBraille: false,
                enableExplorer: false,
                menuOptions: { settings: { enrich: false } },
                skipHtmlTags: ["script", "noscript", "style", "textarea", "pre", "code"]
              },
              startup: {
                typeset: false,
                ready() {
                  try {
                    MathJax.startup.defaultReady();
                  } catch (error) {
                    window.__mdvMathJaxError = error && error.message
                      ? error.message
                      : String(error);
                    throw error;
                  }
                }
              }
            };
          </script>
          \(mathJax)
        </head>
        <body>
          <article id="content" aria-live="polite"></article>
          \(renderer)
        </body>
        </html>
        """
    }()

    private static func resource(_ name: String, extension ext: String) -> String {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Renderer/vendor"),
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Renderer"),
            Bundle.main.url(forResource: name, withExtension: ext)
        ]
        guard let url = candidates.compactMap({ $0 }).first,
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing renderer resource: \(name).\(ext)")
            return ""
        }
        return value
    }

    private static func scriptTag(_ source: String) -> String {
        "<script>\(source.replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive))</script>"
    }
}
