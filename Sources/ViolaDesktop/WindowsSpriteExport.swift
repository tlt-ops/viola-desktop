import AppKit
import ViolaCore

/// Reproducible RGBA frames for the native Windows WPF renderer.
/// Keeps character geometry and the fixed laugh in the macOS renderer as their source of truth.
enum WindowsSpriteExport {
    static func run(to folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let assets = try CharacterAssets(directory: CharacterAssets.bundledDirectory)
        var clips: [String: Any] = [:]
        var poses: [String: String] = [:]
        func frameFolder(_ name: String) throws -> URL {
            let url = folder.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        func save(_ renderer: LayerRenderer, to directory: URL, index: Int) throws {
            try renderer.savePNG(to: directory.appendingPathComponent(String(format: "%04d.png", index)), scale: 0.4)
        }
        for visible in [true, false] {
            let prefix = visible ? "" : "hidden"
            func name(_ kind: String) -> String {
                visible ? kind : prefix + kind.prefix(1).uppercased() + kind.dropFirst()
            }
            let idleName = name("idle"), idleFolder = try frameFolder(idleName)
            let idle = LayerRenderer(assets: assets); idle.setDesksVisible(visible)
            for index in 0..<96 {
                let phase = Double(index) / 96 * 2 * Double.pi
                var frame = AnimationFrame()
                frame.breath = sin(phase) * 1.65
                frame.friendBreath = sin(phase + 0.2) * 0.7
                frame.headTilt = sin(phase) * 0.007
                frame.hairSway = sin(phase + 0.2) * 0.006
                frame.leftLegSwing = sin(phase) * 0.012
                frame.rightLegSwing = sin(phase + 1.1) * 0.012
                frame.dt = 1.0 / 30; frame.renderInterval = 1.0 / 30
                idle.render(frame)
                try save(idle, to: idleFolder, index: index)
            }
            clips[idleName] = ["frameCount": 96, "fps": 30, "loop": true]
            let blinkName = name("blink"), blinkFolder = try frameFolder(blinkName)
            let blink = LayerRenderer(assets: assets); blink.setDesksVisible(visible)
            let closures = [0.0, 0.12, 0.38, 0.72, 1.0, 1.0, 0.72, 0.38, 0.12, 0.0]
            for (index, closure) in closures.enumerated() {
                var frame = AnimationFrame(); frame.blink = closure; frame.friendBlink = closure
                frame.dt = 1.0 / 30; frame.renderInterval = 1.0 / 30
                blink.render(frame); try save(blink, to: blinkFolder, index: index)
            }
            clips[blinkName] = ["frameCount": closures.count, "fps": 30, "loop": false]
            let laughName = name("laugh"), laughFolder = try frameFolder(laughName)
            let laugh = LayerRenderer(assets: assets); laugh.setDesksVisible(visible)
            let engine = AnimationEngine(now: 0, expressionSeed: 42)
            engine.allowsShoeDrops = false; engine.activity.sleepDelay = .infinity
            guard engine.startLaugh(now: 0) else { throw AssetError.invalid("Windows laugh export did not start") }
            for index in 0..<246 {
                var frame = engine.tick(now: Double(index) / 30)
                frame.renderInterval = index == 0 ? 0 : 1.0 / 30
                laugh.render(frame); try save(laugh, to: laughFolder, index: index)
            }
            clips[laughName] = ["frameCount": 246, "fps": 30, "loop": false]
            let crawlName = name("crawl"), crawlFolder = try frameFolder(crawlName)
            let crawl = LayerRenderer(assets: assets); crawl.setDesksVisible(visible)
            let gait = CrawlMotion(); _ = gait.start(now: 0, direction: 1)
            // Skip the entry ramp, then bake exactly one existing 0.72-second gait.
            for index in 0..<24 {
                var frame = AnimationFrame(); frame.state = .crawl
                frame.crawl = gait.tick(now: 0.72 + Double(index) * 0.72 / 24)
                frame.dt = 0.72 / 24; frame.renderInterval = 0.72 / 24
                crawl.render(frame); try save(crawl, to: crawlFolder, index: index)
            }
            clips[crawlName] = ["frameCount": 24, "fps": 24 / 0.72, "loop": true]
            let poseRenderer = LayerRenderer(assets: assets); poseRenderer.setDesksVisible(visible)
            let mode = visible ? "desk" : "hidden"
            func pose(_ key: String, _ frame: AnimationFrame) throws {
                for _ in 0..<48 { poseRenderer.render(frame) }
                let filename = key + ".png"
                try poseRenderer.savePNG(to: folder.appendingPathComponent(filename), scale: 0.4)
                poses[key] = filename
            }
            var neutral = AnimationFrame(); neutral.dt = 1.0 / 60; neutral.renderInterval = 1.0 / 60
            try pose(mode + "-idle", neutral)
            for key in KeyboardLayout.keys {
                var frame = neutral; frame.state = .typing; frame.keyboardActive = true
                frame.leftAim = key.code; frame.keyPressures = [key.code: 1]
                frame.fingerPressures = [key.finger: 1]; frame.fingerKeys = [key.finger: key.code]
                try pose(mode + "-key-" + String(key.code), frame)
            }
            for (index, target) in [CGPoint(x: -32, y: -22), CGPoint(x: 32, y: -22), CGPoint(x: 32, y: 12), CGPoint(x: -32, y: 12)].enumerated() {
                var frame = neutral; frame.state = .mouseMove; frame.mouseX = target.x; frame.mouseY = target.y
                try pose(mode + "-mouse-" + String(index), frame)
            }
            var click = neutral; click.state = .click; click.mousePress = 1
            try pose(mode + "-mouse-click", click)
        }
        let manifest: [String: Any] = ["schemaVersion": 1, "sourceVersion": "0.2.49", "width": 320, "height": 384,
            "clips": clips, "poses": poses, "crawlCycleSeconds": 0.72, "laughActionSeconds": 8,
            "license": "See ASSET_LICENSE.md; media are not MIT licensed"]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("frames.json"))
        print("Exported Windows RGBA animation clips and physical-key poses to \(folder.path)")
    }
}
