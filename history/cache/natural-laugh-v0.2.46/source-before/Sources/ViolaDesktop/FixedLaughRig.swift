import AppKit
import QuartzCore

/// Frozen belly-laugh artwork and registration. Only entry/exit contacts are
/// sampled from the interactive rig; the main pose never reads its layout.
final class FixedLaughRig {
    static let revision = "fixed-belly-laugh-v1"
    struct Contact { let wrist: CGPoint; let angle: CGFloat; let sleeveMap: CGAffineTransform? }
    let root = CALayer()
    private struct HandPiece { let layer: CALayer; let origin: CGPoint; let wrist: CGPoint }
    private let leftSleeve: Sleeve
    private let rightSleeve: Sleeve
    private var leftHand: [HandPiece] = []
    private var rightHand: [HandPiece] = []
    private var entryLeft: Contact?
    private var entryRight: Contact?
    private var previousWeight: CGFloat = 0
    private var previousLeft: Contact?
    private var previousRight: Contact?
    private var returning = false
    private var returnStart: CGFloat = 0
    private var returnLeft: Contact?
    private var returnRight: Contact?
    private(set) var diagnostics: [String:Any] = [:]

    init?(canvasSize: CGSize) {
        let directory = CharacterAssets.bundledDirectory
        func load(_ name: String, crop: CGRect? = nil) -> CGImage? {
            guard let image = NSImage(contentsOf:directory.appendingPathComponent(name)),
                  let cg = image.cgImage(forProposedRect:nil,context:nil,hints:nil) else { return nil }
            return crop.flatMap { cg.cropping(to:$0) } ?? cg
        }
        guard let leftImage = load("frontal-arms-v0.2.5.png",crop:CGRect(x:210,y:0,width:440,height:590)),
              let rightImage = load("frontal-arms-v0.2.5.png",crop:CGRect(x:870,y:0,width:420,height:574)),
              let lap = load("resting_lap_arm-original-v0.2.31.png") else { return nil }
        let lf = CGRect(x:168.44,y:637.68,width:112,height:140.5859375)
        let ls = CGPoint(x:232.056,y:766.0659375)
        let axis = CGPoint(x:227.24-ls.x,y:637.68-ls.y)
        let length = hypot(axis.x,axis.y)
        let lw = CGPoint(x:227.24-axis.x/length*10,y:637.68-axis.y/length*10)
        leftSleeve = Sleeve(image:leftImage,frame:lf,sourceShoulder:ls,sourceWrist:lw,
            shoulder:CGPoint(x:267.2,y:741.6),widthGain:0.75)
        // Purple-only upper mouse sleeve; the lap hand owns the original cuff.
        let rf = CGRect(x:401,y:583.091796875+(1-574.0/750)*180.908203125,
            width:106,height:574.0/750*180.908203125)
        rightSleeve = Sleeve(image:rightImage,frame:rf,
            sourceShoulder:CGPoint(x:454,y:751.65),sourceWrist:CGPoint(x:454,y:626.509765625),
            shoulder:CGPoint(x:425.28,y:742.24),widthGain:0.70)
        root.anchorPoint = .zero; root.position = .zero
        root.bounds = CGRect(origin:.zero,size:canvasSize); root.contentsScale = 2
        root.addSublayer(leftSleeve.root); root.addSublayer(rightSleeve.root)
        // The complete open keyboard hand is assembled once at its original
        // registrations. No key pressure or mutable manifest enters these parts.
        let parts: [(String,CGRect)] = [
            ("left_palm",CGRect(x:201.64,y:602.48,width:58.24,height:36.48)),
            ("left_pinky",CGRect(x:202.28,y:571.12,width:23.04,height:42.24)),
            ("left_ring",CGRect(x:214.44,y:566.64,width:21.12,height:48)),
            ("left_middle",CGRect(x:224.68,y:566.64,width:21.76,height:47.36)),
            ("left_index",CGRect(x:234.92,y:571.12,width:19.84,height:42.88)),
            ("left_thumb",CGRect(x:243.24,y:585.84,width:17.92,height:33.92))]
        for (name,frame) in parts {
            guard let image = load(name+"-original-v0.2.29.png") else { return nil }
            leftHand.append(makeHand(image:image,frame:frame,wrist:CGPoint(x:227.24,y:637.68)))
        }
        // Isolate the painted right palm/cuff from the skirt, sleeve and hair.
        // Coordinates are frozen pixels in the original 221 x 348 extraction.
        guard let context = CGContext(data:nil,width:lap.width,height:lap.height,bitsPerComponent:8,
            bytesPerRow:lap.width*4,space:CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let outline: [CGPoint] = [CGPoint(x:0,y:314),CGPoint(x:12,y:297),CGPoint(x:30,y:285),
            CGPoint(x:73,y:275),CGPoint(x:89,y:257),CGPoint(x:111,y:249),CGPoint(x:133,y:252),
            CGPoint(x:147,y:266),CGPoint(x:153,y:286),CGPoint(x:144,y:301),CGPoint(x:111,y:310),
            CGPoint(x:76,y:315),CGPoint(x:39,y:329),CGPoint(x:8,y:339),CGPoint(x:0,y:336)]
        let path = CGMutablePath()
        for (i,p) in outline.enumerated() {
            let q = CGPoint(x:p.x,y:CGFloat(lap.height)-p.y)
            if i == 0 { path.move(to:q) } else { path.addLine(to:q) }
        }
        path.closeSubpath(); context.addPath(path); context.clip()
        context.draw(lap,in:CGRect(x:0,y:0,width:lap.width,height:lap.height))
        guard let hand = context.makeImage() else { return nil }
        rightHand.append(makeHand(image:hand,frame:CGRect(x:354.24,y:536.16,width:141.44,height:222.72),
            wrist:CGPoint(x:416.96,y:577.12)))
        root.isHidden = true
    }

    private func makeHand(image: CGImage, frame: CGRect, wrist: CGPoint) -> HandPiece {
        let layer = CALayer(); layer.anchorPoint = .zero
        layer.bounds = CGRect(origin:.zero,size:frame.size); layer.position = frame.origin
        layer.contents = image; layer.contentsGravity = .resize; layer.contentsScale = 2
        root.addSublayer(layer)
        return HandPiece(layer:layer,origin:frame.origin,wrist:wrist)
    }

    func render(weight rawWeight: Double, shoulderOffset: CGPoint, age: Double,
                reducedMotion: Bool, normalLeft: Contact, normalRight: Contact) {
        let weight = CGFloat(max(0,min(1,rawWeight)))
        let progress = Self.smooth(min(1,weight/0.35))
        let active = weight > 0
        if active && previousWeight == 0 {
            entryLeft = Self.relative(normalLeft,offset:shoulderOffset)
            entryRight = Self.relative(normalRight,offset:shoulderOffset)
            returning = false
        }
        if active && weight < previousWeight-0.00001 && !returning {
            returning = true; returnStart = weight
            returnLeft = previousLeft; returnRight = previousRight
        }
        let vibration = reducedMotion ? CGFloat(0) : CGFloat(sin(max(0,age)*2*Double.pi*6.5))*0.85
        let mainLeft = Contact(wrist:CGPoint(x:306+vibration,y:662+vibration*0.45),angle:1.3,sleeveMap:nil)
        // The lap hand already points left in the source art. This rotation
        // levels its fingers over the abdomen without curling them into a grip.
        let mainRight = Contact(wrist:CGPoint(x:399-vibration,y:652-vibration*0.35),angle:-0.45,sleeveMap:nil)
        var left = Self.mix(entryLeft ?? Self.relative(normalLeft,offset:shoulderOffset),mainLeft,progress)
        var right = Self.mix(entryRight ?? Self.relative(normalRight,offset:shoulderOffset),mainRight,progress)
        var sleeveProgress = progress
        if returning {
            let amount = Self.smooth(returnStart > 0 ? min(1,weight/returnStart) : 0)
            left = Self.mix(Self.relative(normalLeft,offset:shoulderOffset),returnLeft ?? mainLeft,amount)
            right = Self.mix(Self.relative(normalRight,offset:shoulderOffset),returnRight ?? mainRight,amount)
            sleeveProgress = amount
        }
        previousLeft = left; previousRight = right
        leftSleeve.render(contact:left,offset:shoulderOffset,progress:sleeveProgress,
            normalMap:normalLeft.sleeveMap,forearmAngle:left.angle,cuffOffset:.zero)
        rightSleeve.render(contact:right,offset:shoulderOffset,progress:sleeveProgress,
            normalMap:normalRight.sleeveMap,forearmAngle:-1.3,cuffOffset:CGPoint(x:0,y:20.48))
        func place(_ pieces: [HandPiece],_ contact: Contact) {
            let c = cos(contact.angle), s = sin(contact.angle)
            for piece in pieces {
                let d = CGPoint(x:piece.origin.x-piece.wrist.x,y:piece.origin.y-piece.wrist.y)
                piece.layer.position = CGPoint(x:contact.wrist.x+shoulderOffset.x+c*d.x-s*d.y,
                    y:contact.wrist.y+shoulderOffset.y+s*d.x+c*d.y)
                piece.layer.setAffineTransform(CGAffineTransform(a:c,b:s,c:-s,d:c,tx:0,ty:0))
            }
        }
        place(leftHand,left); place(rightHand,right)
        root.isHidden = !active; root.opacity = 1
        diagnostics = ["active":active,"revision":Self.revision,"weight":weight,
            "normalizedProgress":progress,"phase":returning ? "return" : (progress == 1 ? "main" : "entry"),
            "leftWrist":[left.wrist.x+shoulderOffset.x,left.wrist.y+shoulderOffset.y],
            "rightWrist":[right.wrist.x+shoulderOffset.x,right.wrist.y+shoulderOffset.y],
            "mainLeftWrist":[CGFloat(306),CGFloat(662)],"mainRightWrist":[CGFloat(399),CGFloat(652)],
            "leftAngle":left.angle,"rightAngle":right.angle,
            "leftHandAngle":left.angle,"rightHandAngle":right.angle,"handAngles":[left.angle,right.angle],
            "normalVisible":!active,"normalOpacity":active ? 0 : 1,"dedicatedOpacity":active ? 1 : 0,
            "left":leftSleeve.diagnostics,"right":rightSleeve.diagnostics,
            "minimumDeterminant":min(leftSleeve.minimumDeterminant,rightSleeve.minimumDeterminant),
            "cuffGap":max(leftSleeve.diagnostics["cuffGap"] as? CGFloat ?? 0,rightSleeve.diagnostics["cuffGap"] as? CGFloat ?? 0),"handRigid":true,"vibration":vibration,
            "poseKey":"abdomen-306x662-399x652-open-hands-v1",
            "artSignature":"bundled-frontal-v0.2.5-left-open-v0.2.29-right-lap-v0.2.31-fixed-mask-v1",
            "inputDependencies":["shoulderOffset","laughAge","laughWeight","reducedMotion"]]
        previousWeight = weight
        if !active { entryLeft = nil; entryRight = nil; returning = false }
    }

    private static func relative(_ c: Contact,offset: CGPoint) -> Contact {
        Contact(wrist:CGPoint(x:c.wrist.x-offset.x,y:c.wrist.y-offset.y),angle:c.angle,sleeveMap:c.sleeveMap)
    }
    private static func mix(_ a: Contact,_ b: Contact,_ t: CGFloat) -> Contact {
        let delta = atan2(sin(b.angle-a.angle),cos(b.angle-a.angle))
        return Contact(wrist:CGPoint(x:a.wrist.x+(b.wrist.x-a.wrist.x)*t,y:a.wrist.y+(b.wrist.y-a.wrist.y)*t),
            angle:a.angle+delta*t,sleeveMap:a.sleeveMap)
    }
    private static func smooth(_ value: CGFloat) -> CGFloat { let t = max(0,min(1,value)); return t*t*(3-2*t) }

    /// One opaque triangle mesh retains the same sleeve pixels from entry to
    /// the bent main pose. A rigid endpoint basis keeps the cuff contact fixed.
    private final class Sleeve {
        let root = CALayer()
        private struct Triangle { let layer: CALayer; let border: CAShapeLayer; let points: [CGPoint] }
        private let frame: CGRect
        private let sourceShoulder: CGPoint
        private let sourceWrist: CGPoint
        private let shoulder: CGPoint
        private let widthGain: CGFloat
        private var triangles: [Triangle] = []
        private(set) var diagnostics: [String:Any] = [:]
        private(set) var minimumDeterminant: CGFloat = 1
        init(image: CGImage,frame: CGRect,sourceShoulder: CGPoint,sourceWrist: CGPoint,shoulder: CGPoint,widthGain: CGFloat) {
            self.frame = frame; self.sourceShoulder = sourceShoulder; self.sourceWrist = sourceWrist
            self.shoulder = shoulder; self.widthGain = widthGain
            root.anchorPoint = .zero; root.position = .zero
            root.bounds = CGRect(x:0,y:0,width:800,height:1100)
            let rows = 36, columns = 4
            for row in 0..<rows { for column in 0..<columns {
                let x0 = CGFloat(column)/CGFloat(columns)*frame.width, x1 = CGFloat(column+1)/CGFloat(columns)*frame.width
                let y0 = CGFloat(row)/CGFloat(rows)*frame.height, y1 = CGFloat(row+1)/CGFloat(rows)*frame.height
                let p = [CGPoint(x:x0,y:y0),CGPoint(x:x1,y:y0),CGPoint(x:x1,y:y1),CGPoint(x:x0,y:y1)]
                for vertices in [[p[0],p[1],p[2]],[p[0],p[2],p[3]]] {
                    let layer = CALayer(); layer.anchorPoint = .zero; layer.position = .zero
                    layer.bounds = CGRect(origin:.zero,size:frame.size)
                    layer.contents = image; layer.contentsGravity = .resize; layer.contentsScale = 2
                    let mask = CAShapeLayer(), path = CGMutablePath()
                    path.move(to:vertices[0]); path.addLine(to:vertices[1]); path.addLine(to:vertices[2]); path.closeSubpath()
                    mask.path = path; mask.fillColor = NSColor.white.cgColor; mask.contentsScale = 2
                    let border = CAShapeLayer(); border.fillColor = NSColor.white.cgColor; border.contentsScale = 2
                    mask.addSublayer(border); layer.mask = mask; root.addSublayer(layer)
                    triangles.append(Triangle(layer:layer,border:border,points:vertices))
                }
            } }
        }
        func render(contact: Contact,offset: CGPoint,progress: CGFloat,normalMap: CGAffineTransform?,forearmAngle: CGFloat,cuffOffset: CGPoint) {
            let s = CGPoint(x:shoulder.x+offset.x,y:shoulder.y+offset.y)
            let handWrist = CGPoint(x:contact.wrist.x+offset.x,y:contact.wrist.y+offset.y)
            let c = cos(contact.angle), sn = sin(contact.angle)
            let w = CGPoint(x:handWrist.x+c*cuffOffset.x-sn*cuffOffset.y,
                y:handWrist.y+sn*cuffOffset.x+c*cuffOffset.y)
            let sourceLength = sourceShoulder.y-sourceWrist.y
            let direction = CGPoint(x:sin(forearmAngle),y:-cos(forearmAngle))
            let c1 = CGPoint(x:s.x+(shoulder.x < 350 ? -8 : 8),y:s.y-40)
            let c2 = CGPoint(x:w.x-direction.x*37,y:w.y-direction.y*37)
            let oldMap = contact.sleeveMap ?? normalMap
            let oldJoin = oldMap.map { sourceWrist.applying($0) } ?? w
            let oldShoulder = oldMap.map { sourceShoulder.applying($0) } ?? s
            let shoulderCorrection = CGPoint(x:s.x-oldShoulder.x,y:s.y-oldShoulder.y)
            let joinCorrection = CGPoint(x:w.x-oldJoin.x,y:w.y-oldJoin.y)
            func mapped(_ p: CGPoint) -> CGPoint {
                let world = CGPoint(x:p.x+frame.minX,y:p.y+frame.minY)
                let t = (sourceShoulder.y-world.y)/sourceLength
                let u = max(0,min(1,t)), v = 1-u
                var center = CGPoint(x:v*v*v*s.x+3*v*v*u*c1.x+3*v*u*u*c2.x+u*u*u*w.x,
                    y:v*v*v*s.y+3*v*v*u*c1.y+3*v*u*u*c2.y+u*u*u*w.y)
                var tangent = CGPoint(x:3*v*v*(c1.x-s.x)+6*v*u*(c2.x-c1.x)+3*u*u*(w.x-c2.x),
                    y:3*v*v*(c1.y-s.y)+6*v*u*(c2.y-c1.y)+3*u*u*(w.y-c2.y))
                let length = max(0.001,hypot(tangent.x,tangent.y)); tangent.x /= length; tangent.y /= length
                if t < 0 { center.x += tangent.x*t*sourceLength; center.y += tangent.y*t*sourceLength }
                if t > 1 { center.x += direction.x*(t-1)*sourceLength; center.y += direction.y*(t-1)*sourceLength; tangent = direction }
                let axisX = sourceShoulder.x+(sourceWrist.x-sourceShoulder.x)*u
                let across = world.x-axisX
                let width = 1-(1-widthGain)*pow(sin(.pi*u),2)
                // Preserve the complete shoulder width, then turn the fabric
                // rings gradually toward the forearm. Only the inner elbow
                // gathers; shoulder and cuff keep their source cross-sections.
                let ringAngle = forearmAngle*u
                let transverse = CGPoint(x:cos(ringAngle),y:sin(ringAngle))
                let bent = CGPoint(x:center.x+transverse.x*across*width,y:center.y+transverse.y*across*width)
                guard let oldMap, progress < 1 else { return bent }
                let registered = world.applying(oldMap)
                let old = CGPoint(x:registered.x+shoulderCorrection.x*(1-u)+joinCorrection.x*u,
                    y:registered.y+shoulderCorrection.y*(1-u)+joinCorrection.y*u)
                return CGPoint(x:old.x+(bent.x-old.x)*progress,y:old.y+(bent.y-old.y)*progress)
            }
            minimumDeterminant = .greatestFiniteMagnitude
            for triangle in triangles {
                let q = triangle.points.map(mapped)
                let map = Self.affine(triangle.points,q)
                triangle.layer.setAffineTransform(map)
                minimumDeterminant = min(minimumDeterminant,map.a*map.d-map.b*map.c)
                let path = CGMutablePath(); path.move(to:q[0]); path.addLine(to:q[1]); path.addLine(to:q[2]); path.closeSubpath()
                var inverse = map.inverted()
                triangle.border.path = path.copy(strokingWithWidth:0.9,lineCap:.round,lineJoin:.round,miterLimit:2).copy(using:&inverse)
            }
            let projectedWrist = mapped(CGPoint(x:sourceWrist.x-frame.minX,y:sourceWrist.y-frame.minY))
            let cuffGap = hypot(projectedWrist.x-w.x,projectedWrist.y-w.y)
            diagnostics = ["mode":"fixed-bent-sleeve","shoulder":[s.x,s.y],"wrist":[handWrist.x,handWrist.y],"sleeveJoin":[w.x,w.y],
                "requestedWrist":[w.x,w.y],"wristError":cuffGap,"cuffGap":cuffGap,
                "handAngle":forearmAngle,"cuffRigid":true,"minimumDeterminant":minimumDeterminant,
                "minimumTriangleDeterminant":minimumDeterminant,"triangleCount":triangles.count]
        }
        private static func affine(_ p: [CGPoint],_ q: [CGPoint]) -> CGAffineTransform {
            let ux = p[1].x-p[0].x, uy = p[1].y-p[0].y, vx = p[2].x-p[0].x, vy = p[2].y-p[0].y
            let det = ux*vy-uy*vx
            let ax = q[1].x-q[0].x, ay = q[1].y-q[0].y, bx = q[2].x-q[0].x, by = q[2].y-q[0].y
            let a = (ax*vy-bx*uy)/det, c = (bx*ux-ax*vx)/det
            let b = (ay*vy-by*uy)/det, d = (by*ux-ay*vx)/det
            return CGAffineTransform(a:a,b:b,c:c,d:d,tx:q[0].x-a*p[0].x-c*p[0].y,ty:q[0].y-b*p[0].x-d*p[0].y)
        }
    }
}
