import SwiftUI

struct ReaderDetailView: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if model.isSourceVisible {
                #if os(macOS)
                HSplitView {
                    source
                    MarkdownWebView(model: model)
                        .frame(minWidth: 320)
                }
                #else
                TabView {
                    MarkdownWebView(model: model)
                        .tabItem { Label("阅读", systemImage: "book") }
                    source
                        .tabItem { Label("源文", systemImage: "doc.plaintext") }
                }
                #endif
            } else {
                MarkdownWebView(model: model)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("在文档中查找", text: $model.searchText)
                .textFieldStyle(.plain)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.bar)
    }

    private var source: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(model.markdown)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 280)
    }
}
