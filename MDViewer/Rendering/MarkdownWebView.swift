import SwiftUI
@preconcurrency import WebKit

#if os(macOS)
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
#else
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

struct MarkdownWebView: PlatformViewRepresentable {
    @ObservedObject var model: ReaderModel
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView { makeView(context: context) }
    func updateNSView(_ view: WKWebView, context: Context) { updateView(view, context: context) }
    #else
    func makeUIView(context: Context) -> WKWebView { makeView(context: context) }
    func updateUIView(_ view: WKWebView, context: Context) { updateView(view, context: context) }
    #endif

    private func makeView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(context.coordinator, name: "bridge")
        #if os(macOS)
        let resourceHandler = DocumentResourceSchemeHandler(model: model)
        configuration.setURLSchemeHandler(
            resourceHandler,
            forURLScheme: DocumentResourceSchemeHandler.scheme
        )
        context.coordinator.resourceHandler = resourceHandler
        #endif

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = false
        #if os(macOS)
        view.setValue(false, forKey: "drawsBackground")
        #else
        view.isOpaque = false
        view.backgroundColor = .clear
        #endif
        #if DEBUG
        if #available(macOS 13.3, iOS 16.4, *) { view.isInspectable = true }
        #endif
        context.coordinator.webView = view

        #if os(macOS)
        // WebKit runs out of process. Relative resources use the native
        // document-resource handler instead of a broad file base URL.
        view.loadHTMLString(RendererBundle.html, baseURL: nil)
        #else
        let baseURL = model.fileURL?.deletingLastPathComponent()
        view.loadHTMLString(RendererBundle.html, baseURL: baseURL)
        #endif

        let token = NotificationCenter.default.addObserver(
            forName: .readerScrollToHeading,
            object: nil,
            queue: .main
        ) { [weak coordinator = context.coordinator] notification in
            guard let id = notification.object as? String else { return }
            Task { @MainActor in coordinator?.scroll(to: id) }
        }
        context.coordinator.headingObserver = SendableNotificationToken(token)

