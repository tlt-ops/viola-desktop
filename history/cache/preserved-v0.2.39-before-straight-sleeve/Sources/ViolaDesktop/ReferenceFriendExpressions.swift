import AppKit
import QuartzCore
import ViolaCore

/// Eye-only overlays registered directly to the reference illustration. The
/// original hair, eyebrows and heart-expression lashes remain in the base art.
final class ReferenceFriendExpressions {
    static let retiredEyeIDs: Set<String> = ["friend_effort_eye_l", "friend_effort_eye_r", "friend_hearts_eye_l", "friend_hearts_eye_r", "friend_reference_effort_eyes"]
    let root = CALayer()
    private let hearts = CALayer()
    private let effort = CALayer()

    init(canvasSize: CGSize, closedEyes: CGImage? = nil) {
        for layer in [root, hearts, effort] {
            layer.bounds = CGRect(origin: .zero, size: canvasSize)
            layer.anchorPoint = .zero
            layer.position = .zero
            layer.contentsScale = 2
        }
        root.addSublayer(hearts); root.addSublayer(effort)
        // Keep the reference iris and upper lash intact; only its pupil gets a
        // pink heart, avoiding a second eye silhouette at expression transitions.
        addHeart(center: CGPoint(x: 481, y: 747), size: 14, rotation: -0.10)
        addHeart(center: CGPoint(x: 566, y: 733), size: 17, rotation: 0.10)

        // Boundaries follow the reference's actual open eyes, including the
        // outer lash tips. The opaque core removes the entire iris and lash.
        let left = path([
            [448,743], [454,737,460,732,472,732],
            [486,731,497,735,503,742], [507,749,501,757,496,760],
            [481,765,467,763,456,752], [451,749,449,746,448,743]
        ])
        let right = path([
            [536,730], [544,718,557,715,569,711],
            [578,708,585,708,589,709], [587,722,587,733,581,741],
            [576,748,565,752,554,749], [546,745,540,739,537,731]
        ])
        if let closedEyes {
            addRegisteredClosedEyes(closedEyes, outlines:[left,right])
            return
        }
        addSkinPatch(left, sourceBounds: CGRect(x: 446,y: 728,width: 64,height: 40), top: [251,232,220], bottom: [253,216,208])
        addSkinPatch(right, sourceBounds: CGRect(x: 533,y: 706,width: 59,height: 50), top: [252,226,216], bottom: [251,213,205])
        // A single lowered closed lash replaces each open eye. The endpoints
        // retain the original asymmetry and face tilt, instead of transplanting
        // lashes/strands from the retired face crop.
        addLash(path([[450,747],[465,738,486,738,501,747]]), width: 3.4)
        addLash(path([[539,738],[552,726,574,722,590,714]]), width: 3.8)
        for points in [
            [[450.0,747.0],[447,745],[445,743]],
            [[454.0,744.0],[450,741],[449,739]],
            [[459.0,742.0],[456,738],[455,737]],
            [[589.0,715.0],[592,712],[594,710]],
            [[584.0,717.0],[588,713],[589,711]]
        ] { addLash(path(points), width: 1.8) }
    }

    func render(expression: FriendExpression, opacity: Double, support: CGAffineTransform) {
        root.position = .zero
        root.setAffineTransform(support)
        hearts.opacity = expression == .hearts ? Float(opacity) : 0
        // Switching the skin patch on as a unit prevents the original open eye
        // showing through the replacement closed lash during the fade.
        effort.opacity = expression == .effort && opacity > 0.01 ? 1 : 0
    }

