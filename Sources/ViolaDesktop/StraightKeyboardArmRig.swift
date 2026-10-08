import AppKit
import QuartzCore
import ViolaCore

/// One original purple sleeve rotates and extends along its shoulder axis.
/// The existing palm owns the cuff, so its pixels rotate with the fingers.
final class StraightKeyboardArmRig {
    struct Result {
        let arm: SourceReferenceArmRig.Result
        let handAngle: CGFloat
    }
    private struct Pose { let length: CGFloat; let angle: CGFloat }
    let root = CALayer()
    private let imageLayer = CALayer()
    private let frame: CGRect
    private let sourceShoulder: CGPoint
    private let sourceJoin: CGPoint
    private let sourceAxis: CGPoint
    private let sourceLength: CGFloat
    private let destinationShoulder: CGPoint
    private var pose: Pose?
    private static let cuffOverlap: CGFloat = 10
    private(set) var diagnostics: [String:Any] = [:]

    init(image: CGImage, definition: SpriteDefinition, destinationShoulder: CGPoint) {
        frame = definition.frame
        let a = definition.anchor ?? [0.568,538.8/590]
        let c = definition.contact ?? [231.0/440,0]
        let shoulder = CGPoint(x:frame.minX+a[0]*frame.width,y:frame.minY+a[1]*frame.height)
        let end = CGPoint(x:frame.minX+c[0]*frame.width,y:frame.minY+c[1]*frame.height)
        let dx = end.x-shoulder.x, dy = end.y-shoulder.y, length = hypot(dx,dy)
        sourceShoulder = shoulder
        let axis = CGPoint(x:dx/length,y:dy/length)
        sourceAxis = axis
        // The palm draws above this purple-only strip. Its cuff covers the last
        // 10 source-canvas units without introducing a second white cuff.
        sourceJoin = CGPoint(x:end.x-axis.x*Self.cuffOverlap,y:end.y-axis.y*Self.cuffOverlap)
        sourceLength = length-Self.cuffOverlap
        self.destinationShoulder = destinationShoulder
        root.anchorPoint = .zero; root.position = .zero
        root.bounds = CGRect(origin:.zero,size:CGSize(width:frame.maxX,height:frame.maxY))
        imageLayer.anchorPoint = .zero; imageLayer.bounds = CGRect(origin:.zero,size:frame.size)
        imageLayer.contents = image; imageLayer.contentsGravity = .resize; imageLayer.contentsScale = 2
        root.addSublayer(imageLayer)
    }

