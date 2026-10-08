import Foundation
import CoreGraphics

/// A small, deterministic displacement field over the original distal toe pixels.
/// Coordinates identify the retained PNG, with its origin at the upper left;
/// displacement vectors use the renderer's upward-positive canvas coordinates.
public final class ToeMicroMotion {
    public struct Toe {
        public let root: CGPoint
        public let tip: CGPoint
        public let radius: Double
        public let period: Double
        public let phase: Double
    }
    public let side: String
    public let sourceSize: CGSize
    public let canvasSize: CGSize
    public let toes: [Toe]
    public let meshSourceY: Int
    public private(set) var time = 0.0
    public private(set) var enabled = true
    public private(set) var amplitudeLimit = 0.95
    private var drives: [CGPoint] = []

    public init(side: String, sourceSize: CGSize, canvasSize: CGSize) {
        self.side = side; self.sourceSize = sourceSize; self.canvasSize = canvasSize
        // These roots and tips follow the five visible toe lobes in the retained
        // reference crops. The larger front toe is at the left of its image;
        // the larger back toe is at the right, so neither foot is mirrored.
        let points: [(Double, Double, Double, Double)] = side == "front" ? [
            (77,501,67,536), (91,504,82,539), (104,498,96,529),
            (116,493,108,515), (125,488,116,498)
        ] : [
            (15,476,5,492), (21,478,9,500), (27,480,14,506),
            (33,482,20,510), (39,483,28,509)
        ]
        let periods = [5.7,4.4,5.1,3.7,4.8]
        let phaseOffset = side == "front" ? 0.0 : 1.93
        toes = points.enumerated().map { index, p in
            Toe(root:CGPoint(x:p.0,y:p.1),tip:CGPoint(x:p.2,y:p.3),
                radius:side == "front" ? 9 : 6, period:periods[index],
                phase:phaseOffset+Double(index)*1.37)
        }
        meshSourceY = side == "front" ? 482 : 470
        updateDrives()
    }

    public func advance(dt: Double, shoe: ShoeFrame, reducedMotion: Bool) {
        // Cap suspend/resume gaps, while retaining a separate continuous clock
        // for each renderer instead of coupling toe phases to the shoe timer.
        if dt.isFinite { time += max(0,min(0.1,dt)) }
        enabled = !reducedMotion
        let fitted = shoe.phase == .halfWorn || shoe.phase == .slipping ||
            (shoe.phase == .recovering && shoe.recovery == .toeHook)
        amplitudeLimit = reducedMotion ? 0 : 0.95*(fitted ? 0.15 : 1)
        updateDrives()
    }

    public var tipDisplacements: [CGPoint] { toes.map { displacement(at:$0.tip) } }

    public func displacement(at point: CGPoint) -> CGPoint {
        guard enabled, amplitudeLimit > 0 else { return .zero }
        var x = 0.0, y = 0.0, totalWeight = 0.0
        var nearestRoot = Double.greatestFiniteMagnitude, firstRootY = sourceSize.height
        for (index,toe) in toes.enumerated() {
            let vx = toe.tip.x-toe.root.x, vy = toe.tip.y-toe.root.y
            let length = hypot(vx,vy), ax = vx/length, ay = vy/length
            let rx = point.x-toe.root.x, ry = point.y-toe.root.y
            nearestRoot = min(nearestRoot,hypot(rx,ry)); firstRootY = min(firstRootY,toe.root.y)
            let t = (rx*ax+ry*ay)/length
            let cross = abs(-rx*ay+ry*ax)/toe.radius
            guard t > 0, t < 1.5, cross < 1 else { continue }
            // Compact support and a flat derivative at the root keep calf and
            // forefoot pixels still, without a seam where the fine mesh begins.
            let rootWeight = smooth(min(1,t))
            let endWeight = 1-smooth(max(0,(t-1.06)/0.44))
            let lateral = (1-cross*cross)*(1-cross*cross)
            let weight = rootWeight*endWeight*lateral
            x += weight*drives[index].x; y += weight*drives[index].y
            totalWeight += weight
        }
        // A convex blend retains every root fade and guarantees the amplitude
        // bound even where the neighboring toe fields overlap.
        let anchored = smooth(nearestRoot/(side == "front" ? 4 : 3))
        let distal = smooth((point.y-firstRootY)/8)
        return CGPoint(x:x/max(1,totalWeight)*anchored*distal,
                       y:y/max(1,totalWeight)*anchored*distal)
    }

    private func updateDrives() {
        let scaleX = canvasSize.width/sourceSize.width, scaleY = canvasSize.height/sourceSize.height
        drives = toes.enumerated().map { index,toe in
            let vx = (toe.tip.x-toe.root.x)*scaleX, vy = -(toe.tip.y-toe.root.y)*scaleY
            let length = hypot(vx,vy), ux = vx/length, uy = vy/length
            let phase = time*2*Double.pi/toe.period+toe.phase
            let curl = sin(phase)*0.82, spread = sin(phase*1.13+Double(index)*0.43)*0.35
            let amplitude = (1-Double(index)*0.035)*amplitudeLimit
            return CGPoint(x:(-ux*curl-uy*spread)*amplitude,
                           y:(-uy*curl+ux*spread)*amplitude)
        }
    }

    private func smooth(_ value: Double) -> Double {
        let p = max(0,min(1,value)); return p*p*(3-2*p)
    }
}
