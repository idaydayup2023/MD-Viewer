#if os(macOS)
import Foundation
import UniformTypeIdentifiers
@preconcurrency import WebKit

/// Serves resources referenced by a Markdown document without giving WebKit a
/// broad `file://` base URL. The native process resolves and reads each
/// resource relative to the current document.
@MainActor
final class DocumentResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "mdviewer-resource"

    private weak var model: ReaderModel?

    init(model: ReaderModel) {
        self.model = model
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let resourceURL = resolve(requestURL) else {
            urlSchemeTask.didFailWithError(CocoaError(.fileNoSuchFile))
            return
        }

        do {
            let data = try CoordinatedFileAccess.read(resourceURL)
            let mimeType = UTType(filenameExtension: resourceURL.pathExtension)?
                .preferredMIMEType ?? "application/octet-stream"
            let response = URLResponse(
                url: requestURL,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    func resolve(_ url: URL) -> URL? {
        guard url.scheme == Self.scheme,
              let documentURL = model?.fileURL,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let rawPath = components.queryItems?.first(where: { $0.name == "path" })?.value,
              !rawPath.isEmpty,
              !rawPath.hasPrefix("/") else { return nil }

        let pathOnly = rawPath
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
        guard !pathOnly.isEmpty else { return nil }

        let baseURL = documentURL.deletingLastPathComponent().standardizedFileURL
        return URL(
            fileURLWithPath: String(pathOnly),
            relativeTo: baseURL
        ).standardizedFileURL
    }
}

private enum CoordinatedFileAccess {
    static func read(_ url: URL) throws -> Data {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<Data, Error>?

        coordinator.coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            result = Result {
                try Data(contentsOf: coordinatedURL, options: [.mappedIfSafe])
            }
        }

        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }
}
#endif