    func render(shoulderOffset: CGPoint, restingWrist: CGPoint, fingerTarget: CGPoint?, fingerVector: CGPoint?,
                laughWeight: CGFloat, laughWrist: CGPoint, laughAngle: CGFloat, dt: Double) -> Result {
        let shoulder = CGPoint(x:destinationShoulder.x+shoulderOffset.x,y:destinationShoulder.y+shoulderOffset.y)
        let rest = poseForWrist(restingWrist,shoulder:shoulder)
        var goal = rest
        var solvable = true
        if let fingerTarget, let fingerVector {
            if let contact = poseForContact(fingerTarget,vector:fingerVector,shoulder:shoulder) { goal = contact }
            else { solvable = false }
        }
        if let previous = pose {
            let blend = CGFloat(1-exp(-max(0,dt)*28))
            let difference = atan2(sin(goal.angle-previous.angle),cos(goal.angle-previous.angle))
            pose = Pose(length:previous.length+(goal.length-previous.length)*blend,
                        angle:previous.angle+difference*blend)
        } else { pose = goal }
        let normal = pose ?? goal
        let normalAxis = rotated(sourceAxis,by:normal.angle)
        let normalWrist = CGPoint(x:shoulder.x+normalAxis.x*normal.length,y:shoulder.y+normalAxis.y*normal.length)
        let weight = max(0,min(1,laughWeight))
        let wrist = CGPoint(x:normalWrist.x+(laughWrist.x-normalWrist.x)*weight,
                            y:normalWrist.y+(laughWrist.y-normalWrist.y)*weight)
        let handAngle = normal.angle*(1-weight)+laughAngle
        let perpendicular = CGPoint(x:-sourceAxis.y,y:sourceAxis.x)
        let widthAxis = rotated(perpendicular,by:handAngle)
        let longitudinal = CGPoint(x:(wrist.x-shoulder.x)/sourceLength,y:(wrist.y-shoulder.y)/sourceLength)
        // At weight zero these bases are orthogonal: a rotation plus scaling
        // along one axis. The shoulder is fixed, including during transitions.
        let a = longitudinal.x*sourceAxis.x+widthAxis.x*perpendicular.x
        let b = longitudinal.y*sourceAxis.x+widthAxis.y*perpendicular.x
        let c = longitudinal.x*sourceAxis.y+widthAxis.x*perpendicular.y
        let d = longitudinal.y*sourceAxis.y+widthAxis.y*perpendicular.y
        let map = CGAffineTransform(a:a,b:b,c:c,d:d,
            tx:shoulder.x-a*sourceShoulder.x-c*sourceShoulder.y,
            ty:shoulder.y-b*sourceShoulder.x-d*sourceShoulder.y)
        imageLayer.position = frame.origin.applying(map)
        imageLayer.setAffineTransform(CGAffineTransform(a:a,b:b,c:c,d:d,tx:0,ty:0))
        let mappedShoulder = sourceShoulder.applying(map), mappedWrist = sourceJoin.applying(map)
        let cosine = cos(handAngle), sine = sin(handAngle)
        let hand = CGAffineTransform(a:cosine,b:sine,c:-sine,d:cosine,
            tx:wrist.x-cosine*sourceJoin.x+sine*sourceJoin.y,
            ty:wrist.y-sine*sourceJoin.x-cosine*sourceJoin.y)
        let determinant = a*d-b*c
        let cuffGap = hypot(mappedWrist.x-wrist.x,mappedWrist.y-wrist.y)
        let stretch = hypot(wrist.x-shoulder.x,wrist.y-shoulder.y)/sourceLength
        let goalAxis = rotated(sourceAxis,by:goal.angle)
        let goalWrist = CGPoint(x:shoulder.x+goalAxis.x*goal.length,y:shoulder.y+goalAxis.y*goal.length)
        diagnostics = ["mode":"straight-keyboard-axis","shoulder":[shoulder.x,shoulder.y],
            "wrist":[mappedWrist.x,mappedWrist.y],"requestedWrist":[wrist.x,wrist.y],
            "goalWrist":[goalWrist.x,goalWrist.y],"elbow":[wrist.x,wrist.y],
            "wristError":cuffGap,"cuffGap":cuffGap,"cuffRigid":true,"triangleCount":0,
            "minimumDeterminant":determinant,"minimumTriangleDeterminant":determinant,
            "shoulderError":hypot(mappedShoulder.x-shoulder.x,mappedShoulder.y-shoulder.y),
            "axisShear":widthAxis.x*longitudinal.x+widthAxis.y*longitudinal.y,
            "handAngle":handAngle,"lowerRotation":handAngle,"wristAngleMismatch":CGFloat(0),
            "stretch":stretch,"upperStretch":stretch,"lowerStretch":CGFloat(1),"wristAlignment":CGFloat(1),
            "contactSolvable":solvable,"normalAngle":normal.angle,"normalLength":normal.length,
            "sourceShoulder":[sourceShoulder.x,sourceShoulder.y],"sourceJoin":[sourceJoin.x,sourceJoin.y],
            "overlap":Self.cuffOverlap,"upperAffine":[a,b,c,d,map.tx,map.ty]]
        return Result(arm:SourceReferenceArmRig.Result(wrist:mappedWrist,handTransform:hand),handAngle:handAngle)
    }

    private func poseForContact(_ target: CGPoint, vector: CGPoint, shoulder: CGPoint) -> Pose? {
        let q = CGPoint(x:target.x-shoulder.x,y:target.y-shoulder.y)
        let perpendicular = CGPoint(x:-sourceAxis.y,y:sourceAxis.x)
        let along = vector.x*sourceAxis.x+vector.y*sourceAxis.y
        let across = vector.x*perpendicular.x+vector.y*perpendicular.y
        let squared = q.x*q.x+q.y*q.y-across*across
        guard squared >= 0 else { return nil }
        let reach = sqrt(squared), length = reach-along
        guard length > 0 else { return nil }
        let direction = CGPoint(x:sourceAxis.x*reach+perpendicular.x*across,
                                y:sourceAxis.y*reach+perpendicular.y*across)
        return Pose(length:length,angle:atan2(q.y,q.x)-atan2(direction.y,direction.x))
    }
    private func poseForWrist(_ wrist: CGPoint, shoulder: CGPoint) -> Pose {
        let dx = wrist.x-shoulder.x, dy = wrist.y-shoulder.y
        return Pose(length:hypot(dx,dy),angle:atan2(dy,dx)-atan2(sourceAxis.y,sourceAxis.x))
    }
    private func rotated(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        CGPoint(x:cos(angle)*point.x-sin(angle)*point.y,y:sin(angle)*point.x+cos(angle)*point.y)
    }
}
