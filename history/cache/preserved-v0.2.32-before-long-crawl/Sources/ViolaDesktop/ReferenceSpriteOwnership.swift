import AppKit

/// Corrects the retained reference's front-leg ownership without changing its artwork.
/// Both textures use the same source registration: front (655,575), seat (274,569).
enum ReferenceSpriteOwnership {
    static func split(front: CGImage, seating: CGImage) -> (front: CGImage, seating: CGImage)? {
        guard front.width == 169, front.height == 546,
              seating.width == 889, seating.height == 630,
              var leg = pixels(front), var seat = pixels(seating) else { return nil }
        let original = leg
        for y in 60..<395 {
            let left = edge(y, points: leftEdge)
            let right = edge(y, points: rightEdge)
            for x in 0..<front.width {
                let index = (y * front.width + x) * 4
                guard original[index + 3] > 0 else { continue }
                // One source pixel outside the dark stocking contour retains AA.
                var outside = Double(x) < left - 1 || Double(x) > right + 1
                // The rounded upper knee also contains warm exposed Viola skin.
                // Keep those original pixels until the skin wedge ends; only the
                // purple fabric beyond the outline belongs to the seated friend.
                if y < 105, Double(x) > right + 1, original[index] > 120,
                   Int(original[index + 2]) <= Int(original[index]) + 5 {
                    outside = false
                }
                // Back the boundary with a one-pixel overlap of the same source
                // pixels. Independent leg motion then exposes retained clothing.
                let seam = abs(Double(x) - left) <= 1 || abs(Double(x) - right) <= 1
                if outside || seam {
                    let destination = ((y + 6) * seating.width + x + 381) * 4
                    // The original extraction left these pixels transparent in
                    // seating. Do not replace any already-owned visible artwork.
                    if seat[destination + 3] == 0 {
                        for channel in 0..<4 { seat[destination + channel] = original[index + channel] }
                    }
                }
                if outside {
                    for channel in 0..<4 { leg[index + channel] = 0 }
                }
            }
        }
        guard let legImage = image(leg, width: front.width, height: front.height),
              let seatImage = image(seat, width: seating.width, height: seating.height) else { return nil }
        return (legImage, seatImage)
    }

    // Pixel coordinates trace the dark stocking outline, not the extraction's
    // outer edge (which included purple hair, a pink shoulder and skirt ruffles).
    private static let leftEdge: [(Double, Double)] = [
        (60,4),(75,7),(80,8),(100,13),(125,16),(150,19),
        (175,25),(200,34),(225,44),(250,55),(275,65),(300,74),
        (325,81),(350,86),(375,85),(394,86)
    ]
    private static let rightEdge: [(Double, Double)] = [
        (60,103),(75,95),(80,89),(90,93),(100,98),(110,103),
        (125,110),(150,118),(175,121),(200,122),(225,122),
        (250,123),(275,124),(300,126),(325,128),(350,134),
        (375,145),(390,151),(394,152)
    ]
    private static func edge(_ row: Int, points: [(Double, Double)]) -> Double {
        let y = Double(row)
        for index in 1..<points.count where y <= points[index].0 {
            let a = points[index - 1], b = points[index]
            return a.1 + (b.1 - a.1) * (y - a.0) / (b.0 - a.0)
        }
        return points.last!.1
    }

    private static let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    private static func pixels(_ image: CGImage) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let success = bytes.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return success ? bytes : nil
    }
    private static func image(_ bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo), provider: provider,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
