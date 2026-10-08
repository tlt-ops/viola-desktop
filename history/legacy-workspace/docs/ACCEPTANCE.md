# Current review — 0.2.40 build 41 (sleeve and keyboard accepted)

This revision retains the correct mouse-grip hand restored in 0.2.39 and replaces the cuff treatment the user rejected as twisted. `StraightMouseArmRig` extends the original straight frontal sleeve from `frontal-arms-v0.2.5.png` longitudinally with an affine transform for the upper sleeve; the lower sleeve uses a rigid white cuff and near-wrist skin section. The normal mouse-hand/cuff angle is 0°. There is no elbow, triangle patch, or 45° compensation, and the old 0.2.31 source mesh is hidden and not rendered.

- All 2770 review stages passed, including 2574 desktop straight-sleeve stages. Minimum determinant was 0.56456 and maximum cuff gap was 2.54e-13. All 35 core checks passed.
- Hidden-desk before, laugh, and after-settled PNGs are pixel-identical to 0.2.39. The enlarged normal-pose sleeve was reviewed by root and a read-only reviewer as continuous with no fold-back. During laugh, the sleeve shortens longitudinally and folds are more concentrated; no broader claim about dynamic sleeve naturalness is made.
- Installed 0.2.40 build 41 and reopened the app. Native CUA observed normal straight sleeve → menu-triggered laugh → normal pose restored. `native-after-laugh.json` records `mode=straight-extension`, `handAngle=0`, and `cuffRigid=true`. The sleeve review and native pose cycle are complete.
- The final verification records 35 core checks and 2770 review stages. NumPy compared the complete RGBA pixels of the three hidden-desk images (before, laugh, and after-settled) against 0.2.39; all three match exactly.
- Input Monitoring authorization was refreshed through System Settings by removing the old Viola entry, adding the exact current app at `Viola 新版.app`, then using the system's Quit and Reopen action. Fresh runtime diagnostics report `inputPermission=true`, `globalKeyboardConnected=true`, `interaction=true`, and `demo=false`, with `KEY_DOWN=2`, `KEY_UP=2`, and `MOUSE_MOVE=333`. The user confirmed “现在会跟着敲了”. This confirms real user keyboard interaction; synthesized CUA input is not counted as that confirmation.
- Preserved scale is `298.32211192312377`; sound remains off. Backup: `~/Library/Caches/ViolaDesktop/preserved-v0.2.39-before-straight-sleeve`. Evidence: `build/straight-mouse-arm-v0.2.40/verification.json`, `native-after-laugh.json`, and `keyboard-connected-user-confirmed.json`.

---

# Historical review — 0.2.39 build 40 (user-rejected cuff twist)

The mouse-side hand in the seated pose was restored to Viola's anatomical left hand. Builds 0.2.29/0.2.31 had substituted a lap-resting bare hand for the frontal mouse-grip artwork from 0.2.25, while the mouse layer also covered the fingers. A hand-only layer was extracted from the original pixels in `frontal-arms-v0.2.5.png` (source RGB difference 0), then registered with a 45° cuff. Normal and laugh poses used the same solid hand layer and moved it continuously; the hidden-desk pose was unchanged. The user rejected the cuff as twisted and requested a direct sleeve extension; see current candidate 0.2.40 above. The correct hand artwork and its validation remain retained.

- Installed 0.2.39 build 40 in `~/Applications/Viola 新版.app`. Native CUA observed normal mouse grip → menu-triggered laugh with hands at the abdomen → normal mouse grip restored. Native diagnostics recorded `laughWeight=0`, `mouseGripOpacity=1`, and `emptyMouseHandOpacity=0` after return.
- All 35 core checks passed. The 2770-stage render review covered all four actual-engine mouse bounds corners and reverse return motion. Input Monitoring and global keyboard connection remain false; sound remains off. Preserved user scale `298.32211192312377`; crawl, performance, and face artwork are unchanged.
- Backup: `~/Library/Caches/ViolaDesktop/preserved-v0.2.38-before-mouse-grip-restore`. Evidence: `build/mouse-grip-v0.2.39/final/`, `build/mouse-grip-v0.2.39/final-review.log`, and `build/mouse-grip-v0.2.39/core-checks.log`.

---

# Historical review — 0.2.38 build 39

This build adjusted the mouse-side forearm constraint but retained the wrong hand artwork. The user rejected the visual result; build 0.2.39 restores the actual frontal mouse-grip hand and its layer order. The measurements below document the historical geometry/performance work, not final visual acceptance of that hand. Crawl rendering now uses a fixed host window and a fixed frame deadline. This avoids moving the `NSWindow` every frame and avoids a duplicate timing gate; crawl timing, speed, artwork, and eye behavior are unchanged. The gesture migration fix retains the same window and maps drag events through screen coordinates.

- All 478 arm-review stages passed. Desk-visible and desk-hidden before/after renders returned exactly to baseline in all four full RGBA comparisons, both immediately after laughter and after settling. All 35 core checks passed, including four checks for animation frame scheduling.
- Native renderer-call measurements recorded Crawl at 466 calls, 8.53 Hz and p95 351.69 ms in its last sample; fixedhost's most recent sample recorded 600 calls, 59.896 Hz and p95 17.447 ms. The sampling windows differ, and these are renderer-call measurements rather than GPU display FPS. The later final 600-sample native snapshot is recorded below.
- A full crawl measured 27.369 seconds, 1496 canvas units, and −299.2 screen points at width 160; desks and the small window were restored. Laugh renderer-call frequency was approximately twice the baseline in sampled runs: first candidate 59.24 Hz vs 29.95 Hz, with a final snapshot at 58.85 Hz. Treat these values as approximate.
- Installation preserved profile configuration, statistics, and layout hashes. Input permission remains false and sound remains off.
- Final native click check recorded one mouse-down and one mouse-up, with `gestureActive=false` (`native-click-interruption-fixed.json`). Final drag completed once from screen point `(1061,605)` to `(1071,600)`; the panel moved from rounded origin `(953,524)` to `(963,519)`, exactly `(+10,-5)`, and ended with `gestureActive=false` (`native-drag-final.json`). The gesture migration fix retains the same window and routes drag events through screen coordinates.
- A subsequent head click produced one laugh request. The native screenshot confirmed the rider laughing with hands at her abdomen and the purple-haired friend open-eyed with an effort expression (`native-laugh-click-final.json`).
- Final full crawl completed with `cancellationReason=none`, 1496 canvas units, and 27.361 seconds from the last `windowPath` elapsed sample. It ended with the 172-point native host and desks restored (`native-final-end.json`). During the sequence, the user set width to 171.087 points (native width 172); the crawl changed the window position normally. The last install record shows the latest profile hashes and install-time width 171.087, origin `(994,524)` (`last-install.json`); this is the install-time state, not a claim that later native checks kept that position.
- The final 600-sample Crawl draw-interval snapshot measured 57.054 Hz effective rate, p95 17.530 ms, and maximum interval 165.421 ms while other UI actions also occurred. This is renderer-call timing, not display FPS; it does not establish a no-dropped-frame guarantee. The earlier quiet same-width-160 fixedhost sample remains 59.896 Hz with p95 17.447 ms. Do not compare these as equivalent workloads.
- Native click, drag, laugh, and full-crawl checks are complete. Input Monitoring remains off and sound remains off. Cross-app physical click-through in the transparent blank area remains unverified; the temporary probe has been closed.
- Evidence: `build/smooth-motion-v0.2.38/comparison.json`, `native-click-interruption-fixed.json`, `native-drag-final.json`, `native-laugh-click-final.json`, `native-final-end.json`, and `last-install.json`.

