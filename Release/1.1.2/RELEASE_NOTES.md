# MD Viewer 1.1.2

发布日期：2026-08-23

## 本版改进

- 修复 macOS 打开 Markdown 后点击程序坞图标，当前文档被清空并显示空白欢迎页的问题。
- 统一窗口与文档生命周期：关闭窗口只关闭显示窗口，应用仍运行时保留当前文档；再次点击程序坞会恢复原文档。
- 改进文件切换的事务逻辑：只有新文件读取成功后才替换当前文档；读取失败时保留原文档和渲染状态。
- 保持 Finder 冷启动打开、运行中打开、重复事件抑制及相对图片访问逻辑不变。

## 正式包

| 文件 | 平台 | 架构/用途 |
| --- | --- | --- |
| `MD-Viewer-1.1.2-macOS-universal.zip` | macOS 14+ | arm64 + x86_64；包含本地签名的 `MD Viewer.app` |
| `MD-Viewer-1.1.2-x86_64.AppImage` | 麒麟 Linux | x86_64 免安装包 |
| `MD-Viewer-1.1.2-amd64.deb` | 麒麟 Linux | amd64 Debian 安装包 |

麒麟 Linux 不支持 ARM64/aarch64。iOS/iPadOS 保留源码兼容，不属于本次公开发布范围。

## 验证摘要

- macOS：验证文档窗口可正常打开；窗口关闭后重新激活应用，标题、目录、正文和相对图片均保留。
- 单元测试：12 项通过，0 失败，覆盖有窗口和无窗口两种程序坞重开路径、Finder 打开及文件读取失败回退。
- macOS 构建：Release 通用二进制同时包含 arm64 与 x86_64，ad-hoc 签名和严格签名校验通过。
- Linux：离线打印验证通过；AppImage 为 ELF x86-64，Debian 包架构为 amd64、版本为 1.1.2。
- 依赖审计：`npm audit` 和生产依赖审计均无已报告漏洞。
- 校验：运行 `shasum -a 256 -c SHA256SUMS.txt`。

macOS 包尚未使用 Apple Developer ID 公证。Linux 包在 macOS 打包环境完成结构与内容验证，未在本机直接运行 Linux 图形界面。
