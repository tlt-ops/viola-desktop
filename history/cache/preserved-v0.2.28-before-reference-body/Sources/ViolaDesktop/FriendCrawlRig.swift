import AppKit
import QuartzCore
import ViolaCore

/// Deforms only the friend's existing, ownership-corrected pixels. All masks
/// travel with their texture; neither a fixed mask nor the seated rider is warped.
final class FriendCrawlRig {
    private struct Triangle {
        let layer: CALayer
        let rect: CGRect
        let lowerRight: Bool
        let padding: CGPoint
    }
    private final class Mesh {
        let container: CALayer
        let originalContents: Any?
        let originalMask: CALayer?
        let root = CALayer()
        let frame: CGRect
        var triangles: [Triangle] = []
        var active = false
        var maxVertexDisplacement: CGFloat = 0
        var minimumDeterminant: CGFloat = 1
        var minimumCell = CGPoint.zero

        init?(container: CALayer, frame: CGRect, sources: [CALayer]) {
            guard container.contents != nil else { return nil }
            self.container = container; self.frame = frame
            originalContents = container.contents; originalMask = container.mask
            // Bake the existing softened texture and its exact source ownership
            // mask once. CGImage cropping below uses top-origin pixel rows.
            let scale: CGFloat = 2
            let width = Int(ceil(frame.width*scale)), height = Int(ceil(frame.height*scale))
            guard let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,
                bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),
                bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.scaleBy(x:CGFloat(width)/frame.width,y:CGFloat(height)/frame.height)
            // The original rest-arm cutouts cross folds inside the sleeve. Bake
            // their complementary ownership together before deformation so a
            // moving seam cannot reveal an old, stationary cutout behind it.
            for source in sources { source.render(in:context) }
            guard let baked = context.makeImage(), let provider = baked.dataProvider,
                  let data = provider.data, let bytes = CFDataGetBytePtr(data) else { return nil }
            root.bounds = container.bounds; root.anchorPoint = .zero; root.position = .zero
            root.isHidden = true; root.contentsScale = 2
            let cell = 40 // Twenty canvas pixels, with shared edges at every vertex.
            for row in stride(from:0,to:height,by:cell) {
                for column in stride(from:0,to:width,by:cell) {
                    let right = min(width,column+cell), end = min(height,row+cell)
                    var hasPixels = false
                    for y in row..<end {
                        for x in column..<right where bytes[y*baked.bytesPerRow+x*4+3] > 0 {
                            hasPixels = true; break
                        }
                        if hasPixels { break }
                    }
                    let cropLeft = max(0,column-3), cropRight = min(width,right+3)
                    let cropTop = max(0,row-3), cropBottom = min(height,end+3)
                    guard hasPixels,
                          let cut = baked.cropping(to:CGRect(x:cropLeft,y:cropTop,width:cropRight-cropLeft,height:cropBottom-cropTop)) else { continue }
                    let rect = CGRect(x:CGFloat(column)/CGFloat(width)*frame.width,
                        y:CGFloat(height-end)/CGFloat(height)*frame.height,
                        width:CGFloat(right-column)/CGFloat(width)*frame.width,
                        height:CGFloat(end-row)/CGFloat(height)*frame.height)
                    for lowerRight in [true,false] {
                        let layer = CALayer(); layer.contents = cut; layer.contentsGravity = .resize
                        layer.contentsScale = 2; layer.anchorPoint = .zero
                        let padding = CGPoint(x:CGFloat(column-cropLeft)/CGFloat(width)*frame.width,
                            y:CGFloat(cropBottom-end)/CGFloat(height)*frame.height)
                        layer.bounds = CGRect(x:0,y:0,width:CGFloat(cropRight-cropLeft)/CGFloat(width)*frame.width,
                            height:CGFloat(cropBottom-cropTop)/CGFloat(height)*frame.height)
                        let mask = CAShapeLayer(), path = CGMutablePath()
                        path.move(to:padding)
                        if lowerRight {
                            path.addLine(to:CGPoint(x:rect.width+padding.x,y:padding.y))
                            path.addLine(to:CGPoint(x:rect.width+padding.x,y:rect.height+padding.y))
                        } else {
                            path.addLine(to:CGPoint(x:rect.width+padding.x,y:rect.height+padding.y))
                            path.addLine(to:CGPoint(x:padding.x,y:rect.height+padding.y))
                        }
                        path.closeSubpath(); mask.path = path; mask.fillColor = NSColor.white.cgColor
                        // Stroke reaches real neighboring texels, not a crop's
                        // transparent edge. Shared nominal corners stay exact.
                        mask.strokeColor = NSColor.white.cgColor; mask.lineWidth = 1.8
                        layer.mask = mask; root.addSublayer(layer)
                        triangles.append(Triangle(layer:layer,rect:rect,lowerRight:lowerRight,padding:padding))
                    }
                }
            }
            container.addSublayer(root)
        }

