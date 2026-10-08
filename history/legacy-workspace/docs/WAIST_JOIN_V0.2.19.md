# 0.2.19 腰部拼接修复

**状态：build 20 已生产编译、安装并完成原生配置检查；用户最终视觉验收 pending。** 本轮集中修整腰部与裙摆的局部拼接，不代表整体视觉验收完成。补片底边限制已加入并重新渲染、安装：膝部以下只保留围裙谷部及右侧发丝补缺，限制生成腿随原腿活动时露出。最终安装后原生窗口已重新打开。

## 局部调整

- 以旧腰部补片重新配准裙摆局部，并取消横带裁切。
- 补上左下深色布料缝和紫发顶部窄带；袖口局部对齐原手。
- 对补片覆盖范围内、原上身和下裙被桌面截断的边缘做局部渐隐。
- 移除 `viola_skirt` 中 `worldY>505` 的重复上身残片；保留原有露出的大腿和裙摆下缘。
- 所有源 PNG 均保持不变。

## 检查与边界

预览位于 `build/waist-join-v0.2.19/verified-preview`，已完成本地预览复核；用户最终视觉验收待确认。build 20 安装完成，安装日志 `build/waist-join-v0.2.19/install.log` 的 strict code-signature 验证通过。安装后检查确认源文件、bundle 与 profile 的 57 个 sprite 和 29 个 PNG 一致，见 `build/waist-join-v0.2.19/asset-parity-before.json` 与 `build/waist-join-v0.2.19/installed-verification.json`。原生重启后验证了 `showDesks=false` 持久化，随后通过菜单恢复为原来的 `true`；前后配置所有字段一致，证据见 `native-hidden-diagnostics.json`、`config-before-native-check.json` 和 `config-after-native-check.json`。0.2.18 的 23 项核心检查记录在 `build/body-completion-v0.2.18/core-checks.log`，本轮没有重跑；本轮完成生产编译、预览检查、安装和原生配置检查。

原 0.2.18 应用与 profile 备份保存在 `build/preserved-v0.2.18-before-waist-join/`。旧紫裙分区细线及桌面手臂布局不在本轮修改范围，仍待后续处理。

| 验证项目 | 状态 |
|---|---|
| 0.2.19 build 20 生产编译 | 已通过 |
| 修复预览生成与本地复核 | 已完成 |
| 安装与 57 sprites / 29 PNG 一致性 | 已通过 |
| 原生隐藏桌面、重启后配置保存及恢复 | 已通过 |
| 补片底边限制的重新渲染与更新安装 | 已完成 |
| 最后安装后的原生窗口启动 | 已通过；腰部细节以无桌面生产预览复核 |
| 用户最终视觉验收 | pending |
