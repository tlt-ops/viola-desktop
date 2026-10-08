import AVFoundation
import ViolaCore

/// Main-thread audio follows the animation state, including queued and idle laughs.
final class LaughAudio {
    private let profileDirectory: URL
    private var player: AVAudioPlayer?
    private var laughing = false
    private(set) var sourcePath: String?
    private(set) var failure: String?
    private(set) var starts = 0

    init(profileDirectory: URL) { self.profileDirectory = profileDirectory }

    func update(frame: AnimationFrame, enabled: Bool, volume: Double) {
        let active = frame.state == .laugh
        player?.volume = Float(volume)
        if !active || !enabled { player?.stop() }
        if active && !laughing && enabled && volume > 0 { start(volume: volume) }
        laughing = active
    }

    func applySettings(enabled: Bool, volume: Double) {
        player?.volume = Float(volume)
        if !enabled || volume == 0 { player?.stop() }
    }

    func stop() { player?.stop(); laughing = false }

    private func start(volume: Double) {
        player?.stop(); player = nil; sourcePath = nil; failure = nil
        let directories = [profileDirectory.appendingPathComponent("Sounds"), profileDirectory,
                           CharacterAssets.bundledDirectory.appendingPathComponent("Sounds")]
        var foundFile = false
        for directory in directories {
            for ext in ["m4a", "wav", "mp3"] {
                let url = directory.appendingPathComponent("nailong-laugh.\(ext)")
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                foundFile = true
                do {
                    let sound = try AVAudioPlayer(contentsOf: url)
                    sound.volume = Float(volume); sound.numberOfLoops = 0
                    guard sound.prepareToPlay(), sound.play() else {
                        failure = "无法播放大笑声音：\(url.lastPathComponent)"; continue
                    }
                    player = sound; sourcePath = url.path; failure = nil; starts += 1
                    return
                } catch { failure = "无法读取大笑声音：\(error.localizedDescription)" }
            }
        }
        if !foundFile { failure = "未找到 nailong-laugh.m4a / wav / mp3" }
    }

    var diagnostics: [String: Any] {
        ["source": sourcePath ?? "none", "playing": player?.isPlaying ?? false,
         "starts": starts, "failure": failure ?? "none"]
    }
}
