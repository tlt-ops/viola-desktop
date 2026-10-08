import AppKit
import QuartzCore

/// Hidden-desktop arms share the torso's shoulder translation while the petting
/// palm follows the friend's crown. The original cropped textures stay retained.
final class RestingPoseRig {
    let root = CALayer()
    private struct Arm {
        let layer: CALayer
        let shoulder: CGPoint
        let palm: CGPoint
        let vector: CGPoint
        let rotation: CGAffineTransform
    }
    private let pet: Arm
    private let lap: Arm
    private var time: Double = 0
    private var stroke = CGPoint.zero
    private var reduced = false
    private var petShoulder = CGPoint.zero
    private var petPalm = CGPoint.zero
    private var lapShoulder = CGPoint.zero
    private var lapPalm = CGPoint.zero

    init?(canvasSize: CGSize, images: [String:CGImage], definitions: [String:SpriteDefinition]) {
        guard let petImage = images["resting_pet_arm"], let lapImage = images["resting_lap_arm"],
              let petDefinition = definitions["resting_pet_arm"],
              let lapDefinition = definitions["resting_lap_arm"],
              let petArm = Self.makeArm(image:petImage,definition:petDefinition),
              let lapArm = Self.makeArm(image:lapImage,definition:lapDefinition) else { return nil }
        pet = petArm; lap = lapArm
        root.bounds = CGRect(origin:.zero,size:canvasSize)
        root.anchorPoint = .zero; root.position = .zero; root.contentsScale = 2
        root.addSublayer(lap.layer); root.addSublayer(pet.layer)
        render(dt:0,reducedMotion:false,seatX:0,torsoY:0,support:.identity)
    }

    func render(dt: Double, reducedMotion: Bool, seatX: Double, torsoY: Double, support: CGAffineTransform) {
        if dt.isFinite && dt > 0 {
            time = (time+min(dt,0.1)).truncatingRemainder(dividingBy:5)
        }
        reduced = reducedMotion
        let phase = time*2*Double.pi/5
        stroke = reducedMotion ? .zero : CGPoint(x:1.2*sin(phase),y:0.18*sin(2*phase))
        petShoulder = CGPoint(x:pet.shoulder.x+seatX,y:pet.shoulder.y+torsoY)
        petPalm = pet.palm.applying(support)
        petPalm.x += stroke.x; petPalm.y += stroke.y
        let delta = CGPoint(x:petPalm.x-petShoulder.x-pet.vector.x,
                            y:petPalm.y-petShoulder.y-pet.vector.y)
        let lengthSquared = pet.vector.x*pet.vector.x+pet.vector.y*pet.vector.y
        let a = 1+delta.x*pet.vector.x/lengthSquared
        let b = delta.y*pet.vector.x/lengthSquared
        let c = delta.x*pet.vector.y/lengthSquared
        let d = 1+delta.y*pet.vector.y/lengthSquared
        let r = pet.rotation
        let transform = CGAffineTransform(a:a*r.a+c*r.b,b:b*r.a+d*r.b,
            c:a*r.c+c*r.d,d:b*r.c+d*r.d,tx:0,ty:0)
        lapShoulder = CGPoint(x:lap.shoulder.x+seatX,y:lap.shoulder.y+torsoY)
        lapPalm = CGPoint(x:lap.palm.x+seatX,y:lap.palm.y+torsoY)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        pet.layer.position = petShoulder; pet.layer.setAffineTransform(transform)
        lap.layer.position = lapShoulder; lap.layer.setAffineTransform(lap.rotation)
        CATransaction.commit()
    }

    var diagnostics: [String:Any] {
        func pair(_ p: CGPoint) -> [Double] { [Double(p.x),Double(p.y)] }
        return ["time":time,"reducedMotion":reduced,"stroke":pair(stroke),
                "petShoulder":pair(petShoulder),"petPalm":pair(petPalm),
                "lapShoulder":pair(lapShoulder),"lapPalm":pair(lapPalm)]
    }

    private static func makeArm(image: CGImage, definition: SpriteDefinition) -> Arm? {
        guard definition.rect.count == 4, definition.rect.allSatisfy(\.isFinite),
              definition.rect[2] > 0, definition.rect[3] > 0,
              let contact = definition.contact, contact.count == 2,
              contact.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        let anchor = definition.anchor ?? [0.5,0.5]
        guard anchor.count == 2, anchor.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { return nil }
        let frame = definition.frame
        let angle = definition.rotationDegrees ?? 0
        guard angle.isFinite else { return nil }
        let rotation = CGAffineTransform(rotationAngle:angle*Double.pi/180)
        let shoulder = CGPoint(x:frame.minX+anchor[0]*frame.width,y:frame.minY+anchor[1]*frame.height)
        let localVector = CGPoint(x:(contact[0]-anchor[0])*frame.width,y:(contact[1]-anchor[1])*frame.height)
        let vector = localVector.applying(rotation)
        guard vector.x*vector.x+vector.y*vector.y > 1 else { return nil }
        let layer = CALayer(); layer.bounds = CGRect(origin:.zero,size:frame.size)
        layer.anchorPoint = CGPoint(x:anchor[0],y:anchor[1]); layer.position = shoulder
        layer.contents = image; layer.contentsGravity = .resize; layer.contentsScale = 2
        if definition.mirror == true {
            let content = CALayer(); content.bounds = layer.bounds
            content.position = CGPoint(x:layer.bounds.midX,y:layer.bounds.midY)
            content.contents = image; content.contentsGravity = .resize; content.contentsScale = 2
            content.setAffineTransform(CGAffineTransform(scaleX:-1,y:1))
            layer.contents = nil; layer.addSublayer(content)
        }
        if definition.polygon != nil || !(definition.cutouts ?? []).isEmpty {
            let path = CGMutablePath()
            func append(_ points: [[Double]], mirrored: Bool) {
                for (index,p) in points.enumerated() where p.count == 2 {
                    let point = CGPoint(x:(mirrored ? 1-p[0] : p[0])*frame.width,y:(1-p[1])*frame.height)
                    if index == 0 { path.move(to:point) } else { path.addLine(to:point) }
                }
                path.closeSubpath()
            }
            if let polygon = definition.polygon { append(polygon,mirrored:definition.mirror == true) }
            else { path.addRect(layer.bounds) }
            for hole in definition.cutouts ?? [] { append(hole,mirrored:false) }
            let mask = CAShapeLayer(); mask.path = path; mask.fillRule = .evenOdd
            mask.fillColor = NSColor.white.cgColor; layer.mask = mask
        }
        return Arm(layer:layer,shoulder:shoulder,
                   palm:CGPoint(x:shoulder.x+vector.x,y:shoulder.y+vector.y),vector:vector,rotation:rotation)
    }
}
