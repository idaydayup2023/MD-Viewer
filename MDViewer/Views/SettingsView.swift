import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        Form {
            Picker("外观", selection: $model.appearance) {
                ForEach(ReaderModel.Appearance.allCases) { appearance in
                    Text(appearance.label).tag(appearance)
                }
            }

            VStack(alignment: .leading) {
                Text("正文宽度：\(Int(model.contentWidth)) pt")
                Slider(value: $model.contentWidth, in: 560...1200, step: 20)
            }

            VStack(alignment: .leading) {
                Text("字号：\(Int(model.fontScale * 100))%")
                Slider(value: $model.fontScale, in: 0.8...1.5, step: 0.05)
            }

            Toggle("允许原始 HTML", isOn: $model.allowRawHTML)
            Text("关闭时会把文档内的 HTML 当作文本处理，可防止未知文档执行嵌入内容。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: model.appearance) { _, _ in model.requestRender() }
        .onChange(of: model.contentWidth) { _, _ in model.requestRender() }
        .onChange(of: model.fontScale) { _, _ in model.requestRender() }
        .onChange(of: model.allowRawHTML) { _, _ in model.requestRender() }
    }
}
