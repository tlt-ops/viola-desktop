import AppKit
import QuartzCore
import ViolaCore

/// One painted upper body owns the complete laugh. Hands and cuffs cannot
/// drift apart: no normal keyboard/mouse geometry enters this clip.
final class FixedLaughRig {
    static let revision = "natural-belly-laugh-v2"
    struct Contact { let wrist: CGPoint; let angle: CGFloat; let sleeveMap: CGAffineTransform? }
    let root = CALayer()
    private let artwork = CALayer()
    private let mouth = CALayer()
    private let waist = CGPoint(x:350,y:603)
    private(set) var diagnostics: [String:Any] = [:]

    init?(canvasSize: CGSize) {
        let url = CharacterAssets.bundledDirectory.appendingPathComponent("viola-natural-belly-laugh-base-v0.2.46.png")
        guard let image = NSImage(contentsOf:url),
              let cg = image.cgImage(forProposedRect:nil,context:nil,hints:nil),
              let mouthImage = NSImage(contentsOf:CharacterAssets.bundledDirectory.appendingPathComponent("viola-natural-belly-laugh-mouth-v0.2.46.png")),
              let mouthCG = mouthImage.cgImage(forProposedRect:nil,context:nil,hints:nil) else { return nil }
        root.anchorPoint = .zero; root.position = .zero
        root.bounds = CGRect(origin:.zero,size:canvasSize); root.contentsScale = 2
        let scale: CGFloat = 0.326
        let frame = CGRect(x:145,y:934-CGFloat(cg.height)*scale,
            width:CGFloat(cg.width)*scale,height:CGFloat(cg.height)*scale)
        artwork.anchorPoint = .zero; artwork.position = CGPoint(x:frame.minX-waist.x,y:frame.minY-waist.y)
        artwork.bounds = CGRect(origin:.zero,size:frame.size)
        artwork.contents = cg; artwork.contentsGravity = .resize; artwork.contentsScale = 2
        // The apron overlaps the retained painted skirt; soften only its final
        // few pixels, keeping the complete hands, elbows, face and hair opaque.
        let mask = CAGradientLayer(); mask.frame = artwork.bounds
        mask.colors = [NSColor.clear.cgColor,NSColor.white.cgColor,NSColor.white.cgColor]
        mask.locations = [0,0.035,1]; mask.startPoint = CGPoint(x:0.5,y:0); mask.endPoint = CGPoint(x:0.5,y:1)
        artwork.mask = mask
        // A feathered silhouette retains the painted teeth and lip line. The
        // base contains skin only underneath it, so compression leaves no ghost.
        mouth.bounds = CGRect(x:0,y:0,width:109*scale,height:86*scale)
        mouth.anchorPoint = CGPoint(x:0,y:(529.0-455.0)/86.0)
        mouth.position = CGPoint(x:410*scale,y:(CGFloat(cg.height)-455)*scale)
        mouth.contents = mouthCG; mouth.contentsGravity = .resize; mouth.contentsScale = 2
        artwork.addSublayer(mouth)
        let pivot = CALayer(); pivot.anchorPoint = .zero; pivot.position = waist
        pivot.bounds = CGRect(origin:.zero,size:canvasSize)
        pivot.addSublayer(artwork); root.addSublayer(pivot)
        root.isHidden = true
    }

    func render(weight rawWeight: Double, shoulderOffset: CGPoint, age: Double,
                reducedMotion: Bool, normalLeft: Contact, normalRight: Contact) {
        let weight = max(0,min(1,rawWeight)), factor = reducedMotion ? 0.35 : 1.0
        let angle = (FixedLaughMotion.torsoRotation(age:age)+FixedLaughMotion.headNod(age:age)*0.35)*weight*factor
        let movement = FixedLaughMotion.torsoTranslation(age:age)
        let pivot = root.sublayers![0]
        pivot.position = CGPoint(x:waist.x+shoulderOffset.x+movement.x*weight*factor,
            y:waist.y+shoulderOffset.y+movement.y*weight*factor)
        pivot.setAffineTransform(CGAffineTransform(rotationAngle:angle))
        let excitement = max(0,min(1,FixedLaughMotion.mouthExcitement(age:age)))
        let mouthScale = 0.75+0.25*excitement
        mouth.setAffineTransform(CGAffineTransform(scaleX:1,y:mouthScale))
        root.opacity = Float(weight); root.isHidden = weight == 0
        let left = CGPoint(x:319,y:566).applying(CGAffineTransform(translationX:-waist.x,y:-waist.y))
            .applying(CGAffineTransform(rotationAngle:angle))
        let right = CGPoint(x:382,y:562).applying(CGAffineTransform(translationX:-waist.x,y:-waist.y))
            .applying(CGAffineTransform(rotationAngle:angle))
        diagnostics = ["active":weight > 0,"revision":Self.revision,"weight":weight,
            "phase":age < FixedLaughMotion.entryDuration ? "entry" : (age > FixedLaughMotion.duration-FixedLaughMotion.exitDuration ? "return" : "main"),
            "leftWrist":[pivot.position.x+left.x,pivot.position.y+left.y],
            "rightWrist":[pivot.position.x+right.x,pivot.position.y+right.y],
            "leftAngle":angle,"rightAngle":angle,"torsoRotation":angle,
            "torsoPosition":[pivot.position.x,pivot.position.y],"pulse":FixedLaughMotion.pulse(age:age),
            "inhale":FixedLaughMotion.inhale(age:age),"mouthExcitement":excitement,"mouthScale":mouthScale,
            "normalVisible":weight == 0,"normalOpacity":1-weight,"dedicatedOpacity":weight,
            "minimumDeterminant":1,"cuffGap":0,"handRigid":true,
            "left":["minimumDeterminant":CGFloat(1),"cuffGap":CGFloat(0)],
            "right":["minimumDeterminant":CGFloat(1),"cuffGap":CGFloat(0)],
            "poseKey":"open-palms-on-abdomen-painted-v2",
            "artSignature":"viola-natural-belly-laugh-v0.2.46.png",
            "inputDependencies":["shoulderOffset","laughAge","laughWeight","reducedMotion"]]
    }
}