    private func world(_ p: CGPoint) -> CGPoint { CGPoint(x: 40+0.64*p.x,y: 860-0.64*p.y) }
    private func path(_ points: [[Double]]) -> CGPath {
        let p = CGMutablePath()
        for (i, v) in points.enumerated() {
            if i == 0 { p.move(to: world(CGPoint(x:v[0],y:v[1]))) }
            else if v.count == 6 {
                p.addCurve(to:world(CGPoint(x:v[4],y:v[5])),control1:world(CGPoint(x:v[0],y:v[1])),control2:world(CGPoint(x:v[2],y:v[3])))
            } else { p.addLine(to:world(CGPoint(x:v[0],y:v[1]))) }
        }
        return p
    }
    private func color(_ rgb: [CGFloat]) -> CGColor {
        NSColor(calibratedRed:rgb[0]/255,green:rgb[1]/255,blue:rgb[2]/255,alpha:1).cgColor
    }
    private func addRegisteredClosedEyes(_ image: CGImage, outlines: [CGPath]) {
        let texture = CALayer()
        texture.frame = CGRect(x:300,y:315,width:155,height:145)
        texture.contents = image; texture.contentsGravity = .resize; texture.contentsScale = 2
        let combined = CGMutablePath()
        var local = CGAffineTransform(translationX:-300,y:-315)
        for outline in outlines {
            let closed = outline.mutableCopy()!; closed.closeSubpath()
            if let translated = closed.copy(using:&local) { combined.addPath(translated) }
        }
        let mask = CAShapeLayer(); mask.frame = texture.bounds; mask.path = combined
        mask.fillColor = NSColor.white.cgColor; mask.strokeColor = NSColor.white.cgColor
        mask.lineWidth = 1.5; mask.lineJoin = .round
        mask.shadowColor = NSColor.white.cgColor; mask.shadowOpacity = 1
        mask.shadowRadius = 0.65; mask.shadowOffset = .zero; mask.shadowPath = combined
        texture.mask = mask; effort.addSublayer(texture)
    }
    private func addSkinPatch(_ outline: CGPath, sourceBounds: CGRect, top: [CGFloat], bottom: [CGFloat]) {
        let gradient = CAGradientLayer()
        let origin = world(CGPoint(x:sourceBounds.minX,y:sourceBounds.maxY))
        gradient.frame = CGRect(x:origin.x,y:origin.y,width:sourceBounds.width*0.64,height:sourceBounds.height*0.64)
        gradient.colors = [color(bottom),color(top)]
        gradient.startPoint = CGPoint(x:0.5,y:0); gradient.endPoint = CGPoint(x:0.5,y:1)
        let mask = CAShapeLayer()
        var translation = CGAffineTransform(translationX:-origin.x,y:-origin.y)
        let closed = outline.mutableCopy()!; closed.closeSubpath()
        mask.path = closed.copy(using:&translation)
        mask.fillColor = NSColor.white.cgColor
        gradient.mask = mask; effort.addSublayer(gradient)
    }
    private func addLash(_ outline: CGPath, width: CGFloat) {
        let lash = CAShapeLayer(); lash.path = outline
        lash.fillColor = nil; lash.strokeColor = color([44,32,49])
        lash.lineWidth = width*0.64; lash.lineCap = .round; lash.lineJoin = .round
        effort.addSublayer(lash)
    }
    private func addHeart(center: CGPoint, size: CGFloat, rotation: CGFloat) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x:0,y:-0.50))
        p.addCurve(to:CGPoint(x:-0.48,y:0.12),control1:CGPoint(x:-0.18,y:-0.27),control2:CGPoint(x:-0.52,y:-0.04))
        p.addCurve(to:CGPoint(x:0,y:0.23),control1:CGPoint(x:-0.45,y:0.48),control2:CGPoint(x:-0.12,y:0.47))
        p.addCurve(to:CGPoint(x:0.48,y:0.12),control1:CGPoint(x:0.12,y:0.47),control2:CGPoint(x:0.45,y:0.48))
        p.addCurve(to:CGPoint(x:0,y:-0.50),control1:CGPoint(x:0.52,y:-0.04),control2:CGPoint(x:0.18,y:-0.27))
        p.closeSubpath()
        var transform = CGAffineTransform(scaleX:size*0.64,y:size*0.64).rotated(by:rotation)
        let heart = CAShapeLayer(); heart.path = p.copy(using:&transform)
        heart.position = world(center); heart.fillColor = color([255,180,216])
        heart.strokeColor = color([130,69,126]); heart.lineWidth = 0.65
        hearts.addSublayer(heart)
    }
}
