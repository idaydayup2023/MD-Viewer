# MD Viewer 发布目录

每个版本使用独立子目录，包含平台安装包、发布说明与 SHA-256 校验文件。

- macOS：通用架构压缩包，解压后将 `MD Viewer.app` 放入“应用程序”。
- Windows：支持 x64，提供 NSIS 标准安装包和免安装包。
- 麒麟 Linux：仅支持 x86_64（Debian 架构名 `amd64`），不提供 ARM64。

iOS/iPadOS 仅保留源码兼容与内部编译验证，不放入公开 Release，也不提供 Simulator、IPA、App Store 或 TestFlight 下载包。

进入相应版本目录后可运行：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

二进制包保存在本地用于正式发布，但按 `.gitignore` 约定不直接提交到源码仓库；创建 GitHub Release 时再上传。