---

# Historical review — 0.2.37 build 38

The user clarified that the purple-haired girl should keep her eyes open during the rider's laugh and show effort instead of closing her eyes. Effort is now decoupled from the girl's eyelids: her original open eyes and purple irises remain visible, with a slight inward brow tension and a tightened mouth with a narrow tooth gap. Ordinary idle blinking remains unchanged.

- Release build, all31 core checks, and38 focused expression stages passed. Three effort/laugh plus full-blink conflict checks all kept friend closure at0; ordinary full blink still reached1. All13 ordinary-blink full-frame RGBA results exactly match0.2.36, all11 rider laugh face crops are unchanged, and the original friend-eye pixels match the open-eye neutral state. Friend closure remained0 throughout laugh samples.
- Strict/deep signature verification passed. Installed0.2.37/build38 and confirmed configuration, statistics, and layout bytes were identical across installation. User width351.1779107442044, position(198,20), `showDesks=true`, and sound-off were preserved. The .35 crawl speed, cadence, travel, duration, and motion amplitude remain unchanged.
- Native CUA inspection of a click-triggered laugh showed the rider laughing with hands at her abdomen while the purple-haired girl kept her eyes open and showed the narrow tooth gap. Diagnostics recorded `peakLaugh=1`, `peakFriendEffort=1`, and `friendClosure=0` across samples; afterward state returned to Idle with effort and closure at0, `showDesks=true`, and Input Monitoring off.
- Evidence: `build/friend-effort-v0.2.37/verification.json`, `v2/source-motion-review.json`, `friend-effort-final.png`, `install-verification.json`, `native-verification.json`, `native-laugh-diagnostics.json`, and `native-after-laugh-diagnostics.json`.

---

# Historical review — 0.2.36 build 37

This version forced the purple-haired girl to close her eyes during the rider's laugh. User feedback clarified that the girl should remain open-eyed and show effort. The ordinary idle blink repair remains, but the laugh-time closure behavior was superseded by0.2.37.

- Release build, all31 core checks, and strict/deep signature verification passed. The native laugh showed full friend closure and the rider's laugh, then returned to Idle with the eyes reopened.
- Evidence: `build/friend-eyes-v0.2.36/verification.json`, `v3/source-motion-review.json`, `friend-closed-final.png`, `core-checks-final.log`, `install-verification.json`, `native-laugh-diagnostics.json`, and `native-after-laugh-diagnostics.json`.

---

# Historical review — 0.2.35 build 36

Crawl speed is halved again from110 to55 canvas points per second. Cycle, entry, exit, and settlement timings double to0.72s,0.14s,0.18s, and0.208s; maximum target travel stays1496 and analytic full-motion duration is27.36s. The purple-haired girl's body sway, bob, roll, hand lift, and knee motion are1.5× the previous version. Horizontal palm stance travel remains unchanged to avoid slipping, and rider bounce remains unchanged.

- Release build and all31 core checks passed. Forward and reverse 170-frame render verification passed: minimum limb-mesh determinant0.5084827483026991, palm target error<0.045, shoulder error<0.00474, waist error2.54e-13, thigh attachment error0, and all16 friend-isolation comparisons matched.
- Strict/deep signature verification passed. Installed0.2.35/build36 and confirmed configuration, statistics, and layout bytes were identical across installation. User width331.3890170147332 (native width332) and sound-off were preserved. Input Monitoring remains off.
- Native manual crawl completed in27.489041541644838s with canvas travel1496, native window travel620pt at width332, `cancellationReason=none`, and the desk restored. Measured speed was22.8255027245 screen points/s (expected22.825).
- Evidence: `build/crawl-v0.2.35/build.log`, `core-checks.log`, `render-verification.json`, `render/crawl-review.json`, `install-verification.json`, `native-verification.json`, and `native-completed-diagnostics.json`.

---

# Historical review — 0.2.34 build 35

Crawl speed is halved again, from 220 to 110 canvas points per second. Cycle, entry, exit, and settlement timing are doubled while stride and the 1496 canvas-unit maximum target remain unchanged. Analytic integration gives a full-motion duration of 13.68s. Native movement remains bounded by the screen edge.

- Cached Release build, all31 core checks, and strict/deep signing passed. Timing checks cover fixed, coarse, skipped, and irregular frame intervals, exact target travel, cancellation, queued laughter, reduced motion, and stance compensation.
- Installed0.2.34/build35. Native manual crawl ran for10.4680209583s before screen-edge cancellation: window travel850pt and canvas travel1134.86905125, with `cancellationReason=edge`. Desks were restored afterward. At user width599.5466673556596 (native width600), measured speed was82.4526050642 screen points/s (expected82.5), corresponding to110 canvas points/s. This edge-limited run did not complete the 1496-unit target.
- Configuration, statistics, and layout bytes matched across installation. User width and sound-off setting were preserved. Previous0.2.33 app/source/profile are retained at `~/Library/Caches/ViolaDesktop/preserved-v0.2.33-before-half-speed/`.
- Evidence: `build/crawl-v0.2.34/install-verification.json`, `native-verification.json`, and `native-completed-diagnostics.json`.

---

# Historical review — 0.2.33 build 34

Crawl speed is 0.5×0.2.32 (440→220 logical points/s), target travel is 10× (149.6→1496), and cadence slows from0.09s to0.18s per cycle with the same stride. Entry0.035s, exit0.045s and cancellation settlement0.052s preserve the slower timing. Analytic integration determines duration6.84s. Screen-edge stopping and idle frequency remain the existing behavior.

- Cached Release build, all31 core checks and strict/deep signing passed. Fixed/coarse/skipped and irregular frame intervals reach the exact target without replaying distance; cancellation, queued laughter, reduced motion and stance compensation pass.
- Installed0.2.33/build34 and triggered native manual crawl. Completed naturally in6.911177s, canvas travel1496, native window travel−672pt at width359, cancellationReason=none. Desks restored afterward.
- Latest user configuration, statistics and layout were byte-identical during installation, including width358.5878989111005 and sound-off. Input Monitoring remains off. Previous0.2.32 app/source/profile retained in `~/Library/Caches/ViolaDesktop/preserved-v0.2.32-before-long-crawl/`.
- Evidence: `build/crawl-v0.2.33/requested-change.json`, `install-verification.json`, `native-verification.json` and `native-completed-diagnostics.json`.

---

# Historical review — 0.2.32 build 33

Crawl speed is ten times the 0.2.31 speed: speed44→440 logical points/s, duration3.6→0.36s, cycle0.9→0.09s, with entry/exit and cancellation settlement scaled by the same factor. Maximum travel remains149.6 logical points. Manual and idle triggers use this shared motion.

