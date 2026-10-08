import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Sources/ViolaDesktop/Resources/Characters/Viola")
let output = root.appendingPathComponent("build/motion-seams-v0.2.22/ownership")
func load(_ name: String) -> CGImage {
    NSImage(contentsOf: assets.appendingPathComponent(name))!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}
func bytes(_ image: CGImage) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
    result.withUnsafeMutableBytes { storage in
        let context = CGContext(data: storage.baseAddress, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return result
}
func save(_ image: CGImage, _ name: String) {
    try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
let originalFront = load("leg_front-toes-reference-v0.2.16.png")
let originalSeat = load("seating-reference-v0.2.16.png")
let split = ReferenceSpriteOwnership.split(front: originalFront, seating: originalSeat)!
let a = bytes(originalFront), b = bytes(split.front), c = bytes(originalSeat), d = bytes(split.seating)
var removed = 0, restored = 0, changedBaseSeat = 0, invalidTransferredColor = 0, invalidFrontColor = 0
for y in 0..<546 {
    for x in 0..<169 {
        let i = (y * 169 + x) * 4
        if a[i + 3] > 0, b[i + 3] == 0 { removed += 1 }
        if b[i + 3] > 0, Array(a[i..<i+4]) != Array(b[i..<i+4]) { invalidFrontColor += 1 }
        let j = ((y + 6) * 889 + x + 381) * 4
        if Array(c[j..<j+4]) != Array(d[j..<j+4]) {
            restored += 1
            if c[j+3] > 0 { changedBaseSeat += 1 }
            if Array(a[i..<i+4]) != Array(d[j..<j+4]) { invalidTransferredColor += 1 }
        }
    }
}
let lowerUnchanged = Array(a[(395*169*4)...]) == Array(b[(395*169*4)...])
var samples: [[String: Any]] = []
for (x,y) in [(5,100),(16,125),(140,350),(95,200),(100,425)] {
    let i = (y * 169 + x) * 4, j = ((y+6)*889+x+381)*4
    samples.append(["frontPixel":[x,y], "sourcePixel":[655+x,575+y],
        "worldCenter":[40+0.64*(655+Double(x)+0.5),860-0.64*(575+Double(y)+0.5)],
        "originalFrontPremultipliedRGBA":Array(a[i..<i+4]),"newFrontPremultipliedRGBA":Array(b[i..<i+4]),
        "originalSeatPremultipliedRGBA":Array(c[j..<j+4]),"newSeatPremultipliedRGBA":Array(d[j..<j+4])])
}
let audit: [String: Any] = ["frontDimensions":[169,546],"seatDimensions":[889,630],
    "frontToSeatOffset":[381,6],"removedFrontPixels":removed,"restoredSeatPixels":restored,
    "changedPreviouslyVisibleSeatPixels":changedBaseSeat,"alteredRetainedFrontColors":invalidFrontColor,
    "restoredPixelsNotExactCopies":invalidTransferredColor,"frontRows395AndBelowRGBAUnchanged":lowerUnchanged,
    "samples":samples]
try! JSONSerialization.data(withJSONObject:audit,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("audit.json"))
save(split.front,"front-ownership-corrected.png");save(split.seating,"seating-ownership-restored.png")
print(String(data:try! JSONSerialization.data(withJSONObject:audit,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
precondition(lowerUnchanged && changedBaseSeat == 0 && invalidFrontColor == 0 && invalidTransferredColor == 0)
