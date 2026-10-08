import AppKit
import QuartzCore
import ViolaCore

/// Retained resting-arm textures reach a concealed keyboard through one affine
/// field per arm. The shoulder stays registered while the palm taps at the desk.
final class ComputerHandsRig {
    let root = CALayer()
    private struct Arm {
        let layer: CALayer
        let shoulderCap: CALayer
        let shoulder: CGPoint
        let vector: CGPoint
        let rotation: CGAffineTransform
    }
    private let left: Arm
    private let right: Arm
    private var leftShoulder = CGPoint.zero
    private var rightShoulder = CGPoint.zero
    private var leftPalm = CGPoint.zero
    private var rightPalm = CGPoint.zero
    private var leftTransform = CGAffineTransform.identity
    private var rightTransform = CGAffineTransform.identity
    private var typingLeft = 0.0
    private var typingRight = 0.0
    private var leftTypingStroke = 0.0
    private var mouseOffset = CGPoint.zero
    private var mouseCenter = CGPoint.zero
    private let mouseLayer = CALayer()
    private let hasMouseArtwork: Bool

    init?(canvasSize: CGSize, images: [String: CGImage], definitions: [String: SpriteDefinition]) {
        guard let leftImage = images["resting_pet_arm"], let rightImage = images["resting_lap_arm"],
              let leftDefinition = definitions["resting_pet_arm"],
              let rightDefinition = definitions["resting_lap_arm"],
              let leftArm = Self.makeArm(image: leftImage, definition: leftDefinition),
              let rightArm = Self.makeArm(image: rightImage, definition: rightDefinition) else { return nil }
        left = leftArm; right = rightArm
        hasMouseArtwork = images["reference_mouse"] != nil
        root.name = "computer_hands"
        root.bounds = CGRect(origin: .zero, size: canvasSize)
        root.anchorPoint = .zero; root.position = .zero; root.contentsScale = 2
        root.addSublayer(right.shoulderCap); root.addSublayer(left.shoulderCap)
        mouseLayer.name = "computer_mouse"
        mouseLayer.bounds = CGRect(x: 0, y: 0, width: 16, height: 40)
        mouseLayer.contents = images["reference_mouse"]
        mouseLayer.contentsGravity = .resize; mouseLayer.contentsScale = 2
        mouseLayer.setAffineTransform(CGAffineTransform(rotationAngle: 70 * Double.pi / 180))
        root.addSublayer(mouseLayer)
        root.addSublayer(right.layer); root.addSublayer(left.layer)
        render(frame: AnimationFrame(), seatX: 0, torsoY: 0)
    }

    func render(frame: AnimationFrame, seatX: Double, torsoY: Double) {
        func finite(_ value: Double) -> Double { value.isFinite ? value : 0 }
        func stroke(_ value: Double) -> Double { max(0, min(1, finite(value))) }
        func mouse(_ value: Double, limit: Double) -> Double { max(-limit, min(limit, finite(value) * 0.22)) }
        typingLeft = stroke(frame.typingLeft); typingRight = stroke(frame.typingRight)
        leftTypingStroke = max(typingLeft, typingRight)
        let x = finite(seatX), y = finite(torsoY)
        leftShoulder = CGPoint(x: left.shoulder.x + x, y: left.shoulder.y + y)
        rightShoulder = CGPoint(x: right.shoulder.x + x, y: right.shoulder.y + y)
        // Stroke amplitudes already honor reduced motion in the core driver.
        leftPalm = CGPoint(x: 388 - 0.5 * leftTypingStroke, y: 570 - 2.8 * leftTypingStroke)
        mouseOffset = CGPoint(x: mouse(frame.mouseX, limit: 7),
                              y: mouse(frame.mouseY, limit: 4) - 2 * stroke(frame.mousePress))
        rightPalm = CGPoint(x: 510 + mouseOffset.x, y: 565 + mouseOffset.y)
        mouseCenter = CGPoint(x: rightPalm.x - 6, y: rightPalm.y - 7)
        leftTransform = Self.transform(arm: left, shoulder: leftShoulder, palm: leftPalm)
        rightTransform = Self.transform(arm: right, shoulder: rightShoulder, palm: rightPalm)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        left.shoulderCap.position = leftShoulder; right.shoulderCap.position = rightShoulder
        mouseLayer.position = mouseCenter
        left.layer.position = leftShoulder; left.layer.setAffineTransform(leftTransform)
        right.layer.position = rightShoulder; right.layer.setAffineTransform(rightTransform)
        CATransaction.commit()
    }

    var diagnostics: [String: Any] {
        func pair(_ point: CGPoint) -> [Double] { [Double(point.x), Double(point.y)] }
        func matrix(_ value: CGAffineTransform) -> [Double] {
            [value.a, value.b, value.c, value.d, value.tx, value.ty].map(Double.init)
        }
        let matrices = [matrix(leftTransform), matrix(rightTransform)]
        return ["leftShoulder": pair(leftShoulder), "rightShoulder": pair(rightShoulder),
                "leftPalm": pair(leftPalm), "rightPalm": pair(rightPalm),
                "typingLeft": typingLeft, "typingRight": typingRight,
                "leftTypingStroke": leftTypingStroke, "rightHandRole": "mouse",
                "mouseVisible": hasMouseArtwork && !root.isHidden, "mouseSource": "reference_mouse",
                "mouseCenter": pair(mouseCenter),
                "mouseBounds": [16.0, 40.0], "mouseRotationDegrees": 70.0,
                "mouseFrame": [Double(mouseLayer.frame.minX), Double(mouseLayer.frame.minY),
                               Double(mouseLayer.frame.width), Double(mouseLayer.frame.height)],
                "mouseOffset": pair(mouseOffset), "leftTransform": matrices[0],
                "rightTransform": matrices[1], "finiteTransforms": matrices.joined().allSatisfy(\.isFinite),
                "armTextures": ["resting_pet_arm", "resting_lap_arm"],
                "shoulderCapDepth": 20.0, "shoulderCapsUseOriginalRotation": true,
                "keyPositionMapping": false]
    }

