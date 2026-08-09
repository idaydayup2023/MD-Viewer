import SwiftUI

struct OutlineView: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        List {
            if model.fileURL == nil {
                Label("尚未打开文档", systemImage: "doc")
                    .foregroundStyle(.secondary)
            } else if model.headings.isEmpty {
                Label("文档没有标题", systemImage: "list.bullet.indent")
                    .foregroundStyle(.secondary)
            } else {
                Section("目录") {
                    ForEach(model.headings) { heading in
                        Button {
                            NotificationCenter.default.post(
                                name: .readerScrollToHeading,
                                object: heading.id
                            )
                        } label: {
                            Text(heading.title)
                                .lineLimit(2)
                                .padding(.leading, CGFloat(max(0, heading.level - 1)) * 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if model.fileURL != nil {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(model.report.wordCount) 字词")
                        Spacer()
                        Text(model.fileSizeDescription)
                    }
                    HStack {
                        Text("\(model.report.mathCount) 个公式")
                        Spacer()
                        Text(String(format: "%.0f ms", model.report.milliseconds))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .background(.bar)
            }
        }
    }
}

extension Notification.Name {
    static let readerScrollToHeading = Notification.Name("readerScrollToHeading")
    static let readerPrintDocument = Notification.Name("readerPrintDocument")
}
