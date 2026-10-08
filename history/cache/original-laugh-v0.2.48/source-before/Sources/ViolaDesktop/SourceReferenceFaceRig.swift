import AppKit
import QuartzCore
import ViolaCore

/// Facial patches are registered to the supplied portrait. Each eyelid retains
/// the source lashes and skin texture throughout closure, including half blinks.

final class SourceReferenceFaceRig {
    let root = CALayer()
    private let rider = CALayer()
    private let friend = CALayer()
    private let hearts = CALayer()
    private let friendEffort = CALayer()
    private let friendSweat = CALayer()
    private let laughCrownCover = CALayer()
    private let friendEffortBrows = CAShapeLayer()
    private let friendEffortMouth = CAShapeLayer()
    private let mouth = CALayer()
    private let mouthCover = CALayer()
    private let mouthInterior = CAShapeLayer()
    private let teeth = CAShapeLayer()
    private let tongue = CAShapeLayer()
    private let smileLip = CAShapeLayer()
    private let toothClip = CAShapeLayer()
    private let tongueClip = CAShapeLayer()
    private var riderEyes: [SourceEyePatch] = []
    private var friendEyes: [SourceEyePatch] = []
    private var brows: [SourceBrowPatch] = []
    private(set) var diagnostics: [String: Double] = [:]

    init(canvasSize: CGSize, images: [String:CGImage], definitions: [String:SpriteDefinition]) {
        for layer in [root,rider,friend,hearts,mouth,friendEffort,friendSweat,laughCrownCover] {
            layer.bounds = CGRect(origin:.zero,size:canvasSize)
            layer.anchorPoint = .zero; layer.position = .zero; layer.contentsScale = 2
            layer.actions = ["contents":NSNull(),"position":NSNull(),"opacity":NSNull(),"transform":NSNull(),"path":NSNull()]
        }
        root.addSublayer(friend); root.addSublayer(rider)
        friend.addSublayer(hearts); rider.addSublayer(mouth)
        if let image = images["head"], let definition = definitions["head"] {
            let source = SourceFacePixels(image:image,frame:definition.frame)
            riderEyes = [
                SourceEyePatch(source:source,top:[[378,202],[392,195],[418,194],[433,204]],bottom:[[378,207],[395,221],[418,225],[433,210]],closed:[[378,205],[393,217],[419,220],[433,208]]),
                SourceEyePatch(source:source,top:[[453,193],[469,182],[492,178],[506,185]],bottom:[[453,198],[468,213],[492,212],[506,196]],closed:[[453,197],[469,210],[491,210],[506,190]])
            ]
            // Only the visible source eyebrow strokes move; bangs stay anchored.
            brows = [SourceBrowPatch(source:source,points:[[384,190],[394,187],[405,189]]),
                     SourceBrowPatch(source:source,points:[[456,180],[471,173],[488,174]])]
            configureMouth(source:source)
        }
        if let image = images["seating"], let definition = definitions["seating"] {
            let source = SourceFacePixels(image:image,frame:definition.frame)
            configureFriendEffort(source:source)
            // The old extraction retains fingertips under the normal head-pat
            // arm. Only the laugh uncovers them; clone adjacent original hair.
            let crownRect = CGRect(x:285,y:590,width:145,height:145)
            laughCrownCover.frame = Self.frame(crownRect)
            let crownURL = CharacterAssets.bundledDirectory.appendingPathComponent("friend-natural-crown-v0.2.46.png")
            let crown = NSImage(contentsOf:crownURL)?.cgImage(forProposedRect:nil,context:nil,hints:nil)
            laughCrownCover.contents = crown ?? source.laughCrownPatch(rect:crownRect)
            let mask = CALayer(); mask.frame = laughCrownCover.bounds
            mask.contents = NSImage(contentsOf:CharacterAssets.bundledDirectory.appendingPathComponent("friend-natural-crown-mask-v0.2.46.png"))?.cgImage(forProposedRect:nil,context:nil,hints:nil)
            laughCrownCover.mask = mask
            friend.addSublayer(laughCrownCover)
            friendEyes = [
                SourceEyePatch(source:source,top:[[290,780],[303,765],[329,764],[340,775]],bottom:[[290,781],[303,795],[330,800],[340,780]],closed:[[291,782],[306,794],[329,796],[340,778]],style:.friend,cleanupTop:[[283,776],[307,765],[333,759],[353,769]],cleanupBottom:[[283,781],[308,800],[334,802],[353,783]]),
                SourceEyePatch(source:source,top:[[387,761],[403,751],[421,743],[433,745]],bottom:[[387,765],[404,783],[423,779],[433,752]],closed:[[387,764],[401,777],[422,771],[433,749]],style:.friend,cleanupTop:[[378,757],[397,745],[424,737],[440,739]],cleanupBottom:[[378,764],[397,784],[425,776],[440,756]])
            ]
        }
        riderEyes.forEach { rider.addSublayer($0.layer) }
        friendEyes.forEach { friend.addSublayer($0.layer) }
        friend.addSublayer(friendEffort)
        configureFriendSweat()
        friend.addSublayer(friendSweat)
        brows.forEach { rider.addSublayer($0.layer) }
        // The mouth is above the eye patches only to keep all expression details
        // in the same rider transform; their registered regions do not overlap.
        rider.addSublayer(mouth)
        addHeart(at:CGPoint(x:325,y:780),size:12)
        addHeart(at:CGPoint(x:415,y:760),size:13)
    }

