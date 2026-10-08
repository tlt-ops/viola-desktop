import Foundation

public enum ShoePhase: String, Codable { case halfWorn, slipping, falling, grounded, recovering }
public enum ShoeSide: String { case left, right }
public enum ShoeRecovery: String { case toeHook, friendAssist }

/// Shared timing curves keep the reaching foot and its independent shoe in contact.
public struct ToeHookPose {
    public let reach: Double
    public let toeLift: Double
    public let straighten: Double
    public let forward: Double
    public let returnToRest: Double
    public let stage: String
    init(progress: Double) {
        func ease(_ value: Double) -> Double {
            let p = min(1,max(0,value)); return p*p*(3-2*p)
        }
        let p = min(1,max(0,progress))
        returnToRest = ease((p-0.80)/0.20)
        reach = ease(p/0.26)*(1-returnToRest)
        toeLift = ease((p-0.30)/0.14)*(1-returnToRest)
        straighten = ease((p-0.44)/0.16)*(1-returnToRest)
        forward = ease((p-0.60)/0.16)*(1-returnToRest)
        stage = p < 0.26 ? "insert" : p < 0.30 ? "seated" : p < 0.44 ? "toeLift" : p < 0.60 ? "straighten" : p < 0.80 ? "forward" : "return"
    }
}

public struct ShoeFrame {
    public var phase: ShoePhase = .halfWorn
    public var progress = 0.0
    public var wobble = 0.0
    public var recovery: ShoeRecovery = .toeHook
    public var toeHookPose: ToeHookPose { ToeHookPose(progress: progress) }
    public init() {}
}

/// Timing is independent for each shoe; renderer geometry supplies its floor and foot.
final class ShoeMotion {
    private struct State {
        var phase: ShoePhase = .halfWorn
        var started = 0.0
        var due: Double
        var hold = 3.0
        var recovery: ShoeRecovery = .toeHook
    }
    private var states: [State]
    private var seed: UInt64
    private var lastTick: Double
    var isRecovering: Bool { states.contains { $0.phase == .recovering } }
    init(now: Double, seed: UInt64) {
        lastTick = now
        self.seed = seed
        states = [State(due: now + 11, recovery: .friendAssist), State(due: now + 19)]
        states[0].due += random() * 4
        states[1].due += random() * 5
    }
    private func random() -> Double {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Double((seed >> 32) % 10000) / 10000
    }
    @discardableResult
    func recover(_ side: ShoeSide, now: Double) -> Bool {
        let index = side == .left ? 0 : 1
        guard states[index].phase == .grounded else { return false }
        // A direct shoe click asks Viola to hook it herself. Scheduled recoveries
        // still retain their independently selected friend-assisted style.
        states[index].recovery = .toeHook
        states[index].phase = .recovering; states[index].started = now
        return true
    }
    func tick(now: Double, mayDrop: Bool, swings: [Double], motion: Double, allowRecovery: Bool = true) -> [ShoeFrame] {
        let elapsed = max(0,now-lastTick); lastTick = now
        var result: [ShoeFrame] = []
        for index in states.indices {
            var s = states[index]
            // Falling shoes still land, but the friend keeps both hands supporting
            // her body during laughter. Grounded shoes wait for the action to end.
            if !allowRecovery && s.phase == .grounded { s.started += elapsed }
            if s.phase == .halfWorn, mayDrop, now >= s.due, abs(swings[index]) > 0.16 {
                s.phase = .slipping; s.started = now; s.hold = 6 + random() * 3
            }
            let duration: Double
            switch s.phase {
            case .halfWorn: duration = .infinity
            case .slipping: duration = 0.85
            case .falling: duration = 1.1
            case .grounded: duration = s.hold
            case .recovering: duration = 3.4
            }
            if now - s.started >= duration {
                switch s.phase {
                case .slipping: s.phase = .falling
                case .falling: s.phase = .grounded
                case .grounded:
                    if states.indices.contains(where: { $0 != index && states[$0].phase == .recovering && states[$0].recovery == .friendAssist }) { s.recovery = .toeHook }
                    s.phase = .recovering
                case .recovering:
                    s.phase = .halfWorn; s.due = now + 23 + random() * 22
                    s.recovery = random() < 0.5 ? .friendAssist : .toeHook
                case .halfWorn: break
                }
                s.started = now
            }
            let currentDuration: Double
            switch s.phase {
            case .halfWorn: currentDuration = .infinity
            case .slipping: currentDuration = 0.85
            case .falling: currentDuration = 1.1
            case .grounded: currentDuration = s.hold
            case .recovering: currentDuration = 3.4
            }
            var frame = ShoeFrame(); frame.phase = s.phase
            frame.progress = min(1, max(0, (now - s.started) / currentDuration))
            frame.wobble = (sin(now * 2.7 + Double(index) * 2.1) * 0.025 + swings[index] * 0.16) * motion
            frame.recovery = s.recovery
            result.append(frame); states[index] = s
        }
        return result
    }
}
