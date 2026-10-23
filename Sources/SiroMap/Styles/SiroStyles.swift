/**
 * وظيفة الملف: تنفيذ جزء SiroStyles ضمن حزمة العميل أو التطبيق.
 */
import Foundation

/**
 * Predefined map visual styles for the Siro Map SDK for iOS (Swift).
 * Mirrors SiroStyles from Flutter SDK.
 */
public struct SiroStyles {
    public static var dark: String {
        let keyParam = SiroMaps.shared.apiKey.isEmpty ? "" : "?key=\(SiroMaps.shared.apiKey)"
        return "\(SiroMaps.shared.baseUrl)/style-dark.json\(keyParam)"
    }

    public static var light: String {
        let keyParam = SiroMaps.shared.apiKey.isEmpty ? "" : "?key=\(SiroMaps.shared.apiKey)"
        return "\(SiroMaps.shared.baseUrl)/style.json\(keyParam)"
    }

    public static var normal: String {
        let keyParam = SiroMaps.shared.apiKey.isEmpty ? "" : "?key=\(SiroMaps.shared.apiKey)"
        return "\(SiroMaps.shared.baseUrl)/style.json\(keyParam)"
    }

    public static var satellite: String {
        let keyParam = SiroMaps.shared.apiKey.isEmpty ? "" : "?key=\(SiroMaps.shared.apiKey)"
        return "\(SiroMaps.shared.baseUrl)/style-satellite.json\(keyParam)"
    }

    public static var outdoors: String {
        let keyParam = SiroMaps.shared.apiKey.isEmpty ? "" : "?key=\(SiroMaps.shared.apiKey)"
        return "\(SiroMaps.shared.baseUrl)/style-tourism.json\(keyParam)"
    }

    public static var terrain: String {
        let keyParam = SiroMaps.shared.apiKey.isEmpty ? "" : "?key=\(SiroMaps.shared.apiKey)"
        return "\(SiroMaps.shared.baseUrl)/style-3d-terrain.json\(keyParam)"
    }
}

public enum SiroMapType: String, Codable {
    case none
    case normal
    case light
    case satellite
    case dark
    case terrain
}
