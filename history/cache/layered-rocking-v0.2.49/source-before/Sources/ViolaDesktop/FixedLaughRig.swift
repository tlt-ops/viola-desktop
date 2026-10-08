import AppKit
import QuartzCore
import ViolaCore

/// A saved eight-second action with independent chest, head, hair and two
/// articulated arms. Normal contacts are used only to enter and return.
final class FixedLaughRig {
    static let revision = "layered-belly-laugh-v3"
    struct Contact { let wrist: CGPoint; let angle: CGFloat; let sleeveMap: CGAffineTransform? }
    let root = CALayer()
    private let chest = CALayer(), head = CALayer(), hair = CALayer()
    private let mouth = CALayer(), tears = CALayer()
    private let waist = CGPoint(x:350,y:603)
    private let neck = FixedLaughRig.point(565,568)
    private let leftArm: LaughArm
    private let rightArm: LaughArm
    private var entryLeft: Contact?, entryRight: Contact?
    private var previousAge = -1.0
    private(set) var diagnostics: [String:Any] = [:]
    private static let scale: CGFloat = 0.326
    fileprivate static func point(_ x: CGFloat,_ y: CGFloat) -> CGPoint {
        CGPoint(x:145+x*scale,y:934-y*scale)
    }
    fileprivate static func image(_ name: String) -> CGImage? {
        NSImage(contentsOf:CharacterAssets.bundledDirectory.appendingPathComponent(name))?
            .cgImage(forProposedRect:nil,context:nil,hints:nil)
    }
    fileprivate static func art(_ name: String) -> CALayer? {
        guard let cg = image(name) else { return nil }
        let layer = CALayer(); layer.anchorPoint = .zero
        layer.bounds = CGRect(x:0,y:0,width:CGFloat(cg.width)*scale,height:CGFloat(cg.height)*scale)
        layer.position = CGPoint(x:145,y:934-layer.bounds.height)
        layer.contents = cg; layer.contentsGravity = .resize; layer.contentsScale = 2
        return layer
    }
    init?(canvasSize: CGSize) {
        guard let chestArt = Self.art("viola-layered-chest-v0.2.47.png"),
              let headArt = Self.art("viola-layered-head-v0.2.47.png"),
              let hairArt = Self.art("viola-layered-hair-v0.2.47.png"),
              let l = LaughArm(side:"left"), let r = LaughArm(side:"right"),
              let mouthCG = Self.image("viola-natural-belly-laugh-mouth-v0.2.46.png") else { return nil }
        leftArm = l; rightArm = r
        root.anchorPoint = .zero; root.position = .zero
        root.bounds = CGRect(origin:.zero,size:canvasSize); root.contentsScale = 2
        for (pivot,artwork,origin) in [(hair,hairArt,neck),(chest,chestArt,waist),(head,headArt,neck)] {
            pivot.anchorPoint = .zero; pivot.position = origin
            pivot.bounds = CGRect(origin:.zero,size:canvasSize)
            artwork.position.x -= origin.x; artwork.position.y -= origin.y
            pivot.addSublayer(artwork)
        }
        let apronMask = CAGradientLayer(); apronMask.frame = chestArt.bounds
        apronMask.colors = [NSColor.clear.cgColor,NSColor.white.cgColor,NSColor.white.cgColor]
        apronMask.locations = [0,0.035,1]; apronMask.startPoint = CGPoint(x:0.5,y:0); apronMask.endPoint = CGPoint(x:0.5,y:1)
        chestArt.mask = apronMask
        root.addSublayer(hair); root.addSublayer(chest)
        root.addSublayer(l.root); root.addSublayer(r.root)
        // Face and long front strands cover shoulder cuts, but the wiping palm
        // belongs above the face and follows its own wrist trajectory.
        root.addSublayer(head)
        root.addSublayer(r.wipeRoot)
        mouth.anchorPoint = CGPoint(x:0,y:74.0/86.0)
        mouth.bounds = CGRect(x:0,y:0,width:109*Self.scale,height:86*Self.scale)
        let mouthAnchor = Self.point(410,455)
        mouth.position = CGPoint(x:mouthAnchor.x-neck.x,y:mouthAnchor.y-neck.y)
        mouth.contents = mouthCG; mouth.contentsGravity = .resize; mouth.contentsScale = 2
        head.addSublayer(mouth)
        tears.anchorPoint = .zero; tears.position = .zero
        tears.bounds = CGRect(origin:.zero,size:canvasSize)
        for (x,y) in [(CGFloat(322),CGFloat(431)),(CGFloat(545),CGFloat(374))] {
            func local(_ x:CGFloat,_ y:CGFloat)->CGPoint { let p = Self.point(x,y);return CGPoint(x:p.x-neck.x,y:p.y-neck.y) }
            let p = CGMutablePath();p.move(to:local(x,y-3))
            p.addCurve(to:local(x,y+14),control1:local(x-8,y+5),control2:local(x-6,y+15))
            p.addCurve(to:local(x,y-3),control1:local(x+7,y+13),control2:local(x+6,y+5));p.closeSubpath()
            let drop = CAShapeLayer();drop.path = p
            drop.fillColor = NSColor(calibratedRed:0.86,green:0.95,blue:1,alpha:0.8).cgColor
            drop.strokeColor = NSColor(calibratedWhite:1,alpha:0.9).cgColor;drop.lineWidth = 0.45
            tears.addSublayer(drop)
        }
        head.addSublayer(tears);root.isHidden = true
    }
    func render(weight rawWeight: Double, shoulderOffset: CGPoint, age: Double,
                reducedMotion: Bool, normalLeft: Contact, normalRight: Contact) {
        let weight = max(0,min(1,rawWeight)), factor = reducedMotion ? 0.35 : 1.0
        let amount = weight*factor
        if weight > 0 && (entryLeft == nil || age < previousAge) {
            entryLeft = normalLeft;entryRight = normalRight
        }
        previousAge = age
        let angle = FixedLaughMotion.torsoRotation(age:age)*amount
        let compression = 1+(FixedLaughMotion.chestCompression(age:age)-1)*amount
        let lift = FixedLaughMotion.shoulderLift(age:age)*amount
        // The waist uses exactly the retained thighs' translation. Compression
        // and nod happen above it, preventing independent breathing seams.
        let base = CGPoint(x:waist.x+shoulderOffset.x,y:waist.y+shoulderOffset.y)
        func chestPoint(_ p: CGPoint)->CGPoint {
            CGPoint(x:p.x-waist.x,y:p.y-waist.y).applying(CGAffineTransform(scaleX:1,y:compression))
                .applying(CGAffineTransform(rotationAngle:angle))
                .applying(CGAffineTransform(translationX:base.x,y:base.y))
        }
        chest.position = CGPoint(x:base.x,y:base.y)
        chest.setAffineTransform(CGAffineTransform(a:cos(angle),b:sin(angle),c:-compression*sin(angle),d:compression*cos(angle),tx:0,ty:0))
        let movedNeck = chestPoint(neck)
        head.position = CGPoint(x:movedNeck.x,y:movedNeck.y+lift)
        let headAngle = FixedLaughMotion.headNod(age:age)*amount
        head.setAffineTransform(CGAffineTransform(rotationAngle:angle+headAngle))
        hair.position = head.position
        let hairAngle = FixedLaughMotion.hairSway(age:age)*amount
        hair.setAffineTransform(CGAffineTransform(rotationAngle:angle+hairAngle))
        let excitement = max(0,min(1,FixedLaughMotion.mouthExcitement(age:age)))
        let mouthScale = 0.67+0.33*excitement
        mouth.setAffineTransform(CGAffineTransform(scaleX:1+excitement*0.025,y:mouthScale))
        let wipe = FixedLaughMotion.wipeWeight(age:age), stroke = FixedLaughMotion.wipeStroke(age:age)*factor
        tears.opacity = Float(FixedLaughMotion.tearWeight(age:age))
        func blend(_ a:CGPoint,_ b:CGPoint,_ t:Double)->CGPoint { CGPoint(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t) }
        let leftBelly = chestPoint(Self.point(380,1085))
        let rightBelly = chestPoint(Self.point(824,1100))
        // The cuff's eye-contact pose is registered to the independently nodding
        // head, so the index follows the eye rather than crossing a fixed face.
        let wipeSource = Self.point(705,728)
        let wipeGoal = CGPoint(x:wipeSource.x-neck.x,y:wipeSource.y-neck.y)
            .applying(head.affineTransform()).applying(CGAffineTransform(translationX:head.position.x,y:head.position.y))
        let raised = blend(rightBelly,wipeGoal,wipe)
        let rightGoal = CGPoint(x:raised.x+stroke*0.8*wipe,y:raised.y+abs(stroke)*0.18*wipe)
        let isReturn = age > FixedLaughMotion.duration-FixedLaughMotion.exitDuration
        let startLeft = isReturn ? normalLeft : (entryLeft ?? normalLeft)
        let startRight = isReturn ? normalRight : (entryRight ?? normalRight)
        let leftWrist = blend(startLeft.wrist,leftBelly,weight)
        let rightWrist = blend(startRight.wrist,rightGoal,weight)
        let leftShoulder = chestPoint(Self.point(350,585)), rightShoulder = chestPoint(Self.point(831,581))
        leftArm.render(shoulder:CGPoint(x:leftShoulder.x,y:leftShoulder.y+lift),wrist:leftWrist,wipe:0,wipeAngle:0)
        rightArm.render(shoulder:CGPoint(x:rightShoulder.x,y:rightShoulder.y+lift),wrist:rightWrist,wipe:wipe,wipeAngle:angle+headAngle)
        root.opacity = Float(weight);root.isHidden = weight == 0
        diagnostics = ["active":weight > 0,"revision":Self.revision,"weight":weight,
            "phase":age < FixedLaughMotion.entryDuration ? "entry" : (isReturn ? "return" : "main"),
            "leftWrist":[leftArm.wrist.x,leftArm.wrist.y],"rightWrist":[rightArm.wrist.x,rightArm.wrist.y],
            "leftAngle":leftArm.handAngle,"rightAngle":rightArm.handAngle,"torsoRotation":angle,
            "headRotation":headAngle,"hairRotation":hairAngle,"chestScale":compression,"shoulderLift":lift,
            "torsoPosition":[chest.position.x,chest.position.y],"pulse":FixedLaughMotion.pulse(age:age),
            "inhale":FixedLaughMotion.inhale(age:age),"mouthExcitement":excitement,"mouthScale":mouthScale,
            "tearWeight":FixedLaughMotion.tearWeight(age:age),"wipeWeight":wipe,"wipeStroke":stroke,
            "normalVisible":weight == 0,"normalOpacity":1-weight,"dedicatedOpacity":weight,
            "minimumDeterminant":min(leftArm.determinant,rightArm.determinant),"cuffGap":0,"handRigid":true,
            "left":leftArm.diagnostics,"right":rightArm.diagnostics,
            "poseKey":"articulated-belly-laugh-then-tear-wipe-v3",
            "artSignature":"viola-layered-clean-v0.2.47.png",
            "inputDependencies":["entryAndReturnContacts","shoulderOffset","laughAge","laughWeight","reducedMotion"]]
        if weight == 0 { entryLeft = nil;entryRight = nil;previousAge = -1 }
    }
}

