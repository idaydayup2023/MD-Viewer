# Markdown 阅读器调研与 MD Viewer 方案

调研时间：2026-07-24

## 结论

Markdown 本身只负责轻量文档结构，不定义数学公式、图表、脚注、目录、代码高亮或样式。CommonMark 解决了基础语法歧义；GFM 在其上增加表格、任务列表、删除线与自动链接。数学通常由阅读器约定 `$…$`、`$$…$$`、`\(...\)`、`\[...\]`，再交给 MathJax 或 KaTeX，因此“同一个 `.md` 在不同软件显示不同”是格式方言和渲染能力共同导致的，不只是文件损坏。

Codex 对话中的公式如果保存时仍包含完整 TeX 源码与分隔符，就能恢复；如果复制/导出过程只留下了视觉文本、丢失反斜杠，或者阅读器先按 Markdown 转义了 `\[` 与 `\(`，任何阅读器都无法无损推断原公式。本项目解决可解决的渲染顺序问题，但不会凭空重建已经丢失的 TeX 源码。

## 常规产品能力

| 层级 | 阅读器基线 | 高级产品常见能力 | MD Viewer 0.1 |
| --- | --- | --- | --- |
| 文件 | 打开 `.md`、编码识别、相对资源 | 文件夹/知识库、最近文件、云同步 | 单文件原地只读、中文旧编码、相对资源 |
| 基础语法 | 标题、正文、强调、引用、列表、链接、图片 | CommonMark 一致性测试 | CommonMark/GFM 引擎 |
| 扩展语法 | 表格、任务、删除线、代码围栏 | 脚注、Front Matter、高亮、上下标 | 已支持 |
| 富内容 | 代码高亮 | 数学、图表、音视频、嵌入 | MathJax 4、Mermaid、图片 |
| 阅读体验 | 滚动、选择、复制 | 目录、查找、主题、缩放、打印/导出 | 除打印/导出外已支持 |
| 安全 | 外链处理 | HTML 清理、脚本隔离、离线资源 | 默认禁用原始 HTML，外链交给系统 |
| 性能 | 普通文档秒开 | 大文档增量解析、公式懒排版、虚拟化 | 单次解析、渲染耗时可见；懒排版列入下一阶段 |

## 竞品观察

- Obsidian 的优势是文件库、双链、嵌入和插件生态；其官方文档也明确使用自己的 Obsidian Flavored Markdown。迁移到普通阅读器时，Wiki Links、Callout、嵌入等并没有跨软件保证。
- Typora 以所见即所得编辑见长，支持 GFM、Front Matter、目录、脚注、MathJax 数学和图表。官方文档同样提示：图表不是 Markdown、CommonMark 或 GFM 的一部分。
- Marked 2 偏向预览与发布流水线，提供 MathJax、Mermaid/脚本、代码高亮和自定义处理器。
- MacDown 支持 GFM、Front Matter、任务列表，以及四类常见 TeX 分隔符，说明公式兼容的关键一直是“分隔符约定 + 二次渲染”。
- iA Writer 在 macOS/iOS 上提供实时预览、公式、元数据、PDF/Word 导出，更接近写作工具而不是纯阅读器。

因此，首版不复制知识库或编辑器，而是把“任何来源的单个 Markdown 文件尽可能正确地读出来”做成稳定内核。

## 渲染器选型

### 正文：markdown-it

- 规范兼容成熟，插件生态覆盖 GFM/脚注等扩展。
- 官方基准表明其 CommonMark 模式吞吐量很高；完整模式的额外成本来自 linkify、排版替换和扩展能力。
- AST/规则可扩展，适合以后加入 Obsidian、Pandoc、GitLab 方言。

### 数学：MathJax 4 + SVG

- 比 KaTeX 的 TeX 覆盖更广，支持 TeX/LaTeX 与 MathML，适合“兼容优先”的阅读器。
- MathJax 4 增加行内/块级断行、更多字体与表达式辅助功能。
- API 已改为异步 Promise；本项目等待 `startup.promise` 和 `typesetPromise`，避免动态组件尚未就绪时出现偶发空白。
- SVG 输出在不同 Apple 平台上外观一致。对含数百个公式的超长文档，下一阶段可启用官方 lazy 扩展，仅排版视口附近公式。

### 容器：SwiftUI + WKWebView

- SwiftUI 共享 macOS/iOS 的文件、目录、设置和状态代码。
- WKWebView 是 Apple 用于在原生 App 中嵌入交互式 Web 内容的系统组件，适合成熟的 HTML/MathML/SVG 排版栈。
- 所有脚本和样式打包到 App，不依赖 CDN，避免隐私、离线和版本漂移问题。

