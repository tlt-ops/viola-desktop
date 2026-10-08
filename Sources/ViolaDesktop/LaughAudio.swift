import AVFoundation
import ViolaCore

/// Main-thread audio follows the animation state, including queued and idle laughs.
final class LaughAudio {
    private let profileDirectory: URL
    private var player: AVAudioPlayer?
    private var laughing = false
    private(set) var sourceVariant: LaughSoundVariant = .nailong
    private(set) var sourcePath: String?
    private(set) var failure: String?
    private(set) var starts = 0

    init(profileDirectory: URL) { self.profileDirectory = profileDirectory }

    func update(frame: AnimationFrame, enabled: Bool, volume: Double, variant: LaughSoundVariant) {
        selectVariant(variant)
        let active = frame.state == .laugh
        player?.volume = Float(volume)
        if !active || !enabled { player?.stop() }
        if active && !laughing && enabled && volume > 0 { start(volume: volume) }
        laughing = active
    }

    func applySettings(enabled: Bool, volume: Double, variant: LaughSoundVariant) {
        selectVariant(variant)
        player?.volume = Float(volume)
        if !enabled || volume == 0 { player?.stop() }
    }

    func stop() { player?.stop(); laughing = false }

    private func selectVariant(_ variant: LaughSoundVariant) {
        guard sourceVariant != variant else { return }
        player?.stop(); player = nil; sourcePath = nil; failure = nil
        sourceVariant = variant
        // Keep the active-laugh latch: a source change takes effect on the next
        // laugh and cannot restart audio in the middle of the current animation.
    }

    private func start(volume: Double) {
        player?.stop(); player = nil; sourcePath = nil; failure = nil
        let directories = [profileDirectory.appendingPathComponent("Sounds"), profileDirectory,
                           CharacterAssets.bundledDirectory.appendingPathComponent("Sounds")]
        var foundFile = false
        for directory in directories {
            for ext in ["m4a", "wav", "mp3"] {
                let url = directory.appendingPathComponent("\(sourceVariant.filename).\(ext)")
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                foundFile = true
                do {
                    let sound = try AVAudioPlayer(contentsOf: url)
                    sound.volume = Float(volume); sound.numberOfLoops = 0
                    guard sound.prepareToPlay(), sound.play() else {
                        failure = "无法播放\(sourceVariant.label)：\(url.lastPathComponent)"; continue
                    }
                    player = sound; sourcePath = url.path; failure = nil; starts += 1
                    return
                } catch { failure = "无法读取\(sourceVariant.label)（\(url.lastPathComponent)）：\(error.localizedDescription)" }
            }
        }
        if !foundFile { failure = "未找到\(sourceVariant.label)：\(sourceVariant.filename).m4a / wav / mp3" }
    }

    var diagnostics: [String: Any] {
        ["source": sourcePath ?? "none", "playing": player?.isPlaying ?? false,
         "sourceVariant": sourceVariant.rawValue, "sourceLabel": sourceVariant.label,
         "sourceFilename": sourcePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "\(sourceVariant.filename).m4a",
         "starts": starts, "failure": failure ?? "none"]
    }
}