        func render(active: Bool, mapping: (CGPoint) -> CGPoint) {
            if self.active != active {
                self.active = active; root.isHidden = !active
                container.contents = active ? nil : originalContents
                container.mask = active ? nil : originalMask
            }
            maxVertexDisplacement = 0; minimumDeterminant = 1; minimumCell = .zero
            guard active else { return }
            func vertex(_ p: CGPoint) -> CGPoint {
                let world = CGPoint(x:p.x+frame.minX,y:p.y+frame.minY)
                let moved = mapping(world)
                maxVertexDisplacement = max(maxVertexDisplacement,hypot(moved.x-world.x,moved.y-world.y))
                return CGPoint(x:moved.x-frame.minX,y:moved.y-frame.minY)
            }
            for triangle in triangles {
                let r = triangle.rect
                let a = vertex(CGPoint(x:r.minX,y:r.minY)), b = vertex(CGPoint(x:r.maxX,y:r.minY))
                let c = vertex(CGPoint(x:r.maxX,y:r.maxY)), d = vertex(CGPoint(x:r.minX,y:r.maxY))
                let h = triangle.lowerRight ? CGPoint(x:b.x-a.x,y:b.y-a.y) : CGPoint(x:c.x-d.x,y:c.y-d.y)
                let v = triangle.lowerRight ? CGPoint(x:c.x-b.x,y:c.y-b.y) : CGPoint(x:d.x-a.x,y:d.y-a.y)
                let padding = triangle.padding
                let t = CGAffineTransform(a:h.x/r.width,b:h.y/r.width,c:v.x/r.height,d:v.y/r.height,
                    tx:a.x-h.x/r.width*padding.x-v.x/r.height*padding.y,
                    ty:a.y-h.y/r.width*padding.x-v.y/r.height*padding.y)
                let determinant = t.a*t.d-t.b*t.c
                if determinant < minimumDeterminant {
                    minimumDeterminant = determinant
                    minimumCell = CGPoint(x:frame.minX+r.midX,y:frame.minY+r.midY)
                }
                triangle.layer.position = .zero; triangle.layer.setAffineTransform(t)
            }
        }

