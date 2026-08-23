import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class ReaderModel: ObservableObject {
    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .system: "跟随系统"
            case .light: "浅色"
            case .dark: "深色"
            }
        }
    }

    @Published private(set) var fileURL: URL?
    @Published private(set) var markdown = ""
    @Published private(set) var headings: [Heading] = []
    @Published private(set) var report = RenderReport()
    @Published var errorMessage: String?
    @Published var isImporterPresented = false
    @Published var isSourceVisible = false
    @Published var searchText = ""
    @Published var appearance: Appearance = .system
    @Published var contentWidth: Double = 860
    @Published var fontScale: Double = 1
    @Published var allowRawHTML = false
    @Published var renderGeneration = 0

    private var scopedURLs: [URL] = []

    var title: String { fileURL?.lastPathComponent ?? "MD Viewer" }
    var fileSizeDescription: String {
        guard let fileURL,
              let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    func open(_ url: URL) {
        let documentURL = url.standardizedFileURL
        var candidateScopedURLs: [URL] = []
        beginAccessing(documentURL, storingIn: &candidateScopedURLs)
        // A Markdown document commonly owns sibling images. Finder/open-panel
        // grants can include the containing folder; retain that scope when
        // available so WebKit can resolve relative resources from the base URL.
        beginAccessing(
            documentURL.deletingLastPathComponent(),
            storingIn: &candidateScopedURLs
        )

        do {
            let decodedMarkdown = try TextFileDecoder.decode(contentsOf: documentURL)
            stopAccessingCurrentDocument()
            scopedURLs = candidateScopedURLs
            markdown = decodedMarkdown
            fileURL = documentURL
            errorMessage = nil
            renderGeneration += 1
        } catch {
            stopAccessing(candidateScopedURLs)
            errorMessage = "无法读取“\(documentURL.lastPathComponent)”：\(error.localizedDescription)"
        }
    }

    func reload() {
        guard let fileURL else { return }
        do {
            markdown = try TextFileDecoder.decode(contentsOf: fileURL)
            errorMessage = nil
            renderGeneration += 1
        } catch {
            errorMessage = "重新载入失败：\(error.localizedDescription)"
        }
    }

    func closeDocument() {
        stopAccessingCurrentDocument()
        fileURL = nil
        markdown = ""
        headings = []
        report = RenderReport()
        errorMessage = nil
        isImporterPresented = false
        isSourceVisible = false
        searchText = ""
        renderGeneration += 1
    }

    func openSample() {
        guard let url = Bundle.main.url(forResource: "FeatureShowcase", withExtension: "md") else {
            errorMessage = "内置示例文件缺失。"
            return
        }
        open(url)
    }

    func acceptImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first { open(url) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    func updateRender(headings: [Heading], report: RenderReport) {
        self.headings = headings
        self.report = report
    }

    func requestRender() {
        renderGeneration += 1
    }

    func requestPrint() {
        guard fileURL != nil else { return }
        NotificationCenter.default.post(
            name: .readerPrintDocument,
            object: PrintPresentation.print
        )
    }

    func requestPrintPreview() {
        guard fileURL != nil else { return }
        NotificationCenter.default.post(
            name: .readerPrintDocument,
            object: PrintPresentation.preview
        )
    }

    private func beginAccessing(_ url: URL, storingIn urls: inout [URL]) {
        if url.startAccessingSecurityScopedResource() {
            urls.append(url)
        }
    }

    private func stopAccessingCurrentDocument() {
        stopAccessing(scopedURLs)
        scopedURLs.removeAll()
    }

    private func stopAccessing(_ urls: [URL]) {
        urls.forEach { $0.stopAccessingSecurityScopedResource() }
    }
}

enum PrintPresentation: Equatable {
    case preview
    case print
}

enum TextFileDecoder {
    static func decode(contentsOf url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        if let value = String(data: data, encoding: .utf8) { return value }
        if let value = String(data: data, encoding: .utf16) { return value }
        if let value = String(data: data, encoding: .utf32) { return value }

        // GB 18030 is common in older Chinese Markdown collections.
        let gb18030 = String.Encoding(rawValue: 0x8000_0632)
        if let value = String(data: data, encoding: gb18030) { return value }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
}