    func render(blink: Double, laugh: Double, expression: FriendExpression, opacity: Double,
                seatX: Double, torsoY: Double, support: CGAffineTransform,
                friendBlink: Double? = nil, laughAge: Double = 0, desksVisible: Bool = true) {
        rider.position = CGPoint(x:seatX,y:torsoY)
        // The painted laugh owns its face; keep these original face patches
        // only for the normal portrait and for the independent friend.
        rider.opacity = Float(1-Self.ease(laugh))
        friend.setAffineTransform(support)
        let joy = Self.ease(laugh), isLaughing = joy > 0.0001
        // Normal blinks may fully seal. The fixed laugh has its own partial-lid
        // shape, including when the unrelated idle blink reaches its peak.
        let normalRiderClosure = Self.ease(blink)
        let riderClosure = isLaughing
            ? joy*FixedLaughFaceIdentity.riderClosure
                + (1-joy)*min(normalRiderClosure,FixedLaughFaceIdentity.riderClosure)
            : normalRiderClosure
        riderEyes.forEach { $0.render(closure:riderClosure,joy:joy) }
        let effort = isLaughing ? joy*(FixedLaughFaceIdentity.effortBase+FixedLaughFaceIdentity.effortPulse*FixedLaughMotion.pulse(age:laughAge)) : (expression == .effort ? Self.ease(opacity) : 0)
        let normalFriendClosure = Self.ease(friendBlink ?? blink)
        let friendClosure = isLaughing
            ? joy*FixedLaughFaceIdentity.friendClosure
                + (1-joy)*min(normalFriendClosure,FixedLaughFaceIdentity.friendClosure)
            : effort > 0.0001 ? 0 : normalFriendClosure
        friendEyes.forEach { $0.render(closure:friendClosure,joy:0) }
        renderFriendEffort(effort:effort,tension:isLaughing ? FixedLaughFaceIdentity.friendBrowTension : 4)
        friendSweat.opacity = Float(joy*FixedLaughFaceIdentity.sweatOpacity)
        laughCrownCover.opacity = Float(joy)
        hearts.opacity = !isLaughing && expression == .hearts ? Float(opacity) : 0
        brows.forEach { $0.render(joy:joy) }
        renderMouth(joy:joy,age:laughAge)
        diagnostics = ["riderClosure":riderClosure,"friendClosure":friendClosure,
                       "friendEffort":effort,"friendBrowTension":(isLaughing ? FixedLaughFaceIdentity.friendBrowTension : 4)*effort,"friendMouthPress":effort,
                       "friendSweatOpacity":Double(friendSweat.opacity),
                       "friendSweatDropCount":isLaughing ? Double(FixedLaughFaceIdentity.sweatDropCount) : 0,
                       "heartsOpacity":Double(hearts.opacity),
                       "eyelidClosure":riderClosure,"mouthOpen":isLaughing ? Self.mouthDepth(joy:joy,age:laughAge) : 0,
                       "joy":joy,"browLift":1.7*joy,
                       "fixedLaughFaceRevision":FixedLaughFaceIdentity.revision,
                       "fixedLaughRiderClosure":FixedLaughFaceIdentity.riderClosure,
                       "fixedLaughFriendClosure":FixedLaughFaceIdentity.friendClosure,
                       "fixedLaughMouthHalfWidth":FixedLaughFaceIdentity.mouthHalfWidth,
                       "fixedLaughMouthDepth":FixedLaughFaceIdentity.mouthDepth,
                       "fixedLaughSweatOpacity":FixedLaughFaceIdentity.sweatOpacity]
    }

