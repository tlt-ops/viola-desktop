import Foundation

/// Chooses current frames without turning timer jitter into an extra skipped tick.
/// Slow modes retain a fixed phase; late callbacks consume missed slots in one step.
public struct FrameCadence {
    private var state: MotionState?
    private var framesPerSecond: Double?
    private var nextDeadline: Double?
    // The 60 Hz driver supplies the nearest available tick to a slow-mode deadline.
    private let earlyTolerance = 0.5 / 60.0

    public init() {}

    public mutating func reset() {
        state = nil
        framesPerSecond = nil
        nextDeadline = nil
    }

    public mutating func shouldDraw(now: Double, state: MotionState, framesPerSecond: Double,
                                   isTimerTick: Bool) -> Bool {
        guard now.isFinite, framesPerSecond.isFinite, framesPerSecond > 0 else { return false }
        let interval = 1 / framesPerSecond
        if self.state != state || self.framesPerSecond != framesPerSecond || nextDeadline == nil {
            self.state = state
            self.framesPerSecond = framesPerSecond
            nextDeadline = now + interval
            return true
        }
        // Explicit interactions need immediate feedback without changing the timer's phase.
        if !isTimerTick || framesPerSecond >= 60 { return true }
        guard let deadline = nextDeadline, now + earlyTolerance + 1e-9 >= deadline else { return false }
        let elapsedSlots = floor(max(0, now + earlyTolerance - deadline) / interval) + 1
        nextDeadline = deadline + elapsedSlots * interval
        return true
    }
}
