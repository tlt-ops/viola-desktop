# 贡献指南

欢迎通过 issue 报告问题，或提交范围明确的 pull request。先说明触发条件、预期行为和实际结果；动画问题最好附带短视频或局部截图。

开发需要 macOS 13+ 和 Swift 5.9+。运行 `swift build -c release`、`swift run -c release ViolaChecks`，并在修改相应 rig 后使用 [渲染检查](docs/ARCHITECTURE.md) 和实机连续动画验证。涉及输入权限、多屏、菜单、拖动或音频时，请报告实际执行过的操作与平台，不把构建成功写成全部行为通过。

保持 `ViolaCore` 的状态计算与桌面/资源逻辑分开；避免引入不必要的依赖。新增全局输入字段、持久化数据或网络行为时，同步更新 [隐私说明](docs/PRIVACY.md)。本机配置、键位统计和完整诊断请勿提交到仓库。

代码贡献将按项目 MIT License 发布。图片、音频及派生预览遵循独立素材范围；新增素材必须提供作者/来源和足够的许可信息，见 [素材说明](docs/ASSETS.md)。