    /// A = I + delta⊗v/|v|² keeps the shoulder fixed and sends v to the exact
    /// target palm. Compose A with the art's original rotation to preserve both.
    private static func transform(arm: Arm, shoulder: CGPoint, palm: CGPoint) -> CGAffineTransform {
        let delta = CGPoint(x: palm.x - shoulder.x - arm.vector.x,
                            y: palm.y - shoulder.y - arm.vector.y)
        let squared = arm.vector.x * arm.vector.x + arm.vector.y * arm.vector.y
        let a = 1 + delta.x * arm.vector.x / squared
        let b = delta.y * arm.vector.x / squared
        let c = delta.x * arm.vector.y / squared
        let d = 1 + delta.y * arm.vector.y / squared
        let r = arm.rotation
        return CGAffineTransform(a: a * r.a + c * r.b, b: b * r.a + d * r.b,
                                 c: a * r.c + c * r.d, d: b * r.c + d * r.d, tx: 0, ty: 0)
    }

    private static func makeArm(image: CGImage, definition: SpriteDefinition) -> Arm? {
        guard definition.rect.count == 4, definition.rect.allSatisfy(\.isFinite),
              definition.rect[2] > 0, definition.rect[3] > 0,
              let contact = definition.contact, contact.count == 2,
              contact.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        let anchor = definition.anchor ?? [0.5, 0.5]
        guard anchor.count == 2, anchor.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        let angle = definition.rotationDegrees ?? 0
        guard angle.isFinite else { return nil }
        let frame = definition.frame
        let rotation = CGAffineTransform(rotationAngle: angle * Double.pi / 180)
        let shoulder = CGPoint(x: frame.minX + anchor[0] * frame.width,
                               y: frame.minY + anchor[1] * frame.height)
        let localVector = CGPoint(x: (contact[0] - anchor[0]) * frame.width,
                                  y: (contact[1] - anchor[1]) * frame.height)
        let vector = localVector.applying(rotation)
        guard vector.x * vector.x + vector.y * vector.y > 1 else { return nil }
        let layer = CALayer(); layer.name = "computer_" + definition.id
        layer.bounds = CGRect(origin: .zero, size: frame.size)
        layer.anchorPoint = CGPoint(x: anchor[0], y: anchor[1]); layer.position = shoulder
        func applyArtwork(to layer: CALayer) {
            layer.contents = image; layer.contentsGravity = .resize; layer.contentsScale = 2
            if definition.mirror == true {
                let content = CALayer(); content.bounds = layer.bounds
                content.position = CGPoint(x: layer.bounds.midX, y: layer.bounds.midY)
                content.contents = image; content.contentsGravity = .resize; content.contentsScale = 2
                content.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
                layer.contents = nil; layer.addSublayer(content)
            }
            if definition.polygon != nil || !(definition.cutouts ?? []).isEmpty {
                let path = CGMutablePath()
                func append(_ points: [[Double]], mirrored: Bool) {
                    for (index, point) in points.enumerated() where point.count == 2 {
                        let p = CGPoint(x: (mirrored ? 1 - point[0] : point[0]) * frame.width,
                                        y: (1 - point[1]) * frame.height)
                        if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    path.closeSubpath()
                }
                if let polygon = definition.polygon { append(polygon, mirrored: definition.mirror == true) }
                else { path.addRect(layer.bounds) }
                for hole in definition.cutouts ?? [] { append(hole, mirrored: false) }
                let mask = CAShapeLayer(); mask.path = path; mask.fillRule = .evenOdd
                mask.fillColor = NSColor.white.cgColor; layer.mask = mask
            }
        }
        applyArtwork(to: layer)
        // Keep the original alpha silhouette above the shoulder seam. The moving
        // arm's compression otherwise shortens this cap and exposes the torso cut.
        let cap = CALayer(); cap.name = "computer_" + definition.id + "_shoulder_cap"
        cap.bounds = layer.bounds; cap.anchorPoint = layer.anchorPoint; cap.position = shoulder
        cap.contentsScale = 2; cap.setAffineTransform(rotation)
        let capArt = CALayer(); capArt.frame = cap.bounds
        applyArtwork(to: capArt); cap.addSublayer(capArt)
        let capBottom = max(0, anchor[1] * frame.height - 20)
        let capMask = CAShapeLayer()
        capMask.path = CGPath(rect: CGRect(x: 0, y: capBottom, width: frame.width,
                                          height: frame.height - capBottom), transform: nil)
        capMask.fillColor = NSColor.white.cgColor; cap.mask = capMask
        return Arm(layer: layer, shoulderCap: cap, shoulder: shoulder, vector: vector, rotation: rotation)
    }
}
