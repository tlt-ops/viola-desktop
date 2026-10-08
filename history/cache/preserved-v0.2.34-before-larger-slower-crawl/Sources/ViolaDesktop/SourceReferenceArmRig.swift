import AppKit
import QuartzCore
import ViolaCore

/// A sleeve is a small texture mesh bound to shoulder, elbow and wrist. The
/// wrist band and all painted hand pixels use one rigid transform. In
/// particular, moving a hand never shears the complete sleeve (or its cuff).
final class SourceReferenceArmRig {
    struct Result { let wrist: CGPoint; let handTransform: CGAffineTransform }
    let root = CALayer()
    private struct Triangle { let layer: CALayer; let mask: CAShapeLayer; let border: CAShapeLayer; let points: [CGPoint] }
    private let shoulder: CGPoint
    private let elbow: CGPoint
    private let wrist: CGPoint
    private let frame: CGRect
    private let upperLength: CGFloat
    private let lowerLength: CGFloat
    private let bend: CGFloat
    private let rigidCuffDepth: CGFloat
    private var triangles: [Triangle] = []
    private(set) var diagnostics: [String:Any] = [:]

    init(image: CGImage, definition: SpriteDefinition, elbow: CGPoint) {
        frame = definition.frame
        let anchor = definition.anchor ?? [0.5,0.5]
        shoulder = CGPoint(x:frame.minX+anchor[0]*frame.width,y:frame.minY+anchor[1]*frame.height)
        // The full resting images include the fingers; the wrist remains at the
        // registered sleeve contact, not the full image's palm contact.
        let left = definition.id.contains("left") || definition.id.contains("pet")
        wrist = left ? CGPoint(x:242.24,y:579.68) : CGPoint(x:416.96,y:577.12)
        self.elbow = elbow
        rigidCuffDepth = left ? 20 : 27
        upperLength = hypot(elbow.x-shoulder.x,elbow.y-shoulder.y)
        lowerLength = hypot(wrist.x-elbow.x,wrist.y-elbow.y)
        let cross = (wrist.x-shoulder.x)*(elbow.y-shoulder.y)-(wrist.y-shoulder.y)*(elbow.x-shoulder.x)
        bend = cross >= 0 ? 1 : -1
        root.anchorPoint = .zero; root.bounds = CGRect(origin:.zero,size:frame.size)
        root.position = frame.origin
        // Horizontal rings allow the folds to bend while retaining the source
        // silhouette and texture. Adjacent triangles share exactly the same vertices.
        let rows = 32
        let rings = Self.textureRings(image:image,size:frame.size,rows:rows)
        for row in 0..<rows {
            let p = [rings[row].0,rings[row].1,rings[row+1].1,rings[row+1].0]
            for vertices in [[p[0],p[1],p[2]],[p[0],p[2],p[3]]] {
                let layer = CALayer(); layer.anchorPoint = .zero
                layer.bounds = root.bounds; layer.position = .zero
                layer.contents = image; layer.contentsGravity = .resize; layer.contentsScale = 2
                let mask = CAShapeLayer(), path = CGMutablePath()
                for (i,v) in vertices.enumerated() {
                    if i == 0 { path.move(to:v) } else { path.addLine(to:v) }
                }
                path.closeSubpath(); mask.path = path; mask.fillColor = NSColor.white.cgColor
                let border = CAShapeLayer(); border.fillColor = NSColor.white.cgColor; border.contentsScale = 2
                mask.addSublayer(border)
                mask.contentsScale = 2; layer.mask = mask; root.addSublayer(layer)
                triangles.append(Triangle(layer:layer,mask:mask,border:border,points:vertices))
            }
        }
    }

