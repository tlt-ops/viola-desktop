# 架构与开发入口

项目通过 Swift Package Manager 构建，有三个目标：

| 目标 | 职责 |
| --- | --- |
| `ViolaCore` | 输入活动状态、物理键位映射及累计统计、配置模型、动画状态与爬行/大笑/鞋子/衣物动作 |
| `ViolaDesktop` | AppKit 窗口与菜单、被动输入监听、资源加载、Core Animation 分层渲染、音频播放和诊断输出 |
| `ViolaChecks` | 可执行的核心行为及几何检查 |

## 运行流程

`main.swift` 启动 AppKit，普通运行交由 `AppDelegate` 管理。`InputListener` 的只读事件 tap 将物理键码、按下/松开、修饰键变化、鼠标位置/位移和左右点击转换为 `InputEvent`。事件同时送入 `AnimationEngine` 和 `KeyStatistics`；统计只处理有键码的 `keyDown`。演示输入直接送入引擎，绕过真实统计。

`AnimationEngine` 生成 `AnimationFrame`，`LayerRenderer` 和多个专用 rig 将它应用到角色图层。`CharacterAssets` 读取 `character.json`，加载裁切图像、遮罩和锚点。资源默认来自包内 `Resources/Characters/Viola`，应用数据目录的 `character-layout.json` 可提供覆盖布局；对应的 `character-assets` 可提供替换图片与遮罩。自定义布局加载失败时会尝试包内布局。

`PetPanel` 是透明、不抢主窗口焦点的桌面面板；`PetView` 处理点击、拖动、缩放和右键菜单。爬行期间使用扩大后的承载窗口、独立坐姿面板和图层展示区域协调运动，结束后收回窗口并恢复日常展示。屏幕范围变化也由 `AppDelegate` 处理。

帧计时器按 60 Hz 调度；实际绘制由状态和 `FrameCadence` 控制，普通闲置目标 30 fps、睡眠 15 fps、活跃动作及眨眼过渡 60 fps。实际帧间隔和耗时会写入诊断，目标帧率并非所有硬件上的性能保证。

`LaughAudio` 跟随大笑状态播放本地文件。优先顺序为应用数据目录的 `Sounds`、应用数据目录本身、包内角色目录的 `Sounds`；按持久化的 `laughSoundVariant` 选择 `nailong-laugh`（奶龙大笑）或 `viola-laugh`（薇欧拉大笑），依次尝试 `m4a`、`wav`、`mp3`。切换音源会停止旧播放器并保留当前大笑状态，下次大笑才播放新音源；所选音源缺失或读取失败时报告错误，不跨音源回退。不循环播放音频；8 秒是动画周期，音频播放时长由文件与动画退出决定。

## 检查与可复现渲染

```sh
swift run -c release ViolaChecks
swift run -c release ViolaDesktop --render-gallery build/gallery --pose-stills-only
swift run -c release ViolaDesktop --render-gallery build/laugh-review --fixed-laugh-review
swift run -c release ViolaDesktop --render-gallery build/crawl-review --crawl-review --crawl-quick-review
swift run -c release ViolaDesktop --render-gallery build/arm-review --source-arm-return-review
```

渲染命令需要 macOS 图形环境，输出 PNG 和相应 JSON 到指定目录，然后退出。`--layout FILE` 可与 `--render-gallery` 一起指定外部布局，`--hide-desks` 可隐藏桌面键鼠。其他历史调试开关在 `Sources/ViolaDesktop/main.swift` 中定义，主要用于定点渲染、逐帧几何和视觉回归；它们不是稳定的公共 CLI API。

渲染检查用于检查特定姿势、图层隔离和约束，仍需观察实际连续动画，尤其是大笑回位、爬行中断、多屏及权限恢复。维护时优先保留原有图层归属，避免将日常输入臂、独立笑姿、伙伴眼睛与爬行动作互相污染。