### 麒麟 Linux：Electron + Chromium

- Linux 版本复用与 Apple 版本完全相同的 markdown-it、MathJax、highlight.js、Mermaid 和阅读样式，避免两个渲染内核产生公式或排版差异。
- Electron 自带 Chromium，使麒麟系统的 WebKit/浏览器版本不会改变最终渲染效果。
- 界面层重新实现相同的目录、搜索、源文对照、主题、字号、版心和状态统计；文件选择与菜单使用 Linux 原生桌面接口。
- 渲染进程关闭 Node.js 注入、开启上下文隔离和沙箱；外链、关联文件和本地文件读取只通过受控接口处理。
- 当前发布只提供 x86_64/amd64 的 AppImage 与 Debian 安装包；ARM64/aarch64 及其他处理器架构不在维护范围内。

## 公式恢复策略

处理顺序如下：

1. 暂存 fenced code 与 inline code，保证代码中的数学符号不被误识别。
2. 提取 `$$…$$` 与 `\[...\]` 块公式。
3. 提取 `\(...\)` 与符合 Pandoc 风格边界条件的 `$…$` 行内公式；`$12 and $20` 保持金额文本。
4. 恢复代码，将正文交给 Markdown 解析器。
5. 把公式占位符恢复为 MathJax 可识别节点，统一异步排版。

这一步专门修复了“`\[` 在 Markdown 阶段先被当作转义字符处理，MathJax 再也看不到原始定界符”的常见问题。

## 性能目标与当前策略

用户真正感知的是四个指标，而不是单独的 Markdown 解析速度：

- 首次可见时间：文件读取、脚本初始化、Markdown 解析、DOM 布局、公式/图表排版总和。
- 重载延迟：源文件变化后到画面稳定。
- 滚动稳定性：公式、图片加载后不应频繁改变上方布局。
- 峰值内存：超大 DOM、MathJax SVG 和 Mermaid 图表是主要来源。

0.1 版采用映射读取、单次正文解析、异步公式/图表、SVG 本地字体缓存，并在侧栏显示每篇文档的实际渲染毫秒数。普通文章通常由脚本冷启动而非 Markdown 解析主导。后续性能路线：

1. 缓存已初始化的 WebView 与解析器，减少切换文件的冷启动。
2. 文档超过阈值时启用 MathJax lazy typesetting。
3. 超大文档按标题分段渲染，并用 IntersectionObserver 虚拟化不可见段落。
4. 外部文件变化改用 `NSFilePresenter`/`UIDocument` 自动跟踪，不依赖手动重新载入。
5. 建立 100 KB、1 MB、10 MB 与 10/100/1000 公式的固定基准集。

## “通用、完整、无所不能”的工程边界

可做到的是：不改写原文、支持明确的主流规范和方言、对未知扩展优雅降级、持续增加插件。

不能由阅读器单方面做到的是：

- 从已经丢失反斜杠或 TeX 源码的文本精确还原原公式。
- 同时执行互相冲突的 Markdown 方言规则。
- 在默认安全模式下无条件执行文档携带的任意 HTML/JavaScript。
- 让非标准图表、插件查询或专有嵌入在没有对应运行时的环境中完全一致。

因此最终形态应是“确定性的通用内核 + 可选择的方言配置 + 受控插件”，而不是一个不可验证的超级解析器。

## 参考

- CommonMark 0.31.2: https://spec.commonmark.org/0.31.2/
- GitHub Flavored Markdown: https://github.github.com/gfm/
- Typora Markdown Reference: https://support.typora.io/Markdown-Reference/
- Typora Math: https://support.typora.io/Math/
- Obsidian syntax: https://obsidian.md/help/syntax
- Marked 2 Help: https://marked2app.com/help/contents.html
- MacDown features: https://macdown.uranusjr.com/features/
- iA Writer features: https://ia.net/writer/support/basics/features
- MathJax 4 new features: https://docs.mathjax.org/en/stable/upgrading/whats-new-4.0.html
- MathJax lazy typesetting: https://docs.mathjax.org/en/v4.0/output/lazy.html
- Apple WKWebView: https://developer.apple.com/documentation/webkit/wkwebview
- Apple File Provider: https://developer.apple.com/documentation/fileprovider
- Electron distribution: https://www.electronjs.org/docs/latest/tutorial/distribution-overview
- Electron Linux build notes: https://www.electronjs.org/docs/latest/development/build-instructions-linux
