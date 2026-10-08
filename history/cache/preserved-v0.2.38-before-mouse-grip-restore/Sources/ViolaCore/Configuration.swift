import Foundation

public struct PetConfiguration: Codable, Equatable {
    public var version = 1
    public static let defaultWidth = 440.0
    public static let minimumWidth = 160.0
    public static let maximumWidth = 1200.0
    public var width = defaultWidth
    public var originX: Double?
    public var originY: Double?
    public var interactionEnabled = true
    public var stayOnTop = true
    public var clickThrough = false
    public var reducedMotion = false
    public var showDesks = true
    public var idleCrawlEnabled = true
    public var sleepAfter = 60.0
    public var characterID = "viola"
    public var laughSoundEnabled = true
    public var laughSoundVolume = 0.8
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case version, width, originX, originY, interactionEnabled, stayOnTop, clickThrough, reducedMotion, sleepAfter, characterID
        case laughSoundEnabled, laughSoundVolume, showDesks, idleCrawlEnabled
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? version
        width = try values.decodeIfPresent(Double.self, forKey: .width) ?? width
        originX = try values.decodeIfPresent(Double.self, forKey: .originX)
        originY = try values.decodeIfPresent(Double.self, forKey: .originY)
        interactionEnabled = try values.decodeIfPresent(Bool.self, forKey: .interactionEnabled) ?? interactionEnabled
        stayOnTop = try values.decodeIfPresent(Bool.self, forKey: .stayOnTop) ?? stayOnTop
        clickThrough = try values.decodeIfPresent(Bool.self, forKey: .clickThrough) ?? clickThrough
        reducedMotion = try values.decodeIfPresent(Bool.self, forKey: .reducedMotion) ?? reducedMotion
        showDesks = try values.decodeIfPresent(Bool.self, forKey: .showDesks) ?? showDesks
        idleCrawlEnabled = try values.decodeIfPresent(Bool.self, forKey: .idleCrawlEnabled) ?? idleCrawlEnabled
        sleepAfter = try values.decodeIfPresent(Double.self, forKey: .sleepAfter) ?? sleepAfter
        characterID = try values.decodeIfPresent(String.self, forKey: .characterID) ?? characterID
        laughSoundEnabled = try values.decodeIfPresent(Bool.self, forKey: .laughSoundEnabled) ?? laughSoundEnabled
        laughSoundVolume = try values.decodeIfPresent(Double.self, forKey: .laughSoundVolume) ?? laughSoundVolume
    }
    public mutating func sanitize() {
        width = width.isFinite ? max(Self.minimumWidth, min(Self.maximumWidth, width)) : Self.defaultWidth
        sleepAfter = sleepAfter.isFinite ? max(15, min(600, sleepAfter)) : 60
        laughSoundVolume = laughSoundVolume.isFinite ? max(0, min(1, laughSoundVolume)) : 0.8
        if let x = originX, !x.isFinite { originX = nil }
        if let y = originY, !y.isFinite { originY = nil }
        characterID = "viola"
    }
}

public final class ConfigurationStore {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() -> PetConfiguration {
        guard let data = try? Data(contentsOf: url), var value = try? JSONDecoder().decode(PetConfiguration.self, from: data) else { return PetConfiguration() }
        value.sanitize(); return value
    }
    public func save(_ value: PetConfiguration) throws {
        var clean = value; clean.sanitize()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(clean).write(to: url, options: .atomic)
    }
}
