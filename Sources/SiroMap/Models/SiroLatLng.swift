/**
 * وظيفة الملف: تنفيذ جزء SiroLatLng ضمن حزمة العميل أو التطبيق.
 */
import Foundation
import CoreLocation

/**
 * An immutable struct representing a pair of latitude and longitude coordinates.
 * Fully compatible with Google Maps iOS SDK and CoreLocation coordinate signatures.
 */
public struct SiroLatLng: Equatable, Hashable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = max(-90.0, min(90.0, latitude))
        self.longitude = max(-180.0, min(180.0, longitude))
    }

    public init(coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Calculates spherical distance in meters to another SiroLatLng
    public func distance(to other: SiroLatLng) -> Double {
        let loc1 = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }

    /// Calculates initial bearing in degrees to another SiroLatLng
    public func bearing(to other: SiroLatLng) -> Double {
        let lat1 = self.latitude * .pi / 180.0
        let lon1 = self.longitude * .pi / 180.0
        let lat2 = other.latitude * .pi / 180.0
        let lon2 = other.longitude * .pi / 180.0

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let rad = atan2(y, x)
        return (rad * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}
