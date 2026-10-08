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
        for layer in [root,rider,friend,hearts,mouth] {
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
            friendEyes = [
                SourceEyePatch(source:source,top:[[283,776],[307,765],[333,759],[353,769]],bottom:[[283,781],[308,800],[334,802],[353,783]],closed:[[283,779],[307,794],[335,796],[353,776]]),
                SourceEyePatch(source:source,top:[[378,757],[397,745],[424,737],[440,739]],bottom:[[378,764],[397,784],[425,776],[440,756]],closed:[[378,762],[398,778],[424,772],[440,747]])
            ]
        }
        riderEyes.forEach { rider.addSublayer($0.layer) }
        friendEyes.forEach { friend.addSublayer($0.layer) }
        brows.forEach { rider.addSublayer($0.layer) }
        // The mouth is above the eye patches only to keep all expression details
        // in the same rider transform; their registered regions do not overlap.
        rider.addSublayer(mouth)
        addHeart(at:CGPoint(x:325,y:780),size:12)
        addHeart(at:CGPoint(x:415,y:760),size:13)
    }

    func render(blink: Double, laugh: Double, expression: FriendExpression, opacity: Double,
                seatX: Double, torsoY: Double, support: CGAffineTransform,
                friendBlink: Double? = nil, laughAge: Double = 0) {
        rider.position = CGPoint(x:seatX,y:torsoY)
        friend.setAffineTransform(support)
        let joy = Self.ease(laugh), riderClosure = max(Self.ease(blink),joy * 0.94)
        riderEyes.forEach { $0.render(closure:riderClosure,joy:joy) }
        let effort = expression == .effort ? Self.ease(opacity) * 0.87 : 0
        friendEyes.forEach { $0.render(closure:max(Self.ease(friendBlink ?? blink),effort),joy:0) }
        hearts.opacity = expression == .hearts ? Float(opacity) : 0
        brows.forEach { $0.render(joy:joy) }
        renderMouth(joy:joy,age:laughAge)
        diagnostics = ["riderClosure":riderClosure,"friendClosure":max(Self.ease(friendBlink ?? blink),effort),
                       "eyelidClosure":riderClosure,"mouthOpen":joy > 0.0001 ? (0.6+13*joy)*(0.88+0.12*cos(laughAge*13)) : 0,
                       "joy":joy,"browLift":1.7*joy]
    }

    fileprivate static func world(_ p: CGPoint) -> CGPoint { CGPoint(x:24+0.64*p.x,y:940-0.64*p.y) }
    fileprivate static func frame(_ rect: CGRect) -> CGRect {
        CGRect(x:24+0.64*rect.minX,y:940-0.64*rect.maxY,width:rect.width*0.64,height:rect.height*0.64)
    }
    private static func ease(_ value: Double) -> Double {
        let t = min(1,max(0,value)); return t*t*(3-2*t)
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
        let j = CGFloat(joy), beat = CGFloat(0.88 + 0.12*cos(age*13))
        let half = 10.5 + 5*j, depth = (0.6 + 13*j)*beat
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
    static func image(_ pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data:Data(pixels) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
            space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),
            provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }
}

private final class SourceEyePatch {
    let layer = CALayer()
    private let rect: CGRect
    private let top: [[Double]], bottom: [[Double]], closed: [[Double]]
    private let width: Int, height: Int
    private var original: [UInt8] = [], clean: [UInt8] = []
    private var affected: [Double] = []
    private var cache: [Int:CGImage] = [:]
    init(source: SourceFacePixels, top: [[Double]], bottom: [[Double]], closed: [[Double]]) {
        self.top = top; self.bottom = bottom; self.closed = closed
        let minX = floor(top[0][0])-4, maxX = ceil(top[3][0])+4
        let minY = floor(top.map { $0[1] }.min()!)-5, maxY = ceil(bottom.map { $0[1] }.max()!)+5
        rect = CGRect(x:minX,y:minY,width:maxX-minX,height:maxY-minY)
        width = Int(rect.width); height = Int(rect.height)
        layer.frame = SourceReferenceFaceRig.frame(rect); layer.contentsScale = 2
        layer.actions = ["contents":NSNull(),"opacity":NSNull()]
        // Only warm, bright pixels outside the eye can supply lid skin.
        // Sampling an entire cheek column also samples hair at the outer corner.
        var skinColumns: [[(Double,Double,[UInt8])]] = []
        for x in 0..<width {
            let sx = minX+Double(x)
            let t = max(0,min(1,(sx-top[0][0])/(top[3][0]-top[0][0])))
            let a = Self.curve(top,t), b = Self.curve(bottom,t)
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
        var skinField: [Double] = []
        for y in 0..<height { for x in 0..<width {
            let sx = minX+Double(x), sy = minY+Double(y)
            let t = max(0,min(1,(sx-top[0][0])/(top[3][0]-top[0][0])))
            let a = Self.curve(top,t), b = Self.curve(bottom,t)
            var feather = Self.mask(x:sx,y:sy,left:top[0][0],right:top[3][0],top:a-5,bottom:b+2+5*sin(.pi*t))
            let pixel = source.pixel(sx,sy)
            // Preserve the source bangs above the upper lash and the painted
            // hair silhouette under either eye corner, rather than recolor it.
            let dark = (pixel.prefix(3).max() ?? 255) < 165
            if dark, sy > b+1 { feather = 0 }
            if dark, sy < a+0.5 {
                // Rider hair is olive/brown (blue below green); the actual
                // upper lash is plum or neutral. Require a positive olive
                // margin, with a soft transition; neutral lash edge pixels must
                // not be mistaken for bangs and survive as a dotted outline.
                let oliveMargin = Double(Int(pixel[1])-Int(pixel[2]))
                let hairProtection = max(0,min(1,(oliveMargin-4)/8))
                if top[0][1] >= 300 { feather = 0 }
                else { feather *= 1-hairProtection }
            }
            if top[0][0] < 400 {
                let cheekEdge = top[0][0]+max(0,sy-top[0][1]-2)*0.92
                feather *= max(0,min(1,(sx-cheekEdge)/3))
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
        if top[0][1] < 300 {
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
                clean[offset+channel] = UInt8(Double(original[offset+channel])*(1-feather)+(donor[channel]/total)*feather)
            }
        }}

    }
    func render(closure: Double, joy: Double) {
        guard closure > 0.0001 else { layer.opacity = 0; return }
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
