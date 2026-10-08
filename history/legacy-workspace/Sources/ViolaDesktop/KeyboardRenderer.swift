import AppKit
import QuartzCore
import ViolaCore

/// One geometry definition supplies both keycap drawing and physical-key feedback.
final class KeyboardRenderer {
    let root = CALayer()
    private var caps: [UInt16: CAShapeLayer] = [:]
    private var labels: [UInt16: CATextLayer] = [:]
    private let size: CGSize
    init(size: CGSize, textScale: CGFloat = 1) {
        self.size = size; root.bounds = CGRect(origin: .zero, size: size)
        let labelScale = max(0.1,min(1,textScale))
        // Viola sits behind the board: space is nearest her, F keys nearest the viewer.
        // Rotate the complete geometry, so labels, keycaps and finger targets agree.
        root.setAffineTransform(CGAffineTransform(rotationAngle: .pi))
        let caseLayer = CAShapeLayer()
        caseLayer.path = quad([(3,13),(size.width-23,3),(size.width-2,size.height-16),(29,size.height-2)])
        caseLayer.fillColor = NSColor(calibratedRed: 0.23, green: 0.20, blue: 0.27, alpha: 1).cgColor
        caseLayer.strokeColor = NSColor(calibratedWhite: 0.15, alpha: 1).cgColor; caseLayer.lineWidth = 1.1
        let front = CAShapeLayer(); front.path = quad([(3,13),(size.width-23,3),(size.width-23,-3),(3,7)])
        front.fillColor = NSColor(calibratedRed: 0.18,green: 0.15,blue: 0.22,alpha: 1).cgColor
        root.addSublayer(front)
        root.addSublayer(caseLayer)
        for key in KeyboardLayout.keys {
            let p = point(column: key.column + 0.05, row: Double(key.row) + 0.08)
            let q = point(column: key.column + key.width - 0.07, row: Double(key.row) + 0.87)
            let tl = point(column: key.column + 0.05, row: Double(key.row) + 0.87)
            let br = point(column: key.column + key.width - 0.07, row: Double(key.row) + 0.08)
            let cap = CAShapeLayer(); cap.path = quad([(p.x,p.y),(br.x,br.y),(q.x,q.y),(tl.x,tl.y)])
            let side = CAShapeLayer(); side.path = cap.path
            side.setAffineTransform(CGAffineTransform(translationX:0,y:2.5))
            side.fillColor = NSColor(calibratedRed: 0.65,green: 0.61,blue: 0.59,alpha: 1).cgColor
            root.addSublayer(side)
            cap.fillColor = NSColor(calibratedRed: 0.91, green: 0.88, blue: 0.83, alpha: 1).cgColor
            cap.strokeColor = NSColor(calibratedRed: 0.73, green: 0.68, blue: 0.64, alpha: 1).cgColor; cap.lineWidth = 0.55
            root.addSublayer(cap); caps[key.code] = cap
            let center = keyCenter(key.code)!
            let fontSize = 5.6*labelScale
            let text = CATextLayer(); text.string = key.label; text.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
            text.fontSize = fontSize; text.foregroundColor = NSColor(calibratedWhite: 0.30, alpha: 1).cgColor
            text.alignmentMode = .center; text.contentsScale = 2
            let labelWidth = CGFloat(key.width)*22*labelScale
            text.frame = CGRect(x:center.x-labelWidth/2,y:center.y-3*labelScale,width:labelWidth,height:8*labelScale)
            root.addSublayer(text); labels[key.code] = text
        }
    }
    func render(_ pressures: [UInt16: Double]) {
        for (code, cap) in caps {
            let amount = pressures[code] ?? 0
            cap.fillColor = amount > 0.04 ? NSColor(calibratedRed: 0.96, green: 0.75, blue: 0.39, alpha: 1).cgColor : NSColor(calibratedRed: 0.91, green: 0.88, blue: 0.83, alpha: 1).cgColor
            cap.setAffineTransform(CGAffineTransform(translationX: 0, y: depression(amount)))
            labels[code]?.setAffineTransform(CGAffineTransform(translationX: 0, y: depression(amount)))
        }
    }
    func keyCenter(_ code: UInt16) -> CGPoint? {
        guard let key = KeyboardLayout.byCode[code] else { return nil }
        return point(column: key.column + key.width / 2, row: Double(key.row) + 0.48)
    }
    private func depression(_ pressure: Double) -> Double { 1.8 * pressure }
    func keyContact(_ code: UInt16, near: CGPoint, pressure: Double = 0) -> CGPoint? {
        guard let key = KeyboardLayout.byCode[code], let center = keyCenter(code) else { return nil }
        let left = point(column: key.column + 0.12, row: Double(key.row) + 0.48).x
        let right = point(column: key.column + key.width - 0.12, row: Double(key.row) + 0.48).x
        return CGPoint(x: max(left, min(right, near.x)), y: center.y + depression(pressure))
    }
    private func point(column: Double, row: Double) -> CGPoint {
        let depth = 1 - row / 6
        return CGPoint(x: 8 + column * (size.width - 38) / 16.25 + depth * 20,
                       y: 15 + depth * (size.height - 27))
    }
    private func quad(_ corners: [(Double,Double)]) -> CGPath {
        let path = CGMutablePath()
        for (index, p) in corners.enumerated() { if index == 0 { path.move(to: CGPoint(x:p.0,y:p.1)) } else { path.addLine(to: CGPoint(x:p.0,y:p.1)) } }
        path.closeSubpath(); return path
    }
}
