# MD Viewer for Windows

Windows 版本与 macOS、iOS 和麒麟 Linux 版本共用同一套 Markdown、公式、代码与 Mermaid 离线渲染内核，并保持目录、搜索、源文对照、主题和阅读设置一致。

## 系统要求

- Windows 10 或 Windows 11
- x64 处理器

Windows ARM64 和 32 位 Windows 不在当前发布范围内。

## 安装版

运行 `MD-Viewer-1.1.3-Windows-x64-Setup.exe`，可选择安装目录并创建桌面和开始菜单快捷方式。安装版会注册 `.md`、`.markdown`、`.mdown`、`.mkd` 和 `.txt` 文件关联。

## 免安装版

直接运行 `MD-Viewer-1.1.3-Windows-x64-Portable.exe`，无需安装。

## 使用

- 从开始菜单或桌面快捷方式启动“MD Viewer”。
- 点击“打开”选择 Markdown 或纯文本文件。
- 也可以双击已关联的文档，或把文档路径传给 `md-viewer.exe`。
- 默认禁用原始 HTML，MathJax、Mermaid 和代码高亮均离线运行。

## 从源码构建

建议在 Windows 10/11 x64 环境构建。安装 Node.js 与 npm 后运行：

```powershell
npm install
npm run win:dist
```

输出位于 `Build/Windows`。
