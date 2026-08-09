# MD Viewer 1.1.1

发布日期：2026-08-09

## 本版改进

- 修复 macOS 点击“打印”后没有出现系统打印界面的问题。
- 新增 macOS“打印预览…”菜单与工具栏入口；`⌥⌘P` 打开预览，`⌘P` 打开打印面板。
- 打印前等待数学公式、Mermaid、图片、字体与页面布局完成，避免输出原始公式或缺失内容。
- 修复离线 MathJax 初始化阻塞，屏幕阅读与打印均能恢复 TeX/LaTeX 公式。
- 将 Mermaid 升级到 11.16.1，并从官方源码以 DOMPurify 3.4.13 重新生成离线浏览器包，修复发布前依赖审计发现的安全公告。
- 三个平台继续共用 A4 纵向分页、页边距、表格、代码、图片和图表打印样式。

## 正式包

| 文件 | 平台 | 架构/用途 |
| --- | --- | --- |
| `MD-Viewer-1.1.1-macOS-universal.zip` | macOS 14+ | arm64 + x86_64；包含本地签名的 `MD Viewer.app` |
| `MD-Viewer-1.1.1-x86_64.AppImage` | 麒麟 Linux | x86_64 免安装包 |
| `MD-Viewer-1.1.1-amd64.deb` | 麒麟 Linux | amd64 Debian 安装包 |

麒麟 Linux 不支持 ARM64/aarch64。iOS 源码兼容性、Simulator 双架构和真机 arm64 无签名编译已经内部验证，但 iOS 不属于本次公开发布范围，不提供任何 iOS 下载包。

## 验证摘要

- macOS：实际安装并启动 1.1.1；纯启动显示欢迎页；功能示例识别 4 个公式；打印预览显示 2 页 A4；工具栏与 `⌘P` 均能打开系统打印面板。
- 单元测试：10 项通过，0 失败。
- iOS（仅内部验证）：Release 模拟器双架构构建通过；Release 真机 arm64 无签名编译通过；未上传公开产物。
- Linux：离线打印验证 PDF 为 2 页 A4，包含 4 个公式、1 个 Mermaid 图、代码块与表格；AppImage 确认是 ELF x86-64，`.deb` 控制信息确认为 `amd64`、版本 1.1.1、MIT License；包内公式及 Mermaid 引擎与源码 SHA-256 一致。
- 依赖审计：`npm audit` 与生产依赖审计均为 0 个已报告漏洞。
- 校验：运行 `shasum -a 256 -c SHA256SUMS.txt`。

macOS 包是适合本机直接运行的 ad-hoc 签名包，尚未使用 Apple Developer ID 公证。Linux 包在 macOS 打包环境完成结构与内容验证，未在本机直接运行 Linux 图形界面。
