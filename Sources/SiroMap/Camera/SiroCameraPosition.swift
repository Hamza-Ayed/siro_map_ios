/**
 * وظيفة الملف: تنفيذ جزء SiroCameraPosition ضمن حزمة العميل أو التطبيق.
 */
import Foundation
import CoreGraphics

/**
 * Encapsulates all camera position properties for iOS map view.
 * Fully compatible with Google Maps SDK (GMSCameraPosition).
 */
public struct SiroCameraPosition: Equatable, Codable {
    public let target: SiroLatLng
    public let zoom: Float
    public let viewingAngle: Double // Tilt (0 - 60 degrees)
    public let bearing: Double      // Heading (0 - 360 degrees)

    public init(target: SiroLatLng, zoom: Float = 12.0, viewingAngle: Double = 0.0, bearing: Double = 0.0) {
        self.target = target
        self.zoom = zoom
        self.viewingAngle = max(0.0, min(65.0, viewingAngle))
        self.bearing = bearing.truncatingRemainder(dividingBy: 360.0)
    }

    public static func from(target: SiroLatLng, zoom: Float) -> SiroCameraPosition {
        return SiroCameraPosition(target: target, zoom: zoom)
    }
}

/**
 * Camera update instructions for smooth animation.
 */
public enum SiroCameraUpdate {
    case newLatLng(SiroLatLng)
    case newLatLngZoom(SiroLatLng, Float)
    case newCameraPosition(SiroCameraPosition)
    case zoomIn
    case zoomOut
}