    fileprivate static func world(_ p: CGPoint) -> CGPoint { CGPoint(x:24+0.64*p.x,y:940-0.64*p.y) }
    fileprivate static func frame(_ rect: CGRect) -> CGRect {
        CGRect(x:24+0.64*rect.minX,y:940-0.64*rect.maxY,width:rect.width*0.64,height:rect.height*0.64)
    }
    private static func ease(_ value: Double) -> Double {
        let t = min(1,max(0,value)); return t*t*(3-2*t)
    }
    private static func mouthDepth(joy: Double, age: Double) -> Double {
        (0.6+(FixedLaughFaceIdentity.mouthDepth-0.6)*joy)
            * (FixedLaughFaceIdentity.mouthBeatCenter
                + FixedLaughFaceIdentity.mouthBeatAmplitude*cos(age*FixedLaughFaceIdentity.mouthBeatFrequency))
    }
    private func configureFriendSweat() {
        // Registered source coordinates keep both drops attached to her face,
        // inside the same support transform as the original purple-haired head.
        // The small opaque color is faded by the parent instead of becoming a
        // conspicuous effect; her pressed mouth and eyes carry the expression.
        for (center,size) in [(CGPoint(x:431,y:801),CGSize(width:3.6,height:6.2)),
                              (CGPoint(x:441,y:780),CGSize(width:2.5,height:4.4))] {
            let path = CGMutablePath()
            path.move(to:Self.world(CGPoint(x:center.x,y:center.y-size.height*0.5)))
            path.addCurve(to:Self.world(CGPoint(x:center.x,y:center.y+size.height*0.5)),
                control1:Self.world(CGPoint(x:center.x-size.width*0.8,y:center.y+size.height*0.1)),
                control2:Self.world(CGPoint(x:center.x-size.width*0.6,y:center.y+size.height*0.5)))
            path.addCurve(to:Self.world(CGPoint(x:center.x,y:center.y-size.height*0.5)),
                control1:Self.world(CGPoint(x:center.x+size.width*0.6,y:center.y+size.height*0.5)),
                control2:Self.world(CGPoint(x:center.x+size.width*0.8,y:center.y+size.height*0.1)))
            path.closeSubpath()
            let drop = CAShapeLayer(); drop.path = path
            drop.fillColor = NSColor(calibratedRed:0.60,green:0.79,blue:0.91,alpha:1).cgColor
            drop.strokeColor = NSColor(calibratedRed:0.44,green:0.63,blue:0.76,alpha:0.75).cgColor
            drop.lineWidth = 0.35; friendSweat.addSublayer(drop)
        }
        friendSweat.opacity = 0
    }
    private func configureFriendEffort(source: SourceFacePixels) {
        // Cover only the original warm brow strokes. Purple bang pixels and
        // the supplied open eyes stay in the source sprite throughout effort.
        for points in [[[292.0,749],[302,746],[313,743]],[[389.0,726],[405,722],[420,721]]] {
            let rect = CGRect(x:points[0][0]-3,y:points.map { $0[1] }.min()!-3,
                width:points[2][0]-points[0][0]+6,height:points.map { $0[1] }.max()!-points.map { $0[1] }.min()!+6)
            let cover = CALayer(); cover.frame = Self.frame(rect)
            cover.contents = source.warmStrokeCover(rect:rect,points:points)
            friendEffort.addSublayer(cover)
        }
        let cover = CALayer(), rect = CGRect(x:361,y:820,width:29,height:16)
        cover.frame = Self.frame(rect)
        cover.contents = source.cleanedPatch(rect:rect,center:CGPoint(x:375,y:827),
            radius:CGSize(width:13,height:5),donorOffset:-8)
        friendEffort.addSublayer(cover)
        for stroke in [friendEffortBrows,friendEffortMouth] {
            stroke.bounds = root.bounds; stroke.anchorPoint = .zero; stroke.position = .zero
            stroke.actions = ["path":NSNull(),"opacity":NSNull()]
            friendEffort.addSublayer(stroke)
        }
        friendEffortBrows.fillColor = nil
        friendEffortBrows.strokeColor = NSColor(calibratedRed:0.49,green:0.30,blue:0.32,alpha:0.8).cgColor
        friendEffortBrows.lineWidth = 0.75; friendEffortBrows.lineCap = .round
        let browMask = CALayer(), browRect = CGRect(x:286,y:716,width:140,height:39)
        browMask.frame = Self.frame(browRect)
        browMask.contents = source.warmSkinMask(rect:browRect)
        friendEffortBrows.mask = browMask
        friendEffortMouth.fillColor = NSColor(calibratedRed:0.99,green:0.94,blue:0.87,alpha:1).cgColor
        friendEffortMouth.strokeColor = NSColor(calibratedRed:0.53,green:0.33,blue:0.33,alpha:0.85).cgColor
        friendEffortMouth.lineWidth = 0.6; friendEffortMouth.lineJoin = .round
        friendEffort.opacity = 0
    }
    private func renderFriendEffort(effort: Double, tension: Double) {
        friendEffort.opacity = Float(effort)
        guard effort > 0.0001 else { return }
        let e = CGFloat(effort), brows = CGMutablePath()
        brows.move(to:Self.world(CGPoint(x:292,y:749)))
        brows.addQuadCurve(to:Self.world(CGPoint(x:313,y:743+3*e*CGFloat(tension/4))),
            control:Self.world(CGPoint(x:302,y:746+e)))
        brows.move(to:Self.world(CGPoint(x:389,y:726+CGFloat(tension)*e)))
        brows.addQuadCurve(to:Self.world(CGPoint(x:420,y:721)),
            control:Self.world(CGPoint(x:405,y:722+e)))
        friendEffortBrows.path = brows
        // A small pressed tooth slit and tightened corners read as exertion
        // while keeping the original mouth's modest scale and tilt.
        let mouth = CGMutablePath()
        mouth.move(to:Self.world(CGPoint(x:363,y:829)))
        mouth.addQuadCurve(to:Self.world(CGPoint(x:386,y:826)),control:Self.world(CGPoint(x:375,y:823)))
        mouth.addQuadCurve(to:Self.world(CGPoint(x:363,y:829)),control:Self.world(CGPoint(x:375,y:830)))
        mouth.closeSubpath(); friendEffortMouth.path = mouth
    }
    private func configureMouth(source: SourceFacePixels) {
        let rect = CGRect(x:434,y:243,width:36,height:31)
        mouthCover.frame = Self.frame(rect)
        mouthCover.contents = source.cleanedPatch(rect:rect,center:CGPoint(x:451,y:252),radius:CGSize(width:16,height:7),donorOffset:-10)
        mouth.addSublayer(mouthCover)
        for layer in [mouthInterior,teeth,tongue,smileLip] {
            layer.bounds = root.bounds; layer.anchorPoint = .zero; layer.position = .zero
            layer.actions = ["path":NSNull(),"opacity":NSNull()]
            mouth.addSublayer(layer)
        }
        mouthInterior.fillColor = NSColor(calibratedRed:0.29,green:0.12,blue:0.15,alpha:1).cgColor
        mouthInterior.strokeColor = NSColor(calibratedRed:0.47,green:0.24,blue:0.25,alpha:1).cgColor
        mouthInterior.lineWidth = 0.65
        teeth.fillColor = NSColor(calibratedRed:1,green:0.95,blue:0.90,alpha:1).cgColor
        teeth.mask = toothClip; tongue.mask = tongueClip
        for clip in [toothClip,tongueClip] { clip.fillColor = NSColor.black.cgColor; clip.actions = ["path":NSNull()] }
        tongue.fillColor = NSColor(calibratedRed:0.84,green:0.46,blue:0.49,alpha:1).cgColor
        smileLip.fillColor = nil; smileLip.strokeColor = NSColor(calibratedRed:0.76,green:0.45,blue:0.44,alpha:0.65).cgColor
        smileLip.lineWidth = 0.55; smileLip.lineCap = .round
    }
    private func renderMouth(joy: Double, age: Double) {
        // Fully remove every overlay at zero: the supplied mouth remains exact.
        mouth.opacity = Float(min(1,joy*6))
        guard joy > 0.0001 else { return }
        let j = CGFloat(joy)
        let half = 10.5 + (FixedLaughFaceIdentity.mouthHalfWidth-10.5)*j
        let depth = CGFloat(Self.mouthDepth(joy:joy,age:age))
        let left = CGPoint(x:451-half,y:253-3*j)
        let right = CGPoint(x:451+half,y:251-4*j)
        let upper = CGPoint(x:451,y:255-1.5*j)
        let bottom = CGPoint(x:451,y:255+depth)
        func path(_ points: [CGPoint]) -> CGMutablePath {
            let result = CGMutablePath(); result.move(to:Self.world(points[0]))
            result.addQuadCurve(to:Self.world(points[2]),control:Self.world(points[1]))
            result.addQuadCurve(to:Self.world(points[0]),control:Self.world(points[3])); result.closeSubpath()
            return result
        }
        mouthInterior.path = path([left,upper,right,bottom])
        toothClip.path = mouthInterior.path; tongueClip.path = mouthInterior.path
        // The tooth strip follows the same smiling upper arc; it grows gradually
        // with the mouth instead of appearing as a separate binary expression.
        teeth.path = path([CGPoint(x:left.x+2,y:left.y+0.7),upper,
                          CGPoint(x:right.x-2,y:right.y+0.7),CGPoint(x:451,y:upper.y+3.5*j)])
        teeth.opacity = Float(min(1,joy*2))
        tongue.path = path([CGPoint(x:446,y:255+depth*0.25),CGPoint(x:451,y:255+depth*0.15),
                           CGPoint(x:458,y:255+depth*0.25),CGPoint(x:451,y:255+depth*0.55)])
        tongue.opacity = Float(joy)
        let lip = CGMutablePath(); lip.move(to:Self.world(CGPoint(x:left.x+2,y:left.y+depth*0.25)))
        lip.addQuadCurve(to:Self.world(CGPoint(x:right.x-2,y:right.y+depth*0.25)),control:Self.world(CGPoint(x:451,y:256+depth)))
        smileLip.path = lip
    }
    private func addHeart(at source: CGPoint, size: CGFloat) {
        let path = CGMutablePath(); path.move(to:CGPoint(x:0,y:-0.5))
        path.addCurve(to:CGPoint(x:-0.48,y:0.12),control1:CGPoint(x:-0.18,y:-0.27),control2:CGPoint(x:-0.52,y:-0.04))
        path.addCurve(to:CGPoint(x:0,y:0.23),control1:CGPoint(x:-0.45,y:0.48),control2:CGPoint(x:-0.12,y:0.47))
        path.addCurve(to:CGPoint(x:0.48,y:0.12),control1:CGPoint(x:0.12,y:0.47),control2:CGPoint(x:0.45,y:0.48))
        path.addCurve(to:CGPoint(x:0,y:-0.5),control1:CGPoint(x:0.52,y:-0.04),control2:CGPoint(x:0.18,y:-0.27))
        path.closeSubpath(); var scale = CGAffineTransform(scaleX:size*0.64,y:size*0.64)
        let layer = CAShapeLayer(); layer.path = path.copy(using:&scale); layer.position = Self.world(source)
        layer.fillColor = NSColor(calibratedRed:1,green:0.7,blue:0.85,alpha:1).cgColor
        layer.strokeColor = NSColor(calibratedRed:0.51,green:0.27,blue:0.49,alpha:1).cgColor
        layer.lineWidth = 0.65; hearts.addSublayer(layer)
    }
}