- Cached Release build, all31 core checks, and strict/deep application signing passed. Existing timing checks cover positive/negative travel, skipped-frame integration, alternating contacts, cancellation and queued laughter.
- Installed and launched0.2.32/build33. Native manual menu action was exercised. A completed native idle crawl was recorded at0.376774s, canvas travel149.6, window travel30pt at width 160, cancellationReason=none, with the desk restored.
- Config, key statistics and character layout remained byte-identical during installation. Input Monitoring stays off. Previous0.2.31 app/source/profile are retained at `~/Library/Caches/ViolaDesktop/preserved-v0.2.31-before-crawl-10x/`.
- Evidence: `build/crawl-v0.2.32/speed-change.json`, `install-verification.json`, `native-verification.json`, and `native-completed-diagnostics.json`.

---

# Historical review — 0.2.31 build 32

Source portrait motion repair is installed. Laughter now blends both hands toward the abdomen in both desk modes, with a smiling mouth, animated brows and continuous eyelids. Independent blink timing replaces simultaneous threshold-based eye swapping. Source sleeves use articulated meshes with rigid cuffs and palms; keyboard layers render below the fingers. Hidden arm regions use source-derived backing textures. All four leg assets remain byte-identical to 0.2.29.

- Release build and 31 core checks passed. The final source-motion sweep passed 485 frames: 13 blink phases, 386 laugh frames, 82 key poses and four mouse extremes. Minimum arm determinant is 0.1562503371, maximum cuff gap 1.27e-13, and maximum wrist error 1.42e-14 logical points.
- Forward/reverse crawl regression passed 170 frames, 16 friend-isolation comparisons and zero thigh attachment error.
- Native CUA inspection showed belly hands, a smiling mouth and body bounce with desks both shown and hidden. The native typing demo showed fingers above the keyboard and joined wrists.
- App version 0.2.31/build32 and strict/deep code signature verified. All 25 referenced sprite entries and manifests match source, bundle and live profile.
- Config and statistics were byte-identical immediately after installation. User width 160, desk visibility and sound-off settings were retained; automatic crawling continues to update window position normally. Input Monitoring remains off, so real global keyboard input is not claimed.
- Evidence: `build/motion-v0.2.31-final/verification.json`, `install-verification.json`, `source-motion-review.json`, `laugh-preview.gif`, and [repair details](MOTION_REPAIR_V0.2.31.md). The 0.2.29 app/source/profile backup is in `cache/preserved-v0.2.29-before-motion-repair`.

---

# Historical review — 0.2.29 build 30 (restored)

The installed app and live character profile were rolled back from 0.2.30 build 31 to the preserved 0.2.29 build 30 at the user's request. The complete signed .29 app bundle, source, package manifest, packaging files, character layout, and its referenced profile sprites were restored from `cache/preserved-v0.2.29-before-thigh-correction`. The complete current .30 app, profile, source, and packaging snapshot remains archived at `cache/rollback-v0.2.30-before-thigh-rollback-20261003-144000`.

- App metadata is version 0.2.29, build 30. Strict/deep code-signature validation passed.
- All 25 active sprite entries match by SHA-256 across preserved backup, source, app bundle, and live profile.
- `config.json` and `keyboard-stats.json` matched their pre-rollback bytes immediately after the filesystem restore. The native app later rewrote `config.json` on relaunch; its latest bytes were left untouched. `keyboard-stats.json` still matches the pre-rollback hash.
- Native relaunch confirmed the restored app visible at version 0.2.29. The diagnostic showed `showDesks=true` and `inputPermission=false`; no physical keyboard input acceptance is claimed.
- Verification evidence: `build/rollback-thigh-v0.2.30/verification.json` and `build/rollback-thigh-v0.2.30/native-acceptance.json`.
- 0.2.30 art and render evidence remain in `build/thigh-v0.2.30/`; see [rollback status](THIGH_V0.2.30.md).

---

# Historical review — 0.2.29 build 30

以用户提供的完整人物图替换原有分散身体素材。图像为 1145 × 1374，统一映射 `worldX = 24 + 0.64 × sourceX`、`worldY = 940 − 0.64 × sourceY`。源文件与处理记录见 `Assets/reference-v0.2.29/`。0.2.28 的完整源码、应用和 profile 存档于 `cache/preserved-v0.2.28-before-reference-body/`。

- 新 profile 为 `reference-v0.2.29`，活动 sprite 25 个。两组同源部件分别保留 3 px 与 6 px 的原图 RGB 重叠以遮住内部接缝；静态组件重建与原图差异为 0 像素。朋友自有的裙装/衣物隐藏衬片共 34,772 像素，用于遮住原图裁切边缘。用户完整姿势是一手放在朋友头上、另一手放在膝上。
- 从 27 个候选中移除两张眨眼素材，由单一程序化 `SourceReferenceFaceRig` 负责眼部动作。原图中可见的大腿、丝袜及整体高跟鞋外观保留；高跟鞋与人物同属参考源图，不拆为独立鞋脚动画。旧衣物、补片和 toe rig 不渲染但文件保留。鞋内不可见脚不补画；仅此 source profile 不启用独立掉鞋（`ShoeDrops=false`）。
- 桌面现由 `DeskSurfaceRig` 显式根节点平移 `(-80,+75)` 以适配源图较短的手臂，并同步转换命中位置；桌面形状及键盘角度保持不变。0.2.28 的两倍爬行速度和 3.6 秒行程不变。
- `build/reference-v0.2.29/release-render-summary.json` 汇总 964 帧最终爬行检查：无翻折，`minDet=0.5926399126`，最大掌部误差 `0.03497586` 画布像素、肩部误差 `0.00453`、腰部误差 `2.54e-13`，大腿骑乘连接误差为 0；56 组朋友独立素材对照均匹配。30 项核心检查、82 键几何/触点检查通过。静态合成相对源图为 0 像素差异。素材源图、遮罩及最终 release crawl 证据位于 `build/reference-v0.2.29/`。
- 安装在 `Viola 新版.app`，版本 0.2.29 build 30。Strict/deep 签名验证通过；源码、应用与 profile manifests 一致，25 个活动 sprite 的哈希匹配。安装时 `config.json` 与 `keyboard-stats.json` 保持逐字节一致。安装证据见 `build/reference-v0.2.29/install-verification.json`。
- `build/reference-v0.2.29/native-acceptance.json` 记录原生 CUA 启动并看见新版人物；菜单隐藏桌面后显示源图坐姿（一手抚摸朋友头部，另一手放在膝上），随后恢复 `showDesks=true` 并收起菜单。自动爬行自然结束约 3.61577 秒，窗口坐标行程 −70 pt；手动爬行自然结束约 3.60353 秒，窗口坐标行程 +69 pt，`canvasTravel=149.6`、`cancellationReason=none`。关联诊断为 `native-hidden-diagnostics.json` 和 `native-manual-crawl-diagnostics.json`。
- 安装检查时配置精确保留。之后用户再次移动、调整大小并隐藏桌面；最新 profile 为 `showDesks=false`、宽度 548.49 pt、原点 `(820,59)`。不将安装时保留声明延伸为原生检查后字段未变。
- `inputPermission=false`、`globalKeyboardConnected=false`；82 键结果只验证几何/触点，不表示系统键盘权限或真实键盘输入已验收。Input Monitoring 仍关闭。
- 素材切割使用普通像素处理；图像工具去背景请求被输入审核拒绝，没有使用或重试生成结果。

