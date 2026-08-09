import SwiftUI
import UniformTypeIdentifiers

struct ReaderRootView: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .detail

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            OutlineView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 250, max: 340)
        } detail: {
            Group {
                if model.fileURL == nil {
                    WelcomeView()
                } else {
                    ReaderDetailView()
                }
            }
            .navigationTitle(model.title)
        }
        .fileImporter(
            isPresented: $model.isImporterPresented,
            allowedContentTypes: [.markdownDocument, .plainText],
            allowsMultipleSelection: false,
            onCompletion: model.acceptImport
        )
        .alert("MD Viewer", isPresented: errorBinding) {
            Button("好") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.isImporterPresented = true
                } label: {
                    Label("打开", systemImage: "folder")
                }
                .help("打开 Markdown 文件")

                if model.fileURL != nil {
                    Button {
                        model.reload()
                    } label: {
                        Label("重新载入", systemImage: "arrow.clockwise")
                    }
                    .help("重新载入文件")

                    #if os(macOS)
                    Button {
                        model.requestPrintPreview()
                    } label: {
                        Label("打印预览", systemImage: "doc.text.magnifyingglass")
                    }
                    .help("在系统打印面板中预览分页和版式")
                    #endif

                    Button {
                        model.requestPrint()
                    } label: {
                        Label("打印", systemImage: "printer")
                    }
                    .help("打印当前文档")

                    Button {
                        model.isSourceVisible.toggle()
                    } label: {
                        Label("源文", systemImage: model.isSourceVisible ? "doc.richtext.fill" : "doc.plaintext")
                    }
                    .help("显示或隐藏 Markdown 原文")
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}

private extension UTType {
    static let markdownDocument = UTType(filenameExtension: "md") ?? .plainText
}

private struct WelcomeView: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        ContentUnavailableView {
            Label("MD Viewer", systemImage: "text.book.closed")
        } description: {
            Text("忠实阅读 Markdown，完整呈现公式、代码、表格和图表。")
        } actions: {
            HStack {
                Button("打开文件…") { model.isImporterPresented = true }
                    .buttonStyle(.borderedProminent)
                Button("查看功能示例") { model.openSample() }
                    .buttonStyle(.bordered)
            }
        }
    }
}
