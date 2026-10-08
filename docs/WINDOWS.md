# Windows 版本

Windows 版是同一仓库中的独立原生桌面实现，源码位于 `windows/`，使用 .NET 10、WPF 和 Win32 输入接口；macOS 版仍由 Swift/AppKit 构建。Windows 版使用 macOS 角色渲染器导出的 PNG 动画图集，不是把 AppKit 源码直接编译到 Windows。

## 下载与运行

在 [GitHub Actions](https://github.com/tlt-ops/viola-desktop/actions) 中，Windows 构建成功的运行会提供下载产物；正式发布的包请从 [Releases](https://github.com/tlt-ops/viola-desktop/releases) 查找。下载 `viola-windows-win-x64.zip` 后完整解压，运行其中的 `Viola.Windows.exe`，保留旁边的运行库和 `Assets` 目录。

发布包面向 Windows x64，使用 self-contained 多文件发布，运行时不需要另行安装 .NET。当前仓库配置不提供 Windows ARM64 的原生发布包。包未进行商业代码签名，下载后可能出现 SmartScreen 提示；确认来源后再决定是否运行。

## 从源码构建

在 Windows 上安装 .NET SDK 10.0.x，使用 PowerShell：

```powershell
git clone https://github.com/tlt-ops/viola-desktop.git
cd viola-desktop
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1
```

也可在 PowerShell 7 中执行 `pwsh -File .\scripts\build_windows.ps1`。默认输出为：

- `build/windows/win-x64/Viola.Windows.exe` 与完整发布目录；
- `build/windows/viola-windows-win-x64.zip`；
- `build/windows/smoke.png`（构建脚本的窗口渲染冒烟检查输出）；
- `build/windows/logs/`（publish、自检和冒烟检查日志）。

可用 `-OutputDirectory <dir>` 指定输出根目录。脚本先 publish，再执行 `--self-test` 与 `--smoke-test <PNG路径>`；`--smoke-test` 不注册输入钩子、不创建托盘、不读写用户设置，约 1 秒后保存窗口 PNG 并退出；`--self-test` 使用临时文件测试核心数据/图集约束。这些检查通过也不等于已经验证真实键鼠钩子、系统托盘、多屏和持续运行。Windows CI 使用同一构建入口。

## 重新生成角色图集

发布包已经包含图集，普通 Windows 构建不需要 Mac 或 Python。若修改角色素材并重新生成图集，需要在 macOS 使用原生渲染器导出，再用 Python 3 与 Pillow 打包：

```sh
swift build -c release
swift run -c release ViolaDesktop --export-windows-frames build/windows-frames
python3 scripts/pack_windows_sprites.py build/windows-frames windows/Assets/sprites
```

当前 manifest 包含 8 个动画 clip 和 178 个姿势映射。角色视觉仍基于 0.2.49，应用版本为 0.2.50；图集打包会逐帧比较 RGBA 字节，保持导出图像的透明边缘。运行时先检查 PNG 头部和 manifest，再按需解码图集/姿势，图集缓存最多 2 张并设有 128 MiB 目标预算（单张超出时仍保留当前活动图集），姿势缓存最多 12 张。这是实现边界，不是 Windows 实测内存或性能结果。

## 已实现的功能与差异

Windows 源码包含透明桌面窗口、置顶切换、托盘菜单、拖动、滚轮缩放、上半身点击大笑、手动爬行和自动闲置爬行；右键菜单可切换桌面键鼠显示、输入互动和自动爬行，并查看本地键码累计次数。菜单目前使用英文。

0.2.50 的大笑周期为 8 秒，键鼠输入不会打断正在播放的笑姿。右键菜单可选择“奶龙大笑 / 薇欧拉大笑”并开关笑声，选择分别读取 `Assets/nailong-laugh.m4a` 或 `Assets/viola-laugh.m4a`。切换会停止并关闭旧声音，下次大笑使用新选择；文件缺失或播放失败会显示状态，不自动回退。音量设置默认 0.8，当前没有音量调节界面。爬行持续约 8 秒并在窗口工作区域内平滑移动；监听到输入时退出爬行、恢复坐姿并保留当前位置。自动爬行依据应用观察到的活动时间，约 25 秒后触发；暂停输入互动后它无法用全局输入更新闲置计时，可同时关闭自动爬行。

| 范围 | macOS | Windows 首次移植 |
| --- | --- | --- |
| 角色展示 | 动态分层 rig | 导出的 PNG 图集/键位姿势，整帧替换 |
| 输入统计 | 物理键码按下与连发分别累计 | Windows virtual-key 非连发按下累计 |
| 交互设置 | 包含穿透、捏合、减少动作、睡眠等 | 置顶、拖动、滚轮、桌面显示、输入与自动爬行开关 |
| 鞋子与完整图层编辑 | 专用动作及布局机制 | 未移植掉鞋/穿鞋交互和完整可编辑图层 rig |
| 数据与诊断 | 配置、键位统计、持续诊断 | 一个设置/累计统计 JSON，无持续诊断文件 |

Windows 的输入映射采用 Windows virtual-key 到已有角色键位姿势的映射，不能保证所有键盘布局与扩展键都和 macOS 的物理 ANSI 映射等价。当前没有鼠标穿透、触控板捏合、10 秒演示或高级手指分区统计界面。Windows hook 状态可在右键菜单查看；注册失败时动作仍可由菜单触发，暂停/重开互动可尝试重新连接。

## 输入与本地数据

默认启用低级键盘/鼠标钩子，观察虚拟键码、按下/松开/连发状态、鼠标位置和左右点击，忽略标记为注入的事件。回调继续传递事件，不解码正文。保存文件为 `%LOCALAPPDATA%/ViolaDesktop-Windows/settings.json`，包含窗口位置/大小、互动与显示开关、音源/笑声开关/音量和按 virtual-key 聚合的非连发按下累计次数。隐藏窗口仍保留钩子与统计，暂停输入互动或退出才注销钩子。完整范围见 [隐私说明](PRIVACY.md)。

程序清单采用 `asInvoker`，不主动请求管理员权限；Windows 没有本应用对应的 macOS“输入监控”开关。此实现没有屏幕捕获、麦克风或摄像头功能，也没有联网、上传或自动更新代码。

## 验证范围

Windows 端的源码、图集和构建配置在 macOS 上准备；Windows CI 与真实 Windows 桌面运行结果应以实际执行记录为准。未执行的构建、权限/输入和音频行为不能记为通过。此移植不承诺与 macOS 版的每个可编辑图层、掉鞋/穿鞋交互或高级统计界面完全等价。

素材仍属[非官方二创并采用独立授权范围](ASSETS.md)；代码 MIT 不覆盖图片、音频和图集。
