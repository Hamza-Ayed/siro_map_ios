/**
 * وظيفة الملف: تنفيذ جزء SiroGeometry ضمن حزمة العميل أو التطبيق.
 */
import Foundation
import CoreLocation

#if canImport(UIKit)
import UIKit
public typealias SiroColor = UIColor
public typealias SiroImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias SiroColor = NSColor
public typealias SiroImage = NSImage
#endif

// ─────────────────────────────────────────────────────────────
// ID Types (Matching Flutter SDK & Google Maps iOS SDK)
// ─────────────────────────────────────────────────────────────

public struct SiroMarkerId: Hashable, Equatable, Codable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

public struct SiroPolylineId: Hashable, Equatable, Codable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

public struct SiroPolygonId: Hashable, Equatable, Codable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

public struct SiroCircleId: Hashable, Equatable, Codable {
    public let value: String
    public init(_ value: String) { self.value = value }
}

/**
 * An immutable struct representing a latitude/longitude bounding box.
 */
public struct SiroLatLngBounds: Equatable, Codable {
    public let southwest: SiroLatLng
    public let northeast: SiroLatLng

    public init(southwest: SiroLatLng, northeast: SiroLatLng) {
        self.southwest = southwest
        self.northeast = northeast
    }

    public func contains(_ point: SiroLatLng) -> Bool {
        let inLat = point.latitude >= southwest.latitude && point.latitude <= northeast.latitude
        let inLng = point.longitude >= southwest.longitude && point.longitude <= northeast.longitude
        return inLat && inLng
    }
}

// ─────────────────────────────────────────────────────────────
// Bitmap & InfoWindow Types
// ─────────────────────────────────────────────────────────────

public class SiroBitmap {
    public enum BitmapType {
        case defaultMarker
        case defaultMarkerWithHue(CGFloat)
        case image(SiroImage)
        case asset(String)
    }

    public let type: BitmapType

    public init(type: BitmapType) {
        self.type = type
    }

    public static let defaultMarker = SiroBitmap(type: .defaultMarker)

    public static func defaultMarker(withHue hue: CGFloat) -> SiroBitmap {
        return SiroBitmap(type: .defaultMarkerWithHue(hue))
    }

    public static func from(image: SiroImage) -> SiroBitmap {
        return SiroBitmap(type: .image(image))
    }

    public static func from(assetName: String) -> SiroBitmap {
        return SiroBitmap(type: .asset(assetName))
    }
}

public struct SiroInfoWindow {
    public let title: String?
    public let snippet: String?
    public let anchor: CGPoint
    public let onTap: (() -> Void)?

    public init(title: String? = nil, snippet: String? = nil, anchor: CGPoint = CGPoint(x: 0.5, y: 0.0), onTap: (() -> Void)? = nil) {
        self.title = title
        self.snippet = snippet
        self.anchor = anchor
        self.onTap = onTap
    }

    public static let noText = SiroInfoWindow()
}

// ─────────────────────────────────────────────────────────────
// Map Overlay Elements (Matching Flutter SDK)
// ─────────────────────────────────────────────────────────────

public class SiroMarker {
    public let markerId: SiroMarkerId
    public var position: SiroLatLng
    public var alpha: CGFloat
    public var anchor: CGPoint
    public var isDraggable: Bool
    public var isFlat: Bool
    public var icon: SiroBitmap
    public var infoWindow: SiroInfoWindow
    public var rotation: Double
    public var isVisible: Bool
    public var zIndex: Int32
    public var onTap: (() -> Void)?

    public init(
        markerId: SiroMarkerId,
        position: SiroLatLng,
        alpha: CGFloat = 1.0,
        anchor: CGPoint = CGPoint(x: 0.5, y: 1.0),
        isDraggable: Bool = false,
        isFlat: Bool = false,
        icon: SiroBitmap = .defaultMarker,
        infoWindow: SiroInfoWindow = .noText,
        rotation: Double = 0.0,
        isVisible: Bool = true,
        zIndex: Int32 = 0,
        onTap: (() -> Void)? = nil
    ) {
        self.markerId = markerId
        self.position = position
        self.alpha = alpha
        self.anchor = anchor
        self.isDraggable = isDraggable
        self.isFlat = isFlat
        self.icon = icon
        self.infoWindow = infoWindow
        self.rotation = rotation
        self.isVisible = isVisible
        self.zIndex = zIndex
        self.onTap = onTap
    }
}

public class SiroPolyline {
    public let polylineId: SiroPolylineId
    public var points: [SiroLatLng]
    public var strokeColor: SiroColor
    public var strokeWidth: CGFloat
    public var isGeodesic: Bool
    public var isVisible: Bool
    public var zIndex: Int32
    public var onTap: (() -> Void)?

    public init(
        polylineId: SiroPolylineId,
        points: [SiroLatLng] = [],
        strokeColor: SiroColor = SiroColor(red: 0.0, green: 0.44, blue: 0.89, alpha: 1.0),
        strokeWidth: CGFloat = 10.0,
        isGeodesic: Bool = true,
        isVisible: Bool = true,
        zIndex: Int32 = 0,
        onTap: (() -> Void)? = nil
    ) {
        self.polylineId = polylineId
        self.points = points
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.isGeodesic = isGeodesic
        self.isVisible = isVisible
        self.zIndex = zIndex
        self.onTap = onTap
    }
}

public class SiroPolygon {
    public let polygonId: SiroPolygonId
    public var points: [SiroLatLng]
    public var holes: [[SiroLatLng]]
    public var strokeColor: SiroColor
    public var strokeWidth: CGFloat
    public var fillColor: SiroColor
    public var isVisible: Bool
    public var zIndex: Int32
    public var onTap: (() -> Void)?

    public init(
        polygonId: SiroPolygonId,
        points: [SiroLatLng] = [],
        holes: [[SiroLatLng]] = [],
        strokeColor: SiroColor = SiroColor(red: 0.0, green: 0.44, blue: 0.89, alpha: 1.0),
        strokeWidth: CGFloat = 5.0,
        fillColor: SiroColor = SiroColor(red: 0.0, green: 0.44, blue: 0.89, alpha: 0.2),
        isVisible: Bool = true,
        zIndex: Int32 = 0,
        onTap: (() -> Void)? = nil
    ) {
        self.polygonId = polygonId
        self.points = points
        self.holes = holes
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.fillColor = fillColor
        self.isVisible = isVisible
        self.zIndex = zIndex
        self.onTap = onTap
    }
}

public class SiroCircle {
    public let circleId: SiroCircleId
    public var center: SiroLatLng
    public var radiusMeters: Double
    public var strokeColor: SiroColor
    public var strokeWidth: CGFloat
    public var fillColor: SiroColor
    public var isVisible: Bool
    public var zIndex: Int32
    public var onTap: (() -> Void)?

    public init(
        circleId: SiroCircleId,
        center: SiroLatLng,
        radiusMeters: Double,
        strokeColor: SiroColor = SiroColor(red: 0.13, green: 0.77, blue: 0.36, alpha: 1.0),
        strokeWidth: CGFloat = 4.0,
        fillColor: SiroColor = SiroColor(red: 0.13, green: 0.77, blue: 0.36, alpha: 0.2),
        isVisible: Bool = true,
        zIndex: Int32 = 0,
        onTap: (() -> Void)? = nil
    ) {
        self.circleId = circleId
        self.center = center
        self.radiusMeters = radiusMeters
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.fillColor = fillColor
        self.isVisible = isVisible
        self.zIndex = zIndex
        self.onTap = onTap
    }
}