---

# Historical review — 0.2.28 build 29

0.2.28 将爬行速度在 0.2.27 基础上提高一倍，约 3.6 秒完成原 149.6 canvas px 行程；手动爬行期间普通鼠标移动或打字不中断。

- Release 构建、30 项核心检查及 strict/deep 签名验证通过，并安装打开。配置文件和键位统计安装前后逐字节相同。证据位于 `build/crawl-speed-v0.2.28/`，包括 `build.log`、`core-checks.log`、`install.log` 与 `installed-verification.json`。
- 原生闲置爬行自然结束，用时 3.652 秒，`canvasTravel=149.6`，窗口 X 从 30 移至 60 pt，`cancellationReason=none`，并恢复 `showDesks=true`。Input Monitoring 仍关闭，未验收真实物理键盘输入。

---

# Historical review — 0.2.27 build 28

0.2.27 已安装，修复了手动爬行被普通鼠标移动或打字立即中断的问题。用户反馈速度需要提高，并表示其他表现没有问题；因此 0.2.28 单独调整动作速度。

- Release 构建、30 项核心检查、strict/deep 签名检查均通过。日志位于 `build/crawl-input-fix-v0.2.27/`，安装验证见 `installed-verification.json`。
- 本记录不声称 0.2.27 的原生爬行曾完成完整自然结束检查。Input Monitoring 未开启，未验收真实物理键盘输入。

---

# Historical review — 0.2.26 build 27

0.2.26 build 27 已安装并通过原生检查。在 0.2.25 基础上新增薇欧拉短距离爬行，支持菜单手动触发和闲置时偶尔自动触发。Input Monitoring 仍未开启；没有宣称已通过真实物理键盘敲字。

- 核心动画约 7.2 秒、四步态循环，正常模式最大位移 149.6 画布像素；手膝交替、身体重心起伏，薇欧拉轻微随动。菜单项为“爬行一小段”和“闲置时偶尔爬行”；`idleCrawlEnabled=true` 为默认值。空闲 22–30 秒后有机会自动启动，自动爬行冷却为 75–100 秒。通过系统 idle age 识别空闲，不读取输入内容，无需 Input Monitoring。
- 爬行时临时隐藏桌面，结束后恢复用户设置；拖动、菜单操作、键鼠输入或缩放会中断，爬行范围限制在当前屏幕。减少动态效果时禁用自动爬行；手动动作幅度约为 12%，且不产生平移。
- Release 构建和安装通过：`build/crawl-v0.2.26/build-final.log`、`install.log`。严格/深度签名检查、源码/应用/profile manifest 三方哈希一致（`1a2d59ce790e1bdf04738876fc51256023ff1f733cda0856f329f7e30da3a10a`）、62 张 PNG 一致、Mach-O 二进制段一致；安装时配置与统计精确保留。`source-asset-verification.json` 记录 90 个 source 文件与缓存一致，原 62 张 PNG 和 0.2.25 layout 未改变。签名与安装详情见 `installed-verification.json`。
- 29 项核心检查通过：`build/crawl-v0.2.26/core-checks.log`。最终 `final-review/crawl-review.json` 四种模式各覆盖 241 帧；`render-verification-final.json` 检查正向、反向、减少动态及取消状态，无翻折，最小检测值 `0.627272`，掌部最大误差 `0.0389685` 画布像素，肩部/上裙误差低于 `3e-13`，骑乘大腿关节误差为 0。56 对选定的朋友独立图像均一致，朋友没有借用薇欧拉腿部动作。
- `inactive-parity-final.json` 记录 25 张桌面显示图及 25 张桌面隐藏图与 0.2.25 全图像素一致。82 键触点最大误差 `1.458e-10`，鼠标漂移 0。
- `native-verification.json` 记录原生自动爬行自然结束（7.216 秒，窗口 X 坐标 959→886 pt）及一次手动爬行自然结束（7.216 秒，886→959 pt）；两次结束均恢复 `showDesks=true`。另一次手动动作在真实输入到达后 0.415 秒中断并恢复桌面。后续现场诊断确认普通鼠标移动会在约 0.2897 秒时取消手动爬行，用户反馈因此难以看清；此中断规则列为 0.2.27 修正目标。截图曾确认自然结束时的爬行动画及桌面恢复。诊断为 `idleCrawlEnabled=true`，`inputPermission=false`、`globalKeyboardConnected=false`。检查期间用户调整窗口大小，保留最新 profile 状态，不声明固定最终窗口尺寸。
- 视频预览：`build/crawl-v0.2.26/crawl-preview-final.mp4`，1000×960、121 帧、15 fps、8.067 秒。0.2.25 的完整源码、应用与 profile 存档于 `cache/preserved-v0.2.25-before-crawl`；0.2.22 保留版也继续保留。

---

# Historical review — 0.2.25 build 26

在用户要求撤销电脑桌改版并恢复 0.2.22 存档后，本次只将左侧桌板与键盘放平，右侧鼠标桌和鼠标保持原样。0.2.22 保留版仍在。

- 左侧桌板 `DeskSurfaceRig` 四点：`(188,557)、(447,547)、(406,425)、(170,458)`。完整右桌和共用连接边不变。
- 键盘旋转由 −18° 调整至 −8°，矩形 `[179.17417317526753,449.11255332671703,235,80]`，右下角世界坐标保持。其余 sprite 与 PNG 均未更改。
- Release build 已安装。`build/flatter-desk-v0.2.25/installed-verification.json` 记录 strict/deep 签名检查通过；源码、应用包和 profile manifest 三方哈希均为 `1a2d59ce790e1bdf04738876fc51256023ff1f733cda0856f329f7e30da3a10a`；62 张 PNG 一致，二进制代码与数据段一致。安装过程保留了原配置与统计。
- 82 键触点最大误差为 `1.4582220516171308e-10`，鼠标漂移为 0。`build/flatter-desk-v0.2.25/render-parity.json` 显示：17 个共同完整场景中，鼠标区域 `(470,360,645,530)` 像素一致；25 张隐藏桌面图像与 0.2.22 全图像素一致。
- 原生菜单已将桌面设为显示。截图确认放平后的左桌与键盘可见；`native-verification.json` 记录版本 0.2.25、`restingPoseVisible=false`、`inputPermission=false`、`globalKeyboardConnected=false`。原生检查前配置被安装保留；检查期间用户自行调整窗口宽度和位置，因此不记录固定的最终尺寸或位置。只执行了显示桌面的菜单操作。
- 普通核心检查套件未重跑，因为本次只改几何。输入监控未启用，未做物理键盘验收。

---

# Historical review — 0.2.22 build 23

The animation seam repair is installed and engineering verification is complete. The friend's skirt is part of its continuous seating support, so Viola's leg swing no longer drives that garment. Breathing and leg movement retain source-pixel backing at internal joins; the existing leg lining extends behind the calf motion range.

