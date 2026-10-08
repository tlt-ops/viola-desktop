import Foundation

public enum MotionState: String, Codable { case idle = "Idle", typing = "Typing", mouseMove = "Mouse_Move", click = "Click", sleep = "Sleep", wake = "Wake", laugh = "Laugh" }
public enum LaughTrigger: String { case click, idle }
public enum FriendExpression: String, Codable { case neutral, effort, hearts }

public struct AnimationFrame {
    public var state: MotionState = .idle
    public var breath = 0.0
    public var headTilt = 0.0
    public var hairSway = 0.0
    public var leftHandX = 0.0
    public var leftHandY = 0.0
    public var leftHandAngle = 0.0
    public var keyboardY = 0.0
    public var keyGlow = 0.0
    public var mouseX = 0.0
    public var mouseY = 0.0
    public var mousePress = 0.0
    public var blink = 0.0
    public var smile = 0.0
    public var friendBreath = 0.0
    /// Small support-body offsets at shoulder height; palms remain planted in the renderer.
    public var friendTrembleX = 0.0
    public var friendTrembleY = 0.0
    public var laugh = 0.0
    public var laughAge = 0.0
    public var laughTrigger: LaughTrigger?
    public var laughBounce = 0.0
    public var supportSway = 0.0
    public var supportDip = 0.0
    /// Fore/aft knee flexion in radians; the renderer projects depth toward the viewer.
    public var leftLegSwing = 0.0
    public var rightLegSwing = 0.0
    public var leftLegSideSwing = 0.0
    public var rightLegSideSwing = 0.0
    public var leftShoe = ShoeFrame()
    public var rightShoe = ShoeFrame()
    public var friendExpression: FriendExpression = .neutral
    public var friendExpressionOpacity = 0.0
    public var keyPressures: [UInt16: Double] = [:]
    public var fingerPressures: [TypingFinger: Double] = [:]
    public var keyboardActive = false
    /// Normalized alternating hand strokes on the concealed keyboard.
    /// Both hands react to input timing, independently of physical key positions.
    public var typingLeft = 0.0
    public var typingRight = 0.0
    public var typingActive = false
    public var fingerKeys: [TypingFinger: UInt16] = [:]
    public var leftAim: UInt16?
    public var dt = 1.0 / 60
    /// Actual time since the preceding drawing when native idle frames are skipped.
    public var renderInterval: Double?
    public var reducedMotion = false
    public init() {}
}

