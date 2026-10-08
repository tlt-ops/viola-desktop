# 0.2.21 静息姿势

**状态：0.2.21 build 22 已安装，工程检查完成。** 隐藏键盘与鼠标时，薇欧拉一手轻抚紫发朋友头顶，另一手放在自己腿上。用户可继续补充审美反馈；物理键盘输入没有验收。

## 素材与合成

- 两张成功生成的素材：`Assets/RestingPose-v0.2.21/pose-reference.png`、`Assets/RestingPose-v0.2.21/arms-cutout.png`。提示词记录：`docs/RESTING_POSE_PROMPTS_V0.2.21.json`。
- 隐藏姿势中的 `ReferenceBodyJoin` 只清理旧左手区域 `world[203,518,112,48]`，清除 887 个占用像素；默认身体拼接保持逐字节不变，区域外 230435 个像素不变。先前右侧大面积清理已撤回。
- 由姿势素材生成了连贯腰带/围裙补片，左移注册 3 px；另以三个紧凑的底层补片遮住头发与身体缺口，仅用于隐藏键鼠的合成。

## 动作与验证

`RestingPoseRig` 将抚摸手与腿上手分开驱动：抚摸手掌沿朋友头顶支撑点移动，肩部随躯干，腿上手随身体。301 帧、5 秒动作检查测得横向 ±1.2 px、纵向 ±0.179960523 px；减少动态效果时行程为 `[0,0]`，动作终点已检查。最后的头发遮罩修改未改变手部 rig，但没有在该修改后单独重跑最终贴图动画。

`swift run --package-path . ViolaChecks` 的 23 项核心检查通过，日志为 `build/resting-pose-v0.2.21/core-checks.log`。build 22 安装的 strict/deep 签名检查通过；source、bundle 和 profile manifest hash 均为 `c292396db1d3a7fb994a24d71f1dcd02cc07be77fbf3b099944a1dfd334a3239`，两张新增 PNG 的包内副本匹配，安装未改配置。60 张原始 PNG 保持不变。记录见 `install.log`、`installed-verification.json` 和 `verification-summary.json`。

最终预览在 `build/resting-pose-v0.2.21/delivery-preview/`。可见状态 SHA-256 `d721498a862d7cc4bc4f6b8eae53fd59b94fafd715c1e73080c8d957d9c8a40e` 与 0.2.20 一致。原生 UI 中菜单由显示桌面切换为隐藏桌面后，截图确认新姿势出现；两个原生样本记录抚摸轨迹 `[1.0651266543, 0.1471806011]` 与 `[-0.3906744582, -0.1108172336]`。当前预览配置为 `showDesks=false`、宽度 537.158 pt、原点 `(839,195)`；原生复核前后配置无变化。输入权限和全局键盘连接仍为 false，没有执行物理键盘验收。
