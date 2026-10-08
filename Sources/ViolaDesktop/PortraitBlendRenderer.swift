import AppKit
import QuartzCore

/// Combines two complete portraits by weighting their premultiplied RGBA pixels.
/// The caller supplies visible, full-opacity branches in the same canvas space.
final class PortraitBlendRenderer {
    private let viewport: CGRect
    private let scale: CGFloat
    private let pixelBounds: CGRect
    private let normalContext: CGContext
    private let laughContext: CGContext
    private let resultContext: CGContext
    private(set) var lastRenderMilliseconds: Double = 0

    init?(viewport: CGRect, scale: CGFloat = 1.5) {
        guard [viewport.minX, viewport.minY, viewport.width, viewport.height, scale]
            .allSatisfy(\.isFinite), viewport.width > 0, viewport.height > 0, scale > 0 else { return nil }
        let scaledWidth = viewport.width * scale
        let scaledHeight = viewport.height * scale
        guard scaledWidth.isFinite, scaledHeight.isFinite,
              scaledWidth >= 1, scaledHeight >= 1,
              scaledWidth < CGFloat(Int.max / 4), scaledHeight < CGFloat(Int.max) else { return nil }
        // Match LayerRenderer.savePNG's pixel rounding and unflipped canvas CTM.
        let width = Int(scaledWidth), height = Int(scaledHeight)
        let bytesPerRow = width * 4
        guard height <= Int.max / bytesPerRow else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // Explicit byte order makes data-provider bytes RGBA on either Mac CPU.
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        func context() -> CGContext? {
            CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        }
        guard let normal = context(), let laugh = context(), let result = context() else { return nil }
        self.viewport = viewport
        self.scale = scale
        pixelBounds = CGRect(x: 0, y: 0, width: width, height: height)
        normalContext = normal
        laughContext = laugh
        resultContext = result
    }

    func composite(normal: CALayer, laugh: CALayer, weight: Double) -> CGImage? {
        let started = CACurrentMediaTime()
        defer { lastRenderMilliseconds = (CACurrentMediaTime() - started) * 1000 }
        let p = weight.isFinite ? min(1, max(0, weight)) : (weight == .infinity ? 1 : 0)
        guard let normalImage = snapshot(normal, in: normalContext),
              let laughImage = snapshot(laugh, in: laughContext) else { return nil }

        resultContext.saveGState()
        defer { resultContext.restoreGState() }
        resultContext.clear(pixelBounds)
        resultContext.setBlendMode(.copy)
        resultContext.setAlpha(CGFloat(1 - p))
        resultContext.draw(normalImage, in: pixelBounds)
        // source-over would attenuate the first portrait again. Addition instead
        // yields (1-p)*normalRGBA + p*laughRGBA, including their alpha channels.
        resultContext.setBlendMode(.plusLighter)
        resultContext.setAlpha(CGFloat(p))
        resultContext.draw(laughImage, in: pixelBounds)
        return resultContext.makeImage()
    }

    private func snapshot(_ layer: CALayer, in context: CGContext) -> CGImage? {
        context.saveGState()
        defer { context.restoreGState() }
        context.clear(pixelBounds)
        context.setAlpha(1)
        context.setBlendMode(.normal)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -viewport.minX, y: -viewport.minY)
        layer.render(in: context)
        return context.makeImage()
    }

    /// Exercises the actual CALayer -> CGContext -> CGImage path, including
    /// source transparency. Invoke from a renderer review; no global input needed.
    static func verifyPremultipliedBlend() throws {
        guard let renderer = PortraitBlendRenderer(viewport: CGRect(x: 0, y: 0, width: 5, height: 5), scale: 1) else {
            throw AssetError.invalid("portrait blend self-test context")
        }
        func block(red: CGFloat, blue: CGFloat, alpha: CGFloat) -> CALayer {
            let layer = CALayer()
            layer.frame = CGRect(x: 0, y: 0, width: 5, height: 5)
            // The convenience CGColor initializer uses a different RGB space;
            // test in the renderer's device space to avoid a color conversion.
            layer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                                            components: [red, 0, blue, alpha])
            layer.opacity = 1
            layer.isHidden = false
            return layer
        }
        func check(normal: CALayer, laugh: CALayer, weight: Double,
                   expected: [Int], label: String) throws {
            guard let image = renderer.composite(normal: normal, laugh: laugh, weight: weight),
                  image.bitsPerComponent == 8, image.bitsPerPixel == 32,
                  let data = image.dataProvider?.data,
                  CFDataGetLength(data) >= image.bytesPerRow * image.height,
                  let bytes = CFDataGetBytePtr(data) else {
                throw AssetError.invalid("portrait blend self-test image \(label)")
            }
            let offset = 2 * image.bytesPerRow + 2 * 4
            let actual = (0..<4).map { Int(bytes[offset + $0]) }
            guard zip(actual, expected).allSatisfy({ abs($0.0 - $0.1) <= 2 }) else {
                throw AssetError.invalid("portrait blend \(label): RGBA \(actual), expected \(expected)")
            }
        }
        let red = block(red: 1, blue: 0, alpha: 1)
        let blue = block(red: 0, blue: 1, alpha: 1)
        try check(normal: red, laugh: blue, weight: 0, expected: [255, 0, 0, 255], label: "opaque-normal")
        try check(normal: red, laugh: blue, weight: 1, expected: [0, 0, 255, 255], label: "opaque-laugh")
        try check(normal: red, laugh: blue, weight: 0.5, expected: [128, 0, 128, 255], label: "opaque-midpoint")
        let translucentRed = block(red: 1, blue: 0, alpha: 0.5)
        let translucentBlue = block(red: 0, blue: 1, alpha: 0.5)
        try check(normal: translucentRed, laugh: translucentBlue, weight: 0,
                  expected: [128, 0, 0, 128], label: "translucent-normal")
        try check(normal: translucentRed, laugh: translucentBlue, weight: 1,
                  expected: [0, 0, 128, 128], label: "translucent-laugh")
        try check(normal: translucentRed, laugh: translucentBlue, weight: 0.5,
                  expected: [64, 0, 64, 128], label: "translucent-midpoint")
    }
}
