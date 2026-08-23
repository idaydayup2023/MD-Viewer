# MD Viewer

MD Viewer 是一个面向 macOS、iOS/iPadOS、Windows 与麒麟 Linux 的离线 Markdown 阅读器。它把 Markdown 原文当作不可变的事实来源，在渲染前保护公式，再分别交给 CommonMark/GFM、MathJax、highlight.js 与 Mermaid 处理。

## 已实现

- CommonMark 与 GFM：标题、段落、引用、列表、链接、图片、表格、任务列表、删除线、自动链接
- 扩展语法：脚注、高亮、上下标、YAML Front Matter
- 数学：`$…$`、`$$…$$`、`\(...\)`、`\[...\]`，支持 TeX/LaTeX 与 MathML
- 代码：语言识别与离线语法高亮
- 图表：Mermaid
- 阅读：自动目录、标题跳转、全文查找、亮暗主题、字号/版心调整、源文对照
- 打印：三端共用 A4 分页、页边距和打印样式，完整输出公式、代码、表格、图片与 Mermaid；macOS 支持系统打印预览
- 文件：macOS/iOS 系统文件选择器、原地只读访问、UTF-8/UTF-16/UTF-32/GB 18030、相对图片与相对 Markdown 链接
- 安全：默认禁用文档内原始 HTML；渲染依赖全部内置，断网可用

## macOS 与 iOS 运行

1. 用 Xcode 打开 `MDViewer.xcodeproj`。
2. 选择 `MDViewer-macOS` 或 `MDViewer-iOS` scheme。
3. 运行；启动页可直接打开内置“功能示例”。

macOS 要求 14.0 或更高版本，iOS/iPadOS 要求 17.0 或更高版本。

如果修改了 `project.yml`，先执行 `xcodegen generate`。渲染依赖的版本记录在 `package.json`；它们已经复制到 App 资源中，最终用户不需要 Node.js 或网络。

## 开发与验证

```bash
npm install
npm run test:print
```

`npm run vendor:mermaid` 会从官方 `mermaid@11.16.1` 标签重新生成离线浏览器包，并锁定经审计的 DOMPurify 3.4.13。该步骤需要 Git、pnpm 和网络；生成后的应用仍完全离线运行。

Swift 单元测试可在 Xcode 中选择 `MDViewer-macOS` scheme 执行。提交发布前还应运行 `npm audit`，并检查 `Release/<版本>/SHA256SUMS.txt`。

## 麒麟 Linux 运行

麒麟版本仅提供 x86_64/amd64 的 AppImage 和 `.deb`：

- `uname -m` 显示 `x86_64`：使用 `x86_64.AppImage` 或 `amd64.deb`

ARM64/aarch64 及其他处理器架构不在当前发布范围内。

AppImage 免安装运行：

```bash
chmod +x MD-Viewer-1.1.3-x86_64.AppImage
./MD-Viewer-1.1.3-x86_64.AppImage
```

如果系统没有启用 FUSE：

```bash
./MD-Viewer-1.1.3-x86_64.AppImage --appimage-extract-and-run
```

安装 `.deb`：

```bash
sudo apt install ./MD-Viewer-1.1.3-amd64.deb
```

安装后可从应用菜单启动，也可以用 `md-viewer 文件.md` 打开文档。详细说明见 `Linux/README.md`。

## Windows 运行

Windows 版本支持 Windows 10/11 x64，提供标准安装版和免安装版：

- `MD-Viewer-1.1.3-Windows-x64-Setup.exe`
- `MD-Viewer-1.1.3-Windows-x64-Portable.exe`

安装版会创建开始菜单入口，并注册 Markdown 与纯文本文件关联。免安装版可直接运行，不修改系统安装目录。详细说明见 `Windows/README.md`。

## 设计原则

Markdown 不是单一格式，而是一族“基础规范 + 方言 + 渲染扩展”。本项目的兼容顺序是：

1. 保留原文，不自动改写。
2. 代码片段优先，代码中的 `$` 和反斜杠永远不当作公式。
3. 在 Markdown 解析之前保护公式分隔符，避免 `\[`、`\(` 被 Markdown 转义规则吞掉。
4. 用 CommonMark/GFM 解析正文，再恢复公式并异步排版。
5. 未识别内容仍以原文形式可见，用户可随时打开源文对照。

更完整的调研与后续路线见 `Research.md`。

## 发布包

已核验的正式包按版本保存在 `Release` 目录。每个版本都附有发布说明与 `SHA256SUMS.txt`；下载后可运行 `shasum -a 256 -c SHA256SUMS.txt` 校验完整性。

公开 Release 提供 macOS 通用包、Windows x64 安装包与免安装包，以及麒麟 Linux x86_64/amd64 包。iOS/iPadOS 保留源码兼容与内部编译验证，不提供公开下载产物。

## 许可证

本项目采用 MIT License，详见 `LICENSE`。

第三方渲染器与框架保留各自许可证，详见 `THIRD_PARTY_NOTICES.md`。
