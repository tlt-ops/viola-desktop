import Foundation

/// Bounded, memory-only sampling. Summaries are calculated only when diagnostics are written.
final class FramePacingDiagnostics {
    private static let capacity = 600

    private struct Samples {
        private var values: [Double] = []
        private var nextIndex = 0

        mutating func append(seconds: Double) {
            guard seconds.isFinite, seconds >= 0 else { return }
            let milliseconds = seconds * 1_000
            if values.count < FramePacingDiagnostics.capacity { values.append(milliseconds) }
            else { values[nextIndex] = milliseconds }
            nextIndex = (nextIndex + 1) % FramePacingDiagnostics.capacity
        }

        func summary(includeFrequency: Bool = true) -> [String: Any] {
            let sorted = values.sorted()
            guard !sorted.isEmpty else { return ["count": 0] }
            func percentile(_ fraction: Double) -> Double {
                sorted[max(0, Int(ceil(Double(sorted.count) * fraction)) - 1)]
            }
            let mean = sorted.reduce(0, +) / Double(sorted.count)
            var result: [String: Any] = ["count": sorted.count, "meanMs": mean,
                    "p50Ms": percentile(0.5), "p95Ms": percentile(0.95), "maxMs": sorted.last!,
                    "over25Ms": sorted.filter { $0 > 25 }.count,
                    "over40Ms": sorted.filter { $0 > 40 }.count]
            if includeFrequency { result["effectiveHz"] = mean > 0 ? 1_000 / mean : 0 }
            return result
        }
    }

    private final class StateSamples {
        var timerTickCount = 0
        var eventFrameCount = 0
        var drawCount = 0
        var timerDrawCount = 0
        var gateSkipCount = 0
        var timerGateSkipCount = 0
        var targetFPSCounts: [String: Int] = [:]
        var tickIntervals = Samples()
        var drawIntervals = Samples()
        var renderDurations = Samples()
        var movementDurations = Samples()
        var callbackDurations = Samples()

        var summary: [String: Any] {
            ["timerTickCount": timerTickCount, "eventFrameCount": eventFrameCount,
             "drawCount": drawCount, "timerDrawCount": timerDrawCount,
             "gateSkipCount": gateSkipCount, "timerGateSkipCount": timerGateSkipCount,
             "timerGateSkipFraction": timerTickCount > 0 ? Double(timerGateSkipCount) / Double(timerTickCount) : 0,
             "targetFPSCounts": targetFPSCounts,
             "tickInterval": tickIntervals.summary(),
             "drawInterval": drawIntervals.summary(),
             "renderDuration": renderDurations.summary(includeFrequency: false),
             "movementDuration": movementDurations.summary(includeFrequency: false),
             "callbackDuration": callbackDurations.summary(includeFrequency: false)]
        }
    }

    private var states: [String: StateSamples] = [:]
    private var previousTimerTick: (time: Double, state: String)?
    private var previousDraw: (time: Double, state: String)?
    private var previousFrameState: String?

    /// Reset interval anchors after a hidden/stopped timer; preserve every state's samples.
    func beginTimerRun() {
        previousTimerTick = nil
        previousDraw = nil
        previousFrameState = nil
    }

    func recordFrame(now: Double, state: String, targetFPS: Double, isTimerTick: Bool,
                     didDraw: Bool, renderDuration: Double?, movementDuration: Double, callbackDuration: Double) {
        if let previousFrameState, previousFrameState != state {
            previousTimerTick = nil
            previousDraw = nil
        }
        previousFrameState = state
        let samples: StateSamples
        if let existing = states[state] { samples = existing }
        else { samples = StateSamples(); states[state] = samples }
        samples.targetFPSCounts[String(Int(targetFPS)), default: 0] += 1
        samples.movementDurations.append(seconds: movementDuration)
        samples.callbackDurations.append(seconds: callbackDuration)
        if isTimerTick {
            samples.timerTickCount += 1
            if let previousTimerTick, previousTimerTick.state == state {
                samples.tickIntervals.append(seconds: now - previousTimerTick.time)
            }
            previousTimerTick = (now, state)
        } else { samples.eventFrameCount += 1 }

        if didDraw {
            samples.drawCount += 1
            if isTimerTick { samples.timerDrawCount += 1 }
            if let previousDraw, previousDraw.state == state {
                samples.drawIntervals.append(seconds: now - previousDraw.time)
            }
            previousDraw = (now, state)
            if let renderDuration { samples.renderDurations.append(seconds: renderDuration) }
        } else {
            samples.gateSkipCount += 1
            if isTimerTick { samples.timerGateSkipCount += 1 }
        }
    }

    var diagnostics: [String: Any] {
        ["schemaVersion": 2, "scheduler": "timer60-active-every-tick-slow-fixed-deadline",
         "slowDeadlineEarlyToleranceMs": 0.5 / 60 * 1_000,
         "sampleCapacityPerMetricPerState": Self.capacity,
         "intervalUnit": "milliseconds", "percentileMethod": "nearest-rank",
         "intervalBoundaryPolicy": "exclude-state-transitions-and-timer-restarts",
         "counterScope": "process-lifetime", "sampleScope": "latest-per-state",
         "renderDurationScope": "synchronous-renderer-call-not-display-presentation",
         "movementDurationScope": "synchronous-applyCrawlMovement-call",
         "callbackDurationScope": "synchronous-frame-including-outer-transaction-commit-excluding-sampling-and-later-runloop-work",
         "states": states.mapValues { $0.summary }]
    }
}
