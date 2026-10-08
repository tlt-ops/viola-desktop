import AppKit
import QuartzCore
import ViolaCore

/// The original frontal sleeve is extended as one affine image. Its cuff and
/// proximal skin remain a second, rigid image attached to the true wrist.
final class StraightMouseArmRig {
    let root = CALayer()
    private let upper = CALayer()
    private let lower = CALayer()
    private let sourceShoulder: CGPoint
    private let sourceWrist: CGPoint
    private let sourceJoin: CGPoint
    private let destinationShoulder: CGPoint
    private let frame: CGRect
    private let upperOrigin: CGPoint
    private let lowerOrigin: CGPoint
    private(set) var diagnostics: [String:Any] = [:]

    init?(image: CGImage, definition: SpriteDefinition, destinationShoulder: CGPoint) {
        // These rows refer to the supplied 750-pixel crop of the old straight
        // sleeve. Four overlapping pixels keep the joined raster edge covered.
        let split = CGFloat(image.height)*570/750
        let upperEnd = min(CGFloat(image.height),CGFloat(image.height)*574/750)
        guard let upperImage = image.cropping(to:CGRect(x:0,y:0,width:CGFloat(image.width),height:upperEnd)),
              let lowerImage = image.cropping(to:CGRect(x:0,y:split,width:CGFloat(image.width),height:CGFloat(image.height)-split)) else { return nil }
        frame = definition.frame
        let anchor = definition.anchor ?? [0.5,698.8/750]
        let contact = definition.contact ?? [0.5,55.0/750]
        sourceShoulder = CGPoint(x:frame.minX+anchor[0]*frame.width,y:frame.minY+anchor[1]*frame.height)
        sourceWrist = CGPoint(x:frame.minX+contact[0]*frame.width,y:frame.minY+contact[1]*frame.height)
        sourceJoin = CGPoint(x:sourceWrist.x,y:frame.minY+(1-split/CGFloat(image.height))*frame.height)
        self.destinationShoulder = destinationShoulder
        upperOrigin = CGPoint(x:frame.minX,y:frame.minY+(1-upperEnd/CGFloat(image.height))*frame.height)
        lowerOrigin = frame.origin
        root.anchorPoint = .zero; root.position = .zero
        root.bounds = CGRect(origin:.zero,size:CGSize(width:frame.maxX,height:frame.maxY))
        for (layer,part,height) in [(upper,upperImage,upperEnd/CGFloat(image.height)*frame.height),
                                   (lower,lowerImage,(1-split/CGFloat(image.height))*frame.height)] {
            layer.anchorPoint = .zero
            layer.bounds = CGRect(x:0,y:0,width:frame.width,height:height)
            layer.contents = part; layer.contentsGravity = .resize; layer.contentsScale = 2
            root.addSublayer(layer)
        }
    }

    func render(shoulderOffset: CGPoint, target: CGPoint, handAngle: CGFloat) -> SourceReferenceArmRig.Result {
        let shoulder = CGPoint(x:destinationShoulder.x+shoulderOffset.x,y:destinationShoulder.y+shoulderOffset.y)
        let cosine = cos(handAngle), sine = sin(handAngle)
        let cuff = CGAffineTransform(a:cosine,b:sine,c:-sine,d:cosine,
            tx:target.x-cosine*sourceWrist.x+sine*sourceWrist.y,
            ty:target.y-sine*sourceWrist.x-cosine*sourceWrist.y)
        let join = sourceJoin.applying(cuff)
        let sourceDX = sourceShoulder.x-sourceJoin.x
        let sourceDY = sourceShoulder.y-sourceJoin.y
        // Keep the complete horizontal basis identical to the rigid cuff. Only
        // the longitudinal basis changes to connect the join to the shoulder.
        let longitudinalX = (shoulder.x-join.x-cosine*sourceDX)/sourceDY
        let longitudinalY = (shoulder.y-join.y-sine*sourceDX)/sourceDY
        let extensionMap = CGAffineTransform(a:cosine,b:sine,c:longitudinalX,d:longitudinalY,
            tx:join.x-cosine*sourceJoin.x-longitudinalX*sourceJoin.y,
            ty:join.y-sine*sourceJoin.x-longitudinalY*sourceJoin.y)
        place(upper,origin:upperOrigin,map:extensionMap)
        place(lower,origin:lowerOrigin,map:cuff)

        let mappedWrist = sourceWrist.applying(cuff)
        let determinant = extensionMap.a*extensionMap.d-extensionMap.b*extensionMap.c
        let seamErrors = [frame.minX,frame.maxX].map { x -> CGFloat in
            let point = CGPoint(x:x,y:sourceJoin.y)
            let extended = point.applying(extensionMap), rigid = point.applying(cuff)
            return hypot(extended.x-rigid.x,extended.y-rigid.y)
        }
        let sourceLength = hypot(sourceDX,sourceDY)
        let upperStretch = hypot(shoulder.x-join.x,shoulder.y-join.y)/sourceLength
        diagnostics = [
            "mode":"straight-extension","shoulder":[shoulder.x,shoulder.y],
            "elbow":[join.x,join.y],"join":[join.x,join.y],
            "wrist":[mappedWrist.x,mappedWrist.y],"requestedWrist":[target.x,target.y],
            "wristError":hypot(mappedWrist.x-target.x,mappedWrist.y-target.y),
            "minimumDeterminant":min(determinant,1),"minimumTriangleDeterminant":min(determinant,1),
            "cuffGap":seamErrors.max() ?? 0,"cuffRigid":true,"triangleCount":0,
            "handAngle":handAngle,"lowerRotation":handAngle,"wristAngleMismatch":CGFloat(0),
            "wristAlignment":CGFloat(1),"stretch":upperStretch,
            "upperStretch":upperStretch,"lowerStretch":CGFloat(1),
            "upperAffine":[extensionMap.a,extensionMap.b,extensionMap.c,extensionMap.d,extensionMap.tx,extensionMap.ty],
            "sourceShoulder":[sourceShoulder.x,sourceShoulder.y],
            "sourceWrist":[sourceWrist.x,sourceWrist.y],"sourceJoin":[sourceJoin.x,sourceJoin.y]
        ]
        return SourceReferenceArmRig.Result(wrist:mappedWrist,handTransform:cuff)
    }

    private func place(_ layer: CALayer, origin: CGPoint, map: CGAffineTransform) {
        layer.position = origin.applying(map)
        layer.setAffineTransform(CGAffineTransform(a:map.a,b:map.b,c:map.c,d:map.d,tx:0,ty:0))
    }
}
