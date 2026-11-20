/**
 * وظيفة الملف: كتالوج الأصوات المسجّلة ومشغّلها في حزمة iOS (نفس حزم siro_nav بفلاتر).
 * الملفات داخل الحزمة نفسها (Resources/audio)، فلا تحتاج اتصالاً ولا مفتاحاً أثناء الرحلة.
 */
import Foundation
import AVFoundation

public enum SiroNavVoiceGender: String {
    case male = "ar"
    case female = "ar_female"
}

private let siroNavResourceBundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    let own = Bundle(for: SiroNavVoiceCatalog.self)
    if let url = own.url(forResource: "SiroMapAudio", withExtension: "bundle"), let b = Bundle(url: url) { return b }
    return own
    #endif
}()

/// id -> file map read from the pack's manifest.json, with the male pack as fallback for the female one.
public final class SiroNavVoiceCatalog {
    public let gender: SiroNavVoiceGender
    private let primary: [String: String]
    private let fallback: [String: String]
    private let bundle: Bundle

    public init(gender: SiroNavVoiceGender = .female, bundle: Bundle? = nil) {
        self.gender = gender
        let b = bundle ?? siroNavResourceBundle
        self.bundle = b
        self.primary = SiroNavVoiceCatalog.load(gender, b)
        self.fallback = gender == .female ? SiroNavVoiceCatalog.load(.male, b) : [:]
    }

    private static func load(_ gender: SiroNavVoiceGender, _ bundle: Bundle) -> [String: String] {
        guard let url = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "audio/\(gender.rawValue)"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prompts = root["prompts"] as? [String: [String: Any]] else { return [:] }
        var out: [String: String] = [:]
        for (id, p) in prompts { if let f = p["file"] as? String { out[id] = f } }
        return out
    }

    public var count: Int { primary.count }
    public func hasPrompt(_ id: String) -> Bool { primary[id] != nil || fallback[id] != nil }

    /// File URL of the clip, or nil when neither pack has it.
    public func url(for id: String) -> URL? {
        if let f = primary[id] { return fileURL(f, gender) }
        if let f = fallback[id] { return fileURL(f, .male) }
        return nil
    }

    private func fileURL(_ file: String, _ g: SiroNavVoiceGender) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext, subdirectory: "audio/\(g.rawValue)")
    }
}

/// Plays clips one after another as a single announcement; a new call replaces the current one.
public final class SiroNavVoicePlayer: NSObject, AVAudioPlayerDelegate {
    public private(set) var catalog: SiroNavVoiceCatalog
    private var player: AVAudioPlayer?
    private var queue: [URL] = []
    private var generation = 0

    public init(gender: SiroNavVoiceGender = .female) {
        self.catalog = SiroNavVoiceCatalog(gender: gender)
    }

    public func setGender(_ gender: SiroNavVoiceGender) {
        catalog = SiroNavVoiceCatalog(gender: gender)
    }

    /// Plays `ids` in order. Ids without a clip are skipped.
    public func play(_ ids: [String]) {
        stop()
        queue = ids.compactMap { catalog.url(for: $0) }
        guard !queue.isEmpty else { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        #endif
        playNext()
    }

    public func stop() {
        generation += 1
        player?.stop()
        player = nil
        queue = []
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func playNext() {
        guard !queue.isEmpty else { return }
        let url = queue.removeFirst()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            player = p
            p.play()
        } catch {
            playNext()
        }
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if queue.isEmpty {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        } else {
            playNext()
        }
    }
}

/// One-call helper: pick the clip(s) for a step and play them (chained when a second maneuver is close).
public final class SiroNavVoice {
    private let player: SiroNavVoicePlayer

    public init(gender: SiroNavVoiceGender = .female) {
        player = SiroNavVoicePlayer(gender: gender)
    }

    public func setGender(_ gender: SiroNavVoiceGender) { player.setGender(gender) }
    public func stop() { player.stop() }

    /// Clip ids for `step` at `distanceMeters`; `followUp` is a maneuver within ~100 m after it.
    public func clipIds(for step: SiroRouteStep, distanceMeters: Double, priority: Int = 2, followUp: SiroRouteStep? = nil) -> [String] {
        guard let lead = SiroNavVoiceClips.resolveClipId(
            maneuverSign: step.maneuverSign, distanceMeters: distanceMeters, priority: priority,
            envNext: step.envNext, envVariant: step.envVariant) else { return [] }
        var ids = [lead]
        if let f = followUp,
           let chain = SiroNavVoiceClips.chainClipId(
            maneuverSign: f.maneuverSign, envNext: f.envNext, envVariant: f.envVariant,
            hasClip: { self.player.catalog.hasPrompt($0) }) {
            ids.append(chain)
        }
        return ids
    }

    public func announce(_ step: SiroRouteStep, distanceMeters: Double, priority: Int = 2, followUp: SiroRouteStep? = nil) {
        player.play(clipIds(for: step, distanceMeters: distanceMeters, priority: priority, followUp: followUp))
    }
}
