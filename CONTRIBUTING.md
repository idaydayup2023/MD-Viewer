# 参与贡献

感谢改进 MD Viewer。提交变更前请遵循以下约定：

1. 不改写用户 Markdown 原文；兼容处理应放在解析或渲染层。
2. macOS、iOS 与 Linux 必须继续使用同一套 `MDViewer/Resources/Renderer` 资源和打印 CSS。
3. 修改渲染器后运行 `npm run test:print`，确认公式、Mermaid、代码与表格全部出现。
4. 修改 Swift 代码后运行 `MDViewer-macOS` 单元测试，并至少编译一次 iOS Simulator 目标。
5. 不提交 `Build`、`tmp`、`node_modules`、签名证书、配置文件或发布二进制；正式包上传到版本 Release。
6. 提交前运行 `npm audit`，不得忽略会进入最终应用的依赖公告。

报告缺陷时请说明平台版本、MD Viewer 版本、最小 Markdown 示例、复现步骤和预期结果。请先移除文档中的个人信息与敏感内容。
