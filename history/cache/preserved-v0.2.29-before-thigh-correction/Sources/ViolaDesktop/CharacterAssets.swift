import AppKit
import ViolaCore

struct SpriteDefinition: Codable {
    let id: String
    let file: String
    /// Optional generated alpha matte; keeps the original sprite's color pixels.
    let alphaMaskFile: String?
    let rect: [Double]
    let anchor: [Double]?
    let crop: [Double]?
    let polygon: [[Double]]?
    let cutouts: [[[Double]]]?
    let feather: Bool?
    let expression: FriendExpression?
    let contact: [Double]?
    let mirror: Bool?
    let mode: String?
    let finger: TypingFinger?
    let rotationDegrees: Double?
    let swingMultiplier: Double?
    let sideSwingMultiplier: Double?
    let perspectiveDistance: Double?
    let floorY: Double?
    var frame: CGRect { CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3]) }
}
struct CharacterManifest: Codable {
    let version: Int
    let id: String
    let name: String
    let canvas: [Double]
    /// Explicit geometry selection; absent preserves all legacy layouts.
    let rigProfile: String?
    let sprites: [SpriteDefinition]
}
enum AssetError: LocalizedError {
    case missing(String), invalid(String)
    var errorDescription: String? {
        switch self { case .missing(let s): return "缺少角色素材：\(s)"; case .invalid(let s): return "角色素材格式错误：\(s)" }
    }
}
final class CharacterAssets {
    let manifest: CharacterManifest
    let images: [String: CGImage]
    let layoutURL: URL
    init(directory: URL, manifestURL: URL? = nil) throws {
        layoutURL = manifestURL ?? directory.appendingPathComponent("character.json")
        manifest = try JSONDecoder().decode(CharacterManifest.self, from: Data(contentsOf: layoutURL))
        guard manifest.version == 1, manifest.canvas.count == 2, manifest.canvas.allSatisfy({ $0.isFinite && $0 > 0 }), Set(manifest.sprites.map(\.id)).count == manifest.sprites.count else { throw AssetError.invalid("manifest") }
        var loaded: [String: CGImage] = [:]
        var cache: [String: CGImage] = [:]
        for sprite in manifest.sprites {
            guard sprite.rect.count == 4, sprite.rect.allSatisfy(\.isFinite), sprite.rect[2] > 0, sprite.rect[3] > 0,
                  !sprite.file.contains(".."), !sprite.file.contains("/"), sprite.rotationDegrees?.isFinite ?? true,
                  [sprite.anchor, sprite.contact].allSatisfy({ value in value == nil || (value!.count == 2 && value!.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }) }) else { throw AssetError.invalid(sprite.id) }
            if let mask = sprite.alphaMaskFile {
                guard !mask.isEmpty, !mask.contains(".."), !mask.contains("/"), !mask.contains("\\") else { throw AssetError.invalid("alpha mask \(sprite.id)") }
            }
            if let gain = sprite.swingMultiplier {
                guard gain.isFinite, (0...2).contains(gain) else { throw AssetError.invalid("swing \(sprite.id)") }
            }
            if let gain = sprite.sideSwingMultiplier {
                guard gain.isFinite, (0...2).contains(gain) else { throw AssetError.invalid("side swing \(sprite.id)") }
            }
            if let distance = sprite.perspectiveDistance {
                guard distance.isFinite, (500...1600).contains(distance) else { throw AssetError.invalid("perspective \(sprite.id)") }
            }
            if let floor = sprite.floorY {
                guard floor.isFinite, floor >= 0, floor < manifest.canvas[1] else { throw AssetError.invalid("floor \(sprite.id)") }
            }
            for outline in [sprite.polygon].compactMap({ $0 }) + (sprite.cutouts ?? []) {
                guard outline.count >= 3, outline.allSatisfy({ $0.count == 2 && $0.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } }) else { throw AssetError.invalid("mask \(sprite.id)") }
            }
            if let crop = sprite.crop {
                guard crop.count == 4, crop.allSatisfy(\.isFinite), crop[0] >= 0, crop[1] >= 0, crop[2] > 0, crop[3] > 0 else { throw AssetError.invalid("crop \(sprite.id)") }
            }
            let cacheKey = sprite.file + String(describing: sprite.crop) + (sprite.alphaMaskFile ?? "")
            if let cached = cache[cacheKey] { loaded[sprite.id] = cached; continue }
            // Keep optional artwork next to the external layout so later art-only
            // revisions do not have to modify and re-sign the application bundle.
            let external = manifestURL?.deletingLastPathComponent().appendingPathComponent("character-assets",isDirectory:true).appendingPathComponent(sprite.file)
            let imageURL: URL
            if let external, FileManager.default.fileExists(atPath:external.path) { imageURL = external }
            else { imageURL = directory.appendingPathComponent(sprite.file) }
            guard let image = NSImage(contentsOf:imageURL), var cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw AssetError.missing(sprite.file) }
            if let crop = sprite.crop {
                guard crop.count == 4, let cut = cg.cropping(to: CGRect(x: crop[0], y: crop[1], width: crop[2], height: crop[3])) else { throw AssetError.invalid("crop \(sprite.id)") }
                cg = cut
            }
            if let maskName = sprite.alphaMaskFile {
                let externalMask = manifestURL?.deletingLastPathComponent().appendingPathComponent("character-assets",isDirectory:true).appendingPathComponent(maskName)
                let maskURL = externalMask.flatMap { FileManager.default.fileExists(atPath:$0.path) ? $0 : nil } ?? directory.appendingPathComponent(maskName)
                guard let image = NSImage(contentsOf:maskURL), var mask = image.cgImage(forProposedRect:nil,context:nil,hints:nil) else { throw AssetError.missing(maskName) }
                if let crop = sprite.crop {
                    guard let cropped = mask.cropping(to:CGRect(x:crop[0],y:crop[1],width:crop[2],height:crop[3])) else { throw AssetError.invalid("alpha mask crop \(sprite.id)") }
                    mask = cropped
                }
                guard mask.width == cg.width, mask.height == cg.height,
                      let context = CGContext(data:nil,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,
                                              space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { throw AssetError.invalid("alpha mask dimensions \(sprite.id)") }
                let bounds = CGRect(x:0,y:0,width:cg.width,height:cg.height)
                context.clip(to:bounds,mask:mask)
                context.draw(cg,in:bounds)
                guard let masked = context.makeImage() else { throw AssetError.invalid("alpha mask composite \(sprite.id)") }
                cg = masked
            }
            loaded[sprite.id] = cg
            cache[cacheKey] = cg
        }
        images = loaded
    }
    static var bundledDirectory: URL {
        if let path = Bundle.main.resourceURL?.appendingPathComponent("Characters/Viola"),
           FileManager.default.fileExists(atPath: path.appendingPathComponent("character.json").path) { return path }
        let candidates = [Bundle.module.bundleURL.appendingPathComponent("Resources/Characters/Viola"),
                          Bundle.module.resourceURL!.appendingPathComponent("Characters/Viola"),
                          Bundle.module.resourceURL!.appendingPathComponent("Resources/Characters/Viola")]
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("character.json").path) } ?? candidates[0]
    }
}