        let printToken = NotificationCenter.default.addObserver(
            forName: .readerPrintDocument,
            object: nil,
            queue: .main
        ) { [weak coordinator = context.coordinator] _ in
            Task { @MainActor in await coordinator?.printDocument() }
        }
        context.coordinator.printObserver = SendableNotificationToken(printToken)
        return view
    }

    private func updateView(_ view: WKWebView, context: Context) {
        let resolvedTheme: String
        switch model.appearance {
        case .system: resolvedTheme = colorScheme == .dark ? "dark" : "light"
        case .light: resolvedTheme = "light"
        case .dark: resolvedTheme = "dark"
        }

        let request = RenderRequest(
            generation: model.renderGeneration,
            markdown: model.markdown,
            theme: resolvedTheme,
            contentWidth: model.contentWidth,
            fontScale: model.fontScale,
            allowRawHTML: model.allowRawHTML,
            baseURL: model.fileURL?.deletingLastPathComponent()
        )
        context.coordinator.update(request)
        context.coordinator.find(model.searchText)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        fileprivate var headingObserver: SendableNotificationToken?
        fileprivate var printObserver: SendableNotificationToken?
        private let model: ReaderModel
        private var isReady = false
        private var request: RenderRequest?
        private var lastGeneration = -1
        private var lastSearch = ""
        private var loadedBaseURL: URL?
        private let externalURLHandler: ((URL) -> Void)?
        #if os(macOS)
        fileprivate var resourceHandler: DocumentResourceSchemeHandler?
        private var activePrintOperation: NSPrintOperation?
        private var isPresentingPrintPanel = false
        #endif

        init(model: ReaderModel, externalURLHandler: ((URL) -> Void)? = nil) {
            self.model = model
            self.externalURLHandler = externalURLHandler
        }

        deinit {
            if let headingObserver {
                NotificationCenter.default.removeObserver(headingObserver.value)
            }
            if let printObserver {
                NotificationCenter.default.removeObserver(printObserver.value)
            }
        }

        fileprivate func update(_ newRequest: RenderRequest) {
            request = newRequest
            if loadedBaseURL != newRequest.baseURL {
                loadedBaseURL = newRequest.baseURL
                #if !os(macOS)
                isReady = false
                webView?.loadHTMLString(RendererBundle.html, baseURL: newRequest.baseURL)
                return
                #endif
            }
            renderIfNeeded()
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "bridge",
                  let payload = message.body as? [String: Any],
                  let type = payload["type"] as? String else { return }

            switch type {
            case "ready":
                isReady = true
                lastGeneration = -1
                renderIfNeeded()
            case "rendered":
                receiveRendered(payload)
            case "error":
                if let value = payload["message"] as? String {
                    model.errorMessage = value
                }
            case "linkActivated":
                if let value = payload["url"] as? String,
                   let url = URL(string: value) {
                    handleActivatedURL(url)
                }
            default:
                break
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased()
            let shouldHandle = navigationAction.navigationType == .linkActivated
                || ["http", "https", "mailto"].contains(scheme ?? "")

            if shouldHandle, handleActivatedURL(url) {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func scroll(to id: String) {
            guard let data = try? JSONEncoder().encode(id),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView?.evaluateJavaScript("window.MDViewer.scrollToHeading(\(json))")
        }

        func find(_ query: String) {
            guard query != lastSearch else { return }
            lastSearch = query
            guard !query.isEmpty else { return }
            let configuration = WKFindConfiguration()
            configuration.caseSensitive = false
            configuration.wraps = true
            Task { [weak webView] in
                _ = try? await webView?.find(query, configuration: configuration)
            }
        }

        func printDocument() async {
            guard let webView, model.fileURL != nil else { return }
            #if os(macOS)
            guard !isPresentingPrintPanel else { return }
            isPresentingPrintPanel = true
            #endif
            do {
                _ = try await webView.callAsyncJavaScript(
                    "return await window.MDViewer.preparePrint();",
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                presentPrintPanel(for: webView)
            } catch {
                #if os(macOS)
                isPresentingPrintPanel = false
                #endif
                finishPrint()
                model.errorMessage = "准备打印失败：\(error.localizedDescription)"
            }
        }

        private func finishPrint() {
            webView?.evaluateJavaScript("window.MDViewer.finishPrint(); true")
        }

        #if os(macOS)
        private func presentPrintPanel(for webView: WKWebView) {
            guard let window = webView.window else {
                isPresentingPrintPanel = false
                finishPrint()
                model.errorMessage = "无法显示系统打印面板：文档窗口不可用。"
                return
            }

            let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
            // The shared @page rule owns page size and margins on every platform.
            printInfo.topMargin = 0
            printInfo.bottomMargin = 0
            printInfo.leftMargin = 0
            printInfo.rightMargin = 0
            printInfo.orientation = .portrait
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            printInfo.isHorizontallyCentered = false
            printInfo.isVerticallyCentered = false

            let operation = webView.printOperation(with: printInfo)
            operation.jobTitle = model.title
            operation.showsPrintPanel = true
            operation.showsProgressPanel = true
            operation.printPanel.options.formUnion([
                .showsPreview,
                .showsCopies,
                .showsPageRange,
                .showsPaperSize,
                .showsOrientation,
                .showsScaling
            ])

            activePrintOperation = operation
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            operation.runModal(
                for: window,
                delegate: self,
                didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        }

        @objc private func printOperationDidRun(
            _ operation: NSPrintOperation,
            success: Bool,
            contextInfo: UnsafeMutableRawPointer?
        ) {
            activePrintOperation = nil
            isPresentingPrintPanel = false
            finishPrint()
        }
        #else
        private func presentPrintPanel(for webView: WKWebView) {
            guard UIPrintInteractionController.isPrintingAvailable else {
                finishPrint()
                model.errorMessage = "当前设备没有可用的打印服务。"
                return
            }

            let controller = UIPrintInteractionController.shared
            let printInfo = UIPrintInfo(dictionary: nil)
            printInfo.jobName = model.title
            printInfo.outputType = .general
            printInfo.orientation = .portrait
            controller.printInfo = printInfo

            let formatter = webView.viewPrintFormatter()
            formatter.perPageContentInsets = .zero
            controller.printFormatter = formatter

            let completion: UIPrintInteractionController.CompletionHandler = {
                [weak self] _, completed, error in
                Task { @MainActor in
                    self?.finishPrint()
                    if !completed, let error {
                        self?.model.errorMessage = "打印失败：\(error.localizedDescription)"
                    }
                }
            }

            let presented: Bool
            if UIDevice.current.userInterfaceIdiom == .pad {
                presented = controller.present(
                    from: webView.bounds,
                    in: webView,
                    animated: true,
                    completionHandler: completion
                )
            } else {
                presented = controller.present(
                    animated: true,
                    completionHandler: completion
                )
            }

            if !presented {
                finishPrint()
                model.errorMessage = "无法显示系统打印面板。"
            }
        }
        #endif

        private func renderIfNeeded() {
            guard isReady,
                  let request,
                  request.generation != lastGeneration,
                  let markdownData = try? JSONEncoder().encode(request.markdown),
                  let markdownJSON = String(data: markdownData, encoding: .utf8),
                  let optionsData = try? JSONEncoder().encode(request.options),
                  let optionsJSON = String(data: optionsData, encoding: .utf8) else { return }
            lastGeneration = request.generation
            webView?.evaluateJavaScript(
                "window.MDViewer.renderDocument(\(markdownJSON), \(optionsJSON)); true"
            ) { [weak self] _, error in
                if let error {
                    Task { @MainActor in
                        self?.model.errorMessage = "渲染器执行失败：\(error.localizedDescription)"
                    }
                }
            }
        }

        private func receiveRendered(_ payload: [String: Any]) {
            let rawHeadings = payload["headings"] as? [[String: Any]] ?? []
            let headings = rawHeadings.compactMap { item -> Heading? in
                guard let id = item["id"] as? String,
                      let level = item["level"] as? Int,
                      let title = item["title"] as? String else { return nil }
                return Heading(id: id, level: level, title: title)
            }
            var report = RenderReport()
            report.milliseconds = payload["milliseconds"] as? Double ?? 0
            report.wordCount = payload["wordCount"] as? Int ?? 0
            report.mathCount = payload["mathCount"] as? Int ?? 0
            report.diagramCount = payload["diagramCount"] as? Int ?? 0
            model.updateRender(headings: headings, report: report)
        }

        @discardableResult
        func handleActivatedURL(_ url: URL) -> Bool {
            #if os(macOS)
            if url.scheme?.lowercased() == DocumentResourceSchemeHandler.scheme,
               let resolved = resourceHandler?.resolve(url),
               ["md", "markdown", "mdown", "mkd"].contains(resolved.pathExtension.lowercased()) {
                model.open(resolved)
                return true
            }
            #endif

            let scheme = url.scheme?.lowercased()
            if ["http", "https", "mailto"].contains(scheme ?? "") {
                openExternally(url)
                return true
            }

            if url.isFileURL,
               ["md", "markdown", "mdown", "mkd"].contains(url.pathExtension.lowercased()) {
                model.open(url)
                return true
            }

            return false
        }

        private func openExternally(_ url: URL) {
            if let externalURLHandler {
                externalURLHandler(url)
                return
            }

            #if os(macOS)
            if !NSWorkspace.shared.open(url) {
                model.errorMessage = "无法使用系统默认应用打开链接：\(url.absoluteString)"
            }
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
}

private final class SendableNotificationToken: @unchecked Sendable {
    let value: NSObjectProtocol

    init(_ value: NSObjectProtocol) {
        self.value = value
    }
}

private struct RenderRequest {
    struct Options: Encodable {
        let theme: String
        let contentWidth: Double
        let fontScale: Double
        let allowRawHTML: Bool
        let usesDocumentResourceScheme: Bool
        let handlesLinksViaBridge: Bool
    }

    let generation: Int
    let markdown: String
    let theme: String
    let contentWidth: Double
    let fontScale: Double
    let allowRawHTML: Bool
    let baseURL: URL?

    var options: Options {
        Options(
            theme: theme,
            contentWidth: contentWidth,
            fontScale: fontScale,
            allowRawHTML: allowRawHTML,
            usesDocumentResourceScheme: {
                #if os(macOS)
                true
                #else
                false
                #endif
            }(),
            handlesLinksViaBridge: true
        )
    }
}