- `ownership/audit.json` records 8,615 front-leg pixels removed and 10,026 originally transparent seating pixels filled from exact source pixels. Existing visible seating pixels and retained front-leg colors were unchanged; front-leg rows y=395 and below are byte-identical. All 62 original PNG files remain unchanged.
- Final normal review covered 18 poses. The 720-frame-per-mode friend isolation and breathing results were generated before the toe-hook-only backing correction: visible and hidden each had 0 friend-geometry mismatches and 0 mismatches across four selected isolated PNGs; friend breathing changed geometry in all 720 frames in both modes. Body attachment maximum Y delta was about `9.95e-14`. The later toe-hook correction does not alter normal rendering.
- After synchronizing join and skin backing to the actual thigh transform during toe-hook recovery, a separate final export covered 20 recovery poses and 30 corner measurements; maximum corner error was 0. Two forward-motion images were reviewed, and the earlier recovery ghost was no longer visible. Core checks passed: 23. Evidence is under `build/motion-seams-v0.2.22/`, including `verification-summary.json` and `toe-hook-final/`.
- Build 23 installed with strict/deep signature verification. Source, bundle and profile manifest hashes match at `c292396db1d3a7fb994a24d71f1dcd02cc07be77fbf3b099944a1dfd334a3239`; packaged PNGs match, and Mach-O code/data sections match. Install left configuration unchanged. Evidence: `install.log` and `installed-verification.json`.
- The installed executable launched as a native window; screenshot review confirmed the desk-hidden pose without the old slits. Native diagnostics report version 0.2.22, `showDesks=false`, and the pose visible. The user moved the window after launch, so no exact final window origin is claimed. Native evidence: `native-diagnostics.json` and `native-config.json`.
- Physical keyboard input and whole-character aesthetic approval are not claimed. Pre-existing appearance details outside this seam task are not represented as fully resolved.

Engineering checks for the 0.2.22 seam repair are complete. Optional user aesthetic feedback may still be provided.

---

# Historical review — 0.2.21 build 22

Build 22 is installed and desk-hidden resting-pose engineering review is complete. In this pose, Viola gently pets the purple-haired friend's crown with one hand and rests the other on her lap.

- The two successful built-in image-generation assets are `Assets/RestingPose-v0.2.21/pose-reference.png` and `Assets/RestingPose-v0.2.21/arms-cutout.png`. Their prompt records are in `docs/RESTING_POSE_PROMPTS_V0.2.21.json`.
- In the hidden composition, `ReferenceBodyJoin` clears only the old left-hand area `world[203,518,112,48]`, removing 887 occupied pixels. The default body join remains byte-identical and all 230435 pixels outside this rectangle are unchanged. The former right-side broad cleanup was reverted. A coherent belt/apron patch from the generated pose art has a 3 px left registration; three tight backing patches cover the remaining hair/body gaps only in the hidden composition.
- `RestingPoseRig` separates the petting and lap hands. The petting palm follows the friend's crown and its shoulder follows Viola's torso; the lap hand follows her body. A 301-frame, five-second motion check measured X travel ±1.2 px and Y travel ±0.179960523 px; reduced motion yields `[0,0]`. Endpoints were checked. The final hair-mask edit did not change the hand rig; the texture animation was not separately rerun after that edit. Motion evidence: `build/resting-pose-v0.2.21/motion-review/resting-motion.json` and `build/resting-pose-v0.2.21/final-motion/`.
- Existing `ViolaChecks` passed all 23 core behavior checks using `swift run --package-path . ViolaChecks`; output: `build/resting-pose-v0.2.21/core-checks.log`.
- Build 22 installation passed strict/deep signature verification. Source, bundle and profile manifest hashes match at `c292396db1d3a7fb994a24d71f1dcd02cc07be77fbf3b099944a1dfd334a3239`; both new PNG assets match their packaged copies and the install left configuration unchanged. Evidence: `build/resting-pose-v0.2.21/install.log` and `installed-verification.json`.
- Final renderer previews for visible, hidden, restored, hidden-again and hidden-laugh states are in `build/resting-pose-v0.2.21/delivery-preview/`. The visible preview SHA-256 `d721498a862d7cc4bc4f6b8eae53fd59b94fafd715c1e73080c8d957d9c8a40e` matches the 0.2.20 visible preview. All 60 original PNG assets are byte-identical to the 0.2.20 copies; see `verification-summary.json`.
- Native UI began with desks visible and the original typing pose. The menu was then used to hide the desk, and a fresh screenshot showed the resting pose. Two native samples recorded petting stroke `[1.0651266543, 0.1471806011]` then `[-0.3906744582, -0.1108172336]`; hidden-pose diagnostics report `showDesks=false` and `restingPoseVisible=true`. Input permission and global keyboard connection remain false; no physical-key acceptance is claimed. Native evidence: `native-resting-a.json`, `native-resting-b.json`, and `verification-summary.json`.
- The current user preview config is `showDesks=false`, width 537.158 pt, origin `(839, 195)`. The native review made no config changes; before/after comparison is recorded in `config-before-native.json` and `config-after-native.json`.

Engineering verification is complete. User aesthetic feedback may still be provided; it is not an outstanding engineering check.

---

# Historical review — 0.2.20 build 21

The 0.2.20 build 21 desk and arm repair is installed and engineering verification is complete. A continuous `DeskSurfaceRig` replaces independently rotated desk halves while retaining the existing desk texture. The keyboard and left palm/fingers moved together by (-15, -60); the mouse hand, reference pose and laugh pose moved together by (+30, -50). Shoulder positions are unchanged. A generated static right cuff is masked only while the desk is visible, and the desk root sits below interactive sleeves to prevent occlusion. Final rear edges are at hinge y=547 and right-rear y=541. The current profile intentionally has `showDesks=true`; configured width is 751.666 pt and the native window rounds to 752 pt at origin (541, 0).

- Existing `ViolaChecks` suite passed all 23 core behavior checks when run against the current checkout using `swift run --package-path . ViolaChecks` (separate from the release staging package build).
- The 82 key contact geometry check ran after the first cuff mask but before the final rear-edge, mask-boundary and layer-order refinements: maximum fingertip error 1.45516421109398e-10 canvas px and right-hand drift 0. It was not rerun after those final changes; the changes did not alter key or hand geometry. Results: `build/desk-repair-v0.2.20/final-review/key-contact-geometry.json`.
- The hidden composition is identical to 0.2.19: SHA-256 `17b155af3375ca4dfcb1405e4635cb7ad7c84c31cd6f56761be6cfd723ef6174` (`build/desk-repair-v0.2.20/verified-visibility/hidden.png`). Sixteen poses, including idle, typing, mouse movement and right-mouse extremes, are in `build/desk-repair-v0.2.20/verified-poses/`.
- Build 21 is installed. The strict/deep signature check passed in `build/desk-repair-v0.2.20/install.log`. Source, bundle and profile manifests match at SHA-256 `dd40372da0f4b6dd38e58364c743576b0c78ab30b019fadafc703ac5add61e7e`; details: `build/desk-repair-v0.2.20/installed-verification.json`.
- Final summary records 23 core checks, 16 preview states and native UI observations; its 82-key result is the pre-final-refinement check described above: `build/desk-repair-v0.2.20/verification-summary.json`. A separate comparison confirms all 60 original PNGs are unchanged from the 0.2.19 backup: `build/desk-repair-v0.2.20/retained-assets.json`.
- Native UI operation verified show desk → hide desk → show desk. A 10-second demo screenshot showed the yellow Space key and hand/mouse movement. `native-demo.json` was captured after the demo ended, when diagnostics had returned to idle; it does not report `demoActive=true`. Input permission and global keyboard connection remain false, and no physical-key acceptance is claimed.
- The 0.2.19 app/profile backup is retained at `build/preserved-v0.2.19-before-desk-repair/`.
- Current preview: `build/desk-repair-v0.2.20/verified-poses/desk-preview.png`. User aesthetic approval is optional and remains unrecorded. Pre-existing shoulder and skirt seam concerns are outside this desk repair; no claim is made that the full character design is resolved.