/// Renderer-independent transform driver. A future Live2D adapter can consume this frame.
public final class AnimationEngine {
    public let activity: InputActivity
    private var lastTime: Double
    private var nextBlink: Double
    private var blinkStarted = -Double.infinity
    private var wakeStarted = -Double.infinity
    private var mouseX = 0.0
    private var mouseY = 0.0
    private var mouseTargetX = 0.0
    private var mouseTargetY = 0.0
    private var phase = 0.0
    private let typingMotion = TypingMotion()
    private var seed: UInt64 = 0x56494F4C41
    private var expressionSeed: UInt64
    private var nextExpression: Double
    private var expressionStarted = -Double.infinity
    private var expressionDuration = 3.0
    private var expression: FriendExpression = .neutral
    private var idleBlend = 0.0
    private var shoes: ShoeMotion
    public static let laughDuration = 5.6
    public static let laughIdleDelay = 45.0
    public static let laughIdleCooldown = 90.0
    private var laughStarted = -Double.infinity
    private var laughEnded = -Double.infinity
    private var laughSource: LaughTrigger = .click
    private var queuedLaugh = false
    private var queuedShoes: [ShoeSide] = []
    private var lastFootwear: [ShoeFrame] = [ShoeFrame(), ShoeFrame()]
    public init(now: Double, expressionSeed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        shoes = ShoeMotion(now: now, seed: expressionSeed ^ 0x53484F45)
        self.expressionSeed = expressionSeed; nextExpression = now + 8
        activity = InputActivity(now: now); lastTime = now; nextBlink = now + 3.8
        activity.onSemanticEvent = { [weak self] event in
            if event == .wake { self?.wakeStarted = self?.activity.lastActivity ?? 0 }
        }
    }
    public func receive(_ event: InputEvent) {
        if case .mouseMove(_, _, _, let dx, let dy) = event {
            // Viola faces the viewer: invert both axes of the user's mouse motion.
            mouseTargetX = max(-32, min(32, mouseTargetX - dx * 0.65))
            // Preserve the desk's asymmetric front/rear travel limits after inversion.
            mouseTargetY = max(-22, min(12, mouseTargetY + dy * 0.55))
        }
        let asleep = activity.idleTime(now: event.time) >= activity.sleepDelay
        activity.receive(event)
        typingMotion.receive(event)
        if asleep { wakeStarted = event.time }
    }
    @discardableResult
    public func recoverShoe(_ side: ShoeSide, now: Double) -> Bool {
        if now-laughStarted < Self.laughDuration {
            guard lastFootwear[side == .left ? 0 : 1].phase == .grounded else { return false }
            if !queuedShoes.contains(side) { queuedShoes.append(side) }
            return true
        }
        return shoes.recover(side, now: now)
    }
    /// Clicks during shoe fitting wait for the supporting girl's hands to return.
    @discardableResult
    public func startLaugh(now: Double, trigger: LaughTrigger = .click) -> Bool {
        guard now-laughStarted >= Self.laughDuration, now-laughEnded >= 0.6 else { return false }
        if shoes.isRecovering {
            if trigger == .click { queuedLaugh = true }
            return false
        }
        queuedLaugh = false; laughStarted = now; laughSource = trigger
        return true
    }
    public func reset(now: Double) {
        activity.reset(now: now); lastTime = now; mouseX = 0; mouseY = 0
        typingMotion.reset()
        mouseTargetX = 0; mouseTargetY = 0; wakeStarted = -.infinity
        idleBlend = 0; expression = .neutral; expressionStarted = -.infinity; nextExpression = now + 8
        shoes = ShoeMotion(now: now, seed: expressionSeed ^ 0x53484F45)
        laughStarted = -.infinity; laughEnded = -.infinity; queuedLaugh = false; queuedShoes = []
        lastFootwear = [ShoeFrame(), ShoeFrame()]
    }
    public func tick(now: Double, reducedMotion: Bool = false) -> AnimationFrame {
        let dt = max(0, min(0.1, now - lastTime)); lastTime = now
        activity.update(now: now)
        if laughStarted.isFinite, now-laughStarted >= Self.laughDuration {
            laughEnded = laughStarted+Self.laughDuration; laughStarted = -.infinity
            nextExpression = max(nextExpression,now+8)
            for side in queuedShoes { _ = shoes.recover(side,now:now) }
            queuedShoes.removeAll()
        }
        if queuedLaugh { _ = startLaugh(now:now) }
        if activity.heldCodes.isEmpty, activity.idleTime(now:now) >= Self.laughIdleDelay,
           now-laughEnded >= Self.laughIdleCooldown {
            _ = startLaugh(now:now,trigger:.idle)
        }
        var frame = AnimationFrame()
        frame.dt = dt
        frame.reducedMotion = reducedMotion
        if activity.idleTime(now: now) >= activity.sleepDelay { frame.state = .sleep }
        else if now - activity.lastClick < 0.24 { frame.state = .click }
        else if activity.isTyping { frame.state = .typing }
        else if now - activity.lastMouse < 0.38 { frame.state = .mouseMove }
        else if now - wakeStarted < 0.75 { frame.state = .wake }
        let motion = reducedMotion ? 0.35 : 1.0
        let laughing = now-laughStarted < Self.laughDuration
        if laughing {
            let age = max(0,now-laughStarted)
            func smooth(_ value: Double) -> Double { let x = max(0,min(1,value)); return x*x*(3-2*x) }
            frame.state = .laugh; frame.laughAge = age; frame.laughTrigger = laughSource
            frame.laugh = smooth(age/0.42)*smooth((Self.laughDuration-age)/0.7)
            frame.laughBounce = (sin(age*17)*2.6+sin(age*8.5)*1.4)*frame.laugh*motion
            frame.supportSway = (sin(age*5.1)*0.055+sin(age*11.7)*0.012)*frame.laugh*motion
            frame.supportDip = -(3.5+sin(age*8.5)*2.5)*frame.laugh*motion
        }
        frame.keyPressures = activity.keyPressures(now: now)
        for (code, pressure) in frame.keyPressures {
            if let finger = KeyboardLayout.byCode[code]?.finger {
                frame.fingerPressures[finger] = max(frame.fingerPressures[finger] ?? 0, pressure)
            }
        }
        for (code, _) in activity.keyTimes.sorted(by: { $0.value < $1.value }) where frame.keyPressures[code] != nil {
            if let finger = KeyboardLayout.byCode[code]?.finger {
                frame.fingerKeys[finger] = code
                frame.leftAim = code
            }
        }
        // Keyboard and mouse can react together; typing never takes the right
        // hand away from its mouse grip.
        frame.keyboardActive = activity.isTyping || !activity.heldCodes.isEmpty
        let typing = typingMotion.tick(now: now, held: activity.keysHeld > 0, reducedMotion: reducedMotion)
        frame.typingLeft = typing.left; frame.typingRight = typing.right; frame.typingActive = typing.active
        frame.breath = sin(now * (frame.state == .sleep ? 1.4 : 1.9)) * 1.65 * motion
        // A 3.8-second breath with a gentle second harmonic gives the supporting
        // girl a slow inhale/exhale. Incommensurate waves add a subdued muscle
        // tremor without random per-frame jumps or a visibly repeated shake.
        let friendMotion = (reducedMotion ? 0.2 : 1.0) * (1-frame.laugh)
        let friendPhase = now * (2 * Double.pi / 3.8) + 1.7
        frame.friendBreath = (sin(friendPhase)*1.5 + sin(friendPhase*2-0.4)*0.15) * friendMotion
        if !reducedMotion {
            frame.friendTrembleX = (sin(now*12.7+0.8)*0.32 + sin(now*18.1+2.3)*0.18) * (1-frame.laugh)
            frame.friendTrembleY = (sin(now*14.3+1.4)*0.22 + sin(now*21.7+0.2)*0.12) * (1-frame.laugh)
        }
        let idleTarget = activity.idleTime(now: now) > 2 && activity.heldCodes.isEmpty ? 1.0 : 0.0
        idleBlend += (idleTarget-idleBlend) * (1-exp(-dt*4))
        let legAmount = idleBlend * motion * (frame.state == .sleep ? 0.4 : 1)
        frame.leftLegSwing = sin(now*1.4) * 0.36 * legAmount
        frame.rightLegSwing = sin(now*1.4+2.2) * 0.32 * legAmount
        frame.leftLegSideSwing = sin(now*0.92+0.5) * 0.065 * legAmount
        frame.rightLegSideSwing = sin(now*0.86+2.6) * 0.055 * legAmount
        if laughing {
            let a = frame.laughAge, weight = frame.laugh
            frame.leftLegSwing = frame.leftLegSwing*(1-weight)+sin(a*5.8)*0.82*weight*motion
            frame.rightLegSwing = frame.rightLegSwing*(1-weight)+sin(a*5.8+2.1)*0.76*weight*motion
            frame.leftLegSideSwing = frame.leftLegSideSwing*(1-weight)+sin(a*4.1+0.5)*0.15*weight*motion
            frame.rightLegSideSwing = frame.rightLegSideSwing*(1-weight)+sin(a*4.1+2.8)*0.14*weight*motion
        }
        let footwear = shoes.tick(now: now, mayDrop: idleBlend > 0.9 && frame.state == .idle && !reducedMotion,
                                  swings: [frame.leftLegSwing, frame.rightLegSwing], motion: motion, allowRecovery: !laughing)
        lastFootwear = footwear
        frame.leftShoe = footwear[0]; frame.rightShoe = footwear[1]
        // Hold the assisted foot steady while the friend fits its shoe.
        for index in 0..<2 where footwear[index].phase == .recovering && footwear[index].recovery == .friendAssist {
            let p = footwear[index].progress, still = min(1,min(p/0.12,(1-p)/0.12))
            if index == 0 { frame.leftLegSwing *= 1-still*0.92; frame.leftLegSideSwing *= 1-still*0.92 }
            else { frame.rightLegSwing *= 1-still*0.92; frame.rightLegSideSwing *= 1-still*0.92 }
        }
        if now >= nextExpression {
            expressionSeed = expressionSeed &* 6364136223846793005 &+ 1442695040888963407
            expression = ((expressionSeed >> 32) & 1) == 0 ? .effort : .hearts
            expressionStarted = now
            expressionDuration = 2.5 + Double((expressionSeed >> 40) % 100)/100
            nextExpression = now + expressionDuration + 10 + Double((expressionSeed >> 16) % 1000)/100
        }
        let expressionAge = now-expressionStarted
        if expressionAge >= 0 && expressionAge < expressionDuration {
            frame.friendExpression = expression
            frame.friendExpressionOpacity = min(1, min(expressionAge/0.16, (expressionDuration-expressionAge)/0.2))
        }
        if laughing {
            frame.friendExpression = .effort
            frame.friendExpressionOpacity = frame.laugh
        }
        // The initial head/torso art has a shared straight seam. Keep this seam registered.
        frame.headTilt = 0; frame.hairSway = 0
        // Every key has a visible short impulse, independent of the continuous typing cycle.
        let keyAge = max(0, now - activity.lastKey)
        let impulse = exp(-keyAge * 28)
        let speed = 3.8 + min(3.2, activity.frequency(now: now) * 0.4)
        phase += dt * speed
        let cycle = activity.isTyping ? pow(sin(phase * .pi), 2) : 0
        let recoil = keyAge < 0.28 ? pow(sin(keyAge / 0.28 * .pi), 2) : 0
        let lift = max(cycle, recoil)
        // Lift off the visible key plane, then land on it. Avoid driving fingers through keys.
        frame.leftHandY = (22 * lift - 2 * impulse) * motion
        frame.leftHandX = 4.5 * lift * motion
        frame.leftHandAngle = 0
        frame.keyboardY = -1.8 * impulse * motion
        frame.keyGlow = impulse * 0.7
        if now - activity.lastMouse >= 0.4 {
            let release = exp(-dt * 7)
            mouseTargetX *= release; mouseTargetY *= release
        }
        let smoothing = 1 - exp(-dt * 14)
        mouseX += (mouseTargetX - mouseX) * smoothing; mouseY += (mouseTargetY - mouseY) * smoothing
        frame.mouseX = mouseX * motion; frame.mouseY = mouseY * motion
        let clickAge = now - activity.lastClick
        if clickAge >= 0 && clickAge < 0.24 {
            frame.mousePress = sin(clickAge / 0.24 * .pi) * (activity.clickIsRight ? 0.8 : 1)
        }
        if now >= nextBlink {
            blinkStarted = now
            seed = seed &* 6364136223846793005 &+ 1
            nextBlink = now + 3.2 + Double((seed >> 32) % 350) / 100
        }
        let blinkAge = now - blinkStarted
        if blinkAge >= 0 && blinkAge < 0.19 { frame.blink = min(1, sin(blinkAge / 0.19 * .pi) * 1.5) }
        if frame.state == .sleep { frame.blink = 1 }
        frame.smile = frame.state == .wake ? max(0, 1 - (now - wakeStarted) / 0.75) : 0
        return frame
    }
}