/// Two painted sleeve sections rotate about the shoulder and elbow; the cuff
/// and complete hand are rigid. Positive axis scaling never folds the texture.
private final class LaughArm {
    let root = CALayer(), wipeRoot = CALayer()
    private let upper: CALayer, lower: CALayer, palm: CALayer
    private let wipePalm: CALayer?
    private let sourceShoulder: CGPoint, sourceElbow: CGPoint, sourceWrist: CGPoint
    private let upperOrigin: CGPoint,lowerOrigin:CGPoint,palmOrigin:CGPoint
    private var wipeOrigin = CGPoint.zero
    private let bend:CGFloat
    private(set) var wrist = CGPoint.zero,handAngle:CGFloat = 0,determinant:CGFloat = 1
    private(set) var diagnostics:[String:Any] = [:]
    init?(side: String) {
        guard let u = FixedLaughRig.art("viola-layered-\(side)-upper-v0.2.47.png"),
              let l = FixedLaughRig.art("viola-layered-\(side)-lower-v0.2.47.png"),
              let h = FixedLaughRig.art("viola-layered-\(side)-hand-v0.2.47.png") else { return nil }
        upper = u;lower = l;palm = h
        upperOrigin = u.position;lowerOrigin = l.position;palmOrigin = h.position
        let left = side == "left"
        sourceShoulder = left ? FixedLaughRig.point(350,585) : FixedLaughRig.point(831,581)
        sourceElbow = left ? FixedLaughRig.point(240,940) : FixedLaughRig.point(1020,940)
        sourceWrist = left ? FixedLaughRig.point(380,1085) : FixedLaughRig.point(824,1100)
        bend = left ? -1 : 1
        for layer in [root,wipeRoot] {layer.anchorPoint = .zero;layer.position = .zero;layer.bounds = CGRect(x:0,y:0,width:800,height:960)}
        root.addSublayer(u);root.addSublayer(l);root.addSublayer(h)
        wipePalm = left ? nil : FixedLaughRig.art("viola-layered-wipe-hand-v0.2.47.png")
        if let wp = wipePalm { wipeOrigin = wp.position;wipeRoot.addSublayer(wp) }
    }
    func render(shoulder s:CGPoint,wrist target:CGPoint,wipe:Double,wipeAngle:CGFloat) {
        let l1 = hypot(sourceElbow.x-sourceShoulder.x,sourceElbow.y-sourceShoulder.y)
        let l2 = hypot(sourceWrist.x-sourceElbow.x,sourceWrist.y-sourceElbow.y)
        let dx = target.x-s.x,dy = target.y-s.y,d = max(0.001,hypot(dx,dy))
        let scale = max(1,min(1.15,d/(l1+l2-0.1)))
        let a = l1*scale,b = l2*scale
        let reach = max(abs(a-b)+0.05,min(a+b-0.05,d))
        let axis = CGPoint(x:dx/d,y:dy/d)
        let w = CGPoint(x:s.x+axis.x*reach,y:s.y+axis.y*reach)
        let along = (a*a-b*b+reach*reach)/(2*reach)
        let height = sqrt(max(0,a*a-along*along))
        var e = CGPoint(x:s.x+axis.x*along-axis.y*height*bend,y:s.y+axis.y*along+axis.x*height*bend)
        if wipePalm != nil {
            let source = FixedLaughRig.point(705,728), elbow = FixedLaughRig.point(790,840)
            let direction = atan2(source.y-elbow.y,source.x-elbow.x)+wipeAngle
            let aligned = CGPoint(x:w.x-cos(direction)*b,y:w.y-sin(direction)*b)
            e.x += (aligned.x-e.x)*wipe;e.y += (aligned.y-e.y)*wipe
        }
        let um = bone(sourceShoulder,sourceElbow,s,e),lm = bone(sourceElbow,sourceWrist,e,w)
        place(upper,upperOrigin,um);place(lower,lowerOrigin,lm)
        let sourceAngle = atan2(sourceWrist.y-sourceElbow.y,sourceWrist.x-sourceElbow.x)
        let solvedAngle = atan2(w.y-e.y,w.x-e.x)
        handAngle = atan2(sin(solvedAngle-sourceAngle),cos(solvedAngle-sourceAngle))
        let rigid = rigidMap(from:sourceWrist,to:w,angle:handAngle)
        let useWipeHand = wipePalm != nil && wipe > 0.18
        place(palm,palmOrigin,rigid);palm.opacity = useWipeHand ? 0 : 1
        if let wp = wipePalm {
            let wipeWrist = FixedLaughRig.point(705,728),wipeElbow = FixedLaughRig.point(790,840)
            let wipeAngle = solvedAngle-atan2(wipeWrist.y-wipeElbow.y,wipeWrist.x-wipeElbow.x)
            place(wp,wipeOrigin,rigidMap(from:wipeWrist,to:w,angle:wipeAngle));wp.opacity = useWipeHand ? 1 : 0
        }
        wrist = w;determinant = min(um.a*um.d-um.b*um.c,lm.a*lm.d-lm.b*lm.c)
        diagnostics = ["shoulder":[s.x,s.y],"elbow":[e.x,e.y],"wrist":[w.x,w.y],
            "minimumDeterminant":determinant,"cuffGap":hypot(sourceWrist.applying(lm).x-sourceWrist.applying(rigid).x,sourceWrist.applying(lm).y-sourceWrist.applying(rigid).y),"wristError":hypot(w.x-target.x,w.y-target.y),
            "handRigid":true,"palmOpacity":Double(palm.opacity),"wipePalmOpacity":Double(wipePalm?.opacity ?? 0),"handAngle":handAngle,"upperStretch":scale,"lowerStretch":scale]
    }
    private func rigidMap(from:CGPoint,to:CGPoint,angle:CGFloat)->CGAffineTransform {
        let c = cos(angle),s = sin(angle)
        return CGAffineTransform(a:c,b:s,c:-s,d:c,tx:to.x-c*from.x+s*from.y,ty:to.y-s*from.x-c*from.y)
    }
    private func bone(_ from:CGPoint,_ to:CGPoint,_ newFrom:CGPoint,_ newTo:CGPoint)->CGAffineTransform {
        let x = to.x-from.x,y = to.y-from.y,d = max(1,x*x+y*y)
        let nx = newTo.x-newFrom.x,ny = newTo.y-newFrom.y
        let a = (nx*x+ny*y)/d,b = (ny*x-nx*y)/d
        return CGAffineTransform(a:a,b:b,c:-b,d:a,tx:newFrom.x-a*from.x+b*from.y,ty:newFrom.y-b*from.x-a*from.y)
    }
    private func place(_ layer:CALayer,_ origin:CGPoint,_ map:CGAffineTransform) {
        layer.position = origin.applying(map);layer.setAffineTransform(CGAffineTransform(a:map.a,b:map.b,c:map.c,d:map.d,tx:0,ty:0))
    }
}
