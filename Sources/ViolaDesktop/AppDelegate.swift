import AppKit
import CoreGraphics
import QuartzCore
import ViolaCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let appDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(
        Bundle.main.object(forInfoDictionaryKey:"ViolaProfileDirectory") as? String ?? "ViolaDesktop")
    private lazy var store = ConfigurationStore(url: appDirectory.appendingPathComponent("config.json"))
    private var config = PetConfiguration()
    private lazy var laughAudio = LaughAudio(profileDirectory: appDirectory)
    private var panel: PetPanel!
    private var petView: PetView!
    private var renderer: LayerRenderer!
    private var activeLayoutPath = ""
    private var engine = AnimationEngine(now: InputListener.now)
    private let input = InputListener()
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var sizeMenu: NSMenu!
    private var soundSourceMenu: NSMenu!
    private var frameTimer: Timer?
    private var housekeeping: Timer?
    private var screenParametersObserver: NSObjectProtocol?
    private var settings: NSWindow?
    private var permissionLabel: NSTextField?
    private var stateLabel: NSTextField?
    private var interactionButton: NSButton?
    private var topButton: NSButton?
    private var passButton: NSButton?
    private var reducedButton: NSButton?
    private var desksButton: NSButton?
    private var sizeSlider: NSSlider?
    private var sleepSlider: NSSlider?
    private var automaticSleepButton: NSButton?
    private var sizeValue: NSTextField?
    private var sleepValue: NSTextField?
    private var soundButton: NSButton?
    private var soundSourcePopup: NSPopUpButton?
    private var volumeSlider: NSSlider?
    private var volumeValue: NSTextField?
    private var lastDraw = 0.0
    private let framePacing = FramePacingDiagnostics()
    private var frameCadence = FrameCadence()
    private var currentState: MotionState = .idle
    private var currentFrame = AnimationFrame()
    private var demoUntil = 0.0
    private var demoNextKey = 0.0
    private var demoNextClick = 0.0
    private var wasPermissionGranted = false
    private var nextInputRetry = 0.0
    private var saveFailure: String?
    private var startTime = InputListener.now
    private var keyStatistics = KeyStatistics()
    private var statisticsWindow: NSWindow?
    private var statisticsText: NSTextView?
    private var statisticsDirty = false
    private var openMenus = 0
    private var nextAutoCrawl = InputListener.now + Double.random(in: 22...30)
    private var autoCrawlIdleDelay = Double.random(in: 22...30)
    private var nextIdleProbe = 0.0
    private var nativeIdleAge = 0.0
    private var crawlStartedAt = 0.0
    private var crawlTrigger = "none"
    private var crawlCancellationReason = "none"
    private var crawlScreenBounds: CGRect?
    private var crawlMinimumX = 0.0
    private var crawlMaximumX = 0.0
    private var crawlPresentationActive = false
    private var nextCrawlDirection = -1.0
    private var crawlWindowDistance = 0.0
    private var crawlRequestedX = 0.0
    private var crawlOriginX = 0.0
    private var crawlOriginY = 0.0
    private var crawlPetSize: CGSize?
    private var crawlHostExpanded = false
    private var crawlRestingPanel: PetPanel?
    private var crawlWindowPath: [[String: Double]] = []
    private var nextCrawlPathSample = 0.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        // The parallel app starts from the user's current setup, then owns its own files.
        if appDirectory.lastPathComponent != "ViolaDesktop" && !FileManager.default.fileExists(atPath:appDirectory.path) {
            let previous = appDirectory.deletingLastPathComponent().appendingPathComponent("ViolaDesktop")
            try? FileManager.default.createDirectory(at:appDirectory,withIntermediateDirectories:true)
            for file in ["config.json","keyboard-stats.json"] {
                try? FileManager.default.copyItem(at:previous.appendingPathComponent(file),to:appDirectory.appendingPathComponent(file))
            }
        }
        config = store.load(); applySleepPreference()
        laughAudio.applySettings(enabled: config.laughSoundEnabled, volume: config.laughSoundVolume, variant: config.laughSoundVariant)
        if let data = try? Data(contentsOf: appDirectory.appendingPathComponent("keyboard-stats.json")), let saved = try? JSONDecoder().decode(KeyStatistics.self, from: data) { keyStatistics = saved }
        do {
            let directory = CharacterAssets.bundledDirectory
            let override = appDirectory.appendingPathComponent("character-layout.json")
            let assets: CharacterAssets
            if let custom = try? CharacterAssets(directory:directory,manifestURL:override) { assets = custom }
            else { assets = try CharacterAssets(directory:directory) }
            engine.allowsShoeDrops = assets.manifest.rigProfile != "reference-v0.2.29"
            activeLayoutPath = assets.layoutURL.path
            renderer = LayerRenderer(assets:assets)
            renderer.setDesksVisible(config.showDesks)
        }
        catch {
            let alert = NSAlert(); alert.messageText = "无法加载薇欧拉"; alert.informativeText = error.localizedDescription; alert.runModal()
            NSApplication.shared.terminate(nil); return
        }
        panel = PetPanel(contentRect: CGRect(x: 0, y: 0, width: config.width, height: config.width * renderer.canvasSize.height / renderer.canvasSize.width), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = config.stayOnTop ? .floating : .normal
        panel.ignoresMouseEvents = config.clickThrough
        panel.delegate = self
        petView = PetView(renderer: renderer); panel.contentView = petView
        petView.onMenu = { [weak self] event in
            guard let self else { return }; NSMenu.popUpContextMenu(self.menu, with: event, for: self.petView)
        }
        petView.onInteraction = { [weak self] in
            guard let self else { return }
            self.cancelCrawl(immediate: true, reason: "input")
            self.frame()
        }
        petView.onMoved = { [weak self] in self?.rememberPosition() }
        petView.onShoePickup = { [weak self] side in
            guard let self else { return }
            if self.engine.recoverShoe(side,now:InputListener.now) { self.writeDiagnostics() }
        }
        petView.onLaugh = { [weak self] in self?.startLaugh(nil) }
        petView.onScale = { [weak self] factor in
            guard let self else { return }; self.setPetWidth(self.config.width * factor)
        }
        restorePosition()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "薇欧拉桌面伙伴")
        statusItem.button?.toolTip = "Viola · 薇欧拉桌面伙伴"
        buildMenu()
        screenParametersObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.screenParametersDidChange()
        }
        input.onEvent = { [weak self] event in
            guard let self else { return }
            // A menu click delivered before its action must not cancel the action it starts.
            if !self.engine.isCrawling || event.time > self.crawlStartedAt {
                if self.engine.isCrawling && self.crawlTrigger == "idle" {
                    if case .mouseMove(_, _, _, let dx, let dy) = event {
                        if abs(dx) + abs(dy) > 0.01 { self.recordCrawlCancellation("input") }
                    } else { self.recordCrawlCancellation("input") }
                }
                self.engine.receive(event)
            }
            self.keyStatistics.receive(event)
            if case .keyDown = event { self.statisticsDirty = true }
        }
        wasPermissionGranted = input.permissionGranted
        if config.interactionEnabled { input.start() }
        panel.orderFrontRegardless()
        startFrames()
        housekeeping = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.housekeep() }
        if !input.permissionGranted && !UserDefaults.standard.bool(forKey: "hasSeenWelcome") {
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
            showSettings(nil)
        }
        writeDiagnostics()
    }
    func applicationWillTerminate(_ notification: Notification) {
        cancelCrawl(immediate: true)
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
            self.screenParametersObserver = nil
        }
        rememberPosition(); laughAudio.stop(); input.stop(); frameTimer?.invalidate(); housekeeping?.invalidate(); writeDiagnostics()
        saveStatistics()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPet(nil); return true }

    private func buildMenu() {
        menu = NSMenu(); menu.delegate = self; menu.autoenablesItems = false
        func add(_ title: String, _ selector: Selector?, _ key: String = "", tag: Int = 0) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key); item.target = self; item.tag = tag; menu.addItem(item)
        }
        add("Viola · 薇欧拉桌面伙伴", nil)
        menu.addItem(.separator())
        add("显示薇欧拉", #selector(showPet), "", tag: 1)
        add("收起到菜单栏", #selector(hidePet), "", tag: 2)
        add("开启键鼠互动", #selector(toggleInteraction), "", tag: 3)
        add("窗口置顶", #selector(toggleTop), "", tag: 4)
        add("鼠标穿透", #selector(togglePassThrough), "", tag: 5)
        add("显示桌面和键鼠", #selector(toggleDesks), "", tag: 8)
        let sizeItem = NSMenuItem(title: "大小", action: nil, keyEquivalent: ""); sizeItem.tag = 7
        sizeMenu = NSMenu(title: "大小"); sizeMenu.delegate = self; sizeMenu.autoenablesItems = false
        func addSize(_ title: String, _ selector: Selector, tag: Int = 0) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self; item.tag = tag; sizeMenu.addItem(item)
        }
        addSize("放大 10%", #selector(enlargePet), tag: -1)
        addSize("缩小 10%", #selector(shrinkPet), tag: -2)
        sizeMenu.addItem(.separator())
        for percent in [50, 75, 100, 125, 150, 200] {
            addSize(percent == 100 ? "100%（默认大小）" : "\(percent)%", #selector(selectPetSize), tag: percent)
        }
        sizeMenu.addItem(.separator())
        addSize("恢复默认大小", #selector(resetPetSize))
        let hint = NSMenuItem(title: "角色上滚轮 / 触控板捏合可连续缩放", action: nil, keyEquivalent: "")
        sizeMenu.addItem(hint); sizeItem.submenu = sizeMenu; menu.addItem(sizeItem)
        menu.addItem(.separator())
        add("演示键鼠动作（10 秒）", #selector(startDemo))
        add("让薇欧拉大笑", #selector(startLaugh))
        add("爬行一小段", #selector(startManualCrawl), "", tag: 9)
        add("闲置时偶尔爬行", #selector(toggleIdleCrawl), "", tag: 10)
        add("大笑声音", #selector(toggleLaughSound), "", tag: 6)
        let soundSourceItem = NSMenuItem(title: "声音来源", action: nil, keyEquivalent: "")
        soundSourceMenu = NSMenu(title: "声音来源"); soundSourceMenu.delegate = self; soundSourceMenu.autoenablesItems = false
        for variant in LaughSoundVariant.allCases {
            let item = NSMenuItem(title: variant.label, action: #selector(selectLaughSound), keyEquivalent: "")
            item.target = self; item.representedObject = variant.rawValue
            soundSourceMenu.addItem(item)
        }
        soundSourceItem.submenu = soundSourceMenu; menu.addItem(soundSourceItem)
        add("设置与输入权限…", #selector(showSettings), ",")
        add("键位统计与手指分区…", #selector(showStatistics))
        add("恢复默认位置", #selector(resetPosition))
        menu.addItem(.separator())
        add("退出薇欧拉", #selector(quit), "q")
        statusItem.menu = menu
    }
    func menuWillOpen(_ menu: NSMenu) {
        openMenus += 1
        cancelCrawl(immediate: true, reason: "menu")
        if menu === soundSourceMenu {
            for item in menu.items {
                item.state = item.representedObject as? String == config.laughSoundVariant.rawValue ? .on : .off
            }
            return
        }
        if menu === sizeMenu {
            for item in menu.items where item.tag > 0 {
                let width = PetConfiguration.defaultWidth * Double(item.tag) / 100
                item.state = abs(config.width - width) < 0.5 ? .on : .off
            }
            menu.item(withTag: -1)?.isEnabled = config.width < maximumPetWidth - 0.5
            menu.item(withTag: -2)?.isEnabled = config.width > PetConfiguration.minimumWidth + 0.5
            return
        }
        menu.item(withTag: 1)?.isEnabled = !panel.isVisible
        menu.item(withTag: 2)?.isEnabled = panel.isVisible
        menu.item(withTag: 3)?.state = config.interactionEnabled ? .on : .off
        menu.item(withTag: 4)?.state = config.stayOnTop ? .on : .off
        menu.item(withTag: 5)?.state = config.clickThrough ? .on : .off
        menu.item(withTag: 6)?.state = config.laughSoundEnabled ? .on : .off
        menu.item(withTag: 8)?.state = config.showDesks ? .on : .off
        menu.item(withTag: 9)?.isEnabled = canStartCrawl
        menu.item(withTag: 9)?.toolTip = canStartCrawl ? "紫色伙伴驮着薇欧拉爬行一小段" : "等大笑或穿鞋动作结束、双鞋穿回后可爬行"
        menu.item(withTag: 10)?.state = config.idleCrawlEnabled ? .on : .off
        menu.item(withTag: 7)?.title = "大小（\(Int((config.width / PetConfiguration.defaultWidth * 100).rounded()))%）"
    }
    func menuDidClose(_ menu: NSMenu) { openMenus = max(0, openMenus - 1) }
    @objc private func showPet(_ sender: Any?) {
        cancelCrawl(immediate: true)
        laughAudio.stop(); restorePosition(); panel.orderFrontRegardless(); engine.reset(now: InputListener.now); startFrames()
    }
    @objc private func hidePet(_ sender: Any?) { cancelCrawl(immediate: true); laughAudio.stop(); panel.orderOut(nil); frameTimer?.invalidate(); frameTimer = nil; demoUntil = 0; writeDiagnostics() }
    @objc private func toggleInteraction(_ sender: Any?) {
        cancelCrawl(immediate: true)
        config.interactionEnabled.toggle(); laughAudio.stop(); engine.reset(now: InputListener.now)
        if config.interactionEnabled { input.start() } else { input.stop(); demoUntil = 0 }
        interactionButton?.state = config.interactionEnabled ? .on : .off
        save(); refreshSettings(); writeDiagnostics()
    }
    @objc private func toggleTop(_ sender: Any?) {
        config.stayOnTop.toggle(); panel.level = config.stayOnTop ? .floating : .normal
        topButton?.state = config.stayOnTop ? .on : .off; save()
    }
    @objc private func togglePassThrough(_ sender: Any?) {
        config.clickThrough.toggle(); panel.ignoresMouseEvents = config.clickThrough
        passButton?.state = config.clickThrough ? .on : .off; save()
    }
    @objc private func toggleReduced(_ sender: Any?) { cancelCrawl(immediate: true); config.reducedMotion.toggle(); save() }
    @objc private func toggleDesks(_ sender: Any?) {
        config.showDesks.toggle()
        renderer.setDesksVisible(config.showDesks && !crawlPresentationActive)
        menu.item(withTag: 8)?.state = config.showDesks ? .on : .off
        save(); refreshSettings(); writeDiagnostics()
    }
    @objc private func toggleLaughSound(_ sender: Any?) {
        config.laughSoundEnabled.toggle()
        laughAudio.applySettings(enabled: config.laughSoundEnabled, volume: config.laughSoundVolume, variant: config.laughSoundVariant)
        save(); refreshSettings(); writeDiagnostics()
    }
    @objc private func changeLaughVolume(_ sender: NSSlider) {
        config.laughSoundVolume = sender.doubleValue
        laughAudio.applySettings(enabled: config.laughSoundEnabled, volume: config.laughSoundVolume, variant: config.laughSoundVariant)
        save(); refreshSettings()
    }
    @objc private func selectLaughSound(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String, let variant = LaughSoundVariant(rawValue: rawValue) else { return }
        setLaughSoundVariant(variant)
    }
    @objc private func changeLaughSoundSource(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String, let variant = LaughSoundVariant(rawValue: rawValue) else { return }
        setLaughSoundVariant(variant)
    }
    private func setLaughSoundVariant(_ variant: LaughSoundVariant) {
        guard config.laughSoundVariant != variant else { return }
        config.laughSoundVariant = variant
        laughAudio.applySettings(enabled: config.laughSoundEnabled, volume: config.laughSoundVolume, variant: variant)
        save(); refreshSettings(); writeDiagnostics()
    }
    @objc private func startDemo(_ sender: Any?) {
        cancelCrawl(immediate: true)
        showPet(nil)
        let now = InputListener.now
        demoUntil = now + 10; demoNextKey = now; demoNextClick = now + 1
        refreshSettings()
    }
    @objc private func startLaugh(_ sender: Any?) {
        cancelCrawl(immediate: true)
        if !panel.isVisible { showPet(nil) }
        demoUntil = 0
        _ = engine.startLaugh(now:InputListener.now)
        frame(); writeDiagnostics()
    }
    @objc private func resetPosition(_ sender: Any?) {
        cancelCrawl(immediate: true)
        config.originX = nil; config.originY = nil; restorePosition(); rememberPosition()
    }
    @objc private func quit(_ sender: Any?) { NSApplication.shared.terminate(nil) }
    @objc private func requestInput(_ sender: Any?) { input.requestPermission(); openInputSettings(nil) }
    @objc private func openInputSettings(_ sender: Any?) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") { NSWorkspace.shared.open(url) }
    }
    @objc private func reconnectInput(_ sender: Any?) {
        if config.interactionEnabled { input.start() }; refreshSettings(); writeDiagnostics()
    }
    private func startFrames() {
        guard frameTimer == nil else { return }
        framePacing.beginTimerRun()
        frameCadence.reset()
        lastDraw = InputListener.now
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.frame(isTimerTick: true) }
        RunLoop.main.add(timer, forMode: .common); frameTimer = timer
    }
    private func frame(isTimerTick: Bool = false) {
        guard panel.isVisible else { return }
        let now = InputListener.now
        updateCrawlScheduling(now: now)
        if now < demoUntil {
            if now >= demoNextKey {
                let codes: [UInt16] = [0,1,2,3,38,40,37,41,49]
                let code = codes[Int(now * 7) % codes.count]
                engine.receive(.keyDown(time: now, isRepeat: false, keyCode: code)); engine.receive(.keyUp(time: now + 0.015, keyCode: code)); demoNextKey = now + 0.14
            }
            let phase = now * 3
            engine.receive(.mouseMove(time: now, x: sin(phase) * 100, y: cos(phase) * 80, dx: cos(phase) * 18, dy: sin(phase) * 12))
            if now >= demoNextClick { engine.receive(.leftClick(time: now)); demoNextClick = now + 1.1 }
        }
        let value = engine.tick(now: now, reducedMotion: config.reducedMotion)
        let blinking = (value.blink > 0 && value.blink < 1) || (value.friendBlink > 0 && value.friendBlink < 1)
        let fps = blinking ? 60.0 : value.state == .sleep ? 15.0 : value.state == .idle ? 30.0 : 60.0
        var didDraw = false
        var renderDuration: Double?
        var movementDuration = 0.0
        do {
            // Coordinate window movement and its layer changes in one outer transaction.
            // LayerRenderer's existing transaction nests inside this one.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            defer { CATransaction.commit() }
            let movementStarted = InputListener.now
            applyCrawlMovement(value.crawl, now: now)
            movementDuration = InputListener.now - movementStarted
            if crawlPresentationActive && !engine.isCrawling && !value.crawl.active {
                finishCrawlPresentation()
            }
            laughAudio.update(frame: value, enabled: config.laughSoundEnabled, volume: config.laughSoundVolume, variant: config.laughSoundVariant)
            currentState = value.state
            currentFrame = value
            if frameCadence.shouldDraw(now: now, state: value.state, framesPerSecond: fps, isTimerTick: isTimerTick) {
                var drawing = value; drawing.renderInterval = now-lastDraw
                let renderStarted = InputListener.now
                renderer.render(drawing); lastDraw = now
                renderDuration = InputListener.now - renderStarted
                didDraw = true
            }
        }
        let callbackDuration = InputListener.now - now
        framePacing.recordFrame(now: now, state: value.state.rawValue, targetFPS: fps,
                               isTimerTick: isTimerTick, didDraw: didDraw, renderDuration: renderDuration,
                               movementDuration: movementDuration, callbackDuration: callbackDuration)
    }
    private var canStartCrawl: Bool {
        !engine.isCrawling && currentFrame.laugh < 0.001 &&
        currentFrame.leftShoe.phase == .halfWorn && currentFrame.rightShoe.phase == .halfWorn &&
        engine.activity.keysHeld == 0 && !engine.activity.isTyping
    }
    @objc private func startManualCrawl(_ sender: Any?) {
        demoUntil = 0
        if !panel.isVisible {
            restorePosition(); panel.orderFrontRegardless(); startFrames()
        }
        _ = beginCrawl(now: InputListener.now, trigger: "manual")
        frame(); refreshSettings(); writeDiagnostics()
    }
    @objc private func toggleIdleCrawl(_ sender: Any?) {
        config.idleCrawlEnabled.toggle()
        if !config.idleCrawlEnabled { cancelCrawl(immediate: false) }
        nextAutoCrawl = InputListener.now + Double.random(in: 22...30)
        save(); writeDiagnostics()
    }
    /// Event ages expose activity without reading key contents or requesting Input Monitoring.
    private func desktopIdleAge() -> Double {
        let kinds: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .mouseMoved,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged,
            .otherMouseDragged, .scrollWheel]
        let ages = kinds.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
        // A failed/invalid reading suspends automatic motion.
        guard ages.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return 0 }
        return ages.min() ?? 0
    }
    private func updateCrawlScheduling(now: Double) {
        if now >= nextIdleProbe {
            nativeIdleAge = desktopIdleAge(); nextIdleProbe = now + 0.2
            // This also catches typing in other apps when the keyboard tap is disabled.
            let keyboardAge = [CGEventType.keyDown, .keyUp, .flagsChanged].map {
                CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
            }.filter { $0.isFinite && $0 >= 0 }.min() ?? 0
            let keyboardAfterStart = now - keyboardAge > crawlStartedAt + 0.002
            if engine.isCrawling && crawlTrigger == "idle" && (keyboardAfterStart || now - nativeIdleAge > crawlStartedAt + 0.05) {
                cancelCrawl(immediate: false, reason: "input")
            }
        }
        guard config.idleCrawlEnabled, !config.reducedMotion, now >= nextAutoCrawl,
              nativeIdleAge >= autoCrawlIdleDelay, openMenus == 0,
              !petView.isInteracting, now >= demoUntil, currentState != .sleep,
              settings?.isVisible != true, statisticsWindow?.isVisible != true,
              canStartCrawl else { return }
        if !beginCrawl(now: now, trigger: "idle") { nextAutoCrawl = now + 2 }
    }
    @discardableResult
    private func beginCrawl(now: Double, trigger: String) -> Bool {
        guard canStartCrawl, !petView.isInteracting, let visible = petScreen?.visibleFrame else { return false }
        let petFrame = logicalPetFrame
        let margin = 10.0
        let minimumX = max(visible.minX, min(visible.minX + margin, petFrame.minX))
        let maximumX = min(visible.maxX - petFrame.width,
                           max(petFrame.minX, visible.maxX - petFrame.width - margin))
        let travel = CrawlMotion.maximumTravel * petFrame.width / renderer.canvasSize.width
        let leftRoom = max(0, petFrame.minX - minimumX)
        let rightRoom = max(0, maximumX - petFrame.minX)
        var direction = nextCrawlDirection
        let preferredRoom = direction < 0 ? leftRoom : rightRoom
        let otherRoom = direction < 0 ? rightRoom : leftRoom
        if preferredRoom < travel && otherRoom > preferredRoom { direction *= -1 }
        guard config.reducedMotion || max(leftRoom, rightRoom) > 1 else { return false }
        guard engine.startCrawl(now: now, direction: direction, cancelOnInput: trigger == "idle") else { return false }
        crawlStartedAt = now; crawlTrigger = trigger; crawlCancellationReason = "none"
        crawlScreenBounds = visible; crawlPresentationActive = true
        crawlMinimumX = minimumX; crawlMaximumX = maximumX
        crawlRequestedX = petFrame.minX; crawlOriginX = petFrame.minX
        crawlOriginY = petFrame.minY; crawlPetSize = petFrame.size
        let destinationX = max(minimumX, min(petFrame.minX + direction * travel, maximumX))
        let destination = CGRect(origin: CGPoint(x: destinationX, y: petFrame.minY), size: petFrame.size)
        let host = config.reducedMotion ? petFrame : petFrame.union(destination)
        crawlHostExpanded = host.width > petFrame.width + 0.01
        if crawlHostExpanded {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            let restingPanel = panel!
            let hostPanel = PetPanel(contentRect: host, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            hostPanel.backgroundColor = .clear; hostPanel.isOpaque = false; hostPanel.hasShadow = false
            hostPanel.hidesOnDeactivate = false; hostPanel.isReleasedWhenClosed = false
            hostPanel.collectionBehavior = restingPanel.collectionBehavior
            hostPanel.level = restingPanel.level; hostPanel.delegate = self
            // Keep AppKit's fresh transparent-window hit handling when interaction is enabled.
            if config.clickThrough { hostPanel.ignoresMouseEvents = true }
            crawlRestingPanel = restingPanel
            restingPanel.contentView = nil
            hostPanel.contentView = petView
            panel = hostPanel
            petView.setPetPresentationRect(CGRect(
                origin: CGPoint(x: petFrame.minX - host.minX, y: petFrame.minY - host.minY), size: petFrame.size))
            hostPanel.orderFrontRegardless()
            restingPanel.orderOut(nil)
            CATransaction.commit()
        }
        crawlWindowDistance = 0; crawlWindowPath = []; nextCrawlPathSample = now
        recordCrawlPath(now: now)
        nextCrawlDirection = -direction
        nextAutoCrawl = now + Double.random(in: 75...100)
        autoCrawlIdleDelay = Double.random(in: 22...30)
        renderer.setDesksVisible(false)
        return true
    }
    private func applyCrawlMovement(_ crawl: CrawlFrame, now: Double) {
        guard crawlPresentationActive, let visible = crawlScreenBounds, let petSize = crawlPetSize else { return }
        let delta = crawl.deltaX * petSize.width / renderer.canvasSize.width
        let minimumX = crawlMinimumX
        let maximumX = crawlMaximumX
        let desired = crawlRequestedX + delta
        let x = max(minimumX, min(desired, maximumX))
        crawlRequestedX = x
        // Keep travel on the display selected at the start, including non-zero monitor origins.
        let y = max(visible.minY, min(crawlOriginY, visible.maxY - petSize.height))
        crawlOriginY = y
        if crawlHostExpanded {
            petView.movePetPresentation(to: CGPoint(x: x - panel.frame.minX, y: y - panel.frame.minY))
        }
        crawlWindowDistance = x - crawlOriginX
        if abs(desired - x) > 0.01 {
            recordCrawlCancellation("edge")
            engine.stopCrawl(now: now)
        }
        if now >= nextCrawlPathSample { recordCrawlPath(now: now); nextCrawlPathSample = now + 0.3 }
    }
    private func recordCrawlPath(now: Double) {
        let petFrame = logicalPetFrame
        crawlWindowPath.append(["elapsed": max(0, now - crawlStartedAt), "x": petFrame.minX, "y": petFrame.minY])
    }
    private func recordCrawlCancellation(_ reason: String) {
        if crawlCancellationReason == "none" { crawlCancellationReason = reason }
    }
    private func cancelCrawl(immediate: Bool, reason: String = "interaction") {
        guard engine.isCrawling || crawlPresentationActive else { return }
        recordCrawlCancellation(reason)
        let now = InputListener.now
        engine.stopCrawl(now: now, immediate: immediate)
        nextAutoCrawl = now + Double.random(in: 75...100)
        if immediate { finishCrawlPresentation() }
    }
    private func finishCrawlPresentation() {
        guard crawlPresentationActive else { return }
        recordCrawlPath(now: InputListener.now)
        let petFrame = logicalPetFrame
        if crawlHostExpanded, let restingPanel = crawlRestingPanel {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            let hostPanel = panel!
            // Keep the window receiving a mouseDown alive through its drag/mouseUp sequence.
            // The crawl host becomes the next daily panel after shrinking to the logical pet.
            hostPanel.setFrame(petFrame, display: false)
            petView.setPetPresentationRect(nil)
            hostPanel.level = config.stayOnTop ? .floating : .normal
            hostPanel.ignoresMouseEvents = config.clickThrough
            restingPanel.delegate = nil; restingPanel.close()
            crawlRestingPanel = nil
            CATransaction.commit()
        }
        crawlPresentationActive = false; crawlScreenBounds = nil
        crawlHostExpanded = false; crawlPetSize = nil
        renderer.setDesksVisible(config.showDesks)
        rememberPosition()
    }
    private func housekeep() {
        let granted = input.permissionGranted
        let needsRetry = granted && config.interactionEnabled && !input.keyboardAvailable && InputListener.now >= nextInputRetry
        if granted != wasPermissionGranted || needsRetry {
            wasPermissionGranted = granted
            if config.interactionEnabled { input.start(); nextInputRetry = InputListener.now + 5 }
        }
        refreshSettings(); writeDiagnostics()
        saveStatistics(); refreshStatistics()
    }
    private func screenParametersDidChange() {
        cancelCrawl(immediate: true)
        rememberPosition(); refreshSettings(); writeDiagnostics()
    }
    private var petScreen: NSScreen? {
        let petFrame = logicalPetFrame
        let screen = NSScreen.screens.max { a, b in
            let aRect = a.visibleFrame.intersection(petFrame)
            let bRect = b.visibleFrame.intersection(petFrame)
            let aArea = aRect.isNull ? 0 : aRect.width * aRect.height
            let bArea = bRect.isNull ? 0 : bRect.width * bRect.height
            return aArea < bArea
        }
        if let screen, screen.visibleFrame.intersects(petFrame) { return screen }
        return NSScreen.main ?? NSScreen.screens.first
    }
    private var logicalPetFrame: CGRect {
        if crawlPresentationActive, let size = crawlPetSize {
            return CGRect(origin: CGPoint(x: crawlRequestedX, y: crawlOriginY), size: size)
        }
        return panel?.frame ?? .zero
    }
    private var maximumPetWidth: Double {
        guard let screen = petScreen else { return PetConfiguration.maximumWidth }
        let visible = screen.visibleFrame
        let heightLimit = max(1, visible.height - 20) * renderer.canvasSize.width / renderer.canvasSize.height
        return min(PetConfiguration.maximumWidth, Double(min(max(1, visible.width - 20), heightLimit)))
    }
    private func setPetWidth(_ width: Double) {
        guard width.isFinite else { return }
        cancelCrawl(immediate: true)
        config.width = min(maximumPetWidth, max(PetConfiguration.minimumWidth, width))
        resize()
    }
    @objc private func enlargePet(_ sender: Any?) { setPetWidth(config.width * 1.1) }
    @objc private func shrinkPet(_ sender: Any?) { setPetWidth(config.width * 0.9) }
    @objc private func selectPetSize(_ sender: NSMenuItem) { setPetWidth(PetConfiguration.defaultWidth * Double(sender.tag) / 100) }
    @objc private func resetPetSize(_ sender: Any?) { setPetWidth(PetConfiguration.defaultWidth) }
    private func resize() {
        renderer.setDesksVisible(config.showDesks)
        let oldFrame = panel.frame
        let size = NSSize(width: config.width, height: config.width * renderer.canvasSize.height / renderer.canvasSize.width)
        panel.setFrame(NSRect(x: oldFrame.midX - size.width / 2, y: oldFrame.minY, width: size.width, height: size.height), display: true)
        keepOnScreen(); rememberPosition(); refreshSettings()
    }
    private func restorePosition() {
        if let x = config.originX, let y = config.originY { panel.setFrameOrigin(NSPoint(x: x, y: y)) }
        else if let screen = NSScreen.main { panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - panel.frame.width - 24, y: screen.visibleFrame.minY + 20)) }
        keepOnScreen()
    }
    private func keepOnScreen() {
        guard !crawlPresentationActive else { return }
        guard !NSScreen.screens.isEmpty else { return }
        guard let screen = petScreen else { return }
        let visible = screen.visibleFrame
        // Fit both dimensions and preserve the canvas aspect ratio on smaller displays.
        let fittedWidth = min(config.width, maximumPetWidth)
        if abs(panel.frame.width - fittedWidth) > 0.01 {
            let oldFrame = panel.frame
            config.width = fittedWidth
            let size = NSSize(width: fittedWidth, height: fittedWidth * renderer.canvasSize.height / renderer.canvasSize.width)
            panel.setFrame(NSRect(x: oldFrame.midX - size.width / 2, y: oldFrame.minY, width: size.width, height: size.height), display: true)
        }
        let x = max(visible.minX, min(panel.frame.minX, visible.maxX - panel.frame.width))
        let y = max(visible.minY, min(panel.frame.minY, visible.maxY - panel.frame.height))
        if abs(panel.frame.minX - x) > 0.01 || abs(panel.frame.minY - y) > 0.01 {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    private func rememberPosition() {
        guard panel != nil else { return }
        keepOnScreen()
        let petFrame = logicalPetFrame
        config.originX = petFrame.minX; config.originY = petFrame.minY; save()
    }
    private func save() {
        do { try store.save(config); saveFailure = nil }
        catch { saveFailure = "设置保存失败：\(error.localizedDescription)" }
    }

    @objc private func showSettings(_ sender: Any?) {
        if settings == nil { makeSettings() }
        refreshSettings(); settings?.makeKeyAndOrderFront(nil); NSApplication.shared.activate(ignoringOtherApps: true)
    }
    private func makeSettings() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 680), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Viola · 薇欧拉桌面伙伴"; window.isReleasedWhenClosed = false; window.center()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!; content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)])
        func label(_ text: String, size: CGFloat = 13, color: NSColor = .labelColor) -> NSTextField {
            let field = NSTextField(wrappingLabelWithString: text); field.font = .systemFont(ofSize: size); field.textColor = color; return field
        }
        stack.addArrangedSubview(label("你的桌面键鼠伙伴", size: 23))
        stack.addArrangedSubview(label("拖动角色移动 · 滚轮 / 触控板捏合缩放 · 右键「大小」调整", color: .secondaryLabelColor))
        permissionLabel = label(""); stack.addArrangedSubview(permissionLabel!)
        let permissions = NSStackView(); permissions.orientation = .horizontal; permissions.spacing = 8
        for (title, action) in [("启用全局键盘响应", #selector(requestInput)), ("重新连接", #selector(reconnectInput))] {
            let button = NSButton(title: title, target: self, action: action); button.bezelStyle = .rounded; permissions.addArrangedSubview(button)
        }
        stack.addArrangedSubview(permissions)
        stack.addArrangedSubview(label("物理键码用于键帽和手指动画，各键累计次数保存在本机；不读取或保存输入文字。全局键盘需要「输入监控」权限。", color: .secondaryLabelColor))
        let toggles = NSStackView(); toggles.orientation = .horizontal; toggles.spacing = 15
        interactionButton = NSButton(checkboxWithTitle: "键鼠互动", target: self, action: #selector(toggleInteraction))
        topButton = NSButton(checkboxWithTitle: "置顶", target: self, action: #selector(toggleTop))
        passButton = NSButton(checkboxWithTitle: "鼠标穿透", target: self, action: #selector(togglePassThrough))
        reducedButton = NSButton(checkboxWithTitle: "减少动态", target: self, action: #selector(toggleReduced))
        for button in [interactionButton, topButton, passButton, reducedButton] { toggles.addArrangedSubview(button!) }
        stack.addArrangedSubview(toggles)
        desksButton = NSButton(checkboxWithTitle: "显示桌面和键鼠", target: self, action: #selector(toggleDesks))
        stack.addArrangedSubview(desksButton!)
        let sizeRow = NSStackView(); sizeRow.orientation = .horizontal; sizeRow.spacing = 10
        sizeRow.addArrangedSubview(label("大小")); sizeSlider = NSSlider(value: config.width, minValue: PetConfiguration.minimumWidth, maxValue: maximumPetWidth, target: self, action: #selector(changeSize))
        sizeSlider!.isContinuous = true
        sizeSlider!.setAccessibilityLabel("角色大小，滚轮和捏合也可调整")
        sizeSlider!.widthAnchor.constraint(equalToConstant: 250).isActive = true
        sizeRow.addArrangedSubview(sizeSlider!); sizeValue = label(""); sizeRow.addArrangedSubview(sizeValue!); stack.addArrangedSubview(sizeRow)
        automaticSleepButton = NSButton(checkboxWithTitle: "闲置时自动闭眼休眠", target: self, action: #selector(toggleAutomaticSleep))
        stack.addArrangedSubview(automaticSleepButton!)
        let sleepRow = NSStackView(); sleepRow.orientation = .horizontal; sleepRow.spacing = 10
        sleepRow.addArrangedSubview(label("休眠")); sleepSlider = NSSlider(value: config.sleepAfter, minValue: 15, maxValue: 300, target: self, action: #selector(changeSleep))
        sleepSlider!.widthAnchor.constraint(equalToConstant: 280).isActive = true
        sleepRow.addArrangedSubview(sleepSlider!); sleepValue = label(""); sleepRow.addArrangedSubview(sleepValue!); stack.addArrangedSubview(sleepRow)
        let soundRow = NSStackView(); soundRow.orientation = .horizontal; soundRow.spacing = 10
        soundButton = NSButton(checkboxWithTitle: "大笑声音", target: self, action: #selector(toggleLaughSound))
        soundRow.addArrangedSubview(soundButton!)
        volumeSlider = NSSlider(value: config.laughSoundVolume, minValue: 0, maxValue: 1, target: self, action: #selector(changeLaughVolume))
        volumeSlider!.widthAnchor.constraint(equalToConstant: 220).isActive = true
        volumeSlider!.setAccessibilityLabel("大笑音量")
        soundRow.addArrangedSubview(volumeSlider!); volumeValue = label(""); soundRow.addArrangedSubview(volumeValue!)
        stack.addArrangedSubview(soundRow)
        let soundSourceRow = NSStackView(); soundSourceRow.orientation = .horizontal; soundSourceRow.spacing = 10
        soundSourceRow.addArrangedSubview(label("声音来源"))
        soundSourcePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        soundSourcePopup!.target = self; soundSourcePopup!.action = #selector(changeLaughSoundSource)
        soundSourcePopup!.setAccessibilityLabel("大笑声音来源")
        for variant in LaughSoundVariant.allCases {
            soundSourcePopup!.addItem(withTitle: variant.label)
            soundSourcePopup!.lastItem?.representedObject = variant.rawValue
        }
        soundSourceRow.addArrangedSubview(soundSourcePopup!); stack.addArrangedSubview(soundSourceRow)
        stateLabel = label("", color: .secondaryLabelColor); stack.addArrangedSubview(stateLabel!)
        let actions = NSStackView(); actions.orientation = .horizontal; actions.spacing = 10
        for (title, selector) in [("演示 10 秒", #selector(startDemo)), ("键位统计", #selector(showStatistics)), ("显示伙伴", #selector(showPet)), ("收起", #selector(hidePet))] {
            let button = NSButton(title: title, target: self, action: selector); button.bezelStyle = .rounded; actions.addArrangedSubview(button)
        }
        stack.addArrangedSubview(actions); settings = window
    }
    @objc private func changeSize(_ sender: NSSlider) { setPetWidth(sender.doubleValue) }
    private func applySleepPreference() {
        engine.activity.sleepDelay = config.automaticSleepEnabled ? config.sleepAfter : .infinity
    }
    @objc private func toggleAutomaticSleep(_ sender: NSButton) {
        config.automaticSleepEnabled = sender.state == .on
        applySleepPreference(); save(); refreshSettings()
    }
    @objc private func changeSleep(_ sender: NSSlider) { config.sleepAfter = sender.doubleValue; applySleepPreference(); save(); refreshSettings() }
    private func refreshSettings() {
        let permission = input.permissionGranted
        permissionLabel?.stringValue = !config.interactionEnabled ? "键鼠监听已暂停" : input.keyboardAvailable ? "全局键盘已接入 · 已收到 \(input.keyDownCount) 次按键" : permission ? "输入监控已允许，正在尝试连接；也可点击「重新连接」" : "键盘未接入：请开启系统「输入监控」中的 Viola · 鼠标可使用"
        permissionLabel?.textColor = input.keyboardAvailable ? .systemGreen : .secondaryLabelColor
        interactionButton?.state = config.interactionEnabled ? .on : .off
        topButton?.state = config.stayOnTop ? .on : .off
        passButton?.state = config.clickThrough ? .on : .off
        reducedButton?.state = config.reducedMotion ? .on : .off
        desksButton?.state = config.showDesks ? .on : .off
        soundButton?.state = config.laughSoundEnabled ? .on : .off
        soundSourcePopup?.selectItem(withTitle: config.laughSoundVariant.label)
        for item in soundSourceMenu.items {
            item.state = item.representedObject as? String == config.laughSoundVariant.rawValue ? .on : .off
        }
        volumeSlider?.doubleValue = config.laughSoundVolume; volumeValue?.stringValue = "\(Int(config.laughSoundVolume * 100))%"
        sizeSlider?.maxValue = maximumPetWidth
        sizeSlider?.doubleValue = config.width
        sizeValue?.stringValue = "\(Int((config.width / PetConfiguration.defaultWidth * 100).rounded()))% · \(Int(config.width.rounded())) pt"
        automaticSleepButton?.state = config.automaticSleepEnabled ? .on : .off
        sleepSlider?.isEnabled = config.automaticSleepEnabled
        sleepSlider?.doubleValue = config.sleepAfter
        sleepValue?.stringValue = config.automaticSleepEnabled ? "\(Int(config.sleepAfter)) 秒" : "已关闭"
        stateLabel?.stringValue = saveFailure ?? laughAudio.failure ?? (demoUntil > InputListener.now ? "正在演示动作（演示输入）" : "状态：\(currentState.rawValue) · \(panel.isVisible ? "桌面显示中" : "已收起到菜单栏")")
    }
    private func writeDiagnostics() {
        let windowFrame = logicalPetFrame
        let geometry: [String: Double] = ["width": Double(windowFrame.width), "height": Double(windowFrame.height), "x": Double(windowFrame.minX), "y": Double(windowFrame.minY)]
        let diagnostics: [String: Any] = ["version": Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "development", "uptime": InputListener.now - startTime,
            "inputPermission": input.permissionGranted, "globalKeyboardConnected": input.keyboardAvailable,
            "interactionEnabled": config.interactionEnabled, "visible": panel?.isVisible ?? false,
            "demoActive": InputListener.now < demoUntil, "state": currentState.rawValue,
            "events": ["KEY_DOWN": input.keyDownCount, "KEY_UP": input.keyUpCount, "MOUSE_MOVE": input.mouseMoveCount, "LEFT_CLICK": input.leftClickCount, "RIGHT_CLICK": input.rightClickCount],
            "window": geometry,
            "idleLegAngles": [currentFrame.leftLegSwing, currentFrame.rightLegSwing],
            "idleLegSideAngles": [currentFrame.leftLegSideSwing, currentFrame.rightLegSideSwing],
            "shoes": renderer.shoeDiagnostics,
            "shoeRecovery": [currentFrame.leftShoe.recovery.rawValue,currentFrame.rightShoe.recovery.rawValue],
            "friendExpression": currentFrame.friendExpression.rawValue,
            "friendExpressionOpacity": currentFrame.friendExpressionOpacity,
            "laugh": ["intensity":currentFrame.laugh,"age":currentFrame.laughAge,"trigger":currentFrame.laughTrigger?.rawValue ?? "none"],
            "assetDirectory": CharacterAssets.bundledDirectory.path]
        var current = diagnostics
        current["layoutPath"] = activeLayoutPath
        let hostFrame = panel?.frame ?? .zero
        current["hostWindow"] = ["width": Double(hostFrame.width), "height": Double(hostFrame.height),
            "x": Double(hostFrame.minX), "y": Double(hostFrame.minY), "crawlExpanded": crawlHostExpanded,
            "independentCrawlPanel": crawlRestingPanel != nil] as [String: Any]
        current["framePacing"] = framePacing.diagnostics
        current["petInteraction"] = petView.interactionDiagnostics
        current["toeMotion"] = renderer.toeMotionDiagnostics
        current["laughAudio"] = laughAudio.diagnostics
        current["laughSoundEnabled"] = config.laughSoundEnabled
        current["laughSoundVariant"] = config.laughSoundVariant.rawValue
        current["showDesks"] = config.showDesks
        current["sourceArms"] = renderer.sourceArmDiagnostics
        current["sourceFace"] = renderer.sourceFaceDiagnostics
        current["blink"] = ["rider":currentFrame.blink,"friend":currentFrame.friendBlink]
        current["restingPose"] = renderer.deskVisibilityDiagnostics["restingPose"]
        current["restingPoseVisible"] = renderer.deskVisibilityDiagnostics["restingPoseVisible"]
        current["laughSoundVolume"] = config.laughSoundVolume
        current["idleCrawlEnabled"] = config.idleCrawlEnabled
        current["automaticSleepEnabled"] = config.automaticSleepEnabled
        current["configuredSleepAfter"] = config.sleepAfter
        current["crawl"] = ["active": engine.isCrawling, "trigger": crawlTrigger,
            "startedUptime": crawlStartedAt, "cancellationReason": crawlCancellationReason,
            "weight": currentFrame.crawl.weight,
            "phase": currentFrame.crawl.phase, "direction": currentFrame.crawl.direction,
            "canvasTravel": currentFrame.crawl.distance, "windowTravel": crawlWindowDistance,
            "windowPath": crawlWindowPath, "nativeIdleSeconds": nativeIdleAge,
            "nextAutomaticIn": max(0, nextAutoCrawl - InputListener.now),
            "desksTemporarilyHidden": crawlPresentationActive] as [String: Any]
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: current, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: appDirectory.appendingPathComponent("diagnostics.json"), options: .atomic) }
    }
    private func saveStatistics() {
        guard statisticsDirty else { return }
        do {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(keyStatistics).write(to: appDirectory.appendingPathComponent("keyboard-stats.json"), options: .atomic)
            statisticsDirty = false
        } catch { saveFailure = "键位统计保存失败：\(error.localizedDescription)" }
    }
    @objc private func showStatistics(_ sender: Any?) {
        if statisticsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 530,height: 620), styleMask: [.titled,.closable,.resizable], backing: .buffered, defer: false)
            window.title = "Viola · 键位统计与手指分区"; window.isReleasedWhenClosed = false; window.center()
            let scroll = NSScrollView(frame: window.contentView!.bounds); scroll.autoresizingMask = [.width,.height]; scroll.hasVerticalScroller = true
            let text = NSTextView(frame: scroll.bounds); text.isEditable = false; text.isSelectable = true
            text.font = .monospacedSystemFont(ofSize: 12, weight: .regular); text.textContainerInset = NSSize(width: 20,height: 18)
            text.isVerticallyResizable = true; text.autoresizingMask = [.width]; scroll.documentView = text
            window.contentView!.addSubview(scroll); statisticsText = text; statisticsWindow = window
        }
        refreshStatistics(); statisticsWindow?.makeKeyAndOrderFront(nil); NSApplication.shared.activate(ignoringOtherApps: true)
    }
    private func refreshStatistics() {
        guard statisticsWindow?.isVisible == true || statisticsText?.string.isEmpty == true else { return }
        var lines = ["真实输入累计次数 · 演示输入不计入", "物理 ANSI 键位；各键分别统计按下和连发", "左手移动到全部键位 · 右手始终握鼠标", "Space 和底部 ⌘/⌥ 交给左拇指，键盘右半区交给移动的左食指", "数字小键盘/JIS 等扩展键统计保留，当前紧凑键盘不绘制这些键。", "", "键位          按下     连发     手指分区", "──────────────────────────────────────"]
        let allCodes = Set((0...127).map { UInt16($0) }).union(keyStatistics.counts.keys.compactMap(UInt16.init))
        let codes = KeyboardLayout.keys.map(\.code) + allCodes.filter { KeyboardLayout.byCode[$0] == nil }.sorted()
        for code in codes {
            let count = keyStatistics.count(for: code)
            let label = KeyboardLayout.label(for: code)
            let finger = KeyboardLayout.byCode[code]?.finger.name ?? "扩展键"
            lines.append(label.padding(toLength: 12, withPad: " ", startingAt: 0) + String(format:"%6d  %6d  ",count.presses,count.repeats) + finger)
        }
        statisticsText?.string = lines.joined(separator: "\n")
    }
}