    func render(shoulderOffset: CGPoint, target: CGPoint, handAngle: CGFloat) -> Result {
        let s = CGPoint(x:shoulder.x+shoulderOffset.x,y:shoulder.y+shoulderOffset.y)
        var delta = CGPoint(x:target.x-s.x,y:target.y-s.y)
        let requestedDistance = hypot(delta.x,delta.y)
                // A little fabric extension accommodates edge keys. Beyond this range
        // the solved wrist is used by the palm too, so the joint cannot detach.
        let sourceReach = hypot(wrist.x-shoulder.x,wrist.y-shoulder.y)
        // The short painted forearm cannot sustain a sharply folded upper arm
        // without folding its texture through itself. Let fabric gather along
        // both bones as the hand comes inward; keep its transverse width fixed.
        let gather = max(0.48,1-0.97*(1-requestedDistance/sourceReach))
        let reach = requestedDistance/((upperLength+lowerLength)*0.998)
        let stretch = min(1.32,max(gather,reach))
        let l1 = upperLength*stretch, l2 = lowerLength*stretch
        let distance = min(l1+l2-0.05,max(abs(l1-l2)+0.05,requestedDistance))
        if requestedDistance > 0.001 {
            delta.x *= distance/requestedDistance; delta.y *= distance/requestedDistance
        } else { delta = CGPoint(x:0,y:-distance) }
        let w = CGPoint(x:s.x+delta.x,y:s.y+delta.y)
        let axis = CGPoint(x:delta.x/distance,y:delta.y/distance)
        let along = (l1*l1-l2*l2+distance*distance)/(2*distance)
        let height = sqrt(max(0,l1*l1-along*along))
        let e = CGPoint(x:s.x+axis.x*along-axis.y*height*bend,
                        y:s.y+axis.y*along+axis.x*height*bend)
        let upper = Self.bone(from:shoulder,to:elbow,newFrom:s,newTo:e)
        let lower = Self.bone(from:elbow,to:wrist,newFrom:e,newTo:w)
        let c = cos(handAngle), sn = sin(handAngle)
        let cuff = CGAffineTransform(a:c,b:sn,c:-sn,d:c,
            tx:w.x-c*wrist.x+sn*wrist.y,ty:w.y-sn*wrist.x-c*wrist.y)
        func mapped(_ p: CGPoint) -> CGPoint {
            let world = CGPoint(x:p.x+frame.minX,y:p.y+frame.minY)
            let upperWeight = Self.smooth((world.y-elbow.y+60)/120)
            let cuffWeight = 1-Self.smooth((world.y-wrist.y-rigidCuffDepth)/110)
            let up = world.applying(upper), low = world.applying(lower), hand = world.applying(cuff)
            let sleeve = CGPoint(x:low.x+(up.x-low.x)*upperWeight,y:low.y+(up.y-low.y)*upperWeight)
            return CGPoint(x:hand.x+(sleeve.x-hand.x)*(1-cuffWeight)-frame.minX,
                           y:hand.y+(sleeve.y-hand.y)*(1-cuffWeight)-frame.minY)
        }
        var minimumDeterminant = CGFloat.greatestFiniteMagnitude
        for triangle in triangles {
            let q = triangle.points.map(mapped)
            let transform = Self.affine(triangle.points,q)
            minimumDeterminant = min(minimumDeterminant,transform.a*transform.d-transform.b*transform.c)
            triangle.layer.setAffineTransform(transform)
            // Expand each edge by a constant distance in the rendered canvas.
            // Radial expansion leaves almost no overlap on skinny triangles and
            // exposes white diagonal/horizontal raster cracks. Inverting the
            // map puts this exact destination-space padding into the mask.
            let destination = CGMutablePath()
            destination.move(to:q[0]); destination.addLine(to:q[1]); destination.addLine(to:q[2]); destination.closeSubpath()
            let border = destination.copy(strokingWithWidth:1.8,lineCap:.round,lineJoin:.round,miterLimit:2)
            var inverse = transform.inverted()
            triangle.border.path = border.copy(using:&inverse)
        }
        let projectedWrist = mapped(CGPoint(x:wrist.x-frame.minX,y:wrist.y-frame.minY))
        let cuffGap = hypot(projectedWrist.x+frame.minX-w.x,projectedWrist.y+frame.minY-w.y)
        diagnostics = ["shoulder":[s.x,s.y],"elbow":[e.x,e.y],"wrist":[w.x,w.y],
            "requestedWrist":[target.x,target.y],"wristError":hypot(w.x-target.x,w.y-target.y),
            "stretch":stretch,"minimumTriangleDeterminant":minimumDeterminant,
            "minimumDeterminant":minimumDeterminant,"cuffGap":cuffGap,
            "handAngle":handAngle,"triangleCount":triangles.count]
        return Result(wrist:w,handTransform:cuff)
    }

    /// Constrain the mesh boundary to the painted silhouette. A full resting
    /// hand widens its crop far to the left; those empty upper-left corners are
    /// not part of the sleeve and must not become giant deforming triangles.
    private static func textureRings(image: CGImage,size: CGSize,rows: Int) -> [(CGPoint,CGPoint)] {
        let bitmap = NSBitmapImageRep(cgImage:image)
        var spans = Array(repeating:(min:image.width,max:-1),count:image.height)
        for y in 0..<image.height {
            for x in 0..<image.width {
                if (bitmap.colorAt(x:x,y:y)?.alphaComponent ?? 0) > 0 {
                    spans[y].min = min(spans[y].min,x); spans[y].max = max(spans[y].max,x)
                }
            }
        }
        return (0...rows).map { row in
            let low = max(0,Int(Double(image.height)*(1-Double(row+1)/Double(rows))))
            let high = min(image.height,Int(Double(image.height)*(1-Double(row-1)/Double(rows)))+1)
            var left = image.width, right = -1
            if high > low {
                for y in low..<high { left = min(left,spans[y].min); right = max(right,spans[y].max) }
            }
            if right < left { left = 0; right = image.width-1 }
            let x0 = CGFloat(max(0,left-2))/CGFloat(image.width)*size.width
            let x1 = CGFloat(min(image.width,right+3))/CGFloat(image.width)*size.width
            let y = CGFloat(row)/CGFloat(rows)*size.height
            return (CGPoint(x:x0,y:y),CGPoint(x:x1,y:y))
        }
    }
    private static func smooth(_ x: CGFloat) -> CGFloat {
        let t = max(0,min(1,x)); return t*t*(3-2*t)
    }
    private static func bone(from: CGPoint,to: CGPoint,newFrom: CGPoint,newTo: CGPoint) -> CGAffineTransform {
        let v = CGPoint(x:to.x-from.x,y:to.y-from.y), n = CGPoint(x:newTo.x-newFrom.x,y:newTo.y-newFrom.y)
        let length = hypot(v.x,v.y), newLength = hypot(n.x,n.y)
        let u = CGPoint(x:v.x/length,y:v.y/length), d = CGPoint(x:n.x/newLength,y:n.y/newLength)
        let scale = newLength/length
        // Stretch only along the bone: sleeve width and cuff size stay stable.
        let a = scale*d.x*u.x+d.y*u.y, b = scale*d.y*u.x-d.x*u.y
        let c = scale*d.x*u.y-d.y*u.x, dd = scale*d.y*u.y+d.x*u.x
        return CGAffineTransform(a:a,b:b,c:c,d:dd,tx:newFrom.x-a*from.x-c*from.y,ty:newFrom.y-b*from.x-dd*from.y)
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
