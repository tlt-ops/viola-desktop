# 隐私、权限与本地文件

以下 macOS 说明对应 0.2.50 Swift 源码。应用没有实现联网请求、账号登录、遥测、崩溃上传或自动更新；构建工具下载开发工具、GitHub 和你主动分享的反馈属于应用运行之外的行为。

## macOS 实际观察的输入

授予输入监控权限后，`InputListener` 使用 `.listenOnly` 的 `CGEvent` session tap，观察键盘按下/松开、修饰键变化、鼠标移动/拖动和左右点击。它读取物理键码、是否连发、事件时间、鼠标位置和位移，不调用字符解码，不读取剪贴板、正在编辑的正文或前台应用名称，也不注入或拦截输入。

**这仍然是全局键盘事件监听。** `keyboard-stats.json` 按键码（例如字符串形式的数字键码）持久化累计 `presses` 和 `repeats`。统计不保存逐次按键顺序或每次按键的时间，也不保存输入正文，但计数本身可反映键位使用习惯。未获全局权限时，仅有鼠标全局监视和应用内部事件监视作为降级，不保证其他应用中的键盘动作可用。

关闭“键鼠互动”会停止输入 listener。隐藏角色仅收起窗口，监听和统计可继续。应用还通过系统提供的“距上次输入事件的时间”判断桌面是否闲置；该查询不读取键码正文，与全局键盘 listener 分开，用于控制闲置爬行。关闭闲置爬行可取消自动爬行。

## macOS 本地文件

数据位于 `~/Library/Application Support/<profile>/`。`<profile>` 来自应用 `Info.plist` 的 `ViolaProfileDirectory`；没有该键时为 `ViolaDesktop`。当前仓库的 `packaging/Info.plist` 明确指定 `ViolaProfileDirectory` 为 `ViolaDesktop-Preview`，公开应用使用 `~/Library/Application Support/ViolaDesktop-Preview/`，延续原终稿的设置与统计目录。CLI 没有该 Info.plist 键时仍默认使用 `ViolaDesktop`；应用 bundle ID 为 `local.viola.desktop.preview`。首次启动新 profile 时从旧 `ViolaDesktop` 目录迁移 `config.json` 和 `keyboard-stats.json` 的规则不变。可在产物的 `Contents/Info.plist` 确认配置。

| 文件/目录 | 内容 |
| --- | --- |
| `config.json` | 尺寸、窗口坐标、互动/置顶/穿透/减少动作、桌面显示、闲置爬行、睡眠、笑声音源、开关与音量等设置 |
| `keyboard-stats.json` | 按物理键码聚合的按下/连发累计次数 |
| `diagnostics.json` | 权限及监听连接状态、事件总数、动画状态、窗口位置与尺寸、帧耗时/间隔、图层和动作诊断、角色最后一次按下/松开的屏幕及画布坐标、爬行窗口轨迹、系统闲置时长、素材/布局/笑声文件路径及加载错误 |
| `character-layout.json` / `character-assets/` | 用户可选的外部角色布局与素材覆盖，应用会读取它们 |
| `Sounds/` 或目录内的 `nailong-laugh.*` / `viola-laugh.*` | 用户可选的本地笑声覆盖，应用会读取它们 |

首次提示是否显示存于 `UserDefaults`（键为 `hasSeenWelcome`），由 macOS 按应用身份管理。若使用不同于 `ViolaDesktop` 的新 profile 且目录尚不存在，启动逻辑会尝试从旧 `ViolaDesktop` 目录复制 `config.json` 和 `keyboard-stats.json`，之后使用自己的文件。

统计在有变更时由约 2 秒的维护定时器和正常退出流程保存；诊断会约每 2 秒及部分状态变化时覆盖写入，不是仅在手动请求时生成。

诊断包含本机路径，可能间接暴露用户名、安装位置或自定义素材名称。反馈问题时不要整包上传 Application Support 目录；只提供必要字段，并删除用户名、绝对路径、点击坐标和轨迹等不需要的信息。CLI 渲染模式另将 PNG、布局/几何/姿势 JSON 写入你指定的输出目录，控制台错误也可能包含路径。

## macOS 控制与清理

- 在“系统设置 → 隐私与安全性 → 输入监控”中撤销权限，可停止获得全局键盘事件；应用内关闭“键鼠互动”会直接停止 listener。
- 若希望停止后台统计，关闭互动或退出；单纯隐藏窗口不够。
- 清理前先退出应用，备份需要的自定义素材与设置，再删除对应 profile 中的 `keyboard-stats.json`（重置统计）或 `diagnostics.json`（删除当前诊断）。重启后诊断会重新生成。
- 删除整个 profile 可重置该 profile 的文件，但如旧 `ViolaDesktop` 数据仍在，新 profile 的首次启动可能再次迁移旧设置与统计。请先确认自己使用的 profile，避免删错其他版本的数据。

角色运行不需要麦克风、摄像头、屏幕录制权限，代码也没有主动请求辅助功能权限；全局物理键盘互动请求的是输入监控权限。


## Windows 首次移植的范围

Windows 源码位于 `windows/`，采用 Win32 `WH_KEYBOARD_LL` / `WH_MOUSE_LL` 钩子观察键盘与鼠标。键盘回调处理 Windows virtual-key、按下/松开与连发状态；鼠标回调处理位置与左右按下。标记为注入的事件被忽略，回调始终继续调用下一钩子，不阻断用户输入。不读取字符正文、剪贴板或前台应用名称，源码没有网络客户端、遥测、上传或自动更新逻辑。

持久化文件只有 `%LOCALAPPDATA%/ViolaDesktop-Windows/settings.json`，包含窗口宽度、左/上坐标、互动/置顶/桌面显示/自动爬行开关、`LaughVariant`（`nailong` / `viola`）、`SoundEnabled`、`SoundVolume` 与 `KeyPresses`：按 Windows virtual-key 聚合的非连发按下累计次数。它与 macOS `presses`/`repeats` 统计不同，没有单独保存连发累计。设置和计数在有变更时约每 2 秒以及退出时保存，保存使用同目录的临时 `.tmp` 文件后替换。没有逐次按键顺序、正文、鼠标轨迹或持续诊断 JSON；窗口最终位置仍会保存。

隐藏 Windows 窗口会保留托盘、输入钩子和统计。暂停输入互动会注销两个钩子并清空内存中的按住状态，退出也会注销钩子。自动爬行依据应用观察到的输入时间；暂停全局监听后若仍开启自动爬行，程序不能用全局输入更新该计时。需要停止自动运动时请同时关闭自动爬行。

Windows 清单采用 `asInvoker`，不主动要求管理员权限，没有 macOS 式输入监控授权页面。清理前先退出并备份设置，再删除上述 `settings.json` 可同时重置统计和设置；Mac 数据不会被迁移或修改。

`--self-test` 使用临时目录；`--smoke-test <PNG路径>` 不注册输入钩子、不创建托盘、不读写用户设置，而将窗口渲染 PNG 写入指定位置。构建脚本保存日志及烟雾 PNG 到输出目录。反馈时仍请检查文件路径与截图，避免公开私人目录或桌面内容。Windows 功能与验证边界见 [Windows 文档](WINDOWS.md)。
