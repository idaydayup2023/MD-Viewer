import AppKit
import XCTest
@testable import MD_Viewer

final class TextFileDecoderTests: XCTestCase {
    func testSharedRendererDefinesCrossPlatformPrintContract() {
        XCTAssertTrue(RendererBundle.html.contains("size: A4 portrait"))
        XCTAssertTrue(RendererBundle.html.contains("preparePrint"))
        XCTAssertTrue(RendererBundle.html.contains("finishPrint"))
        XCTAssertTrue(RendererBundle.html.contains("break-inside: avoid-page"))
        XCTAssertTrue(RendererBundle.html.contains("MathJax.typesetPromise([article])"))
        XCTAssertTrue(RendererBundle.html.contains("waitForMathJaxReady"))
        XCTAssertFalse(RendererBundle.html.contains("await window.MathJax.startup.promise"))
    }

    @MainActor
    func testPrintRequestRequiresAnOpenDocument() throws {
        let notification = expectation(
            forNotification: .readerPrintDocument,
            object: nil
        )
        notification.assertForOverFulfill = true

        let model = ReaderModel()
        model.requestPrint()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try Data("# 可打印文档".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        model.open(url)
        model.requestPrint()

        wait(for: [notification], timeout: 0.2)
    }

    @MainActor
    func testPrintPreviewRequestRequiresAnOpenDocument() throws {
        let notification = expectation(
            forNotification: .readerPrintDocument,
            object: nil
        ) { notification in
            (notification.object as? PrintPresentation) == .preview
        }
        notification.assertForOverFulfill = true

        let model = ReaderModel()
        model.requestPrintPreview()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try Data("# 可预览文档".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        model.open(url)
        model.requestPrintPreview()

        wait(for: [notification], timeout: 0.2)
    }

    @MainActor
    func testMacAppIconResourceLoadsForDock() throws {
        let iconURL = try XCTUnwrap(
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
        )
        XCTAssertNotNil(NSImage(contentsOf: iconURL))
    }

    @MainActor
    func testStandaloneReopenResetsToWelcome() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("Previously Opened.md")
        try Data("# Previous".utf8).write(to: url)

        let model = ReaderModel()
        model.open(url)
        model.searchText = "Previous"
        model.isSourceVisible = true
        let delegate = MacApplicationDelegate()
        delegate.attach(to: model)

        XCTAssertTrue(
            delegate.applicationShouldHandleReopen(
                NSApplication.shared,
                hasVisibleWindows: true
            )
        )
        XCTAssertNil(model.fileURL)
        XCTAssertEqual(model.markdown, "")
        XCTAssertEqual(model.headings, [])
        XCTAssertEqual(model.searchText, "")
        XCTAssertFalse(model.isSourceVisible)
    }

    @MainActor
    func testFinderOpenSurvivesFollowingReopenEvent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("Finder Requested.md")
        try Data("# Finder".utf8).write(to: url)

        let model = ReaderModel()
        let delegate = MacApplicationDelegate()
        delegate.attach(to: model)
        delegate.application(NSApplication.shared, open: [url])
        XCTAssertTrue(
            delegate.applicationShouldHandleReopen(
                NSApplication.shared,
                hasVisibleWindows: false
            )
        )

        XCTAssertEqual(model.fileURL, url.standardizedFileURL)
        XCTAssertEqual(model.markdown, "# Finder")
    }

    @MainActor
    func testExternalHTTPLinkIsForwardedToSystemHandler() throws {
        let model = ReaderModel()
        var openedURL: URL?
        let coordinator = MarkdownWebView.Coordinator(
            model: model,
            externalURLHandler: { openedURL = $0 }
        )
        let expectedURL = try XCTUnwrap(
            URL(string: "https://www.huntingtonhealth.org/physicians/yang-shen-md__trashed-2/")
        )

        XCTAssertTrue(coordinator.handleActivatedURL(expectedURL))
        XCTAssertEqual(openedURL, expectedURL)
    }

    @MainActor
    func testUnsafeLinkSchemeIsNotForwarded() throws {
        let model = ReaderModel()
        var openedURL: URL?
        let coordinator = MarkdownWebView.Coordinator(
            model: model,
            externalURLHandler: { openedURL = $0 }
        )
        let unsafeURL = try XCTUnwrap(URL(string: "javascript:alert(1)"))

        XCTAssertFalse(coordinator.handleActivatedURL(unsafeURL))
        XCTAssertNil(openedURL)
    }

    func testUTF8Decode() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try Data("# 标题\n公式：$x^2$".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(try TextFileDecoder.decode(contentsOf: url), "# 标题\n公式：$x^2$")
    }

    @MainActor
    func testMacApplicationDelegateQueuesColdOpenAndForwardsLaterOpen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstURL = directory.appendingPathComponent("First.md")
        let secondURL = directory.appendingPathComponent("Second.md")
        try Data("# First".utf8).write(to: firstURL)
        try Data("# Second".utf8).write(to: secondURL)

        let delegate = MacApplicationDelegate()
        let model = ReaderModel()

        delegate.application(NSApplication.shared, open: [firstURL])
        XCTAssertNil(model.fileURL)

        delegate.attach(to: model)
        XCTAssertEqual(model.fileURL, firstURL.standardizedFileURL)
        XCTAssertEqual(model.markdown, "# First")

        delegate.application(NSApplication.shared, open: [secondURL])
        XCTAssertEqual(model.fileURL, secondURL.standardizedFileURL)
        XCTAssertEqual(model.markdown, "# Second")
    }
}
