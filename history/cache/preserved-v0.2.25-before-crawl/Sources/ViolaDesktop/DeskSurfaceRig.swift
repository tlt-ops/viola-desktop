import AppKit
import QuartzCore

/// One statically textured desk with a shared hinge, in character canvas space.
/// The source is the existing [30,190,1900,510] modular-desk crop.
final class DeskSurfaceRig {
    let root = CALayer()
    private let footprint = CGMutablePath()
    private static let thickness: CGFloat = 9

    init(canvasSize: CGSize, source: CGImage) {
        root.bounds = CGRect(origin:.zero,size:canvasSize)
        root.anchorPoint = .zero; root.position = .zero
        root.contentsGravity = .resize; root.contentsScale = 2
        // Flatten the keyboard-side board while retaining the shared hinge and
        // the complete mouse-side board's original geometry.
        let left = [CGPoint(x:188,y:557),CGPoint(x:447,y:547),
                    CGPoint(x:406,y:425),CGPoint(x:170,y:458)]
        let right = [left[1],CGPoint(x:655,y:541),CGPoint(x:673,y:417),left[2]]
        func lower(_ point: CGPoint) -> CGPoint { CGPoint(x:point.x,y:point.y-Self.thickness) }
        let leftFront = [left[3],left[2],lower(left[2]),lower(left[3])]
        let rightFront = [right[3],right[2],lower(right[2]),lower(right[3])]
        let leftSide = [left[0],left[3],lower(left[3]),lower(left[0])]
        let rightSide = [right[1],right[2],lower(right[2]),lower(right[1])]
        for outline in [left,right,leftFront,rightFront,leftSide,rightSide] {
            footprint.move(to:outline[0])
            for point in outline.dropFirst() { footprint.addLine(to:point) }
            footprint.closeSubpath()
        }
        let scale: CGFloat = 2
        guard let context = CGContext(data:nil,width:Int(canvasSize.width*scale),height:Int(canvasSize.height*scale),
            bitsPerComponent:8,bytesPerRow:0,space:source.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.scaleBy(x:scale,y:scale)
        context.interpolationQuality = .high
        // Shared clip edges have a single raster owner. Partial-alpha clipping
        // on two adjoining triangles would expose a white line at the hinge.
        context.setAllowsAntialiasing(false); context.setShouldAntialias(false)
        func sourcePoint(_ x: CGFloat,_ y: CGFloat) -> CGPoint {
            CGPoint(x:x/1900*CGFloat(source.width),y:(1-y/510)*CGFloat(source.height))
        }
        func polygon(_ sourcePoints: [(CGFloat,CGFloat)],_ targetPoints: [CGPoint]) {
            guard sourcePoints.count == targetPoints.count, sourcePoints.count >= 3 else { return }
            let points = sourcePoints.map { sourcePoint($0.0,$0.1) }
            var sourceCenter = CGPoint.zero, targetCenter = CGPoint.zero
            for point in points { sourceCenter.x += point.x; sourceCenter.y += point.y }
            for point in targetPoints { targetCenter.x += point.x; targetCenter.y += point.y }
            sourceCenter.x /= CGFloat(points.count); sourceCenter.y /= CGFloat(points.count)
            targetCenter.x /= CGFloat(points.count); targetCenter.y /= CGFloat(points.count)
            for index in points.indices {
                let next = (index+1)%points.count
                Self.drawTriangle(source:source,context:context,
                    from:[sourceCenter,points[index],points[next]],
                    to:[targetCenter,targetPoints[index],targetPoints[next]])
            }
        }
        // Retain the original front/side-face texture rather than synthesizing
        // a flat dark stroke. Both front faces end on the same lowered hinge.
        polygon([(12,270),(204,447),(204,488),(12,308)],leftSide)
        polygon([(1830,259),(1862,257),(1862,300),(1830,302)],rightSide)
        polygon([(204,447),(1058,205),(1058,245),(204,488)],leftFront)
        polygon([(1058,205),(1862,257),(1862,300),(1058,245)],rightFront)
        // The original left back edge has a fifth bevel corner at (965,6).
        // Map it onto the straight target back edge, keeping all source tabletop
        // pixels instead of discarding the large triangular area above a quad.
        let bevel = CGPoint(x:left[0].x+(left[1].x-left[0].x)*0.87,
                            y:left[0].y+(left[1].y-left[0].y)*0.87)
        polygon([(12,270),(965,6),(1120,45),(1058,205),(204,447)],
                [left[0],bevel,left[1],left[2],left[3]])
        polygon([(1120,45),(1830,70),(1862,257),(1058,205)],right)
        root.contents = context.makeImage()
    }

    /// Only the actual board surfaces and their nine-pixel faces intercept clicks.
    func contains(_ point: CGPoint) -> Bool { footprint.contains(point,using:.winding,transform:.identity) }

    private static func drawTriangle(source: CGImage, context: CGContext, from s: [CGPoint], to d: [CGPoint]) {
        let sx = s[1].x-s[0].x, sy = s[1].y-s[0].y
        let tx = s[2].x-s[0].x, ty = s[2].y-s[0].y
        let determinant = sx*ty-tx*sy
        guard abs(determinant) > 0.00001 else { return }
        let ax = ((d[1].x-d[0].x)*ty-(d[2].x-d[0].x)*sy)/determinant
        let bx = ((d[1].y-d[0].y)*ty-(d[2].y-d[0].y)*sy)/determinant
        let cx = (sx*(d[2].x-d[0].x)-tx*(d[1].x-d[0].x))/determinant
        let dx = (sx*(d[2].y-d[0].y)-tx*(d[1].y-d[0].y))/determinant
        let transform = CGAffineTransform(a:ax,b:bx,c:cx,d:dx,
            tx:d[0].x-ax*s[0].x-cx*s[0].y,ty:d[0].y-bx*s[0].x-dx*s[0].y)
        let clip = CGMutablePath(); clip.move(to:d[0]); clip.addLine(to:d[1]); clip.addLine(to:d[2]); clip.closeSubpath()
        context.saveGState(); context.addPath(clip); context.clip(); context.concatenate(transform)
        context.draw(source,in:CGRect(x:0,y:0,width:source.width,height:source.height))
        context.restoreGState()
    }
}
