#if os(macOS)
import AppKit
import Foundation

/// Bridges Launch Services document-open events into the shared reader model.
///
/// Finder delivers `kAEOpenDocuments` before SwiftUI has necessarily created
/// the WindowGroup content. Keep those URLs until the model is attached so a
/// cold launch and an already-running application follow the same path.
@MainActor
final class MacApplicationDelegate: NSObject, NSApplicationDelegate {
    private weak var model: ReaderModel?
    private var pendingURLs: [URL] = []
    private var recentDeliveries: [URL: Date] = [:]
    private var lastDocumentOpenRequestAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the running application's icon explicitly. Finder can read the
        // bundle icon directly, while Dock may keep an older Launch Services
        // image when several development builds share the same bundle ID.
        guard let iconURL = Bundle.main.url(
            forResource: "AppIcon",
            withExtension: "icns"
        ),
        let icon = NSImage(contentsOf: iconURL) else { return }
        NSApplication.shared.applicationIconImage = icon
    }

    func attach(to model: ReaderModel) {
        self.model = model
        guard !pendingURLs.isEmpty else { return }
        let queued = pendingURLs
        pendingURLs.removeAll()
        queued.forEach(deliver)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        accept(urls)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        accept(filenames.map(URL.init(fileURLWithPath:)))
        sender.reply(toOpenOrPrint: .success)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        let followsDocumentOpen = lastDocumentOpenRequestAt.map {
            Date().timeIntervalSince($0) < 1
        } ?? false

        // Opening the application itself is a request for a fresh reader.
        // Finder document-open events are delivered through accept(_:); keep
        // their queued/current document even if AppKit also emits a reopen.
        if pendingURLs.isEmpty, !followsDocumentOpen {
            model?.resetToWelcome()
        }
        return true
    }

    func applicationShouldSaveSecureApplicationState(
        _ application: NSApplication
    ) -> Bool {
        false
    }

    func applicationShouldRestoreSecureApplicationState(
        _ application: NSApplication
    ) -> Bool {
        false
    }

    private func accept(_ urls: [URL]) {
        let documents = urls
            .filter(\.isFileURL)
            .map { $0.standardizedFileURL }

        guard !documents.isEmpty else { return }
        lastDocumentOpenRequestAt = Date()
        if model == nil {
            pendingURLs.append(contentsOf: documents)
        } else {
            documents.forEach(deliver)
        }
    }

    private func deliver(_ url: URL) {
        // Some macOS releases may surface the same Apple Event through both
        // delegate callbacks. Suppress only that immediate duplicate while
        // allowing an intentional later reopen to reload the document.
        let now = Date()
        recentDeliveries = recentDeliveries.filter {
            now.timeIntervalSince($0.value) < 1
        }
        if let previous = recentDeliveries[url],
           now.timeIntervalSince(previous) < 0.25 {
            return
        }
        recentDeliveries[url] = now
        model?.open(url)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }
}
#endif
