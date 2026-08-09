import SwiftUI

struct ReaderCommands: Commands {
    @ObservedObject var model: ReaderModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("打开…") { model.isImporterPresented = true }
                .keyboardShortcut("o")
            Button("重新载入") { model.reload() }
                .keyboardShortcut("r")
                .disabled(model.fileURL == nil)
        }
        #if os(macOS)
        CommandGroup(replacing: .printItem) {
            Button("打印预览…") { model.requestPrintPreview() }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(model.fileURL == nil)
            Button("打印…") { model.requestPrint() }
                .keyboardShortcut("p")
                .disabled(model.fileURL == nil)
        }
        #endif
        CommandMenu("阅读") {
            Button("显示/隐藏源文") { model.isSourceVisible.toggle() }
                .keyboardShortcut("\\")
                .disabled(model.fileURL == nil)
            Divider()
            Button("放大") {
                model.fontScale = min(1.5, model.fontScale + 0.1)
                model.requestRender()
            }
            .keyboardShortcut("+")
            Button("缩小") {
                model.fontScale = max(0.8, model.fontScale - 0.1)
                model.requestRender()
            }
            .keyboardShortcut("-")
            Button("实际大小") {
                model.fontScale = 1
                model.requestRender()
            }
            .keyboardShortcut("0")
        }
    }
}
