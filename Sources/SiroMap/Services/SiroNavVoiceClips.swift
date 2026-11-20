/**
 * وظيفة الملف: اختيار معرّف المقطع الصوتي لمناورة تدخل نفقاً أو جسراً (نفس منطق حزمة siro_nav بفلاتر).
 * الحزمة لا تحمل ملفات الصوت؛ المعرّفات هي أسماء الملفات (بلا .mp3) في حزم siro_nav الصوتية.
 */
import Foundation

public enum SiroNavVoiceClips {

    /// Clip for a maneuver that leads into a tunnel or bridge, or nil when none applies.
    /// - Parameters:
    ///   - envNext: `tunnel` or `bridge` (`SiroRouteStep.envNext`).
    ///   - envVariant: `kobri` for Egypt and Saudi Arabia (`SiroRouteStep.envVariant`).
    ///   - maneuverSign: GraphHopper sign of the step.
    ///   - distanceMeters: distance to the maneuver.
    public static func envClipId(
        envNext: String,
        envVariant: String? = nil,
        maneuverSign: Int,
        distanceMeters: Double
    ) -> String? {
        let tunnel = envNext == "tunnel"
        let kobri = !tunnel && envVariant == "kobri"
        let noun = tunnel ? "enter_tunnel" : (kobri ? "take_kobri" : "take_bridge")
        if distanceMeters <= 35 {
            switch maneuverSign {
            case -7: return "\(noun)_keep_left"
            case 7: return "\(noun)_keep_right"
            case -1: return "\(noun)_slight_left"
            case 1: return "\(noun)_slight_right"
            default: return "\(noun)_now"
            }
        }
        let bin: String?
        switch distanceMeters {
        case ...125: bin = "100m"
        case ...250: bin = "200m"
        case ...400: bin = "300m"
        case ...700: bin = "500m"
        default: bin = nil
        }
        return bin.map { "after_\($0)_\(noun)" }
    }

    /// "ثم ..." clip for a tunnel/bridge maneuver that follows right after another one.
    public static func thenEnvClipId(envNext: String, envVariant: String? = nil) -> String {
        if envNext == "tunnel" { return "then_enter_tunnel" }
        return envVariant == "kobri" ? "then_take_kobri" : "then_take_bridge"
    }

    private static let turnRight: Set<Int> = [2, 3]
    private static let turnLeft: Set<Int> = [-2, -3]
    private static let uTurn: Set<Int> = [8, -8, -98]

    /// Immediate ("now") clip for a maneuver; nil for "continue" (0) and via points (5).
    public static func immediateClipId(maneuverSign: Int, exitNumber: Int? = nil) -> String? {
        switch maneuverSign {
        case 2: return "turn_right_now"
        case -2: return "turn_left_now"
        case 1: return "slight_right_now"
        case -1: return "slight_left_now"
        case 3: return "sharp_right_now"
        case -3: return "sharp_left_now"
        case 7: return "keep_right"
        case -7: return "keep_left"
        case 8, -8, -98: return "u_turn_now"
        case 4: return "arrived_successfully"
        case 6:
            if let n = exitNumber, (1...6).contains(n) { return "roundabout_exit_\(n)" }
            return "enter_roundabout_now"
        case -6: return "leave_roundabout"
        default: return nil
        }
    }

    private struct Bin {
        let max: Double
        let name: String
        let roundabout: Bool
        let uturn: Bool
    }

    private static let bins: [Bin] = [
        Bin(max: 60, name: "50m", roundabout: true, uturn: false),
        Bin(max: 125, name: "100m", roundabout: false, uturn: true),
        Bin(max: 175, name: "150m", roundabout: false, uturn: false),
        Bin(max: 225, name: "200m", roundabout: false, uturn: false),
        Bin(max: 275, name: "250m", roundabout: false, uturn: false),
        Bin(max: 350, name: "300m", roundabout: true, uturn: false),
        Bin(max: 450, name: "400m", roundabout: true, uturn: false),
        Bin(max: 600, name: "500m", roundabout: true, uturn: false),
        Bin(max: 850, name: "750m", roundabout: false, uturn: false),
        Bin(max: 1200, name: "1km", roundabout: false, uturn: false)
    ]

    /// Pre-recorded clip for a maneuver at a distance, mirroring siro_nav's NavVoiceEngine.
    /// `priority` 0 means "now". Returns nil when nothing should be spoken yet.
    public static func resolveClipId(
        maneuverSign: Int,
        distanceMeters: Double,
        priority: Int = 2,
        exitNumber: Int? = nil,
        envNext: String? = nil,
        envVariant: String? = nil
    ) -> String? {
        if let env = envNext,
           let id = envClipId(envNext: env, envVariant: envVariant, maneuverSign: maneuverSign, distanceMeters: distanceMeters) {
            return id
        }
        if distanceMeters <= 35 || priority == 0 {
            return immediateClipId(maneuverSign: maneuverSign, exitNumber: exitNumber)
        }
        guard let bin = bins.first(where: { distanceMeters <= $0.max }) else { return nil }
        if turnRight.contains(maneuverSign) { return "after_\(bin.name)_turn_right" }
        if turnLeft.contains(maneuverSign) { return "after_\(bin.name)_turn_left" }
        if bin.roundabout && maneuverSign == 6 { return "after_\(bin.name)_roundabout" }
        if bin.uturn && uTurn.contains(maneuverSign) { return "after_\(bin.name)_u_turn" }
        return nil
    }

    /// "ثم ..." clip for a maneuver following right after another one (falls back to the "now" clip).
    public static func chainClipId(
        maneuverSign: Int,
        exitNumber: Int? = nil,
        envNext: String? = nil,
        envVariant: String? = nil,
        hasClip: (String) -> Bool
    ) -> String? {
        if let env = envNext {
            let t = thenEnvClipId(envNext: env, envVariant: envVariant)
            if hasClip(t) { return t }
        }
        var then: String?
        switch maneuverSign {
        case 2: then = "then_turn_right"
        case -2: then = "then_turn_left"
        case 1: then = "then_slight_right"
        case -1: then = "then_slight_left"
        case 3: then = "then_sharp_right"
        case -3: then = "then_sharp_left"
        case 7: then = "then_keep_right"
        case -7: then = "then_keep_left"
        case 8, -8, -98: then = "then_u_turn"
        case 6:
            if let n = exitNumber, (1...6).contains(n) { return "roundabout_exit_\(n)" }
            then = "then_enter_roundabout"
        default: then = nil
        }
        if let t = then, hasClip(t) { return t }
        return immediateClipId(maneuverSign: maneuverSign, exitNumber: exitNumber)
    }
}
