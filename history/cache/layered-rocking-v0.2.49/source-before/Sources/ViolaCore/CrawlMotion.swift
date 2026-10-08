import Foundation

/// Offsets use the renderer's 800 × 960 canvas; positive Y lifts a contact.
public struct CrawlFrame {
    public var active = false
    public var weight = 0.0
    public var phase = 0.0
    public var direction = 1.0
    public var distance = 0.0
    public var deltaX = 0.0
    public var bodyX = 0.0
    public var bodyY = 0.0
    public var bodyRoll = 0.0
    public var riderBounce = 0.0
    public var backHandX = 0.0
    public var backHandY = 0.0
    public var frontHandX = 0.0
    public var frontHandY = 0.0
    public var backKneeX = 0.0
    public var backKneeY = 0.0
    public var frontKneeX = 0.0
    public var frontKneeY = 0.0
    public init() {}
}

/// A bounded repeating gait. Position is integrated analytically, independently
/// of the engine's capped drawing delta, so skipped frames cannot lose travel.
public final class CrawlMotion {
    public static let cycleDuration = 0.72
    public static let settlementDuration = 0.208
    private static let entryDuration = 0.14
    private static let exitDuration = 0.18
    private static let speed = 55.0
    public static let maximumTravel = 1496.0
    // Preserve the current stride and travel while halving crawl speed again.
    public static let duration = maximumTravel / speed + (entryDuration + exitDuration) / 2
    public private(set) var isActive = false
    private var started = 0.0
    private var lastSample = 0.0
    private var direction = 1.0
    private var distance = 0.0
    private var emittedDistance = 0.0
    private var reduced = false
    private var stopStarted: Double?
    private var stopPose = CrawlFrame()

    public init() {}

    @discardableResult
    public func start(now: Double, direction: Double) -> Bool {
        guard now.isFinite, direction.isFinite, !isActive else { return false }
        started = now; lastSample = now; self.direction = direction < 0 ? -1 : 1
        distance = 0; emittedDistance = 0; reduced = false; stopStarted = nil
        isActive = true
        return true
    }

    public func stop(now: Double, immediate: Bool = false) {
        guard isActive, now.isFinite else { return }
        if stopStarted != nil {
            if immediate { isActive = false; emittedDistance = distance }
            return
        }
        let time = max(lastSample, now)
        accumulate(to: time, reducedMotion: reduced)
        stopPose = pose(age: time - started, reducedMotion: false)
        stopStarted = time
        // A direct drag/reposition supersedes any travel not yet drawn.
        if immediate { isActive = false; emittedDistance = distance }
    }

    public func tick(now: Double, reducedMotion: Bool = false) -> CrawlFrame {
        guard now.isFinite else { return CrawlFrame() }
        let time = max(lastSample, now)
        if isActive { accumulate(to: time, reducedMotion: reducedMotion) }
        reduced = reducedMotion
        var result = CrawlFrame()
        if isActive, let stopped = stopStarted {
            result = stopPose
            let fade = 1 - Self.ease((time - stopped) / Self.settlementDuration)
            scalePose(&result, by: fade)
            if reducedMotion { scaleOffsets(&result, by: 0.12) }
            if time - stopped >= Self.settlementDuration { isActive = false }
        } else if isActive {
            result = pose(age: time - started, reducedMotion: reducedMotion)
            if time - started >= Self.duration { isActive = false }
        }
        result.active = isActive
        result.direction = direction
        result.distance = distance
        result.deltaX = (distance - emittedDistance) * direction
        emittedDistance = distance
        return result
    }

    private func accumulate(to now: Double, reducedMotion: Bool) {
        let end = min(now, stopStarted ?? now)
        if !reducedMotion, end > lastSample {
            distance += Self.speed * (Self.travelIntegral(end - started) - Self.travelIntegral(lastSample - started))
            distance = max(0, min(Self.maximumTravel, distance))
        }
        lastSample = now
    }

    private static func ease(_ value: Double) -> Double {
        let x = max(0, min(1, value)); return x*x*(3-2*x)
    }

    private static func easeIntegral(_ x: Double) -> Double { x*x*x - x*x*x*x/2 }

    private static func travelIntegral(_ age: Double) -> Double {
        let t = max(0, min(duration, age))
        if t < entryDuration { return entryDuration * easeIntegral(t / entryDuration) }
        let exitStart = duration - exitDuration
        if t <= exitStart { return t - entryDuration / 2 }
        let x = (t - exitStart) / exitDuration
        return exitStart - entryDuration / 2 + exitDuration * (x - easeIntegral(x))
    }

    private func pose(age: Double, reducedMotion: Bool) -> CrawlFrame {
        let age = max(0, min(Self.duration, age))
        var result = CrawlFrame()
        result.active = true
        result.weight = Self.ease(age / Self.entryDuration) * Self.ease((Self.duration - age) / Self.exitDuration)
        result.phase = age / Self.cycleDuration
        let amplitude = result.weight * (reducedMotion ? 0.12 : 1)
        let angle = result.phase * 2 * Double.pi
        result.bodyX = sin(angle) * 2.25 * amplitude * direction
        result.bodyY = sin(angle * 2) * 3.15 * amplitude
        result.bodyRoll = sin(angle) * 0.027 * amplitude * direction
        result.riderBounce = sin(angle * 2 - 0.3) * 1.5 * amplitude
        // In stance, hand X cancels forward motion. The shorter raised swing
        // returns the hand ahead; diagonally opposite knees alternate with it.
        // Enlarge the visible lifts and knee excursion without changing the
        // palm's stance stride, which remains tied to travel to avoid skating.
        let back = contact(phase: result.phase, stride: Self.speed * Self.cycleDuration * 0.65, lift: 21)
        let front = contact(phase: result.phase + 0.5, stride: Self.speed * Self.cycleDuration * 0.65, lift: 21)
        let backKnee = contact(phase: result.phase + 0.5, stride: 21, lift: 10.5)
        let frontKnee = contact(phase: result.phase, stride: 21, lift: 10.5)
        result.backHandX = back.0 * amplitude * direction; result.backHandY = back.1 * amplitude
        result.frontHandX = front.0 * amplitude * direction; result.frontHandY = front.1 * amplitude
        result.backKneeX = backKnee.0 * amplitude * direction; result.backKneeY = backKnee.1 * amplitude
        result.frontKneeX = frontKnee.0 * amplitude * direction; result.frontKneeY = frontKnee.1 * amplitude
        return result
    }

    private func contact(phase: Double, stride: Double, lift: Double) -> (Double, Double) {
        let p = phase - floor(phase), stance = 0.65
        if p <= stance { return (stride * (0.5 - p / stance), 0) }
        let swing = (p - stance) / (1 - stance)
        return (stride * (Self.ease(swing) - 0.5), lift * pow(sin(swing * .pi), 2))
    }

    private func scalePose(_ frame: inout CrawlFrame, by amount: Double) {
        frame.weight *= amount
        scaleOffsets(&frame, by: amount)
    }

    private func scaleOffsets(_ frame: inout CrawlFrame, by amount: Double) {
        frame.bodyX *= amount; frame.bodyY *= amount; frame.bodyRoll *= amount; frame.riderBounce *= amount
        frame.backHandX *= amount; frame.backHandY *= amount; frame.frontHandX *= amount; frame.frontHandY *= amount
        frame.backKneeX *= amount; frame.backKneeY *= amount; frame.frontKneeX *= amount; frame.frontKneeY *= amount
    }
}