Engineering checks for the desk repair are complete. Physical keyboard input and optional user aesthetic approval remain unverified.

---

# Historical review — 0.2.19 build 20

Production compilation, installation, and native relaunch passed for 0.2.19 build 20. Native configuration checks verified hiding and restoring the desks, persistence of `showDesks=false`, and preservation of every configuration field. The waist/skirt preview is at `build/waist-join-v0.2.19/verified-preview`. User visual acceptance remains pending. Source PNG assets remain unchanged. The patch hem boundary was then constrained, rerendered, and reinstalled. The final native window reopened successfully; its waist detail was checked in the production-renderer no-desk preview.

- Local waist/skirt join changes: removed the horizontal-band crop; added the lower-left dark fabric seam and narrow purple-hair strip; aligned the cuff locally to the original hand; faded covered table-cut edges of the original upper body and lower skirt under the patch; removed the duplicated upper-body fragment in `viola_skirt` above `worldY>505`. Original exposed thighs and skirt hem remain.
- Source, installed bundle, and profile parity passed for 57 sprites and 29 PNGs: `build/evidence/asset-parity-before.json` and `build/waist-join-v0.2.19/installed-verification.json`.
- Installed-app relaunch with desks hidden and `showDesks=false` persistence passed: `build/waist-join-v0.2.19/native-hidden-diagnostics.json`. Native menu restored `showDesks=true` to its pre-check value; all configuration fields match `build/waist-join-v0.2.19/config-before-native-check.json` (`config-after-native-check.json`).
- The 23 core checks in `build/body-completion-v0.2.18/core-checks.log` belong to 0.2.18; they were not rerun for this renderer-only repair. 0.2.19 production compilation, install, native configuration review, and preview review are complete for the installed state described above. Install log: `build/waist-join-v0.2.19/install.log` (strict code-signature verification passed).
- 0.2.18 app/profile backup: `build/preserved-v0.2.18-before-waist-join/`.
- Final visual acceptance is pending. The old purple-skirt partition line and desk/arm layout were not part of this repair and remain unresolved.

Overall visual acceptance for the 0.2.19 character/layout remains pending; current work continues in the 0.2.20 review section above.

---

# Historical review — 0.2.17 build 18

User visual review rejected the fitted arms and desks. Overall visual acceptance remains incomplete. The current native preview hides only `desk_keyboard` and `desk_mouse` through the external profile layout, leaving 48 sprites; keyboard, mouse, and current character pose remain visible for the user's next arrangement. The full 50-sprite layout is preserved under `build/character-only-review-v0.2.17/character-before-hiding-tables.json`. The installed executable and ZIP are intermediate build 18 artifacts, not an accepted final layout.

- Final build and strict/deep signature verification passed. Archive integrity passed for `build/releases/Viola-macOS-arm64-v0.2.17-parallel.zip`.
- 22 core checks passed; 16 gallery states and 82 key contacts passed, with maximum fingertip error 1.4552915504933292e-10 pt and no mouse-grip displacement during keyboard contact checks.
- Toe motion artwork recorded 723 frames across free, fitted, and reduced modes. All ten digits varied; maximum displacement was 0.844733 canvas px free and 0.126710 fitted. Fixed-calf shoe anchors stayed still. Native reduced motion disables both feet's micro-motion, and the corrected native toe clock tracked 19.983463 seconds over 19.996666 seconds of wall time.
- Native 75% size produced 330×396 pt and survived quit/relaunch. Wheel resizing reached configured width 403.062910 pt, with a rounded 404×484 pt native window. The current user preview is 440 pt wide.
- Native demo showed Typing and `demoActive=true`; native laughter and the repaired closed-eye expression were visibly observed. These do not establish physical keyboard acceptance. Current input permission and global keyboard connection are false.
- Arm diagnosis: old sleeve layers overlay the new body's existing sleeves, and the translated left shoulder was moved 12.056 pt right and 31.02 pt down relative to the old consistent registration. Its shoulder/wrist gap shrank from 96.98 to 65.96 pt with unchanged sleeve width. No further arm or desk arrangement has been applied after the user's request to inspect the character without desks.

Evidence: `build/evidence/core-checks-v0.2.17.txt`, `key-contact-summary-v0.2.17.json`, `toe-motion-summary-v0.2.17.json`, `native-reduced-v0.2.17.json`, `native-toe-clock-v0.2.17.json`, `native-restart-size75-v0.2.17.json`, `native-demo-v0.2.17.json`, and `native-without-tables-review-v0.2.17.json`.

---

# Historical revision — 0.2.11 build 13

- Added a small drool trail and droplet to the heart-eye mouth patch. Original eye sprites and face silhouette retained. The patch shares the existing hearts expression opacity and friend breathing offset.
- Release preview build completed; 16 art states exported with `--art-only`. Inspected enlarged heart-eye, neutral and effort previews: drool appears in hearts only. No behavioral tests or physical-key sequence run. Preview directory: `build/previews-v0.2.11-drool/`.
- Optional external artwork loading added alongside the existing profile layout. Current mouth image installed in both source/bundle resources and the external profile's `character-assets/` directory.
- Installed only `~/Applications/Viola 新版.app` as 0.2.11 build 13, and reopened the native desktop window. Fresh diagnostics report visible true, demo false and the active external layout. Evidence: `build/evidence/build-installed-v0.2.11.txt`, `build/evidence/native-drool-v0.2.11.json`. The new expression was inspected in production-renderer artwork; a full random native expression cycle was not separately exercised.
- Created `build/releases/Viola-macOS-arm64-v0.2.11-parallel.zip`. The build script verified the signature; current code hash `4d0aab0fab429a271dbf5b7d3de04a4782f8b865`. Original app remains `25549d56ec49a54af964a95890eae66400f49992`, with earlier packages retained.
- Input permission and global keyboard connection are currently false, still awaiting the earlier manual permission refresh. Expression scheduling does not require the keyboard tap.

---

# Historical revision — 0.2.10 build 12

