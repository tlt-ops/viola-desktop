import AppKit
import QuartzCore

/// Only fills the deleted source desktop band, underneath original visible art.
final class ReferenceBodyCompletion {
    let costume = CALayer()
    let crown = CALayer()
    init(canvasSize: CGSize, patch: CGImage?) {
        for layer in [costume,crown] {
            layer.bounds = CGRect(origin:.zero,size:canvasSize)
            layer.anchorPoint = .zero; layer.position = .zero
        }
        guard let patch else { return }
        let registration = CGRect(x:260,y:440,width:390,height:180)
        let band = CGRect(x:260,y:476,width:390,height:65)
        // The completed local crop has the same framing as the original input.
        // Limit it to the missing band; the original exposed thigh and hem remain
        // foreground layers and are never replaced by the generated reference.
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
        let contour = CGMutablePath()
        contour.move(to:CGPoint(x:280,y:476)); contour.addLine(to:CGPoint(x:280,y:495))
        contour.addLine(to:CGPoint(x:312,y:505)); contour.addLine(to:CGPoint(x:338,y:512))
        contour.addLine(to:CGPoint(x:350,y:539)); contour.addLine(to:CGPoint(x:395,y:541))
        contour.addLine(to:CGPoint(x:650,y:541)); contour.addLine(to:CGPoint(x:650,y:476)); contour.closeSubpath()
        let clothingMask = CGMutablePath(); clothingMask.addPath(contour); clothingMask.addPath(purple)
        let garment = CALayer(); garment.frame = registration; garment.contents = patch; garment.contentsGravity = .resize
        let mask = CAShapeLayer(); var translation = CGAffineTransform(translationX:-registration.minX,y:-registration.minY)
        mask.path = clothingMask.copy(using:&translation); mask.fillRule = .evenOdd; mask.fillColor = NSColor.white.cgColor
        // A bounds mask prevents the purple cutout from introducing the reference
        // outside the narrow repair band through the even-odd outer polygon.
        garment.mask = mask; costume.addSublayer(garment)
        let restrict = CAShapeLayer(); restrict.path = CGPath(rect:band,transform:nil); restrict.fillColor = NSColor.white.cgColor
        costume.mask = restrict
        let hair = CALayer(); hair.frame = registration; hair.contents = patch; hair.contentsGravity = .resize
        let hairMask = CAShapeLayer(); hairMask.path = purple.copy(using:&translation); hairMask.fillColor = NSColor.white.cgColor
        hair.mask = hairMask; crown.addSublayer(hair)
        let cap = CAShapeLayer(); cap.path = CGPath(rect:CGRect(x:300,y:476,width:155,height:24),transform:nil); cap.fillColor = NSColor.white.cgColor
        crown.mask = cap
    }
    func render(seatX: Double, torsoY: Double, support: CGAffineTransform) {
        costume.position = CGPoint(x:seatX,y:torsoY)
        crown.position = CGPoint.zero.applying(support)
        crown.setAffineTransform(CGAffineTransform(a:support.a,b:support.b,c:support.c,d:support.d,tx:0,ty:0))
    }
}
