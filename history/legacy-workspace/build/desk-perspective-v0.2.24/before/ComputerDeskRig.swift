import AppKit
import QuartzCore

/// One continuous desk, split only for character occlusion. The monitor and
/// tabletop share their original pixels; the supports stay behind the figures.
final class ComputerDeskRig {
    let root = CALayer()
    let supports = CALayer()
    let wristY: CGFloat = 576
    let tabletopMinY: CGFloat = 533
    let tabletopSurfaceY: CGFloat = 533 + (425 - 373) * (700 / 1536)
    let frontLipY: CGFloat = 533 + (425 - 420) * (700 / 1536)

    private struct Piece {
        let image: CGImage
        let frame: CGRect
        let crop: CGRect
        let container: CALayer
    }
    private var pieces: [Piece] = []
    private let sourceSize: CGSize
    private static let headerCrop = CGRect(x: 0, y: 0, width: 1536, height: 425)
    private static let supportCrop = CGRect(x: 0, y: 420, width: 1536, height: 604)
    private static let headerFrame = CGRect(x: 70, y: 533, width: 700, height: 425.0 * (700.0 / 1536.0))
    private static let supportFrame = CGRect(x: 70, y: 100, width: 700, height: 433)

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
        add(source: source, crop: Self.headerCrop, frame: Self.headerFrame, to: root)
        add(source: source, crop: Self.supportCrop, frame: Self.supportFrame, to: supports)
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
        return ["sourceSize": [Double(sourceSize.width), Double(sourceSize.height)],
                "sourceExpectedSize": sourceSize == CGSize(width: 1536, height: 1024),
                "headerCrop": rect(Self.headerCrop), "headerFrame": rect(Self.headerFrame),
                "supportCrop": rect(Self.supportCrop), "supportFrame": rect(Self.supportFrame),
                "loadedPieces": pieces.count, "hidden": isHidden,
                "wristY": Double(wristY), "tabletopMinY": Double(tabletopMinY),
                "tabletopSurfaceY": Double(tabletopSurfaceY), "frontLipY": Double(frontLipY),
                "keyboardVisible": false,
                "hitTest": "source_alpha", "hitAlphaThreshold": 48]
    }

    private func add(source: CGImage, crop: CGRect, frame: CGRect, to container: CALayer) {
        let scaledCrop = CGRect(x: crop.minX / 1536 * sourceSize.width,
                                y: crop.minY / 1024 * sourceSize.height,
                                width: crop.width / 1536 * sourceSize.width,
                                height: crop.height / 1024 * sourceSize.height)
        guard let image = source.cropping(to: scaledCrop) else { return }
        let layer = CALayer()
        layer.frame = frame; layer.contents = image
        layer.contentsGravity = .resize; layer.contentsScale = 2
        layer.minificationFilter = .linear; layer.magnificationFilter = .linear
        container.addSublayer(layer)
        pieces.append(Piece(image: image, frame: frame, crop: crop, container: container))
    }
}