/// Source sampler uses the sprite's registered frame, so cropped head textures
/// and the full seating texture share the portrait's original pixel coordinates.
private final class SourceFacePixels {
    private let bitmap: NSBitmapImageRep
    private let frame: CGRect
    init(image: CGImage, frame: CGRect) { bitmap = NSBitmapImageRep(cgImage:image); self.frame = frame }
    func pixel(_ x: Double, _ y: Double) -> [UInt8] {
        let p = SourceReferenceFaceRig.world(CGPoint(x:x,y:y))
        let ix = max(0,min(bitmap.pixelsWide-1,Int(((p.x-frame.minX)/frame.width*CGFloat(bitmap.pixelsWide)).rounded())))
        let iy = max(0,min(bitmap.pixelsHigh-1,Int(((frame.maxY-p.y)/frame.height*CGFloat(bitmap.pixelsHigh)).rounded())))
        guard let c = bitmap.colorAt(x:ix,y:iy)?.usingColorSpace(.sRGB) else { return [0,0,0,0] }
        return [UInt8(max(0,min(255,c.redComponent*255))),UInt8(max(0,min(255,c.greenComponent*255))),UInt8(max(0,min(255,c.blueComponent*255))),UInt8(max(0,min(255,c.alphaComponent*255)))]
    }
    func laughCrownPatch(rect: CGRect) -> CGImage? {
        var output: [UInt8] = []
        for y in 0..<Int(rect.height) { for x in 0..<Int(rect.width) {
            let sx = rect.minX+Double(x), sy = rect.minY+Double(y)
            let distance = hypot((sx-350)/43,(sy-646)/40)
            let original = pixel(sx,sy)
            let warm = min(1,max(0,(Double(Int(original[0])-Int(original[2]))-10)/24))
                * min(1,max(0,(Double(original[0])-110)/50))
            let alpha = min(1,max(0,(1.05-distance)*9))*warm
            // Healthy original crown strands on the right fill the small hand
            // remnant. Keep their painted colors and texture without smoothing.
            let donor = pixel(416+(sx-350)*0.45,sy+20)
            output += [donor[0],donor[1],donor[2],UInt8(255*alpha)]
        }}
        return Self.image(output,width:Int(rect.width),height:Int(rect.height))
    }
    func cleanedPatch(rect: CGRect, center: CGPoint, radius: CGSize, donorOffset: Double) -> CGImage? {
        var pixels = [UInt8](); pixels.reserveCapacity(Int(rect.width*rect.height)*4)
        for y in 0..<Int(rect.height) { for x in 0..<Int(rect.width) {
            let sx = Double(rect.minX)+Double(x), sy = Double(rect.minY)+Double(y)
            let distance = hypot((sx-center.x)/radius.width,(sy-center.y)/radius.height)
            let weight = max(0,min(1,(1.15-distance)*5))
            let original = pixel(sx,sy), donor = pixel(sx,sy+donorOffset)
            var mixed = (0..<4).map { UInt8(Double(original[$0])*(1-weight)+Double(donor[$0])*weight) }
            mixed[3] = UInt8(Double(original[3])*weight); pixels += mixed
        }}
        return Self.image(pixels,width:Int(rect.width),height:Int(rect.height))
    }
    func warmSkinMask(rect: CGRect) -> CGImage? {
        var output: [UInt8] = []
        for y in 0..<Int(rect.height) { for x in 0..<Int(rect.width) {
            let color = pixel(rect.minX+Double(x),rect.minY+Double(y))
            let bright = max(0,min(1,(Double(color[0])-180)/35))
            let warm = max(0,min(1,Double(Int(color[0])-Int(color[2])-8)/12))
            output += [255,255,255,UInt8(255*bright*warm)]
        }}
        return Self.image(output,width:Int(rect.width),height:Int(rect.height))
    }
    func warmStrokeCover(rect: CGRect, points: [[Double]]) -> CGImage? {
        var output: [UInt8] = []
        for y in 0..<Int(rect.height) { for x in 0..<Int(rect.width) {
            let sx = rect.minX+Double(x), sy = rect.minY+Double(y)
            let t = max(0,min(1,(sx-points[0][0])/(points[2][0]-points[0][0])))
            let u = 1-t, line = u*u*points[0][1]+2*u*t*points[1][1]+t*t*points[2][1]
            let original = pixel(sx,sy)
            var donor = pixel(sx,line-5)
            if donor[0] < 185 || Int(donor[0])-Int(donor[2]) < 8 { donor = pixel(sx,line+4) }
            let warm = max(0,min(1,Double(Int(original[0])-Int(original[2])-3)/8))
            let safeDonor = donor[0] > 185 && Int(donor[0])-Int(donor[2]) > 8
            let hair = Int(original[2])-Int(original[1]) > 12 && Int(original[0])-Int(original[2]) < 25
            let alpha = max(0,min(1,(2.5-abs(sy-line))*0.8))
                * max(0,min(1,min(t,1-t)*12))*warm*(safeDonor && !hair ? 1 : 0)
            donor[3] = UInt8(Double(original[3])*alpha); output += donor
        }}
        return Self.image(output,width:Int(rect.width),height:Int(rect.height))
    }
    static func image(_ pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data:Data(pixels) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),
            provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }
}