- Built-in image tool redrew the typing hand with shorter projected fingertip reach and relaxed curved joints. Exactly five independent finger masks use the new source. Source PNG and exact prompt retained locally.
- Removed finger elongation on key press. The four long fingers now foreshorten by at most 6.5%, thumb 3.5%; the key aiming calculation uses the same transformed fingertip.
- Replaced the typing sleeve's two straight shear transforms with a continuous curve from shoulder to wrist. Shared triangular patches preserve the fabric silhouette across bends; partial cross-section rotation avoids folds at the shoulder. The wrist and cuff remain forward-facing.
- Release preview compilation completed; inspected production-renderer artwork at rest and representative ASDF, Space, Enter and Esc positions. Export includes 11 keys at 0%, 50% and 100% pressure. No behavior tests or physical-key sequence were run this revision.
- Prior eye-spacing correction is retained in the source manifest and active profile. Release build installed through `scripts/build_app.sh --parallel`, signature verified by the script; native window reopened and visibly shows the new hand. Diagnostics: 0.2.10, visible true, demo false, active external profile loaded. Evidence: `build/evidence/build-installed-v0.2.10.txt` and `build/evidence/native-typing-hand-v0.2.10.json`.
- Rebuilt app currently reports inputPermission false and globalKeyboardConnected false; real keyboard acceptance remains pending a user refresh of Input Monitoring for this executable. No TCC setting was changed by automation.
- Saved `build/releases/Viola-macOS-arm64-v0.2.10-parallel.zip`. New signature `c3ff6cbebf5def0355ecdefc3bd1a5dcbae2d2f7`; original app remains `25549d56ec49a54af964a95890eae66400f49992`. Earlier packages retained.

---

# Historical revision — 0.2.9 build 11

## Expression registration layout update

- Repositioned the two existing amused eye sprites to the neutral face's horizontal pupil anchors. Adjusted the right eye vertically to give both eyes the same subtle downward gaze, and trimmed the outer skin margin away from side hair. Eye sprite pixel scale, head shape and all source raster images are unchanged.
- Fixed-region artwork at 4× scale shows approximate pupil spacing: neutral 216.453 px, previous amused 192.614 px, corrected amused 216.816 px. These are dark-pupil centroid measurements for alignment, not exact anatomical landmarks. Reviewed neutral, transition, amused and blink crops under `build/previews-v0.2.9-eye-alignment/`.
- Corrected source manifest and the active external profile layout. Only the preview CLI was compiled for artwork export; the installed executable and its signature remain unchanged. Existing 0.2.9 ZIP retains its earlier embedded manifest; corrected portable layout: `build/releases/Viola-v0.2.9-eye-alignment.json`.
- No behavioral tests were added or run. Evidence: `build/evidence/eye-registration-v0.2.9.json`; exact layout changes: `docs/EXPRESSION_ALIGNMENT_V0.2.9.json`.
- Relaunched the installed app and observed the native window; fresh diagnostics identify the corrected external profile path. Snapshot: `build/evidence/native-eye-alignment-v0.2.9.json`. The expression itself was reviewed in production-renderer crops; no full live assistance cycle was exercised in this revision. This relaunch now reports `inputPermission=true` and `globalKeyboardConnected=true`, resolving the earlier permission/connection issue. A controlled physical-key sequence was not performed during this visual revision.

## Mouse response release

Both mouse response axes are inverted in the animation engine. User right/left/up/down motion maps to on-screen left/right/down/up grip motion. Desk limits, smoothing, click pressure and all 0.2.8 artwork remain unchanged.

- Existing direction assertions were updated for the reversed signs. No tests were added or executed for this revision.
- Release compilation and installation completed through `scripts/build_app.sh --parallel`; the script verified the application signature. Build output: `build/evidence/build-installed-v0.2.9.txt`.
- Launched `~/Applications/Viola 新版.app` and observed the native character window. Diagnostics report 0.2.9, visible true, demo false, and nonzero mouse movement/click counters. Position and size remain x1030/y394/440×528. Snapshot: `build/evidence/native-mouse-v0.2.9.json`.
- Created `build/releases/Viola-macOS-arm64-v0.2.9-parallel.zip`. The original app remains installed with its prior signature `25549d56ec49a54af964a95890eae66400f49992`; prior release archives are retained.
- Keyboard input permission and global keyboard connection remain false; the fallback mouse listener is receiving events.
- Physical four-direction acceptance has not been performed.
- Follow-up input permission diagnosis: System Settings visibly shows `Viola 新版` enabled, but a clean relaunch still reports both permission and global keyboard connection false. `tccd` logs identify a code-requirement mismatch: saved hash `fa2efef8afcbec2c7689b5b1b36463d57584f781`, installed hash `17e4c36b0cc0a806c380d1256c05c4a303caa30a`. The user was asked to re-add only the preview app in Input Monitoring. Evidence: `build/evidence/native-input-restart-v0.2.9.json` and `build/evidence/input-identity-mismatch-v0.2.9.txt`. No permission changes were made by automation.

---

# Historical revision — 0.2.8 build 10

Slender legs with the final 6% width refinement (length unchanged); two independent half-worn heels; idle slipping, falling and floor bounce; automatic recovery plus early click; toe-hook and friend-assisted recovery; Viola's downcast amused expression during assistance.

- Release source compiled successfully; no behavior or key-contact tests run.
- Production-rendered idle, falling, grounded, toe-hook and friend-assistance key poses inspected. Original hand hiding and shoulder coverage were adjusted; eye patches preserve hair and face boundaries.
- Five generated source assets and exact built-in image-tool prompts retained locally.
- Final 0.2.8 build 10 installed in `~/Applications/Viola 新版.app` and the native window visibly observed with the final 6% width refinement. Active profile layout and independent shoe diagnostics are recorded in `build/evidence/native-shoes-v0.2.8-final.json`.
- Final app signature is `713d611de37e9a924e4c07b8847437f82e77306f`; preserved 0.2.4 signature remains `25549d56ec49a54af964a95890eae66400f49992`.
- Final production art export contains 16 standard poses, stage snapshots and 570 frames at 15 fps (38 seconds). Timeline includes a friend-assisted recovery at 21.33–24.73 seconds and toe-hook recovery at 33.07–34.73 seconds. `shoe-interaction.mp4` preserves the entire sequence; `friend-assists.gif` is the 20–28 second excerpt, both 500 × 600.
- Archive `build/releases/Viola-macOS-arm64-v0.2.8-parallel.zip` passed archive integrity checking. The install script verified the signature. Old application and earlier versioned ZIPs remain intact.
- Current native snapshot: version 0.2.8, visible true, demo false, inputPermission false, globalKeyboardConnected false. A prior native 0.2.8 snapshot captured a grounded independent shoe; this was before the final width/mask adjustment. No physical-key acceptance is claimed.
- Native early-click behavior and full interaction regression have not been exercised. Global keyboard authorization remains separate from this visual interaction work.

---

# Historical revision — 0.2.7 build 9

Fuller anime legs and combined fore/aft plus lateral idle movement. Upper sections stay attached while each calf/foot projects around its knee. The central front-facing mouse desk, inward side keyboard and purple-haired friend remain in the composition.

