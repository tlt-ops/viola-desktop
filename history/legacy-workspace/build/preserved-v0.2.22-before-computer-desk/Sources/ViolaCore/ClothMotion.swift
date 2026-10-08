import Foundation

/// Canvas-space attachment motion and leg contact drive a separate cloth spring.
public struct ClothDrive {
    public var baseX: Double
    public var baseY: Double
    public var baseAngle: Double
    public var legSwing: Double
    public var legSideSwing: Double
    public var stretch: Double
    public init(baseX: Double = 0, baseY: Double = 0, baseAngle: Double = 0,
                legSwing: Double = 0, legSideSwing: Double = 0, stretch: Double = 0) {
        self.baseX = baseX; self.baseY = baseY; self.baseAngle = baseAngle
        self.legSwing = legSwing; self.legSideSwing = legSideSwing; self.stretch = stretch
    }
}

public struct ClothFrame {
    /// Point displacements at the free hem; the waist always has zero displacement.
    public var offsetX = 0.0
    public var liftY = 0.0
    public var angle = 0.0
    public var shape = 0.0
    public init() {}
}

/// Small, bounded damped springs preserve momentum when the body changes direction.
public final class ClothMotion {
    private struct Spring {
        var position = 0.0
        var velocity = 0.0
        mutating func advance(target: Double, stiffness: Double, damping: Double, dt: Double, limit: Double) {
            velocity += ((target-position)*stiffness-velocity*damping)*dt
            position += velocity*dt
            if abs(position) > limit {
                position = max(-limit,min(limit,position))
                if position*velocity > 0 { velocity *= 0.15 }
            }
        }
    }
    private var lateral = Spring(), vertical = Spring(), ripple = Spring()
    private var previous: ClothDrive?
    private var velocityX = 0.0, velocityY = 0.0, angularVelocity = 0.0
    private let gain: Double
    public init(gain: Double = 1) { self.gain = max(0,min(1.5,gain.isFinite ? gain : 1)) }
    public func reset() {
        lateral = Spring(); vertical = Spring(); ripple = Spring()
        previous = nil; velocityX = 0; velocityY = 0; angularVelocity = 0
    }
    public func tick(dt: Double, drive: ClothDrive, reducedMotion: Bool = false) -> ClothFrame {
        func finite(_ value: Double) -> Double { value.isFinite ? value : 0 }
        func bound(_ value: Double, _ limit: Double) -> Double { max(-limit,min(limit,value)) }
        let input = ClothDrive(baseX:finite(drive.baseX),baseY:finite(drive.baseY),baseAngle:finite(drive.baseAngle),
                               legSwing:bound(finite(drive.legSwing),1),legSideSwing:bound(finite(drive.legSideSwing),0.25),
                               stretch:bound(finite(drive.stretch),1))
        // A stopped clock does not create a synthetic impulse. Accessibility mode
        // resets inertia, so leaving it cannot release stored motion unexpectedly.
        if reducedMotion { reset(); previous = input; return ClothFrame() }
        let elapsed = max(0,min(0.1,finite(dt)))
        guard elapsed > 0 else { return output() }
        guard let last = previous else { previous = input; return output() }
        previous = input
        let smoothing = 1-exp(-elapsed*16)
        let vx = velocityX+(bound((input.baseX-last.baseX)/elapsed,180)-velocityX)*smoothing
        let vy = velocityY+(bound((input.baseY-last.baseY)/elapsed,180)-velocityY)*smoothing
        let av = angularVelocity+(bound((input.baseAngle-last.baseAngle)/elapsed,3)-angularVelocity)*smoothing
        let ax = bound((vx-velocityX)/elapsed,700)
        let ay = bound((vy-velocityY)/elapsed,700)
        let aa = bound((av-angularVelocity)/elapsed,30)
        velocityX = vx; velocityY = vy; angularVelocity = av
        let sway = bound((-ax*0.007-aa*0.14+input.legSideSwing*14+input.legSwing*1.5+input.stretch*2.1)*gain,7)
        let lift = bound((-ay*0.0025+abs(input.legSwing)*0.7+input.stretch*1.0)*gain,1.7)
        let curl = bound((-vx*0.011-input.legSwing*0.65+input.stretch*0.5)*gain,1.2)
        // Semi-implicit integration is subdivided for low and variable frame rates.
        let count = max(1,Int(ceil(elapsed*120))), step = elapsed/Double(count)
        for _ in 0..<count {
            lateral.advance(target:sway,stiffness:62,damping:9,dt:step,limit:8.5)
            vertical.advance(target:lift,stiffness:88,damping:14,dt:step,limit:2.0)
            ripple.advance(target:curl,stiffness:110,damping:12,dt:step,limit:1.35)
        }
        return output()
    }
    private func output() -> ClothFrame {
        var frame = ClothFrame()
        frame.offsetX = lateral.position; frame.liftY = vertical.position
        frame.angle = max(-0.045,min(0.045,lateral.position*0.005))
        frame.shape = ripple.position
        return frame
    }
}
