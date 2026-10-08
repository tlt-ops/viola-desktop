import Foundation
import CoreGraphics

/// Reassembles retained reference pixels into one sampling surface for inspection.
/// Source boxes use the original PNG's upper-left origin, including its alpha.
enum ReferenceBodyJoin {
    private static let bodyBox = CGRect(x:255,y:169,width:670,height:363)
    private static let parts: [(String, CGRect)] = [
        ("body",bodyBox),
        ("inspection_left_arm",CGRect(x:369,y:283,width:183,height:219)),
        ("inspection_right_arm",CGRect(x:735,y:274,width:140,height:252)),
        ("inspection_left_hand",CGRect(x:266,y:475,width:132,height:43)),
        ("inspection_right_hand",CGRect(x:693,y:481,width:108,height:54))
    ]
    private static let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue |
        CGImageAlphaInfo.premultipliedLast.rawValue

    static func make(source: CGImage, images: [String:CGImage], includeOriginalArms: Bool = true) -> CGImage? {
        guard source.width >= Int(bodyBox.maxX), source.height >= Int(bodyBox.maxY),
              let original = source.cropping(to:bodyBox) else { return nil }
        let width = Int(bodyBox.width), height = Int(bodyBox.height)
        let space: CGColorSpace
        if let originalSpace = original.colorSpace, originalSpace.model == .rgb,
           originalSpace.numberOfComponents == 3 { space = originalSpace }
        else { space = CGColorSpaceCreateDeviceRGB() }
        guard var pixels = rgba(original,space:space) else { return nil }
        var matte = [UInt8](repeating:0,count:width*height)
        for (id,box) in parts where includeOriginalArms || id == "body" {
            // A missing or differently registered part must not silently produce
            // a partial body or place a mask over unrelated original pixels.
            guard let image = images[id], image.width == Int(box.width), image.height == Int(box.height),
                  let part = rgba(image,space:space) else { return nil }
            let offsetX = Int(box.minX-bodyBox.minX), offsetY = Int(box.minY-bodyBox.minY)
            for y in 0..<image.height {
                let targetY = offsetY+y
                guard targetY >= 0, targetY < height else { continue }
                for x in 0..<image.width {
                    let targetX = offsetX+x
                    guard targetX >= 0, targetX < width else { continue }
                    let index = targetY*width+targetX
                    matte[index] = max(matte[index],part[(y*image.width+x)*4+3])
                }
            }
        }
        // One original-source-pixel dilation eliminates the transparent sample
        // borders between complementary arm/body cuts. It cannot fill the broad
        // desk occlusion, because only immediate neighbors of retained alpha grow.
        var expanded = matte
        for y in 0..<height {
            for x in 0..<width {
                let alpha = matte[y*width+x]
                guard alpha > 0 else { continue }
                for dy in -1...1 where y+dy >= 0 && y+dy < height {
                    for dx in -1...1 where x+dx >= 0 && x+dx < width {
                        let neighbor = (y+dy)*width+x+dx
                        expanded[neighbor] = max(expanded[neighbor],alpha)
                    }
                }
            }
        }
        for index in 0..<matte.count {
            let byte = index*4, originalAlpha = Int(pixels[byte+3])
            // Torso-only mode removes exposed remnants of the old left hand.
            // Apply the measured cut after dilation so neighboring alpha cannot
            // regrow fingers. The right hand region also contains retained torso.
            if !includeOriginalArms {
                let world = CGPoint(x:203.2+(CGFloat(index%width)+0.5)*0.64,
                                    y:751.84-(CGFloat(index/width)+0.5)*0.64)
                if CGRect(x:203,y:518,width:112,height:48).contains(world) {
                    pixels[byte] = 0; pixels[byte+1] = 0; pixels[byte+2] = 0; pixels[byte+3] = 0
                    continue
                }
            }
            // Clamp to the original silhouette; do not multiply alpha twice.
            let alpha = min(originalAlpha,Int(expanded[index]))
            if alpha == 0 || originalAlpha == 0 {
                pixels[byte] = 0; pixels[byte+1] = 0; pixels[byte+2] = 0; pixels[byte+3] = 0
            } else {
                // The source buffer is premultiplied. Rescale only for its new
                // matte alpha, retaining the source's visible RGB and color space.
                if alpha != originalAlpha {
                    for channel in 0..<3 {
                        pixels[byte+channel] = UInt8((Int(pixels[byte+channel])*alpha+originalAlpha/2)/originalAlpha)
                    }
                }
                pixels[byte+3] = UInt8(alpha)
            }
        }
        guard let provider = CGDataProvider(data:Data(pixels) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,
                       bytesPerRow:width*4,space:space,bitmapInfo:CGBitmapInfo(rawValue:bitmapInfo),
                       provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }

    private static func rgba(_ image: CGImage, space: CGColorSpace) -> [UInt8]? {
        var pixels = [UInt8](repeating:0,count:image.width*image.height*4)
        let success = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data:bytes.baseAddress,width:image.width,height:image.height,
                bitsPerComponent:8,bytesPerRow:image.width*4,space:space,bitmapInfo:bitmapInfo) else { return false }
            context.interpolationQuality = .none
            // CGImage scanlines and bitmap storage both begin at image row zero.
            // No flipped CTM is applied: the source-box offsets remain top-down.
            context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
            return true
        }
        return success ? pixels : nil
    }
}