- Creative asset: built-in image tool; local source and exact prompt retained.
- Release compilation completed. Production rendering exported 16 art states and 180 idle frames, with no behavioral/key-contact checks executed this revision.
- Static combined/opposite poses and texture seams were visually inspected. Current files: `build/previews-v0.2.7/`.
- Installed only `~/Applications/Viola 新版.app`, 0.2.7 build 9; relaunched and observed two native window snapshots with different leg positions. Diagnostics show nonzero fore/aft and side angles, visible Idle state, demo false, and the external profile layout.
- Final signature: `279d486c882e771551c36d54519b7d8ec3065dc0`. Old 0.2.4 signature remains `25549d56ec49a54af964a95890eae66400f49992`.
- Current native keyboard permission/connection are false. No physical keyboard acceptance or full interaction regression was performed.
- The 9-second idle GIF is 500 × 600, 180 frames. Exported foot positions span about 23/32 logical points horizontally and 45 points vertically; these are projected screen coordinates, not measured physical depth.
- `build/releases/Viola-macOS-arm64-v0.2.7-parallel.zip` passed archive integrity checking; installation script also verified the app signature.
- Evidence: `build-installed-v0.2.7.txt`, `art-preview-v0.2.7.txt`, `idle-foot-range-v0.2.7.json`, `native-legs-v0.2.7.json`, `native-legs-v0.2.7-final.json` under `build/evidence/`.
- Prior 18-check and 82-key results belong to 0.2.6, not this version. Current real keyboard acceptance remains dependent on native permission and physical key input.

---

# Acceptance evidence — 2026-09-30 / 0.2.6 desk revisions

## Current deliverable

Two plum desk panels turn inward toward Viola, joining in front of her as a shallow U. The left keyboard follows its desk to -18 degrees; the right grip remains on its own mouse desk. The lower seating/legs/facial-feature group moves together to close the previously concealed waist gap, retaining the friend and legs on either side of her head.

- Old installed `Viola.app` remains 0.2.4 with designated requirement `25549d56ec49a54af964a95890eae66400f49992`.
- New app is `Viola 新版`, bundle `local.viola.desktop.preview`, version 0.2.6 build 8, separate `ViolaDesktop-Preview` profile.
- Profile `character-layout.json` is loaded at startup. Images resolve to bundled assets, and invalid layouts fall back to the bundled manifest. The final inward layout is also the bundled default.
- Static sprite rotations now apply during layer construction. Both sleeve segments share lateral travel: 58% at the elbow, remainder in the forearm, preserving shoulder/cuff cross-sections.

## Validation

| Area | Evidence |
|---|---|
| Core | 18 behavior checks passed, including typing/clicks, configuration, per-key statistics, idle legs and temporary friend expressions |
| Key geometry | All 82 production-rendered keys use left fingers; maximum stable fingertip error 1.55e-10 logical point |
| Right hand | Mouse grip/sleeves remain visible for all keyboard cases; keyboard-only input changes mouse position by 0 |
| Reduced reach | Left wrist horizontal span 373.31 → 255.87 points (31.46% reduction); maximum lateral shoulder distance 208.61 → 149.32 (28.42% reduction) |
| Art inspection | Inward idle, edge-key, mouse extremes and expression renders inspected; five-digit art retained, face unobscured |
| Prior real input | 0.2.5 genuine global keyboard counters increased with permission/tap true and demo false; preserved pre-update diagnostics |
| Native 0.2.6 | The initial outward candidate was observed running, with the profile layout loaded and mouse events arriving; keyboard grant was false after the executable signature changed |

Current-version native launch/permission follow-up is recorded below after final installation. Earlier 0.2.5 or outward 0.2.6 input/render results are not a substitute for final-version acceptance.

## Permissions and preserved state

System Input Monitoring initially still displayed the new-app toggle on while native diagnostics reported false, following the changed ad-hoc executable identity. The page was opened and the user was asked to re-add only `~/Applications/Viola 新版.app`, enable it and follow the OS restart prompt. Old Viola's grant was not touched. The user's next response corrected the desk direction, which was implemented before final native follow-up.

## Known rendering boundaries

The two desks and sleeves are 2D sprite transforms. Edge-key poses still stretch sleeve folds, and the lower source retains some rough alpha pixels. Same-hand chords aim toward the latest key while retaining independent pressure states. Keypad/ISO/JIS extras are counted without visible targets. Separate hair and speaking-mouth rigs remain future work. Isolated app screenshots do not establish full desktop click-through/drag acceptance.

## Evidence

- `build/evidence/core-checks-v0.2.6.txt`
- `build/evidence/keyboard-reach-inward-v0.2.6.json`
- `build/evidence/gallery-inward-v0.2.6.txt`
- `build/evidence/physical-input-connected-v0.2.5-before-update.json`
- `build/previews-v0.2.6-inward/`
- `build/releases/Viola-macOS-arm64-v0.2.6-inward-parallel.zip`

The initial outward candidate's source layout, previews and ZIP remain for historical comparison. Final acceptance uses files explicitly named `inward`.

## Final native follow-up

The final inward 0.2.6 build 8 was launched and its actual native window inspected. Both boards face inward, keyboard/mouse sit on their respective surfaces, and the friend remains visible. Diagnostics confirm the profile-level layout is active. The final executable identity is `b16c2b1e5c11e31c25f014c99009f65fac544695`.

Saved diagnostics: permission=False, globalKeyboardConnected=False, demoActive=False; real events {'KEY_DOWN': 0, 'KEY_UP': 0, 'LEFT_CLICK': 14, 'MOUSE_MOVE': 1542, 'RIGHT_CLICK': 0}. Native mouse response is receiving events. Final global keyboard acceptance remains pending manual system reauthorization. See `build/evidence/native-inward-v0.2.6.json`.

Final inward ZIP passed archive integrity checking. Interaction/idle GIFs contain 120/180 frames respectively at 500 × 600. The 540 intermediate PNGs were removed after encoding because the disk was nearly full; source, stills, geometry records, GIFs and all versioned packages remain.

## Current revision: central mouse desk, side keyboard desk

The user corrected the double-inward candidate: retain a forward-facing mouse desk at the center, and fold only the keyboard desk inward on Viola's right (viewer-left). This has superseded the preceding candidate.

- Mouse panel rotation is 0 degrees, enlarged in depth, with grip rect `[401,379,106,247]`.
- Keyboard side panel retains its inward turn; keyboard is 235 × 80 and shifts left, leaving separate hand work areas.
- All 82 key contacts pass with maximum error 1.46e-10; keyboard input leaves the mouse grip unchanged. Wrist horizontal span is 243.15 points, 34.87% below 0.2.5.
- Idle, edge-key and mouse extreme renders inspected. Production native window was relaunched and visually observed with the central mouse desk horizontal and the side keyboard folded inward.
- Only the external layout changed for this correction; executable identity remains `b16c2b1e5c11e31c25f014c99009f65fac544695`. No additional rebuild/signature change.
- Current evidence: `key-analysis-center-mouse-v0.2.6.json`, `native-center-mouse-v0.2.6.json`, `gallery-center-mouse-v0.2.6.txt`, and `build/previews-v0.2.6-center-mouse/`.

Latest native snapshot: inputPermission=False, globalKeyboardConnected=False, demoActive=False. Real events: {'KEY_DOWN': 0, 'KEY_UP': 0, 'LEFT_CLICK': 0, 'MOUSE_MOVE': 0, 'RIGHT_CLICK': 0}. The unresolved global keyboard authorization remains separate from the verified layout/mouse rendering.
