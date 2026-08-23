# MD Viewer for 麒麟 Linux

此版本与 macOS/iOS 版本共用同一套 Markdown、公式、代码与 Mermaid 渲染内核，并保持目录、搜索、源文对照、主题和阅读设置一致。

## 支持架构

当前发布版仅支持 `x86_64`（Debian 架构名为 `amd64`）。在麒麟终端运行：

```bash
uname -m
```

只有输出为 `x86_64` 时，才能使用本目录中的安装包：

| AppImage | Debian 安装包 |
| --- | --- |
| `MD-Viewer-1.1.3-x86_64.AppImage` | `MD-Viewer-1.1.3-amd64.deb` |

ARM64/aarch64、龙芯 LoongArch、申威等其他架构不在当前发布范围内，不应使用上述安装包。

## AppImage

```bash
chmod +x MD-Viewer-1.1.3-x86_64.AppImage
./MD-Viewer-1.1.3-x86_64.AppImage
```

如果系统缺少 FUSE：

```bash
./MD-Viewer-1.1.3-x86_64.AppImage --appimage-extract-and-run
```

## Debian 安装包

```bash
sudo apt install ./MD-Viewer-1.1.3-amd64.deb
```

卸载：

```bash
sudo apt remove md-viewer
```

## 使用

- 从应用菜单启动 “MD Viewer”。
- 点击“打开”选择 `.md`、`.markdown`、`.mdown`、`.mkd` 或 `.txt`。
- 也可以在终端运行 `md-viewer 文件.md`。
- “源文”用于并排查看 Markdown 原文。
- “打印”使用与 macOS/iOS 相同的 A4 版式，并在公式、图表和图片完成后打开系统打印面板。
- 齿轮按钮可切换亮暗主题、正文宽度、字号与原始 HTML。
- 默认禁用原始 HTML，MathJax、Mermaid 和代码高亮均离线运行。

## 从源码构建

需要 Node.js 与 npm：

```bash
npm install
npm run linux:dist
```

输出位于 `Build/Linux`。
