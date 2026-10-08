import AppKit
import QuartzCore
import ViolaCore

/// A cloth texture is split into connected affine rectangular strips, supported by both
/// native Core Animation and CALayer.render(in:). The upper row stays attached.
final class ClothRig {
    private struct Patch { let layer: CALayer; let bottom: CGFloat; let top: CGFloat }
    private var patches: [Patch] = []
    private let width: CGFloat
    private let hem: CGFloat
    private let waist: CGFloat
    var attachmentY: CGFloat { waist }
    private var last = ClothFrame()
    init(container: CALayer, image: CGImage, definition: SpriteDefinition) {
        width = definition.frame.width
        let ys = definition.polygon?.map { $0[1] } ?? [0,1]
        let first = max(0,Int(floor((ys.min() ?? 0)*Double(image.height))))
        let end = min(image.height,Int(ceil((ys.max() ?? 1)*Double(image.height))))
        hem = CGFloat(image.height-end)/CGFloat(image.height)*definition.frame.height
        waist = CGFloat(image.height-first)/CGFloat(image.height)*definition.frame.height
        guard end > first, let texture = Self.maskedTexture(image,definition:definition) else { return }
        container.contents = nil; container.mask = nil
        // A mirrored sprite has a source-content child before this rig is created.
        for child in container.sublayers ?? [] { child.removeFromSuperlayer() }
        let count = min(32,max(8,(end-first)/6))
        for index in 0..<count {
            // One source-pixel overlap prevents texture filtering from opening
            // hairlines when the connected rows land between screen pixels.
            let start = max(first,first+(end-first)*index/count-1)
            let stop = min(end,first+(end-first)*(index+1)/count+1)
            guard stop > start, let crop = texture.cropping(to:CGRect(x:0,y:start,width:image.width,height:stop-start)) else { continue }
            let bottom = CGFloat(image.height-stop)/CGFloat(image.height)*definition.frame.height
            let top = CGFloat(image.height-start)/CGFloat(image.height)*definition.frame.height
            let layer = CALayer(); layer.contents = crop; layer.contentsGravity = .resize; layer.contentsScale = 2
            layer.bounds = CGRect(x:0,y:0,width:width,height:top-bottom); layer.anchorPoint = .zero
            // Use rectangles, avoiding independently antialiased triangle seams.
            layer.edgeAntialiasingMask = []; layer.allowsEdgeAntialiasing = false
            container.addSublayer(layer)
            patches.append(Patch(layer:layer,bottom:bottom,top:top))
        }
        render(ClothFrame())
    }
    func render(_ frame: ClothFrame) {
        last = frame
        for patch in patches {
            let bl = point(x:0,y:patch.bottom,frame:frame)
            let tl = point(x:0,y:patch.top,frame:frame)
            let height = patch.top-patch.bottom
            // Shared row positions keep the strip boundaries registered. Width
            // stays unchanged so each row is a parallelogram under one affine map.
            let transform = CGAffineTransform(a:1,b:0,c:(tl.x-bl.x)/height,
                                              d:(tl.y-bl.y)/height,tx:bl.x,ty:bl.y)
            patch.layer.position = .zero; patch.layer.setAffineTransform(transform)
        }
    }
    private func point(x: CGFloat, y: CGFloat, frame: ClothFrame) -> CGPoint {
        let span = max(1,waist-hem), depth = max(0,min(1,(waist-y)/span))
        // The seated waist and compressed upper pleats stay pinned. Only the
        // free lower cloth carries momentum; the original skirt length remains.
        let t = max(0,(depth-0.20)/0.80)
        let offset = max(-span*0.10,min(span*0.10,CGFloat(frame.offsetX)))
        let angle = max(-0.045,min(0.045,CGFloat(frame.angle)))
        let lift = max(-span*0.03,min(span*0.03,CGFloat(frame.liftY)))
        let shape = max(-1.35,min(1.35,CGFloat(frame.shape)))
        let lateral = offset*t*t+angle*span*t*t*(1-t)*0.35+shape*sin(t*CGFloat.pi)*t
        return CGPoint(x:x+lateral,y:y+lift*t*t)
    }
    private static func maskedTexture(_ image: CGImage, definition: SpriteDefinition) -> CGImage? {
        guard definition.polygon != nil || definition.mirror == true else { return image }
        guard let context = CGContext(data:nil,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:0,
            space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let w = CGFloat(image.width), h = CGFloat(image.height)
        if let polygon = definition.polygon {
            let path = CGMutablePath()
            for outline in [polygon]+(definition.cutouts ?? []) {
                for (index,p) in outline.enumerated() {
                    let point = CGPoint(x:CGFloat(definition.mirror == true ? 1-p[0] : p[0])*w,y:CGFloat(1-p[1])*h)
                    if index == 0 { path.move(to:point) } else { path.addLine(to:point) }
                }
                path.closeSubpath()
            }
            context.addPath(path); context.clip(using:.evenOdd)
        }
        if definition.mirror == true { context.translateBy(x:w,y:0); context.scaleBy(x:-1,y:1) }
        context.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
        return context.makeImage()
    }
    var diagnostic: [String:Any] {
        ["patches":patches.count,"waistY":waist,"hemY":hem,"offsetX":last.offsetX,
         "liftY":last.liftY,"angle":last.angle,"shape":last.shape]
    }
}