private final class SourceEyePatch {
    enum Style { case rider, friend }
    private let style: Style
    let layer = CALayer()
    private let rect: CGRect
    private let top: [[Double]], bottom: [[Double]], closed: [[Double]]
    private let width: Int, height: Int
    private var original: [UInt8] = [], clean: [UInt8] = []
    private var affected: [Double] = []
    private var cache: [Int:CGImage] = [:]
    init(source: SourceFacePixels, top: [[Double]], bottom: [[Double]], closed: [[Double]], style: Style = .rider, cleanupTop: [[Double]]? = nil, cleanupBottom: [[Double]]? = nil) {
        self.style = style
        self.top = top; self.bottom = bottom; self.closed = closed
        let matteTop = cleanupTop ?? top, matteBottom = cleanupBottom ?? bottom
        let minX = floor(matteTop[0][0])-4, maxX = ceil(matteTop[3][0])+4
        let minY = floor(matteTop.map { $0[1] }.min()!)-5
        let maxY = ceil(matteBottom.map { $0[1] }.max()!)+5
        rect = CGRect(x:minX,y:minY,width:maxX-minX,height:maxY-minY)
        width = Int(rect.width); height = Int(rect.height)
        layer.frame = SourceReferenceFaceRig.frame(rect); layer.contentsScale = 2
        layer.actions = ["contents":NSNull(),"opacity":NSNull()]
        // Only warm, bright pixels outside the eye can supply lid skin.
        // Sampling an entire cheek column also samples hair at the outer corner.
        var skinColumns: [[(Double,Double,[UInt8])]] = []
        for x in 0..<width {
            let sx = minX+Double(x)
            let t = max(0,min(1,(sx-matteTop[0][0])/(matteTop[3][0]-matteTop[0][0])))
            let a = Self.curve(matteTop,t), b = Self.curve(matteBottom,t)
            var samples: [(Double,Double,[UInt8])] = []
            for dx in [-12.0,-8,-4,0,4,8,12] {
                for dy in [9.0,13,17,21] {
                    let donorX = sx+dx, donorY = b+dy
                    let color = source.pixel(donorX,donorY)
                    if Self.isSkin(color) { samples.append((donorX,donorY,color)) }
                }
                for dy in [-10.0,-7] {
                    let donorX = sx+dx, donorY = a+dy
                    let color = source.pixel(donorX,donorY)
                    if Self.isSkin(color) { samples.append((donorX,donorY,color)) }
                }
            }
            if samples.isEmpty {
                let donorX = (top[0][0]+top[3][0])*0.5, donorY = b+15
                samples.append((donorX,donorY,source.pixel(donorX,donorY)))
            }
            skinColumns.append(samples)
        }
        let friendHair = style == .friend ? Self.friendHairMask(source:source,rect:rect,top:top) : []
        var skinField: [Double] = []
        for y in 0..<height { for x in 0..<width {
            let sx = minX+Double(x), sy = minY+Double(y)
            let t = max(0,min(1,(sx-matteTop[0][0])/(matteTop[3][0]-matteTop[0][0])))
            let a = Self.curve(matteTop,t), b = Self.curve(matteBottom,t)
            var feather = Self.mask(x:sx,y:sy,left:matteTop[0][0],right:matteTop[3][0],top:a-5,bottom:b+2+5*sin(.pi*t))
            let pixel = source.pixel(sx,sy)
            // Preserve the source bangs above the upper lash and the painted
            // hair silhouette under either eye corner, rather than recolor it.
            let dark = (pixel.prefix(3).max() ?? 255) < 165
            if style == .rider, dark, sy > b+1 { feather = 0 }
            if style == .rider, dark, sy < a+0.5 {
                // Rider hair is olive/brown (blue below green); the actual
                // upper lash is plum or neutral. Require a positive olive
                // margin, with a soft transition; neutral lash edge pixels must
                // not be mistaken for bangs and survive as a dotted outline.
                let oliveMargin = Double(Int(pixel[1])-Int(pixel[2]))
                let hairProtection = max(0,min(1,(oliveMargin-4)/8))
                if top[0][1] >= 300 { feather = 0 }
                else { feather *= 1-hairProtection }
            }
            if style == .rider, top[0][0] < 400 {
                let cheekEdge = top[0][0]+max(0,sy-top[0][1]-2)*0.92
                feather *= max(0,min(1,(sx-cheekEdge)/3))
            }
            if style == .friend {
                // The registered eye ends stop inside the painted hairline.
                // Protect purple bang pixels above the source upper lash;
                // neutral/plum lash pixels remain inside the eye removal matte.
                let purple = Double(Int(pixel[2])-Int(pixel[0]))
                feather *= 1-friendHair[y*width+x]
                if sy > b+1, !Self.isSkin(pixel), purple > 3 { feather = 0 }
                // Bound outer corners to the actual source face outline.
                if top[0][0] < 350 {
                    let faceEdge = 289+max(0,sy-780)*0.88
                    feather *= max(0,min(1,(sx-faceEdge+1)/2))
                } else {
                    feather *= max(0,min(1,(435-max(0,sy-750)*0.12-sx)/2))
                }
            }
            var donor = [Double](repeating:0,count:4), totalWeight = 0.0
            for sample in skinColumns[x] {
                let dx = sample.0-sx, dy = sample.1-sy
                let weight = 1/(dx*dx+dy*dy+16)
                totalWeight += weight
                for channel in 0..<4 { donor[channel] += Double(sample.2[channel])*weight }
            }
            for channel in 0..<4 { donor[channel] /= totalWeight }
            original += pixel; affected.append(feather); skinField += donor
        }}
        // Smooth only the synthesized skin field, before compositing its eye
        // matte, so per-column donor variation cannot produce vertical stripes.
        // Hair and the source eye texture never enter this filtering operation.
        if style == .rider {
            // Hue protection can leave isolated source-lash pixels under the
            // bangs. Close those tiny holes in the coverage matte, while the
            // broad, connected hair silhouette remains outside the eyelid.
            var expanded = affected, sealed = affected
            for y in 0..<height { for x in 0..<width {
                var coverage = 0.0
                for dy in -2...2 { for dx in -2...2 {
                    let px = max(0,min(width-1,x+dx)), py = max(0,min(height-1,y+dy))
                    coverage = max(coverage,affected[py*width+px])
                }}
                expanded[y*width+x] = coverage
            }}
            for y in 0..<height { for x in 0..<width {
                var coverage = 1.0
                for dy in -2...2 { for dx in -2...2 {
                    let px = max(0,min(width-1,x+dx)), py = max(0,min(height-1,y+dy))
                    coverage = min(coverage,expanded[py*width+px])
                }}
                let sx = minX+Double(x), sy = minY+Double(y)
                let t = max(0,min(1,(sx-top[0][0])/(top[3][0]-top[0][0])))
                let bound = Self.mask(x:sx,y:sy,left:top[0][0],right:top[3][0],
                    top:Self.curve(top,t)-5,bottom:Self.curve(bottom,t)+2+5*sin(.pi*t))
                sealed[y*width+x] = max(affected[y*width+x],min(bound,coverage))
            }}
            affected = sealed
        }
        let kernel = [1.0,4,6,4,1]
        clean = original
        for y in 0..<height { for x in 0..<width {
            var donor = [Double](repeating:0,count:4), total = 0.0
            for dy in -2...2 { for dx in -2...2 {
                let px = max(0,min(width-1,x+dx)), py = max(0,min(height-1,y+dy))
                let weight = kernel[dx+2]*kernel[dy+2]
                total += weight
                let sampleStart = (py*width+px)*4
                for channel in 0..<4 { donor[channel] += skinField[sampleStart+channel]*weight }
            }}
            let offset = (y*width+x)*4, feather = affected[y*width+x]
            for channel in 0..<4 {
                clean[offset+channel] = style == .friend ? UInt8(donor[channel]/total) : UInt8(Double(original[offset+channel])*(1-feather)+(donor[channel]/total)*feather)
            }
        }}

    }
    func render(closure: Double, joy: Double) {
        guard closure > 0.0001 else { layer.opacity = 0; return }
        if style == .friend { renderFriend(closure:closure); return }
        layer.opacity = Float(min(1,closure*20))
        let closeIndex = Int((max(0,min(1,closure))*100).rounded()), joyIndex = Int((max(0,min(1,joy))*24).rounded())
        let key = closeIndex+joyIndex*101
        if let image = cache[key] { layer.contents = image; return }
        let c = Double(closeIndex)/100, j = Double(joyIndex)/24
        var output = clean, influence = affected
        for x in 0..<width {
            let sx = rect.minX+Double(x), t = max(0,min(1,(sx-top[0][0])/(top[3][0]-top[0][0])))
            let a = Self.curve(top,t)-3, b = Self.curve(bottom,t)+7
            let cornerLine = closed[0][1]*(1-t)+closed[3][1]*t
            // Follow the original eye tilt, with only a small lid bow. The
            // previous deep U curve did not match these painted faces.
            let target = cornerLine+(2.0-4.5*j)*sin(.pi*t)
            let lashHalfWidth = 0.45+0.95*pow(max(0,sin(.pi*t)),0.7)
            let upper = a*(1-c)+(target-lashHalfWidth)*c, lower = b*(1-c)+(target+lashHalfWidth)*c
            var lashCandidates: [[UInt8]] = []
            let firstLashRow = Int(a-Double(rect.minY))
            for rowOffset in 0...12 {
                let row = max(0,min(height-1,firstLashRow+rowOffset))
                let pixelStart = (row*width+x)*4
                lashCandidates.append(Array(original[pixelStart..<(pixelStart+4)]))
            }
            lashCandidates.sort { lhs,rhs in
                let leftBrightness = Int(lhs[0])+Int(lhs[1])+Int(lhs[2])
                let rightBrightness = Int(rhs[0])+Int(rhs[1])+Int(rhs[2])
                return leftBrightness < rightBrightness
            }
            var lash = [Double](repeating:0,count:3)
            for candidate in lashCandidates.prefix(3) {
                for channel in 0..<3 { lash[channel] += Double(candidate[channel])/3 }
            }
            for y in 0..<height {
                let sy = rect.minY+Double(y)
                guard sy >= upper-1 && sy <= lower+1 else { continue }
                let fraction = max(0,min(1,(sy-upper)/max(0.1,lower-upper)))
                // As the eye seals, retain the real upper lash pixels at their
                // natural thickness while the iris disappears under the lid.
                let sourceY = a+(b-a)*fraction*(1-pow(c,6)) + min(5,b-a)*fraction*pow(c,6)
                let openMask = Self.mask(x:sx,y:sourceY,left:top[0][0],right:top[3][0],top:a,bottom:b-5+5*sin(.pi*t))
                    * max(0,min(1,min(sy-upper+1,lower-sy+1)))
                let taper = max(0,min(1,min(t,1-t)*14))
                let lashMask = taper*pow(max(0,1-abs(sy-target)/(lashHalfWidth+0.65)),0.75)
                let mask = openMask*(1-pow(c,7))+lashMask*pow(c,7)
                let sampleY = max(0,min(Double(height-1),sourceY-rect.minY)), y0 = Int(sampleY), y1 = min(height-1,y0+1), blend = sampleY-Double(y0)
                let offset = (y*width+x)*4
                influence[y*width+x] = max(influence[y*width+x],mask)
                for channel in 0..<4 {
                    let sampled = Double(original[(y0*width+x)*4+channel])*(1-blend)+Double(original[(y1*width+x)*4+channel])*blend
                    let value = channel < 3 ? sampled*(1-pow(c,7))+lash[channel]*pow(c,7) : sampled
                    output[offset+channel] = UInt8(max(0,min(255,Double(output[offset+channel])*(1-mask)+value*mask)))
                }
            }
        }
        // Only changed eye pixels are drawn. An opaque crop would expose even
        // tiny sampling/profile differences as a rectangular patch on the face.
        for index in influence.indices { output[index*4+3] = UInt8(Double(original[index*4+3])*influence[index]) }
        if let image = SourceFacePixels.image(output,width:width,height:height) {
            if cache.count > 180 { cache.removeAll(keepingCapacity:true) }
            cache[key] = image; layer.contents = image
        }
    }
    private static func friendHairMask(source: SourceFacePixels, rect: CGRect, top: [[Double]]) -> [Double] {
        let width = Int(rect.width), height = Int(rect.height)
        var candidates = [Double](repeating:0,count:width*height)
        for y in 0..<height { for x in 0..<width {
            let sx = rect.minX+Double(x), sy = rect.minY+Double(y)
            let t = max(0,min(1,(sx-top[0][0])/(top[3][0]-top[0][0])))
            let color = source.pixel(sx,sy)
            let chroma = max(0,min(1,(Double(Int(color[2])-Int(color[1]))-13)/5))
            let warmth = max(0,min(1,(22+Double(Int(color[2])-Int(color[0])))/10))
            let aboveLash = max(0,min(1,(Self.curve(top,t)-1-sy)/2))
            candidates[y*width+x] = chroma*warmth*aboveLash
        }}
        // A one-pixel opening removes the narrow plum upper-lash fragments
        // from hair candidates, while retaining the connected painted bangs.
        var core = candidates, opened = candidates
        for y in 0..<height { for x in 0..<width {
            var value = 1.0
            for dy in -1...1 { for dx in -1...1 {
                let px = max(0,min(width-1,x+dx)), py = max(0,min(height-1,y+dy))
                value = min(value,candidates[py*width+px])
            }}
            core[y*width+x] = value
        }}
        for y in 0..<height { for x in 0..<width {
            var value = 0.0
            for dy in -1...1 { for dx in -1...1 {
                let px = max(0,min(width-1,x+dx)), py = max(0,min(height-1,y+dy))
                value = max(value,core[py*width+px])
            }}
            opened[y*width+x] = min(candidates[y*width+x],value)
        }}
        var connected = [Bool](repeating:false,count:width*height), queue: [Int] = []
        for y in 0..<height { for x in 0..<width where x == 0 || x == width-1 || y == 0 {
            let index = y*width+x
            if opened[index] > 0.05 { connected[index] = true; queue.append(index) }
        }}
        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]; cursor += 1
            let x = index%width, y = index/width
            for dy in -1...1 { for dx in -1...1 {
                let px = x+dx, py = y+dy
                guard px >= 0, px < width, py >= 0, py < height else { continue }
                let next = py*width+px
                if !connected[next], opened[next] > 0.05 { connected[next] = true; queue.append(next) }
            }}
        }
        return opened.indices.map { connected[$0] ? opened[$0] : 0 }
    }
    private func renderFriend(closure: Double) {
        layer.opacity = Float(min(1,closure*20))
        let closeIndex = Int((max(0,min(1,closure))*100).rounded())
        if let image = cache[closeIndex] { layer.contents = image; return }
        let c = Double(closeIndex)/100
        let blend = max(0,min(1,(c-0.55)/0.45))
        let sealed = blend*blend*(3-2*blend)
        var output = clean
        let influence = affected
        for x in 0..<width {
            let sx = rect.minX+Double(x)
            let t = max(0,min(1,(sx-top[0][0])/(top[3][0]-top[0][0])))
            let a = Self.curve(top,t)-3, b = Self.curve(bottom,t)+4
            let corner = closed[0][1]*(1-t)+closed[3][1]*t
            let target = corner+0.8*(Self.curve(closed,t)-corner)
            let taper = pow(max(0,sin(.pi*t)),0.55)
            let halfWidth = 0.35+0.85*taper
            let upper = a*(1-c)+(target-halfWidth)*c
            let lower = b*(1-c)+(target+halfWidth)*c
            for y in 0..<height {
                let sy = rect.minY+Double(y), coverage = affected[y*width+x]
                guard coverage > 0, sy >= upper-1, sy <= lower+1 else { continue }
                let fraction = max(0,min(1,(sy-upper)/max(0.1,lower-upper)))
                let sourceY = a+(b-a)*fraction
                let open = Self.mask(x:sx,y:sourceY,left:top[0][0],right:top[3][0],top:a,bottom:b)
                    * max(0,min(1,min(sy-upper+1,lower-sy+1)))
                let lash = taper*pow(max(0,1-abs(sy-target)/(halfWidth+0.6)),0.8)
                let amount = (open*(1-sealed)+lash*sealed)*coverage
                let sampleY = max(0,min(Double(height-1),sourceY-rect.minY))
                let y0 = Int(sampleY), y1 = min(height-1,y0+1), fractionY = sampleY-Double(y0)
                let offset = (y*width+x)*4
                for channel in 0..<3 {
                    let sampled = Double(original[(y0*width+x)*4+channel])*(1-fractionY)
                        + Double(original[(y1*width+x)*4+channel])*fractionY
                    let lashColor = [58.0,34,44][channel]
                    let value = sampled*(1-sealed)+lashColor*sealed
                    output[offset+channel] = UInt8(max(0,min(255,Double(output[offset+channel])*(1-amount)+value*amount)))
                }
            }
        }
        for index in influence.indices { output[index*4+3] = UInt8(Double(original[index*4+3])*influence[index]) }
        if let image = SourceFacePixels.image(output,width:width,height:height) {
            cache[closeIndex] = image; layer.contents = image
        }
    }
    private static func isSkin(_ color: [UInt8]) -> Bool {
        let r = Int(color[0]), g = Int(color[1]), b = Int(color[2])
        return color[3] > 230 && r > 185 && g > 130 && b > 115 && r-g > 7 && r-b > 8
    }
    private static func curve(_ p: [[Double]], _ t: Double) -> Double {
        let u = 1-t; return u*u*u*p[0][1]+3*u*u*t*p[1][1]+3*u*t*t*p[2][1]+t*t*t*p[3][1]
    }
    private static func mask(x: Double,y: Double,left: Double,right: Double,top: Double,bottom: Double) -> Double {
        max(0,min(1,min(min((x-left)/3,(right-x)/3),min((y-top)/2.5,(bottom-y)/4))))
    }
}

