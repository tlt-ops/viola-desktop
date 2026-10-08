import AppKit
import QuartzCore
import ViolaCore

/// Small facial motions registered to the complete v0.2.29 source. Original
/// faces and hair remain in their body textures; no previous costume art is used.
final class SourceReferenceFaceRig {
    let root = CALayer()
    private let rider = CALayer()
    private let friend = CALayer()
    private let closed = CALayer()
    private let effort = CALayer()
    private let hearts = CALayer()

    init(canvasSize: CGSize, images: [String:CGImage], definitions: [String:SpriteDefinition]) {
        for layer in [root,rider,friend,closed,effort,hearts] {
            layer.bounds = CGRect(origin:.zero,size:canvasSize)
            layer.anchorPoint = .zero; layer.position = .zero; layer.contentsScale = 2
        }
        root.addSublayer(friend); root.addSublayer(rider)
        rider.addSublayer(closed); friend.addSublayer(effort); friend.addSublayer(hearts)
        func skin(_ id: String, _ x: CGFloat, _ y: CGFloat) -> CGColor {
            // Sample the actual supplied cheek in its registered crop. This is
            // only the narrow eyelid fill used while a closed lash is visible.
            if let image = images[id], let definition = definitions[id] {
                let p = Self.world(CGPoint(x:x,y:y)), f = definition.frame
                let ix = Int((p.x-f.minX)/f.width*CGFloat(image.width))
                let iy = Int((f.maxY-p.y)/f.height*CGFloat(image.height))
                let bitmap = NSBitmapImageRep(cgImage:image)
                if ix >= 0, iy >= 0, ix < bitmap.pixelsWide, iy < bitmap.pixelsHigh,
                   let color = bitmap.colorAt(x:ix,y:iy), color.alphaComponent > 0.8 {
                    return color.withAlphaComponent(1).cgColor
                }
            }
            return NSColor(calibratedRed:0.97,green:0.85,blue:0.81,alpha:1).cgColor
        }
        addEye(to:closed, outline:[[378,198],[398,194],[421,197],[431,207],[423,219],[409,226],[391,220]],
               lash:[[380,207],[395,218],[414,220],[428,210]],fill:skin("head",411,233))
        addEye(to:closed, outline:[[455,190],[474,182],[493,182],[504,188],[500,204],[484,214],[465,211]],
               lash:[[457,198],[473,209],[491,207],[502,192]],fill:skin("head",480,225))
        addEye(to:effort, outline:[[286,775],[310,765],[335,760],[350,767],[350,785],[329,800],[307,799]],
               lash:[[289,779],[309,794],[335,791],[350,777]],fill:skin("seating",320,812))
        addEye(to:effort, outline:[[380,755],[398,744],[426,737],[439,739],[438,761],[419,779],[399,782]],
               lash:[[383,763],[403,775],[425,767],[437,748]],fill:skin("seating",411,795))
        addHeart(at:CGPoint(x:325,y:780),size:12)
        addHeart(at:CGPoint(x:415,y:760),size:13)
    }

    func render(blink: Double, laugh: Double, expression: FriendExpression, opacity: Double,
                seatX: Double, torsoY: Double, support: CGAffineTransform) {
        rider.position = CGPoint(x:seatX,y:torsoY)
        friend.setAffineTransform(support)
        closed.opacity = blink >= 0.55 || laugh > 0.12 ? 1 : 0
        effort.opacity = expression == .effort && opacity > 0.01 ? 1 : 0
        hearts.opacity = expression == .hearts ? Float(opacity) : 0
    }

    private static func world(_ p: CGPoint) -> CGPoint { CGPoint(x:24+0.64*p.x,y:940-0.64*p.y) }
    private func addEye(to parent: CALayer, outline: [[CGFloat]], lash: [[CGFloat]], fill: CGColor) {
        let patch = CAShapeLayer(), boundary = CGMutablePath()
        for (index,p) in outline.enumerated() {
            let point = Self.world(CGPoint(x:p[0],y:p[1]))
            if index == 0 { boundary.move(to:point) } else { boundary.addLine(to:point) }
        }
        boundary.closeSubpath(); patch.path = boundary; patch.fillColor = fill
        parent.addSublayer(patch)
        let line = CAShapeLayer(), path = CGMutablePath()
        path.move(to:Self.world(CGPoint(x:lash[0][0],y:lash[0][1])))
        path.addCurve(to:Self.world(CGPoint(x:lash[3][0],y:lash[3][1])),
            control1:Self.world(CGPoint(x:lash[1][0],y:lash[1][1])),
            control2:Self.world(CGPoint(x:lash[2][0],y:lash[2][1])))
        line.path = path; line.fillColor = nil
        line.strokeColor = NSColor(calibratedRed:0.18,green:0.12,blue:0.19,alpha:1).cgColor
        line.lineWidth = 1.9; line.lineCap = .round; parent.addSublayer(line)
    }
    private func addHeart(at source: CGPoint, size: CGFloat) {
        let path = CGMutablePath()
        path.move(to:CGPoint(x:0,y:-0.5))
        path.addCurve(to:CGPoint(x:-0.48,y:0.12),control1:CGPoint(x:-0.18,y:-0.27),control2:CGPoint(x:-0.52,y:-0.04))
        path.addCurve(to:CGPoint(x:0,y:0.23),control1:CGPoint(x:-0.45,y:0.48),control2:CGPoint(x:-0.12,y:0.47))
        path.addCurve(to:CGPoint(x:0.48,y:0.12),control1:CGPoint(x:0.12,y:0.47),control2:CGPoint(x:0.45,y:0.48))
        path.addCurve(to:CGPoint(x:0,y:-0.5),control1:CGPoint(x:0.52,y:-0.04),control2:CGPoint(x:0.18,y:-0.27))
        path.closeSubpath()
        var scale = CGAffineTransform(scaleX:size*0.64,y:size*0.64)
        let layer = CAShapeLayer(); layer.path = path.copy(using:&scale)
        layer.position = Self.world(source)
        layer.fillColor = NSColor(calibratedRed:1,green:0.7,blue:0.85,alpha:1).cgColor
        layer.strokeColor = NSColor(calibratedRed:0.51,green:0.27,blue:0.49,alpha:1).cgColor
        layer.lineWidth = 0.65; hearts.addSublayer(layer)
    }
}
