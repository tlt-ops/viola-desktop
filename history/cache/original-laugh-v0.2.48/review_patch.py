from pathlib import Path
r=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/source')
p=r/'Sources/ViolaDesktop/main.swift'; s=p.read_text()
a=s.index('        if arguments.contains("--fixed-laugh-review") {'); b=s.index('        if arguments.contains("--source-arm-return-review") {',a)
s=s[:a]+'''        if arguments.contains("--fixed-laugh-review") {
            let assets = try CharacterAssets(directory:CharacterAssets.bundledDirectory,manifestURL:layout)
            let background = NSColor(calibratedWhite:0.96,alpha:1)
            var evidence: [[String:Any]] = []
            func capture(_ rig: LayerRenderer, _ name: String) throws {
                try rig.savePNG(to:folder.appendingPathComponent(name+".png"),background:background)
                try rig.savePNG(to:folder.appendingPathComponent(name+"-rider-face.png"),background:background,
                    region:CGRect(x:220,y:730,width:195,height:135),scale:3)
                try rig.savePNG(to:folder.appendingPathComponent(name+"-friend-face.png"),background:background,
                    region:CGRect(x:170,y:360,width:200,height:140),scale:3)
                try rig.savePNG(to:folder.appendingPathComponent(name+"-belly.png"),background:background,
                    region:CGRect(x:210,y:525,width:270,height:220),scale:3)
            }
            let last = Int((FixedLaughMotion.duration+0.8)*60)
            for visible in [true,false] {
                let rig = LayerRenderer(assets:assets), mode = visible ? "desk" : "hidden"
                rig.setDesksVisible(visible)
                let engine = AnimationEngine(now:0,expressionSeed:42); engine.allowsShoeDrops = false
                guard engine.startLaugh(now:0) else { throw AssetError.invalid("original laugh did not start") }
                for n in 0...last {
                    var frame = engine.tick(now:Double(n)/60); frame.renderInterval = n == 0 ? 0 : 1.0/60
                    rig.render(frame)
                    let face = rig.sourceFaceDiagnostics, arms = rig.sourceArmDiagnostics
                    if frame.laugh > 0.9 {
                        let rider = face["riderClosure"] as? Double ?? .nan
                        let friend = face["friendClosure"] as? Double ?? .nan
                        guard rider > 0.2 && rider < 0.55, friend > 0.12 && friend < 0.42,
                              (face["friendEffort"] as? Double ?? 0) > 0.5,
                              frame.friendExpression == .effort,
                              (face["riderOpacity"] as? Double ?? 0) == 1 else {
                            throw AssetError.invalid("original laugh loses portrait/effort at \\(mode)-\\(n): \\(face)")
                        }
                    }
                    let seams = rig.motionSeamDiagnostics
                    if let offsets = seams["breathingAttachmentDeltaY"] as? [String:Double] {
                        guard offsets.values.allSatisfy({ abs($0)<0.001 }) else {
                            throw AssetError.invalid("waist/thigh separates in \\(mode)-\\(n): \\(offsets)")
                        }
                    }
                    evidence.append(["name":"\\(mode)-\\(n)","age":frame.laughAge,"laugh":frame.laugh,
                        "bounce":frame.laughBounce,"supportSway":frame.supportSway,"supportDip":frame.supportDip,
                        "leftLeg":frame.leftLegSwing,"rightLeg":frame.rightLegSwing,
                        "face":face,"arms":arms,"attachment":seams["breathingAttachmentDeltaY"] ?? [:]])
                    if n % 2 == 0 && visible {
                        try rig.savePNG(to:folder.appendingPathComponent(String(format:"clip-%03d.png",n/2)),background:background,scale:0.625)
                    }
                    if [0,6,12,18,26,45,60,90,120,168,204,240,288,300,318,330,336,360,384].contains(n) {
                        try capture(rig,"\\(mode)-phase-\\(n)")
                    }
                }
                var neutral = AnimationFrame(); neutral.dt = 1.0/60; neutral.renderInterval = 1.0/60
                for _ in 0..<120 { rig.render(neutral) }
                try capture(rig,mode+"-settled")
            }
            // Test the held original pose against simultaneous live typing and
            // mouse movement; input may resume normally as the clip exits.
            let a = LayerRenderer(assets:assets), b = LayerRenderer(assets:assets)
            let quiet = AnimationEngine(now:0,expressionSeed:42), busy = AnimationEngine(now:0,expressionSeed:42)
            quiet.allowsShoeDrops = false; busy.allowsShoeDrops = false
            _ = quiet.startLaugh(now:0); _ = busy.startLaugh(now:0)
            var isolationCount = 0
            for n in 0...last {
                let now = Double(n)/60
                if n.isMultiple(of:6) {
                    busy.receive(.keyDown(time:now,isRepeat:false,keyCode:n.isMultiple(of:12) ? 53 : 115))
                    busy.receive(.mouseMove(time:now,x:0,y:0,dx:n.isMultiple(of:12) ? 25 : -25,dy:12))
                }
                if n%6 == 2 { busy.receive(.keyUp(time:now,keyCode:(n-2).isMultiple(of:12) ? 53 : 115)) }
                var x = quiet.tick(now:now), y = busy.tick(now:now)
                x.renderInterval = 1.0/60; y.renderInterval = 1.0/60
                a.render(x); b.render(y)
                if x.laugh == 1 {
                    let left = a.sourceArmDiagnostics["arms"] as? [String:[String:Any]] ?? [:]
                    let right = b.sourceArmDiagnostics["arms"] as? [String:[String:Any]] ?? [:]
                    for id in ["reference_left_arm","reference_right_arm"] {
                        for key in ["wrist","handAngle"] {
                            let lv = try JSONSerialization.data(withJSONObject:["value":left[id]?[key] ?? NSNull()],options:[.sortedKeys])
                            let rv = try JSONSerialization.data(withJSONObject:["value":right[id]?[key] ?? NSNull()],options:[.sortedKeys])
                            guard lv == rv else { throw AssetError.invalid("input changes held original laugh \\(id)/\\(key)") }
                        }
                    }
                    guard NSDictionary(dictionary:a.sourceFaceDiagnostics).isEqual(to:b.sourceFaceDiagnostics) else {
                        throw AssetError.invalid("input changes original laugh face")
                    }
                    isolationCount += 1
                }
            }
            var edge = AnimationFrame(); edge.laugh = 1; edge.laughAge = 2; edge.blink = 1; edge.friendBlink = 1
            a.render(edge); try capture(a,"laugh-with-full-blink")
            let face = a.sourceFaceDiagnostics
            guard (face["riderClosure"] as? Double ?? 1) < 0.55,
                  (face["friendClosure"] as? Double ?? 1) < 0.42 else {
                throw AssetError.invalid("full blink overrides laugh effort eyes")
            }
            try JSONSerialization.data(withJSONObject:evidence,options:[.prettyPrinted,.sortedKeys])
                .write(to:folder.appendingPathComponent("fixed-laugh-review.json"))
            print("Original rocking laugh: \\(evidence.count) timeline stages, \\(isolationCount) held-pose input stages, waist/thigh attachment, full-blink collision and neutral return")
            exit(0)
        }
''' +s[b:]
p.write_text(s)
p=r/'Sources/ViolaDesktop/SourceReferenceFaceRig.swift'; s=p.read_text().replace('''        diagnostics = ["riderClosure":riderClosure,"friendClosure":friendClosure,''','''        diagnostics = ["riderOpacity":Double(rider.opacity),"riderClosure":riderClosure,"friendClosure":friendClosure,''');p.write_text(s)
p=r/'packaging/Info.plist'; s=p.read_text().replace('<string>0.2.47</string>','<string>0.2.48</string>').replace('<string>48</string>','<string>49</string>');p.write_text(s)
print('Original-laugh timeline and input/return verification updated.')
