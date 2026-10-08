import AppKit
import ViolaCore

struct LegRecoveryTarget {
    let point: CGPoint
    let blend: CGFloat
    let scale: CGFloat
    let straighten: CGFloat
    let forward: CGFloat
    let direction: CGFloat
}

/// A rear shoe and its toe/rim overlay share one rigid transform, separate from the leg.
final class ShoeRig {
    private let rear: CALayer
    private let front: CALayer
    private let direction: CGFloat
    private let floorY: CGFloat
    private var previous: ShoePhase = .halfWorn
    private var position = CGPoint.zero
    private var angle: CGFloat = 0
    private var scale: CGFloat = 1
    private var launch = CGPoint.zero
    private var launchAngle: CGFloat = 0
    private var landing = CGPoint.zero
    private var landingAngle: CGFloat = 0
    private var detachedScale: CGFloat = 1
    private let offset = CGPoint(x: 0, y: -6)
    init(rear: CALayer, front: CALayer, direction: CGFloat, floorY: CGFloat) {
        self.rear = rear; self.front = front; self.direction = direction; self.floorY = floorY
    }
    private func smooth(_ x: CGFloat) -> CGFloat { let p = max(0, min(1, x)); return p*p*(3-2*p) }
    func recoveryTarget(_ frame: ShoeFrame) -> LegRecoveryTarget? {
        guard frame.phase == .recovering, frame.recovery == .toeHook else { return nil }
        let pose = frame.toeHookPose
        // Reach the opening using the actual grounded rotation, then lift only
        // after the foot has seated. The knee projection owns the forward reach.
        let opening = rotatedOffset(angle:landingAngle,scale:detachedScale)
        let point = CGPoint(x:landing.x-opening.x,
                            y:landing.y-opening.y+24*CGFloat(pose.toeLift))
        return LegRecoveryTarget(point:point,blend:CGFloat(pose.reach),
            scale:detachedScale*(1+0.18*CGFloat(pose.forward)),
            straighten:CGFloat(pose.straighten),forward:CGFloat(pose.forward),direction:direction)
    }
    private func rotatedOffset(angle: CGFloat, scale: CGFloat) -> CGPoint {
        CGPoint(x:(offset.x*cos(angle)-offset.y*sin(angle))*scale,
                y:(offset.x*sin(angle)+offset.y*cos(angle))*scale)
    }
    private func toeHookAngle(_ frame: ShoeFrame, resting: CGFloat) -> CGFloat {
        let pose = frame.toeHookPose
        let lift = CGFloat(pose.toeLift), straighten = CGFloat(pose.straighten)
        // Both atlas shoes point toward canvas-left. Their fall directions are
        // independent, but a negative rotation raises the toe on both images.
        let carried = landingAngle+(-0.40-landingAngle)*lift+0.28*straighten
        return carried+(resting-carried)*CGFloat(pose.returnToRest)
    }
    private func bottomOffset(angle: CGFloat, scale: CGFloat) -> CGFloat {
        let anchor = front.anchorPoint, size = front.bounds.size
        return [CGPoint(x:0,y:0),CGPoint(x:size.width,y:0),CGPoint(x:0,y:size.height),CGPoint(x:size.width,y:size.height)].map {
            let x = ($0.x-anchor.x*size.width)*scale, y = ($0.y-anchor.y*size.height)*scale
            return x*sin(angle)+y*cos(angle)
        }.min() ?? 0
    }
    func render(_ frame: ShoeFrame, foot: CGPoint, footScale: CGFloat, side: Double, dt: Double) {
        let attached = CGPoint(x: foot.x+offset.x*footScale, y: foot.y+offset.y*footScale)
        let restingAngle = CGFloat(side+frame.wobble)
        if frame.phase == .falling, previous != .falling {
            launch = position; launchAngle = angle; detachedScale = scale
            landingAngle = direction * 0.48
            landing = CGPoint(x: launch.x+direction*18, y: floorY-bottomOffset(angle:landingAngle,scale:scale))
        }
        switch frame.phase {
        case .halfWorn, .slipping:
            let slip = frame.phase == .slipping ? smooth(CGFloat(frame.progress)) : 0
            position = CGPoint(x:attached.x+direction*3*slip,y:attached.y-11*slip)
            // Soft angular lag makes a loose shoe respond after its foot changes direction.
            angle += (restingAngle+direction*0.12*slip-angle)*CGFloat(1-exp(-max(0,dt)*10))
            scale = footScale
        case .falling:
            let t = CGFloat(frame.progress)*1.1, gravity: CGFloat = 580, initialVelocity: CGFloat = -12
            let drop = max(0, launch.y-landing.y)
            let impact = (initialVelocity+sqrt(initialVelocity*initialVelocity+2*gravity*drop))/gravity
            let bounceVelocity = (gravity*impact-initialVelocity)*0.2
            let bounceTime = max(0,t-impact)
            let y = t < impact ? launch.y+initialVelocity*t-0.5*gravity*t*t : landing.y+max(0,bounceVelocity*bounceTime-0.5*gravity*bounceTime*bounceTime)
            let travel = smooth(t/max(0.12,impact))
            position = CGPoint(x:launch.x+(landing.x-launch.x)*travel,y:y)
            angle = launchAngle+(landingAngle-launchAngle)*smooth(t/max(0.18,impact))
            scale = detachedScale
            position.y = max(position.y, floorY-bottomOffset(angle:angle,scale:scale))
        case .grounded:
            position = landing; angle = landingAngle; scale = detachedScale
        case .recovering:
            let assisted = frame.recovery == .friendAssist
            if assisted {
                let pickup = smooth((CGFloat(frame.progress)-0.22)/0.42)
                position = CGPoint(x:landing.x+(attached.x-landing.x)*pickup,
                                   y:landing.y+(attached.y-landing.y)*pickup+sin(pickup*CGFloat.pi)*12)
                angle = landingAngle+(restingAngle-landingAngle)*pickup
                scale = detachedScale+(footScale-detachedScale)*pickup
            } else {
                let pose = frame.toeHookPose
                let pickup = smooth((CGFloat(frame.progress)-0.30)/0.08)
                angle = toeHookAngle(frame,resting:restingAngle)
                scale = detachedScale+(footScale-detachedScale)*pickup
                // The rotated opening stays registered to the reaching foot.
                // This is continuous at pickup; the shoe never teleports to it.
                let carriedOffset = rotatedOffset(angle:angle,scale:scale)
                let carried = CGPoint(x:foot.x+carriedOffset.x,y:foot.y+carriedOffset.y)
                position = CGPoint(x:landing.x+(carried.x-landing.x)*pickup,
                                   y:landing.y+(carried.y-landing.y)*pickup)
                // Ease from the rotated fitted offset to the half-worn offset
                // used by normal idle motion at the end of the return.
                let settle = CGFloat(pose.returnToRest)
                position.x += (attached.x-carried.x)*settle
                position.y += (attached.y-carried.y)*settle
            }
        }
        for layer in [rear,front] {
            layer.position = position
            layer.setAffineTransform(CGAffineTransform(rotationAngle:angle).scaledBy(x:scale,y:scale))
        }
        previous = frame.phase
    }
    var diagnostic: [String:Any] {
        ["phase":previous.rawValue,"position":[position.x,position.y],"rotation":angle,"scale":scale]
    }
    func containsGroundedShoe(_ point: CGPoint, in root: CALayer) -> Bool {
        guard previous == .grounded else { return false }
        let local = rear.convert(point, from: root)
        return rear.bounds.insetBy(dx: -4, dy: -4).contains(local)
    }
    func helpHand(_ frame: ShoeFrame, rest: CGPoint) -> (point:CGPoint,opacity:Float) {
        guard frame.phase == .recovering, frame.recovery == .friendAssist else { return (rest,0) }
        let p = CGFloat(frame.progress)
        let grip = CGPoint(x:position.x-7*scale,y:position.y-15*scale)
        let reach = p < 0.22 ? smooth(p/0.22) : p > 0.78 ? 1-smooth((p-0.78)/0.22) : 1
        return (CGPoint(x:rest.x+(grip.x-rest.x)*reach,y:rest.y+(grip.y-rest.y)*reach),
                Float(min(1,min(p/0.07,(1-p)/0.07))))
    }
}
