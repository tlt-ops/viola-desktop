# 0.2.20 桌面与手臂配准

**状态：build 21 已安装，桌面修复工程复核完成。** 用户审美确认仍待反馈；物理键盘输入未验收。

## 布局调整

- 使用连续的 `DeskSurfaceRig` 取代分别旋转的桌面板，并保留原桌面纹理。
- 键盘、左掌和手指作为一组移动 `(-15, -60)`；鼠标手、参考姿势和大笑姿势作为一组移动 `(+30, -50)`。肩部位置保持不变。
- 新生成的静态右袖口只在显示桌面时加遮罩。
- 桌面 root 放在可互动袖子下方，避免遮住袖口。最终后铰链 y 为 547，右后缘 y 为 541。

## 验证状态

当前 checkout 的现有 core suite 使用 `swift run --package-path . ViolaChecks` 执行，23 项核心行为检查全部通过；该命令在项目 `.build` 中构建，不使用 release staging package。82 键几何检查是在首轮 cuff mask 后、最终后缘/mask-boundary/layer-order 调整前完成：最大指尖误差 `1.45516421109398e-10` 画布像素，右手漂移为 0。最终三项调整后未重跑；它们没有改变键位或手部几何。16 个最终姿势预览位于 `build/desk-repair-v0.2.20/verified-poses/`。

遮桌画面与 0.2.19 完全一致，SHA-256 为 `17b155af3375ca4dfcb1405e4635cb7ad7c84c31cd6f56761be6cfd723ef6174`，见 `build/desk-repair-v0.2.20/verified-visibility/hidden.png`。build 21 已安装，`build/desk-repair-v0.2.20/install.log` 中 strict/deep 签名检查通过。源、bundle、profile manifest hash 均为 `dd40372da0f4b6dd38e58364c743576b0c78ab30b019fadafc703ac5add61e7e`，见 `installed-verification.json`。

素材比较确认 60 张原始 PNG 与 0.2.19 备份相同，没有原始 PNG 改动；记录见 `build/desk-repair-v0.2.20/retained-assets.json`。汇总数据见 `build/desk-repair-v0.2.20/verification-summary.json`。

原生 UI 已实际操作“显示桌面→隐藏桌面→再显示桌面”，当前 `showDesks=true` 供用户预览。10 秒演示截图显示黄色 Space 键以及手/鼠标动作；`native-demo.json` 在演示结束回到 idle 后采集，不能作为 demoActive=true 的证据。全局输入权限和键盘连接均为 false，没有执行物理键盘验收。当前预览为 `build/desk-repair-v0.2.20/verified-poses/desk-preview.png`。用户审美确认仍待反馈；既有肩部与裙摆接缝问题不属于本次桌面修复。

恢复的用户预览配置为 `showDesks=true`、宽度 751.666 pt（原生窗口显示 752 pt）、原点 `(541, 0)`，其他配置与检查前一致。0.2.19 的应用/profile 备份保存在 `build/preserved-v0.2.19-before-desk-repair/`。
