import Foundation

/// Two alternating hand strokes for a concealed keyboard. Physical key
/// positions never enter this driver; only the timing of real keyDown events does.
final class TypingMotion {
    private struct Stroke {
        let time: Double
        let left: Bool
    }
    private var strokes: [Stroke] = []
    private var nextLeft = true
    private var nextHeldStroke = Double.infinity
    private static let duration = 0.22
    private static let cadence = 0.18

    func receive(_ event: InputEvent) {
        guard case .keyDown(let time, _, _) = event else { return }
        append(at: time)
        // Real autorepeat pulses refresh the cadence instead of doubling it.
        nextHeldStroke = time + Self.cadence
    }

    func reset() {
        strokes.removeAll(); nextLeft = true; nextHeldStroke = .infinity
    }

    func tick(now: Double, held: Bool, reducedMotion: Bool) -> (left: Double, right: Double, active: Bool) {
        if held, nextHeldStroke.isFinite, now >= nextHeldStroke {
            // Skip invisible historical strokes after suspension. Keep the side
            // alternation and the current short stroke, without a catch-up burst.
            let skipped = max(0, Int(floor((now - nextHeldStroke) / Self.cadence)) - 1)
            if skipped % 2 == 1 { nextLeft.toggle() }
            nextHeldStroke += Double(skipped) * Self.cadence
            while nextHeldStroke <= now {
                append(at: nextHeldStroke)
                nextHeldStroke += Self.cadence
            }
        } else if !held {
            nextHeldStroke = .infinity
        }
        strokes.removeAll { now - $0.time >= Self.duration }
        var left = 0.0, right = 0.0
        for stroke in strokes {
            let age = now - stroke.time
            guard age >= 0, age < Self.duration else { continue }
            // A quick depression and slower release give a single tap a clear,
            // bounded response, without starting a free-running typing cycle.
            let attack = min(1, age / 0.035)
            let release = max(0, (Self.duration - age) / (Self.duration - 0.035))
            let value = smooth(attack) * smooth(release)
            if stroke.left { left = max(left, value) } else { right = max(right, value) }
        }
        let amount = reducedMotion ? 0.35 : 1.0
        return (left * amount, right * amount, held || left > 0 || right > 0)
    }

    private func append(at time: Double) {
        strokes.removeAll { time - $0.time >= Self.duration }
        strokes.append(Stroke(time: time, left: nextLeft)); nextLeft.toggle()
    }
    private func smooth(_ value: Double) -> Double { value * value * (3 - 2 * value) }
}