private final class SourceBrowPatch {
    let layer = CALayer()
    private let texture = CALayer()
    init(source: SourceFacePixels, points: [[Double]]) {
        let rect = CGRect(x:points[0][0]-2,y:(points.map { $0[1] }.min() ?? 0)-3,width:points[2][0]-points[0][0]+4,height:13)
        layer.frame = SourceReferenceFaceRig.frame(rect); layer.actions = ["opacity":NSNull()]
        let clear = CALayer(); clear.frame = layer.bounds
        layer.addSublayer(clear)
        var pixels = [UInt8](), clearPixels = [UInt8]()
        for y in 0..<Int(rect.height) { for x in 0..<Int(rect.width) {
            let sx = Double(rect.minX)+Double(x), sy = Double(rect.minY)+Double(y)
            let t = max(0,min(1,(sx-points[0][0])/(points[2][0]-points[0][0])))
            let u = 1-t, line = u*u*points[0][1]+2*u*t*points[1][1]+t*t*points[2][1]
            var pixel = source.pixel(sx,sy)
            let mask = max(0,min(1,(2.2-abs(sy-line))*0.8))*max(0,min(1,min(Double(x),rect.width-Double(x)-1)/2))
            var donor = source.pixel(sx,line+3)
            if (donor.prefix(3).max() ?? 0) < 180 { donor = source.pixel(443,190) }
            donor[3] = UInt8(Double(donor[3])*mask); clearPixels += donor
            pixel[3] = UInt8(Double(pixel[3])*mask); pixels += pixel
        }}
        clear.contents = SourceFacePixels.image(clearPixels,width:Int(rect.width),height:Int(rect.height))
        texture.frame = layer.bounds; texture.contents = SourceFacePixels.image(pixels,width:Int(rect.width),height:Int(rect.height))
        texture.actions = ["position":NSNull()]; layer.addSublayer(texture)
    }
    func render(joy: Double) { layer.opacity = Float(joy); texture.position = CGPoint(x:layer.bounds.midX,y:layer.bounds.midY+1.7*joy) }
}
