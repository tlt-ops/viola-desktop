import AppKit
import QuartzCore

/// One continuous desk, split only for character occlusion. The monitor and
/// tabletop share their original pixels; the supports stay behind the figures.
final class ComputerDeskRig {
    let root = CALayer()
    let supports = CALayer()
    let wristY: CGFloat = 576
    let tabletopMinY: CGFloat = 748 - 594 * (700.0 / 1536.0)
    let tabletopSurfaceY: CGFloat = 748 - 390 * (700.0 / 1536.0)
    let frontLipY: CGFloat = 748 - 480 * (700.0 / 1536.0)

    private struct Piece {
        let image: CGImage
        let frame: CGRect
        let crop: CGRect
        let container: CALayer
        let footprint: CGPath?
    }
    private var pieces: [Piece] = []
    private let sourceSize: CGSize
    private static let scale: CGFloat = 700.0 / 1536.0
    private static let headerCrop = CGRect(x: 0, y: 0, width: 1536, height: 600)
    private static let headerFrame = CGRect(x: 70, y: 748 - 600 * scale, width: 700, height: 600 * scale)
    private static let headerOutline: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 1536, y: 0), CGPoint(x: 1536, y: 482),
        CGPoint(x: 1456, y: 482), CGPoint(x: 1436, y: 512), CGPoint(x: 1248, y: 566),
        CGPoint(x: 1245, y: 594), CGPoint(x: 1187, y: 594), CGPoint(x: 1167, y: 545),
        CGPoint(x: 132, y: 357), CGPoint(x: 104, y: 383), CGPoint(x: 85, y: 377),
        CGPoint(x: 70, y: 330), CGPoint(x: 0, y: 330)
    ]
    private static let legCrops = [CGRect(x: 86, y: 373, width: 50, height: 293),
                                   CGRect(x: 373, y: 398, width: 51, height: 202),
                                   CGRect(x: 1181, y: 589, width: 65, height: 411),
                                   CGRect(x: 1404, y: 488, width: 52, height: 356)]
    private static let legFloorY: [CGFloat] = [180, 220, 100, 155]
    private static var legFrames: [CGRect] {
        zip(legCrops, legFloorY).map { crop, floor in
            CGRect(x: 70 + crop.minX * scale, y: floor, width: crop.width * scale,
                   height: 748 - crop.minY * scale - floor)
        }
    }
    private static func lowerBoundary(at x: CGFloat) -> CGFloat {
        let sourceX = (x - 70) / scale
        let sourceY = 357 + (sourceX - 132) * (545 - 357) / (1167 - 132)
        return 748 - sourceY * scale
    }

    init(canvasSize: CGSize, source: CGImage) {
        sourceSize = CGSize(width: source.width, height: source.height)
        for (layer, name) in [(root, "computer_desk_header"), (supports, "computer_desk_supports")] {
            layer.name = name
            layer.bounds = CGRect(origin: .zero, size: canvasSize)
            layer.anchorPoint = .zero; layer.position = .zero
            layer.contentsScale = 2
        }
        // Crop at runtime so the retained source PNG remains untouched. Geometry
        // uses the 1536×1024 source coordinates even if a loader rescales pixels.
        for (index, pair) in zip(Self.legCrops, Self.legFrames).enumerated() {
            // The two near legs belong in front of the seated figures; otherwise
            // their exposed feet would appear detached beneath the clothing.
            add(source: source, crop: pair.0, frame: pair.1,
                to: [0,2].contains(index) ? root : supports)
        }
        add(source: source, crop: Self.headerCrop, frame: Self.headerFrame, to: root,
            outline: Self.headerOutline)
    }

    /// Use this property when toggling the complete desk from the menu.
    var isHidden: Bool {
        get { root.isHidden && supports.isHidden }
        set {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            root.isHidden = newValue; supports.isHidden = newValue
            CATransaction.commit()
        }
    }

    /// Transparent space between the legs, and around the monitor, passes through.
    /// Sampling the image alpha also follows later source-only artwork cleanup.
    func contains(_ point: CGPoint) -> Bool {
        for piece in pieces where !piece.container.isHidden && piece.container.opacity > 0 {
            guard piece.frame.contains(point) else { continue }
            if let footprint = piece.footprint, !footprint.contains(point) { continue }
            let u = (point.x - piece.frame.minX) / piece.frame.width
            let v = (piece.frame.maxY - point.y) / piece.frame.height
            let x = max(0, min(piece.image.width - 1, Int(u * CGFloat(piece.image.width))))
            let y = max(0, min(piece.image.height - 1, Int(v * CGFloat(piece.image.height))))
            // A one-pixel crop avoids assumptions about source byte order or
            // bitmap scanline orientation, while keeping click checks bounded.
            guard let pixel = piece.image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { continue }
            var rgba = [UInt8](repeating: 0, count: 4)
            let alpha: UInt8 = rgba.withUnsafeMutableBytes { bytes in
                guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1,
                    bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return 0 }
                context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return bytes[3]
            }
            if alpha >= 48 { return true }
        }
        return false
    }

    var diagnostics: [String: Any] {
        func rect(_ value: CGRect) -> [Double] {
            [Double(value.minX), Double(value.minY), Double(value.width), Double(value.height)]
        }
        let supportCrop = Self.legCrops.reduce(CGRect.null) { $0.union($1) }
        let supportFrame = Self.legFrames.reduce(CGRect.null) { $0.union($1) }
        let thighLeft: CGFloat = 493.12, thighRight: CGFloat = 557.12, thighTop: CGFloat = 495.84
        let leftBoundary = Self.lowerBoundary(at: thighLeft), rightBoundary = Self.lowerBoundary(at: thighRight)
        let minimumBoundary = min(leftBoundary, rightBoundary)
        return ["sourceSize": [Double(sourceSize.width), Double(sourceSize.height)],
                "sourceExpectedSize": sourceSize == CGSize(width: 1536, height: 1024),
                "headerCrop": rect(Self.headerCrop), "headerFrame": rect(Self.headerFrame),
                "supportCrop": rect(supportCrop), "supportFrame": rect(supportFrame),
                "supportCrops": Self.legCrops.map(rect), "supportFrames": Self.legFrames.map(rect),
                "supportFloorY": Self.legFloorY.map(Double.init),
                "headerOutline": Self.headerOutline.map { [Double($0.x), Double($0.y)] },
                "sourceToWorld": ["xOrigin": 70.0, "yOrigin": 748.0, "scale": Double(Self.scale)],
                "loadedPieces": pieces.count, "hidden": isHidden,
                "wristY": Double(wristY), "tabletopMinY": Double(tabletopMinY),
                "tabletopSurfaceY": Double(tabletopSurfaceY), "frontLipY": Double(frontLipY),
                "thighXSpan": [Double(thighLeft), Double(thighRight)], "thighTopY": Double(thighTop),
                "boundaryAtThighLeftY": Double(leftBoundary), "boundaryAtThighRightY": Double(rightBoundary),
                "minimumThighBoundaryY": Double(minimumBoundary), "thighClearance": Double(minimumBoundary - thighTop),
                "requiredThighClearance": 8.0,
                "keyboardVisible": false,
                "hitTest": "masked_source_alpha", "hitAlphaThreshold": 48]
    }

    private func add(source: CGImage, crop: CGRect, frame: CGRect, to container: CALayer,
                     outline: [CGPoint]? = nil) {
        let scaledCrop = CGRect(x: crop.minX / 1536 * sourceSize.width,
                                y: crop.minY / 1024 * sourceSize.height,
                                width: crop.width / 1536 * sourceSize.width,
                                height: crop.height / 1024 * sourceSize.height)
        guard let image = source.cropping(to: scaledCrop) else { return }
        let layer = CALayer()
        layer.frame = frame; layer.contents = image
        layer.contentsGravity = .resize; layer.contentsScale = 2
        layer.minificationFilter = .linear; layer.magnificationFilter = .linear
        var footprint: CGPath?
        if let outline {
            let local = CGMutablePath(), world = CGMutablePath()
            for (index, point) in outline.enumerated() {
                let x = (point.x - crop.minX) / crop.width * frame.width
                let y = (crop.maxY - point.y) / crop.height * frame.height
                let p = CGPoint(x: x, y: y), q = CGPoint(x: frame.minX + x, y: frame.minY + y)
                if index == 0 { local.move(to: p); world.move(to: q) }
                else { local.addLine(to: p); world.addLine(to: q) }
            }
            local.closeSubpath(); world.closeSubpath()
            let mask = CAShapeLayer(); mask.path = local; mask.fillColor = NSColor.white.cgColor
            layer.mask = mask; footprint = world
        }
        container.addSublayer(layer)
        pieces.append(Piece(image: image, frame: frame, crop: crop, container: container, footprint: footprint))
    }
}
