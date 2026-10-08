import AppKit
import QuartzCore

/// Completes the deleted desktop area underneath all retained foreground art.
final class ReferenceBodyCompletion {
    let costume = CALayer()
    let crown = CALayer()
    private var registeredImage: CGImage?
    private let garment = CALayer()
    private var computerGarment: CGImage?
    private var restingFillOutline: CGPath?
    private var restingImage: CGImage?
    private var computerRestingFill: CGImage?
    private var repairOutline: CGPath?
    let restingFill = CALayer()
    let restingUnderlay = CALayer()
    init(canvasSize: CGSize, patch: CGImage?, restingSource: CGImage? = nil) {
        for layer in [costume,crown] {
            layer.bounds = CGRect(origin:.zero,size:canvasSize)
            layer.anchorPoint = .zero; layer.position = .zero
        }
        guard let patch else { return }
        let registration = CGRect(x:260,y:440,width:390,height:180)
        // Original exposed thigh, legs, fingers and skirt remain in foreground.
        // The local repair is baked once, so animation only moves its whole layer.
        func point(_ x: Double,_ y: Double) -> CGPoint {
            CGPoint(x:registration.minX+x/1847*registration.width,
                    y:registration.maxY-y/851*registration.height)
        }
        let purple = CGMutablePath()
        let points = [(222.0,851.0),(260,683),(355,643),(482,624),(598,633),(690,682),(748,759),(785,851)]
        for (index,p) in points.enumerated() {
            let world = point(p.0,p.1)
            if index == 0 { purple.move(to:world) } else { purple.addLine(to:world) }
        }
        purple.closeSubpath()
        garment.frame = registration
        registeredImage = Self.registeredGarment(patch,registration:registration)
        if let registeredImage { computerGarment = Self.computerApron(registeredImage) }
        garment.contents = registeredImage
        garment.contentsGravity = .resize; costume.addSublayer(garment)
        // Keep the upper repair below the retained torso, but follow the natural
        // hem below it. Neither a sloping sleeve cut nor y476 truncates the fabric.
        let repairBounds = CGMutablePath()
        // Only the apron valley extends below the original knee/head joins. This
        // prevents the hidden reference legs from appearing when the real legs move.
        for (index,p) in [(260.0,477.0),(260,558),(620,558),(630,543),(632,525),(641,508),
                          (650,495),(650,440),(550,440),(550,477),(480,477),(470,466),(454,458),(441,461),(421,477)].enumerated() {
            if index == 0 { repairBounds.move(to:CGPoint(x:p.0,y:p.1)) }
            else { repairBounds.addLine(to:CGPoint(x:p.0,y:p.1)) }
        }
        repairBounds.closeSubpath()
        repairOutline = repairBounds
        let restrict = CAShapeLayer(); restrict.path = repairBounds; restrict.fillColor = NSColor.white.cgColor
        costume.mask = restrict
        // The former typing hand left a hole across the belt and apron. Use one
        // continuous fabric patch from the new pose, underneath the resting arms.
        if let restingSource {
            restingImage = restingSource
            computerRestingFill = Self.featherComputerFill(restingSource,canvasSize:canvasSize)
            restingUnderlay.bounds = CGRect(origin:.zero,size:canvasSize)
            restingUnderlay.anchorPoint = .zero; restingUnderlay.position = .zero
            restingUnderlay.contents = restingSource; restingUnderlay.contentsGravity = .resize
            let underlayMask = CAShapeLayer(), underlayPath = CGMutablePath()
            for points in [
                [(512.0,551.0),(540,551),(539,625),(525,626),(523,613),(519,604),(511,589)],
                [(580.0,552.0),(623,552),(622,542),(622,533),(622,523),(620,512),(595,508),(577,530)],
                [(363.0,639.0),(372,639),(372,575),(345,575),(334,590),(341,606),(350,619),(358,632)]
            ] {
                for (index,p) in points.enumerated() {
                    if index == 0 { underlayPath.move(to:CGPoint(x:p.0,y:p.1)) }
                    else { underlayPath.addLine(to:CGPoint(x:p.0,y:p.1)) }
                }
                underlayPath.closeSubpath()
            }
            underlayMask.path = underlayPath; underlayMask.fillColor = NSColor.white.cgColor
            restingUnderlay.mask = underlayMask; restingUnderlay.isHidden = true
            restingFill.bounds = CGRect(origin:.zero,size:canvasSize)
            restingFill.anchorPoint = .zero; restingFill.position = CGPoint(x:-3,y:0)
            restingFill.contents = restingSource; restingFill.contentsGravity = .resize
            let fillMask = CAShapeLayer(), fillPath = CGMutablePath()
            for (index,p) in [(415.0,574.0),(521,579),(557,561),(557,537),(549,516),(476,516),(415,531)].enumerated() {
                let point = CGPoint(x:p.0+3,y:p.1)
                if index == 0 { fillPath.move(to:point) }
                else { fillPath.addLine(to:point) }
            }
            fillPath.closeSubpath(); fillMask.path = fillPath; fillMask.fillColor = NSColor.white.cgColor
            restingFillOutline = fillPath
            restingFill.mask = fillMask; restingFill.isHidden = true
        }
        let hair = CALayer(); hair.frame = registration; hair.contents = patch; hair.contentsGravity = .resize
        var translation = CGAffineTransform(translationX:-registration.minX,y:-registration.minY)
        let hairMask = CAShapeLayer(); hairMask.path = purple.copy(using:&translation); hairMask.fillColor = NSColor.white.cgColor
        hair.mask = hairMask; crown.addSublayer(hair)
        let cap = CAShapeLayer(); cap.path = CGPath(rect:CGRect(x:300,y:476,width:155,height:24),transform:nil); cap.fillColor = NSColor.white.cgColor
        crown.mask = cap
    }
    /// The interactive right arm replaces the static cuff in the completion.
    /// Inspection mode keeps the original completion outline exactly intact.
    func setInteractiveDeskMode(_ active: Bool) {
        guard let outline = repairOutline, let mask = costume.mask as? CAShapeLayer else { return }
        guard active else { mask.path = outline; mask.fillRule = .nonZero; return }
        let path = CGMutablePath(); path.addPath(outline)
        for (index,p) in [(515.0,548.0),(535,558),(604,558),(603,552),(607,545),
                          (611,538),(614,530),(611,523),(600,514),(583,510),
                          (557,510),(534,517),(518,530)].enumerated() {
            if index == 0 { path.move(to:CGPoint(x:p.0,y:p.1)) }
            else { path.addLine(to:CGPoint(x:p.0,y:p.1)) }
        }
        path.closeSubpath()
        mask.path = path; mask.fillRule = .evenOdd
    }
    func setRestingPoseMode(_ active: Bool) {
        restingFill.isHidden = !active
        restingUnderlay.isHidden = !active
        guard active, let outline = repairOutline, let mask = costume.mask as? CAShapeLayer else { return }
        let path = CGMutablePath(); path.addPath(outline)
        for points in [
            [(260.0,518.0),(335,518),(365,537),(374,558),(260,558)],
            [(515.0,548.0),(535,558),(604,558),(603,552),(607,545),(611,538),(614,530),(611,523),(600,514),(583,510),(557,510),(534,517),(518,530)]
        ] {
            for (index,p) in points.enumerated() {
                if index == 0 { path.move(to:CGPoint(x:p.0,y:p.1)) }
                else { path.addLine(to:CGPoint(x:p.0,y:p.1)) }
            }
            path.closeSubpath()
        }
        mask.path = path; mask.fillRule = .evenOdd
    }
    /// Raising both arms reveals the apron underneath their old lap position.
    /// Reuse the unobstructed lower fabric while keeping the real thigh join fixed.
    func setComputerDeskMode(_ active: Bool) {
        garment.contents = active ? computerGarment ?? registeredImage : registeredImage
        restingFill.contents = active ? computerRestingFill ?? restingImage : restingImage
        if let outline = restingFillOutline, let mask = restingFill.mask as? CAShapeLayer {
            mask.path = outline; mask.fillRule = .nonZero
        }
        guard active, let outline = repairOutline, let mask = costume.mask as? CAShapeLayer else { return }
        // The computer apron supplies the right cuff's former footprint. Retain
        // the left sleeve cut used by the resting pose, without reopening it.
        let path = CGMutablePath(); path.addPath(outline)
        for (index,p) in [(260.0,518.0),(335,518),(365,537),(374,558),(260,558)].enumerated() {
            if index == 0 { path.move(to:CGPoint(x:p.0,y:p.1)) }
            else { path.addLine(to:CGPoint(x:p.0,y:p.1)) }
        }
        path.closeSubpath(); mask.path = path; mask.fillRule = .evenOdd
    }
    private static func featherComputerFill(_ source: CGImage, canvasSize: CGSize) -> CGImage? {
        let width = source.width, height = source.height
        let space = source.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        var pixels = [UInt8](repeating:0,count:width*height*4)
        let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data:bytes.baseAddress,width:width,height:height,bitsPerComponent:8,
                bytesPerRow:width*4,space:space,bitmapInfo:info) else { return false }
            context.draw(source,in:CGRect(x:0,y:0,width:width,height:height)); return true
        }
        guard success else { return nil }
        func smooth(_ value: CGFloat) -> CGFloat { let t = max(0,min(1,value)); return t*t*(3-2*t) }
        for y in 0..<height {
            let worldY = canvasSize.height-(CGFloat(y)+0.5)/CGFloat(height)*canvasSize.height
            guard worldY >= 490 && worldY <= 540 else { continue }
            for x in 0..<width {
                let worldX = (CGFloat(x)+0.5)/CGFloat(width)*canvasSize.width-3
                let factor = 1-smooth((worldX-465)/34)*(1-smooth((worldY-534)/6))
                guard factor < 1 else { continue }
                let byte = (y*width+x)*4
                for channel in 0..<4 { pixels[byte+channel] = UInt8((CGFloat(pixels[byte+channel])*factor).rounded()) }
            }
        }
        guard let provider = CGDataProvider(data:Data(pixels) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
            space:space,bitmapInfo:CGBitmapInfo(rawValue:info),provider:provider,decode:nil,
            shouldInterpolate:true,intent:.defaultIntent)
    }
    private static func computerApron(_ source: CGImage) -> CGImage? {
        let width = source.width, height = source.height
        let space = source.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        var original = [UInt8](repeating:0,count:width*height*4)
        let success = original.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data:bytes.baseAddress,width:width,height:height,bitsPerComponent:8,
                bytesPerRow:width*4,space:space,bitmapInfo:info) else { return false }
            context.draw(source,in:CGRect(x:0,y:0,width:width,height:height)); return true
        }
        guard success else { return nil }
        var pixels = original
        func smooth(_ value: CGFloat) -> CGFloat { let t = max(0,min(1,value)); return t*t*(3-2*t) }
        for y in 0..<height {
            let worldY = 620-(CGFloat(y)+0.5)/CGFloat(height)*180
            guard worldY >= 495 && worldY <= 540 else { continue }
            // Sample above the gold thigh hem and below the removed lap cuff.
            // Pulling the hem itself upward would create a second knee outline.
            let sampleY = (620-(508+(worldY-495)*6/45))/180*CGFloat(height)-0.5
            let top = max(0,min(height-1,Int(floor(sampleY)))), bottom = min(height-1,top+1)
            let mix = max(0,min(1,sampleY-CGFloat(top)))
            for x in 0..<width {
                let worldX = 260+(CGFloat(x)+0.5)/CGFloat(width)*390
                let strength = smooth((worldX-465)/20)*smooth((625-worldX)/15)*smooth((worldY-495)/6)
                guard strength > 0 else { continue }
                let byte = (y*width+x)*4
                for channel in 0..<4 {
                    let upper = CGFloat(original[(top*width+x)*4+channel])
                    let lower = CGFloat(original[(bottom*width+x)*4+channel])
                    let fabric = upper+(lower-upper)*mix
                    pixels[byte+channel] = UInt8((CGFloat(original[byte+channel])*(1-strength)+fabric*strength).rounded())
                }
            }
        }
        guard let provider = CGDataProvider(data:Data(pixels) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
            space:space,bitmapInfo:CGBitmapInfo(rawValue:info),provider:provider,decode:nil,
            shouldInterpolate:true,intent:.defaultIntent)
    }
    private static func registeredGarment(_ patch: CGImage, registration: CGRect) -> CGImage? {
        let width = CGFloat(patch.width), height = CGFloat(patch.height)
        let space = patch.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        func context() -> CGContext? {
            CGContext(data:nil,width:patch.width,height:patch.height,bitsPerComponent:8,bytesPerRow:0,
                      space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)
        }
        guard let matteContext = context(), let destination = context() else { return nil }
        let bounds = CGRect(x:0,y:0,width:width,height:height)
        // Keep only enough generated lining and crown to close the original desk
        // gap. The world-space outline below clips this fill at the original joins.
        let exclusions: [[CGPoint]] = [
            // Retain a short crown strip where registration opened a gap; the
            // original purple-haired character supplies everything below it.
            [(222,851),(256,700),(704,700),(748,759),(785,851)],
            // Left palm and right fingers are supplied by the original body join.
            [(0,265),(94,296),(130,350),(123,411),(76,450),(0,453)],
            [(1096,429),(1110,382),(1150,342),(1210,323),(1270,327),(1320,350),
             (1390,386),(1425,439),(1391,482),(1320,494),(1250,457),(1190,466),(1130,449)],
            // The warm wedge beside the front stocking is generated thigh skin.
            [(1275,646),(1340,673),(1395,729),(1454,817),(1465,851),(1390,851),
             (1350,751),(1293,687)]
        ].map { points in points.map { CGPoint(x:CGFloat($0.0)/1847*width,y:CGFloat($0.1)/851*height) } }
        // Intersect separate even-odd cuts. Combining overlapping exclusion paths
        // in one even-odd mask would inadvertently reveal their intersection.
        for outline in exclusions {
            let path = CGMutablePath(); path.addRect(bounds)
            for (index,p) in outline.enumerated() {
                let point = CGPoint(x:p.x,y:height-p.y)
                if index == 0 { path.move(to:point) } else { path.addLine(to:point) }
            }
            path.closeSubpath(); matteContext.addPath(path); matteContext.clip(using:.evenOdd)
        }
        matteContext.draw(patch,in:bounds)
        guard let texture = matteContext.makeImage() else { return nil }
        func smooth(_ value: CGFloat) -> CGFloat {
            let p = max(0,min(1,value)); return p*p*(3-2*p)
        }
        func warped(_ cgPoint: CGPoint) -> CGPoint {
            let x = cgPoint.x/width*1847, y = (height-cgPoint.y)/height*851
            let t = smooth((y-333.80)/(815-333.80))
            let center = 1037.44+(852.92-1037.44)*t
            let lateralWeight = smooth(1-abs(x-center)/740)
            let weight = lateralWeight*smooth(y/240)
            let dx = (-11.5+(9.7+11.5)*t)*weight
            let dy = (0.2+(14.3-0.2)*t)*weight
            // The generated cuffs also drifted from the original wrists. Local
            // compact corrections stop a second cuff appearing below each hand.
            let left = smooth(1-abs(x-210)/320)*smooth(1-abs(y-420)/270)
            let right = smooth(1-abs(x-1500)/290)*smooth(1-abs(y-420)/260)
            return CGPoint(x:cgPoint.x+(dx-20*left-12*right)/registration.width*width,
                           y:cgPoint.y+(dy+15*left+9*right)/registration.height*height)
        }
        destination.interpolationQuality = .high
        // Shared vertices and non-antialiased triangle clips cover the static
        // mesh without partial-alpha grid lines. Texture sampling remains smooth.
        destination.setShouldAntialias(false); destination.setAllowsAntialiasing(false)
        func triangle(_ a: CGPoint,_ b: CGPoint,_ c: CGPoint) {
            let aa = warped(a), bb = warped(b), cc = warped(c)
            let sx = b.x-a.x, sy = b.y-a.y, tx = c.x-a.x, ty = c.y-a.y
            let determinant = sx*ty-tx*sy
            guard abs(determinant) > 0.00001 else { return }
            let ax = ((bb.x-aa.x)*ty-(cc.x-aa.x)*sy)/determinant
            let bx = ((bb.y-aa.y)*ty-(cc.y-aa.y)*sy)/determinant
            let cx = (sx*(cc.x-aa.x)-tx*(bb.x-aa.x))/determinant
            let dx = (sx*(cc.y-aa.y)-tx*(bb.y-aa.y))/determinant
            let transform = CGAffineTransform(a:ax,b:bx,c:cx,d:dx,
                tx:aa.x-ax*a.x-cx*a.y,ty:aa.y-bx*a.x-dx*a.y)
            let path = CGMutablePath(); path.move(to:aa); path.addLine(to:bb); path.addLine(to:cc); path.closeSubpath()
            destination.saveGState(); destination.addPath(path); destination.clip()
            destination.concatenate(transform); destination.draw(texture,in:bounds)
            destination.restoreGState()
        }
        let cell: CGFloat = 64
        var y: CGFloat = 0
        while y < height {
            var x: CGFloat = 0
            while x < width {
                let right = min(width,x+cell), top = min(height,y+cell)
                let a = CGPoint(x:x,y:y), b = CGPoint(x:right,y:y)
                let c = CGPoint(x:right,y:top), d = CGPoint(x:x,y:top)
                triangle(a,b,c); triangle(a,c,d)
                x = right
            }
            y = min(height,y+cell)
        }
        return destination.makeImage()
    }
    /// Feather only a retained desktop cut when opaque replacement fabric is
    /// directly behind it. Original exterior contours and all source files stay
    /// intact; there is no fade into an unfilled or transparent region.
    func softeningCutEdge(_ source: CGImage, frame: CGRect, upper: Bool, discardAbove: CGFloat? = nil) -> CGImage {
        guard let backing = registeredImage else { return source }
        let space = source.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let info = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        func rgba(_ image: CGImage) -> [UInt8]? {
            var bytes = [UInt8](repeating:0,count:image.width*image.height*4)
            let success = bytes.withUnsafeMutableBytes { storage -> Bool in
                guard let context = CGContext(data:storage.baseAddress,width:image.width,height:image.height,
                    bitsPerComponent:8,bytesPerRow:image.width*4,space:space,bitmapInfo:info) else { return false }
                context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
                return true
            }
            return success ? bytes : nil
        }
        guard var pixels = rgba(source), let repair = rgba(backing) else { return source }
        // The skirt atlas retained an isolated fragment of the upper torso above
        // the deleted desk. The restored body already supplies that fragment;
        // retaining both made its rectangular border opaque again after blending.
        if let ceiling = discardAbove {
            for y in 0..<source.height where frame.maxY-(CGFloat(y)+0.5)/CGFloat(source.height)*frame.height > ceiling {
                for byte in (y*source.width*4)..<((y+1)*source.width*4) { pixels[byte] = 0 }
            }
        }
        let original = pixels
        let radius = max(1,Int(ceil((upper ? 5 : 8)*CGFloat(source.height)/frame.height)))
        let step = upper ? -1 : 1
        for y in 0..<source.height {
            let worldY = frame.maxY-(CGFloat(y)+0.5)/CGFloat(source.height)*frame.height
            guard upper ? (worldY > 475 && worldY < 502) : (worldY > 515 && worldY < 548) else { continue }
            let repairY = Int((620-worldY)/180*CGFloat(backing.height))
            guard repairY >= 0, repairY < backing.height else { continue }
            for x in 0..<source.width {
                let byte = (y*source.width+x)*4, alpha = original[byte+3]
                guard alpha > 0 else { continue }
                let worldX = frame.minX+(CGFloat(x)+0.5)/CGFloat(source.width)*frame.width
                guard repairOutline?.contains(CGPoint(x:worldX,y:worldY)) == true else { continue }
                let repairX = Int((worldX-260)/390*CGFloat(backing.width))
                guard repairX >= 0, repairX < backing.width,
                    repair[(repairY*backing.width+repairX)*4+3] > 242 else { continue }
                var distance = radius
                for d in 1...radius {
                    let yy = y+d*step
                    let sideEdge = !upper && worldY < 540 &&
                        ((x-d >= 0 && original[(y*source.width+x-d)*4+3] < 16) ||
                         (x+d < source.width && original[(y*source.width+x+d)*4+3] < 16))
                    if yy < 0 || yy >= source.height || original[(yy*source.width+x)*4+3] < 16 || sideEdge {
                        distance = d; break
                    }
                }
                guard distance < radius else { continue }
                let t = CGFloat(distance)/CGFloat(radius)
                let factor = t*t*(3-2*t)
                for channel in 0..<4 { pixels[byte+channel] = UInt8((CGFloat(original[byte+channel])*factor).rounded()) }
            }
        }
        guard let provider = CGDataProvider(data:Data(pixels) as CFData),
              let image = CGImage(width:source.width,height:source.height,bitsPerComponent:8,bitsPerPixel:32,
                bytesPerRow:source.width*4,space:space,bitmapInfo:CGBitmapInfo(rawValue:info),provider:provider,
                decode:nil,shouldInterpolate:true,intent:.defaultIntent) else { return source }
        return image
    }
    func render(seatX: Double, torsoY: Double, support: CGAffineTransform) {
        costume.position = CGPoint(x:seatX,y:torsoY)
        restingFill.position = CGPoint(x:seatX-3,y:torsoY)
        restingUnderlay.position = CGPoint(x:seatX,y:torsoY)
        crown.position = CGPoint.zero.applying(support)
        crown.setAffineTransform(CGAffineTransform(a:support.a,b:support.b,c:support.c,d:support.d,tx:0,ty:0))
    }
}
