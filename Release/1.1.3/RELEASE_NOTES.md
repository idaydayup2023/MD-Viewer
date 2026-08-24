# MD Viewer 1.1.3

发布日期：2026-08-23

## 本版改进

- 纠正 1.1.2 的窗口关闭语义：点击红色关闭按钮会同时关闭当前 Markdown 文件和阅读窗口，再次点击程序坞只显示欢迎页。
- 明确区分关闭与暂时隐藏：黄色最小化、隐藏应用及窗口仍打开时点击程序坞，都会保留并恢复当前文档。
- 保持文件切换的事务逻辑：新文件读取成功后才替换当前文档，读取失败时保留原文档。
- 重绘 MD Viewer 图标，移除外围不透明白色画布，改为真实透明背景。
- 新增可重复执行的原生 Swift 图标生成脚本，确保透明边缘、圆角、渐变和文档标识稳定一致。
- 新增 Windows 10/11 x64 版本，提供标准安装包和免安装包，并支持 Markdown 与纯文本文件关联。

## 正式包

| 文件 | 平台 | 架构/用途 |
| --- | --- | --- |
| `MD-Viewer-1.1.3-macOS-universal.zip` | macOS 14+ | arm64 + x86_64；包含本地签名的 `MD Viewer.app` |
| `MD-Viewer-1.1.3-Windows-x64-Setup.exe` | Windows 10/11 | x64 标准安装包；支持开始菜单、桌面快捷方式和文件关联 |
| `MD-Viewer-1.1.3-Windows-x64-Portable.exe` | Windows 10/11 | x64 免安装包 |
| `MD-Viewer-1.1.3-x86_64.AppImage` | 麒麟 Linux | x86_64 免安装包 |
| `MD-Viewer-1.1.3-amd64.deb` | 麒麟 Linux | amd64 Debian 安装包 |

麒麟 Linux 不支持 ARM64/aarch64。iOS/iPadOS 保留源码兼容，不属于本次公开发布范围。

Windows 发布策略：1.1.3 是最后一个编译并公开提供的 Windows 版本。后续迭代不再编译、验证或发布 Windows 安装包，现有下载继续保留。

## 验证摘要

- macOS 真实窗口验证：红色关闭后重新激活显示欢迎页；黄色最小化后恢复仍显示原文档。
- 单元测试：12 项通过，0 失败，覆盖窗口关闭、程序坞重开、Finder 打开及文件读取失败回退。
- 图标：主图为 1024×1024 RGBA，透明画布有效；所有 macOS 图标尺寸已重新生成。
- macOS 构建：Release 通用二进制同时包含 arm64 与 x86_64，ad-hoc 签名和严格签名校验通过。
- Linux：离线打印验证通过；AppImage 为 ELF x86-64，Debian 包架构为 amd64、版本为 1.1.3。
- Windows：安装包与免安装包均包含 PE32+ x86-64 应用；应用资源、文件关联和离线渲染依赖完成结构检查。
- 依赖审计：`npm audit` 和生产依赖审计均无已报告漏洞。
- 校验：运行 `shasum -a 256 -c SHA256SUMS.txt`。

macOS 包尚未使用 Apple Developer ID 公证。Windows 包尚未使用代码签名证书，首次运行可能显示 Microsoft Defender SmartScreen 提示。Windows 与 Linux 包均在 macOS 打包环境完成结构与内容验证，尚未在对应系统运行图形界面。
