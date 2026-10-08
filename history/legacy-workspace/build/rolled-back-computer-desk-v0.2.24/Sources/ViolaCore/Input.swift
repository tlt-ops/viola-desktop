import Foundation

public enum InputEvent: Equatable {
    case keyDown(time: Double, isRepeat: Bool, keyCode: UInt16? = nil)
    case keyUp(time: Double, keyCode: UInt16? = nil)
    case mouseMove(time: Double, x: Double, y: Double, dx: Double, dy: Double)
    case leftClick(time: Double)
    case rightClick(time: Double)

    public var time: Double {
        switch self {
        case .keyDown(let t, _, _), .keyUp(let t, _), .mouseMove(let t, _, _, _, _), .leftClick(let t), .rightClick(let t): return t
        }
    }
}

public enum SemanticEvent: String { case typingStart = "TYPING_START", typingStop = "TYPING_STOP", wake = "WAKE" }

/// Physical codes stay in memory for finger/keycap animation. No characters or text.
public final class InputActivity {
    public private(set) var lastActivity: Double
    public private(set) var lastKey: Double = -.infinity
    public private(set) var lastMouse: Double = -.infinity
    public private(set) var lastClick: Double = -.infinity
    public private(set) var clickIsRight = false
    public private(set) var keyPulses: [Double] = []
    public private(set) var keysHeld = 0
    private var anonymousHeld = 0
    public private(set) var heldCodes: Set<UInt16> = []
    public private(set) var keyTimes: [UInt16: Double] = [:]
    public private(set) var isTyping = false
    public private(set) var mouseDX = 0.0
    public private(set) var mouseDY = 0.0
    public private(set) var mouseX = 0.0
    public private(set) var mouseY = 0.0
    public var typingStopDelay = 0.45
    public var sleepDelay = 60.0
    public var onSemanticEvent: ((SemanticEvent) -> Void)?

    public init(now: Double) { lastActivity = now }
    public func receive(_ event: InputEvent) {
        if case .mouseMove(_, _, _, let dx, let dy) = event, abs(dx) + abs(dy) <= 0.01 { return }
        if event.time - lastActivity >= sleepDelay { onSemanticEvent?(.wake) }
        lastActivity = max(lastActivity, event.time)
        switch event {
        case .keyDown(let t, let repeatKey, let code):
            lastKey = t
            keyPulses.append(t)
            if let code { heldCodes.insert(code); keyTimes[code] = t }
            else if !repeatKey { anonymousHeld += 1 }
            keysHeld = heldCodes.count + anonymousHeld
            if !isTyping { isTyping = true; onSemanticEvent?(.typingStart) }
        case .keyUp(let t, let code):
            if let code { heldCodes.remove(code); if keyTimes[code] != nil { keyTimes[code] = t } }
            else { anonymousHeld = max(0, anonymousHeld - 1) }
            keysHeld = heldCodes.count + anonymousHeld
        case .mouseMove(let t, let x, let y, let dx, let dy):
            // Ignore stationary notifications, otherwise sleep would never begin.
            guard abs(dx) + abs(dy) > 0.01 else { return }
            lastMouse = t; mouseX = x; mouseY = y
            mouseDX = max(-28, min(28, dx)); mouseDY = max(-28, min(28, dy))
        case .leftClick(let t): lastClick = t; clickIsRight = false
        case .rightClick(let t): lastClick = t; clickIsRight = true
        }
        prune(now: event.time)
    }
    public func update(now: Double) {
        prune(now: now)
        if isTyping && now - lastKey > typingStopDelay {
            isTyping = false; onSemanticEvent?(.typingStop)
        }
    }
    public func frequency(now: Double) -> Double {
        Double(keyPulses.filter { now - $0 < 2 && now >= $0 }.count) / 2
    }
    public func keyPressures(now: Double) -> [UInt16: Double] {
        var result: [UInt16: Double] = [:]
        for (code, time) in keyTimes {
            let age = now - time
            if heldCodes.contains(code) { result[code] = 1 }
            else if age >= 0 && age < 0.24 { result[code] = exp(-age * 12) }
        }
        return result
    }
    public func idleTime(now: Double) -> Double { max(0, now - lastActivity) }
    public func reset(now: Double) {
        lastActivity = now; lastKey = -.infinity; lastMouse = -.infinity; lastClick = -.infinity
        keyPulses.removeAll(); keysHeld = 0; anonymousHeld = 0; isTyping = false; mouseDX = 0; mouseDY = 0
        heldCodes.removeAll(); keyTimes.removeAll()
    }
    private func prune(now: Double) {
        keyPulses.removeAll { now - $0 > 2 }
        keyTimes = keyTimes.filter { heldCodes.contains($0.key) || now - $0.value < 0.25 }
    }
}