        /// Measure the rendered triangle's affine mapping, including its parent
        /// support transform, rather than reporting the requested target as evidence.
        func renderedPoint(_ world: CGPoint) -> CGPoint? {
            let p = CGPoint(x:world.x-frame.minX,y:world.y-frame.minY)
            if !active { return container.superlayer.map { container.convert(p,to:$0) } }
            for triangle in triangles where triangle.rect.contains(p) {
                let r = triangle.rect
                let x = (p.x-r.minX)/r.width, y = (p.y-r.minY)/r.height
                guard triangle.lowerRight ? y <= x : y >= x else { continue }
                let local = CGPoint(x:p.x-r.minX+triangle.padding.x,y:p.y-r.minY+triangle.padding.y)
                guard let canvas = container.superlayer else { return nil }
                return triangle.layer.convert(local,to:canvas)
            }
            return nil
        }
    }

    private struct ArmPose {
        let shoulder: CGPoint
        let elbow: CGPoint
        let palm: CGPoint
        let target: CGPoint
        let solvedElbow: CGPoint
        let reachScale: CGFloat
        let upperLengthRatio: CGFloat
        let lowerLengthRatio: CGFloat
        let capY: CGFloat

        init(back: Bool, target: CGPoint) {
            shoulder = back ? CGPoint(x:330,y:312) : CGPoint(x:453,y:302)
            elbow = back ? CGPoint(x:327,y:226) : CGPoint(x:450,y:215)
            palm = back ? CGPoint(x:286.4,y:140) : CGPoint(x:433.6,y:120.8)
            capY = 290
            self.target = target
            let first = hypot(elbow.x-shoulder.x,elbow.y-shoulder.y)
            let second = hypot(palm.x-elbow.x,palm.y-elbow.y)
            let delta = CGPoint(x:target.x-shoulder.x,y:target.y-shoulder.y)
            let distance = max(0.01,hypot(delta.x,delta.y))
            // Keep the source bend direction and fixed bone lengths except for a
            // very small reach beyond full extension. No independent palm scale.
            reachScale = max(1,distance/(first+second-0.01))
            let a = first*reachScale, b = second*reachScale
            let along = (a*a-b*b+distance*distance)/(2*distance)
            let height = sqrt(max(0,a*a-along*along))
            let u = CGPoint(x:delta.x/distance,y:delta.y/distance)
            let cross = (palm.x-shoulder.x)*(elbow.y-shoulder.y)-(palm.y-shoulder.y)*(elbow.x-shoulder.x)
            let sign: CGFloat = cross >= 0 ? 1 : -1
            let ideal = CGPoint(x:shoulder.x+u.x*along-u.y*height*sign,
                y:shoulder.y+u.y*along+u.x*height*sign)
            // A nearly straight source sleeve has little visible elbow depth.
            // Bound its projected bend instead of forcing the large sideways IK
            // solution into a narrow painted sleeve and folding its texture.
            solvedElbow = CGPoint(x:elbow.x+12*tanh((ideal.x-elbow.x)/12),
                y:elbow.y+6*tanh((ideal.y-elbow.y)/6))
            upperLengthRatio = hypot(solvedElbow.x-shoulder.x,solvedElbow.y-shoulder.y)/first
            lowerLengthRatio = hypot(target.x-solvedElbow.x,target.y-solvedElbow.y)/second
        }

        func map(_ p: CGPoint) -> CGPoint {
            func transformed(from: CGPoint, to: CGPoint, sourceEnd: CGPoint, targetEnd: CGPoint) -> CGPoint {
                let x = p.x-from.x, y = p.y-from.y
                let vx = sourceEnd.x-from.x, vy = sourceEnd.y-from.y
                let along = (x*vx+y*vy)/max(1,vx*vx+vy*vy)
                // Map both joint endpoints while retaining every transverse
                // cross-section's source width. Cloth can shorten slightly when
                // its elbow bends, but the whole sleeve never scales like rubber.
                return CGPoint(x:to.x+x+(targetEnd.x-to.x-vx)*along,
                               y:to.y+y+(targetEnd.y-to.y-vy)*along)
            }
            let upper = transformed(from:shoulder,to:shoulder,sourceEnd:elbow,targetEnd:solvedElbow)
            let lower = transformed(from:elbow,to:solvedElbow,sourceEnd:palm,targetEnd:target)
            let bend = FriendCrawlRig.smooth((elbow.y+22-p.y)/44)
            let limb = FriendCrawlRig.mix(upper,lower,bend)
            let rigidPalm = CGPoint(x:p.x+target.x-palm.x,y:p.y+target.y-palm.y)
            let wrist = FriendCrawlRig.smooth((palm.y+38-p.y)/25)
            let moved = FriendCrawlRig.mix(limb,rigidPalm,wrist)
            // Entire painted upper cut edge stays bound to the torso, including
            // its slanted corners. Bend begins below that shared source boundary.
            return FriendCrawlRig.mix(p,moved,FriendCrawlRig.smooth((capY-p.y)/35))
        }
    }

    private var meshes: [String:Mesh] = [:]
    private var poses: [String:ArmPose] = [:]
    private var support = CGAffineTransform.identity
    private var crawl = CrawlFrame()
    private var targets: [String:CGPoint] = [:]
    private var baselineSupport = CGAffineTransform.identity
    private var restArms: [CALayer] = []
    private var armVisibility: [Bool] = []
    private var armsHidden = false

    init(layers: [String:CALayer], definitions: [String:SpriteDefinition]) {
        restArms = ["friend_rest_back","friend_rest_front"].compactMap { layers[$0] }
        if let layer = layers["seating"], let definition = definitions["seating"],
           let mesh = Mesh(container:layer,frame:definition.frame,sources:[layer]+restArms) {
            meshes["seating"] = mesh
        }
    }

    func render(_ crawl: CrawlFrame, support: CGAffineTransform, baselineSupport: CGAffineTransform) {
        self.crawl = crawl; self.support = support; self.baselineSupport = baselineSupport
        let active = crawl.weight > 0.000001
        if active != armsHidden {
            if active {
                armVisibility = restArms.map(\.isHidden)
                for arm in restArms { arm.isHidden = true }
            } else {
                for (arm,hidden) in zip(restArms,armVisibility) { arm.isHidden = hidden }
            }
            armsHidden = active
        }
        if !active {
            // Native idle draws do not solve or update the dormant mesh.
            for mesh in meshes.values where mesh.active { mesh.render(active:false,mapping: { $0 }) }
            poses.removeAll(keepingCapacity:true); targets.removeAll(keepingCapacity:true)
            return
        }
        poses.removeAll(keepingCapacity:true); targets.removeAll(keepingCapacity:true)
        for back in [true,false] {
            let id = back ? "friend_rest_back" : "friend_rest_front"
            let palm = back ? CGPoint(x:286.4,y:140) : CGPoint(x:433.6,y:120.8)
            let base = palm.applying(baselineSupport)
            let target = CGPoint(x:base.x+(back ? crawl.backHandX : crawl.frontHandX),
                                 y:base.y+(back ? crawl.backHandY : crawl.frontHandY))
            let pose = ArmPose(back:back,target:target.applying(support.inverted()))
            poses[id] = pose; targets[id] = target
        }
        meshes["seating"]?.render(active:active) { self.mapFriend($0) }
    }

    private func mapFriend(_ p: CGPoint) -> CGPoint {
        var dx: CGFloat = 0, dy: CGFloat = 0, total: CGFloat = 0
        for pose in poses.values {
            let t = Self.smooth((pose.shoulder.y-p.y)/max(1,pose.shoulder.y-pose.palm.y))
            let center = pose.shoulder.x+(pose.palm.x-pose.shoulder.x)*t
            let w = 1-Self.smooth((abs(p.x-center)-42)/75)
            guard w > 0 else { continue }
            let moved = pose.map(p)
            dx += (moved.x-p.x)*w; dy += (moved.y-p.y)*w; total += w
        }
        let dress = mapDress(p)
        return CGPoint(x:dress.x+dx/max(1,total),y:dress.y+dy/max(1,total))
    }

    private func mapDress(_ p: CGPoint) -> CGPoint {
        // Spatial weights live exclusively in the connected lower dress. They
        // vanish above the waist and beside the rider's independently owned calf.
        let vertical = Self.smooth((330-p.y)/130), left = Self.smooth((p.x-536)/44)
        let near = exp(-pow((p.x-616)/105,2)-pow((p.y-166)/150,2))
        let far = exp(-pow((p.x-735)/92,2)-pow((p.y-156)/150,2))
        let total = max(1,near+far), w = vertical*left
        return CGPoint(x:p.x+w*(near*crawl.frontKneeX+far*crawl.backKneeX)/total,
                       y:p.y+w*(near*crawl.frontKneeY+far*crawl.backKneeY)/total)
    }

    func contact(_ id: String) -> CGPoint? {
        guard crawl.weight > 0.000001, let pose = poses[id] else { return nil }
        return meshes["seating"]?.renderedPoint(pose.palm)
    }

    var diagnostics: [String:Any] {
        func pair(_ p: CGPoint) -> [Double] { [p.x,p.y] }
        var arms: [String:Any] = [:]
        for (id,pose) in poses {
            let expectedShoulder = pose.shoulder.applying(support)
            let shoulder = meshes["seating"]?.renderedPoint(pose.shoulder)
            let palm = meshes["seating"]?.renderedPoint(pose.palm)
            let target = targets[id]!
            arms[id] = ["palm":palm.map(pair) ?? [],"target":pair(target),
                "palmTargetError":palm.map { hypot($0.x-target.x,$0.y-target.y) } ?? -1,
                "shoulder":shoulder.map(pair) ?? [],"expectedShoulder":pair(expectedShoulder),
                "shoulderAttachmentError":shoulder.map { hypot($0.x-expectedShoulder.x,$0.y-expectedShoulder.y) } ?? -1,
                "elbow":pair(pose.solvedElbow.applying(support)),"reachScale":pose.reachScale,
                "upperLengthRatio":pose.upperLengthRatio,"lowerLengthRatio":pose.lowerLengthRatio]
        }
        let knees = ["front":CGPoint(x:616,y:166),"back":CGPoint(x:735,y:156)].mapValues { p -> [String:Any] in
            let rest = p.applying(support), rendered = meshes["seating"]?.renderedPoint(p)
            return ["source":pair(p),"rendered":rendered.map(pair) ?? [],
                    "displacement":rendered.map { pair(CGPoint(x:$0.x-rest.x,y:$0.y-rest.y)) } ?? []]
        }
        let waist = [CGPoint(x:580,y:350),CGPoint(x:640,y:350)].map { p -> [String:Any] in
            let expected = p.applying(support), rendered = meshes["seating"]?.renderedPoint(p)
            return ["source":pair(p),"expected":pair(expected),"rendered":rendered.map(pair) ?? [],
                "attachmentError":rendered.map { hypot($0.x-expected.x,$0.y-expected.y) } ?? -1]
        }
        return ["active":crawl.active,"weight":crawl.weight,"phase":crawl.phase,
                "arms":arms,"knees":knees,"waist":waist,"meshCount":meshes.count,
                "meshes":meshes.mapValues { ["enabled":$0.active,"triangleCount":$0.triangles.count,
                    "maxVertexDisplacement":$0.maxVertexDisplacement,"minimumDeterminant":$0.minimumDeterminant,
                    "minimumCellSource":pair($0.minimumCell)] as [String:Any] }]
    }

    private static func smooth(_ x: CGFloat) -> CGFloat { let t = max(0,min(1,x)); return t*t*(3-2*t) }
    private static func mix(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t)
    }
}
