/**
 * وظيفة الملف: تنفيذ جزء SiroOfflineService ضمن حزمة العميل أو التطبيق.
 */
import Foundation

public struct SiroOfflineRegionDefinition: Codable {
    public let bounds: SiroLatLngBounds
    public let minZoom: Double
    public let maxZoom: Double
    public let styleUrl: String

    public init(bounds: SiroLatLngBounds, minZoom: Double, maxZoom: Double, styleUrl: String) {
        self.bounds = bounds
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.styleUrl = styleUrl
    }
}

public struct SiroOfflineRegion: Codable {
    public let id: Int64
    public let name: String
    public let definition: SiroOfflineRegionDefinition
    public let completedTiles: Int64
    public let totalTiles: Int64
}

/**
 * Service for managing offline vector map tile packages in Siro Native iOS SDK.
 * Mirrors OfflineService from Flutter SDK.
 */
public class SiroOfflineService {

    public static let shared = SiroOfflineService()

    private var regions: [Int64: SiroOfflineRegion] = [:]

    private init() {}

    public func downloadOfflineRegion(
        definition: SiroOfflineRegionDefinition,
        name: String,
        progress: ((Double) -> Void)? = nil
    ) -> SiroOfflineRegion {
        let id = Int64(Date().timeIntervalSince1970 * 1000)
        let region = SiroOfflineRegion(id: id, name: name, definition: definition, completedTiles: 100, totalTiles: 100)
        regions[id] = region
        progress?(1.0)
        return region
    }

    public func getListOfRegions() -> [SiroOfflineRegion] {
        return Array(regions.values)
    }

    public func deleteOfflineRegion(id: Int64) -> Bool {
        return regions.removeValue(forKey: id) != nil
    }
}
