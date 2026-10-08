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
    private let wipeArtwork = CALayer()
    private let wipeHand = CALayer()
    private let wipeMouth = CALayer()
    private let tears = CALayer()
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
        let wipeURL = CharacterAssets.bundledDirectory.appendingPathComponent("viola-natural-wipe-base-v0.2.46.png")
        let handURL = CharacterAssets.bundledDirectory.appendingPathComponent("viola-natural-wipe-hand-v0.2.46.png")
        guard let wipeCG = NSImage(contentsOf:wipeURL)?.cgImage(forProposedRect:nil,context:nil,hints:nil),
              let handCG = NSImage(contentsOf:handURL)?.cgImage(forProposedRect:nil,context:nil,hints:nil) else { return nil }
        wipeArtwork.anchorPoint = .zero; wipeArtwork.position = artwork.position
        wipeArtwork.bounds = artwork.bounds; wipeArtwork.contents = wipeCG; wipeArtwork.contentsGravity = .resize
        wipeArtwork.contentsScale = 2
        let wipeMask = CAGradientLayer(); wipeMask.frame = mask.frame; wipeMask.colors = mask.colors
        wipeMask.locations = mask.locations; wipeMask.startPoint = mask.startPoint; wipeMask.endPoint = mask.endPoint
        wipeArtwork.mask = wipeMask
        wipeMouth.bounds = mouth.bounds; wipeMouth.anchorPoint = mouth.anchorPoint
        wipeMouth.position = mouth.position; wipeMouth.contents = mouthCG; wipeMouth.contentsGravity = .resize
        wipeMouth.contentsScale = 2; wipeArtwork.addSublayer(wipeMouth)
        // The palm, bare forearm and cuff move as one painted piece around the
        // cuff. A clean face beneath it prevents a stationary duplicate finger.
        wipeHand.bounds = CGRect(x:0,y:0,width:270*scale,height:390*scale)
        wipeHand.anchorPoint = CGPoint(x:(705.0-525)/270,y:(755.0-728)/390)
        wipeHand.position = CGPoint(x:705*scale,y:(CGFloat(cg.height)-728)*scale)
        wipeHand.contents = handCG; wipeHand.contentsGravity = .resize; wipeHand.contentsScale = 2
        wipeArtwork.addSublayer(wipeHand); pivot.addSublayer(wipeArtwork)
        tears.anchorPoint = .zero; tears.position = artwork.position; tears.bounds = artwork.bounds
        func point(_ x: CGFloat,_ y: CGFloat) -> CGPoint { CGPoint(x:x*scale,y:(CGFloat(cg.height)-y)*scale) }
        for (x,y) in [(CGFloat(322),CGFloat(431)),(CGFloat(545),CGFloat(374))] {
            let path = CGMutablePath(); path.move(to:point(x,y-3))
            path.addCurve(to:point(x,y+14),control1:point(x-8,y+5),control2:point(x-6,y+15))
            path.addCurve(to:point(x,y-3),control1:point(x+7,y+13),control2:point(x+6,y+5));path.closeSubpath()
            let drop = CAShapeLayer(); drop.path = path
            drop.fillColor = NSColor(calibratedRed:0.86,green:0.95,blue:1,alpha:0.8).cgColor
            drop.strokeColor = NSColor(calibratedRed:1,green:1,blue:1,alpha:0.9).cgColor;drop.lineWidth = 0.45
            tears.addSublayer(drop)
        }
        pivot.addSublayer(tears); wipeArtwork.opacity = 0; tears.opacity = 0
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
        wipeMouth.setAffineTransform(CGAffineTransform(scaleX:1,y:mouthScale))
        let wipe = FixedLaughMotion.wipeWeight(age:age), tear = FixedLaughMotion.tearWeight(age:age)
        artwork.opacity = Float(1-wipe); wipeArtwork.opacity = Float(wipe)
        tears.opacity = Float(tear)
        let stroke = FixedLaughMotion.wipeStroke(age:age)*factor
        wipeHand.setAffineTransform(CGAffineTransform(rotationAngle:stroke/85))
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
            "inhale":FixedLaughMotion.inhale(age:age),"mouthExcitement":excitement,"mouthScale":mouthScale,"tearWeight":tear,"wipeWeight":wipe,"wipeStroke":stroke,
            "normalVisible":weight == 0,"normalOpacity":1-weight,"dedicatedOpacity":weight,
            "minimumDeterminant":1,"cuffGap":0,"handRigid":true,
            "left":["minimumDeterminant":CGFloat(1),"cuffGap":CGFloat(0)],
            "right":["minimumDeterminant":CGFloat(1),"cuffGap":CGFloat(0)],
            "poseKey":"open-palms-belly-laugh-then-tear-wipe-v2",
            "artSignature":"viola-natural-belly-laugh-v0.2.46.png",
            "inputDependencies":["shoulderOffset","laughAge","laughWeight","reducedMotion"]]
    }
}
