import AppKit
import ViolaCore

let application = NSApplication.shared
let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--render-gallery"), arguments.count > index + 1 {
    do {
        let folder = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bindings: [[String:Any]] = KeyboardLayout.keys.map { ["keyCode":Int($0.code),"label":$0.label,"row":$0.row,"column":$0.column,"width":$0.width,"finger":$0.finger.rawValue] }
        try JSONSerialization.data(withJSONObject: bindings,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("key-bindings.json"))
        let layoutIndex = arguments.firstIndex(of:"--layout")
        let layout = layoutIndex.flatMap { $0+1 < arguments.count ? URL(fileURLWithPath:arguments[$0+1]) : nil }
        let renderer = try LayerRenderer(assets: CharacterAssets(directory: CharacterAssets.bundledDirectory,manifestURL:layout))
        if arguments.contains("--hide-desks") { renderer.setDesksVisible(false) }
        if arguments.contains("--source-arm-return-review") {
            let assets = try CharacterAssets(directory:CharacterAssets.bundledDirectory,manifestURL:layout)
            let background = NSColor(calibratedWhite:0.96,alpha:1)
            var evidence: [[String:Any]] = []
            func inspect(_ rig: LayerRenderer, _ name: String, capture: Bool = false) throws {
                let arms = rig.sourceArmDiagnostics
                if arms["mouseGripRestored"] as? Bool == true, rig.desksVisible {
                    let grip = Double(arms["mouseGripOpacity"] as? Float ?? -1)
                    let empty = Double(arms["emptyMouseHandOpacity"] as? Float ?? -1)
                    guard grip == 1 && empty == 0 else {
                        throw AssetError.invalid("mouse hand duplicated or changed pose in \(name)")
                    }
                }
                if let values = arms["arms"] as? [String:[String:Any]] {
                    for (id,arm) in values where !arm.isEmpty {
                        func number(_ key: String) -> Double {
                            if let value = arm[key] as? CGFloat { return Double(value) }
                            return arm[key] as? Double ?? .nan
                        }
                        guard number("minimumDeterminant") > 0, number("cuffGap") < 0.001,
                              number("wristError") < 2 else {
                            throw AssetError.invalid("source arm folds or detaches in \(name): \(id), \(arm)")
                        }
                    }
                }
                if let reach = arms["keyboardReach"] as? [String:Any], reach["enabled"] as? Bool == true {
                    let limits = reach["limits"] as? [CGFloat] ?? []
                    func inside(_ key: String) -> Bool {
                        guard let offset = reach[key] as? [CGFloat], offset.count == 2, limits.count == 3 else { return false }
                        return offset.allSatisfy { $0.isFinite } && abs(offset[0]) <= limits[0]+0.001 &&
                            offset[1] >= -limits[1]-0.001 && offset[1] <= limits[2]+0.001
                    }
                    guard inside("limitedOffset"), inside("renderedOffset") else {
                        throw AssetError.invalid("keyboard gesture exceeds its wrist range in \(name): \(reach)")
                    }
                    if (arms["laughWeight"] as? Double ?? 0) == 0 {
                        guard inside("actualWristOffset") else {
                            throw AssetError.invalid("keyboard wrist leaves its resting area in \(name): \(reach)")
                        }
                        if name.hasSuffix("after-settled") || name == "keyboard-release-settled" {
                            let offset = reach["actualWristOffset"] as? [CGFloat] ?? []
                            guard offset.count == 2, hypot(offset[0],offset[1]) < 0.001 else {
                                throw AssetError.invalid("keyboard wrist did not return to rest in \(name): \(reach)")
                            }
                        }
                    }
                }
                evidence.append(["name":name,"arms":arms])
                if capture {
                    try rig.savePNG(to:folder.appendingPathComponent(name+".png"),background:background)
                    try rig.savePNG(to:folder.appendingPathComponent(name+"-arms.png"),background:background,
                        region:CGRect(x:180,y:530,width:410,height:230),scale:3)
                }
            }
            for visible in [true,false] {
                let rig = LayerRenderer(assets:assets), mode = visible ? "desk" : "hidden"
                rig.setDesksVisible(visible)
                var neutral = AnimationFrame(); neutral.dt = 1.0/60; neutral.renderInterval = 1.0/60
                for _ in 0..<48 { rig.render(neutral) }
                try inspect(rig,mode+"-before",capture:true)
                let engine = AnimationEngine(now:0,expressionSeed:42)
                engine.allowsShoeDrops = false
                guard engine.startLaugh(now:0) else { throw AssetError.invalid("source laugh did not start") }
                for n in 0...192 {
                    var frame = engine.tick(now:Double(n)/30)
                    frame.renderInterval = n == 0 ? 0 : 1.0/30
                    rig.render(frame)
                    try inspect(rig,mode+"-laugh-\(n)",capture:[0,4,5,8,33,60,159,160,161,162,180,192].contains(n))
                }
                rig.render(neutral)
                try inspect(rig,mode+"-after-immediate",capture:true)
                for _ in 0..<120 { rig.render(neutral) }
                try inspect(rig,mode+"-after-settled",capture:true)
            }
            let rig = LayerRenderer(assets:assets); rig.setDesksVisible(true)
            for key in KeyboardLayout.keys {
                var frame = AnimationFrame(); frame.dt = 1.0/60; frame.renderInterval = 1.0/60
                frame.state = .typing; frame.keyboardActive = true; frame.leftAim = key.code
                frame.keyPressures = [key.code:1]; frame.fingerPressures = [key.finger:1]
                frame.fingerKeys = [key.finger:key.code]
                for _ in 0..<48 { rig.render(frame) }
                try inspect(rig,"key-\(key.code)",capture:[0,8,38,36,49,53,51].contains(Int(key.code)))
            }
            var release = AnimationFrame(); release.dt = 1.0/60; release.renderInterval = 1.0/60
            rig.render(release)
            try inspect(rig,"keyboard-release-immediate",capture:true)
            for _ in 0..<120 { rig.render(release) }
            try inspect(rig,"keyboard-release-settled",capture:true)
            // These are the actual mouse travel limits in AnimationEngine.
            for (index,target) in [CGPoint(x:-32,y:-22),CGPoint(x:32,y:-22),CGPoint(x:32,y:12),CGPoint(x:-32,y:12)].enumerated() {
                var frame = AnimationFrame(); frame.dt = 1.0/60; frame.renderInterval = 1.0/60
                frame.state = .mouseMove; frame.mouseX = target.x; frame.mouseY = target.y
                for _ in 0..<48 { rig.render(frame) }
                try inspect(rig,"mouse-corner-\(index)",capture:true)
                // A relocated wrist must also release/return from every mouse
                // extreme, including the intermediate cuff rotation.
                for n in 0...60 {
                    frame.laugh = Double(n)/60
                    rig.render(frame)
                    try inspect(rig,"mouse-corner-\(index)-release-\(n)")
                }
                for n in stride(from:60,through:0,by:-1) {
                    frame.laugh = Double(n)/60
                    rig.render(frame)
                    try inspect(rig,"mouse-corner-\(index)-return-\(n)")
                }
            }
            for (index,direction) in [CGPoint(x:-1,y:-1),CGPoint(x:1,y:-1),CGPoint(x:1,y:1),CGPoint(x:-1,y:1)].enumerated() {
                let rig = LayerRenderer(assets:assets)
                let engine = AnimationEngine(now:0,expressionSeed:42)
                engine.allowsShoeDrops = false
                for n in 0...450 {
                    let now = Double(n)/60
                    if n == 30 { _ = engine.startLaugh(now:now) }
                    if n % 3 == 0 {
                        let reverse = n >= 352 ? -1.0 : 1.0
                        engine.receive(.mouseMove(time:now,x:0,y:0,dx:direction.x*20*reverse,dy:direction.y*20*reverse))
                    }
                    var frame = engine.tick(now:now); frame.renderInterval = 1.0/60
                    rig.render(frame)
                    try inspect(rig,"live-mouse-reversal-\(index)-\(n)",capture:[352,370,450].contains(n))
                }
            }
            try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys])
                .write(to:folder.appendingPathComponent("source-arm-return-review.json"))
            print("Rendered arm returns, all physical keys, and four mouse corners")
            exit(0)
        }
        if arguments.contains("--source-motion-review") {
            let assets = try CharacterAssets(directory:CharacterAssets.bundledDirectory,manifestURL:layout)
            let background = NSColor(calibratedWhite:0.96,alpha:1)
            var evidence: [[String:Any]] = []
            func capture(_ rig: LayerRenderer, _ name: String) throws {
                try rig.savePNG(to:folder.appendingPathComponent(name+".png"),background:background)
                try rig.savePNG(to:folder.appendingPathComponent(name+"-rider-face.png"),background:background,
                    region:CGRect(x:242,y:745,width:145,height:105),scale:4)
                try rig.savePNG(to:folder.appendingPathComponent(name+"-friend-face.png"),background:background,
                    region:CGRect(x:196,y:376,width:162,height:112),scale:3)
            }
            func record(_ rig: LayerRenderer, _ name: String, _ frame: AnimationFrame) throws {
                if let arms = rig.sourceArmDiagnostics["arms"] as? [String:[String:Any]] {
                    for (id,arm) in arms where !arm.isEmpty {
                        func number(_ key: String) -> Double? {
                            if let value = arm[key] as? CGFloat { return Double(value) }
                            return arm[key] as? Double
                        }
                        guard let determinant = number("minimumDeterminant"),
                              determinant.isFinite, determinant > 0,
                              let cuffGap = number("cuffGap"),
                              cuffGap.isFinite, cuffGap < 0.001,
                              let wristError = number("wristError"),
                              wristError.isFinite, wristError < 2 else {
                            throw AssetError.invalid("source arm folds or detaches in \(name): \(id), \(arm)")
                        }
                    }
                }
                evidence.append(["name":name,"laugh":frame.laugh,"laughAge":frame.laughAge,
                    "blink":frame.blink,"friendBlink":frame.friendBlink,
                    "arms":rig.sourceArmDiagnostics,"face":rig.sourceFaceDiagnostics])
            }
            let blinkRig = LayerRenderer(assets:assets)
            blinkRig.setDesksVisible(false)
            for (index,closure) in [0.0,0.1,0.25,0.45,0.65,0.85,1.0,0.85,0.65,0.45,0.25,0.1,0.0].enumerated() {
                var frame = AnimationFrame(); frame.blink = closure; frame.friendBlink = closure
                blinkRig.render(frame)
                let name = String(format:"blink-%02d",index)
                try capture(blinkRig,name); try record(blinkRig,name,frame)
            }
            if arguments.contains("--source-friend-eyes-only") {
                for (index,opacity) in [0.0,0.25,0.5,0.75,0.9,1.0,0.75,0.5,0.25,0.0].enumerated() {
                    var frame = AnimationFrame()
                    frame.friendExpression = .effort; frame.friendExpressionOpacity = opacity
                    blinkRig.render(frame)
                    let name = String(format:"effort-%02d",index)
                    try capture(blinkRig,name); try record(blinkRig,name,frame)
                }
                for (name,laugh,expression,expressionOpacity,friendBlink) in [
                    ("effort-blink-open",0.0,FriendExpression.effort,1.0,1.0),
                    ("laugh-blink-open",1.0,FriendExpression.neutral,0.0,1.0),
                    ("laugh-effort-blink-open",1.0,FriendExpression.effort,1.0,1.0),
                    ("idle-blink-closed",0.0,FriendExpression.neutral,0.0,1.0)
                ] {
                    var frame = AnimationFrame()
                    frame.laugh = laugh; frame.friendExpression = expression
                    frame.friendExpressionOpacity = expressionOpacity; frame.friendBlink = friendBlink
                    blinkRig.render(frame)
                    try capture(blinkRig,name); try record(blinkRig,name,frame)
                }
                let engine = AnimationEngine(now:0,expressionSeed:42)
                engine.allowsShoeDrops = false
                guard engine.startLaugh(now:0) else { throw AssetError.invalid("source laugh did not start") }
                for n in [0,3,8,15,33,60,90,135,162,180,192] {
                    let frame = engine.tick(now:Double(n)/30)
                    blinkRig.render(frame)
                    let name = "laugh-hidden-\(n)"
                    try capture(blinkRig,name); try record(blinkRig,name,frame)
                }
                try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys])
                    .write(to:folder.appendingPathComponent("source-motion-review.json"))
                print("Rendered 13 blink, 10 open-eye effort, 4 blink edge cases, and 11 laugh phases")
                exit(0)
            }
            if arguments.contains("--source-blink-only") {
                try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys])
                    .write(to:folder.appendingPathComponent("source-motion-review.json"))
                print("Rendered 13 continuous blink phases")
                exit(0)
            }
            for visible in [true,false] {
                let mode = visible ? "desk" : "hidden"
                let rig = LayerRenderer(assets:assets)
                rig.setDesksVisible(visible)
                let movieFolder = folder.appendingPathComponent("movie-"+mode,isDirectory:true)
                if arguments.contains("--source-motion-video") {
                    try FileManager.default.createDirectory(at:movieFolder,withIntermediateDirectories:true)
                }
                let engine = AnimationEngine(now:0,expressionSeed:42)
                engine.allowsShoeDrops = false
                guard engine.startLaugh(now:0) else { throw AssetError.invalid("source laugh did not start") }
                for n in 0...192 {
                    var frame = engine.tick(now:Double(n)/30)
                    frame.renderInterval = n == 0 ? 0 : 1.0/30
                    rig.render(frame)
                    let name = "laugh-\(mode)-\(n)"
                    try record(rig,name,frame)
                    if [0,3,8,15,33,60,90,135,162,180,192].contains(n) { try capture(rig,name) }
                    if arguments.contains("--source-motion-video"), n % 2 == 0 {
                        try rig.savePNG(to:movieFolder.appendingPathComponent(String(format:"%03d.png",n/2)),background:background)
                    }
                }
            }
            let armRig = LayerRenderer(assets:assets)
            armRig.setDesksVisible(true)
            for key in KeyboardLayout.keys {
                var frame = AnimationFrame(); frame.state = .typing; frame.keyboardActive = true
                frame.leftAim = key.code; frame.keyPressures = [key.code:1]
                frame.fingerPressures = [key.finger:1]; frame.fingerKeys = [key.finger:key.code]
                for _ in 0..<48 { armRig.render(frame) }
                let name = "key-\(key.code)"
                try record(armRig,name,frame)
                if [0,38,36,49,53,51].contains(Int(key.code)) {
                    try armRig.savePNG(to:folder.appendingPathComponent(name+".png"),background:background)
                }
            }
            for (index,target) in [CGPoint(x:-60,y:-40),CGPoint(x:60,y:-40),CGPoint(x:60,y:40),CGPoint(x:-60,y:40)].enumerated() {
                var frame = AnimationFrame(); frame.state = .mouseMove
                frame.mouseX = target.x; frame.mouseY = target.y
                for _ in 0..<48 { armRig.render(frame) }
                let name = "mouse-corner-\(index)"
                try record(armRig,name,frame)
                try armRig.savePNG(to:folder.appendingPathComponent(name+".png"),background:background)
            }
            try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys])
                .write(to:folder.appendingPathComponent("source-motion-review.json"))
            print("Rendered continuous blink phases, laughter in both desk modes, every physical key and mouse extremes")
            exit(0)
        }
        if arguments.contains("--crawl-review") {
            let assets = try CharacterAssets(directory:CharacterAssets.bundledDirectory,manifestURL:layout)
            let background = NSColor(calibratedWhite:0.96,alpha:1)
            let selected = Set([0,12,18,27,42,54,72,81,108,162,180,201,216,240])
            let stillsOnly = arguments.contains("--crawl-stills-only")
            let quick = arguments.contains("--crawl-quick-review")
            var evidence: [[String:Any]] = []
            for mode in (quick ? ["normal","reverse"] : ["normal","reverse","reduced","cancelled"]) {
                let rig = LayerRenderer(assets:assets), isolated = LayerRenderer(assets:assets)
                rig.setDesksVisible(false); isolated.setDesksVisible(false)
                let engine = AnimationEngine(now:0,expressionSeed:42)
                guard engine.startCrawl(now:0,direction:mode == "reverse" ? -1 : 1) else {
                    throw AssetError.invalid("crawl review could not start")
                }
                let motionFolder = folder.appendingPathComponent(mode,isDirectory:true)
                try FileManager.default.createDirectory(at:motionFolder,withIntermediateDirectories:true)
                var timeline: [[String:Any]] = [], comparison: [[String:Any]] = []
                var travel = 0.0, maxAttachmentError = 0.0
                for n in 0...(quick ? 84 : 240) {
                    let time = Double(n)/30
                    if mode == "cancelled", n == 64 { engine.stopCrawl(now:time) }
                    var frame = engine.tick(now:time,reducedMotion:mode == "reduced")
                    frame.renderInterval = n == 0 ? 0 : 1.0/30
                    travel += frame.crawl.deltaX
                    rig.render(frame)
                    if let meshes = rig.crawlDiagnostics["meshes"] as? [String:[String:Any]] {
                        for mesh in meshes.values {
                            if let determinant = mesh["minimumDeterminant"] as? Double,
                               !determinant.isFinite || determinant <= 0 {
                                throw AssetError.invalid("crawl mesh folds in \(mode) frame \(n): \(determinant)")
                            }
                        }
                    }
                    var other = frame
                    other.leftLegSwing = 0.48*sin(time*2.1+0.3)
                    other.rightLegSwing = -0.45*cos(time*1.7)
                    isolated.render(other)
                    if let attachments = rig.motionSeamDiagnostics["breathingAttachmentDeltaY"] as? [String:Double] {
                        maxAttachmentError = max(maxAttachmentError,attachments.values.map(abs).max() ?? 0)
                    }
                    timeline.append(["frame":n,"time":time,"state":frame.state.rawValue,
                        "active":frame.crawl.active,"weight":frame.crawl.weight,"phase":frame.crawl.phase,
                        "travel":travel,"deltaX":frame.crawl.deltaX,"rig":rig.crawlDiagnostics])
                    if mode == "normal", !stillsOnly, !quick, n % 2 == 0 {
                        // The viewport offset emulates native panel travel without
                        // changing the rig's local coordinates or joint measurements.
                        try rig.savePNG(to:motionFolder.appendingPathComponent(String(format:"%03d.png",n/2)),
                            background:background,region:CGRect(x:-20-travel,y:0,width:1000,height:960))
                    }
                    if selected.contains(n) {
                        let name = "\(mode)-\(n)"
                        try rig.savePNG(to:folder.appendingPathComponent(name+".png"),background:background)
                        try rig.savePNG(to:folder.appendingPathComponent(name+"-support.png"),background:background,
                            region:CGRect(x:210,y:80,width:585,height:470),scale:1.5)
                        let first = motionFolder.appendingPathComponent("friend-\(n).png")
                        let second = motionFolder.appendingPathComponent("friend-other-legs-\(n).png")
                        try rig.saveFriendSupportPNG(to:first); try isolated.saveFriendSupportPNG(to:second)
                        let equal = try Data(contentsOf:first) == Data(contentsOf:second)
                        comparison.append(["frame":n,"friendPNGEqualWithDifferentViolaLegs":equal])
                        if !equal { throw AssetError.invalid("crawl borrows Viola leg motion in \(name)") }
                    }
                }
                if maxAttachmentError > 0.000001 { throw AssetError.invalid("crawl separates thigh/body attachment") }
                if mode == "reduced", abs(travel) > 0.000001 { throw AssetError.invalid("reduced crawl moves window") }
                evidence.append(["mode":mode,"frames":timeline,"totalTravel":travel,
                    "maxThighAttachmentError":maxAttachmentError,"friendIsolation":comparison])
            }
            try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys])
                .write(to:folder.appendingPathComponent("crawl-review.json"))
            print(quick ? "Rendered quick forward/reverse crawl poses and checked mesh orientation and attachment" :
                "Rendered crawl, reverse, reduced motion and interruption; checked mesh orientation, source-owned friend isolation and rider attachment")
            exit(0)
        }
        if arguments.contains("--motion-seam-review") {
            let assets = try CharacterAssets(directory:CharacterAssets.bundledDirectory,manifestURL:layout)
            let background = NSColor(calibratedWhite:0.96,alpha:1)
            let detail = CGRect(x:200,y:290,width:500,height:280)
            func freshRig(_ visible: Bool) -> LayerRenderer {
                let rig = LayerRenderer(assets:assets); rig.setDesksVisible(visible); return rig
            }
            func friendSignature(_ diagnostics: [String:Any]) -> Data? {
                guard let friend = diagnostics["friend"], JSONSerialization.isValidJSONObject(friend) else { return nil }
                return try? JSONSerialization.data(withJSONObject:friend,options:[.sortedKeys])
            }
            var stills: [[String:Any]] = []
            var isolation: [[String:Any]] = []
            var ownBreath: [[String:Any]] = []
            var gapMeasurements: [[String:Any]] = []
            let variants = ["baseline","breath-plus","breath-minus","friend-breath-plus","friend-breath-minus",
                            "legs-plus","legs-minus","side-plus","side-minus"]
            for visible in [true,false] {
                let mode = visible ? "visible" : "hidden"
                for variant in variants {
                    let rig = freshRig(visible)
                    var frame = AnimationFrame(); frame.dt = 0; frame.renderInterval = 0
                    switch variant {
                    case "breath-plus": frame.breath = 2.2
                    case "breath-minus": frame.breath = -2.2
                    case "friend-breath-plus": frame.friendBreath = 1.6
                    case "friend-breath-minus": frame.friendBreath = -1.6
                    case "legs-plus": frame.leftLegSwing = 0.6; frame.rightLegSwing = 0.6
                    case "legs-minus": frame.leftLegSwing = -0.6; frame.rightLegSwing = -0.6
                    case "side-plus": frame.leftLegSideSwing = 0.13; frame.rightLegSideSwing = 0.13
                    case "side-minus": frame.leftLegSideSwing = -0.13; frame.rightLegSideSwing = -0.13
                    default: break
                    }
                    rig.render(frame)
                    let label = "\(mode)-\(variant)", diagnostics = rig.motionSeamDiagnostics
                    try rig.savePNG(to:folder.appendingPathComponent(label+".png"),background:background)
                    try rig.savePNG(to:folder.appendingPathComponent(label+"-detail.png"),background:background,region:detail,scale:2)
                    stills.append(["mode":mode,"variant":variant,"full":label+".png","detail":label+"-detail.png",
                        "inputs":["breath":frame.breath,"friendBreath":frame.friendBreath,
                                  "legs":[frame.leftLegSwing,frame.rightLegSwing],
                                  "side":[frame.leftLegSideSwing,frame.rightLegSideSwing]],"diagnostics":diagnostics])
                    var gap: [String:Any] = ["pose":label]
                    for key in ["maxJointGap","expectedMaxJointGap"] {
                        if let value = diagnostics[key] { gap[key] = value }
                    }
                    if gap.count > 1 { gapMeasurements.append(gap) }
                }
                // Separate rigs retain independent spring histories. Only Viola's
                // legs differ; the friend's support inputs and clock are identical.
                let stillLegs = freshRig(visible), movingLegs = freshRig(visible)
                let breathingFriend = freshRig(visible), staticFriend = freshRig(visible)
                let frameCount = 720, selected = Set([0,114,342,719])
                var mismatches: [Int] = [], missing = 0, changed = 0, ownMissing = 0
                var isolationImages: [[String:Any]] = [], breathImages: [[String:Any]] = []
                for n in 0..<frameCount {
                    let t = Double(n)/60
                    var common = AnimationFrame(); common.dt = n == 0 ? 0 : 1.0/60
                    common.renderInterval = common.dt
                    common.breath = 0.9*sin(t*1.3)
                    common.friendBreath = 1.6*sin(t*2*Double.pi/3.8+1.7)
                    common.friendTrembleX = 0.25*sin(t*12.7+0.8)
                    common.friendTrembleY = 0.18*sin(t*14.3+1.4)
                    var moving = common
                    moving.leftLegSwing = 0.6*sin(t*1.4+0.3)
                    moving.rightLegSwing = 0.6*sin(t*1.4+2.2)
                    moving.leftLegSideSwing = 0.13*sin(t*0.92+0.5)
                    moving.rightLegSideSwing = 0.13*sin(t*0.86+2.6)
                    stillLegs.render(common); movingLegs.render(moving)
                    let a = stillLegs.motionSeamDiagnostics, b = movingLegs.motionSeamDiagnostics
                    if let first = friendSignature(a), let second = friendSignature(b) {
                        if first != second { mismatches.append(n) }
                    } else { missing += 1 }
                    var own = AnimationFrame(); own.dt = common.dt; own.renderInterval = common.dt
                    own.friendBreath = common.friendBreath
                    var fixed = own; fixed.friendBreath = 0
                    breathingFriend.render(own); staticFriend.render(fixed)
                    let dynamicDiagnostics = breathingFriend.motionSeamDiagnostics
                    let staticDiagnostics = staticFriend.motionSeamDiagnostics
                    var differs = false
                    if let dynamic = friendSignature(dynamicDiagnostics), let stationary = friendSignature(staticDiagnostics) {
                        differs = dynamic != stationary
                        if differs { changed += 1 }
                    } else { ownMissing += 1 }
                    if selected.contains(n) {
                        try movingLegs.savePNG(to:folder.appendingPathComponent("\(mode)-combined-\(n).png"),background:background)
                        try movingLegs.savePNG(to:folder.appendingPathComponent("\(mode)-combined-\(n)-detail.png"),background:background,region:detail,scale:2)
                        let aName = "\(mode)-isolation-still-\(n).png", bName = "\(mode)-isolation-moving-\(n).png"
                        let aURL = folder.appendingPathComponent(aName), bURL = folder.appendingPathComponent(bName)
                        try stillLegs.saveFriendSupportPNG(to:aURL); try movingLegs.saveFriendSupportPNG(to:bURL)
                        let equal = try Data(contentsOf:aURL) == Data(contentsOf:bURL)
                        isolationImages.append(["frame":n,"time":t,"still":aName,"moving":bName,
                            "pngBytesEqual":equal,"stillDiagnostics":a,"movingDiagnostics":b])
                        let dynamicName = "\(mode)-friend-breath-\(n).png", staticName = "\(mode)-friend-static-\(n).png"
                        let dynamicURL = folder.appendingPathComponent(dynamicName), staticURL = folder.appendingPathComponent(staticName)
                        try breathingFriend.saveFriendSupportPNG(to:dynamicURL); try staticFriend.saveFriendSupportPNG(to:staticURL)
                        let pixelsDiffer = try Data(contentsOf:dynamicURL) != Data(contentsOf:staticURL)
                        breathImages.append(["frame":n,"time":t,"breath":own.friendBreath,
                            "dynamic":dynamicName,"static":staticName,"geometryDiffers":differs,
                            "pngBytesDiffer":pixelsDiffer,"dynamicDiagnostics":dynamicDiagnostics,
                            "staticDiagnostics":staticDiagnostics])
                    }
                }
                let pngMismatches = isolationImages.filter { ($0["pngBytesEqual"] as? Bool) != true }.count
                isolation.append(["mode":mode,"frames":frameCount,"seconds":Double(frameCount)/60,
                    "friendBreathingPeriod":3.8,"geometryMismatchCount":mismatches.count,
                    "mismatchFrames":mismatches,"missingFriendDiagnostics":missing,
                    "selectedPNGMismatchCount":pngMismatches,
                    "passed":missing == 0 && mismatches.isEmpty && pngMismatches == 0,"selected":isolationImages])
                ownBreath.append(["mode":mode,"frames":frameCount,"geometryChangedFrames":changed,
                    "missingFriendDiagnostics":ownMissing,"friendOwnBreathResponds":ownMissing == 0 && changed > 0,
                    "selected":breathImages])
            }
            var evidence: [String:Any] = ["stills":stills,"friendIsolation":isolation,"friendOwnBreath":ownBreath,
                "comparison":"The friend diagnostic object is compared every frame; selected isolated friend PNG bytes are compared separately.",
                "detailRegion":[detail.minX,detail.minY,detail.width,detail.height],"detailScale":2]
            if !gapMeasurements.isEmpty { evidence["jointGapMeasurements"] = gapMeasurements }
            try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys])
                .write(to:folder.appendingPathComponent("motion-seam-review.json"))
            print("Exported 18 seam poses and 12-second friend isolation/own-breath checks in both desktop modes")
            exit(0)
        }
        if arguments.contains("--completion-seam-input") {
            try renderer.saveCompletionInput(to:folder.appendingPathComponent("costume-seam-input.png"))
            print("Exported missing costume region from the original artwork")
            exit(0)
        }
        if arguments.contains("--resting-pose-review") {
            renderer.setDesksVisible(false)
            var evidence: [[String:Any]] = []
            for n in 0...300 {
                var frame = AnimationFrame(); frame.dt = n == 0 ? 0 : 1.0/60
                let t = Double(n)/60
                frame.breath = 1.2*sin(t*1.1); frame.friendBreath = 0.7*sin(t*0.9)
                frame.supportSway = 0.004*sin(t*0.8)
                renderer.render(frame)
                evidence.append(["frame":n,"diagnostics":renderer.deskVisibilityDiagnostics])
                if [0,75,150,225,300].contains(n) {
                    try renderer.savePNG(to:folder.appendingPathComponent("rest-\(n).png"),background:NSColor(calibratedWhite:0.96,alpha:1))
                    try renderer.savePNG(to:folder.appendingPathComponent("hands-\(n).png"),background:NSColor(calibratedWhite:0.96,alpha:1),region:CGRect(x:285,y:430,width:350,height:270),scale:3)
                }
            }
            var reduced = AnimationFrame(); reduced.reducedMotion = true
            renderer.render(reduced)
            evidence.append(["frame":"reduced","diagnostics":renderer.deskVisibilityDiagnostics])
            try renderer.savePNG(to:folder.appendingPathComponent("reduced.png"),background:NSColor(calibratedWhite:0.96,alpha:1))
            try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("resting-motion.json"))
            print("Rendered resting contact motion over five seconds and reduced motion")
            exit(0)
        }
        if arguments.contains("--desk-visibility-review") {
            var evidence: [[String:Any]] = []
            for (name,visible) in [("visible",true),("hidden",false),("restored",true),("hidden-again",false)] {
                renderer.setDesksVisible(visible)
                var frame = AnimationFrame(); frame.breath = 1.2
                frame.supportSway = 0.004; frame.friendBreath = 0.7
                if !visible { frame.leftAim = 0; frame.keyPressures = [0:1]; frame.mouseX = 16; frame.mouseY = 9 }
                renderer.render(frame)
                try renderer.savePNG(to:folder.appendingPathComponent(name+".png"),background:NSColor(calibratedWhite:0.96,alpha:1))
                if name == "hidden" {
                    try renderer.savePNG(to:folder.appendingPathComponent("waist-detail.png"),
                        background:NSColor(calibratedWhite:0.96,alpha:1),
                        region:CGRect(x:250,y:435,width:410,height:200),scale:3)
                }
                evidence.append(["state":name,"layers":renderer.deskVisibilityDiagnostics])
            }
            renderer.setDesksVisible(false)
            var frame = AnimationFrame(); frame.laugh = 1; frame.laughBounce = 2
            renderer.render(frame)
            try renderer.savePNG(to:folder.appendingPathComponent("hidden-laugh.png"),background:NSColor(calibratedWhite:0.96,alpha:1))
            evidence.append(["state":"hidden-laugh","layers":renderer.deskVisibilityDiagnostics])
            try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("visibility.json"))
            print("Exported visibility restoration and hidden animated poses")
            exit(0)
        }
        if arguments.contains("--toe-motion-art") {
            // Render the retained texture's local deformation with the calf fixed,
            // so toe motion and shoe attachment can be inspected independently.
            var timeline: [[String:Any]] = []
            let detail = CGRect(x:165,y:95,width:430,height:150)
            for mode in ["bare","half-worn","reduced"] {
                let rig = try LayerRenderer(assets:CharacterAssets(directory:CharacterAssets.bundledDirectory,manifestURL:layout))
                var frame = AnimationFrame(); frame.dt = 0
                if mode != "half-worn" {
                    frame.leftShoe.phase = .falling; frame.rightShoe.phase = .falling
                    rig.render(frame)
                    frame.leftShoe.progress = 1; frame.rightShoe.progress = 1
                    rig.render(frame)
                    frame.leftShoe.phase = .grounded; frame.rightShoe.phase = .grounded
                }
                frame.reducedMotion = mode == "reduced"
                let motion = folder.appendingPathComponent(mode,isDirectory:true)
                if mode == "bare" { try FileManager.default.createDirectory(at:motion,withIntermediateDirectories:true) }
                for n in 0...240 {
                    frame.dt = n == 0 ? 0 : 1.0/30
                    rig.render(frame)
                    if mode == "bare", n % 2 == 0 {
                        try rig.savePNG(to:motion.appendingPathComponent(String(format:"%03d.png",n/2)),
                            background:NSColor(calibratedWhite:0.94,alpha:1),region:detail,scale:2)
                    }
                    if [0,60,120,180,240].contains(n) {
                        try rig.savePNG(to:folder.appendingPathComponent("\(mode)-\(n).png"),region:detail,scale:3)
                    }
                    var entry: [String:Any] = ["mode":mode,"time":Double(n)/30,"toes":rig.toeMotionDiagnostics,"shoes":rig.shoeDiagnostics]
                    for id in ["leg_back","leg_front"] {
                        if let contact = rig.spriteContact(id) { entry[id+"Contact"] = [contact.x,contact.y] }
                    }
                    timeline.append(entry)
                }
            }
            try JSONSerialization.data(withJSONObject:timeline,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("toe-motion-poses.json"))
            print("Exported independent toe artwork with fixed calf and shoe contacts")
            exit(0)
        }
        if arguments.contains("--friend-motion-art") || arguments.contains("--friend-motion-stills") {
            // Arranged artwork poses expose breathing, both expression patches and
            // the existing assisted-shoe contact. No input or behavior checks run.
            var timeline: [[String:Any]] = []
            let stills = arguments.contains("--friend-motion-stills")
            for mode in ["normal","reduced","assistance"] {
                let rig = try LayerRenderer(assets:CharacterAssets(directory:CharacterAssets.bundledDirectory,manifestURL:layout))
                let engine = AnimationEngine(now:0,expressionSeed:42)
                let motion = folder.appendingPathComponent(mode,isDirectory:true)
                if !stills { try FileManager.default.createDirectory(at:motion,withIntermediateDirectories:true) }
                for n in 0..<180 {
                    let time = Double(n)/30
                    var frame = engine.tick(now:time,reducedMotion:mode == "reduced")
                    if (45..<75).contains(n) { frame.friendExpression = .hearts; frame.friendExpressionOpacity = 1 }
                    if (100..<140).contains(n) { frame.friendExpression = .effort; frame.friendExpressionOpacity = 1 }
                    if mode == "assistance" {
                        frame.leftShoe.phase = .recovering; frame.leftShoe.recovery = .friendAssist
                        frame.leftShoe.progress = Double(n)/179
                    }
                    rig.render(frame)
                    if !stills {
                        try rig.savePNG(to:motion.appendingPathComponent(String(format:"%03d.png",n)),
                                        background:NSColor(calibratedWhite:0.94,alpha:1),region:CGRect(x:120,y:70,width:390,height:400),scale:1.5)
                    }
                    let selected = mode == "assistance" ? [0,90,179] : [0,55,111]
                    if selected.contains(n) {
                        try rig.savePNG(to:folder.appendingPathComponent("\(mode)-\(n).png"))
                    }
                    timeline.append(["mode":mode,"time":time,"breath":frame.friendBreath,
                                     "tremble":[frame.friendTrembleX,frame.friendTrembleY],
                                     "contacts":rig.friendMotionDiagnostics,"shoes":rig.shoeDiagnostics,
                                     "cloth":rig.clothDiagnostics])
                }
            }
            try JSONSerialization.data(withJSONObject:timeline,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("friend-motion-poses.json"))
            print("Exported normal, reduced and assistance artwork; no behavior checks run")
            exit(0)
        }
        if arguments.contains("--toe-hook-art") {
            // Compact choreography artwork: each leg keeps its own shoe state.
            // This export performs no behavior checks or input simulation.
            var timeline: [[String:Any]] = []
            for side in [ShoeSide.left,.right] {
                let rig = try LayerRenderer(assets: CharacterAssets(directory:CharacterAssets.bundledDirectory,manifestURL:layout))
                var frame = AnimationFrame()
                for _ in 0..<24 { rig.render(frame) }
                func setShoe(_ shoe: ShoeFrame) {
                    if side == .left { frame.leftShoe = shoe } else { frame.rightShoe = shoe }
                }
                var shoe = ShoeFrame(); shoe.phase = .falling
                setShoe(shoe); rig.render(frame)
                shoe.progress = 1; setShoe(shoe); rig.render(frame)
                shoe.phase = .grounded; setShoe(shoe); rig.render(frame)
                try rig.savePNG(to:folder.appendingPathComponent("\(side.rawValue)-grounded.png"))
                for progress in [0.0,0.16,0.26,0.36,0.44,0.56,0.66,0.76,0.90,1.0] {
                    shoe.phase = .recovering; shoe.recovery = .toeHook; shoe.progress = progress
                    setShoe(shoe); rig.render(frame)
                    let filename = "\(side.rawValue)-\(Int((progress*100).rounded()))-\(shoe.toeHookPose.stage).png"
                    try rig.savePNG(to:folder.appendingPathComponent(filename),region:CGRect(x:110,y:40,width:590,height:420),scale:1.5)
                    timeline.append(["side":side.rawValue,"progress":progress,"stage":shoe.toeHookPose.stage,"image":filename,
                        "shoes":rig.shoeDiagnostics,"recoveryBackingCornerError":rig.motionSeamDiagnostics["recoveryBackingCornerError"] ?? [:]])
                }
                shoe = ShoeFrame(); setShoe(shoe); rig.render(frame)
                try rig.savePNG(to:folder.appendingPathComponent("\(side.rawValue)-returned.png"),region:CGRect(x:110,y:40,width:590,height:420),scale:1.5)
            }
            try JSONSerialization.data(withJSONObject:timeline,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("toe-hook-poses.json"))
            print("Exported toe-hook choreography artwork; no behavior checks run")
            exit(0)
        }
        if arguments.contains("--laugh-art") || arguments.contains("--laugh-stills") {
            let engine = AnimationEngine(now:0,expressionSeed:42)
            _ = engine.startLaugh(now:0)
            let motion = folder.appendingPathComponent("motion",isDirectory:true)
            let stills = arguments.contains("--laugh-stills")
            if !stills { try FileManager.default.createDirectory(at:motion,withIntermediateDirectories:true) }
            for n in 0...120 {
                let frame = engine.tick(now:Double(n)/20)
                renderer.render(frame)
                if !stills { try renderer.savePNG(to:motion.appendingPathComponent(String(format:"%03d.png",n)),background:NSColor(calibratedWhite:0.94,alpha:1),scale:0.625) }
                if [0,4,10,23,36,51,73,99,112,120].contains(n) {
                    try renderer.savePNG(to:folder.appendingPathComponent("laugh-\(n).png"))
                }
                if n == 23 {
                    try renderer.savePNG(to:folder.appendingPathComponent("laugh-face.png"),region:CGRect(x:275,y:625,width:195,height:165),scale:3)
                    try renderer.savePNG(to:folder.appendingPathComponent("laugh-arms.png"),region:CGRect(x:250,y:445,width:280,height:200),scale:2)
                    try renderer.savePNG(to:folder.appendingPathComponent("friend-effort.png"),region:CGRect(x:300,y:315,width:155,height:145),scale:3)
                }
            }
            print("Exported laughter animation artwork; no behavior checks run")
            exit(0)
        }
        if arguments.contains("--hand-art") {
            // Production artwork at rest and at representative physical keys.
            // This export deliberately performs no behavior assertions or input injection.
            let region = CGRect(x:70,y:360,width:360,height:290)
            for _ in 0..<60 { renderer.render(AnimationFrame()) }
            try renderer.savePNG(to:folder.appendingPathComponent("idle.png"))
            try renderer.savePNG(to:folder.appendingPathComponent("idle-hand.png"),region:region,scale:2)
            for code: UInt16 in [0,1,2,3,38,40,37,36,49,53,51] {
                guard let key = KeyboardLayout.byCode[code] else { continue }
                for pressure in [0.0,0.5,1.0] {
                    var frame = AnimationFrame(); frame.state = .typing; frame.keyboardActive = true
                    frame.leftAim = code; frame.keyPressures = [code:pressure]
                    frame.fingerPressures = [key.finger:pressure]; frame.fingerKeys = [key.finger:code]
                    for _ in 0..<60 { renderer.render(frame) }
                    try renderer.savePNG(to:folder.appendingPathComponent("key-\(code)-\(Int(pressure*100)).png"),region:region,scale:2)
                }
            }
            print("Exported keyboard hand artwork; no behavior checks run")
            exit(0)
        }
        if arguments.contains("--expression-art") {
            // A fixed head crop keeps the original face and expression registration comparable.
            // Export artwork only; do not advance input simulation or run behavior checks.
            let region = CGRect(x:275,y:605,width:195,height:180)
            let neutral = AnimationFrame()
            var half = neutral; half.leftShoe.phase = .recovering
            half.leftShoe.recovery = .friendAssist; half.leftShoe.progress = 0.035
            var assisted = half; assisted.leftShoe.progress = 0.5
            var blink = assisted; blink.blink = 1
            for (name,frame) in [("neutral",neutral),("transition",half),("assisted",assisted),("blink",blink)] {
                renderer.render(frame)
                try renderer.savePNG(to:folder.appendingPathComponent(name+"-face.png"),region:region,scale:4)
            }
            print("Exported fixed-position expression artwork; no behavior checks run")
            exit(0)
        }
        let scenarios: [(String, AnimationFrame)] = {
            var typing = AnimationFrame(); typing.state = .typing; typing.leftHandX = 4.5; typing.leftHandY = 22; typing.keyboardY = -1; typing.keyGlow = 0.7
            typing.keyboardActive = true; typing.keyPressures = [38:1]
            typing.fingerPressures = [.leftIndex:1]; typing.fingerKeys = [.leftIndex:38]
            typing.leftAim = 38
            var typingMouse = typing; typingMouse.mouseX = 20; typingMouse.mouseY = 8
            var mouse = AnimationFrame(); mouse.state = .mouseMove; mouse.mouseX = 32; mouse.mouseY = 12
            var mouseLeft = mouse; mouseLeft.mouseX = -32; mouseLeft.mouseY = -22
            var mouseLeftFront = mouse; mouseLeftFront.mouseX = -32
            var click = mouse; click.state = .click; click.mousePress = 1
            var blink = AnimationFrame(); blink.blink = 1
            var sleep = blink; sleep.state = .sleep
            var breathe = AnimationFrame(); breathe.breath = 1.65
            var effort = AnimationFrame(); effort.friendExpression = .effort; effort.friendExpressionOpacity = 1
            var hearts = effort; hearts.friendExpression = .hearts
            var legs = AnimationFrame(); legs.leftLegSwing = -0.36; legs.rightLegSwing = -0.32
            var legsBack = legs; legsBack.leftLegSwing *= -1; legsBack.rightLegSwing *= -1
            var combined = legs; combined.leftLegSideSwing = 0.065; combined.rightLegSideSwing = -0.055
            var opposite = legsBack; opposite.leftLegSideSwing = -0.065; opposite.rightLegSideSwing = 0.055
            return [("idle", AnimationFrame()), ("typing", typing), ("typing-and-mouse", typingMouse), ("mouse-move", mouse), ("mouse-left", mouseLeft), ("mouse-left-front", mouseLeftFront), ("click", click), ("blink", blink), ("sleep", sleep), ("breathing", breathe), ("friend-effort",effort), ("friend-hearts",hearts), ("legs-forward",legs), ("legs-back",legsBack), ("legs-combined",combined), ("legs-opposite",opposite)]
        }()
        for (name, frame) in scenarios {
            for _ in 0..<24 { renderer.render(frame) }
            try renderer.savePNG(to: folder.appendingPathComponent("\(name).png"))
            if ["idle","friend-effort","friend-hearts"].contains(name) {
                try renderer.savePNG(to:folder.appendingPathComponent("\(name)-face-detail.png"),region:CGRect(x:300,y:315,width:155,height:145),scale:5)
            }
            if name == "idle" {
                try renderer.savePNG(to:folder.appendingPathComponent("desk-preview.png"),background:NSColor(calibratedWhite:0.96,alpha:1))
                try renderer.savePNG(to:folder.appendingPathComponent("desk-detail.png"),background:NSColor(calibratedWhite:0.96,alpha:1),region:CGRect(x:155,y:405,width:540,height:230),scale:3)
                try renderer.savePNG(to:folder.appendingPathComponent("hands-detail.png"),region:CGRect(x:230,y:405,width:370,height:150),scale:3)
            }
            if ["idle","legs-forward","legs-back"].contains(name) {
                try renderer.savePNG(to:folder.appendingPathComponent("\(name)-legs-detail.png"),region:CGRect(x:110,y:65,width:590,height:390),scale:2)
            }
        }
        if arguments.contains("--pose-stills-only") { print("Rendered \(scenarios.count) poses"); exit(0) }
        if arguments.contains("--idle-only") || arguments.contains("--shoe-art") || arguments.contains("--shoe-stills") {
            let frames = folder.appendingPathComponent("idle-motion",isDirectory:true)
            try FileManager.default.createDirectory(at:frames,withIntermediateDirectories:true)
            let engine = AnimationEngine(now:0,expressionSeed:42)
            var positions: [[String:Any]] = []
            let shoeStills = arguments.contains("--shoe-stills")
            let shoeArt = arguments.contains("--shoe-art") || shoeStills, count = shoeArt ? 570 : 180
            let fps = shoeArt ? 15.0 : 20.0
            var saved: Set<String> = []
            for n in 0..<count {
                let time = Double(n)/fps, frame = engine.tick(now:Double(n)/fps)
                renderer.render(frame)
                if !shoeStills { try renderer.savePNG(to:frames.appendingPathComponent(String(format:"%03d.png",n)),background:NSColor(calibratedWhite:0.94,alpha:1),scale:shoeArt ? 0.625 : 1) }
                var entry: [String:Any] = ["time":time,"angles":[frame.leftLegSwing,frame.rightLegSwing],"sideAngles":[frame.leftLegSideSwing,frame.rightLegSideSwing]]
                entry["shoes"] = renderer.shoeDiagnostics
                entry["recovery"] = [frame.leftShoe.recovery.rawValue,frame.rightShoe.recovery.rawValue]
                if shoeArt {
                    for (side,shoe) in [("left",frame.leftShoe),("right",frame.rightShoe)] {
                        let label = side+"-"+shoe.phase.rawValue+(shoe.phase == .recovering ? "-"+shoe.recovery.rawValue : "")
                        if shoe.progress > 0.5, saved.insert(label).inserted {
                            try renderer.savePNG(to:folder.appendingPathComponent(label+".png"))
                            if shoe.phase == .recovering {
                                try renderer.savePNG(to:folder.appendingPathComponent(label+"-face.png"),region:CGRect(x:275,y:605,width:195,height:180),scale:3)
                            }
                        }
                    }
                }
                for id in ["leg_back","leg_front"] {
                    if let point = renderer.spriteContact(id) { entry[id+"Foot"] = [point.x,point.y] }
                }
                positions.append(entry)
            }
            try JSONSerialization.data(withJSONObject:positions,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("idle-leg-positions.json"))
            print("Exported \(scenarios.count) art states and \(shoeStills ? 0 : count) idle frames; no behavior checks run")
            exit(0)
        }
        if arguments.contains("--art-only") { print("Exported \(scenarios.count) art states; no behavior checks run"); exit(0) }
        let fingerCodes: [UInt16] = [0,1,2,3,49]
        for code in fingerCodes {
            let finger = KeyboardLayout.byCode[code]!.finger
            var frame = AnimationFrame(); frame.keyboardActive = true; frame.state = .typing
            frame.keyPressures = [code:1]; frame.fingerPressures = [finger:1]; frame.fingerKeys = [finger:code]
            frame.leftAim = code
            for _ in 0..<30 { renderer.render(frame) }
            try renderer.savePNG(to: folder.appendingPathComponent("finger-\(finger.rawValue).png"))
        }
        let mouseRest = renderer.pointInCanvas("mouse_hand", normalized: CGPoint(x:0.5,y:0.3))!
        var keyContacts: [[String:Any]] = []
        for key in KeyboardLayout.keys {
            var frame = AnimationFrame(); frame.keyboardActive = true; frame.state = .typing
            frame.keyPressures = [key.code:1]; frame.fingerPressures = [key.finger:1]; frame.fingerKeys = [key.finger:key.code]
            frame.leftAim = key.code
            for _ in 0..<60 { renderer.render(frame) }
            guard let tip = renderer.fingerContact(for:key.finger), let target = renderer.keyContactInCanvas(key.code,near:tip,pressure:1) else { throw AssetError.invalid("missing key/finger contact") }
            let error = hypot(tip.x-target.x,tip.y-target.y)
            let mouseContact = renderer.pointInCanvas("mouse_hand", normalized: CGPoint(x:0.5,y:0.3))!
            let mouseError = hypot(mouseContact.x-mouseRest.x,mouseContact.y-mouseRest.y)
            let mouseSleeveVisible = (renderer.spriteIsVisible("right_arm") && renderer.spriteIsVisible("right_arm_forearm"))
                || (renderer.spriteIsVisible("reference_right_arm") && renderer.spriteIsVisible("reference_mouse"))
            let mouseVisible = renderer.spriteIsVisible("mouse_hand") && mouseSleeveVisible
            keyContacts.append(["keyCode":Int(key.code),"label":key.label,"finger":key.finger.rawValue,"tip":[tip.x,tip.y],"keyContact":[target.x,target.y],"error":error,"mouseContact":[mouseContact.x,mouseContact.y],"mousePositionError":mouseError,"mouseVisible":mouseVisible])
            if error > 0.1 { throw AssetError.invalid("finger misses key \(key.label): \(error)") }
            if !key.finger.isLeft || !mouseVisible || mouseError > 0.000001 { throw AssetError.invalid("typing changes right mouse grip: \(key.label)") }
            if [0,1,2,3,49,38,40,37,36,115].contains(key.code) {
                try renderer.savePNG(to:folder.appendingPathComponent("key-\(key.code).png"))
            }
        }
        try JSONSerialization.data(withJSONObject:keyContacts,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("key-contact-geometry.json"))
        renderer.render(AnimationFrame())
        try renderer.savePNG(to: folder.appendingPathComponent("preview.png"), background: NSColor(calibratedRed: 0.91, green: 0.92, blue: 0.93, alpha: 1))
        if arguments.contains("--stills-only") { print("Rendered \(scenarios.count) states and checked \(keyContacts.count) key contacts"); exit(0) }
        let motionFolder = folder.appendingPathComponent("motion", isDirectory: true)
        try FileManager.default.createDirectory(at: motionFolder, withIntermediateDirectories: true)
        let engine = AnimationEngine(now: 0)
        let motionCodes: [UInt16] = [0,1,2,3,38,40,37,36,49,115]
        var geometry: [[String: Any]] = []
        for n in 0..<180 {
            let now = Double(n) / 30
            if n < 100 && n % 8 == 0 {
                let code = motionCodes[(n/8) % motionCodes.count]
                engine.receive(.keyDown(time: now, isRepeat: false, keyCode: code)); engine.receive(.keyUp(time: now + 0.01, keyCode: code))
            }
            if n >= 110 && n < 165 {
                let theta = Double(n - 110) / 30 * 3
                engine.receive(.mouseMove(time: now, x: 100 * sin(theta), y: 70 * cos(theta), dx: 5 * cos(theta), dy: 4 * sin(theta)))
            }
            if n == 128 || n == 152 { engine.receive(.leftClick(time: now)) }
            let frame = engine.tick(now: now)
            renderer.render(frame)
            try renderer.savePNG(to: motionFolder.appendingPathComponent(String(format: "%03d.png", n)), background: NSColor(calibratedRed: 0.91, green: 0.92, blue: 0.93, alpha: 1))
            if let shoulder = renderer.pointInCanvas("right_arm", normalized: CGPoint(x: 0.19, y: 0.94)),
               let hand = renderer.pointInCanvas("mouse_hand", normalized: CGPoint(x: 0.18, y: 0.67)) {
                geometry.append(["frame": n, "shoulder": [shoulder.x, shoulder.y], "hand": [hand.x, hand.y], "mouseOffset": [frame.mouseX, frame.mouseY], "press": frame.mousePress, "breath": frame.breath])
            }
        }
        try JSONSerialization.data(withJSONObject: geometry, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("motion-geometry.json"))
        let idleFolder = folder.appendingPathComponent("idle-motion",isDirectory:true)
        try FileManager.default.createDirectory(at:idleFolder,withIntermediateDirectories:true)
        let idleEngine = AnimationEngine(now:0,expressionSeed:42)
        for n in 0..<360 {
            let frame = idleEngine.tick(now:Double(n)/30)
            renderer.render(frame)
            try renderer.savePNG(to:idleFolder.appendingPathComponent(String(format:"%03d.png",n)),background:NSColor(calibratedRed:0.91,green:0.92,blue:0.93,alpha:1))
        }
        print("Rendered \(scenarios.count) actual renderer states to \(folder.path)")
        exit(0)
    } catch { fputs("Render failed: \(error.localizedDescription)\n", stderr); exit(1) }
}
let delegate = AppDelegate()
application.delegate = delegate
application.run()
